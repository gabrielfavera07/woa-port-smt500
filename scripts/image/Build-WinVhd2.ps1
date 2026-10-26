# Continuacao do Build-WinVhd.ps1 (win.vhd falhou) — saida VISIVEL.
# Roda elevado. Log: image-work\output\build-vhd2.log
$ErrorActionPreference = 'Stop'
$root = 'E:\VIBECODING\windroid10\woa-port-smt500'
$out = "$root\image-work\output"
$esd = "$root\image-work\uup\UUPs\professional_pt-br.esd"
Start-Transcript -Path "$out\build-vhd2.log" -Force

Write-Host "== A) estado atual (volumes/VHDs)"
Get-Volume | Where-Object DriveLetter | Select-Object DriveLetter,FileSystemLabel,Size | Format-Table -AutoSize
Get-Item "$out\*.vhd" -ErrorAction SilentlyContinue | Select-Object Name,Length | Format-Table -AutoSize

Write-Host "== B) destacha o que estiver pendurado"
$hs0 = @'
select vdisk file="E:\VIBECODING\windroid10\woa-port-smt500\image-work\output\esp.vhd"
detach vdisk
'@
Set-Content -Path "$root\image-work\dp-det0.txt" -Value $hs0
diskpart /s "$root\image-work\dp-det0.txt"

Write-Host "== C) remove win.vhd antigo e recria (23976MB fixo)"
Remove-Item "$out\win.vhd" -Force -ErrorAction SilentlyContinue
$hs1 = @'
create vdisk file="E:\VIBECODING\windroid10\woa-port-smt500\image-work\output\win.vhd" type=fixed maximum=23976
'@
Set-Content -Path "$root\image-work\dp-w1.txt" -Value $hs1
diskpart /s "$root\image-work\dp-w1.txt"
if (-not (Test-Path "$out\win.vhd")) { throw "win.vhd nao foi criado (ver saida do diskpart acima)" }

$hs2 = @'
select vdisk file="E:\VIBECODING\windroid10\woa-port-smt500\image-work\output\win.vhd"
attach vdisk
'@
Set-Content -Path "$root\image-work\dp-w2.txt" -Value $hs2
diskpart /s "$root\image-work\dp-w2.txt"

$hs3 = @'
list disk
list volume
'@
Set-Content -Path "$root\image-work\dp-ls.txt" -Value $hs3
diskpart /s "$root\image-work\dp-ls.txt"

$hs4 = @'
select vdisk file="E:\VIBECODING\windroid10\woa-port-smt500\image-work\output\win.vhd"
select partition 1
format fs=ntfs label=WIN quick
assign letter=W
'@
Set-Content -Path "$root\image-work\dp-w3.txt" -Value $hs4
diskpart /s "$root\image-work\dp-w3.txt"
if (-not (Test-Path 'W:\')) { throw "W: nao montou" }

Write-Host "== D) reanexa esp.vhd em S:"
$hs5 = @'
select vdisk file="E:\VIBECODING\windroid10\woa-port-smt500\image-work\output\esp.vhd"
attach vdisk
select partition 1
assign letter=S
'@
Set-Content -Path "$root\image-work\dp-e2.txt" -Value $hs5
diskpart /s "$root\image-work\dp-e2.txt"
if (-not (Test-Path 'S:\')) { throw "S: nao montou" }

Write-Host "== E) aplica ESD index 3"
dism /Apply-Image /ImageFile:$esd /Index:3 /ApplyDir:W:\
if ($LASTEXITCODE -ne 0) { throw "DISM apply falhou ($LASTEXITCODE)" }

Write-Host "== F) Unattend.xml"
$panther = 'W:\Windows\Panther'
New-Item -ItemType Directory -Force -Path $panther | Out-Null
$hs6 = @'
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
  <settings pass="oobeSystem">
    <component name="Microsoft-Windows-International-Core" processorArchitecture="arm64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <InputLocale>0416:00000416</InputLocale><SystemLocale>pt-BR</SystemLocale><UILanguage>pt-BR</UILanguage><UserLocale>pt-BR</UserLocale>
    </component>
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="arm64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <OOBE><HideEULAPage>true</HideEULAPage><HideOnlineAccountScreens>true</HideOnlineAccountScreens><HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE><ProtectYourPC>3</ProtectYourPC></OOBE>
      <UserAccounts><LocalAccounts><LocalAccount wcm:action="add" xmlns:wcm="urn:schemas-microsoft-com:unattend"><Name>favera</Name><Group>Administrators</Group><DisplayName>favera</DisplayName></LocalAccount></LocalAccounts></UserAccounts>
      <AutoLogon><Enabled>true</Enabled><Username>favera</Username><LogonCount>999</LogonCount></AutoLogon>
    </component>
  </settings>
  <settings pass="specialize">
    <component name="Microsoft-Windows-Deployment" processorArchitecture="arm64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <RunSynchronous><RunSynchronousCommand wcm:action="add" xmlns:wcm="urn:schemas-microsoft-com:unattend"><Order>1</Order><Path>cmd /c bcdedit /set testsigning on</Path></RunSynchronousCommand><RunSynchronousCommand wcm:action="add" xmlns:wcm="urn:schemas-microsoft-com:unattend"><Order>2</Order><Path>cmd /c bcdedit /set nointegritychecks on</Path></RunSynchronousCommand></RunSynchronous>
    </component>
  </settings>
</unattend>
'@
Set-Content -Path "$panther\Unattend.xml" -Value $hs6 -Encoding UTF8

Write-Host "== G) bypass no hive offline"
reg load HKLM\_WOA "W:\Windows\System32\config\SYSTEM" | Out-Null
reg add "HKLM\_WOA\Setup\LabConfig" /v BypassTPMCheck /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\_WOA\Setup\LabConfig" /v BypassRAMCheck /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\_WOA\Setup\LabConfig" /v BypassSecureBootCheck /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\_WOA\Setup\LabConfig" /v BypassCPUCheck /t REG_DWORD /d 1 /f | Out-Null
reg unload HKLM\_WOA | Out-Null

Write-Host "== H) bcdboot -> S:"
bcdboot W:\Windows /s S: /f UEFI
if ($LASTEXITCODE -ne 0) { throw "bcdboot falhou" }

Write-Host "== I) BCD testsigning"
bcdedit /store S:\EFI\Microsoft\Boot\BCD /set "{default}" testsigning on
bcdedit /store S:\EFI\Microsoft\Boot\BCD /set "{default}" nointegritychecks on
bcdedit /store S:\EFI\Microsoft\Boot\BCD /set "{default}" recoveryenabled no
if (Test-Path "S:\EFI\Microsoft\Boot\SiPolicy.p7b") { Remove-Item "S:\EFI\Microsoft\Boot\SiPolicy.p7b" -Force }

Write-Host "== J) desanexa tudo"
$hs7 = @'
select vdisk file="E:\VIBECODING\windroid10\woa-port-smt500\image-work\output\win.vhd"
detach vdisk
select vdisk file="E:\VIBECODING\windroid10\woa-port-smt500\image-work\output\esp.vhd"
detach vdisk
'@
Set-Content -Path "$root\image-work\dp-det9.txt" -Value $hs7
diskpart /s "$root\image-work\dp-det9.txt"

Get-Item "$out\win.vhd","$out\esp.vhd" | Select-Object Name,Length | Format-Table -AutoSize
Set-Content -Path "$out\BUILD-OK.txt" -Value "OK $(Get-Date)"
Stop-Transcript

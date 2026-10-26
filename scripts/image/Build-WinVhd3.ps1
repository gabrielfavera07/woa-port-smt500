# v3: win.vhd DINAMICO 16GB em C:\woa-temp (C: com 12,7GB livres); esp.vhd ja existe em E:.
# Saida VISIVEL. Roda elevado. Log: image-work\output\build-vhd3.log
$ErrorActionPreference = 'Stop'
$root = 'E:\VIBECODING\windroid10\woa-port-smt500'
$out = "$root\image-work\output"
$esd = "$root\image-work\uup\UUPs\professional_pt-br.esd"
$ctmp = 'C:\woa-temp'
New-Item -ItemType Directory -Force -Path $ctmp | Out-Null
Start-Transcript -Path "$out\build-vhd3.log" -Force

Write-Host "== A) destacha pendurados"
$hs0 = @'
select vdisk file="E:\VIBECODING\windroid10\woa-port-smt500\image-work\output\esp.vhd"
detach vdisk
'@
Set-Content -Path "$root\image-work\dp-a.txt" -Value $hs0
diskpart /s "$root\image-work\dp-a.txt"

Write-Host "== B) cria win.vhd dinamico 16GB em C:"
Remove-Item "$ctmp\win.vhd" -Force -ErrorAction SilentlyContinue
$hs1 = @'
create vdisk file="C:\woa-temp\win.vhd" type=expandable maximum=16000
select vdisk file="C:\woa-temp\win.vhd"
attach vdisk
create partition primary
format fs=ntfs label=WIN quick
assign letter=W
'@
Set-Content -Path "$root\image-work\dp-b.txt" -Value $hs1
diskpart /s "$root\image-work\dp-b.txt"
if (-not (Test-Path 'W:\')) { throw 'W: nao montou (ver diskpart acima)' }

Write-Host "== C) anexa esp.vhd em S:"
$hs2 = @'
select vdisk file="E:\VIBECODING\windroid10\woa-port-smt500\image-work\output\esp.vhd"
attach vdisk
select partition 1
assign letter=S
'@
Set-Content -Path "$root\image-work\dp-c.txt" -Value $hs2
diskpart /s "$root\image-work\dp-c.txt"
if (-not (Test-Path 'S:\')) { throw 'S: nao montou' }

Write-Host "== D) aplica ESD index 3 (~10 min)"
dism /Apply-Image /ImageFile:$esd /Index:3 /ApplyDir:W:\
if ($LASTEXITCODE -ne 0) { throw "DISM apply falhou ($LASTEXITCODE)" }
$usado = (Get-Volume W).Size - (Get-Volume W).SizeRemaining
Write-Host ("Windows aplicado: {0:N1} GB" -f ($usado/1GB))
Write-Host ("C: livre agora: {0:N1} GB" -f ((Get-PSDrive C).Free/1GB))

Write-Host "== E) Unattend.xml"
$panther = 'W:\Windows\Panther'
New-Item -ItemType Directory -Force -Path $panther | Out-Null
$hs3 = @'
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
Set-Content -Path "$panther\Unattend.xml" -Value $hs3 -Encoding UTF8

Write-Host "== F) bypass hive offline"
reg load HKLM\_WOA "W:\Windows\System32\config\SYSTEM" | Out-Null
reg add "HKLM\_WOA\Setup\LabConfig" /v BypassTPMCheck /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\_WOA\Setup\LabConfig" /v BypassRAMCheck /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\_WOA\Setup\LabConfig" /v BypassSecureBootCheck /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\_WOA\Setup\LabConfig" /v BypassCPUCheck /t REG_DWORD /d 1 /f | Out-Null
reg unload HKLM\_WOA | Out-Null

Write-Host "== G) bcdboot -> S:"
bcdboot W:\Windows /s S: /f UEFI
if ($LASTEXITCODE -ne 0) { throw 'bcdboot falhou' }

Write-Host "== H) BCD testsigning"
bcdedit /store S:\EFI\Microsoft\Boot\BCD /set "{default}" testsigning on
bcdedit /store S:\EFI\Microsoft\Boot\BCD /set "{default}" nointegritychecks on
bcdedit /store S:\EFI\Microsoft\Boot\BCD /set "{default}" recoveryenabled no

Write-Host "== I) desanexa"
$hs4 = @'
select vdisk file="C:\woa-temp\win.vhd"
detach vdisk
select vdisk file="E:\VIBECODING\windroid10\woa-port-smt500\image-work\output\esp.vhd"
detach vdisk
'@
Set-Content -Path "$root\image-work\dp-i.txt" -Value $hs4
diskpart /s "$root\image-work\dp-i.txt"

Get-Item "$ctmp\win.vhd","$out\esp.vhd" | Select-Object FullName,Length | Format-Table -AutoSize
Set-Content -Path "$out\BUILD-OK.txt" -Value "OK $(Get-Date)"
Stop-Transcript

<#
.SYNOPSIS
  Constrói win.vhd (23976MiB NTFS, Windows 11 Pro ARM64 22621 aplicado + Unattend)
  e esp.vhd (600MiB FAT32, BCD com testsigning) para gravacao via dd no SM-T500.
  Roda ELEVADO. Log: image-work\output\build-vhd.log
#>
$ErrorActionPreference = 'Stop'
$root = 'E:\VIBECODING\windroid10\woa-port-smt500'
$out = "$root\image-work\output"
$esd = "$root\image-work\uup\UUPs\professional_pt-br.esd"
New-Item -ItemType Directory -Force -Path $out | Out-Null
Start-Transcript -Path "$out\build-vhd.log" -Force

# limpa montagens/imagens anteriores
Write-Host "== 0/7 limpeza"
dism /Unmount-Image /MountDir:$root\image-work\mount /Discard 2>$null | Out-Null

Write-Host "== 1/7 criando VHDs (fixos)"
$hs1 = @'
select vdisk file="E:\VIBECODING\windroid10\woa-port-smt500\image-work\output\win.vhd"
detach vdisk
select vdisk file="E:\VIBECODING\windroid10\woa-port-smt500\image-work\output\esp.vhd"
detach vdisk
'@
Set-Content -Path "$root\image-work\dp-clean.txt" -Value $hs1
diskpart /s "$root\image-work\dp-clean.txt" 2>$null | Out-Null
Remove-Item "$out\win.vhd","$out\esp.vhd" -Force -ErrorAction SilentlyContinue

$hs2 = @'
create vdisk file="E:\VIBECODING\windroid10\woa-port-smt500\image-work\output\win.vhd" type=fixed maximum=23976
attach vdisk
create partition primary
format fs=ntfs label=WIN quick
assign letter=W
'@
Set-Content -Path "$root\image-work\dp-win.txt" -Value $hs2
diskpart /s "$root\image-work\dp-win.txt" | Out-Null

$hs3 = @'
create vdisk file="E:\VIBECODING\windroid10\woa-port-smt500\image-work\output\esp.vhd" type=fixed maximum=600
attach vdisk
create partition primary
format fs=fat32 label=ESP quick
assign letter=S
'@
Set-Content -Path "$root\image-work\dp-esp.txt" -Value $hs3
diskpart /s "$root\image-work\dp-esp.txt" | Out-Null

Write-Host "== 2/7 aplicando ESD (index 3 = Pro ARM64) -- alguns minutos"
dism /Apply-Image /ImageFile:$esd /Index:3 /ApplyDir:W:\
if ($LASTEXITCODE -ne 0) { throw "DISM apply falhou ($LASTEXITCODE)" }

Write-Host "== 3/7 Unattend.xml (pular OOBE + autologon, sem input)"
$panther = 'W:\Windows\Panther'
New-Item -ItemType Directory -Force -Path $panther | Out-Null
$hs4 = @'
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
Set-Content -Path "$panther\Unattend.xml" -Value $hs4 -Encoding UTF8

Write-Host "== 4/7 bypass RAM/TPM/SB no hive offline"
reg load HKLM\_WOA "W:\Windows\System32\config\SYSTEM" | Out-Null
reg add "HKLM\_WOA\Setup\LabConfig" /v BypassTPMCheck /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\_WOA\Setup\LabConfig" /v BypassRAMCheck /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\_WOA\Setup\LabConfig" /v BypassSecureBootCheck /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\_WOA\Setup\LabConfig" /v BypassCPUCheck /t REG_DWORD /d 1 /f | Out-Null
reg unload HKLM\_WOA | Out-Null

Write-Host "== 5/7 bcdboot -> ESP"
bcdboot W:\Windows /s S: /f UEFI
if ($LASTEXITCODE -ne 0) { throw "bcdboot falhou" }

Write-Host "== 6/7 BCD: testsigning + nointegritychecks"
bcdedit /store S:\EFI\Microsoft\Boot\BCD /set '{default}' testsigning on
bcdedit /store S:\EFI\Microsoft\Boot\BCD /set '{default}' nointegritychecks on
bcdedit /store S:\EFI\Microsoft\Boot\BCD /set '{default}' recoveryenabled no
if (Test-Path S:\EFI\Microsoft\Boot\SiPolicy.p7b) { Remove-Item S:\EFI\Microsoft\Boot\SiPolicy.p7b -Force }

Write-Host "== 7/7 desanexando"
$hs5 = @'
select vdisk file="E:\VIBECODING\windroid10\woa-port-smt500\image-work\output\win.vhd"
detach vdisk
select vdisk file="E:\VIBECODING\windroid10\woa-port-smt500\image-work\output\esp.vhd"
detach vdisk
'@
Set-Content -Path "$root\image-work\dp-det.txt" -Value $hs5
diskpart /s "$root\image-work\dp-det.txt" | Out-Null

Write-Host "CONCLUIDO:"
Get-Item "$out\win.vhd","$out\esp.vhd" | Select-Object Name,Length | Format-Table -AutoSize
Stop-Transcript

<#
.SYNOPSIS
  Aplica o Windows 11 ARM64 (22621) na partição WIN do tablet, via modo USB Mass
  Storage do UEFI (edk2 MSC). Roda NO PC com o tablet exposto como discos.

.DESCRIPTION
  Pré-requisitos:
    - Tablet bootado no UEFI com Mass Storage ativo (ESP e WIN visíveis como volumes)
    - ISO/WIM ARM64 build 22621 em -WimPath (install.wim ou install.esd)
    - Pasta com drivers ARM64 (WOA community) em -DriversPath
  Parâmetros obrigatórios: -WinDrive W: -EspDrive S: -WimPath <install.wim> -Index 1
  O script: aplica imagem, injeta drivers, bcdboot, testsigning/nointegritychecks,
  bypass LabConfig (RAM<4GB/TPM/SB) e remove SiPolicy.p7b.

.EXAMPLE
  .\Apply-WindowsToTablet.ps1 -WinDrive W: -EspDrive S: -WimPath C:\iso\install.wim -Index 1 -DriversPath C:\drivers-arm64
#>
param(
  [Parameter(Mandatory)] [string]$WinDrive,
  [Parameter(Mandatory)] [string]$EspDrive,
  [Parameter(Mandatory)] [string]$WimPath,
  [int]$Index = 1,
  [string]$DriversPath = "",
  [switch]$SkipDrivers
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path "$WinDrive\")) { throw "WinDrive $WinDrive inacessível — Mass Storage ativo?" }
if (-not (Test-Path "$EspDrive\EFI")) { throw "EspDrive $EspDrive sem EFI — letra certa?" }

Write-Host "== 1/6 Apply-Image ($WimPath index $Index) -> $WinDrive" -ForegroundColor Cyan
dism /Apply-Image /ImageFile:$WimPath /Index:$Index /ApplyDir:$WinDrive
if ($LASTEXITCODE -ne 0) { throw "DISM apply falhou ($LASTEXITCODE)" }

if (-not $SkipDrivers -and $DriversPath -and (Test-Path $DriversPath)) {
  Write-Host "== 2/6 Injetando drivers ARM64 de $DriversPath" -ForegroundColor Cyan
  dism /Image:$WinDrive /Add-Driver /Driver:$DriversPath /Recurse
  if ($LASTEXITCODE -ne 0) { Write-Warning "Add-Driver retornou $LASTEXITCODE — conferir log (%WINDIR%\Logs\DISM\dism.log)" }
} else { Write-Host "== 2/6 Drivers ignorados (-SkipDrivers/caminho vazio)" }

Write-Host "== 3/6 BCD boot files -> $EspDrive" -ForegroundColor Cyan
bcdboot "$WinDrive\Windows" /s $EspDrive /f UEFI
if ($LASTEXITCODE -ne 0) { throw "bcdboot falhou" }

$BcdStore = "$EspDrive\EFI\Microsoft\Boot\BCD"
Write-Host "== 4/6 testsigning + nointegritychecks (drivers community)" -ForegroundColor Cyan
bcdedit /store $BcdStore /set '{default}' testsigning on
bcdedit /store $BcdStore /set '{default}' nointegritychecks on
bcdedit /store $BcdStore /set '{default}' recoveryenabled no

Write-Host "== 5/6 Bypass de requisitos (RAM 3GB / TPM / SecureBoot) no offline hive" -ForegroundColor Cyan
reg load HKLM\_WOA_OFF "$WinDrive\Windows\System32\config\SYSTEM" | Out-Null
try {
  reg add "HKLM\_WOA_OFF\Setup\LabConfig" /v BypassTPMCheck /t REG_DWORD /d 1 /f | Out-Null
  reg add "HKLM\_WOA_OFF\Setup\LabConfig" /v BypassRAMCheck /t REG_DWORD /d 1 /f | Out-Null
  reg add "HKLM\_WOA_OFF\Setup\LabConfig" /v BypassSecureBootCheck /t REG_DWORD /d 1 /f | Out-Null
  reg add "HKLM\_WOA_OFF\Setup\LabConfig" /v BypassCPUCheck /t REG_DWORD /d 1 /f | Out-Null
} finally { reg unload HKLM\_WOA_OFF | Out-Null }

Write-Host "== 6/6 Removendo SiPolicy (SecureBoot policy) se presente" -ForegroundColor Cyan
$policy = "$EspDrive\EFI\Microsoft\Boot\SiPolicy.p7b"
if (Test-Path $policy) { Remove-Item $policy -Force; Write-Host "  SiPolicy.p7b removido" }

Write-Host ""
Write-Host "CONCLUIDO. Ejetar discos com seguranca, desligar MSC no UEFI e reiniciar." -ForegroundColor Green
Write-Host "Se OOBE travar em rede: Shift+F10 -> 'oobe\bypassnro' (Wi-Fi pode nao ter driver ainda)."

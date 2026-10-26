@echo off
REM ============================================================
REM Injecao offline do driver B2 no install.wim (DISM, ELEVADO).
REM Requisitos: C:\woa-temp\install-w-drv.wim + C:\woa-temp\driver-out\sdhc.inf
REM Log: C:\woa-temp\inject-driver.log
REM ============================================================
if not exist C:\woa-temp\wimmnt mkdir C:\woa-temp\wimmnt

dism /Mount-Wim /WimFile:C:\woa-temp\install-w-drv.wim /Index:1 /MountDir:C:\woa-temp\wimmnt
if errorlevel 1 goto :fail

dism /Image:C:\woa-temp\wimmnt /Add-Driver /Driver:C:\woa-temp\driver-out\sdhc.inf /ForceUnsigned
if errorlevel 1 goto :failunmount

dism /Unmount-Wim /MountDir:C:\woa-temp\wimmnt /Commit
if errorlevel 1 goto :fail

REM --- BCD da ESP: testsigning (BCD esperado em C:\woa-temp\BCD) ---
if exist C:\woa-temp\BCD (
  bcdedit /store C:\woa-temp\BCD /set {default} testsigning on
  bcdedit /store C:\woa-temp\BCD /set {default} nointegritychecks on
  bcdedit /store C:\woa-temp\BCD /set {default} recoveryenabled no
)

echo INJECT-OK > C:\woa-temp\INJECT-OK.txt
echo INJECT-OK
exit /b 0

:failunmount
dism /Unmount-Wim /MountDir:C:\woa-temp\wimmnt /Discard
:fail
echo INJECT-FALHOU > C:\woa-temp\INJECT-FAIL.txt
echo INJECT-FALHOU
exit /b 1

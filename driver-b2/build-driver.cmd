@echo off
REM ============================================================
REM Build do driver B2 (sdhc-msm) no EWDK 22621 - v3
REM ============================================================
setlocal
set OUT=C:\woa-temp\driver-out
if not exist %OUT% mkdir %OUT%

set EWDL=
for %%d in (D E F G H I J) do if exist %%d:\LaunchBuildEnv.cmd set EWDL=%%d
if "%EWDL%"=="" (
  powershell -nop -c "Mount-DiskImage -ImagePath 'E:\VIBECODING\ewdk-22621.iso'" >nul 2>&1
  for %%d in (D E F G H I J) do if exist %%d:\LaunchBuildEnv.cmd set EWDL=%%d
)
if "%EWDL%"=="" (
  echo ERRO: EWDK nao montou
  exit /b 1
)
echo EWDK montado em %EWDL%:

set MSB=%EWDL%:\Program Files\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe
if not exist "%MSB%" (
  echo ERRO: MSBuild nao encontrado
  exit /b 1
)

call %EWDL%:\BuildEnv\SetupBuildEnv.cmd C:\woa-temp\ewdk-cache >nul 2>&1

cd /d E:\VIBECODING\windroid10\woa-port-smt500\driver-b2
"%MSB%" src\inbox\sdhc.vcxproj /p:Configuration=Release /p:Platform=ARM64 /p:SignMode=Off /m /v:m
if errorlevel 1 (
  echo ERRO: msbuild falhou
  exit /b 1
)

for /r src %%f in (sdhc.sys sdhc.inf sdhc.cat sdhc.pdb) do copy /y "%%f" %OUT%\ >nul
dir %OUT%
echo BUILD-DRIVER-OK > C:\woa-temp\BUILD-DRIVER-OK.txt
echo BUILD-DRIVER-OK

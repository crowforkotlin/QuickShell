@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "ROOT=%~dp0.."
set "SERIAL=%ANDROID_SERIAL%"
set "REMOTE_DIR=files/home/.local/share/quick-shell"

echo [info] Checking adb...
where adb >nul 2>&1
if errorlevel 1 (
    echo [error] adb was not found in PATH.
    exit /b 1
)

if defined SERIAL (
    adb -s "%SERIAL%" get-state >nul 2>&1
    if errorlevel 1 (
        echo [error] The selected device is not available: %SERIAL%
        exit /b 1
    )
) else (
    set "DEVICE_COUNT=0"
    for /f "skip=1 tokens=1,2" %%A in ('adb devices 2^>nul') do (
        if "%%B"=="device" (
            set /a DEVICE_COUNT+=1
            set "SERIAL=%%A"
        )
    )
    if "!DEVICE_COUNT!"=="0" (
        echo [error] No authorized adb device was found.
        exit /b 1
    )
    if not "!DEVICE_COUNT!"=="1" (
        echo [error] Multiple devices were found. Set ANDROID_SERIAL and retry.
        exit /b 1
    )
)

echo [info] Using device: %SERIAL%
adb -s "%SERIAL%" shell pm path com.termux >nul 2>&1
if errorlevel 1 (
    echo [error] Termux is not installed on the device.
    exit /b 1
)

adb -s "%SERIAL%" shell run-as com.termux id >nul 2>&1
if errorlevel 1 (
    echo [error] run-as cannot access Termux.
    echo [error] Install the GitHub debug build or run the scripts inside Termux.
    exit /b 1
)

adb -s "%SERIAL%" shell run-as com.termux mkdir -p "%REMOTE_DIR%/bin"
if errorlevel 1 (
    echo [error] Could not create the private deployment directory.
    exit /b 1
)

call :upload "%ROOT%\init_shizuku.sh" "init_shizuku.sh"
if errorlevel 1 exit /b 1
call :upload "%ROOT%\init_light.sh" "init_light.sh"
if errorlevel 1 exit /b 1
call :upload "%~dp0init_termux.sh" "init_termux.sh"
if errorlevel 1 exit /b 1
call :upload "%~dp0termux.sh" "termux.sh"
if errorlevel 1 exit /b 1
call :upload "%~dp0bin\adb-connect" "bin/adb-connect"
if errorlevel 1 exit /b 1
call :upload "%~dp0bin\light" "bin/light"
if errorlevel 1 exit /b 1
call :upload "%~dp0bin\shizuku" "bin/shizuku"
if errorlevel 1 exit /b 1
call :upload "%~dp0bin\wf" "bin/wf"
if errorlevel 1 exit /b 1

adb -s "%SERIAL%" shell am start -n com.termux/.HomeActivity >nul 2>&1
echo [info] Running the Termux installer...
adb -s "%SERIAL%" shell run-as com.termux /data/data/com.termux/files/usr/bin/bash /data/data/com.termux/files/home/.local/share/quick-shell/init_termux.sh
if errorlevel 1 (
    echo [error] The Termux installer failed.
    exit /b 1
)

echo [info] Deployment completed.
exit /b 0
:upload
if not exist "%~1" (
    echo [error] File not found: %~1
    exit /b 1
)
adb -s "%SERIAL%" exec-out run-as com.termux sh -c "cat ^> %REMOTE_DIR%/%~2" < "%~1" >nul
if errorlevel 1 (
    echo [error] Could not upload: %~2
    exit /b 1
)
adb -s "%SERIAL%" shell run-as com.termux chmod 700 "%REMOTE_DIR%/%~2" >nul 2>&1
if errorlevel 1 (
    echo [error] Could not set permissions: %~2
    exit /b 1
)
exit /b 0

@echo off
setlocal EnableExtensions
pushd "%~dp0" >nul
if errorlevel 1 (
    echo [ERROR] Could not open the Argon installer repository folder.
    pause
    exit /b 1
)

echo ==========================================
echo Argon Installer Builder
echo ==========================================
echo.
echo This builds an installer from an Argon release by default.
echo For a local smoke test, pass your Argon-sim directory:
echo build-installer.bat -PayloadDirectory "%%USERPROFILE%%\Desktop\Argon-sim" -AppVersion "0.1.0-test.1"
echo.

where powershell.exe >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Windows PowerShell was not found.
    goto :failed
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\Build-Installer.ps1" %*
set "BUILD_EXIT_CODE=%ERRORLEVEL%"
if not "%BUILD_EXIT_CODE%"=="0" (
    echo.
    echo [ERROR] Installer build failed with exit code %BUILD_EXIT_CODE%.
    echo Read the diagnostics above. The installer EXE was not confirmed as successful.
    goto :failed
)

echo.
echo ==========================================
echo INSTALLER BUILD SUCCEEDED
echo Output folder: "%~dp0dist\output"
echo ==========================================
echo.
pause
popd
exit /b 0

:failed
echo.
pause
popd
exit /b 1

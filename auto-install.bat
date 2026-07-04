@echo off
chcp 65001 > nul

cd /d "%~dp0"

net session >nul 2>&1
if errorlevel 1 (
    echo Requesting admin rights...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%ComSpec%' -ArgumentList '/c call ""%~f0""' -WorkingDirectory '%~dp0' -Verb RunAs"
    exit /b
)

call "%~dp0utils\install-zapret.bat" auto
set "INSTALL_EXIT=%errorlevel%"

if not "%INSTALL_EXIT%"=="0" (
    echo.
    echo Auto install failed with code %INSTALL_EXIT%.
)

echo Press any key to exit . . .
pause >nul
exit /b %INSTALL_EXIT%

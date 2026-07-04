@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 > nul

cd /d "%~dp0"

:: PARSE ARGS ================================
:parse_args
if "%~1"=="" goto args_done
if /I "%~1"=="--make-template" (shift & call :run_make_template & exit /b !INSTALL_EXIT!)
if /I "%~1"=="--help" (call "%~dp0utils\install-zapret.bat" --help & exit /b 0)
if /I "%~1"=="-Help" (call "%~dp0utils\install-zapret.bat" --help & exit /b 0)
echo Error: Unknown argument '%~1'. Run with --help for usage.
exit /b 1
:args_done

net session >nul 2>&1
if errorlevel 1 (
    echo Requesting admin rights...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%ComSpec%' -ArgumentList '/c call ""%~f0""' -WorkingDirectory '%~dp0' -Verb RunAs"
    exit /b
)

call "%~dp0utils\install-zapret.bat" easy
set "INSTALL_EXIT=!errorlevel!"

if not "!INSTALL_EXIT!"=="0" (
    echo.
    echo Easy install failed with code !INSTALL_EXIT!.
)

echo Press any key to exit . . .
pause >nul
exit /b !INSTALL_EXIT!

:run_make_template
call "%~dp0utils\install-zapret.bat" easy --make-template
set "INSTALL_EXIT=!errorlevel!"
echo Press any key to exit . . .
pause >nul
exit /b !INSTALL_EXIT!

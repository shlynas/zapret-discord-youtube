@echo off
set "LOCAL_VERSION=1.9.9"

:: External commands
if "%~1"=="status_zapret" (
    call :test_service zapret soft
    call :tcp_enable
    exit /b
)

if "%~1"=="check_updates" (
    if defined NO_UPDATE_CHECK exit /b

    if exist "%~dp0utils\check_updates.enabled" (
        if not "%~2"=="soft" (
            start /b service check_updates soft
        ) else (
            call :service_check_updates soft
        )
    )
	
    exit /b
)

if "%~1"=="load_game_filter" (
    call :game_switch_status
    exit /b
)

if "%~1"=="load_discord_fake" (
    call :discord_fake_status
    exit /b
)

if "%~1"=="load_game_fake_tcp" (
    call :game_fake_tcp_status
    exit /b
)

if "%~1"=="load_game_fake_tcp_alt" (
    call :game_fake_tcp_alt_status
    exit /b
)

if "%~1"=="load_game_fake_tcp_alt2" (
    call :game_fake_tcp_alt2_status
    exit /b
)

if "%~1"=="load_game_fake_udp" (
    call :game_fake_udp_status
    exit /b
)

if "%~1"=="load_ipset_fake_tcp" (
    call :ipset_fake_tcp_status
    exit /b
)

if "%~1"=="load_ipset_fake_tcp_alt" (
    call :ipset_fake_tcp_alt_status
    exit /b
)

if "%~1"=="load_ipset_fake_tcp_alt2" (
    call :ipset_fake_tcp_alt2_status
    exit /b
)

if "%~1"=="load_ipset_fake_udp" (
    call :ipset_fake_udp_status
    exit /b
)

if "%~1"=="load_general_tcp" (
    call :general_tcp_status
    exit /b
)

if "%~1"=="load_general_tcp_alt" (
    call :general_tcp_alt_status
    exit /b
)

if "%~1"=="load_general_tcp_alt2" (
    call :general_tcp_alt2_status
    exit /b
)

if "%~1"=="load_general_udp" (
    call :general_udp_status
    exit /b
)

if "%~1"=="load_stun_fake" (
    call :stun_fake_status
    exit /b
)

if "%~1"=="load_hostfakesplit" (
    call :get_hfs_status "hostfakesplit" "hsf" "ozon.ru" "HostFakeSplitStatus"
    exit /b
)

if "%~1"=="load_hostfakesplit_alt" (
    call :get_hfs_status "hostfakesplit_alt" "hsfalt" "ya.ru" "HostFakeSplitAltStatus"
    exit /b
)

if "%~1"=="install_file" (
    call :service_install_file "%~2"
    exit /b %errorlevel%
)

if "%~1"=="load_user_lists" (
    call :load_user_lists
    exit /b
)

if "%1"=="admin" (
    call :check_command chcp
    call :check_command find
    call :check_command findstr
    call :check_command netsh

    call :load_user_lists

    echo Started with admin rights
) else (
    call :check_extracted
    call :check_command powershell

    echo Requesting admin rights...
    powershell -NoProfile -Command "Start-Process 'cmd.exe' -ArgumentList '/c \"\"%~f0\" admin\"' -Verb RunAs"
    exit
)


:: MENU ================================
setlocal EnableDelayedExpansion
:menu
cls
call :game_switch_status
call :ipset_switch_status
call :check_updates_switch_status
:: call :autorestart_status
call :load_current_strategy

set "menu_choice=null"

echo.
echo   ZAPRET SERVICE MANAGER v!LOCAL_VERSION! (shlynas)
echo   Current strategy: !CurrentStrategy!
echo   ----------------------------------------
echo.
echo   :: SERVICE
echo      1. Install Service
echo      2. Remove Services
echo      3. Check Status
echo.
echo   :: SETTINGS
echo      4. Game Filter         [!GameFilterStatus!]
echo      5. IPSet Filter        [!IPsetStatus!]
echo      6. Auto-Update Check   [!CheckUpdatesStatus!]
echo      7. Extra Settings
echo.
echo   :: UPDATES
echo      8. Update IPSet List
echo      9. Update Hosts File
echo      10. Check for Updates
echo.
echo   :: TOOLS
echo      11. Run Diagnostics
echo      12. Run Tests
echo.
echo   ----------------------------------------
echo      0. Exit
echo.

set /p menu_choice=   Select option (0-12): 

if "%menu_choice%"=="1" goto service_install
if "%menu_choice%"=="2" goto service_remove
if "%menu_choice%"=="3" goto service_status
if "%menu_choice%"=="4" goto game_switch
if "%menu_choice%"=="5" goto ipset_switch
if "%menu_choice%"=="6" goto check_updates_switch
if "%menu_choice%"=="7" goto extra_menu
if "%menu_choice%"=="8" goto ipset_update
if "%menu_choice%"=="9" goto hosts_update
if "%menu_choice%"=="10" goto service_check_updates
if "%menu_choice%"=="11" goto service_diagnostics
if "%menu_choice%"=="12" goto run_tests
if "%menu_choice%"=="99" goto verify_eof
if "%menu_choice%"=="0" exit /b
goto menu


:: CURRENT STRATEGY ====================
:load_current_strategy
set "CurrentStrategy=not installed"

sc query "zapret" >nul 2>&1
if errorlevel 1 exit /b

set "CurrentStrategy=unknown"
for /f "tokens=2*" %%A in ('reg query "HKLM\System\CurrentControlSet\Services\zapret" /v zapret-discord-youtube 2^>nul ^| findstr /i "zapret-discord-youtube"') do set "CurrentStrategy=%%B"

exit /b


:: LOAD USER LISTS =====================
:load_user_lists
set "LISTS_PATH=%~dp0lists\"

if not exist "%LISTS_PATH%ipset-exclude-user.txt" (
    echo 203.0.113.113/32>"%LISTS_PATH%ipset-exclude-user.txt"
)
if not exist "%LISTS_PATH%list-general-user.txt" (
    echo domain.example.abc>"%LISTS_PATH%list-general-user.txt"
)
if not exist "%LISTS_PATH%list-exclude-user.txt" (
    echo domain.example.abc>"%LISTS_PATH%list-exclude-user.txt"
)

exit /b


:: TCP ENABLE ==========================
:tcp_enable
netsh interface tcp show global | findstr /i "timestamps" | findstr /i "enabled" > nul || netsh interface tcp set global timestamps=enabled > nul 2>&1
exit /b


:: STATUS ==============================
:service_status
cls
chcp 437 > nul

sc query "zapret" >nul 2>&1
if !errorlevel!==0 (
    for /f "tokens=2*" %%A in ('reg query "HKLM\System\CurrentControlSet\Services\zapret" /v zapret-discord-youtube 2^>nul') do echo Service strategy installed from "%%B"
)

call :test_service zapret
call :test_service WinDivert

set "BIN_PATH=%~dp0bin\"
if not exist "%BIN_PATH%\*.sys" (
    call :PrintRed "WinDivert64.sys file NOT found."
)
echo:

tasklist /FI "IMAGENAME eq winws.exe" | find /I "winws.exe" > nul
if !errorlevel!==0 (
    call :PrintGreen "Bypass (winws.exe) is RUNNING."
) else (
    call :PrintRed "Bypass (winws.exe) is NOT running."
)

pause
goto menu

:test_service
set "ServiceName=%~1"
set "ServiceStatus="

for /f "tokens=3 delims=: " %%A in ('sc query "%ServiceName%" ^| findstr /i "STATE"') do set "ServiceStatus=%%A"
set "ServiceStatus=%ServiceStatus: =%"

if "%ServiceStatus%"=="RUNNING" (
    if "%~2"=="soft" (
        echo "%ServiceName%" is ALREADY RUNNING as service, use "service.bat" and choose "Remove Services" first if you want to run standalone bat.
        pause
        exit
    ) else (
        echo "%ServiceName%" service is RUNNING.
    )
) else if "%ServiceStatus%"=="STOP_PENDING" (
    call :PrintYellow "!ServiceName! is STOP_PENDING, that may be caused by a conflict with another bypass. Run Diagnostics to try to fix conflicts"
) else if not "%~2"=="soft" (
    echo "%ServiceName%" service is NOT running.
)

exit /b


:: REMOVE ==============================
:service_remove
cls
chcp 65001 > nul

set SRVCNAME=zapret
sc query "!SRVCNAME!" >nul 2>&1
if !errorlevel!==0 (
    net stop %SRVCNAME%
    sc delete %SRVCNAME%
    rem schtasks /delete /tn "ZapretRestart" /f >nul 2>&1
) else (
    echo Service "%SRVCNAME%" is not installed.
)

tasklist /FI "IMAGENAME eq winws.exe" | find /I "winws.exe" > nul
if !errorlevel!==0 (
    taskkill /IM winws.exe /F > nul
)

sc query "WinDivert" >nul 2>&1
if !errorlevel!==0 (
    net stop "WinDivert"

    sc query "WinDivert" >nul 2>&1
    if !errorlevel!==0 (
        sc delete "WinDivert"
    )
)
net stop "WinDivert14" >nul 2>&1
sc delete "WinDivert14" >nul 2>&1

pause
goto menu


:: INSTALL =============================
:service_install
cls
chcp 437 > nul

:: Main
cd /d "%~dp0"
set "BIN_PATH=%~dp0bin\"
set "LISTS_PATH=%~dp0lists\"

:: Searching for strategy files in current folder
echo Pick one of the options:
set "count=0"
for /f "delims=" %%F in ('powershell -NoProfile -Command "Get-ChildItem -LiteralPath '.' -Filter 'general*.bat' | Sort-Object { [Regex]::Replace($_.Name, '(\d+)', { $args[0].Value.PadLeft(8, '0') }) } | ForEach-Object { $_.Name }"') do (
    set /a count+=1
    echo !count!. %%F
    set "file!count!=%%F"
)

:: Choosing file
set "choice="
set /p "choice=Input file index (number): "
if "!choice!"=="" (
    echo The choice is empty, exiting...
    pause
    goto menu
)

set "selectedFile=!file%choice%!"
if not defined selectedFile (
    echo Invalid choice, exiting...
    pause
    goto menu
)

call :load_user_lists
call :game_switch_status
call :discord_fake_status
call :game_fake_status
call :game_fake_tcp_status
call :game_fake_tcp_alt_status
call :game_fake_tcp_alt2_status
call :game_fake_udp_status
call :ipset_fake_tcp_status
call :ipset_fake_tcp_alt_status
call :ipset_fake_tcp_alt2_status
call :ipset_fake_udp_status
call :general_tcp_status
call :general_tcp_alt_status
call :general_tcp_alt2_status
call :general_udp_status
call :stun_fake_status
call :get_hfs_status "hostfakesplit" "hsf" "ozon.ru" "HostFakeSplitStatus"
call :get_hfs_status "hostfakesplit_alt" "hsfalt" "ya.ru" "HostFakeSplitAltStatus"

call :service_install_from_file "!selectedFile!"

:service_install_end
pause
goto menu

:service_install_file
setlocal EnableDelayedExpansion

if "%~1"=="" (
    echo Missing strategy file name
    for /f %%E in ("1") do endlocal & exit /b %%E
)

call :load_user_lists
call :game_switch_status
call :discord_fake_status
call :game_fake_status
call :game_fake_tcp_status
call :game_fake_tcp_alt_status
call :game_fake_tcp_alt2_status
call :game_fake_udp_status
call :ipset_fake_tcp_status
call :ipset_fake_tcp_alt_status
call :ipset_fake_tcp_alt2_status
call :ipset_fake_udp_status
call :general_tcp_status
call :general_tcp_alt_status
call :general_tcp_alt2_status
call :general_udp_status
call :stun_fake_status
call :get_hfs_status "hostfakesplit" "hsf" "ozon.ru" "HostFakeSplitStatus"
call :get_hfs_status "hostfakesplit_alt" "hsfalt" "ya.ru" "HostFakeSplitAltStatus"

call :service_install_from_file "%~1"
set "install_exit=!errorlevel!"
for /f %%E in ("!install_exit!") do endlocal & exit /b %%E


:service_install_from_file
set "selectedFile=%~1"

if "%selectedFile%"=="" (
    echo Missing selected strategy file
    exit /b 1
)

:: Main
cd /d "%~dp0"
set "BIN_PATH=%~dp0bin\"
set "LISTS_PATH=%~dp0lists\"

set "selectedFilePath=%selectedFile%"
if not exist "%selectedFilePath%" set "selectedFilePath=%~dp0%selectedFile%"

if not exist "%selectedFilePath%" (
    echo Strategy file "%selectedFile%" was not found.
    exit /b 1
)

for %%F in ("%selectedFilePath%") do (
    set "selectedFile=%%~nxF"
)

:: Args that should be followed by value
set "args_with_value=sni host altorder"

:: Parsing args (mergeargs: 2=start param|3=arg with value|1=params args|0=default)
set "args="
set "capture=0"
set "mergeargs=0"
set QUOTE="

for /f "tokens=*" %%a in ('type "%selectedFilePath%"') do (
    set "line=%%a"
    call set "line=%%line:^!=EXCL_MARK%%"
    if defined DiscordFake set "line=!line:%%DiscordFake%%=%DiscordFake%!"
    if defined GameFake set "line=!line:%%GameFake%%=%GameFake%!"
    if defined GameFakeTCP set "line=!line:%%GameFakeTCP%%=%GameFakeTCP%!"
    if defined GameFakeTCPAlt set "line=!line:%%GameFakeTCPAlt%%=%GameFakeTCPAlt%!"
    if defined GameFakeTCPAlt2 set "line=!line:%%GameFakeTCPAlt2%%=%GameFakeTCPAlt2%!"
    if defined GameFakeUDP set "line=!line:%%GameFakeUDP%%=%GameFakeUDP%!"
    if defined IpsetFakeTCP set "line=!line:%%IpsetFakeTCP%%=%IpsetFakeTCP%!"
    if defined IpsetFakeTCPAlt set "line=!line:%%IpsetFakeTCPAlt%%=%IpsetFakeTCPAlt%!"
    if defined IpsetFakeTCPAlt2 set "line=!line:%%IpsetFakeTCPAlt2%%=%IpsetFakeTCPAlt2%!"
    if defined IpsetFakeUDP set "line=!line:%%IpsetFakeUDP%%=%IpsetFakeUDP%!"
    if defined GeneralTCP set "line=!line:%%GeneralTCP%%=%GeneralTCP%!"
    if defined GeneralTCPAlt set "line=!line:%%GeneralTCPAlt%%=%GeneralTCPAlt%!"
    if defined GeneralTCPAlt2 set "line=!line:%%GeneralTCPAlt2%%=%GeneralTCPAlt2%!"
    if defined GeneralUDP set "line=!line:%%GeneralUDP%%=%GeneralUDP%!"
    if defined StunFake set "line=!line:%%StunFake%%=%StunFake%!"
    if defined hsf set "line=!line:%%hsf%%=%hsf%!"
    if defined hsfalt set "line=!line:%%hsfalt%%=%hsfalt%!"

    echo !line! | findstr /i "%BIN%winws.exe" >nul
    if not errorlevel 1 (
        set "capture=1"

        if not defined args (
            set "line=!line:*%BIN%winws.exe"=!"
        )
    )

    if "!capture!"=="1" (
        set "temp_args="
        set "line_has_caret=0"

        for %%i in (!line!) do (
            set "arg=%%i"

            if "!arg!"=="^" (
                set "line_has_caret=1"
            ) else (
                if "!arg:~0,2!" EQU "--" if not !mergeargs!==0 (
                    set "mergeargs=0"
                )

                if "!arg:~0,1!" EQU "!QUOTE!" (
                    set "arg=!arg:~1,-1!"

                    echo !arg! | findstr ":" >nul
                    if !errorlevel!==0 (
                        set "arg=\!QUOTE!!arg!\!QUOTE!"
                    ) else if "!arg:~0,1!"=="@" (
                        set "arg=\!QUOTE!@%~dp0!arg:~1!\!QUOTE!"
                    ) else if "!arg:~0,5!"=="%%BIN%%" (
                        set "arg=\!QUOTE!!BIN_PATH!!arg:~5!\!QUOTE!"
                    ) else if "!arg:~0,7!"=="%%LISTS%%" (
                        set "arg=\!QUOTE!!LISTS_PATH!!arg:~7!\!QUOTE!"
                    ) else (
                        set "arg=\!QUOTE!%~dp0!arg!\!QUOTE!"
                    )
                ) else if "!arg:~0,12!" EQU "%%GameFilter%%" (
                    set "arg=%GameFilter%"
                ) else if "!arg:~0,15!" EQU "%%GameFilterTCP%%" (
                    set "arg=%GameFilterTCP%"
                ) else if "!arg:~0,15!" EQU "%%GameFilterUDP%%" (
                    set "arg=%GameFilterUDP%"
                )

                if !mergeargs!==1 (
                    set "temp_args=!temp_args!,!arg!"
                ) else if !mergeargs!==3 (
                    set "temp_args=!temp_args!=!arg!"
                    set "mergeargs=1"
                ) else (
                    set "temp_args=!temp_args! !arg!"
                )

                if "!arg:~0,2!" EQU "--" (
                    set "mergeargs=2"
                ) else if !mergeargs! GEQ 1 (
                    if !mergeargs!==2 set "mergeargs=1"

                    for %%x in (!args_with_value!) do (
                        if /i "%%x"=="!arg!" (
                            set "mergeargs=3"
                        )
                    )
                )
            )
        )

        if not "!temp_args!"=="" (
            set "args=!args! !temp_args!"
        )

        if "!line_has_caret!"=="0" (
            set "capture=0"
        )
    )
)

:: Creating service with parsed args
call :tcp_enable

set ARGS=%args%
call set "ARGS=%%ARGS:EXCL_MARK=^!%%"
echo Final args: !ARGS!
set SRVCNAME=zapret

net stop %SRVCNAME% >nul 2>&1
sc delete %SRVCNAME% >nul 2>&1
sc create %SRVCNAME% binPath= "\"%BIN_PATH%winws.exe\" !ARGS!" DisplayName= "zapret" start= auto
sc description %SRVCNAME% "Zapret DPI bypass software"
sc start %SRVCNAME%

:: call :autorestart_status
:: if not "!AutorestartHours!"=="disabled" (
::     schtasks /create /tn "ZapretRestart" /tr "cmd.exe /c net stop zapret & net start zapret" /sc HOURLY /mo !AutorestartHours! /ru SYSTEM /f >nul 2>&1
:: )

for %%F in ("!selectedFile!") do (
    set "filename=%%~nF"
)
reg add "HKLM\System\CurrentControlSet\Services\zapret" /v zapret-discord-youtube /t REG_SZ /d "!filename!" /f

exit /b 0


:: CHECK UPDATES =======================
:service_check_updates
chcp 437 > nul
cls

:: Set current version and URLs
set "GITHUB_VERSION_URL=https://raw.githubusercontent.com/shlynas/zapret-discord-youtube/main/.service/version.txt"
set "GITHUB_RELEASE_URL=https://github.com/shlynas/zapret-discord-youtube/releases/tag/"
set "GITHUB_DOWNLOAD_URL=https://github.com/shlynas/zapret-discord-youtube/releases/latest"

:: Get the latest version from GitHub
for /f "delims=" %%A in ('powershell -NoProfile -Command "(Invoke-WebRequest -Uri \"%GITHUB_VERSION_URL%\" -Headers @{\"Cache-Control\"=\"no-cache\"} -UseBasicParsing -TimeoutSec 5).Content.Trim()" 2^>nul') do set "GITHUB_VERSION=%%A"

:: Error handling
if not defined GITHUB_VERSION (
    echo Warning: failed to fetch the latest version. This warning does not affect the operation of zapret
    timeout /T 9
    if "%1"=="soft" exit 
    goto menu
)

:: Version comparison
if "%LOCAL_VERSION%"=="%GITHUB_VERSION%" (
    echo Latest version installed: %LOCAL_VERSION%
    
    if "%1"=="soft" exit 
    pause
    goto menu
) 

echo New version available: %GITHUB_VERSION%
echo Release page: %GITHUB_RELEASE_URL%%GITHUB_VERSION%

echo Opening the download page...
start "" "%GITHUB_DOWNLOAD_URL%"


if "%1"=="soft" exit 
pause
goto menu


:: DIAGNOSTICS =========================
:service_diagnostics
chcp 437 > nul
cls

:: Base Filtering Engine
sc query BFE | findstr /I "RUNNING" > nul
if !errorlevel!==0 (
    call :PrintGreen "Base Filtering Engine check passed"
) else (
    call :PrintRed "[X] Base Filtering Engine is not running. This service is required for zapret to work"
)
echo:

:: Proxy check
set "proxyEnabled=0"
set "proxyServer="

for /f "tokens=2*" %%A in ('reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable 2^>nul ^| findstr /i "ProxyEnable"') do (
    if "%%B"=="0x1" set "proxyEnabled=1"
)

if !proxyEnabled!==1 (
    for /f "tokens=2*" %%A in ('reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyServer 2^>nul ^| findstr /i "ProxyServer"') do (
        set "proxyServer=%%B"
    )
    
    call :PrintYellow "[?] System proxy is enabled: !proxyServer!"
    call :PrintYellow "Make sure it's valid or disable it if you don't use a proxy"
) else (
    call :PrintGreen "Proxy check passed"
)
echo:

:: TCP timestamps check
netsh interface tcp show global | findstr /i "timestamps" | findstr /i "enabled" > nul
if !errorlevel!==0 (
    call :PrintGreen "TCP timestamps check passed"
) else (
    call :PrintYellow "[?] TCP timestamps are disabled. Enabling timestamps..."
    netsh interface tcp set global timestamps=enabled > nul 2>&1
    if !errorlevel!==0 (
        call :PrintGreen "TCP timestamps successfully enabled"
    ) else (
        call :PrintRed "[X] Failed to enable TCP timestamps"
    )
)
echo:

:: AdguardSvc.exe
tasklist /FI "IMAGENAME eq AdguardSvc.exe" | find /I "AdguardSvc.exe" > nul
if !errorlevel!==0 (
    call :PrintRed "[X] Adguard process found. Adguard may cause problems with Discord"
    call :PrintRed "https://github.com/Flowseal/zapret-discord-youtube/issues/417"
) else (
    call :PrintGreen "Adguard check passed"
)
echo:

:: Killer
sc query | findstr /I "Killer" > nul
if !errorlevel!==0 (
    call :PrintRed "[X] Killer services found. Killer conflicts with zapret"
    call :PrintRed "https://github.com/Flowseal/zapret-discord-youtube/issues/2512#issuecomment-2821119513"
) else (
    call :PrintGreen "Killer check passed"
)
echo:

:: Intel Connectivity Network Service
sc query | findstr /I "Intel" | findstr /I "Connectivity" | findstr /I "Network" > nul
if !errorlevel!==0 (
    call :PrintRed "[X] Intel Connectivity Network Service found. It conflicts with zapret"
    call :PrintRed "https://github.com/ValdikSS/GoodbyeDPI/issues/541#issuecomment-2661670982"
) else (
    call :PrintGreen "Intel Connectivity check passed"
)
echo:

:: Check Point
set "checkpointFound=0"
sc query | findstr /I "TracSrvWrapper" > nul
if !errorlevel!==0 (
    set "checkpointFound=1"
)

sc query | findstr /I "EPWD" > nul
if !errorlevel!==0 (
    set "checkpointFound=1"
)

if !checkpointFound!==1 (
    call :PrintRed "[X] Check Point services found. Check Point conflicts with zapret"
    call :PrintRed "Try to uninstall Check Point"
) else (
    call :PrintGreen "Check Point check passed"
)
echo:

:: SmartByte
sc query | findstr /I "SmartByte" > nul
if !errorlevel!==0 (
    call :PrintRed "[X] SmartByte services found. SmartByte conflicts with zapret"
    call :PrintRed "Try to uninstall or disable SmartByte through services.msc"
) else (
    call :PrintGreen "SmartByte check passed"
)
echo:

:: WinDivert64.sys file
set "BIN_PATH=%~dp0bin\"
if not exist "%BIN_PATH%\*.sys" (
    call :PrintRed "WinDivert64.sys file NOT found."
    echo:
)

:: VPN
set "VPN_SERVICES="
sc query | findstr /I "VPN" > nul
if !errorlevel!==0 (
    for /f "tokens=2 delims=:" %%A in ('sc query ^| findstr /I "VPN"') do (
        if not defined VPN_SERVICES (
            set "VPN_SERVICES=!VPN_SERVICES!%%A"
        ) else (
            set "VPN_SERVICES=!VPN_SERVICES!,%%A"
        )
    )
    call :PrintYellow "[?] VPN services found:!VPN_SERVICES!. Some VPNs can conflict with zapret"
    call :PrintYellow "Make sure that all VPNs are disabled"
) else (
    call :PrintGreen "VPN check passed"
)
echo:

:: DNS
set "dohfound=0"
for /f "delims=" %%a in ('powershell -NoProfile -Command "Get-ChildItem -Recurse -Path 'HKLM:System\CurrentControlSet\Services\Dnscache\InterfaceSpecificParameters\' | Get-ItemProperty | Where-Object { $_.DohFlags -gt 0 } | Measure-Object | Select-Object -ExpandProperty Count"') do (
    if %%a gtr 0 (
        set "dohfound=1"
    )
)
if !dohfound!==0 (
    call :PrintYellow "[?] Make sure you have configured secure DNS in a browser with some non-default DNS service provider,"
    call :PrintYellow "If you use Windows 11 you can configure encrypted DNS in the Settings to hide this warning"
) else (
    call :PrintGreen "Secure DNS check passed"
)
echo:

:: Hosts file check
set "hostsFile=%SystemRoot%\System32\drivers\etc\hosts"
if exist "%hostsFile%" (
    set "yt_found=0"
    >nul 2>&1 findstr /I "youtube.com" "%hostsFile%" && set "yt_found=1"
    >nul 2>&1 findstr /I "youtu.be" "%hostsFile%" && set "yt_found=1"
    if !yt_found!==1 (
        call :PrintYellow "[?] Your hosts file contains entries for youtube.com or youtu.be. This may cause problems with YouTube access"
    )
)

:: WinDivert conflict
tasklist /FI "IMAGENAME eq winws.exe" | find /I "winws.exe" > nul
set "winws_running=!errorlevel!"

sc query "WinDivert" | findstr /I "RUNNING STOP_PENDING" > nul
set "windivert_running=!errorlevel!"

if !winws_running! neq 0 if !windivert_running!==0 (
    call :PrintYellow "[?] winws.exe is not running but WinDivert service is active. Attempting to delete WinDivert..."
    
    net stop "WinDivert" >nul 2>&1
    sc delete "WinDivert" >nul 2>&1
    sc query "WinDivert" >nul 2>&1
    if !errorlevel!==0 (
        call :PrintRed "[X] Failed to delete WinDivert. Checking for conflicting services..."
        
        set "conflicting_services=GoodbyeDPI"
        set "found_conflict=0"
        
        for %%s in (!conflicting_services!) do (
            sc query "%%s" >nul 2>&1
            if !errorlevel!==0 (
                call :PrintYellow "[?] Found conflicting service: %%s. Stopping and removing..."
                net stop "%%s" >nul 2>&1
                sc delete "%%s" >nul 2>&1
                if !errorlevel!==0 (
                    call :PrintGreen "Successfully removed service: %%s"
                ) else (
                    call :PrintRed "[X] Failed to remove service: %%s"
                )
                set "found_conflict=1"
            )
        )
        
        if !found_conflict!==0 (
            call :PrintRed "[X] No conflicting services found. Check manually if any other bypass is using WinDivert."
        ) else (
            call :PrintYellow "[?] Attempting to delete WinDivert again..."

            net stop "WinDivert" >nul 2>&1
            sc delete "WinDivert" >nul 2>&1
            sc query "WinDivert" >nul 2>&1
            if !errorlevel! neq 0 (
                call :PrintGreen "WinDivert successfully deleted after removing conflicting services"
            ) else (
                call :PrintRed "[X] WinDivert still cannot be deleted. Check manually if any other bypass is using WinDivert."
            )
        )
    ) else (
        call :PrintGreen "WinDivert successfully removed"
    )
    
    echo:
)

:: Conflicting bypasses
set "conflicting_services=GoodbyeDPI discordfix_zapret winws1 winws2"
set "found_any_conflict=0"
set "found_conflicts="

for %%s in (!conflicting_services!) do (
    sc query "%%s" >nul 2>&1
    if !errorlevel!==0 (
        if "!found_conflicts!"=="" (
            set "found_conflicts=%%s"
        ) else (
            set "found_conflicts=!found_conflicts! %%s"
        )
        set "found_any_conflict=1"
    )
)

if !found_any_conflict!==1 (
    call :PrintRed "[X] Conflicting bypass services found: !found_conflicts!"
    
    set "CHOICE="
    set /p "CHOICE=Do you want to remove these conflicting services? (Y/N) (default: N) "
    if "!CHOICE!"=="" set "CHOICE=N"
    if "!CHOICE!"=="y" set "CHOICE=Y"
    
    if /i "!CHOICE!"=="Y" (
        for %%s in (!found_conflicts!) do (
            call :PrintYellow "Stopping and removing service: %%s"
            net stop "%%s" >nul 2>&1
            sc delete "%%s" >nul 2>&1
            if !errorlevel!==0 (
                call :PrintGreen "Successfully removed service: %%s"
            ) else (
                call :PrintRed "[X] Failed to remove service: %%s"
            )
        )

        net stop "WinDivert" >nul 2>&1
        sc delete "WinDivert" >nul 2>&1
        net stop "WinDivert14" >nul 2>&1
        sc delete "WinDivert14" >nul 2>&1
    )
    
    echo:
)

:: Discord cache clearing
set "CHOICE="
set /p "CHOICE=Do you want to clear the Discord cache? (Y/N) (default: Y)  "
if "!CHOICE!"=="" set "CHOICE=Y"
if "!CHOICE!"=="y" set "CHOICE=Y"

if /i "!CHOICE!"=="Y" (
    tasklist /FI "IMAGENAME eq Discord.exe" | findstr /I "Discord.exe" > nul
    if !errorlevel!==0 (
        echo Discord is running, closing...
        taskkill /IM Discord.exe /F > nul
        if !errorlevel! == 0 (
            call :PrintGreen "Discord was successfully closed"
        ) else (
            call :PrintRed "Unable to close Discord"
        )
    )

    set "discordCacheDir=%appdata%\discord"

    for %%d in ("Cache" "Code Cache" "GPUCache") do (
        set "dirPath=!discordCacheDir!\%%~d"
        if exist "!dirPath!" (
            rd /s /q "!dirPath!"
            if !errorlevel!==0 (
                call :PrintGreen "Successfully deleted !dirPath!"
            ) else (
                call :PrintRed "Failed to delete !dirPath!"
            )
        ) else (
            call :PrintRed "!dirPath! does not exist"
        )
    )
)
echo:

for /f %%A in ('powershell -NoProfile -Command "(Get-Content '%~f0').Count"') do set "total_lines=%%A"
if !total_lines! gtr 1800 (
    call :PrintYellow "[?] Non-executable data block detected at the end of service.bat."
    echo:
)

pause
goto menu


:: GAME SWITCH ========================
:game_switch_status
chcp 437 > nul

set "gameFlagFile=%~dp0utils\game_filter.enabled"

if not exist "%gameFlagFile%" (
    set "GameFilterStatus=disabled"
    set "GameFilter=12"
    set "GameFilterTCP=12"
    set "GameFilterUDP=12"
    exit /b
)

set "GameFilterMode="
for /f "usebackq delims=" %%A in ("%gameFlagFile%") do (
    if not defined GameFilterMode set "GameFilterMode=%%A"
)

if /i "%GameFilterMode%"=="all" (
    set "GameFilterStatus=enabled (TCP and UDP)"
    set "GameFilter=1024-65535"
    set "GameFilterTCP=1024-65535"
    set "GameFilterUDP=1024-65535"
) else if /i "%GameFilterMode%"=="tcp" (
    set "GameFilterStatus=enabled (TCP)"
    set "GameFilter=1024-65535"
    set "GameFilterTCP=1024-65535"
    set "GameFilterUDP=12"
) else (
    set "GameFilterStatus=enabled (UDP)"
    set "GameFilter=1024-65535"
    set "GameFilterTCP=12"
    set "GameFilterUDP=1024-65535"
)
exit /b


:game_switch
chcp 437 > nul
cls

echo Select game filter mode:
echo   0. Disable
echo   1. TCP and UDP
echo   2. TCP only
echo   3. UDP only
echo.
set "GameFilterChoice=0"
set /p "GameFilterChoice=Select option (0-3, default: 0): "
if %GameFilterChoice%=="" set "GameFilterChoice=0"

if "%GameFilterChoice%"=="0" (
    if exist "%gameFlagFile%" (
        del /f /q "%gameFlagFile%"
    ) else (
        goto menu
    )
) else if "%GameFilterChoice%"=="1" (
    echo all>"%gameFlagFile%"
) else if "%GameFilterChoice%"=="2" (
    echo tcp>"%gameFlagFile%"
) else if "%GameFilterChoice%"=="3" (
    echo udp>"%gameFlagFile%"
) else (
    echo Invalid choice, exiting...
    pause
    goto menu
)

call :PrintYellow "Restart the zapret to apply the changes"
pause
goto menu


:: EXTRA MENU ==========================
:extra_menu
cls
call :discord_fake_status
call :game_fake_udp_status
call :game_fake_tcp_status
call :game_fake_tcp_alt_status
call :game_fake_tcp_alt2_status
call :ipset_fake_udp_status
call :ipset_fake_tcp_status
call :ipset_fake_tcp_alt_status
call :ipset_fake_tcp_alt2_status
call :general_udp_status
call :general_tcp_status
call :general_tcp_alt_status
call :general_tcp_alt2_status
call :stun_fake_status
call :get_hfs_status "hostfakesplit" "hsf" "ozon.ru" "HostFakeSplitStatus"
call :get_hfs_status "hostfakesplit_alt" "hsfalt" "ya.ru" "HostFakeSplitAltStatus"

set "extra_choice=null"

echo.
echo   EXTRA SETTINGS
echo   ----------------------------------------
echo.
echo   [^^!] WARNING: This section is for advanced users and specialized setups only.
echo   [^^!] Regular users without technical knowledge may break their internet connection.
echo   [^^!] Default values are always safe to use.
echo.
echo   Groups: ST(general,ALT10,SIMPLE,TLS AUTO) ^| Alt(ALT1-4,6-8,SIMPLE ALT,TLS AUTO ALT)
echo           Alt2(ALT11-12,SIMPLE ALT2,TLS AUTO ALT2-3) ^| HS(ALT3,ALT9)
echo.
echo   ----------------------------------------
echo.
echo   1. Discord Fake            [!DiscordFakeStatus!]
echo   2. Game Fake UDP           [!GameFakeUDPStatus!]
echo   3. IPSet Fake UDP          [!IpsetFakeUDPStatus!]
echo   4. General UDP             [!GeneralUDPStatus!]
echo   5. Stun Fake               [!StunFakeStatus!]
echo.
echo   6. Game Fake TCP           [!GameFakeTCPStatus!]
echo   7. IPSet Fake TCP          [!IpsetFakeTCPStatus!]
echo   8. General TCP             [!GeneralTCPStatus!]
echo.
echo   9. Game Fake TCP Alt       [!GameFakeTCPAltStatus!]
echo   10. IPSet Fake TCP Alt     [!IpsetFakeTCPAltStatus!]
echo   11. General TCP Alt        [!GeneralTCPAltStatus!]
echo.
echo   12. Game Fake TCP Alt2     [!GameFakeTCPAlt2Status!]
echo   13. IPSet Fake TCP Alt2    [!IpsetFakeTCPAlt2Status!]
echo   14. General TCP Alt2       [!GeneralTCPAlt2Status!]
echo.
echo   15. HostFakeSplit (ALT9)   [!HostFakeSplitStatus!]
echo   16. HostFakeSplit (ALT3)   [!HostFakeSplitAltStatus!]
echo   17. Factory Reset
echo.
echo   ----------------------------------------
echo   0. Back
echo.

set /p extra_choice=   Select option (0-17): 

if "%extra_choice%"=="1" goto discord_fake_switch
if "%extra_choice%"=="2" goto game_fake_udp_switch
if "%extra_choice%"=="3" goto ipset_fake_udp_switch
if "%extra_choice%"=="4" goto general_udp_switch
if "%extra_choice%"=="5" goto stun_fake_switch
if "%extra_choice%"=="6" goto game_fake_tcp_switch
if "%extra_choice%"=="7" goto ipset_fake_tcp_switch
if "%extra_choice%"=="8" goto general_tcp_switch
if "%extra_choice%"=="9" goto game_fake_tcp_alt_switch
if "%extra_choice%"=="10" goto ipset_fake_tcp_alt_switch
if "%extra_choice%"=="11" goto general_tcp_alt_switch
if "%extra_choice%"=="12" goto game_fake_tcp_alt2_switch
if "%extra_choice%"=="13" goto ipset_fake_tcp_alt2_switch
if "%extra_choice%"=="14" goto general_tcp_alt2_switch
if "%extra_choice%"=="15" goto hostfakesplit_switch
if "%extra_choice%"=="16" goto hostfakesplit_alt_switch
if "%extra_choice%"=="17" goto factory_reset
if "%extra_choice%"=="0" goto menu
goto extra_menu


:: AUTORESTART SWITCH ==================
:autorestart_status
chcp 437 > nul

set "autorestartFlag=%~dp0utils\autorestart.enabled"

if not exist "%autorestartFlag%" (
    set "AutorestartStatus=disabled"
    set "AutorestartHours=disabled"
    exit /b
)

set "AutorestartHours="
for /f "usebackq delims=" %%A in ("%autorestartFlag%") do (
    if not defined AutorestartHours set "AutorestartHours=%%A"
)

set "AutorestartStatus=every !AutorestartHours! hours"
exit /b


:autorestart_switch
chcp 437 > nul
cls

echo Select Autorestart Timer mode:
echo   0. Disable
echo   [1-24]. Enter restart interval in hours
echo.
set "AutorestartChoice=0"
set /p "AutorestartChoice=Select option (0-24, default: 0): "
if "%AutorestartChoice%"=="" set "AutorestartChoice=0"

if "%AutorestartChoice%"=="0" (
    if exist "%autorestartFlag%" (
        del /f /q "%autorestartFlag%"
    )
    schtasks /delete /tn "ZapretRestart" /f >nul 2>&1
) else (
    echo !AutorestartChoice!>"%autorestartFlag%"
    call :autorestart_status
    sc query "zapret" >nul 2>&1
    if !errorlevel!==0 (
        schtasks /create /tn "ZapretRestart" /tr "cmd.exe /c net stop zapret & net start zapret" /sc HOURLY /mo !AutorestartChoice! /ru SYSTEM /f >nul 2>&1
    )
)

call :PrintYellow "Autorestart timer applied"
pause
goto menu


:: CHECK UPDATES SWITCH =================
:check_updates_switch_status
chcp 437 > nul

set "checkUpdatesFlag=%~dp0utils\check_updates.enabled"

if exist "%checkUpdatesFlag%" (
    set "CheckUpdatesStatus=enabled"
) else (
    set "CheckUpdatesStatus=disabled"
)
exit /b


:check_updates_switch
chcp 437 > nul
cls

if not exist "%checkUpdatesFlag%" (
    echo Enabling check updates...
    echo ENABLED > "%checkUpdatesFlag%"
) else (
    echo Disabling check updates...
    del /f /q "%checkUpdatesFlag%"
)

pause
goto menu


:: IPSET SWITCH =======================
:ipset_switch_status
chcp 437 > nul

set "listFile=%~dp0lists\ipset-all.txt"
for /f %%i in ('type "%listFile%" 2^>nul ^| find /c /v ""') do set "lineCount=%%i"

if !lineCount!==0 (
    set "IPsetStatus=any"
) else (
    findstr /R "^203\.0\.113\.113/32$" "%listFile%" >nul
    if !errorlevel!==0 (
        set "IPsetStatus=none"
    ) else (
        set "IPsetStatus=loaded"
    )
)
exit /b


:ipset_switch
chcp 437 > nul
cls

set "listFile=%~dp0lists\ipset-all.txt"
set "backupFile=%listFile%.backup"

if "%IPsetStatus%"=="loaded" (
    echo Switching to none mode...
    
    if not exist "%backupFile%" (
        ren "%listFile%" "ipset-all.txt.backup"
    ) else (
        del /f /q "%backupFile%"
        ren "%listFile%" "ipset-all.txt.backup"
    )
    
    >"%listFile%" (
        echo 203.0.113.113/32
    )
    
) else if "%IPsetStatus%"=="none" (
    echo Switching to any mode...
    
    >"%listFile%" (
        rem Creating empty file
    )
    
) else if "%IPsetStatus%"=="any" (
    echo Switching to loaded mode...
    
    if exist "%backupFile%" (
        del /f /q "%listFile%"
        ren "%backupFile%" "ipset-all.txt"
    ) else (
        echo Error: no backup to restore. Update list from service menu first
        pause
        goto menu
    )
    
)

pause
goto menu


:: IPSET UPDATE =======================
:ipset_update
chcp 437 > nul
cls

set "listFile=%~dp0lists\ipset-all.txt"
set "url=https://raw.githubusercontent.com/shlynas/zapret-discord-youtube/refs/heads/main/.service/ipset-service.txt"

echo Updating ipset-all...

if exist "%SystemRoot%\System32\curl.exe" (
    curl -L -o "%listFile%" "%url%"
) else (
    powershell -NoProfile -Command ^
        "$url = '%url%';" ^
        "$out = '%listFile%';" ^
        "$dir = Split-Path -Parent $out;" ^
        "if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null };" ^
        "$res = Invoke-WebRequest -Uri $url -TimeoutSec 10 -UseBasicParsing;" ^
        "if ($res.StatusCode -eq 200) { $res.Content | Out-File -FilePath $out -Encoding UTF8 } else { exit 1 }"
)

echo Finished

pause
goto menu


:: HOSTS UPDATE =======================
:hosts_update
chcp 437 > nul
cls

set "hostsFile=%SystemRoot%\System32\drivers\etc\hosts"
set "hostsUrl=https://raw.githubusercontent.com/shlynas/zapret-discord-youtube/refs/heads/main/.service/hosts"
set "tempFile=%TEMP%\zapret_hosts.txt"
set "needsUpdate=0"

echo Checking hosts file...

if exist "%SystemRoot%\System32\curl.exe" (
    curl -L -s -o "%tempFile%" "%hostsUrl%"
) else (
    powershell -NoProfile -Command ^
        "$url = '%hostsUrl%';" ^
        "$out = '%tempFile%';" ^
        "$res = Invoke-WebRequest -Uri $url -TimeoutSec 10 -UseBasicParsing;" ^
        "if ($res.StatusCode -eq 200) { $res.Content | Out-File -FilePath $out -Encoding UTF8 } else { exit 1 }"
)

if not exist "%tempFile%" (
    call :PrintRed "Failed to download hosts file from repository"
    call :PrintYellow "Copy hosts file manually from %hostsUrl%"
    pause
    goto menu
)

set "firstLine="
set "lastLine="
for /f "usebackq delims=" %%a in ("%tempFile%") do (
    if not defined firstLine (
        set "firstLine=%%a"
    )
    set "lastLine=%%a"
)

findstr /C:"!firstLine!" "%hostsFile%" >nul 2>&1
if !errorlevel! neq 0 (
    echo First line from repository not found in hosts file
    set "needsUpdate=1"
)

findstr /C:"!lastLine!" "%hostsFile%" >nul 2>&1
if !errorlevel! neq 0 (
    echo Last line from repository not found in hosts file
    set "needsUpdate=1"
)

if "%needsUpdate%"=="1" (
    echo:
    call :PrintYellow "Hosts file needs to be updated"
    call :PrintYellow "Please manually copy the content from the downloaded file to your hosts file"
    
    start notepad "%tempFile%"
    explorer /select,"%hostsFile%"
) else (
    call :PrintGreen "Hosts file is up to date"
    if exist "%tempFile%" del /f /q "%tempFile%"
)

echo:
pause
goto menu


:: RUN TESTS =============================
:run_tests
chcp 437 >nul
cls

:: Require PowerShell 3.0+
powershell -NoProfile -Command "if ($PSVersionTable -and $PSVersionTable.PSVersion -and $PSVersionTable.PSVersion.Major -ge 3) { exit 0 } else { exit 1 }" >nul 2>&1
if %errorLevel% neq 0 (
    echo PowerShell 3.0 or newer is required.
    echo Please upgrade PowerShell and rerun this script.
    echo.
    pause
    goto menu
)

echo Starting configuration tests in PowerShell window...
echo.
start "" powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0utils\test zapret.ps1"
pause
goto menu


:: CUSTOM FAKE ==================

:get_fake_status
chcp 437 > nul
set "flagFile=%~dp0utils\custom_fakes\%~1.enabled"
if not exist "%flagFile%" (
    set "%~2=%~3"
    call :get_clean_name "%~3" "%~2Status"
    exit /b
)
set "localMode="
for /f "usebackq delims=" %%A in ("%flagFile%") do (
    if not defined localMode set "localMode=%%A"
)
if /i "%localMode%"=="alt" (
    set "%~2=%~4"
) else if /i "%localMode%"=="backup" (
    set "%~2=%~5"
) else if /i "%localMode%"=="nvidia" (
    set "%~2=%~3"
) else if "%localMode:~-4%"==".bin" (
    set "%~2=%localMode%"
) else (
    set "%~2=%~3"
)
setlocal EnableDelayedExpansion
set "resolved_val=!%~2!"
endlocal & call :get_clean_name "%resolved_val%" "%~2Status"
exit /b


:fake_switch
chcp 437 > nul
cls

echo Select %~1 payload:

set "count=0"
set "known_files=,"

:: Adding default bins
for %%F in ("%~3" "%~4" "%~5" "%~6") do (
    if not "%%~F"=="" (
        set "file!count!=%%~nxF"
        call :get_clean_name "%%~nxF" "cleanName"
        if "!count!"=="0" (
            echo   !count!. !cleanName! ^(%%~nxF^) - default
        ) else (
            echo   !count!. !cleanName! ^(%%~nxF^)
        )
        set "known_files=!known_files!%%~nxF,"
        set /a count+=1
    )
)

:: Getting prefix
set "prefix="
if not "%~4"=="" (
    echo %~4 | findstr /i "quic_initial" > nul
    if !errorlevel!==0 set "prefix=quic_initial_"
    echo %~4 | findstr /i "tls_clienthello" > nul
    if !errorlevel!==0 set "prefix=tls_clienthello_"
)

:: Adding user bins
if defined prefix (
    for %%F in ("%~dp0bin\!prefix!*.bin") do (
        set "nxF=%%~nxF"
        if "!known_files:,%%~nxF,=!"=="!known_files!" (
            set "file!count!=!nxF!"
            call :get_clean_name "!nxF!" "cleanName"
            echo   !count!. !cleanName! ^(!nxF!^)
            set "known_files=!known_files!!nxF!,"
            set /a count+=1
        )
    )
)
echo.

set /a max_choice=count-1
set "choice=0"
set /p "choice=Select option (0-!max_choice!, default: 0): "
if "!choice!"=="" set "choice=0"

set "selectedFile=!file%choice%!"
set "flagFile=%~dp0utils\custom_fakes\%~2.enabled"

if "!choice!"=="0" (
    if exist "!flagFile!" del /f /q "!flagFile!"
) else if defined selectedFile (
    echo !selectedFile!>"!flagFile!"
) else (
    echo Invalid choice, exiting...
    pause
    goto menu
)

call :PrintYellow "Restart the zapret to apply the changes"
pause
goto menu


:get_clean_name
setlocal EnableDelayedExpansion
set "name=%~1"
if "%name%"=="" (
    endlocal & set "%~2=none"
    exit /b
)

:: Removing known prefixes and extension
set "name=!name:tls_clienthello_=!"
set "name=!name:quic_initial_=!"
set "name=!name:.bin=!"
set "name=!name:_= !"

:: Getting 2nd level domain (penultimate word)
set "domain="
set "prev="
for %%A in (!name!) do (
    if defined prev set "domain=!prev!"
    set "prev=%%A"
)
if not defined domain set "domain=!prev!"

:: Capitalizing the first letter
set "first=!domain:~0,1!"
for %%C in (A B C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if /i "!first!"=="%%C" set "first=%%C"
)
set "domain=!first!!domain:~1!"

endlocal & set "%~2=%domain%"
exit /b


:game_fake_status
call :get_fake_status "game_fake" "GameFake" "quic_initial_dbankcloud_ru.bin" "quic_initial_www_google_com.bin" "" ""
exit /b

:game_fake_switch
call :fake_switch "Game Fake" "game_fake" "quic_initial_dbankcloud_ru.bin" "quic_initial_www_google_com.bin" "" ""
exit /b

:discord_fake_status
call :get_fake_status "discord_fake" "DiscordFake" "quic_initial_dbankcloud_ru.bin" "quic_initial_www_google_com.bin" "" ""
exit /b

:discord_fake_switch
call :fake_switch "Discord Fake" "discord_fake" "quic_initial_dbankcloud_ru.bin" "quic_initial_www_google_com.bin" "" ""
exit /b

:game_fake_udp_status
call :get_fake_status "game_fake_udp" "GameFakeUDP" "quic_initial_dbankcloud_ru.bin" "quic_initial_www_google_com.bin" "" ""
exit /b

:game_fake_udp_switch
call :fake_switch "Game Fake UDP" "game_fake_udp" "quic_initial_dbankcloud_ru.bin" "quic_initial_www_google_com.bin" "" ""
exit /b

:game_fake_tcp_status
call :get_fake_status "game_fake_tcp" "GameFakeTCP" "tls_clienthello_4pda_to.bin" "tls_clienthello_www_google_com.bin" "tls_clienthello_max_ru.bin" ""
exit /b

:game_fake_tcp_switch
call :fake_switch "Game Fake TCP" "game_fake_tcp" "tls_clienthello_4pda_to.bin" "tls_clienthello_www_google_com.bin" "tls_clienthello_max_ru.bin" ""
exit /b

:game_fake_tcp_alt_status
call :get_fake_status "game_fake_tcp_alt" "GameFakeTCPAlt" "tls_clienthello_www_google_com.bin" "tls_clienthello_max_ru.bin" "" "tls_clienthello_4pda_to.bin"
exit /b

:game_fake_tcp_alt_switch
call :fake_switch "Game Fake TCP Alt" "game_fake_tcp_alt" "tls_clienthello_www_google_com.bin" "tls_clienthello_max_ru.bin" "" "tls_clienthello_4pda_to.bin"
exit /b

:game_fake_tcp_alt2_status
call :get_fake_status "game_fake_tcp_alt2" "GameFakeTCPAlt2" "tls_clienthello_max_ru.bin" "" "tls_clienthello_4pda_to.bin" "tls_clienthello_www_google_com.bin"
exit /b

:game_fake_tcp_alt2_switch
call :fake_switch "Game Fake TCP Alt2" "game_fake_tcp_alt2" "tls_clienthello_max_ru.bin" "" "tls_clienthello_4pda_to.bin" "tls_clienthello_www_google_com.bin"
exit /b

:ipset_fake_tcp_status
call :get_fake_status "ipset_fake_tcp" "IpsetFakeTCP" "tls_clienthello_4pda_to.bin" "tls_clienthello_www_google_com.bin" "tls_clienthello_max_ru.bin" ""
exit /b

:ipset_fake_tcp_switch
call :fake_switch "IPSet Fake TCP" "ipset_fake_tcp" "tls_clienthello_4pda_to.bin" "tls_clienthello_www_google_com.bin" "tls_clienthello_max_ru.bin" ""
exit /b

:ipset_fake_tcp_alt_status
call :get_fake_status "ipset_fake_tcp_alt" "IpsetFakeTCPAlt" "tls_clienthello_www_google_com.bin" "tls_clienthello_max_ru.bin" "" "tls_clienthello_4pda_to.bin"
exit /b

:ipset_fake_tcp_alt_switch
call :fake_switch "IPSet Fake TCP Alt" "ipset_fake_tcp_alt" "tls_clienthello_www_google_com.bin" "tls_clienthello_max_ru.bin" "" "tls_clienthello_4pda_to.bin"
exit /b

:ipset_fake_tcp_alt2_status
call :get_fake_status "ipset_fake_tcp_alt2" "IpsetFakeTCPAlt2" "tls_clienthello_max_ru.bin" "" "tls_clienthello_4pda_to.bin" "tls_clienthello_www_google_com.bin"
exit /b

:ipset_fake_tcp_alt2_switch
call :fake_switch "IPSet Fake TCP Alt2" "ipset_fake_tcp_alt2" "tls_clienthello_max_ru.bin" "" "tls_clienthello_4pda_to.bin" "tls_clienthello_www_google_com.bin"
exit /b

:ipset_fake_udp_status
call :get_fake_status "ipset_fake_udp" "IpsetFakeUDP" "quic_initial_www_google_com.bin" "quic_initial_dbankcloud_ru.bin" "" ""
exit /b

:ipset_fake_udp_switch
call :fake_switch "IPSet Fake UDP" "ipset_fake_udp" "quic_initial_www_google_com.bin" "quic_initial_dbankcloud_ru.bin" "" ""
exit /b

:general_tcp_status
call :get_fake_status "general_tcp" "GeneralTCP" "tls_clienthello_4pda_to.bin" "tls_clienthello_www_google_com.bin" "tls_clienthello_max_ru.bin" ""
exit /b

:general_tcp_switch
call :fake_switch "General TCP" "general_tcp" "tls_clienthello_4pda_to.bin" "tls_clienthello_www_google_com.bin" "tls_clienthello_max_ru.bin" ""
exit /b

:general_tcp_alt_status
call :get_fake_status "general_tcp_alt" "GeneralTCPAlt" "tls_clienthello_www_google_com.bin" "tls_clienthello_max_ru.bin" "" "tls_clienthello_4pda_to.bin"
exit /b

:general_tcp_alt_switch
call :fake_switch "General TCP Alt" "general_tcp_alt" "tls_clienthello_www_google_com.bin" "tls_clienthello_max_ru.bin" "" "tls_clienthello_4pda_to.bin"
exit /b

:general_tcp_alt2_status
call :get_fake_status "general_tcp_alt2" "GeneralTCPAlt2" "tls_clienthello_max_ru.bin" "" "tls_clienthello_4pda_to.bin" "tls_clienthello_www_google_com.bin"
exit /b

:general_tcp_alt2_switch
call :fake_switch "General TCP Alt2" "general_tcp_alt2" "tls_clienthello_max_ru.bin" "" "tls_clienthello_4pda_to.bin" "tls_clienthello_www_google_com.bin"
exit /b

:general_udp_status
call :get_fake_status "general_udp" "GeneralUDP" "quic_initial_www_google_com.bin" "quic_initial_dbankcloud_ru.bin" "" ""
exit /b

:general_udp_switch
call :fake_switch "General UDP" "general_udp" "quic_initial_www_google_com.bin" "quic_initial_dbankcloud_ru.bin" "" ""
exit /b

:stun_fake_status
call :get_fake_status "stun_fake" "StunFake" "stun.bin" "" "tls_clienthello_www_google_com.bin" "tls_clienthello_max_ru.bin"
exit /b

:stun_fake_switch
call :fake_switch "Stun Fake" "stun_fake" "stun.bin" "" "tls_clienthello_www_google_com.bin" "tls_clienthello_max_ru.bin"
exit /b


:: Utility functions

:PrintGreen
powershell -NoProfile -Command "Write-Host \"%~1\" -ForegroundColor Green"
exit /b

:PrintRed
powershell -NoProfile -Command "Write-Host \"%~1\" -ForegroundColor Red"
exit /b

:PrintYellow
powershell -NoProfile -Command "Write-Host \"%~1\" -ForegroundColor Yellow"
exit /b

:check_command
where %1 >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] %1 not found in PATH
    echo Fix your PATH variable with instructions here https://github.com/Flowseal/zapret-discord-youtube/issues/7490
    pause
    exit /b 1
)
exit /b 0

:check_extracted
set "extracted=1"

if not exist "%~dp0bin\" set "extracted=0"

if "%extracted%"=="0" (
    echo Zapret must be extracted from archive first or bin folder not found for some reason
    pause
    exit
)
exit /b 0

:factory_reset
chcp 437 > nul
cls
echo Resetting fake configurations...

:: Reset Extra Settings
for %%F in (
    "discord_fake"
    "game_fake"
    "game_fake_udp"
    "game_fake_tcp"
    "game_fake_tcp_alt"
    "game_fake_tcp_alt2"
    "ipset_fake_udp"
    "ipset_fake_tcp"
    "ipset_fake_tcp_alt"
    "ipset_fake_tcp_alt2"
    "general_udp"
    "general_tcp"
    "general_tcp_alt"
    "general_tcp_alt2"
    "stun_fake"
    "hostfakesplit"
    "hostfakesplit_alt"
) do (
    if exist "%~dp0utils\custom_fakes\%%~F.enabled" (
        del /f /q "%~dp0utils\custom_fakes\%%~F.enabled"
    )
)

call :PrintYellow "Extra settings have been successfully reset to defaults."
call :PrintYellow "System settings (Game Filter, Auto-Update, etc.) were NOT modified."
call :PrintYellow "Please restart the zapret service to apply the changes."
pause
goto extra_menu

:get_hfs_status
chcp 437 > nul
set "flagFile=%~dp0utils\custom_fakes\%~1.enabled"
if not exist "%flagFile%" (
    set "%~4=%~3"
    set "%~2=%~3"
    exit /b
)
set "mode="
for /f "usebackq delims=" %%A in ("%flagFile%") do (
    if not defined mode set "mode=%%A"
)
if not "%mode%"=="" (
    set "%~4=%mode%"
    set "%~2=%mode%"
) else (
    set "%~4=%~3"
    set "%~2=%~3"
)
exit /b


:hfs_switch
chcp 437 > nul
cls
set "current_val=!%~2!"
echo Select %~1 mode:
echo   1. Keep current (!current_val!)
echo   2. Set custom host
echo   3. Restore default (%~3)
echo.
set "choice="
set /p "choice=Select option (1-3): "
if "%choice%"=="1" goto menu
set "flagFile=%~dp0utils\custom_fakes\%~4.enabled"
if "%choice%"=="3" (
    if exist "%flagFile%" del /f /q "%flagFile%"
    call :PrintYellow "Default host (%~3) restored"
    pause
    goto menu
)
if "%choice%"=="2" (
    echo.
    set "hfsInput="
    set /p "hfsInput=Enter custom host (e.g. google.com): "
    if not "!hfsInput!"=="" (
        echo !hfsInput!>"%flagFile%"
    )
)
call :PrintYellow "Restart the zapret to apply the changes"
pause
goto menu


:hostfakesplit_switch
call :hfs_switch "HostFakeSplit (ALT9)" "hsf" "ozon.ru" "hostfakesplit"
goto menu


:hostfakesplit_alt_switch
call :hfs_switch "HostFakeSplit (ALT3)" "hsfalt" "ya.ru" "hostfakesplit_alt"
goto menu

:: rkn sucks
:verify_eof
cls
echo   why, go check the last lines of service.bat
pause
goto menu

:: $c = Get-Content 'service.bat'; [IO.File]::WriteAllBytes('lol.jpg', [Convert]::FromBase64String(($c[([array]::LastIndexOf($c, 'exit /b') + 1)..($c.Length - 1)] -join '')))
exit /b

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
WxwkyUAVpmaNMppq6TkdSx1JLQFgApNSNAjRQALKaQECApMIoTBqhgAJqTSPzKnP1vlRtauyVQ5ZAAAY
AIlPZel876Ln0yEudKJEdTS2BABK7ii3FQhOJY6AZJRCY4qpYxNDzHp/mO8cff0ef6fP7/2Xy/6Zw9mz
kwZePq3drS3JSMuPHSqizNn18wtbYwpzce3qXOj8i+t/FPT48ebFl9Xh9j9M+J/YvH6toDh1NfPgMHX5
PXmuZjzYdNzZ1trNkatSoqeV1eXeeXqczp43PC73Due+riaJHqggppwNMEKxiMmJo2JpuXNXePIrTUpN
EqB5rTITTspprVTRSFA01dS6BCVIKgcgiqlhKISIQMTACmwUqXFAQAEuSvzPFR9b5Rsa+yU05QAEAwQR
aT2/e4nbx0sDOwBHUW1bTVgoKmsncsQgYGjB5AOBshVNDTQ/kv1r5D148558Ps87+v8Axv6t5vX2c+DL
w9efJqwdG+blz03759zXSy87NZuYufps9LTwaqanxz6J4D0+KLy4/T5N36b8x9/5u/sAXk9Bg2daXD1+
R1152LNgrc2tbYwQF0DW08vqcpyz9Pm9PHRcTt8TWO/FTnabLUDpMQyUUDEDhMJKTajGpUktiJWS5oae
a0ANCUwLqWrAUpMQCAmo0FSIblggRS0IBaciUJrQmNqoAIJc0iWfmmMuL63yzZ19iRktaBAmkpMHLD3X
Z5HZz0pMzpA1bmpaqGUJylDgGACpoeRUXAwigYqAAYvjH2j41244tUn1efq+n8Z6Pn29Xi0+Zw9XSzeV
ybz7N+PM69zp4tfO+hqb/mI6m95b2VaV9Dsc+nzPxn1/5B6fFmrT3e/l2fbeA+h8Ontk58frrW2MBr9j
kdjN5+vsa+7u7GvsZsg6aci5XV5N57HT5nUzuON2eNc96WpsaajhpSRakwKThMBsIpiGmQDUMG0gcqY8
7AEANKaIyOLlYhKJFoTAAAFaJKJcOXNgqkQwBBTTloQNqgGBFwQAfmzFlw/W+Vexr7MACoaRDUUBsnJl
7/scjrZ6WgzticFgoDRscNy5ptADQxPIqaGBFNMoYSxi+L/avkfbjyNbLr+rz5/XeM+gc+3bybWbye/Q
0fTYTwvP93gufTcv0L5+nyps9ROJudHKuln2NaXkfJvtHyjv5POVjXs+btfW/kv3Dz991qvJ6HrbWqa/
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

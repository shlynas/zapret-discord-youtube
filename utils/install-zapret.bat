@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 > nul

:: init
set "mode=easy"
set "makeTemplate=0"
set "installCompleted=0"
set "serviceWasRunning=0"
set "serviceStoppedByInstaller=0"

:: PARSE ARGS ================================
:parse_args
if "%~1"=="" goto args_done
if /I "%~1"=="easy" (set "mode=easy" & shift & goto parse_args)
if /I "%~1"=="auto" (set "mode=auto" & shift & goto parse_args)
if /I "%~1"=="--make-template" (set "makeTemplate=1" & shift & goto parse_args)
if /I "%~1"=="-MakeTemplate" (set "makeTemplate=1" & shift & goto parse_args)
if /I "%~1"=="--help" (call :show_help & exit /b 0)
if /I "%~1"=="-Help" (call :show_help & exit /b 0)
if /I "%~1"=="-Mode" (shift & if /I "%~1"=="auto" set "mode=auto" & if /I "%~1"=="easy" set "mode=easy" & shift & goto parse_args)
if /I "%~1"=="--mode" (shift & if /I "%~1"=="auto" set "mode=auto" & if /I "%~1"=="easy" set "mode=easy" & shift & goto parse_args)
echo Error: Unknown argument '%~1'. Run with --help for usage.
exit /b 1

:args_done
set "utilsDir=%~dp0"
pushd "%utilsDir%.." && set "rootDir=%CD%\" & popd
set "listsDir=%rootDir%lists\"
set "serviceBat=%rootDir%service.bat"
set "answersPath=%rootDir%answers.txt"

if "%makeTemplate%"=="1" (call :write_answers_template & exit /b %errorlevel%)

if not exist "%serviceBat%" (set "failureMessage=service.bat not found." & goto fail)

call :read_answers
call :load_strategies
if !strategy_count! EQU 0 (set "failureMessage=No strategy files found (general*.bat)." & goto fail)

:: CONFIGURE ================================
if /I "%mode%"=="auto" (call :configure_auto) else (call :configure_easy)

:: STOP SERVICE ================================
call :stop_zapret_service_if_needed
if errorlevel 1 (set "failureMessage=Failed to stop service 'zapret'." & goto fail)

:: APPLY SETTINGS ================================
if /I "%settings_update_ipset_list%"=="yes" if /I "%settings_ipset_mode%"=="loaded" (
    call :update_ipset_list
    del /q "%listsDir%ipset-all.txt.backup" >nul 2>&1
)
call :set_ipset_mode "%settings_ipset_mode%"
if errorlevel 1 (set "failureMessage=Failed to set ipset mode." & goto fail)
call :set_game_filter_mode "%settings_gamefilter%"
if errorlevel 1 (set "failureMessage=Failed to set game filter mode." & goto fail)
call :set_fake_mode "%settings_discord_fake%" "discord_fake"
if errorlevel 1 (set "failureMessage=Failed to set discord fake mode." & goto fail)
call :set_fake_mode "%settings_game_fake_udp%" "game_fake_udp"
if errorlevel 1 (set "failureMessage=Failed to set game fake UDP mode." & goto fail)
call :set_fake_mode "%settings_ipset_fake_udp%" "ipset_fake_udp"
if errorlevel 1 (set "failureMessage=Failed to set ipset fake UDP mode." & goto fail)
call :set_fake_mode "%settings_general_udp%" "general_udp"
if errorlevel 1 (set "failureMessage=Failed to set general UDP mode." & goto fail)
call :set_fake_mode "%settings_stun_fake%" "stun_fake"
if errorlevel 1 (set "failureMessage=Failed to set stun fake mode." & goto fail)
call :set_fake_mode "%settings_game_fake_tcp%" "game_fake_tcp"
if errorlevel 1 (set "failureMessage=Failed to set game fake TCP mode." & goto fail)
call :set_fake_mode "%settings_ipset_fake_tcp%" "ipset_fake_tcp"
if errorlevel 1 (set "failureMessage=Failed to set ipset fake TCP mode." & goto fail)
call :set_fake_mode "%settings_general_tcp%" "general_tcp"
if errorlevel 1 (set "failureMessage=Failed to set general TCP mode." & goto fail)
call :set_fake_mode "%settings_game_fake_tcp_alt%" "game_fake_tcp_alt"
if errorlevel 1 (set "failureMessage=Failed to set game fake TCP Alt mode." & goto fail)
call :set_fake_mode "%settings_ipset_fake_tcp_alt%" "ipset_fake_tcp_alt"
if errorlevel 1 (set "failureMessage=Failed to set ipset fake TCP Alt mode." & goto fail)
call :set_fake_mode "%settings_general_tcp_alt%" "general_tcp_alt"
if errorlevel 1 (set "failureMessage=Failed to set general TCP Alt mode." & goto fail)
call :set_fake_mode "%settings_game_fake_tcp_alt2%" "game_fake_tcp_alt2"
if errorlevel 1 (set "failureMessage=Failed to set game fake TCP Alt2 mode." & goto fail)
call :set_fake_mode "%settings_ipset_fake_tcp_alt2%" "ipset_fake_tcp_alt2"
if errorlevel 1 (set "failureMessage=Failed to set ipset fake TCP Alt2 mode." & goto fail)
call :set_fake_mode "%settings_general_tcp_alt2%" "general_tcp_alt2"
if errorlevel 1 (set "failureMessage=Failed to set general TCP Alt2 mode." & goto fail)
call :set_hfs_mode "%settings_hostfakesplit%" "hostfakesplit" "ozon.ru"
if errorlevel 1 (set "failureMessage=Failed to set hostfakesplit." & goto fail)
call :set_hfs_mode "%settings_hostfakesplit_alt%" "hostfakesplit_alt" "ya.ru"
if errorlevel 1 (set "failureMessage=Failed to set hostfakesplit alt." & goto fail)
:: call :set_autorestart_mode "%settings_autorestart%"
:: if errorlevel 1 (set "failureMessage=Failed to set autorestart mode." & goto fail)
call :set_auto_updates_mode "%settings_auto_updates%"
if errorlevel 1 (set "failureMessage=Failed to set auto updates mode." & goto fail)
call :apply_custom_user_list
if errorlevel 1 (set "failureMessage=Failed to apply custom user list." & goto fail)
call :apply_exclude_user_list
if errorlevel 1 (set "failureMessage=Failed to apply exclude user list." & goto fail)
call :print_install_summary

:: SELECT STRATEGY ================================
set "selectedStrategy="
if /I "%mode%"=="auto" (
    call :select_strategy_auto
) else (
    if /I "%settings_strategy_select_mode%"=="auto" (call :select_strategy_auto) else (set "selectedStrategy=%settings_strategy_file%")
)
if errorlevel 1 goto fail
if not defined selectedStrategy (set "failureMessage=Unable to get selected strategy." & goto fail)

:: INSTALL ================================
call :resolve_strategy "%selectedStrategy%"
if not defined resolvedStrategy (set "failureMessage=Strategy file '%selectedStrategy%' not found." & goto fail)
echo Installing strategy: %resolvedStrategy%
call "%serviceBat%" install_file "%resolvedStrategy%"
if errorlevel 1 (set "failureMessage=service.bat install_file failed." & goto fail)
set "installCompleted=1"
echo Installation completed successfully.
exit /b 0

:: READ ANSWERS ================================
:read_answers
set "ans_ipset_mode=" & set "ans_gamefilter="
set "ans_discord_fake=" & set "ans_game_fake_udp=" & set "ans_ipset_fake_udp=" & set "ans_general_udp=" & set "ans_stun_fake="
set "ans_game_fake_tcp=" & set "ans_ipset_fake_tcp=" & set "ans_general_tcp="
set "ans_game_fake_tcp_alt=" & set "ans_ipset_fake_tcp_alt=" & set "ans_general_tcp_alt="
set "ans_game_fake_tcp_alt2=" & set "ans_ipset_fake_tcp_alt2=" & set "ans_general_tcp_alt2="
set "ans_hostfakesplit=" & set "ans_hostfakesplit_alt="
set "ans_auto_updates=" & set "ans_update_ipset-list=" & set "ans_strategy_select_mode="
set "ans_strategy_file=" & set "ans_custom_user_list=" & set "ans_exists_custom_user_list=0"
set "ans_exclude_user_list="
if not exist "%answersPath%" exit /b 0
for /f "usebackq tokens=1,* delims==" %%A in ("%answersPath%") do (
    set "answerKey=%%A" & set "answerValue=%%B"
    if not "!answerKey!"=="" if not "!answerKey:~0,1!"=="#" if not "!answerKey:~0,1!"==";" (
        if /I "!answerKey!"=="ipset_mode" set "ans_ipset_mode=!answerValue!"
        if /I "!answerKey!"=="gamefilter" set "ans_gamefilter=!answerValue!"
        if /I "!answerKey!"=="discord_fake" set "ans_discord_fake=!answerValue!"
        if /I "!answerKey!"=="game_fake_udp" set "ans_game_fake_udp=!answerValue!"
        if /I "!answerKey!"=="ipset_fake_udp" set "ans_ipset_fake_udp=!answerValue!"
        if /I "!answerKey!"=="general_udp" set "ans_general_udp=!answerValue!"
        if /I "!answerKey!"=="stun_fake" set "ans_stun_fake=!answerValue!"
        if /I "!answerKey!"=="game_fake_tcp" set "ans_game_fake_tcp=!answerValue!"
        if /I "!answerKey!"=="ipset_fake_tcp" set "ans_ipset_fake_tcp=!answerValue!"
        if /I "!answerKey!"=="general_tcp" set "ans_general_tcp=!answerValue!"
        if /I "!answerKey!"=="game_fake_tcp_alt" set "ans_game_fake_tcp_alt=!answerValue!"
        if /I "!answerKey!"=="ipset_fake_tcp_alt" set "ans_ipset_fake_tcp_alt=!answerValue!"
        if /I "!answerKey!"=="general_tcp_alt" set "ans_general_tcp_alt=!answerValue!"
        if /I "!answerKey!"=="game_fake_tcp_alt2" set "ans_game_fake_tcp_alt2=!answerValue!"
        if /I "!answerKey!"=="ipset_fake_tcp_alt2" set "ans_ipset_fake_tcp_alt2=!answerValue!"
        if /I "!answerKey!"=="general_tcp_alt2" set "ans_general_tcp_alt2=!answerValue!"
        if /I "!answerKey!"=="hostfakesplit" set "ans_hostfakesplit=!answerValue!"
        if /I "!answerKey!"=="hostfakesplit_alt" set "ans_hostfakesplit_alt=!answerValue!"
        if /I "!answerKey!"=="auto_updates" set "ans_auto_updates=!answerValue!"
        if /I "!answerKey!"=="update_ipset-list" set "ans_update_ipset-list=!answerValue!"
        if /I "!answerKey!"=="strategy_select_mode" set "ans_strategy_select_mode=!answerValue!"
        if /I "!answerKey!"=="strategy_file" set "ans_strategy_file=!answerValue!"
        if /I "!answerKey!"=="custom_user_list" set "ans_custom_user_list=!answerValue!"
        if /I "!answerKey!"=="exclude_user_list" set "ans_exclude_user_list=!answerValue!"
    )
)
exit /b 0

:: WRITE ANSWERS TEMPLATE ================================
:write_answers_template
type nul > "%answersPath%"
>> "%answersPath%" echo(# Zapret easy install answers
>> "%answersPath%" echo(# Fill values and run easy-install.bat or auto-install.bat
>> "%answersPath%" echo(# Empty values trigger interactive questions (easy mode only).
>> "%answersPath%" echo(# In auto mode empty values use defaults.
>> "%answersPath%" echo(
>> "%answersPath%" echo(# ipset_mode: none=0, loaded=1, any=2 (default: loaded)
>> "%answersPath%" echo(ipset_mode=loaded
>> "%answersPath%" echo(
>> "%answersPath%" echo(# gamefilter: disable=0, all=1, tcp=2, udp=3 (default: disable)
>> "%answersPath%" echo(gamefilter=disable
>> "%answersPath%" echo(
>> "%answersPath%" echo(# === UDP / QUIC Fakes ===
>> "%answersPath%" echo(# For custom fakes, you can use clean names (e.g. google, sentry),
>> "%answersPath%" echo(# full filenames (e.g. quic_initial_ajax_aspnetcdn_com.bin), or partials (e.g. ajax_aspnetcdn_com)
>> "%answersPath%" echo(
>> "%answersPath%" echo(# discord_fake: standard, alt, or custom payload name from bin/ (default: standard)
>> "%answersPath%" echo(# Example: discord_fake=ajax_aspnetcdn_com
>> "%answersPath%" echo(discord_fake=standard
>> "%answersPath%" echo(
>> "%answersPath%" echo(# game_fake_udp: standard, alt, or custom payload name from bin/ (default: standard)
>> "%answersPath%" echo(# Example: game_fake_udp=google
>> "%answersPath%" echo(game_fake_udp=standard
>> "%answersPath%" echo(
>> "%answersPath%" echo(# ipset_fake_udp: standard, alt, or custom payload name from bin/ (default: standard)
>> "%answersPath%" echo(ipset_fake_udp=standard
>> "%answersPath%" echo(
>> "%answersPath%" echo(# general_udp: standard, alt, or custom payload name from bin/ (default: standard)
>> "%answersPath%" echo(general_udp=standard
>> "%answersPath%" echo(
>> "%answersPath%" echo(# stun_fake: standard, google, max_ru, or custom payload name from bin/ (default: standard)
>> "%answersPath%" echo(stun_fake=standard
>> "%answersPath%" echo(
>> "%answersPath%" echo(# === TCP Fakes ===
>> "%answersPath%" echo(# For custom fakes, you can use clean names (e.g. google, sentry),
>> "%answersPath%" echo(# full filenames (e.g. tls_clienthello_ajax_aspnetcdn_com.bin), or partials (e.g. ajax_aspnetcdn_com)
>> "%answersPath%" echo(
>> "%answersPath%" echo(# game_fake_tcp: standard, alt, backup, or custom payload name from bin/ (default: standard)
>> "%answersPath%" echo(# Example: game_fake_tcp=sentry
>> "%answersPath%" echo(game_fake_tcp=standard
>> "%answersPath%" echo(
>> "%answersPath%" echo(# ipset_fake_tcp: standard, alt, backup, or custom payload name from bin/ (default: standard)
>> "%answersPath%" echo(ipset_fake_tcp=standard
>> "%answersPath%" echo(
>> "%answersPath%" echo(# general_tcp: standard, alt, backup, or custom payload name from bin/ (default: standard)
>> "%answersPath%" echo(general_tcp=standard
>> "%answersPath%" echo(
>> "%answersPath%" echo(# === TCP Alt Fakes ===
>> "%answersPath%" echo(
>> "%answersPath%" echo(# game_fake_tcp_alt: standard, alt, or custom payload name from bin/ (default: standard)
>> "%answersPath%" echo(game_fake_tcp_alt=standard
>> "%answersPath%" echo(
>> "%answersPath%" echo(# ipset_fake_tcp_alt: standard, alt, or custom payload name from bin/ (default: standard)
>> "%answersPath%" echo(ipset_fake_tcp_alt=standard
>> "%answersPath%" echo(
>> "%answersPath%" echo(# general_tcp_alt: standard, alt, or custom payload name from bin/ (default: standard)
>> "%answersPath%" echo(general_tcp_alt=standard
>> "%answersPath%" echo(
>> "%answersPath%" echo(# === TCP Alt2 Fakes ===
>> "%answersPath%" echo(
>> "%answersPath%" echo(# game_fake_tcp_alt2: standard, backup, or custom payload name from bin/ (default: standard)
>> "%answersPath%" echo(game_fake_tcp_alt2=standard
>> "%answersPath%" echo(
>> "%answersPath%" echo(# ipset_fake_tcp_alt2: standard, backup, or custom payload name from bin/ (default: standard)
>> "%answersPath%" echo(ipset_fake_tcp_alt2=standard
>> "%answersPath%" echo(
>> "%answersPath%" echo(# general_tcp_alt2: standard, backup, or custom payload name from bin/ (default: standard)
>> "%answersPath%" echo(general_tcp_alt2=standard
>> "%answersPath%" echo(
>> "%answersPath%" echo(# === HostFakeSplit ===
>> "%answersPath%" echo(
>> "%answersPath%" echo(# hostfakesplit: default, or custom domain (e.g. google.com) (default: default)
>> "%answersPath%" echo(hostfakesplit=default
>> "%answersPath%" echo(
>> "%answersPath%" echo(# hostfakesplit_alt: default, or custom domain (e.g. google.com) (default: default)
>> "%answersPath%" echo(hostfakesplit_alt=default
>> "%answersPath%" echo(
>> "%answersPath%" echo(# === System Settings ===
>> "%answersPath%" echo(
>> "%answersPath%" echo(# auto_updates: yes=1, no=0 (default: yes)
>> "%answersPath%" echo(auto_updates=yes
>> "%answersPath%" echo(
>> "%answersPath%" echo(# update_ipset-list: yes=1, no=0 (default: no)
>> "%answersPath%" echo(update_ipset-list=no
>> "%answersPath%" echo(
>> "%answersPath%" echo(# strategy_select_mode: auto=1, manual=2 (default: auto)
>> "%answersPath%" echo(strategy_select_mode=auto
>> "%answersPath%" echo(
>> "%answersPath%" echo(# strategy_file: filename of strategy bat (only for manual mode, e.g. general.bat)
>> "%answersPath%" echo(strategy_file=
>> "%answersPath%" echo(
>> "%answersPath%" echo(# custom_user_list: domains to bypass, comma or semicolon separated
>> "%answersPath%" echo(# Example: google.com,youtube.com,discord.com
>> "%answersPath%" echo(custom_user_list=
>> "%answersPath%" echo(
>> "%answersPath%" echo(# exclude_user_list: domains to exclude from bypass, comma or semicolon separated
>> "%answersPath%" echo(# Example: example.com,test.com
>> "%answersPath%" echo(exclude_user_list=
echo Template created: %answersPath%
exit /b 0

:: CONFIGURE AUTO ================================
:configure_auto
call :normalize_ipset_mode "%ans_ipset_mode%"
if defined normalized (set "settings_ipset_mode=!normalized!") else set "settings_ipset_mode=loaded"
call :normalize_game_filter "%ans_gamefilter%"
if defined normalized (set "settings_gamefilter=!normalized!") else set "settings_gamefilter=disable"

:: UDP
call :normalize_udp_fake "%ans_discord_fake%"
if defined normalized (set "settings_discord_fake=!normalized!") else set "settings_discord_fake=standard"
call :normalize_udp_fake "%ans_game_fake_udp%"
if defined normalized (set "settings_game_fake_udp=!normalized!") else set "settings_game_fake_udp=standard"
call :normalize_udp_fake "%ans_ipset_fake_udp%"
if defined normalized (set "settings_ipset_fake_udp=!normalized!") else set "settings_ipset_fake_udp=standard"
call :normalize_udp_fake "%ans_general_udp%"
if defined normalized (set "settings_general_udp=!normalized!") else set "settings_general_udp=standard"
call :normalize_tcp_fake "%ans_stun_fake%"
if defined normalized (set "settings_stun_fake=!normalized!") else set "settings_stun_fake=standard"

:: TCP
call :normalize_tcp_fake "%ans_game_fake_tcp%"
if defined normalized (set "settings_game_fake_tcp=!normalized!") else set "settings_game_fake_tcp=standard"
call :normalize_tcp_fake "%ans_ipset_fake_tcp%"
if defined normalized (set "settings_ipset_fake_tcp=!normalized!") else set "settings_ipset_fake_tcp=standard"
call :normalize_tcp_fake "%ans_general_tcp%"
if defined normalized (set "settings_general_tcp=!normalized!") else set "settings_general_tcp=standard"

:: TCP Alt
call :normalize_tcp_fake "%ans_game_fake_tcp_alt%"
if defined normalized (set "settings_game_fake_tcp_alt=!normalized!") else set "settings_game_fake_tcp_alt=standard"
call :normalize_tcp_fake "%ans_ipset_fake_tcp_alt%"
if defined normalized (set "settings_ipset_fake_tcp_alt=!normalized!") else set "settings_ipset_fake_tcp_alt=standard"
call :normalize_tcp_fake "%ans_general_tcp_alt%"
if defined normalized (set "settings_general_tcp_alt=!normalized!") else set "settings_general_tcp_alt=standard"

:: TCP Alt2
call :normalize_tcp_fake "%ans_game_fake_tcp_alt2%"
if defined normalized (set "settings_game_fake_tcp_alt2=!normalized!") else set "settings_game_fake_tcp_alt2=standard"
call :normalize_tcp_fake "%ans_ipset_fake_tcp_alt2%"
if defined normalized (set "settings_ipset_fake_tcp_alt2=!normalized!") else set "settings_ipset_fake_tcp_alt2=standard"
call :normalize_tcp_fake "%ans_general_tcp_alt2%"
if defined normalized (set "settings_general_tcp_alt2=!normalized!") else set "settings_general_tcp_alt2=standard"

:: HostFakeSplit
call :normalize_hfs "%ans_hostfakesplit%"
if defined normalized (set "settings_hostfakesplit=!normalized!") else set "settings_hostfakesplit=default"
call :normalize_hfs "%ans_hostfakesplit_alt%"
if defined normalized (set "settings_hostfakesplit_alt=!normalized!") else set "settings_hostfakesplit_alt=default"

:: System
call :normalize_yes_no "%ans_auto_updates%"
if defined normalized (set "settings_auto_updates=!normalized!") else set "settings_auto_updates=yes"
call :normalize_yes_no "%ans_update_ipset-list%"
if defined normalized (set "settings_update_ipset_list=!normalized!") else set "settings_update_ipset_list=no"
set "settings_strategy_select_mode=auto"
set "settings_strategy_file="
set "settings_custom_user_list=%ans_custom_user_list%"
set "settings_exclude_user_list=%ans_exclude_user_list%"
exit /b 0

:: CONFIGURE EASY ================================
:configure_easy
call :normalize_ipset_mode "%ans_ipset_mode%"
if defined normalized (set "settings_ipset_mode=!normalized!") else (
    echo IPSet mode options: 0=none, 1=loaded, 2=any
    call :read_choice "Select ipset mode [default loaded]" "0 1 2 none loaded any" "loaded"
    call :normalize_ipset_mode "!choice!"
    set "settings_ipset_mode=!normalized!"
)
call :normalize_game_filter "%ans_gamefilter%"
if defined normalized (set "settings_gamefilter=!normalized!") else (
    echo Game filter options: 0=disable, 1=all, 2=tcp, 3=udp
    call :read_choice "Select game filter mode [default disable]" "0 1 2 3 disable all tcp udp" "disable"
    call :normalize_game_filter "!choice!"
    set "settings_gamefilter=!normalized!"
)

:: UDP
call :normalize_udp_fake "%ans_discord_fake%"
if defined normalized (set "settings_discord_fake=!normalized!") else set "settings_discord_fake=standard"
call :normalize_udp_fake "%ans_game_fake_udp%"
if defined normalized (set "settings_game_fake_udp=!normalized!") else set "settings_game_fake_udp=standard"
call :normalize_udp_fake "%ans_ipset_fake_udp%"
if defined normalized (set "settings_ipset_fake_udp=!normalized!") else set "settings_ipset_fake_udp=standard"
call :normalize_udp_fake "%ans_general_udp%"
if defined normalized (set "settings_general_udp=!normalized!") else set "settings_general_udp=standard"
call :normalize_tcp_fake "%ans_stun_fake%"
if defined normalized (set "settings_stun_fake=!normalized!") else set "settings_stun_fake=standard"

:: TCP
call :normalize_tcp_fake "%ans_game_fake_tcp%"
if defined normalized (set "settings_game_fake_tcp=!normalized!") else set "settings_game_fake_tcp=standard"
call :normalize_tcp_fake "%ans_ipset_fake_tcp%"
if defined normalized (set "settings_ipset_fake_tcp=!normalized!") else set "settings_ipset_fake_tcp=standard"
call :normalize_tcp_fake "%ans_general_tcp%"
if defined normalized (set "settings_general_tcp=!normalized!") else set "settings_general_tcp=standard"

:: TCP Alt
call :normalize_tcp_fake "%ans_game_fake_tcp_alt%"
if defined normalized (set "settings_game_fake_tcp_alt=!normalized!") else set "settings_game_fake_tcp_alt=standard"
call :normalize_tcp_fake "%ans_ipset_fake_tcp_alt%"
if defined normalized (set "settings_ipset_fake_tcp_alt=!normalized!") else set "settings_ipset_fake_tcp_alt=standard"
call :normalize_tcp_fake "%ans_general_tcp_alt%"
if defined normalized (set "settings_general_tcp_alt=!normalized!") else set "settings_general_tcp_alt=standard"

:: TCP Alt2
call :normalize_tcp_fake "%ans_game_fake_tcp_alt2%"
if defined normalized (set "settings_game_fake_tcp_alt2=!normalized!") else set "settings_game_fake_tcp_alt2=standard"
call :normalize_tcp_fake "%ans_ipset_fake_tcp_alt2%"
if defined normalized (set "settings_ipset_fake_tcp_alt2=!normalized!") else set "settings_ipset_fake_tcp_alt2=standard"
call :normalize_tcp_fake "%ans_general_tcp_alt2%"
if defined normalized (set "settings_general_tcp_alt2=!normalized!") else set "settings_general_tcp_alt2=standard"

:: HostFakeSplit
call :normalize_hfs "%ans_hostfakesplit%"
if defined normalized (set "settings_hostfakesplit=!normalized!") else set "settings_hostfakesplit=default"
call :normalize_hfs "%ans_hostfakesplit_alt%"
if defined normalized (set "settings_hostfakesplit_alt=!normalized!") else set "settings_hostfakesplit_alt=default"

:: System
call :normalize_yes_no "%ans_auto_updates%"
if defined normalized (set "settings_auto_updates=!normalized!") else (
    echo Auto updates options: 0=no, 1=yes
    call :read_choice "Enable auto updates? [default yes]" "0 1 yes no" "yes"
    call :normalize_yes_no "!choice!"
    set "settings_auto_updates=!normalized!"
)
call :normalize_yes_no "%ans_update_ipset-list%"
if defined normalized (set "settings_update_ipset_list=!normalized!") else (
    echo Update ipset list options: 0=no, 1=yes
    call :read_choice "Update ipset list before install? [default no]" "0 1 yes no" "no"
    call :normalize_yes_no "!choice!"
    set "settings_update_ipset_list=!normalized!"
)
call :normalize_strategy_mode "%ans_strategy_select_mode%"
if defined normalized (set "settings_strategy_select_mode=!normalized!") else (
    echo Strategy mode options: 1=auto, 2=manual
    call :read_choice "Select strategy mode [default auto]" "1 2 auto manual" "auto"
    call :normalize_strategy_mode "!choice!"
    set "settings_strategy_select_mode=!normalized!"
)
set "settings_custom_user_list=%ans_custom_user_list%"
set "settings_exclude_user_list=%ans_exclude_user_list%"
if /I "%settings_strategy_select_mode%"=="manual" (
    call :resolve_strategy "%ans_strategy_file%"
    if defined resolvedStrategy (set "settings_strategy_file=%resolvedStrategy%") else (call :select_strategy_interactive & set "settings_strategy_file=!selectedStrategy!")
) else (
    set "settings_strategy_file="
)
exit /b 0

:: NORMALIZE YES/NO ================================
:normalize_yes_no
set "normalized=" & set "value=%~1"
if not defined value exit /b 0
for %%V in (1 y yes true on enable enabled) do if /I "%value%"=="%%V" (set "normalized=yes" & exit /b 0)
for %%V in (0 n no false off disable disabled) do if /I "%value%"=="%%V" (set "normalized=no" & exit /b 0)
exit /b 0

:: NORMALIZE GAME FILTER ================================
:normalize_game_filter
set "normalized=" & set "value=%~1"
if not defined value exit /b 0
for %%V in (disable off none 0) do if /I "%value%"=="%%V" (set "normalized=disable" & exit /b 0)
for %%V in (all 1) do if /I "%value%"=="%%V" (set "normalized=all" & exit /b 0)
for %%V in (tcp 2) do if /I "%value%"=="%%V" (set "normalized=tcp" & exit /b 0)
for %%V in (udp 3) do if /I "%value%"=="%%V" (set "normalized=udp" & exit /b 0)
exit /b 0

:: NORMALIZE IPSET MODE ================================
:normalize_ipset_mode
set "normalized=" & set "value=%~1"
if not defined value exit /b 0
for %%V in (none 0) do if /I "%value%"=="%%V" (set "normalized=none" & exit /b 0)
for %%V in (loaded 1) do if /I "%value%"=="%%V" (set "normalized=loaded" & exit /b 0)
for %%V in (any 2) do if /I "%value%"=="%%V" (set "normalized=any" & exit /b 0)
exit /b 0

:: NORMALIZE FAKE ================================
:normalize_udp_fake
call :normalize_fake "%~1" "quic_initial_"
exit /b

:normalize_tcp_fake
call :normalize_fake "%~1" "tls_clienthello_"
exit /b

:normalize_fake
set "normalized=" & set "value=%~1"
set "prefix=%~2"
if not defined value exit /b 0
for %%V in (standard 0) do if /I "%value%"=="%%V" (set "normalized=standard" & exit /b 0)
for %%V in (alt 1) do if /I "%value%"=="%%V" (set "normalized=alt" & exit /b 0)
for %%V in (backup 2) do if /I "%value%"=="%%V" (set "normalized=backup" & exit /b 0)
for %%V in (google) do if /I "%value%"=="%%V" (set "normalized=google" & exit /b 0)
for %%V in (max_ru) do if /I "%value%"=="%%V" (set "normalized=max_ru" & exit /b 0)
if "%value:~-4%"==".bin" (
    if exist "%rootDir%bin\%value%" (
        set "normalized=%value%"
        exit /b 0
    )
)
call :find_fake_by_name "%value%" "%prefix%"
if defined normalized exit /b 0
exit /b 0

:: NORMALIZE AUTORESTART ================================
:: :normalize_autorestart
:: set "normalized=" & set "value=%~1"
:: if not defined value exit /b 0
:: echo(%value%| findstr /r "^[0-9][0-9]*$" >nul 2>&1
:: if not errorlevel 1 (set "normalized=%value%" & exit /b 0)
:: exit /b 0

:: NORMALIZE STRATEGY MODE ================================
:normalize_strategy_mode
set "normalized=" & set "value=%~1"
if not defined value exit /b 0
for %%V in (auto best 1) do if /I "%value%"=="%%V" (set "normalized=auto" & exit /b 0)
for %%V in (manual 2) do if /I "%value%"=="%%V" (set "normalized=manual" & exit /b 0)
exit /b 0

:: READ CHOICE (with default) ================================
:read_choice
set "choice=" & set "default=%~3"
:read_choice_loop
set /p "choice=%~1: "
if not defined choice (if defined default (set "choice=!default!" & exit /b 0))
for %%V in (%~2) do if /I "!choice!"=="%%V" exit /b 0
echo Invalid input. Allowed: %~2
goto read_choice_loop

:: LOAD STRATEGIES ================================
:load_strategies
set "strategy_count=0"
chcp 437 > nul
for /f "delims=" %%F in ('powershell -NoProfile -Command "Get-ChildItem -LiteralPath '%rootDir%' -Filter 'general*.bat' | Sort-Object { [Regex]::Replace($_.Name, '(\d+)', { $args[0].Value.PadLeft(8, '0') }) } | ForEach-Object { $_.Name }"') do (
    set /a strategy_count+=1
    set "strategy_!strategy_count!=%%F"
)
chcp 65001 > nul
exit /b 0

:: RESOLVE STRATEGY ================================
:resolve_strategy
set "resolvedStrategy=" & set "candidate=%~1"
if not defined candidate exit /b 1
if exist "%candidate%" (for %%F in ("%candidate%") do set "resolvedStrategy=%%~nxF" & exit /b 0)
if exist "%rootDir%%candidate%" (for %%F in ("%rootDir%%candidate%") do set "resolvedStrategy=%%~nxF" & exit /b 0)
for /l %%I in (1,1,!strategy_count!) do if /I "!strategy_%%I!"=="%candidate%" set "resolvedStrategy=!strategy_%%I!"
if defined resolvedStrategy exit /b 0
exit /b 1

:: SELECT STRATEGY INTERACTIVE ================================
:select_strategy_interactive
echo Available strategies:
for /l %%I in (1,1,!strategy_count!) do echo   %%I. !strategy_%%I!
:select_strategy_loop
set "strategyNumber=" & set /p "strategyNumber=Select strategy number: "
echo(!strategyNumber!| findstr /r "^[0-9][0-9]*$" >nul 2>&1
if errorlevel 1 goto invalid_strategy_number
if !strategyNumber! LSS 1 goto invalid_strategy_number
if !strategyNumber! GTR !strategy_count! goto invalid_strategy_number
for %%I in (!strategyNumber!) do set "selectedStrategy=!strategy_%%I!"
exit /b 0
:invalid_strategy_number
echo Invalid strategy number.
goto select_strategy_loop

:: PRINT INSTALL SUMMARY ================================
:print_install_summary
set "displayAutoUpdates=%settings_auto_updates%"
set "displayUpdateIpSet=%settings_update_ipset_list%"
set "displayStrategy="
if /I "%displayGameFilter%"=="disable" set "displayGameFilter=disabled"

call :get_display_fake "%settings_discord_fake%" "displayDiscordFake" "quic_initial_dbankcloud_ru.bin" "quic_initial_www_google_com.bin" ""
call :get_display_fake "%settings_game_fake_udp%" "displayGameFakeUDP" "quic_initial_dbankcloud_ru.bin" "quic_initial_www_google_com.bin" ""
call :get_display_fake "%settings_ipset_fake_udp%" "displayIpsetFakeUDP" "quic_initial_www_google_com.bin" "quic_initial_dbankcloud_ru.bin" ""
call :get_display_fake "%settings_general_udp%" "displayGeneralUDP" "quic_initial_www_google_com.bin" "quic_initial_dbankcloud_ru.bin" ""
call :get_display_fake "%settings_stun_fake%" "displayStunFake" "stun.bin" "" "tls_clienthello_www_google_com.bin" "tls_clienthello_max_ru.bin"

call :get_display_fake "%settings_game_fake_tcp%" "displayGameFakeTCP" "tls_clienthello_4pda_to.bin" "tls_clienthello_www_google_com.bin" "tls_clienthello_max_ru.bin"
call :get_display_fake "%settings_ipset_fake_tcp%" "displayIpsetFakeTCP" "tls_clienthello_4pda_to.bin" "tls_clienthello_www_google_com.bin" "tls_clienthello_max_ru.bin"
call :get_display_fake "%settings_general_tcp%" "displayGeneralTCP" "tls_clienthello_4pda_to.bin" "tls_clienthello_www_google_com.bin" "tls_clienthello_max_ru.bin"

call :get_display_fake "%settings_game_fake_tcp_alt%" "displayGameFakeTCPAlt" "tls_clienthello_www_google_com.bin" "tls_clienthello_max_ru.bin" ""
call :get_display_fake "%settings_ipset_fake_tcp_alt%" "displayIpsetFakeTCPAlt" "tls_clienthello_www_google_com.bin" "tls_clienthello_max_ru.bin" ""
call :get_display_fake "%settings_general_tcp_alt%" "displayGeneralTCPAlt" "tls_clienthello_www_google_com.bin" "tls_clienthello_max_ru.bin" ""

call :get_display_fake "%settings_game_fake_tcp_alt2%" "displayGameFakeTCPAlt2" "tls_clienthello_max_ru.bin" "" "tls_clienthello_4pda_to.bin"
call :get_display_fake "%settings_ipset_fake_tcp_alt2%" "displayIpsetFakeTCPAlt2" "tls_clienthello_max_ru.bin" "" "tls_clienthello_4pda_to.bin"
call :get_display_fake "%settings_general_tcp_alt2%" "displayGeneralTCPAlt2" "tls_clienthello_max_ru.bin" "" "tls_clienthello_4pda_to.bin"

set "displayHostFakeSplit=%settings_hostfakesplit%"
set "displayHostFakeSplitAlt=%settings_hostfakesplit_alt%"

if /I "%displayAutoUpdates%"=="yes" set "displayAutoUpdates=enabled"
if /I "%displayAutoUpdates%"=="no" set "displayAutoUpdates=disabled"
if /I "%settings_strategy_select_mode%"=="manual" set "displayStrategy=%settings_strategy_file%"
if defined resolvedStrategy set "displayStrategy=%resolvedStrategy%"
echo.
echo Installation parameters:
echo   IPSet mode: %settings_ipset_mode%
echo   Game filter: %displayGameFilter%
echo.
echo   UDP Fakes:
echo     Discord fake: %displayDiscordFake%
echo     Game fake UDP: %displayGameFakeUDP%
echo     IPSet fake UDP: %displayIpsetFakeUDP%
echo     General UDP: %displayGeneralUDP%
echo     Stun Fake: %displayStunFake%
echo.
echo   TCP Fakes:
echo     Game fake TCP: %displayGameFakeTCP%
echo     IPSet fake TCP: %displayIpsetFakeTCP%
echo     General TCP: %displayGeneralTCP%
echo.
echo   TCP Alt Fakes:
echo     Game fake TCP Alt: %displayGameFakeTCPAlt%
echo     IPSet fake TCP Alt: %displayIpsetFakeTCPAlt%
echo     General TCP Alt: %displayGeneralTCPAlt%
echo.
echo   TCP Alt2 Fakes:
echo     Game fake TCP Alt2: %displayGameFakeTCPAlt2%
echo     IPSet fake TCP Alt2: %displayIpsetFakeTCPAlt2%
echo     General TCP Alt2: %displayGeneralTCPAlt2%
echo.
echo   HostFakeSplit:
echo     HostFakeSplit (ALT9): %displayHostFakeSplit%
echo     HostFakeSplit Alt (ALT3): %displayHostFakeSplitAlt%
echo.
echo   System:
echo     Auto updates: %displayAutoUpdates%
echo     Update IPSet list: %displayUpdateIpSet%
echo     Strategy mode: %settings_strategy_select_mode%
if defined settings_custom_user_list (echo     Custom user list: %settings_custom_user_list%) else echo     Custom user list: unchanged
if defined settings_exclude_user_list (echo     Exclude user list: %settings_exclude_user_list%) else echo     Exclude user list: unchanged
if defined displayStrategy echo     Strategy: %displayStrategy%
echo.
exit /b 0

:: SET IPSET MODE ================================
:set_ipset_mode
set "modeValue=%~1"
set "listFile=%listsDir%ipset-all.txt"
set "backupFile=%listsDir%ipset-all.txt.backup"
if not exist "%listsDir%" mkdir "%listsDir%" >nul 2>&1
if not exist "%listFile%" type nul > "%listFile%"
if /I "%modeValue%"=="none" (
    call :is_dummy_ipset "%listFile%"
    if not "!dummyOnly!"=="1" copy /y "%listFile%" "%backupFile%" >nul 2>&1
    > "%listFile%" echo 203.0.113.113/32
    exit /b 0
)
if /I "%modeValue%"=="any" (
    type nul > "%listFile%"
    exit /b 0
)
if /I "%modeValue%"=="loaded" (
    if exist "%backupFile%" (
        move /y "%backupFile%" "%listFile%" >nul
    ) else (
        call :is_dummy_ipset "%listFile%"
        for %%F in ("%listFile%") do set "ipsetSize=%%~zF"
        if "!dummyOnly!"=="1" (echo IPSet mode: loaded requested, but no backup exists. Keeping current list.
        ) else if "!ipsetSize!"=="0" (echo IPSet mode: loaded requested, but no backup exists. Keeping current list.
        )
    )
    exit /b 0
)
exit /b 1

:: IS DUMMY IPSET ================================
:is_dummy_ipset
set "dummyOnly=0"
set "dummyFile=%TEMP%\zapret_dummy_%RANDOM%%RANDOM%.txt"
> "%dummyFile%" echo 203.0.113.113/32
fc /b "%~1" "%dummyFile%" >nul 2>&1
if not errorlevel 1 set "dummyOnly=1"
del /q "%dummyFile%" >nul 2>&1
exit /b 0

:: SET GAME FILTER MODE ================================
:set_game_filter_mode
set "gameValue=%~1"
set "flagPath=%rootDir%utils\game_filter.enabled"
if not defined gameValue set "gameValue=disable"
if /I not "%gameValue%"=="disable" goto :gf_all
if exist "%flagPath%" del /q "%flagPath%" >nul 2>&1
exit /b 0
:gf_all
if /I not "%gameValue%"=="all" goto :gf_tcp
> "%flagPath%" echo all
exit /b 0
:gf_tcp
if /I not "%gameValue%"=="tcp" goto :gf_udp
> "%flagPath%" echo tcp
exit /b 0
:gf_udp
if /I not "%gameValue%"=="udp" goto :gf_err
> "%flagPath%" echo udp
exit /b 0
:gf_err
echo [DEBUG] set_game_filter_mode: unknown value '%gameValue%'
exit /b 1

:: SET FAKE MODE ================================
:set_fake_mode
set "fakeValue=%~1"
set "flagPath=%rootDir%utils\custom_fakes\%~2.enabled"
if not defined fakeValue set "fakeValue=standard"
if /I "%fakeValue%"=="standard" (
    if exist "%flagPath%" del /q "%flagPath%" >nul 2>&1
    exit /b 0
)
if /I "%fakeValue%"=="alt" ( > "%flagPath%" echo alt & exit /b 0 )
if /I "%fakeValue%"=="backup" ( > "%flagPath%" echo backup & exit /b 0 )
if /I "%fakeValue%"=="google" ( > "%flagPath%" echo google & exit /b 0 )
if /I "%fakeValue%"=="max_ru" ( > "%flagPath%" echo max_ru & exit /b 0 )
if "%fakeValue:~-4%"==".bin" ( > "%flagPath%" echo %fakeValue% & exit /b 0 )

echo [DEBUG] set_%~2_mode: unknown value '%fakeValue%'
exit /b 1

:: SET AUTO UPDATES MODE ================================
:set_auto_updates_mode
set "updatesValue=%~1"
set "flagPath=%rootDir%utils\check_updates.enabled"
if not defined updatesValue set "updatesValue=yes"
if /I not "%updatesValue%"=="yes" goto :au_off
> "%flagPath%" echo ENABLED
exit /b 0
:au_off
if exist "%flagPath%" del /q "%flagPath%" >nul 2>&1
exit /b 0

:: UPDATE IPSET LIST ================================
:update_ipset_list
set "listFile=%listsDir%ipset-all.txt"
set "tmpList=%TEMP%\zapret_ipset_%RANDOM%%RANDOM%.txt"
set "ipsetUrl=https://raw.githubusercontent.com/shlynas/zapret-discord-youtube/refs/heads/main/.service/ipset-service.txt"
curl.exe --fail -L --connect-timeout 10 --max-time 30 -o "%tmpList%" "%ipsetUrl%" >nul 2>&1
if errorlevel 1 (if exist "%tmpList%" del /q "%tmpList%" >nul 2>&1 & echo WARNING: IPSet list update failed. Continuing without update. & exit /b 0)
move /y "%tmpList%" "%listFile%" >nul
echo IPSet list updated.
exit /b 0

:: APPLY CUSTOM USER LIST ================================
:apply_custom_user_list
if not defined settings_custom_user_list exit /b 0
if not exist "%listsDir%" mkdir "%listsDir%" >nul 2>&1
set "generalUserFile=%listsDir%list-general-user.txt"
if not exist "%generalUserFile%" type nul > "%generalUserFile%"
set "customDomains=%settings_custom_user_list:,= %"
set "customDomains=!customDomains:;= !"
set "domainCount=0"
set "checkFile=%TEMP%\zapret_general_check_%RANDOM%%RANDOM%.txt"
copy /y "%generalUserFile%" "%checkFile%" >nul 2>&1
for %%D in (!customDomains!) do (
    findstr /x /i /c:"%%D" "%checkFile%" >nul 2>&1
    if errorlevel 1 (>> "%generalUserFile%" echo(%%D& set /a domainCount+=1)
)
del /q "%checkFile%" >nul 2>&1
if "!domainCount!"=="0" (echo Custom user list: no new domains to add.) else (echo Custom user list: !domainCount! domains added.)
exit /b 0

:: APPLY EXCLUDE USER LIST ================================
:apply_exclude_user_list
if not defined settings_exclude_user_list exit /b 0
if not exist "%listsDir%" mkdir "%listsDir%" >nul 2>&1
set "excludeUserFile=%listsDir%list-exclude-user.txt"
if not exist "%excludeUserFile%" type nul > "%excludeUserFile%"
set "customDomains=%settings_exclude_user_list:,= %"
set "customDomains=!customDomains:;= !"
set "domainCount=0"
set "checkFile=%TEMP%\zapret_exclude_check_%RANDOM%%RANDOM%.txt"
copy /y "%excludeUserFile%" "%checkFile%" >nul 2>&1
for %%D in (!customDomains!) do (
    findstr /x /i /c:"%%D" "%checkFile%" >nul 2>&1
    if errorlevel 1 (>> "%excludeUserFile%" echo(%%D& set /a domainCount+=1)
)
del /q "%checkFile%" >nul 2>&1
if "!domainCount!"=="0" (echo Exclude user list: no new domains to add.) else (echo Exclude user list: !domainCount! domains added.)
exit /b 0

:: STOP ZAPRET SERVICE ================================
:stop_zapret_service_if_needed
sc query "zapret" >nul 2>&1
if errorlevel 1 (echo Service 'zapret' not found. Skipping stop. & exit /b 0)
sc query "zapret" | findstr /i "RUNNING" >nul 2>&1
if errorlevel 1 (echo Service 'zapret' is already stopped. & exit /b 0)
net stop "zapret" >nul 2>&1
if errorlevel 1 exit /b 1
set "serviceWasRunning=1" & set "serviceStoppedByInstaller=1"
echo Service 'zapret' stopped successfully.
exit /b 0

:: AUTO STRATEGY SELECTION ================================
:select_strategy_auto
set "testResultFile=%TEMP%\zapret_strategy_%RANDOM%%RANDOM%.txt"
set "testDoneFile=%testResultFile%.done"
if exist "%testResultFile%" del /q "%testResultFile%" >nul 2>&1
if exist "%testDoneFile%" del /q "%testDoneFile%" >nul 2>&1
echo Opening test window - see the new PowerShell window for progress...
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%rootDir%utils\test zapret.ps1" -AutoInstall -NoPause -ResultFile "%testResultFile%" -DoneFile "%testDoneFile%"
:: wait for test completion marker (max 10 min)
set "waitLoops=0"
:wait_test_result
if exist "%testDoneFile%" goto test_result_ready
set /a waitLoops+=1
if !waitLoops! GEQ 600 (set "failureMessage=Auto test timed out (10 min)." & del /q "%testResultFile%" "%testDoneFile%" >nul 2>&1 & exit /b 1)
ping -n 2 127.0.0.1 >nul 2>&1
goto wait_test_result
:test_result_ready
if exist "%testResultFile%" set /p "selectedStrategy=" < "%testResultFile%"
del /q "%testResultFile%" "%testDoneFile%" >nul 2>&1
if not defined selectedStrategy (set "failureMessage=Unable to get best strategy from tests." & exit /b 1)
echo Best strategy from tests: %selectedStrategy%
exit /b 0

:: SHOW HELP ================================
:show_help
echo Usage: install-zapret.bat [mode] [options]
echo.
echo Modes:
echo   easy              Interactive installation with prompts
echo   auto              Non-interactive, uses answers.txt or defaults
echo.
echo Options:
echo   --make-template   Create answers.txt template with examples and exit
echo   --help            Show this help message and exit
echo.
echo Configuration is read from answers.txt in the root directory.
echo Run with --make-template to generate a template file.
exit /b 0

:: NORMALIZE HFS ================================
:normalize_hfs
set "normalized=" & set "value=%~1"
if not defined value exit /b 0
if /I "%value%"=="default" (set "normalized=default" & exit /b 0)
if /I "%value%"=="standard" (set "normalized=default" & exit /b 0)
set "normalized=%value%"
exit /b 0

:: SET HOSTFAKESPLIT MODE ================================
:set_hfs_mode
set "hfsValue=%~1"
set "flagPath=%rootDir%utils\custom_fakes\%~2.enabled"
set "defaultHost=%~3"
if not defined hfsValue set "hfsValue=default"
if /I "%hfsValue%"=="default" (
    if exist "%flagPath%" del /q "%flagPath%" >nul 2>&1
    exit /b 0
)
if /I "%hfsValue%"=="%defaultHost%" (
    if exist "%flagPath%" del /q "%flagPath%" >nul 2>&1
    exit /b 0
)
if not exist "%rootDir%utils\custom_fakes" mkdir "%rootDir%utils\custom_fakes" >nul 2>&1
> "%flagPath%" echo %hfsValue%
exit /b 0

:: RESTORE SERVICE AFTER FAILURE ================================
:restore_service_after_failure
if not "%installCompleted%"=="1" if "%serviceWasRunning%"=="1" if "%serviceStoppedByInstaller%"=="1" (
    net start "zapret" >nul 2>&1
    if errorlevel 1 (echo Failed to restore service 'zapret'.) else (echo Service 'zapret' restored and started after emergency stop.)
)
exit /b 0

:: FAIL ================================
:fail
echo Installation failed: %failureMessage%
call :restore_service_after_failure
exit /b 1


:: DYNAMIC FAKE RESOLVER HELPERS ================================

:get_clean_name
setlocal EnableDelayedExpansion
set "name=%~1"
if "%name%"=="stun.bin" (
    endlocal & set "%~2=Stun"
    exit /b 0
)
if "%name%"=="" (
    endlocal & set "%~2=none"
    exit /b 0
)
set "name=!name:tls_clienthello_=!"
set "name=!name:quic_initial_=!"
set "name=!name:.bin=!"
set "name=!name:_= !"
set "domain="
set "prev="
for %%A in (!name!) do (
    if defined prev set "domain=!prev!"
    set "prev=%%A"
)
if not defined domain set "domain=!prev!"
set "first=!domain:~0,1!"
for %%C in (A B C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if /i "!first!"=="%%C" set "first=%%C"
)
set "domain=!first!!domain:~1!"
endlocal & set "%~2=%domain%"
exit /b 0


:find_fake_by_name
setlocal EnableDelayedExpansion
set "input=%~1"
set "prefix=%~2"
set "found="

for %%F in ("%rootDir%bin\%prefix%*.bin") do (
    set "fname=%%~nxF"
    call :get_clean_name "!fname!" "cleanName"
    if /I "!cleanName!"=="!input!" (
        set "found=!fname!"
        goto :find_fake_done
    )
)

for %%F in ("%rootDir%bin\%prefix%*.bin") do (
    set "fname=%%~nxF"
    echo !fname! | findstr /i "!input!" >nul
    if not errorlevel 1 (
        set "found=!fname!"
        goto :find_fake_done
    )
)

:find_fake_done
endlocal & set "normalized=%found%"
exit /b 0


:get_display_fake
setlocal EnableDelayedExpansion
set "val=%~1"
set "var_name=%~2"
set "default_bin=%~3"
set "alt_bin=%~4"
set "backup_bin=%~5"

if not defined val set "val=standard"

set "resolved_bin="
set "label="

if /I "%val%"=="standard" (
    set "resolved_bin=%default_bin%"
    set "label=standard"
) else if /I "%val%"=="alt" (
    set "resolved_bin=%alt_bin%"
    set "label=alternative"
) else if /I "%val%"=="backup" (
    set "resolved_bin=%backup_bin%"
    set "label=backup"
) else if "%val:~-4%"==".bin" (
    set "resolved_bin=%val%"
) else (
    set "prefix="
    if not "%default_bin%"=="" (
        echo %default_bin% | findstr /i "quic_initial" >nul
        if !errorlevel!==0 set "prefix=quic_initial_"
        echo %default_bin% | findstr /i "tls_clienthello" >nul
        if !errorlevel!==0 set "prefix=tls_clienthello_"
    )
    call :find_fake_by_name "%val%" "!prefix!"
    if defined normalized (
        set "resolved_bin=!normalized!"
    ) else (
        set "label=%val%"
    )
)

if not "%resolved_bin%"=="" (
    call :get_clean_name "%resolved_bin%" "cleanName"
    if not "%label%"=="" (
        set "display=!label! (!cleanName!)"
    ) else (
        set "display=!cleanName! (%resolved_bin%)"
    )
) else (
    set "display=%label%"
)

endlocal & set "%var_name%=%display%"
exit /b 0


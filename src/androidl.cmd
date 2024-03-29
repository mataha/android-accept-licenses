:: Copyright (c) mataha and contributors
:: 
:: Permission is hereby granted, free of charge, to any person obtaining a copy
:: of this software and associated documentation files (the "Software"), to
:: deal in the Software without restriction, including without limitation the
:: rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
:: sell copies of the Software, and to permit persons to whom the Software is
:: furnished to do so, subject to the following conditions:
:: 
:: The above copyright notice and this permission notice shall be included in
:: all copies or substantial portions of the Software.
:: 
:: THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
:: IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
:: FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
:: AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
:: LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
:: FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
:: IN THE SOFTWARE.

@if "%DEBUG%"=="" @echo off

@setlocal DisableDelayedExpansion EnableExtensions

@set PROGRAM=androidl
@set VERSION=1.0.3+dev
@set DESCRIPTION=Accepts licenses for all available packages of Android SDK.

@goto :main


:generate_filename (*filename, prefix = "", suffix = "")
    setlocal

    set timestamp=
    for /f "skip=1 delims=.-+ " %%t in ('wmic os get localdatetime 2^>nul') do (
        set "timestamp=%%t"
        goto :break
    )
    :break

    if not "%~2"=="" (set "prefix=%~2-") else (set "prefix=")
    if not "%~3"=="" (set "suffix=-%~3") else (set "suffix=")

    set filename=%prefix%%timestamp%%suffix%

    endlocal & set "%~1=%filename%" & goto :EOF

:create_stream #[io] (*file, content, lines = 2)
    setlocal EnableDelayedExpansion

    set temporary=%TEMP%
    if "%temporary%"=="" set temporary=.
    for %%i in ("%temporary%") do set temporary=%%~fi

    call :generate_filename filename "%PROGRAM%" "!RANDOM!"
    set extension=.yes

    set stream=%temporary%\%filename%%extension%
    type nul >"%stream%" 2>nul

    set /a "lines=%~3" 2>nul || set /a "lines=2" >nul 2>&1
    if not "%~2"=="" for /l %%u in (1, 1, %lines%) do >>"%stream%" 2>nul echo:%~2

    endlocal & set "%~1=%stream%" & goto :EOF

:delete_stream #[io] (*file)
    setlocal EnableDelayedExpansion

    set stream=!%~1!
    if exist "%stream%" del /f /q "%stream%" 2>nul

    endlocal & goto :EOF

:find_android_sdk_root (*sdk_root)
    setlocal

    :: https://developer.android.com/studio/command-line/variables#envar
    if not defined ANDROID_HOME (
        @rem Default Windows installation location, perhaps?
        set ANDROID_HOME=%LOCALAPPDATA%\Android\Sdk
    ) else (
        @rem Deprecated, but does it exist AND contain a valid SDK installation?
        @rem https://stackoverflow.com/q/16606301/6724141#comment109828062_20421751
        if not exist "%ANDROID_HOME%\platforms\*" (
            set ANDROID_HOME=%LOCALAPPDATA%\Android\Sdk
        )
    )

    :: https://developer.android.com/studio/command-line/variables
    if not defined ANDROID_SDK_ROOT (
        call :warning "ANDROID_SDK_ROOT not defined, using: %ANDROID_HOME%"
        set ANDROID_SDK_ROOT=%ANDROID_HOME%
    )

    set sdk_root=%ANDROID_SDK_ROOT:"=%

    endlocal & set "%~1=%sdk_root%" & goto :EOF

:find_sdkmanager (*sdkmanager) -> errorlevel
    setlocal

    set binary=sdkmanager.bat

    :: Take 1: try to find `sdkmanager` in our PATH (or in this directory)
    set sdkmanager=%binary%
    call :is_command_available "%sdkmanager%" && goto :sdkmanager_exists

    :: Take 2: check whether we can find `sdkmanager` from ANDROID_SDK_ROOT
    call :find_android_sdk_root android_sdk_root

    :: Take 2a: latest SDK Command-Line Tools package directory
    :: https://developer.android.com/studio/command-line/#tools-sdk
    set sdkmanager=%android_sdk_root%\cmdline-tools\latest\bin\%binary%
    if exist "%sdkmanager%" goto :sdkmanager_exists

    :: Take 2b: legacy SDK Tools package directory (last revision: 26.1.1)
    :: https://developer.android.com/studio/releases/sdk-tools
    set sdkmanager=%android_sdk_root%\tools\bin\%binary%
    if exist "%sdkmanager%" goto :sdkmanager_exists

    set /a code=0

    :sdkmanager_exists
        call "%sdkmanager%" --version >nul 2>&1
        set /a code=%ERRORLEVEL%

    endlocal & set "%~1=%sdkmanager%" & exit /b %code%

:accept_licenses (*sdkmanager, *licenses)
    setlocal EnableDelayedExpansion

    set /a offset=2 + 5 &:: total licenses (2 tokens) + info string (5 tokens)
    call :count_licenses %~1 licenses offset

    if %licenses% gtr 0 (
        @rem Account for 'Review licenses that have not been accepted (y/N)?'
        set /a prompts=licenses + 1

        call :create_stream stream "y" !prompts!
        call "!%~1!" --licenses <"!stream!" >nul 2>&1
        call :delete_stream stream
    ) else (
        set /a licenses=0
    )

    endlocal & set "%~2=%licenses%" & goto :EOF

:count_licenses (*sdkmanager, *licenses, *offset)
    setlocal EnableDelayedExpansion

    set "pattern=SDK package license"

    set "echo=echo:N"
    set "call=call "!%~1!" --licenses 2^^>nul"
    set "find=find /i "%pattern%" 2^>nul"

    set "command=%echo%^|%call%^|%find%"
    set /a length=0

    for /f "usebackq eol= tokens=*" %%i in (`%command%`) do (
        @rem Can be potentially nasty if the command's output contains
        @rem exclamation marks, but so far Google has never put them there.
        @rem If it ever becomes an issue: https://stackoverflow.com/a/8162578
        set "line=%%i"

        for %%l in ("!LF!") do (
            for /f "eol= " %%w in ("!line: =%%~l!") do (
                set /a length+=1
                set tokens[!length!]=%%w
            )
        )
    )

    set /a token_index=length - %~3
    set token=!tokens[%token_index%]!

    :: Sanitize this, as it most likely contains a carriage return character
    set /a "licenses=%token%" 2>nul || set /a "licenses=0" >nul 2>&1

    endlocal & set "%~2=%licenses%" & goto :EOF

:is_command_available (command) -> errorlevel
    where /q "%~1" 2>nul

    goto :EOF

:is_windows_10_or_higher () -> errorlevel
    ::      A short list of common Windows versions:
    ::
    :: +--------------+-----------+---------+------------+
    :: | Product name | ReleaseId | Version |   Semver   |
    :: +--------------+-----------+---------+------------+
    :: |  Windows 10  |   1507    |         | 10.0.10240 |
    :: |              |   1511    |         |      10586 |
    :: |              |   1607    |         |      14393 |
    :: |              |   1703    |         |      15063 |
    :: |              |   1709    |         |      16299 |
    :: |              |   1803    |         |      17134 |
    :: |              |   1809    |         |      17763 |
    :: |              |   1903    |         |      18362 |
    :: |              |   1909    |         |      18363 |
    :: |              |   2004    |         |      19041 |
    :: |              |   2009    |  20H2   |      19042 |
    :: |              |           |  21H1   |      19043 |
    :: |              |           |  21H2   |      19044 |
    :: |  Windows 11  |   2009    |  21H2   | 10.0.22000 |
    :: +--------------+-----------+---------+------------+
    ::
    :: Thus, "[Version 10." from `ver` will match Windows 11 and higher as well.

    ver | find /i "[Version 10." >nul 2>&1

    goto :EOF

:setup #[global] ()
    call :setup_colors
    call :setup_term
    call :setup_title

    goto :EOF

:setup_colors #[global] ()
    for /f "usebackq" %%c in (`echo:prompt $E^| cmd "" 2^>nul`) do set esc=%%c

    if not defined ClientName call :is_windows_10_or_higher && (
        set RED=%esc%[31m
        set GREEN=%esc%[32m
        set YELLOW=%esc%[33m
        set RESET=%esc%[0m
    ) || (
        set RED=
        set GREEN=
        set YELLOW=
        set RESET=
    )

    set "esc=" & goto :EOF

:setup_term #[global] ()
    if defined ClientName set UNATTENDED=true

    set LF=^


    goto :EOF

:setup_title #[title] ()
    :: Arcane method of detecting whether our session is an indirect cmd.exe one
    if not "%CMDCMDLINE:"=%"=="%ComSpec:"=% " title %PROGRAM% %VERSION%

    goto :EOF

:error #[io] (message)
    >&2 echo:%RED%%~1%RESET%

    goto :EOF

:warning #[io] (message)
    >&2 echo:%YELLOW%%~1%RESET%

    goto :EOF

:info #[io] (message)
    echo:%GREEN%%~1%RESET%

    goto :EOF

:halt #[sync] (timeout = -1)
    timeout /t "%~1" 2>nul || timeout /t -1 2>nul

    goto :EOF

:version
    :: Assume we're running in the context of the project - from a subdirectory
    if not "%VERSION%"=="%VERSION:+dev=%" for %%i in ("%~dp0.\..") do (
        if exist "%%~fi\.git\*" call :is_command_available "git" && (
            for /f %%c in ('git rev-parse --quiet --verify HEAD 2^>nul') do (
                set "VERSION=%VERSION%.%%c"
            )
        )
    )

    echo:%PROGRAM% %VERSION%

    exit /b 0

:usage
    echo:Usage: %PROGRAM% [-h] [-u] [--version]
    echo:    %DESCRIPTION%
    echo:
    echo:    Optional arguments:
    echo:      -h, --help        show this help message and exit
    echo:      -u, --unattended  run this script unattended (don't halt)
    echo:      --version         output version information and exit
    echo:
    echo:    Exit status:
    echo:      0                 successful program execution
    echo:      1                 this dialog was displayed
    echo:      2                 incorrect command line usage
    echo:      3                 sdkmanager discovery failed
    echo:      4                 sdkmanager execution failed

    exit /b 1

:parse_error
    >&2 echo:%SCRIPT%: error: unrecognized argument combination: %*
    >&2 echo:Try '%PROGRAM% --help' for more information.

    exit /b 2

:failed_discovery
    call :error "%SCRIPT%: error: sdkmanager discovery failed:"
    call :error
    call :error "    - `sdkmanager` command could not be found in your PATH;"
    call :error "    - ANDROID_SDK_ROOT was not set or was set incorrectly"
    call :error
    call :error "Last location checked: %SDKMANAGER%"

    if not "%UNATTENDED%"=="true" call :halt

    exit /b 3

:failed_execution
    call :error "%SCRIPT%: error: sdkmanager execution failed (exit code: %ERRORLEVEL%)"

    if not "%UNATTENDED%"=="true" call :halt

    exit /b 4

:main
    set SCRIPT=%~n0

    if "%~1"=="-h"           goto :usage
    if "%~1"=="--help"       goto :usage
    if "%~1"=="--version"    goto :version

    if not "%~2"==""                                                 goto :parse_error
    if not "%~1"=="" if not "%~1"=="--unattended" if not "%~1"=="-u" goto :parse_error

    set UNATTENDED=
    if "%~1"=="--unattended" set UNATTENDED=true
    if "%~1"=="-u"           set UNATTENDED=true

    call :setup

    call :find_sdkmanager SDKMANAGER
    if %ERRORLEVEL% equ 9009 goto :failed_discovery
    if %ERRORLEVEL% neq 0    goto :failed_execution

    call :accept_licenses SDKMANAGER licenses

    if %licenses% gtr 0 (
        call :info "All (%licenses%) SDK package licenses have been accepted."
    ) else (
        call :info "There are no SDK package licenses to accept."
    )

    if not "%UNATTENDED%"=="true" call :halt 3

@endlocal & exit /b 0

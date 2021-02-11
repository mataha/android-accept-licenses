@if "%DEBUG%"=="" @echo off
::
:: Copyright (c) 2021 mataha <mataha@users.noreply.github.com>
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
::
@setlocal DisableDelayedExpansion EnableExtensions

set PROGRAM=%~n0
set VERSION=0.0.1

if not "%~2"==""            goto :usage &:: only one argument allowed
if /i "%~1"=="-h"           goto :usage
if /i "%~1"=="--help"       goto :usage
if /i "%~1"=="-?"           goto :usage
if /i "%~1"=="--version"    goto :version
if /i "%~1"=="-u"           set UNATTENDED=true
if /i "%~1"=="--unattended" set UNATTENDED=true
set LF=^


goto :main


:create_stream &:: (*file, lines)
    @setlocal EnableDelayedExpansion

    set __extension=.yes

    set __temp=%TEMP%
    if "%__temp%"=="" set __temp=.
    for %%i in ("%__temp%") do set __temp=%%~fi

    for /l %%u in (0, 1, 5) do set __filename=!__filename!!RANDOM!
    set __stream=%__temp%\%__filename%%__extension%
    type nul >%__stream% 2>nul

    set __fill=y
    for /l %%u in (1, 1, %~2) do echo:%__fill%>>%__stream%

    @endlocal & set "%~1=%__stream%" & goto :EOF

:delete_stream &:: (file)
    if not "%~1"=="" del /f /q "%~1" 2>nul

    goto :EOF

:find_sdkmanager &:: (*sdkmanager) |> errorlevel
    @setlocal

    :: Take 1: try to find `sdkmanager` in our PATH (or in this directory)
    set __sdkmanager=sdkmanager.bat
    where /q %__sdkmanager% 2>nul && goto :command_exists

    :: Take 2: check if we can find `sdkmanager` command from ANDROID_SDK_ROOT
    :: https://developer.android.com/studio/command-line/variables#envar
    if not defined ANDROID_HOME (
        @rem Default Windows installation location, perhaps?
        set ANDROID_HOME=%LOCALAPPDATA%\Android\Sdk
    ) else (
        if not exist "%ANDROID_HOME%\.knownPackages" (
            set ANDROID_HOME=%LOCALAPPDATA%\Android\Sdk
        )
    )
    :: https://developer.android.com/studio/command-line/variables
    if not defined ANDROID_SDK_ROOT (
        call :warning "ANDROID_SDK_ROOT not defined, using: %ANDROID_HOME%"
        set ANDROID_SDK_ROOT=%ANDROID_HOME%
    )
    set __android_sdk_root=%ANDROID_SDK_ROOT:"=%

    :: Take 2a: latest SDK Command-Line Tools package directory
    :: https://developer.android.com/studio/command-line/#tools-sdk
    set __sdkmanager=%__android_sdk_root%\cmdline-tools\latest\bin\sdkmanager.bat
    if exist "%__sdkmanager%" goto :command_exists

    :: Take 2b: legacy SDK Tools package directory (last revision: 26.1.1)
    :: https://developer.android.com/studio/releases/sdk-tools
    set __sdkmanager=%__android_sdk_root%\tools\bin\sdkmanager.bat
    if exist "%__sdkmanager%" goto :command_exists

    :command_exists
        call %__sdkmanager% --version >nul 2>&1
        set __errorlevel=%ERRORLEVEL%

    endlocal & set "%~1=%__sdkmanager%" & exit /b %__errorlevel%

:accept_licenses &:: (sdkmanager)
    @setlocal

    set /a __offset=2 + 5
    call :count_licenses "%~1" "licenses" %__offset%

    if %licenses% equ 0 (
        call :info "There are no SDK package licenses to accept."
        @endlocal & goto :EOF
    )

    :: Account for 'Review licenses that have not been accepted (y/N)?' prompt
    set /a __prompts=licenses + 1

    call :create_stream "stream" %__prompts%
    call "%~1" --licenses <"%stream%" >nul 2>&1 &:: Always returns 0 unless ^C
    call :delete_stream "%stream%"

    call :info "All (%licenses%) SDK package licenses have been accepted."

    @endlocal & goto :EOF

:count_licenses &:: (sdkmanager, *licenses, offset)
    @setlocal EnableDelayedExpansion

    set "__pattern=SDK package license"

    set "__echo=echo:N"
    set "__call=call "%~1" --licenses 2^>nul"
    set "__find=find /i "%__pattern%" 2^>nul"

    set "__command=%__echo%^|%__call%^|%__find%"

    for /f "usebackq eol= tokens=*" %%i in (`%__command%`) do (
        @rem Can be potentially nasty if the command's output contains
        @rem exclamation marks, but so far Google has never put them there.
        @rem If it ever becomes an issue: https://stackoverflow.com/a/8162578
        set "__line=%%i"

        set /a __length=0

        for %%l in ("!LF!") do (
            for /f "eol= " %%w in ("!__line: =%%~l!") do (
                set /a __length+=1
                set __tokens[!__length!]=%%w
            )
        )
    )

    set /a __token_index=__length - %~3
    set __token=!__tokens[%__token_index%]!

    :: Sanitize this, as it most likely contains a carriage return character
    set /a "__licenses=%__token%" 2>nul || set /a __licenses=0

    @endlocal & set "%~2=%__licenses%" & goto :EOF

:setup_colors
    ver | find /i "Version 10.0" >nul 2>&1 && if not defined ClientName (
        set RED=[31m
        set GREEN=[32m
        set YELLOW=[33m
        set RESET=[0m
    ) || (
        set RED=
        set GREEN=
        set YELLOW=
        set RESET=
    )

    goto :EOF

:setup_term
    :: If we're not running directly from a terminal, just stay unattended
    if defined ClientName if not defined SESSIONNAME set UNATTENDED=true

    goto :EOF

:setup_title
    :: Arcane method of detecting whether our session isn't a direct cmd.exe one
    if not "%CMDCMDLINE:"=%"=="%ComSpec:"=% " title %PROGRAM% %VERSION%

    goto :EOF

:error &:: (message)
    >&2 echo:%RED%%~1%RESET%

    goto :EOF

:warning &:: (message)
    >&2 echo:%YELLOW%%~1%RESET%

    goto :EOF

:info &:: (message)
    echo:%GREEN%%~1%RESET%

    goto :EOF

:halt
    @setlocal

    set /a __=3 &:: same delay as `ping [-n 4] localhost`

    set /a "__timeout=%~1" 2>nul || set /a __timeout=__
    if %__timeout% equ 0 if not 0%1 equ 00 set /a __timeout=__

    timeout /t %__timeout% 2>nul

    @endlocal & goto :EOF

:stop
    if not "%UNATTENDED%"=="true" call :halt

    goto :EOF

:version
    echo:%VERSION%

    exit /b 0

:usage
    echo:Usage: %PROGRAM% [-h ^| -u ^| --version]
    echo:    Accepts licenses for all available packages of Android SDK.
    echo:
    echo:    Optional arguments:
    echo:      -h, --help, -?    show this help message and exit
    echo:      -u, --unattended  run this script unattended (don't halt)
    echo:      --version         output version information and exit
    echo:
    echo:    Exit status:
    echo:      0                 successful program execution
    echo:      1                 this dialog was displayed
    echo:      2                 sdkmanager discovery failed
    echo:      3                 sdkmanager execution failed

    exit /b 1

:failed_discovery
    call :error "Error: sdkmanager discovery failed:"
    call :error
    call :error "    - `sdkmanager` command could not be found in your PATH;"
    call :error "    - ANDROID_SDK_ROOT was not set or was set incorrectly"
    call :error
    call :error "Last location checked: %SDKMANAGER%"

    call :stop

    exit /b 2

:failed_execution
    call :error "Error: sdkmanager execution failed (exit code: %ERRORLEVEL%)"

    call :stop

    exit /b 3

:setup
    call :setup_colors
    call :setup_term
    call :setup_title

    goto :EOF

:main
    call :setup

    call :find_sdkmanager "SDKMANAGER"
    if %ERRORLEVEL% equ 9009 goto :failed_discovery
    if %ERRORLEVEL% neq 0    goto :failed_execution

    call :accept_licenses "%SDKMANAGER%"

    call :stop

@endlocal & exit /b 0

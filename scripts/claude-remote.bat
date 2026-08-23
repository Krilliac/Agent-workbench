@echo off
REM claude-remote.bat — launch a Claude Code session with remote-control
REM   mirroring active, so it shows up in the phone Claude app.
REM
REM Usage:
REM   claude-remote                          run in current dir, label = dir name
REM   claude-remote "C:\path\to\repo"        cd there, label = folder name
REM   claude-remote "C:\path\to\repo" "Foo"  cd there, label = "Foo"

setlocal EnableDelayedExpansion

set "REPO=%~1"
if "%REPO%"=="" set "REPO=%CD%"

set "NAME=%~2"
if "%NAME%"=="" (
    for %%A in ("%REPO%") do set "NAME=%%~nxA"
)

if not exist "%REPO%\" (
    echo [claude-remote] Path not found: %REPO%
    exit /b 1
)

echo [claude-remote] Repo:  %REPO%
echo [claude-remote] Label: %NAME%
echo [claude-remote] Launching Claude Code with --remote-control...
echo.

cd /d "%REPO%"
claude --remote-control "%NAME%"

endlocal

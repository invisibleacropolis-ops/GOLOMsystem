@echo off
@echo off
setlocal
REM Thin wrapper that forwards to the PowerShell runner with all args.
set SCRIPT_DIR=%~dp0
set PS1=%SCRIPT_DIR%godot4.ps1
set POWERSHELL=pwsh.exe
where %POWERSHELL% >NUL 2>&1
if errorlevel 1 set POWERSHELL=powershell.exe

"%POWERSHELL%" -NoProfile -ExecutionPolicy Bypass -File "%PS1%" %*
set EXITCODE=%ERRORLEVEL%
endlocal & exit /b %EXITCODE%

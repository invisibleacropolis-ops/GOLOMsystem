@echo off
REM Open the Windows editor using the PowerShell wrapper, with logging.
setlocal
set "PS_EXE=pwsh"
where %PS_EXE% >nul 2>&1 || set "PS_EXE=powershell"
"%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0open_editor.ps1" %*

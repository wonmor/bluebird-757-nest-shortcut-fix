@echo off
rem Removes the shortcuts and the run-as-administrator flag created by Install-NestShortcut.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-NestShortcut.ps1" -Uninstall
echo.
pause

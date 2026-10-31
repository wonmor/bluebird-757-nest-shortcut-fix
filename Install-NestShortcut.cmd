@echo off
rem Double-click launcher: runs Install-NestShortcut.ps1 from this folder, passing any arguments through.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-NestShortcut.ps1" %*
echo.
pause

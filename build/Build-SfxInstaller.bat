@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Build-SfxInstaller.ps1"
echo.
pause

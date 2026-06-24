@echo off
setlocal
set "DEST=%USERPROFILE%\Downloads\Godot Installer"
if not exist "%DEST%" mkdir "%DEST%"
xcopy "%~dp0*.*" "%DEST%\" /Y /I /Q
del "%DEST%\_bootstrap.bat" >nul 2>&1
start "" "%DEST%\Godot Install Menu.bat"
endlocal

@echo off
if exist "%~dp0scripts\Godot Install Menu.ps1" (
	set "MENU_PS1=%~dp0scripts\Godot Install Menu.ps1"
) else (
	set "MENU_PS1=%~dp0Godot Install Menu.ps1"
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%MENU_PS1%"
exit

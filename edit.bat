@echo off
setlocal
set HERE=%~dp0
if "%GODOT%"=="" set GODOT=%USERPROFILE%\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64.exe
if not exist "%GODOT%" (
	echo edit: Godot not found at %GODOT%, set GODOT=path\to\godot.exe
	pause
	exit /b 2
)
start "" "%GODOT%" --path "%HERE%project" --editor
endlocal

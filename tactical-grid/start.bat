@echo off
chcp 65001 >nul
echo ============================================
echo  Tactical Grid - Development Launcher
echo ============================================
echo.

set PROJECT_DIR=%~dp0
set CLIENT_DIR=%PROJECT_DIR%client

REM Allow overriding the Godot executable via environment variable
if defined GODOT_PATH (
    set GODOT_EXE=%GODOT_PATH%
) else (
    REM Common install locations for Godot 4.7.1
    if exist "D:\Program Files\Godot\Godot_v4.7.1-stable_win64.exe" (
        set GODOT_EXE="D:\Program Files\Godot\Godot_v4.7.1-stable_win64.exe"
    ) else if exist "D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe" (
        set GODOT_EXE="D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe"
    ) else if exist "%LOCALAPPDATA%\Godot\Godot_v4.7.1-stable_win64.exe" (
        set GODOT_EXE="%LOCALAPPDATA%\Godot\Godot_v4.7.1-stable_win64.exe"
    ) else (
        echo ERROR: Could not find Godot 4.7.1 executable.
        echo Please install Godot 4.7.1 or set GODOT_PATH to the executable.
        pause
        exit /b 1
    )
)

echo Using Godot: %GODOT_EXE%
echo Project: %CLIENT_DIR%\project.godot
echo.

echo [1/1] Opening Godot editor...
echo.

start "" %GODOT_EXE% -e "%CLIENT_DIR%\project.godot"

echo.
echo ============================================
echo  Godot editor should open shortly.
echo  Use F5 or the Play button to run the game.
echo  This script is for development only.
echo ============================================
echo.
pause

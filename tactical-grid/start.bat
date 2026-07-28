@echo off
chcp 65001 >nul
echo ============================================
echo  Tactical Grid - Development Launcher
echo ============================================
echo.

set PROJECT_DIR=%~dp0
set CLIENT_DIR=%PROJECT_DIR%client
set SERVER_DIR=%PROJECT_DIR%server

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

REM Optional: start backend server in a new window for backend/mapgen development
if "%1"=="--with-server" (
    echo [1/2] Starting backend server for development...
    start "TacticalGrid-Server" cmd /k "cd /d %SERVER_DIR% && set JWT_SECRET=dev-secret && npx tsx src/index.ts"
    timeout /t 4 /nobreak >nul
    curl -s http://localhost:3000/health >nul 2>&1
    if %errorlevel% == 0 (
        echo    Server OK on http://localhost:3000
    ) else (
        echo    Server not ready yet; the editor will still open.
    )
    echo.
    echo [2/2] Opening Godot editor...
) else (
    echo [1/1] Opening Godot editor...
    echo Tip: run with --with-server to also start the Node backend.
    echo.
)

start "" %GODOT_EXE% -e "%CLIENT_DIR%\project.godot"

echo.
echo ============================================
echo  Godot editor should open shortly.
echo  Use F5 or the Play button to run the game.
echo  This script is for development only.
echo ============================================
echo.
pause

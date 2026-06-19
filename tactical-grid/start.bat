@echo off
chcp 65001 >nul 2>&1
echo ============================================
echo  Tactical Grid - One-Click Start
echo ============================================
echo.

REM Check Node.js
where node >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Node.js not found. Please install Node.js 18+
    pause
    exit /b 1
)

REM Install dependencies if needed
if not exist "%~dp0server\node_modules" (
    echo [0/3] Installing dependencies...
    cd /d "%~dp0server"
    call npm install
    if %errorlevel% neq 0 (
        echo [ERROR] npm install failed
        pause
        exit /b 1
    )
)

REM Start backend server in new window
echo [1/3] Starting backend server...
start "TacticalGrid-Server" cmd /k "cd /d %~dp0server && npm run dev"

REM Wait for server to start
echo [2/3] Waiting for server...
timeout /t 5 /nobreak >nul

REM Test server
curl -s http://localhost:3000/health >nul 2>&1
if %errorlevel% == 0 (
    echo    Server OK - http://localhost:3000
) else (
    echo    Server may still be starting...
)

REM Open Godot project
echo [3/3] Opening Godot project...
echo.
echo ============================================
echo  Instructions:
echo  1. Server is running on http://localhost:3000
echo  2. Open Godot 4.2+ editor
echo  3. Open project: client/project.godot
echo  4. Press F5 to run the game
echo ============================================
echo.

REM Try to find and open Godot
set GODOT_PATH=
if exist "%~dp0Godot*.exe" (
    for %%f in ("%~dp0Godot*.exe") do set GODOT_PATH=%%f
) else if exist "%~dp0..\Godot*.exe" (
    for %%f in ("%~dp0..\Godot*.exe") do set GODOT_PATH=%%f
) else if exist "%ProgramFiles%\Godot\Godot*.exe" (
    for %%f in ("%ProgramFiles%\Godot\Godot*.exe") do set GODOT_PATH=%%f
)

if defined GODOT_PATH (
    start "" "%GODOT_PATH%" -e "%~dp0client\project.godot"
    echo Godot editor opened.
) else (
    echo Godot not found in common locations.
    echo Please open Godot manually and load: %~dp0client\project.godot
)

echo.
pause

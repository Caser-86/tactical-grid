@echo off
echo ============================================
echo  Tactical Grid - One-Click Start
echo ============================================
echo.

REM Start backend server in new window
echo [1/3] Starting backend server...
start "TacticalGrid-Server" cmd /k "cd /d %~dp0server && set JWT_SECRET=dev-secret && npx tsx src/index.ts"

REM Wait for server to start
timeout /t 4 /nobreak >nul

REM Test server
echo [2/3] Testing server...
curl -s http://localhost:3000/health >nul 2>&1
if %errorlevel% == 0 (
    echo    Server OK
) else (
    echo    Server may not be ready, but Godot will still work
)

REM Open Godot project
echo [3/3] Opening Godot project...
start "" "%~dp0..\Godot_v4.6.3-stable_win64.exe" -e "%~dp0client\project.godot"

echo.
echo ============================================
echo  Done!
echo  - Server running on http://localhost:3000
echo  - Godot editor should open shortly
echo  - Press F5 in Godot to run the game
echo ============================================
echo.
pause

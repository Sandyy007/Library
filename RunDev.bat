@echo off
title Library Management System - Development Mode
echo ===============================================
echo   Library Management System - Development Mode
echo ===============================================
echo.

REM Navigate to project root
cd /d "%~dp0"

echo Starting Backend Server in background...
start "Backend Server" cmd /c "cd backend && node server.js"

echo Waiting for backend to start...
timeout /t 3 /nobreak >nul

echo.
echo Starting Flutter App...
cd flutter_app
flutter run -d windows

echo.
echo Stopping Backend Server...
for /f "tokens=1,2,3,4,5" %%a in ('netstat -ano ^| findstr /R /C:":3000 .*LISTENING"') do (
    set PID=%%e
)
if defined PID (
    echo Stopping backend process PID %PID%...
    taskkill /PID %PID% /F >nul 2>nul
)

echo.
echo Development session ended.
pause

@echo off
title Library Management System - Backend Server
cd /d "%~dp0"
echo ===============================================
echo   Library Management System - Backend Server
echo ===============================================
echo.
echo Starting backend server on http://localhost:3000
echo Press Ctrl+C to stop the server
echo.
if exist "server.js" (
    node server.js
) else if exist "dist\server.js" (
    node dist\server.js
) else (
    echo No compiled server found. Run "npm run build" first.
)
if errorlevel 1 (
    echo.
    echo Error: Backend server failed to start.
    echo Please ensure Node.js is installed and in your PATH.
    pause
)
pause

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
node server.js
if errorlevel 1 (
    echo.
    echo Error: Backend server failed to start.
    echo Please ensure Node.js is installed and in your PATH.
    pause
)
pause

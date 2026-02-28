@echo off
title Library Management System - Build Release
echo ===============================================
echo   Library Management System - Build Release
echo ===============================================
echo.

REM Navigate to project root
cd /d "%~dp0"

echo Step 1: Building Flutter Windows application...
echo.
cd flutter_app
call flutter clean
call flutter pub get
call flutter build windows --release
if errorlevel 1 (
    echo.
    echo ERROR: Flutter build failed!
    pause
    exit /b 1
)
cd ..

echo.
echo Step 2: Installing backend dependencies...
echo.
cd backend
call npm install --production
if errorlevel 1 (
    echo.
    echo ERROR: npm install failed!
    pause
    exit /b 1
)
cd ..

echo.
echo Step 3: Running Flutter analyze...
echo.
cd flutter_app
call flutter analyze
cd ..

echo.
echo ===============================================
echo   Build completed successfully!
echo ===============================================
echo.
echo Next steps:
echo 1. Test the application by running flutter_app/build/windows/x64/runner/Release/library_management_app.exe
echo 2. Create the installer using Inno Setup Compiler with installer.iss
echo.
pause

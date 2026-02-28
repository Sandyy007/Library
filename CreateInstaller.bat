@echo off
title Library Management System - Create Installer
echo ===============================================
echo   Library Management System - Create Installer
echo ===============================================
echo.

REM Navigate to project root
cd /d "%~dp0"

REM Check if Inno Setup is installed
set ISCC=
where iscc >nul 2>nul
if %errorlevel% equ 0 (
    set ISCC=iscc
) else if exist "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" (
    set "ISCC=C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
) else if exist "C:\Program Files\Inno Setup 6\ISCC.exe" (
    set "ISCC=C:\Program Files\Inno Setup 6\ISCC.exe"
) else (
    echo ERROR: Inno Setup Compiler (ISCC.exe) not found!
    echo.
    echo Please install Inno Setup 6 from: https://jrsoftware.org/isdl.php
    echo Or add ISCC.exe to your PATH environment variable.
    pause
    exit /b 1
)

echo Found Inno Setup Compiler: %ISCC%
echo.

echo Checking for required files...
if not exist "flutter_app\build\windows\x64\runner\Release\library_management_app.exe" (
    echo.
    echo ERROR: Flutter build not found!
    echo Please run BuildRelease.bat first to build the application.
    pause
    exit /b 1
)

if not exist "backend\server.js" (
    echo.
    echo ERROR: Backend server.js not found!
    pause
    exit /b 1
)

if not exist "backend\node_modules" (
    echo.
    echo WARNING: backend/node_modules not found!
    echo Running npm install...
    cd backend
    call npm install --production
    cd ..
)

echo.
echo Creating installer...
"%ISCC%" installer.iss
if errorlevel 1 (
    echo.
    echo ERROR: Installer creation failed!
    pause
    exit /b 1
)

echo.
echo ===============================================
echo   Installer created successfully!
echo ===============================================
echo.
echo Output location: installer_output\
dir /b installer_output\*.exe
echo.
pause

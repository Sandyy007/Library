@echo off
REM Run from the directory where this script lives
cd /d %~dp0

set PORT=3000

echo Checking for existing server on port %PORT%...
for /f "tokens=1,2,3,4,5" %%a in ('netstat -ano ^| findstr /R /C:":%PORT% .*LISTENING"') do (
	set PID=%%e
)
if defined PID (
	echo Stopping existing process PID %PID% on port %PORT%...
	taskkill /PID %PID% /F >nul 2>nul
	set PID=
	timeout /t 1 /nobreak >nul
)

REM Start the server in the background
echo Starting Backend Server...
start "" /B cmd /c "node server.js > server_test.log 2>&1"

REM Wait for server to start
timeout /t 3 /nobreak >nul

REM Run API tests
echo.
echo Running API Tests...
node test_all_apis.js

echo.
echo Stopping Backend Server on port %PORT%...
for /f "tokens=1,2,3,4,5" %%a in ('netstat -ano ^| findstr /R /C:":%PORT% .*LISTENING"') do (
	set PID=%%e
)
if defined PID (
	taskkill /PID %PID% /F >nul 2>nul
	set PID=
)

REM Keep window open only for interactive/manual runs
if /i "%~1"=="--pause" pause

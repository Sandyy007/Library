@echo off
setlocal

REM Starts backend in a new window, then starts the Flutter Windows EXE.

set "ROOT=%~dp0..\..\"
set "APP_EXE=%ROOT%app\library_management_app.exe"

REM Start backend in separate console
start "Library Backend" cmd /c "%~dp0start_backend.bat"

REM Small delay to let backend bind port
timeout /t 2 /nobreak >nul

if exist "%APP_EXE%" (
  echo Launching app: %APP_EXE%
  start "Library App" "%APP_EXE%"
) else (
  echo ERROR: Cannot find app EXE at: %APP_EXE%
  echo Expected you to copy Flutter Release output into: %ROOT%app\
  pause
)

endlocal

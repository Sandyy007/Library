@echo off
setlocal

REM Starts the backend API (expects Node runtime available).
REM If you bundle a portable Node, set NODE_EXE to its path.

set "ROOT=%~dp0..\..\"
set "BACKEND_DIR=%ROOT%backend"

REM Prefer a bundled portable Node if present
set "NODE_EXE=%ROOT%runtime\node\node.exe"
if not exist "%NODE_EXE%" set "NODE_EXE=node"

echo Starting backend from: %BACKEND_DIR%
pushd "%BACKEND_DIR%"
%NODE_EXE% server.js
popd

endlocal

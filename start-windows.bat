@echo off
echo Starting USB Token Server on Windows...
echo.

REM Check if Node.js is installed
node --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Node.js is not installed or not in PATH
    echo Please install Node.js from https://nodejs.org/
    pause
    exit /b 1
)

REM Check if npm dependencies are installed
if not exist "node_modules" (
    echo Installing Node.js dependencies...
    npm install
    if errorlevel 1 (
        echo ERROR: Failed to install dependencies
        pause
        exit /b 1
    )
)

REM Set environment variables for Windows
set NODE_ENV=development
set PORT=3000
set CORS_ORIGIN=*
set LOG_LEVEL=info
set PKCS11_MODULE=C:\Windows\System32\opensc-pkcs11.dll

REM Create temp directory if it doesn't exist
if not exist "temp" mkdir temp
if not exist "logs" mkdir logs

echo.
echo USB Token Server Configuration:
echo - Port: %PORT%
echo - PKCS11 Module: %PKCS11_MODULE%
echo - Environment: %NODE_ENV%
echo.

REM Start the server
echo Starting server...
node server.js

pause

@echo off
:: setup.cmd : double-click friendly entrypoint for setup.ps1.
:: Self-elevates and bypasses ExecutionPolicy for this process only.

setlocal
set HERE=%~dp0

:: Self-elevate to admin if not already.
net session >nul 2>&1
if %errorlevel% NEQ 0 (
    echo Requesting admin (UAC prompt)...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:: Now running as admin. Launch setup.ps1 with policy bypass.
powershell -NoProfile -ExecutionPolicy Bypass -File "%HERE%setup.ps1" %*
endlocal

@echo off
:: Self-elevating: if not admin, relaunch via PowerShell with UAC prompt
net session >nul 2>&1
if %errorlevel% NEQ 0 (
    echo Needs admin to edit hosts file. Re-launching with UAC prompt...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:: Now running as admin
set HOSTS=%SystemRoot%\System32\drivers\etc\hosts
findstr /C:"license.unity3d.com" "%HOSTS%" >nul 2>&1
if %errorlevel% EQU 0 (
    echo Already blocked.
) else (
    echo Adding block for license.unity3d.com...
    echo.>> "%HOSTS%"
    echo # Unity 4.6.5 offline license fallback >> "%HOSTS%"
    echo 0.0.0.0 license.unity3d.com >> "%HOSTS%"
    echo Done. Unity will now use the offline .ulf license.
)

:: Flush DNS so the change takes effect immediately
ipconfig /flushdns >nul

echo.
echo You can now close this window and re-launch Unity 4.6.5 via launch_unity46.bat
pause

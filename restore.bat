@echo off
setlocal

:: Self-elevating: if not admin, relaunch via PowerShell with UAC prompt
net session >nul 2>&1
if %errorlevel% NEQ 0 (
    echo Needs admin for hosts file edit. Re-launching with UAC prompt...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

set HERE=%~dp0
set UNITY_DST=%USERPROFILE%\Unity4.6.5
set MONO_CERTS=%APPDATA%\.mono\certs\Trust
set MONO_CERTS_LEGACY=%USERPROFILE%\.config\.mono\certs\Trust

echo ==================================================
echo Unity 4.6.5f1 Portable Restore
echo ==================================================
echo.

:: Step 1: Unity install
if exist "%UNITY_DST%\Unity.exe" (
    echo [1/5] Unity already at %UNITY_DST%, skipping copy.
) else (
    echo [1/5] Looking for unity-install\Unity4.6.5\ next to restore.bat...
    if exist "%HERE%unity-install\Unity4.6.5\Unity.exe" (
        echo       Found. Copying to %UNITY_DST% (this takes a few minutes)...
        robocopy "%HERE%unity-install\Unity4.6.5" "%UNITY_DST%" /MIR /NFL /NDL /NP /MT:8 >nul
    ) else (
        echo       NOT FOUND.
        echo       Either download the Unity 4.6.5f1 installer from Unity's archive
        echo       (https://unity.com/releases/editor/archive) and install normally,
        echo       or place a trimmed install at %HERE%unity-install\Unity4.6.5\
        echo       and re-run this script.
        pause
        exit /b 1
    )
)

:: Step 2: Mono cert store (both paths)
echo [2/5] Populating Mono trust store (%MONO_CERTS%)
if not exist "%MONO_CERTS%" mkdir "%MONO_CERTS%"
copy /Y "%HERE%mono_certs\*" "%MONO_CERTS%\" >nul
if not exist "%MONO_CERTS_LEGACY%" mkdir "%MONO_CERTS_LEGACY%"
copy /Y "%HERE%mono_certs\*" "%MONO_CERTS_LEGACY%\" >nul

:: Step 3: Registry prefs (welcome screen suppression only)
echo [3/5] Importing Unity Editor 4.x registry prefs
reg import "%HERE%registry\unity_editor_4x_prefs.reg" >nul 2>&1

:: Step 4: Hosts file block (this is what stops the SSL crash)
echo [4/5] Adding hosts block for license.unity3d.com
set HOSTS=%SystemRoot%\System32\drivers\etc\hosts
findstr /C:"license.unity3d.com" "%HOSTS%" >nul 2>&1
if %errorlevel% EQU 0 (
    echo       Already blocked.
) else (
    echo.>> "%HOSTS%"
    echo # Unity 4.6.5 offline license fallback >> "%HOSTS%"
    echo 0.0.0.0 license.unity3d.com >> "%HOSTS%"
)
ipconfig /flushdns >nul

:: Step 5: Copy helper scripts to Desktop
echo [5/5] Copying helper scripts to Desktop
copy /Y "%HERE%scripts\launch_unity46.bat" "%USERPROFILE%\Desktop\" >nul
copy /Y "%HERE%scripts\block_unity_license_check.bat" "%USERPROFILE%\Desktop\" >nul

echo.
echo ==================================================
echo DONE. Launch Unity via Desktop\launch_unity46.bat
echo ==================================================
echo.
echo You must still activate your own Unity Personal license.
echo See README.md Step 4 for the manual activation flow at
echo https://license.unity3d.com/manual (sign in with your Unity ID).
echo.
echo NOTE: The hosts block just added also affects your browser, so
echo the activation URL above will not load on THIS machine until you
echo either temporarily comment out the hosts entry or do the upload
echo from a phone / second computer. README.md Step 4 has both paths.
echo.
pause

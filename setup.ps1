#requires -version 5
#
# setup.ps1 : one click installer for Unity 4.6.5f1 Portable.
#
# Run via setup.cmd (which self-elevates and sets ExecutionPolicy Bypass).
# Walks a fresh user from "nothing installed" to "Unity 4.6.5f1 opens,
# license is activated, dark skin is applied". Handles the hosts /
# browser deadlock by pausing the block during the browser activation
# step.

[CmdletBinding()]
param(
    [string]$InstallRoot = (Join-Path $env:USERPROFILE 'Unity4.6.5')
)

$ErrorActionPreference = 'Stop'
$script:Here    = $PSScriptRoot
$script:Hosts   = "$env:SystemRoot\System32\drivers\etc\hosts"
$script:UlfPath = 'C:\ProgramData\Unity\Unity_v4.x.ulf'
$script:AlfPath = (Join-Path $env:USERPROFILE 'Documents\Unity_v4.x.alf')

function Write-Banner($Title) {
    Write-Host ""
    Write-Host "===========================================================" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "===========================================================" -ForegroundColor Cyan
}

function Write-Step($N, $Total, $Title) {
    Write-Host ""
    Write-Host "[$N/$Total] $Title" -ForegroundColor Yellow
}

function Pause-Continue($Message = 'Press Enter to continue.') {
    Read-Host $Message | Out-Null
}

function Assert-Admin {
    $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object System.Security.Principal.WindowsPrincipal($id)
    if (-not $p.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "setup.ps1 must be run elevated. Launch it via setup.cmd which self-elevates."
    }
}

# ---- Phase 1: preflight ----

function Phase1-Preflight {
    Write-Step 1 5 "Preflight"

    Write-Host "  Looking for Unity at: $InstallRoot"
    $unityExe = Join-Path $InstallRoot 'Unity.exe'
    if (-not (Test-Path $unityExe)) {
        Write-Host ""
        Write-Host "  Unity 4.6.5f1 is not installed at $InstallRoot." -ForegroundColor Red
        Write-Host ""
        Write-Host "  Opening Unity's archive in your browser. Download the Unity 4.6.5f1"
        Write-Host "  Windows installer, install it normally (the default install path is fine),"
        Write-Host "  then re-run this script."
        Write-Host ""
        Start-Process 'https://unity.com/releases/editor/archive'
        Write-Host "  After Unity is installed, run setup.cmd again."
        Pause-Continue
        exit 1
    }
    Write-Host "  Found: $unityExe" -ForegroundColor Green

    Write-Host ""
    Write-Host "  This installer will:"
    Write-Host "    1. Populate the Mono trust store (so Unity 4's SSL stack can verify modern CAs)"
    Write-Host "    2. Add a hosts block for license.unity3d.com (so Unity stops self quitting)"
    Write-Host "    3. Import the editor color / keybinding / welcome screen registry prefs"
    Write-Host "    4. Walk you through activating your own free Unity Personal license"
    Write-Host "    5. Optionally apply the Pro dark editor skin patches"
    Write-Host ""
    $resp = Read-Host "  Continue? (Y/n)"
    if ($resp -and $resp -notmatch '^[Yy]') { exit 0 }
}

# ---- Phase 2: system setup ----

function Phase2-SystemSetup {
    Write-Step 2 5 "System setup (Mono certs + hosts + registry)"

    # Mono certs
    $monoDirs = @(
        "$env:APPDATA\.mono\certs\Trust",
        "$env:USERPROFILE\.config\.mono\certs\Trust"
    )
    foreach ($d in $monoDirs) {
        if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
        Copy-Item -Path (Join-Path $script:Here 'mono_certs\*.cer') -Destination $d -Force
    }
    Write-Host "  Mono trust stores populated (121 CAs)" -ForegroundColor Green

    # Registry
    $regFile = Join-Path $script:Here 'registry\unity_editor_4x_prefs.reg'
    & reg import $regFile 2>$null | Out-Null
    Write-Host "  Editor registry prefs imported" -ForegroundColor Green

    # Hosts block
    Add-HostsBlock
    Write-Host "  Hosts block added for license.unity3d.com" -ForegroundColor Green

    # Helper scripts to Desktop
    Copy-Item (Join-Path $script:Here 'scripts\launch_unity46.bat')             "$env:USERPROFILE\Desktop\" -Force
    Copy-Item (Join-Path $script:Here 'scripts\block_unity_license_check.bat')  "$env:USERPROFILE\Desktop\" -Force
    Write-Host "  Helper launch scripts copied to Desktop" -ForegroundColor Green
}

function Add-HostsBlock {
    $content = Get-Content $script:Hosts -Raw
    if ($content -match 'license\.unity3d\.com') {
        # Could be commented out (paused). Uncomment if so.
        $newContent = $content -replace '#\s*(0\.0\.0\.0\s+license\.unity3d\.com)', '$1'
        if ($newContent -ne $content) {
            Set-Content -Path $script:Hosts -Value $newContent -NoNewline
            ipconfig /flushdns | Out-Null
        }
        return
    }
    Add-Content -Path $script:Hosts -Value "`r`n# Unity 4.6.5 offline license fallback`r`n0.0.0.0 license.unity3d.com"
    ipconfig /flushdns | Out-Null
}

function Remove-HostsBlock-Temp {
    # Comments out the block lines rather than deleting them, easier to restore.
    $content = Get-Content $script:Hosts -Raw
    $newContent = $content -replace '(?m)^(0\.0\.0\.0\s+license\.unity3d\.com)\s*$', '# PAUSED $1'
    Set-Content -Path $script:Hosts -Value $newContent -NoNewline
    ipconfig /flushdns | Out-Null
}

function Restore-HostsBlock {
    $content = Get-Content $script:Hosts -Raw
    $newContent = $content -replace '#\s*PAUSED\s+(0\.0\.0\.0\s+license\.unity3d\.com)', '$1'
    Set-Content -Path $script:Hosts -Value $newContent -NoNewline
    ipconfig /flushdns | Out-Null
}

# ---- Phase 3: activation ----

function Phase3-Activation {
    Write-Step 3 5 "License activation"

    if (Test-Path $script:UlfPath) {
        Write-Host "  Existing .ulf already present at $script:UlfPath" -ForegroundColor Green
        $resp = Read-Host "  Re-activate anyway? (y/N)"
        if ($resp -notmatch '^[Yy]') { return }
    }

    # Phase 3a: generate the .alf
    Write-Host ""
    Write-Host "  3a. Generate activation request (.alf)"
    Write-Host "      I'll launch Unity now. In Unity:"
    Write-Host "        1. Click 'Manual activation' on the license dialog."
    Write-Host "        2. Unity writes a .alf file. Note where it saved it."
    Write-Host "        3. Close Unity."
    Write-Host ""
    Pause-Continue '      Press Enter when ready to launch Unity.'
    if (Test-Path $script:AlfPath) { Remove-Item $script:AlfPath -Force }
    Start-Process (Join-Path $InstallRoot 'Unity.exe')
    Write-Host "      Waiting for $script:AlfPath ..."
    while (-not (Test-Path $script:AlfPath)) { Start-Sleep -Seconds 2 }
    Write-Host "      .alf detected. Close Unity now if you haven't." -ForegroundColor Green
    Pause-Continue '      Press Enter once Unity is closed.'

    # Phase 3b: pause the hosts block so the browser can reach the activation URL
    Write-Host ""
    Write-Host "  3b. Pausing hosts block so your browser can reach license.unity3d.com..."
    Remove-HostsBlock-Temp
    Write-Host "      Hosts block paused (will be restored in 3d)" -ForegroundColor Green

    # Phase 3c: walk through browser upload
    Write-Host ""
    Write-Host "  3c. Upload the .alf and download your .ulf"
    Write-Host "      I'm opening https://license.unity3d.com/manual now."
    Write-Host "      On that page:"
    Write-Host "        1. Sign in with your Unity ID."
    Write-Host "        2. Upload: $script:AlfPath"
    Write-Host "        3. Choose 'Unity Personal' (free)."
    Write-Host "        4. Download the returned .ulf to anywhere (e.g. Downloads)."
    Write-Host ""
    Start-Process 'https://license.unity3d.com/manual'
    Write-Host "      Looking for the .ulf in your Downloads folder..."
    $found = $null
    $downloads = (Join-Path $env:USERPROFILE 'Downloads')
    while (-not $found) {
        $found = Get-ChildItem $downloads -Filter 'Unity_v4.x*.ulf' -ErrorAction SilentlyContinue |
                 Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if (-not $found) { Start-Sleep -Seconds 3 }
    }
    Write-Host "      Found: $($found.FullName)" -ForegroundColor Green
    if (-not (Test-Path 'C:\ProgramData\Unity')) {
        New-Item -ItemType Directory -Path 'C:\ProgramData\Unity' -Force | Out-Null
    }
    Copy-Item $found.FullName $script:UlfPath -Force
    Write-Host "      .ulf installed to $script:UlfPath" -ForegroundColor Green

    # Phase 3d: restore hosts block
    Write-Host ""
    Write-Host "  3d. Restoring hosts block..."
    Restore-HostsBlock
    Write-Host "      Hosts block restored. Activation complete." -ForegroundColor Green
}

# ---- Phase 4: optional dark skin ----

function Phase4-DarkSkin {
    Write-Step 4 5 "Optional: Pro dark editor skin"

    Write-Host "  Unity Personal hides the dark editor skin behind a Pro check."
    Write-Host "  Two reversible binary patches unlock it without modifying your license."
    Write-Host "  Reversible via .preDarkSkinBackup copies and dark_skin\restore.ps1."
    Write-Host ""
    $resp = Read-Host "  Apply dark skin now? (Y/n)"
    if ($resp -and $resp -notmatch '^[Yy]') {
        Write-Host "  Skipped. You can run dark_skin\apply.ps1 later." -ForegroundColor Yellow
        return
    }

    & (Join-Path $script:Here 'dark_skin\apply.ps1') -InstallRoot $InstallRoot
}

# ---- Phase 5: launch ----

function Phase5-Launch {
    Write-Step 5 5 "Launch Unity"

    $resp = Read-Host "  Launch Unity now to verify? (Y/n)"
    if ($resp -and $resp -notmatch '^[Yy]') { return }
    Start-Process (Join-Path $InstallRoot 'Unity.exe')
    Write-Host "  Unity launched. If you see 'license expired' click Re-activate." -ForegroundColor Green
}

# ---- Run ----

try {
    Assert-Admin
    Write-Banner 'Unity 4.6.5f1 Portable : One-click Setup'

    Phase1-Preflight
    Phase2-SystemSetup
    Phase3-Activation
    Phase4-DarkSkin
    Phase5-Launch

    Write-Banner 'All done. Enjoy Unity 4.6.5f1.'
    Write-Host ""
    Write-Host "  Launch later from: %USERPROFILE%\Desktop\launch_unity46.bat"
    Write-Host "  To undo dark skin: cd dark_skin ; .\restore.ps1"
    Write-Host "  To undo hosts block: see README.md FAQ."
    Write-Host ""
    Pause-Continue '  Press Enter to close.'
}
catch {
    Write-Host ""
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "If the hosts block was paused mid-activation and the script aborted," -ForegroundColor Yellow
    Write-Host "you may need to restore it manually. See README.md FAQ." -ForegroundColor Yellow
    Pause-Continue '  Press Enter to close.'
    exit 1
}

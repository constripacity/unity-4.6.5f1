# restore.ps1 : undoes apply.ps1 by restoring both files from their
# .preDarkSkinBackup copies.

[CmdletBinding()]
param(
    [string]$InstallRoot = (Join-Path $env:USERPROFILE 'Unity4.6.5')
)

$ErrorActionPreference = 'Stop'

$pairs = @(
    @{ live = Join-Path $InstallRoot 'Unity.exe' },
    @{ live = Join-Path $InstallRoot 'Data\Managed\UnityEditor.dll' }
)

foreach ($p in $pairs) {
    $live = $p.live
    $bak  = "$live.preDarkSkinBackup"
    if (-not (Test-Path $bak)) {
        Write-Warning "no backup for $live (already original, or never patched)"
        continue
    }
    Copy-Item $bak $live -Force
    Write-Host "restored $live"
    Write-Host "  SHA256: $((Get-FileHash $live -Algorithm SHA256).Hash)"
}

Write-Host ""
Write-Host "Both files restored from .preDarkSkinBackup copies."
Write-Host "Unity will now boot with the original Light skin gating."

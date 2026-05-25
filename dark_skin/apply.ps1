# apply.ps1 : enables the Pro Dark Skin in Unity 4.6.5f1 Personal/Free.
#
# Two patches, both reversible. Backups are created with the suffix
# ".preDarkSkinBackup" next to each original.
#
#   1. Native one byte patch on Unity.exe at file offset 0x00B7D51C
#      (changes JNZ to JMP in the editor skin license gate so the
#      cached UserSkin EditorPref is honored regardless of license).
#
#   2. Managed CIL patch on Data\Managed\UnityEditor.dll using
#      Mono.Cecil to force InternalEditorUtility.HasPro and
#      InternalEditorUtility.HasAdvancedLicenseOnBuildTarget to
#      return true so the Editor Skin dropdown stays unlocked.
#
# Usage:
#   .\apply.ps1                  (default: %USERPROFILE%\Unity4.6.5)
#   .\apply.ps1 -InstallRoot ... (custom path)
#
# After running, restart Unity, go to Edit, Preferences, General,
# pick "Dark" from the Editor Skin dropdown.

[CmdletBinding()]
param(
    [string]$InstallRoot = (Join-Path $env:USERPROFILE 'Unity4.6.5')
)

$ErrorActionPreference = 'Stop'

$exe = Join-Path $InstallRoot 'Unity.exe'
$dll = Join-Path $InstallRoot 'Data\Managed\UnityEditor.dll'

foreach ($p in @($exe, $dll)) {
    if (-not (Test-Path $p)) { throw "not found: $p" }
}

function Backup-Once($path) {
    $bak = "$path.preDarkSkinBackup"
    if (-not (Test-Path $bak)) {
        Copy-Item $path $bak
        Write-Host "  backed up -> $bak"
    } else {
        Write-Host "  backup already exists (kept)"
    }
}

function SHA256-Of($path) {
    (Get-FileHash $path -Algorithm SHA256).Hash
}

# Native one byte patch on Unity.exe
Write-Host "[1/2] Patching Unity.exe (native chrome skin gate)..."
Backup-Once $exe

$EXPECTED_SHA = '37ced0c440ffa212a82114d48379ec01926c79bb5baec72ac560c4917203d542'
$PATCHED_SHA  = '97bd8289a8eb499a068d9f59fa66c2a072383d9eb2e9dce500297542ff25e51b'
$currentSha = (SHA256-Of $exe).ToLower()
if ($currentSha -ne $EXPECTED_SHA -and $currentSha -ne $PATCHED_SHA) {
    throw "Unity.exe SHA256 mismatch. Expected $EXPECTED_SHA (or $PATCHED_SHA if already patched). Got $currentSha. This script targets the Unity 4.6.5f1 build documented in dark_skin/README.md. Refusing to patch a different build."
}

$NATIVE_OFFSET   = 0x00B7D51C
$NATIVE_EXPECTED = 0x75   # JNZ short
$NATIVE_PATCH    = 0xEB   # JMP short

$bytes = [System.IO.File]::ReadAllBytes($exe)
$cur = $bytes[$NATIVE_OFFSET]
if ($cur -eq $NATIVE_PATCH) {
    Write-Host ("  already patched at file=0x{0:X8}" -f $NATIVE_OFFSET)
} elseif ($cur -ne $NATIVE_EXPECTED) {
    throw ("Unexpected byte 0x{0:X2} at file offset 0x{1:X8} (wanted 0x{2:X2}). Refusing to patch. Wrong Unity build?" -f $cur, $NATIVE_OFFSET, $NATIVE_EXPECTED)
} else {
    $bytes[$NATIVE_OFFSET] = $NATIVE_PATCH
    [System.IO.File]::WriteAllBytes($exe, $bytes)
    Write-Host ("  patched byte 0x75 -> 0xEB at file=0x{0:X8}" -f $NATIVE_OFFSET)
}
Write-Host "  SHA256: $(SHA256-Of $exe)"
Write-Host ""

# Managed CIL patch on UnityEditor.dll
Write-Host "[2/2] Patching UnityEditor.dll (managed HasPro getters)..."
Backup-Once $dll

$cecilPath = Join-Path $PSScriptRoot 'Mono.Cecil.dll'
if (-not (Test-Path $cecilPath)) { throw "Mono.Cecil.dll missing next to apply.ps1: $cecilPath" }
Add-Type -Path $cecilPath

$resolver = New-Object Mono.Cecil.DefaultAssemblyResolver
$resolver.AddSearchDirectory((Split-Path $dll -Parent))
$rp = New-Object Mono.Cecil.ReaderParameters
$rp.InMemory  = $true
$rp.AssemblyResolver = $resolver

$asm = [Mono.Cecil.AssemblyDefinition]::ReadAssembly($dll, $rp)

$targets = 'HasPro','HasAdvancedLicenseOnBuildTarget'
$patched = 0
foreach ($module in $asm.Modules) {
    foreach ($type in $module.GetTypes()) {
        if ($type.FullName -ne 'UnityEditorInternal.InternalEditorUtility') { continue }
        foreach ($m in $type.Methods) {
            if (-not $m.IsStatic) { continue }
            if ($m.ReturnType.FullName -ne 'System.Boolean') { continue }
            if ($targets -notcontains $m.Name) { continue }

            $isInternalCall = ([int]$m.ImplAttributes -band [int][Mono.Cecil.MethodImplAttributes]::InternalCall) -ne 0
            $existingTrue = $false
            if (-not $isInternalCall -and $m.HasBody -and $m.Body.Instructions.Count -eq 2) {
                $i0 = $m.Body.Instructions[0]
                $i1 = $m.Body.Instructions[1]
                if ($i0.OpCode.Code -eq [Mono.Cecil.Cil.Code]::Ldc_I4_1 -and $i1.OpCode.Code -eq [Mono.Cecil.Cil.Code]::Ret) {
                    $existingTrue = $true
                }
            }
            if ($existingTrue) {
                Write-Host "  $($m.Name): already patched"
                continue
            }

            # Clear InternalCall, Native, Runtime; set Managed.
            $m.ImplAttributes = ($m.ImplAttributes -band (-bnot ([Mono.Cecil.MethodImplAttributes]::InternalCall))) `
                                                  -band (-bnot ([Mono.Cecil.MethodImplAttributes]::Native)) `
                                                  -band (-bnot ([Mono.Cecil.MethodImplAttributes]::Runtime)) `
                                                  -bor  ([Mono.Cecil.MethodImplAttributes]::Managed)

            $body = New-Object Mono.Cecil.Cil.MethodBody($m)
            $il = $body.GetILProcessor()
            $il.Append($il.Create([Mono.Cecil.Cil.OpCodes]::Ldc_I4_1))
            $il.Append($il.Create([Mono.Cecil.Cil.OpCodes]::Ret))
            $m.Body = $body
            Write-Host "  $($m.Name): patched -> return true"
            $patched++
        }
    }
}

if ($patched -gt 0) {
    $asm.Write($dll)
    Write-Host "  wrote $dll"
}
Write-Host "  SHA256: $(SHA256-Of $dll)"
Write-Host ""

# EditorPrefs UserSkin = 1 (so first launch is Dark)
$root = 'HKCU:\Software\Unity Technologies\Unity Editor 4.x'
if (Test-Path $root) {
    $k = Get-Item $root
    $key = $k.GetValueNames() | Where-Object { $_ -like 'UserSkin*' } | Select-Object -First 1
    if ($key) {
        Set-ItemProperty -Path $root -Name $key -Value 1 -Type DWord
        Write-Host "Set HKCU\...\Unity Editor 4.x\$key = 1 (Dark)"
    }
}

Write-Host ""
Write-Host "Done. Launch Unity (scripts\launch_unity46.bat). Editor Skin is now switchable."
Write-Host "To restore originals: .\restore.ps1"

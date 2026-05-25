# Dark Skin for Unity 4.6.5f1 Personal

Two file patches that enable the Pro dark editor skin on a Personal/Free license. Both reversible. Backups (`.preDarkSkinBackup`) are kept next to each original.

## Quick start

```powershell
# from this directory:
.\apply.ps1                      # default: %USERPROFILE%\Unity4.6.5
.\apply.ps1 -InstallRoot D:\...  # custom path
```

To undo:

```powershell
.\restore.ps1
```

After applying, launch Unity and switch via **Edit, Preferences, General, Editor Skin**. Dark and Light are freely switchable.

## What gets patched

### 1. `Unity.exe` (one byte)

| Offset | Original | Patched | Meaning |
|---|---|---|---|
| `0x00B7D51C` | `0x75` | `0xEB` | `JNZ short +4` becomes `JMP short +4` |

This is inside the native function `FUN_00f7e110` at VA `0x00F7E11C`. The function reads the cached `UserSkin` EditorPref and gates it with a check on `LicenseInfo->flags & 1`. If the Pro bit isn't set, it returns 0 (forcing Light) regardless of the user's pick. Changing the conditional jump to unconditional bypasses the gate, so the cached pref value is always returned.

Decompiled `FUN_00f7e110` (before patch):

```c
int GetEffectiveUserSkin(int *cachedSkin) {
    LicenseInfo *li = GetLicenseInfo();
    if ((li->flags & 1) == 0)   // the branch we bypass
        return 0;               // was: forced light skin
    return *cachedSkin;
}
```

After the patch the `if` is always taken, so the function always returns `*cachedSkin`. Writing `UserSkin = 0` or `1` via Preferences honors the user's pick.

### 2. `Data\Managed\UnityEditor.dll` (two CIL method bodies)

| Method | Original | Patched |
|---|---|---|
| `UnityEditorInternal.InternalEditorUtility::HasPro` | InternalCall to native | `return true` |
| `UnityEditorInternal.InternalEditorUtility::HasAdvancedLicenseOnBuildTarget` | InternalCall to native | `return true` |

The Preferences dropdown for Editor Skin is gated with `if (HasPro()) ...` to decide whether to enable it. With both getters force true, the dropdown stays unlocked. `isProSkin` and `skinIndex` are **not** touched. They pass through to native, which (after the Unity.exe patch above) correctly reflects the user's current pick.

## How the patches were discovered

Ghidra (without PDB, since `PdbUniversalAnalyzer` chokes on Unity's PDB with a `TypeDef data-type may not be a bitfield: ulong:31` exception in Ghidra 11.3.2), then tracing string xrefs to `"UserSkin"` and the error message `"set_skinIndex can only be called from the main thread."`.

The chrome skin selection path goes:

1. Managed `EditorGUIUtility.skinIndex` getter calls into native via InternalCall.
2. Native `get_skinIndex` (VA `0x009B6440`) calls `FUN_00f7e2a0` to lazy load the cached UserSkin.
3. Native `FUN_00f7e110` returns the gated value.

`FUN_00f7e110` is the choke point. Patching its one byte gate flips the entire chrome.

## Requirements for `apply.ps1`

* Windows PowerShell 5+ (built in on Windows 10/11).
* `Mono.Cecil.dll` bundled in this folder (~350 KB).
* `Unity.exe` SHA256 must match the original `37ced0c440ffa212a82114d48379ec01926c79bb5baec72ac560c4917203d542` (or the already patched hash `97bd8289a8eb499a068d9f59fa66c2a072383d9eb2e9dce500297542ff25e51b`).

`apply.ps1` checks both the full SHA256 of `Unity.exe` and the single expected byte at file offset `0x00B7D51C` before writing. If either check fails, the script refuses to patch. File an issue if you hit that on a stock Unity 4.6.5f1 install.

## File hashes

| File | SHA256 |
|---|---|
| Original `Unity.exe` | `37ced0c440ffa212a82114d48379ec01926c79bb5baec72ac560c4917203d542` |
| Patched `Unity.exe` | `97bd8289a8eb499a068d9f59fa66c2a072383d9eb2e9dce500297542ff25e51b` |
| Original `UnityEditor.dll` | `0564a8a8505e0aac8a5481e0e518d148326d666b84cc41c6c2783afd6342016f` |
| Patched `UnityEditor.dll` | `28542bb82eba8845674583572490613e75812db494aac9a2d1d8d50272d95d78` |

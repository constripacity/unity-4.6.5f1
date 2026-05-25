# Third Party Notices

This repository redistributes the following third party files. Their original licenses apply.

## Mono.Cecil (`dark_skin/Mono.Cecil.dll`)

MIT License. Copyright (C) 2008 to 2015 Jb Evain. Copyright (C) 2008 to 2011 Novell, Inc.
Source: https://github.com/jbevain/cecil
License text: https://github.com/jbevain/cecil/blob/master/LICENSE.txt

Bundled version: **0.11.5** (from the NuGet package `Mono.Cecil 0.11.5`, the official release at that tag).
File size: 359 424 bytes.
SHA256: `9c2908709da6761e9b5b9d4d46102d65851145bac987787d6c5a05ffe5689487`.

Verify locally with:
```powershell
(Get-FileHash dark_skin/Mono.Cecil.dll -Algorithm SHA256).Hash
```

Used by `dark_skin/apply.ps1` to rewrite two CIL method bodies in a local copy of `UnityEditor.dll`.

## Mozilla Root CA Bundle (`mono_certs/`)

The 121 certificate files in `mono_certs/` are extracted from the Mozilla CA Certificate Program bundle distributed at https://curl.se/ca/cacert.pem. The CAs themselves are operated by their respective organisations (DigiCert, Let's Encrypt, GlobalSign, Microsoft, Google, FNMT-RCM, Certum, and others). Mozilla curates and distributes the bundle. License: Mozilla Public License v2.0 for the bundle itself; the certificates are public material.

Used by `restore.bat` to populate Unity 4's empty Mono trust store at `%APPDATA%\.mono\certs\Trust\`.

## Everything else

All scripts (`.bat`, `.ps1`), the registry tweak, and the README content are authored for this repo and covered by the MIT License at the repo root (`LICENSE`).

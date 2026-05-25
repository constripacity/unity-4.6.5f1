# Unity 4.6.5f1 Portable

Tooling that makes the old **Unity 4.6.5f1** editor launch and run on modern Windows. Useful for any Unity 4.6.5f1 project where the editor refuses to open due to the 2014 era SSL stack.

## Why this is needed

Unity 4.6.5f1 was released in 2014. On a modern Windows machine it doesn't open out of the box. The 2014 era SSL stack can't validate today's Unity license servers, so the editor pops a "Peer certificate cannot be authenticated" error on startup and self quits.

This repo bundles three fixes plus an optional Pro Dark Skin patch.

## What you need before starting

* Windows 10 or 11. (The Unity 4 editor is 32 bit Windows only.)
* A free **Unity ID**. Register at https://id.unity.com if you don't have one.
* About 3 GB free disk space.

## Lazy mode: one click setup

If you just want it to work, **double click `setup.cmd`** in the repo root. It:

1. Approves UAC
2. Detects (or prompts you to install) Unity 4.6.5f1
3. Sets up the Mono trust store, hosts block, and registry prefs
4. Walks you through activating your own free Unity Personal license, including pausing the hosts block during the browser step so the activation URL actually loads
5. Optionally applies the Pro dark editor skin patches
6. Launches Unity

Total user interaction: a couple of Y/N prompts and one Unity ID login in your browser. No editing scripts, no copying files manually.

If you'd rather understand what each piece does, follow the 5 step manual setup below.

## Manual setup in 5 steps

### Step 1. Get Unity 4.6.5f1

The Unity binaries are **not in this repo** (we don't redistribute Unity itself). Download the official Unity 4.6.5f1 installer from [Unity's archive](https://unity.com/releases/editor/archive) under Unity 4.x then 4.6.5, and run it.

The rest of the guide assumes your Unity install lives at `%USERPROFILE%\Unity4.6.5\`. If you installed it elsewhere, substitute your own path everywhere (and edit `scripts\launch_unity46.bat` to point at it).

If you want a smaller install, see the "Trimmed platforms" section at the bottom of this README for which subfolders are safe to remove.

### Step 2. Clone this repo

```
git clone https://github.com/constripacity/unity-4.6.5f1
cd unity-4.6.5f1
```

If your Unity install path is not `%USERPROFILE%\Unity4.6.5\` (the default our scripts assume), open `scripts\launch_unity46.bat` in a text editor and point it at your install.

### Step 3. Run `restore.bat`

Double click `restore.bat`. It will request UAC because it edits the hosts file. It does five things in one shot.

1. Optionally copies a `unity-install/Unity4.6.5/` folder placed next to `restore.bat` into `%USERPROFILE%\Unity4.6.5\`. Skipped if Unity is already at that path.
2. Imports 121 modern Mozilla root CAs into Mono's trust store at `%APPDATA%\.mono\certs\Trust\`. Unity 4 ships an empty trust store, which is why SSL validation fails.
3. Imports a small registry tweak (color prefs, keybindings, layout). No project paths and no analytics keys.
4. Adds `0.0.0.0  license.unity3d.com` to your hosts file. This forces Unity to fall back to your offline `.ulf` license instead of trying to refresh from a modern license server it can't validate.
5. Copies `launch_unity46.bat` and `block_unity_license_check.bat` to your Desktop for convenience.

### Step 4. Activate Unity with your own Unity ID

Each user activates their own free Personal license against their own Unity ID. The result is a `.ulf` file bound to your specific machine.

> **Heads up.** The hosts block from Step 3 affects every program on this machine, including your browser. The manual activation URL below lives on the same `license.unity3d.com` host that's being blocked. You have two ways around it.
>
> * **Easy path (recommended):** open the activation URL on a phone, tablet, or a second computer. Transfer the `.alf` file there (e.g. via cloud storage or USB), upload it, download the resulting `.ulf` back to this machine.
> * **Same machine path:** open `%SystemRoot%\System32\drivers\etc\hosts` in Notepad (as admin), comment out the line `0.0.0.0 license.unity3d.com` by adding a `#` in front. Do the activation. Then uncomment it again and run `ipconfig /flushdns` in an admin terminal.

1. Launch Unity once: `scripts\launch_unity46.bat`.
2. Unity pops "License is not for this machine". Click **Manual activation**.
3. Unity writes `%USERPROFILE%\Documents\Unity_v4.x.alf`. This is your activation request.
4. Go to https://license.unity3d.com/manual (see the heads up above for the right way to reach it).
5. **Sign in with your Unity ID.** Upload the `.alf` file. Choose **Unity Personal** (the free tier, no payment).
6. Download the returned `.ulf` file.
7. Place it at `C:\ProgramData\Unity\Unity_v4.x.ulf`. Create the `Unity` folder if it doesn't exist.
8. If you used the same machine path above, restore the hosts block now and `ipconfig /flushdns`.
9. Relaunch Unity via `scripts\launch_unity46.bat`. On first launch you may see a "license expired" popup; click "Re activate" and Unity continues normally. Uncheck "Show at Startup" on the welcome screen.

You're done with the base setup. Editor opens, projects can be loaded.

### Step 5. Optional. Enable the Pro Dark editor skin

Unity Personal hides the dark editor skin behind a Pro license check. Two reversible binary patches unlock it **without changing your license**.

```powershell
cd dark_skin
.\apply.ps1
```

What the script does:

* Patches one byte in `Unity.exe` (bypasses the native chrome skin license gate).
* Patches two CIL methods in `UnityEditor.dll` (unlocks the Edit, Preferences, General, Editor Skin dropdown).
* Sets your `UserSkin` EditorPref to 1 so Unity boots in Dark on first launch.

Backups are kept as `.preDarkSkinBackup` files next to each original. To undo:

```powershell
.\restore.ps1
```

After the patch you can freely switch Light and Dark via Edit then Preferences then General then Editor Skin.

Byte level details in [`dark_skin/README.md`](dark_skin/README.md).

## What's in this repo

| Folder or file | What it is |
|---|---|
| `setup.cmd` | Double click entrypoint for the lazy mode installer. Self elevates and bypasses PowerShell execution policy for the script. |
| `setup.ps1` | Guided installer that does the full 5 step setup including license activation (with hosts block pause/resume). |
| `restore.bat` | Minimal one shot setup: Mono certs + hosts block + registry + copy launchers to Desktop. For users who want to do activation manually per Step 4. |
| `scripts/launch_unity46.bat` | Launches `Unity.exe` from `%USERPROFILE%\Unity4.6.5`. Pass `-projectPath <path>` as an argument to open a specific project directly. |
| `scripts/block_unity_license_check.bat` | Standalone hosts blocker (self elevating). |
| `mono_certs/` | The public Mozilla root CA bundle, 121 certificates. |
| `registry/unity_editor_4x_prefs.reg` | Editor color prefs, keybindings, layout defaults, and welcome screen suppression. |
| `dark_skin/` | Optional Pro Dark skin patches (PowerShell + bundled Mono.Cecil.dll). |

No personal license data ships in this repo. You generate your own `.ulf` in Step 4.

## FAQ

**Q. Do I need to pay Unity anything?**
No. Unity Personal (the free tier, what the Unity 4 era called "Free" or "Indie") has always been free. The only requirement is a free Unity ID account.

**Q. What are the certificates in `mono_certs/`? Are they yours or Unity's?**
Neither. They are the standard public Mozilla root CA bundle from `curl.se/ca/cacert.pem`. They are the same root CAs every browser, every operating system, and every `curl` installation ships with. Maintained by the certificate authorities themselves (DigiCert, Let's Encrypt, GlobalSign, Microsoft, Google, and so on) and distributed via Mozilla. Sharing them is equivalent to sharing a copy of any browser's built in trust store.

**Q. Why doesn't this repo include a Unity 4.6.5f1 installer?**
Because Unity Technologies still hosts the original installer themselves (link in Step 1), and redistributing Unity binaries would be a license violation. We only ship the workarounds and the optional Dark Skin patch.

**Q. Is the Dark Skin patch legal?**
The patches modify your local Unity binaries on your machine. They do not redistribute modified Unity binaries. This kind of local binary patching has been a longstanding community practice. If you'd rather not patch, skip Step 5. The base setup works without it.

**Q. I'm on a different machine. Why won't my `.ulf` validate?**
Unity licenses are machine bound. Each machine gets its own `.ulf`. Repeat Step 4 on each machine where you want to use Unity 4.6.5f1.

**Q. How do I undo the hosts block?**
Open `%SystemRoot%\System32\drivers\etc\hosts` in Notepad (run Notepad as administrator). Find the line `0.0.0.0 license.unity3d.com` and the `# Unity 4.6.5 offline license fallback` comment above it, delete both lines, save. Then in an admin terminal run `ipconfig /flushdns`. Unity will go back to trying the online license server on next launch (which is what blocked it in the first place, so only do this if you've removed Unity or want online activation).

## How the fix actually works (for the curious)

Three things must all be true for Unity 4.6.5f1 to open on a modern Windows machine.

1. **Valid offline `.ulf` license** at `C:\ProgramData\Unity\Unity_v4.x.ulf`. Produced by Step 4's manual activation. The crash on a stock Unity 4.6.5 isn't about the license being invalid. It's about Unity trying to refresh the license at startup and failing on SSL.

2. **Mono trust store populated** at `%APPDATA%\.mono\certs\Trust\`. Unity 4 ships an empty trust store. Modern Unity's `cert-sync.exe` imports 121 current Mozilla roots from `curl.se/ca/cacert.pem`. `restore.bat` runs this for you.

3. **Hosts block on `license.unity3d.com`**. Even with the trust store populated, Unity 4.6's older Mono uses a different cert file naming convention than modern `cert-sync` writes, so SSL validation still fails. Blocking the host forces Unity to fall back to the offline `.ulf` ("Recovered backup license file" in the log). Side effect: Unity shows a "license expired" popup on every launch. Click "Re activate" and it proceeds.

The welcome screen still fails to load tutorial content (also an SSL fetch issue), but with the license issue resolved, dismissing that popup no longer quits the editor. Uncheck "Show at Startup" on first launch to retire it permanently.

## Trimmed platforms (optional disk savings)

If you only need Windows Standalone builds (the most common case for Unity 4.6.5f1 today), you can delete about 5.6 GB of unused build target support folders from your Unity install. Safe to remove from `%USERPROFILE%\Unity4.6.5\Data\`:

```
Data/PlaybackEngines/iossupport              (2.4 GB)
Data/PlaybackEngines/metrosupport            (1.7 GB)
Data/PlaybackEngines/linuxstandalonesupport  (380 MB)
Data/PlaybackEngines/wp8support              (352 MB)
Data/PlaybackEngines/macstandalonesupport    (206 MB)
Data/PlaybackEngines/androidplayer           (76 MB)
Data/PlaybackEngines/blackberryplayer        (32 MB)
Data/Documentation                           (293 MB)
Data/MonoBleedingEdge                        (185 MB)   note: Unity 4.6 uses Data/Mono, not BleedingEdge
```

If you need any of these later, download the full Unity 4.6.5f1 installer from [Unity's archive](https://unity.com/releases/editor/archive) and merge the missing `PlaybackEngines/*` subfolders into your install.

## License of this repo

This repo contains tooling and scripts authored for community use. Unity Technologies retains all rights to Unity itself; nothing in this repo redistributes Unity binaries.

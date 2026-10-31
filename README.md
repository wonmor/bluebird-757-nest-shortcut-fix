# bluebird-757-nest-shortcut-fix

**The BlueBird Simulations NEST installer doesn't create a shortcut, so after you install NEST, Windows Search can't find it.** This repo has a small PowerShell tool that adds the missing Start Menu and Desktop shortcuts. By default it also sets NEST to always run as administrator, which prevents the permission errors NEST hits when installing the 757.

> Not affiliated with, endorsed by, or supported by BlueBird Simulations. "BlueBird Simulations" and "NEST" are used only to identify the software this workaround is for. If BlueBird ships an installer that creates shortcuts, you don't need this.

---

## Contents

- [TL;DR](#tldr)
- [The problem](#the-problem)
- [Why NEST looks like it isn't installed](#why-nest-looks-like-it-isnt-installed)
- [What the installer actually does (evidence)](#what-the-installer-actually-does-evidence)
- [Root cause](#root-cause)
- [The fix](#the-fix)
- [Usage](#usage)
- [What the tool changes, exactly](#what-the-tool-changes-exactly)
- [About "run as administrator"](#about-run-as-administrator)
- [Known caveats](#known-caveats)
- [Fixing it by hand (no script)](#fixing-it-by-hand-no-script)
- [Undoing everything](#undoing-everything)
- [Troubleshooting](#troubleshooting)
- [FAQ](#faq)
- [Notes for the developer](#notes-for-the-developer)
- [Tested on](#tested-on)
- [License](#license)

---

## TL;DR

1. Install NEST with the official installer, as usual.
2. Download this repo (green **Code** button, then **Download ZIP**) and unzip it.
3. Double-click **`Install-NestShortcut.cmd`**.
4. Press Start and type **BlueBird NEST**. You can also use the new Desktop icon.

Don't want admin mode? Run `Install-NestShortcut.cmd -NoAdmin` from a terminal, or see [Usage](#usage).
To remove everything this tool added, double-click **`Uninstall-NestShortcut.cmd`**.

---

## The problem

You run the NEST installer and it finishes without an error. Then:

- typing "NEST" or "BlueBird" in the Start menu finds nothing
- there's no new folder or entry in **Start, All apps**
- there's no Desktop icon
- the only sign the install worked is **Settings, Apps, Installed apps**, which lists **BlueBird Simulations NEST** with an **Uninstall** button but no way to launch it

So NEST is installed but has no launcher. The only way to start it is to find the `.exe` yourself, and the installer never tells you where it went.

## Why NEST looks like it isn't installed

Windows' app search and the **All apps** list don't scan your disk for programs. They list **shortcuts** (`.lnk` files) and packaged apps from two folders:

| Scope | Folder |
|---|---|
| Current user | `%APPDATA%\Microsoft\Windows\Start Menu\Programs` |
| All users | `%ProgramData%\Microsoft\Windows\Start Menu\Programs` |

An ordinary desktop program that puts no shortcut in either folder doesn't appear in Start search, even though its files are on disk and it's registered in **Installed apps**. The "Installed apps" list comes from a different place: the `Uninstall` registry key. That's why NEST shows up there and nowhere else.

On top of that, NEST installs **per user** under `%LOCALAPPDATA%\Programs`. That's a hidden folder (`AppData` is hidden by default), so browsing *Program Files* won't find it either.

## What the installer actually does (evidence)

These observations come from a clean install of **NEST 1.0.0.0** on Windows 11.

**1. The files go to a per-user, hidden location:**

```
%LOCALAPPDATA%\Programs\BlueBird Simulations\NEST\
    bbs_nest.exe            <- the app (a .NET apphost)
    bbs_nest.dll
    BBSNestUpdater.exe      <- updater
    SubSystem.dll, SDL2.dll, glew32.dll
    ot\  shdrsb\  runtimes\
    uninstall.exe
    uninstall.dat
```

User data (cache, liveries, `user.dat`) goes to a separate folder, `%LOCALAPPDATA%\BlueBird Simulations\Nest\`.

**2. It registers an uninstaller (per user):**

```
HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\BlueBird Simulations NEST
    DisplayName      = BlueBird Simulations NEST
    DisplayVersion   = 1.0.0.0
    Publisher        = BlueBird Simulations
    InstallLocation  = %LOCALAPPDATA%\Programs\BlueBird Simulations\NEST
    DisplayIcon      = ...\NEST\bbs_nest.exe
    UninstallString  = "...\NEST\uninstall.exe" /uninstall
```

That's everything **Installed apps** needs, so NEST appears there.

**3. It creates no shortcut anywhere.** After installing, searching all of these folders for `*.lnk` files with "nest" or "bluebird" in the name returns nothing:

- `%APPDATA%\Microsoft\Windows\Start Menu` (current user Start Menu)
- `%ProgramData%\Microsoft\Windows\Start Menu` (all-users Start Menu)
- `%USERPROFILE%\Desktop`
- `%PUBLIC%\Desktop`

**4. The installer's own manifest confirms it never planned to make one.** `uninstall.dat` is the plain-text list of everything the installer wrote. The uninstaller uses it to know what to delete. It starts with `owned=1`, followed by one relative path per line, and every entry is a file **inside the install folder**: the binaries, the `ot\tr\*.DEM/*.HDR` terrain tiles, the `shdrsb\*` shaders and so on. No entry points at a Start Menu or Desktop `.lnk`.

So this isn't a shortcut that was created and then lost, or blocked by antivirus, or put in some other place. The installer never wrote one.

## Root cause

The installer skips the "create shortcuts" step. Installer frameworks such as Inno Setup, NSIS, WiX and electron-builder all do this step by default. NEST uses a custom installer, judging by the custom `uninstall.dat` format, and that installer seems to:

1. copy the payload to `%LOCALAPPDATA%\Programs\BlueBird Simulations\NEST`
2. write the `Uninstall` registry key
3. write `uninstall.dat`

and stop there, with no step 4 to create `Start Menu\Programs\...\BlueBird NEST.lnk`. Because the shortcut also isn't in the manifest, adding a shortcut yourself is safe: the uninstaller won't delete it. The flip side is that the uninstaller won't clean it up either. That's why this tool has its own `-Uninstall` switch.

## The fix

`Install-NestShortcut.ps1` does the step the installer skips, and one optional extra:

1. **Finds NEST.** It reads the `Uninstall` registry entry (HKCU first, then HKLM) and uses `DisplayIcon` or `InstallLocation`. If that fails, it falls back to the default path. Nothing is hard-coded to one user's profile.
2. **Creates `BlueBird NEST.lnk`** in your Start Menu (`%APPDATA%\Microsoft\Windows\Start Menu\Programs`) and on your Desktop. Each shortcut uses NEST's own icon and sets the working folder to the install folder.
3. **Sets "Run this program as an administrator"** for `bbs_nest.exe`. This is the same setting as the checkbox under *Properties, Compatibility*. It's on by default; `-NoAdmin` turns it off.

Everything is **per user** and can be undone. The script itself **doesn't need admin rights**, because it only writes to your own profile and to `HKCU`.

## Usage

### Double-click

| File | What it does |
|---|---|
| `Install-NestShortcut.cmd` | Creates both shortcuts and turns on run-as-admin |
| `Uninstall-NestShortcut.cmd` | Removes both shortcuts and clears run-as-admin |

The `.cmd` files only start the PowerShell script with `-ExecutionPolicy Bypass`, which applies to that one run. They change no system policy.

### From a terminal

```powershell
# default: Start Menu + Desktop shortcuts, run as administrator
.\Install-NestShortcut.ps1

# shortcuts only, no admin
.\Install-NestShortcut.ps1 -NoAdmin

# Start Menu only (no Desktop icon)
.\Install-NestShortcut.ps1 -NoDesktop

# NEST installed somewhere unusual
.\Install-NestShortcut.ps1 -ExePath 'D:\Games\NEST\bbs_nest.exe'

# preview without changing anything
.\Install-NestShortcut.ps1 -WhatIf

# undo
.\Install-NestShortcut.ps1 -Uninstall
```

If PowerShell refuses to run the script because of the execution policy, use the `.cmd` launcher, or run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-NestShortcut.ps1
```

You can run it any number of times. Running it again recreates the shortcuts, which is handy after a NEST update or reinstall.

## What the tool changes, exactly

| Change | Location | Removed by `-Uninstall` |
|---|---|---|
| Start Menu shortcut | `%APPDATA%\Microsoft\Windows\Start Menu\Programs\BlueBird NEST.lnk` | yes |
| Desktop shortcut | `[Desktop folder]\BlueBird NEST.lnk` (follows OneDrive Desktop redirection) | yes |
| Run-as-admin flag | `HKCU\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers`, value name = full path to `bbs_nest.exe`, data = `~ RUNASADMIN` | yes |

Nothing else changes: not NEST's files, not its registry entry, not any system-wide setting. If you already set other compatibility options on `bbs_nest.exe`, such as a DPI override, the tool keeps them and only adds or removes `RUNASADMIN`.

## About "run as administrator"

**Why it's on by default.** NEST also installs aircraft. Without administrator rights, installing the **757** through NEST fails with a permission error, because NEST can't write everything it needs into the protected folders the aircraft goes to. With NEST elevated, the 757 installs normally. If you only use NEST for things that don't need it, `-NoAdmin` is the safer choice: running a program with fewer rights is always the safer default.

**How it works.** Windows keeps per-program compatibility settings in the `AppCompatFlags\Layers` registry key. The `RUNASADMIN` layer tells Windows to require elevation whenever that `.exe` starts, whether you launch it from the shortcut, from Explorer, or by double-clicking the `.exe`. That's why it's set on the program and not just on the shortcut: a shortcut-only "Run as administrator" tick wouldn't apply when NEST is started any other way. The leading `~` is the normal prefix Windows itself writes for layers set through the Properties dialog.

**What you'll see.** A UAC prompt ("Do you want to allow this app to make changes to your device?") each time NEST starts. That's expected; click **Yes**.

## Known caveats

- **UAC on every launch.** That's what run-as-admin means. Use `-NoAdmin` if it bothers you.
- **The updater relaunching NEST.** Once an `.exe` requires elevation, a program that isn't elevated and starts it with the low-level `CreateProcess` call fails with error 740 ("The requested operation requires elevation"). Starting it with `ShellExecute` works and shows UAC instead. If NEST's updater (`BBSNestUpdater.exe`) restarts NEST after an update and that restart silently fails, just open NEST from the shortcut. If it keeps happening, run `-NoAdmin`. I haven't confirmed this either way; it's a general Windows behaviour worth knowing about.
- **Path-specific.** The admin flag is tied to the exact `.exe` path. If a future NEST version installs somewhere else, run the tool again.
- **Per user.** Each Windows account that uses NEST needs to run the tool once. That matches the per-user install.
- **Uninstalling NEST doesn't remove the shortcuts.** As explained above, NEST's uninstaller doesn't know about them. Run `Uninstall-NestShortcut.cmd` before or after uninstalling NEST.

## Fixing it by hand (no script)

If you'd rather not run a script:

1. Press **Win + R**, paste `%LOCALAPPDATA%\Programs\BlueBird Simulations\NEST` and press Enter.
2. Right-click **`bbs_nest.exe`** and choose **Show more options, Send to, Desktop (create shortcut)**.
3. For Start Menu search: press **Win + R**, paste `shell:Programs` and press Enter, then copy the new Desktop shortcut into that folder.
4. Optional, admin by default: right-click **`bbs_nest.exe`**, choose **Properties, Compatibility**, tick **Run this program as an administrator**, then **OK**.

This does exactly what the tool does.

## Undoing everything

- Double-click `Uninstall-NestShortcut.cmd`, **or**
- run `.\Install-NestShortcut.ps1 -Uninstall`, **or**
- by hand: delete the two `BlueBird NEST.lnk` files, and untick *Run this program as an administrator* in `bbs_nest.exe`'s Properties.

## Troubleshooting

**"Could not find bbs_nest.exe."** NEST isn't installed for your Windows account, or it's somewhere unusual. Pass the path with `-ExePath`.

**"Permission" or "access denied" error while installing the 757.** NEST isn't running elevated. Run the tool without `-NoAdmin`, close NEST completely, then start it again from the shortcut and click **Yes** on the UAC prompt.

**The shortcut exists but Start search still doesn't show it.** Give Windows Search a minute to index the new Start Menu entry, or sign out and back in. You can also check **Start, All apps, B**.

**No UAC prompt even though admin mode is on.** Your account might have UAC set to "Never notify", in which case Windows elevates silently. Or the flag wasn't written: open Properties on `bbs_nest.exe`, then **Compatibility**, and check the box.

**Antivirus flags the script.** It's about 150 lines of plain PowerShell; read it first. It makes two `.lnk` files and changes one registry value under `HKCU`. It downloads nothing and runs no other program.

## FAQ

**Does this modify NEST?**
No. It never touches any file in the NEST install folder.

**Is this safe to run more than once?**
Yes. It overwrites its own shortcuts and won't add `RUNASADMIN` twice.

**Will a NEST update undo it?**
Probably not, since updates usually replace files in the install folder and the shortcuts live elsewhere. If the install path changes, run the tool again.

**Why not use HKLM / Program Files / an all-users shortcut?**
NEST installs per user and registers itself under `HKCU`. Matching that keeps the fix admin-free and avoids touching anything other accounts use.

## Notes for the developer

If anyone at BlueBird reads this, the installer fix is small:

- At the end of the install, create `%APPDATA%\Microsoft\Windows\Start Menu\Programs\BlueBird Simulations\NEST.lnk` pointing at `bbs_nest.exe`. An optional Desktop shortcut, behind a checkbox, is a common extra.
- Add those `.lnk` paths to `uninstall.dat`, or delete them in `uninstall.exe`, so uninstalling cleans them up.
- Optionally, give the app an explicit AppUserModelID so taskbar pinning and Start grouping behave well.
- If NEST needs elevation, declaring `requireAdministrator` in the application manifest is clearer than relying on users to set compatibility flags. If it doesn't need elevation, nothing further is needed.

## Tested on

- BlueBird Simulations NEST **1.0.0.0** (per-user install, `%LOCALAPPDATA%\Programs`), October 2026
- Windows 11 (build 26200)
- Windows PowerShell 5.1 (the version built into Windows) and PowerShell 7

## License

MIT, see [LICENSE](LICENSE).

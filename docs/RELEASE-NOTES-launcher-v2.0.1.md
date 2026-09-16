# Project Reverie Launcher 2.0.1 — Rebirth

Fixes startup when the launcher EXE is moved without its companion configuration
file. The official public update configuration is now built into the EXE. Your
selected game folder and launcher preferences remain in your Windows profile.

Launcher updates still need a separate writable launcher folder outside WoW.
If an update is blocked, the error now identifies the folder and explains how
to recover. This check happens before creating an update workspace.

## Installing

Use **Check Updates** in the launcher and accept the 2.0.1 update. If your old
copy cannot start or reports that it is inside the WoW folder, close it, download
this release, and extract the **entire ZIP** into a fresh folder outside WoW.
Open that new copy. For desktop access, create a shortcut to the EXE.

Keep the executable named `ProjectReverie.Launcher.exe` for built-in updates.
An existing `launcher.bootstrap.json` is still respected; a damaged configuration
file is reported rather than silently ignored.

Content remains generation 1 / 0.1.30. This release preserves the 2.0.0 appearance,
gameplay content and native client data. No server or account changes are needed.
The package contains no game client or game archives.

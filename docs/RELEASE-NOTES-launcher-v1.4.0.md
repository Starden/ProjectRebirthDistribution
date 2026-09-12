# Project Reverie Launcher 1.4.0 — Rebirth

Download **Project-Reverie-Launcher-1.4.0-win-x64.zip**, extract the whole ZIP into
its own folder, and run **ProjectReverie.Launcher.exe**. No VPN or separate .NET
installation is required. Do not download the GitHub source-code archives.

## What's new

- The launcher now checks its own version against a separately signed HTTPS feed.
- New versions prompt you to open the official download page, with a persistent
  header download button if you choose later.
- Checks run on startup, Check Updates, and before installing content or playing.
- Required launcher upgrades block content installation and Play. Failed checks
  are shown as unavailable, never as proof that the launcher is current.
- Download and extract the newest ZIP manually; the launcher does not silently
  replace itself. Client selection and preferences survive the upgrade.

Users of older launchers must download 1.4.0 manually once to gain this feature.
The live game-content feed and server deployment are unchanged by this release.

## Closed-alpha limitations

This is an **onboarding/connection preview**, not a complete gameplay installer.
You still need your own lawful clean ChromieCraft WoW 3.3.5a build 12340 client,
matching native Rebirth data, and an approved account. The tester-side native-data
installer is still pending. Native Data Required is an intentional Play guard.
Character-creation-only access does not permit world entry. Mandatory first-login
password replacement is not implemented. No WoW client or MPQ is included.

Release metadata is ECDSA-signed; the executable is not yet Authenticode-signed,
so Windows may identify an unknown publisher. Compare the ZIP SHA-256 with the
checksum supplied through a separate trusted owner channel before running it.

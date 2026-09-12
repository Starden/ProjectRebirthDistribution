# Project Reverie Launcher 1.5.0 — Rebirth

Adds the missing **Prepare Client** step for outside testers.

1. Download `Project-Reverie-Launcher-1.5.0-win-x64.zip` and extract it into a new folder.
2. Run `ProjectReverie.Launcher.exe`. Your previous client selection is retained.
3. Locate your own clean ChromieCraft 3.3.5a build 12340 client if needed.
4. Select **Update** for addons, then **Prepare Client** and confirm.
5. Select **Play Rebirth** and log in with your privately supplied credentials.

Preparation reconstructs matching Rebirth item data from your own game files.
No game archive, WoW executable, credentials or extracted Blizzard data is
distributed. Original archives are not changed. All 36,260 custom item additions
are generated locally, with source-data, output-data and complete-archive hash
verification. Existing unknown patches are refused; repeated preparation of a
matching client is a no-op. No VPN, separate patcher, Python or .NET installation
is required. English enUS clean-client compatibility has been verified.

Launcher 1.4.0's **Native Data Required** blocker now has a working preparation
action. The existing signed launcher-version feed prompts older 1.4.0 users to
download this update. The signed addon content stays at 1.24.0.

Account permissions are unchanged: character-creation-only accounts still cannot
enter the world. Password replacement is not automatically enforced on first
login. No server gameplay, whitelist, database or Skillful changes are included.

The Windows executable is not Authenticode-signed; signed update metadata is a
separate protection. Review the checksum from your operator's trusted channel.
An actual outside tester login is still required to confirm end-to-end access.

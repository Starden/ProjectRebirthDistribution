# Project Reverie — Rebirth external-test onboarding

## What you receive

From GitHub, download only the latest
`Project-Reverie-Launcher-*-win-x64.zip` from the
[Project Reverie Releases page](https://github.com/Starden/ProjectRebirthDistribution/releases/latest).
The source-code archives and `.sha256` sidecar are not required to play.

You receive two things in total:

1. that single public Project Reverie launcher ZIP; and
2. one dedicated, non-GM Rebirth account credential through a private channel.

No WireGuard installation, VPN client, separate patcher, or other networking
package is required. Never share the account password. Report a compromised
credential immediately so the account can be revoked.

## Requirements

- Windows 10 or 11 x64;
- your own lawful, clean ChromieCraft WoW 3.3.5a client (build 12340);
- enough permission to update the selected game folder.

The Project Reverie launcher does not include or download World of Warcraft.

## First connection

**Launcher 1.6.4 / content 1.30.0 adds the visible display selector and coordinated QoL update, retaining the dedicated updater and fourth-spec/Feral Cat native preparation.** Use Start Here to
request an account and test the gateway. After updating the addons, select
**Prepare Client** to build Rebirth's item, Heirloom, fourth-spec and Feral Cat data from your own clean client.
No game archives are downloaded; original client files stay unchanged.
Already-matching native data are not rebuilt. After content 1.30.0 activates,
**Prepare Client** performs a one-time, recoverable backup of the enUS item cache
so revised stack sizes can be fetched; it does not clear other caches or settings.
Do not bypass verification. A character-creation-only account cannot enter the world
until the owner grants full access. Password replacement is not automatically
enforced on first login; follow the owner's private instructions.

1. Download the launcher ZIP from the announced GitHub Release.
2. Compare its SHA-256 with the value the owner sent through a separate trusted
   channel.
3. Extract the ZIP to its own folder. Windows may show an unknown-publisher
   warning because the pilot launcher is not Authenticode-signed yet.
4. Start `ProjectReverie.Launcher.exe`, select **Locate Client**, and choose the
   folder containing the clean `Wow.exe`.
5. Select **Update** for the signed addons.
6. Close WoW, select **Prepare Client**, and confirm.
7. Choose Fullscreen, Windowed, or Windowed Maximized in the selector beside Play.
   Once native data and gateway checks pass, select **Play Rebirth** and log in
   with the dedicated Rebirth test account.

The launcher writes the signed VPS gateway address automatically. Do not edit
`realmlist.wtf` manually.

## Safety and troubleshooting

- Starting with version 1.6.3, **Update and restart?** downloads and verifies a newer launcher.
  Yes downloads, verifies, installs and reopens it without a browser. No postpones
  the update; use the header's **Update to...** button later. Settings are retained.
  Every 1.6.2-or-older build needs one final manual fresh-folder ZIP update to
  the latest 1.6.4 because its earlier WPF helper cannot reliably install this repair.
  Version 1.6.3 can install 1.6.4 through the built-in prompt. The dedicated updater
  remains embedded; no separate install is needed. Content 1.30.0 requires 1.6.4.
- Keep the launcher separate from WoW in a regular writable folder, outside linked
  or cloud-managed folders. Keep `ProjectReverie.Launcher.exe` named as supplied.
  Failed replacements restore backups where safe; power loss may need manual
  recovery from `.reverie-update-*` in the launcher folder or a fresh ZIP.

- Do not bypass a manifest signature, expiry, rollback, or file-hash warning.
- Do not send screenshots containing an account password or personal network
  details.
- If the update feed is online but the game services are unavailable, contact the
  owner; do not change the realm address manually.
- If an older launcher says **Native Data Required**, update to 1.6.4 and use **Prepare Client**.
  Use a fresh-folder ZIP install only if running 1.6.2 or older, or recovering a failed update.
- If preparation reports a pending item-cache refresh, close WoW and retry
  **Prepare Client**. Keep its backups and markers; do not clear the whole Cache folder.
- Skill links are shareable descriptions, not proof of ownership or live effect validation.
  Fourth-spec talents and Skills retain their alpha/WiP labels where applicable.
- The native generator is tested on English enUS ChromieCraft build 12340. A
  mismatched source table or unknown existing archive is refused. Keep existing
  files and contact the owner; do not delete arbitrary archives.
- The launcher downloads its own verified updates and Project Reverie-owned addon files, and generates
  native Rebirth item and ability data locally. It does not repair original game archives
  or make another WoW version compatible.

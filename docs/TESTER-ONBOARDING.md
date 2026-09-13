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

**Launcher 1.6.0 includes fourth-specialization and Feral Cat native-data preparation.** Use Start Here to
request an account and test the gateway. After updating the addons, select
**Prepare Client** to build Rebirth's item, Heirloom, fourth-spec and Feral Cat data from your own clean client.
No game archives are downloaded; original client files stay unchanged.
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
6. Select **Prepare Client**, close this WoW client, and confirm.
7. Once native data and gateway checks pass, select **Play Rebirth** and log in
   with the dedicated Rebirth test account.

The launcher writes the signed VPS gateway address automatically. Do not edit
`realmlist.wtf` manually.

## Safety and troubleshooting

- Version 1.4.0 checks the launcher's own signed release feed and prompts when a
  newer launcher is available. Use its header download button or **Check Updates**
  to retry. Close the old launcher, extract the new ZIP to a fresh folder, and
  run it; your client selection is retained. Pre-1.4.0 users upgrade manually once.

- Do not bypass a manifest signature, expiry, rollback, or file-hash warning.
- Do not send screenshots containing an account password or personal network
  details.
- If the update feed is online but the game services are unavailable, contact the
  owner; do not change the realm address manually.
- If an older launcher says **Native Data Required**, upgrade to 1.6.0 and use **Prepare Client**.
- The native generator is tested on English enUS ChromieCraft build 12340. A
  mismatched source table or unknown existing archive is refused. Keep existing
  files and contact the owner; do not delete arbitrary archives.
- The launcher downloads only Project Reverie-owned addon files and generates
  native Rebirth item and ability data locally. It does not repair original game archives
  or make another WoW version compatible.

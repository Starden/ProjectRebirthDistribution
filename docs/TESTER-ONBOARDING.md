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

1. Download the launcher ZIP from the announced GitHub Release.
2. Compare its SHA-256 with the value the owner sent through a separate trusted
   channel.
3. Extract the ZIP to its own folder. Windows may show an unknown-publisher
   warning because the pilot launcher is not Authenticode-signed yet.
4. Start `ProjectReverie.Launcher.exe`, select **Locate Client**, and choose the
   folder containing the clean `Wow.exe`.
5. Select **Update**, then **Play**, and log in with the dedicated Rebirth test
   account.

The launcher writes the signed VPS gateway address automatically. Do not edit
`realmlist.wtf` manually.

## Safety and troubleshooting

- Do not bypass a manifest signature, expiry, rollback, or file-hash warning.
- Do not send screenshots containing an account password or personal network
  details.
- If the update feed is online but the game services are unavailable, contact the
  owner; do not change the realm address manually.
- The launcher manages only Project Reverie-owned Rebirth add-on files. It does not repair
  base client files or make another WoW version compatible.

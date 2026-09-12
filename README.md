# Project Reverie Distribution — Rebirth

## Player quick start

From this GitHub repository, you only need to download **one file**: the latest
`Project-Reverie-Launcher-*-win-x64.zip` from the
[Releases page](https://github.com/Starden/ProjectRebirthDistribution/releases/latest).

You do **not** need to download the source code, the `.sha256` file, WireGuard,
a VPN client, a separate patcher, or any other networking software. The launcher
handles Project Reverie updates for the Rebirth realm and writes the correct server address for you.

You will also need:

- your own lawful, clean ChromieCraft WoW 3.3.5a client, build 12340; and
- an approved Rebirth account supplied privately by the server owner.

**Current release: 1.5.0 — integrated client preparation.** You can request an
account and test the gateway immediately. After locating your own clean client,
**Prepare Client** generates and verifies Rebirth's native item data locally.
No game archives are downloaded and no separate patcher is needed. Original
client archives are left unchanged. Server access is granted separately:
a character-creation-only account cannot enter the world.

To get started:

1. Download the launcher ZIP from the Releases page.
2. Extract the entire ZIP into its own folder.
3. Run `ProjectReverie.Launcher.exe`.
4. Use **Start Here** to request an account and **Test Connection**.
5. Under **Home**, choose **Locate Client** and select your clean `Wow.exe` folder.
6. Choose **Update** for the signed Rebirth addons.
7. Choose **Prepare Client**, close this WoW client, and confirm local preparation.
8. Select **Play Rebirth** after checks pass and log in with your approved account.
   World entry also requires the owner's full-access approval.

If launcher 1.4.0 says **Native Data Required**, download 1.5.0 or newer, extract
it into a new folder and run it. Your client selection is retained. No password
reset or VPN is needed. This release is tested with the English enUS clean client;
incompatible source data or unknown existing patches are refused, not overwritten.

## Launcher updates

Starting with **1.4.0**, the launcher checks its own version on startup and when
you click **Check Updates**. When a newer version is available, it prompts you
to open the official release page; a download button remains in the header.
Download the new launcher ZIP, close the old launcher, extract the new ZIP into
a fresh folder, and run it. Your selected client and preferences are retained.
The launcher does not silently overwrite itself or execute downloads.

The launcher-release feed is signed independently of game-content updates.
An upgrade below the minimum supported version is required before installing
content or playing. Failed or expired checks are labelled unavailable, not
current. Older launchers need a **one-time manual upgrade to 1.4.0**.

Do not edit `realmlist.wtf` manually. The launcher does not include or download
the base World of Warcraft client. Windows may show an **Unknown publisher**
warning during this early test because the launcher is not yet Authenticode-signed.

For more detail, see the [tester onboarding guide](docs/TESTER-ONBOARDING.md).

## Repository purpose

This repository is the public distribution edge for a small, controlled Project
Rebirth test. It contains only:

- the HTTPS update site under `site/`;
- a detached ECDSA P-256 signature for the exact update manifest bytes;
- Project Reverie-owned Rebirth add-on payload files;
- public verification and release automation;
- publisher and tester documentation.

The launcher archive is uploaded directly to GitHub Releases and is deliberately
ignored by Git. The repository never contains a World of Warcraft client,
`Wow.exe`, MPQ archives, extracted Blizzard data, game credentials, WireGuard
private keys, or publisher private-key material.

## Public endpoints

- Update manifest: `https://starden.github.io/ProjectRebirthDistribution/stable/manifest.json`
- Detached signature: `https://starden.github.io/ProjectRebirthDistribution/stable/manifest.json.sig`
- Launcher version: `https://starden.github.io/ProjectRebirthDistribution/stable/launcher.json`
- Launcher version signature: `https://starden.github.io/ProjectRebirthDistribution/stable/launcher.json.sig`
- Launcher releases: `https://github.com/Starden/ProjectRebirthDistribution/releases`

The signed realm endpoint is the public VPS gateway at `134.122.124.150:3724`;
world service status uses `134.122.124.150:8087`. The gateway carries traffic to
the Rebirth host over a private WireGuard link and preserves public client
addresses with PROXY protocol v2. Testers do not install a VPN. The client-data
and account-access prerequisites above still apply.

## Validate locally

```powershell
pwsh -NoProfile -File ./tools/Test-PublicDistribution.ps1
```

Server operators should review [publishing](docs/PUBLISHING.md) and
[go-live checks](docs/GO-LIVE-CHECKLIST.md) before publishing anything.

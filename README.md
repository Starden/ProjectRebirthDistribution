# Project Rebirth Distribution

## Player quick start

From this GitHub repository, you only need to download **one file**: the latest
`Project-Rebirth-Launcher-*-win-x64.zip` from the
[Releases page](https://github.com/Starden/ProjectRebirthDistribution/releases/latest).

You do **not** need to download the source code, the `.sha256` file, WireGuard,
a VPN client, a separate patcher, or any other networking software. The launcher
handles Project Rebirth updates and writes the correct server address for you.

You will also need:

- your own lawful, clean ChromieCraft WoW 3.3.5a client, build 12340; and
- an approved Project Rebirth account supplied privately by the server owner.

To play:

1. Download the launcher ZIP from the Releases page.
2. Extract the entire ZIP into its own folder.
3. Run `ProjectRebirth.Launcher.exe`.
4. Choose **Locate Client** and select the folder containing your clean `Wow.exe`.
5. Choose **Update**, wait for verification to finish, and then choose **Play**.
6. Log in with your approved Project Rebirth account.

Do not edit `realmlist.wtf` manually. The launcher does not include or download
the base World of Warcraft client. Windows may show an **Unknown publisher**
warning during this early test because the launcher is not yet Authenticode-signed.

For more detail, see the [tester onboarding guide](docs/TESTER-ONBOARDING.md).

## Repository purpose

This repository is the public distribution edge for a small, controlled Project
Rebirth test. It contains only:

- the HTTPS update site under `site/`;
- a detached ECDSA P-256 signature for the exact update manifest bytes;
- Project Rebirth-owned add-on payload files;
- public verification and release automation;
- publisher and tester documentation.

The launcher archive is uploaded directly to GitHub Releases and is deliberately
ignored by Git. The repository never contains a World of Warcraft client,
`Wow.exe`, MPQ archives, extracted Blizzard data, game credentials, WireGuard
private keys, or publisher private-key material.

## Public endpoints

- Update manifest: `https://starden.github.io/ProjectRebirthDistribution/stable/manifest.json`
- Detached signature: `https://starden.github.io/ProjectRebirthDistribution/stable/manifest.json.sig`
- Launcher releases: `https://github.com/Starden/ProjectRebirthDistribution/releases`

The signed realm endpoint is the public VPS gateway at `134.122.124.150:3724`;
world service status uses `134.122.124.150:8087`. The gateway carries traffic to
the Rebirth host over a private WireGuard link and preserves public client
addresses with PROXY protocol v2. Testers need only the launcher, their lawful
clean client, and an approved game account.

## Validate locally

```powershell
pwsh -NoProfile -File ./tools/Test-PublicDistribution.ps1
```

Server operators should review [publishing](docs/PUBLISHING.md) and
[go-live checks](docs/GO-LIVE-CHECKLIST.md) before publishing anything.

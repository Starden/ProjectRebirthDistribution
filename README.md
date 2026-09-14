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

**Current release: launcher 1.6.1 / content 1.28.1 — built-in updates and corrected Heirloom on-use tooltips.**

**Next release prepared: launcher 1.6.2 / content 1.29.0.** The versioned launcher
archive is published and verified before the signed feeds change. Until that
second step, the active channels above remain unchanged. See the
[1.6.2 preparation notes](docs/RELEASE-NOTES-launcher-v1.6.2.md).
Heirloom r10 requires **Update → close WoW → Prepare Client**; its server rollout
is separately controlled and remains pending guarded deployment.

The 1.28.1 addon hotfix replaces inverted on-use ranges with the existing
level-scaled base bonuses for all four active Heirloom trinket families.
Use **Check Updates → Update** with WoW closed, then reopen the game.
No launcher replacement, Prepare Client step, or server restart is required.
Gameplay values and cooldowns are unchanged.
You can request an account and test the gateway immediately. After locating your
own clean client, **Prepare Client** generates and verifies Rebirth's item,
Heirloom, fourth-specialization, Feral Cat and tooltip data locally.
The update preserves the existing Skill descriptions, Currency tab, gear-upgrade
and Heirloom interface. Existing 1.6.0 and older users need one final manual ZIP
update to 1.6.1. Future updates prompt and install inside the launcher, without
redirecting to GitHub. If upgrading from before 1.6.0, also use
**Check Updates → Update → Prepare Client** with WoW closed.
Your selected client and launcher preferences are retained. Server activation is
separately controlled; installing client definitions is not proof every alpha
ability has passed in-game testing. Existing account permissions are unchanged.
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

If an older launcher says **Native Data Required** or **Release Pending**, download 1.6.1 or newer, extract
it into a new folder and run it. Your client selection is retained. No password
reset or VPN is needed. This release is tested with the English enUS clean client;
incompatible source data or unknown existing patches are refused, not overwritten.

## Launcher updates

Starting with **1.6.1**, choose **Yes** at **Update and restart?** to download,
verify, install and reopen a newer launcher automatically. Choose **No** to wait,
then use the header's **Update to...** button later. No browser or manual ZIP
extraction is needed for future updates. Your client selection and preferences
are retained. Updates install only after your confirmation.

**1.6.0 and older:** download the new ZIP once, close the old launcher, extract
into a fresh folder and run it. Older executables do not contain the self-updater.
Keep the launcher separate from WoW in a regular writable, non-cloud/linked folder,
and keep the executable named `ProjectReverie.Launcher.exe`. The updater replaces
only its four package files, not your game installation or saved settings.
Verified backups remain under `.reverie-update-*` in the launcher folder; a failed
replacement restores the previous files where safe. A power failure may need
manual backup recovery or a fresh ZIP. Never bypass signature/hash warnings.

The launcher-release feed is signed independently of game-content updates.
An upgrade below the minimum supported version is required before installing
content or playing. Failed or expired checks are labelled unavailable, not
current. Older launchers need a **one-time manual upgrade to 1.6.1**.

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

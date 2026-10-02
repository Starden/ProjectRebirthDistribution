# Project Reverie — Rebirth and Skillful

Download the latest **Project-Reverie-Launcher-2.3.0-win-x64.zip** from the [Releases page](https://github.com/Starden/ProjectRebirthDistribution/releases/latest), extract it into its own writable folder outside WoW, and run `ProjectReverie.Launcher.exe`.

Choose **Rebirth** or **Skillful** in the launcher before opening WoW. Each game uses a separate client folder. You need your own lawful, clean English enUS ChromieCraft WoW 3.3.5a client, build 12340, and an approved game account. Players need no VPN or separate patcher. The launcher does not include or download a game client or Blizzard archives.

## Current release

- Launcher **2.3.0**, with Goldleaf, Follow Realm and owner-painted game emblems. The Skillful feed requires launcher 2.2.0 or newer.
- Rebirth content **0.1.34**; its existing payloads and preparation remain unchanged.
- Skillful addon **0.12.1**, with compact Skills tiles, stacked levels, new Strength/Vitality/Devotion icons, and totals for level, combat level and completed quests. The accepted Northshire item tooltips, 167 physical affix variants and equipment-bonuses pane remain available.

Choose **Settings → Appearance → Follow Realm** for Void on Rebirth and Goldleaf on Skillful; the palette follows the selected game. Follow Windows, Void, Moonstone and Goldleaf can also be selected directly. Your existing preference is retained.

Existing player accounts now have Skillful access. Rebirth accounts newly copied to Skillful use the same password; accounts that already existed on Skillful retain their Skillful password. No password reset is required for this update.

See the [2.3.0 release notes](docs/RELEASE-NOTES-launcher-v2.3.0.md). Both games remain in testing; availability is controlled by the server operator.

## Play

1. Select **Rebirth** or **Skillful** in the launcher.
2. Use **Locate Client** to select that game's separate clean `Wow.exe` folder.
3. Choose **Update** to install the signed addons.
4. Close WoW, then use **Prepare Client** when prompted.
5. Select your display mode and **Play**, then sign in with your approved account.

Preparation creates the required data from your own client and verifies the result. Original game archives and character settings are preserved. Unknown custom patches or incompatible source data are refused. Do not share one prepared client folder between the two games or edit `realmlist.wtf` manually.

Rebirth retains all fourteen non-Monarch Heritage definitions, four-tree talent previews, current-level and level-80 Heirloom comparisons, the Currency tab, gear upgrades and Wardrobe. Both Heirloom tooltips remain visible at level 80. Existing item-cache preparation stays valid unless the launcher asks you to refresh it. Skillful retains its profession repair and equipment requirements. Its approved first item pass now uses 165 supported static item definitions and 167 exact physical affix mappings across 20 additional items against the Northshire test creatures. Five other item mappings and 347 unsupported affix variants remain held. Unsupported equipment and enchants retain the existing combat rules; wider-world conversion and weapon-skill changes are pending.

New players can use **Start Here** to request an account and **Test Connection**. The owner reviews access before world entry. The [tester onboarding guide](docs/TESTER-ONBOARDING.md) contains further Rebirth guidance.

## Launcher updates

The launcher checks a separately signed release feed and offers a verified update to 2.3.0. Accept **Restart to update** when ready. Your selected client folders and preferences carry over. Keep the launcher in its own regular writable folder outside WoW; a desktop shortcut can point to it.

If an older launcher cannot start or update, close it and extract the complete latest ZIP into a fresh folder. Versions 1.6.2 and older require this manual upgrade once. The dedicated updater is embedded in newer packages, so no separate updater installation is needed. Windows may show **Unknown publisher** because the package is not yet Authenticode-signed.

Launcher updates replace only the four package files. Verified backups are retained under `.reverie-update-*`; failed replacements restore the previous files where safe. Do not bypass signature or hash errors.

The signed launcher feed is valid through November 1, 2026; the Skillful feed is valid through October 31, 2026. Rebirth's existing signed content renewal is preserved. Feed renewal is an operator task, even when content has not changed.

## Public endpoints

The launcher chooses the appropriate signed feed and configures the game endpoint:

| Game | Login | World | Signed content |
| --- | --- | --- | --- |
| Rebirth | 134.122.124.150:3724 | 134.122.124.150:8087 | [Rebirth stable feed](https://starden.github.io/ProjectRebirthDistribution/stable/manifest.json) |
| Skillful | 134.122.124.150:3725 | 134.122.124.150:8085 | [Skillful stable feed](https://starden.github.io/ProjectRebirthDistribution/skillful/stable/manifest.json) |

The [launcher release feed](https://starden.github.io/ProjectRebirthDistribution/stable/launcher.json) and [public verification key](https://starden.github.io/ProjectRebirthDistribution/update-signing-public-key.pem) are served over HTTPS. Detached signatures accompany both game manifests and the launcher feed.

## Repository purpose and validation

This repository contains the public HTTPS distribution site, signed metadata, Project Reverie-owned addon payloads, verification automation and player documentation. Launcher ZIPs are uploaded to GitHub Releases and excluded from Git. No client, Blizzard data, account credentials, publisher private key or VPN profile belongs here.

Run `pwsh -NoProfile -File ./tools/Test-PublicDistribution.ps1` to validate the signed feeds, payloads and launcher archive. Operators should follow the [publishing procedure](docs/PUBLISHING.md) and [go-live checks](docs/GO-LIVE-CHECKLIST.md).

# Project Reverie Launcher 1.6.2 — Heirloom r10 preparation

This release prepares the client for Heirloom r10. The signed content 1.29.0
rollout and server activation are separate steps. Server r10 rollout remains
pending guarded deployment; a client package does not activate server gameplay.

## Updating

Launcher 1.6.1 can install the signed 1.6.2 update through its normal prompted
self-updater. From 1.6.0 or older, close the launcher and extract the complete
1.6.2 ZIP into a fresh folder. Your selected client and preferences are retained.

When signed content 1.29.0 is offered, choose **Update**, close WoW, then choose
**Prepare Client** before Play. Keep your original game archives and do not
overwrite an unrecognized custom patch.

## Native preparation

- Adds locally generated native support for upgradeable Swift Hand of Justice,
  Discerning Eye of the Beast and Dread Pirate Ring families.
- Supports distinct paired-item progression and explicit fist hand slots.
- Preserves the existing fourth-specialization and Feral Cat native bytes.
- Recognizes approved r8/r9 archives and both r9 tooltip serializations, keeping
  exact recoverable backups during an upgrade.
- Refreshes only the enUS `itemcache.wdb` when upgrading a recognized old patch.
  The exact old cache is backed up; unrelated caches and WTF settings stay intact.
- An interrupted cache refresh blocks Play until Prepare Client finishes, even
  when the new native archive is already present. Keep pending markers/backups;
  do not bypass errors or delete unrelated files.

Of the 34 signed owned addon payloads, only `HeirloomTooltips.lua` and the addon
TOC version change. The other 32 files, including wardrobe, are byte-preserved.
No WoW client, MPQ or extracted native table is distributed.

## Validation and archive

Validation includes 60 r10 upgrade/cache checks, 70 fourth/native compatibility
checks, 48 self-update checks, 130 package/feed checks and 10 two-file staging
tests. A disposable 1.6.1 test host exercised the production update helper through
verified 1.6.2 executable restart, with exact backups and unchanged user settings.
Interactive Yes/No prompt acceptance and authenticated gameplay are separate
operator acceptance steps, not claims made by these automated tests.

`Project-Reverie-Launcher-1.6.2-win-x64.zip` is 61,654,575 bytes.

SHA-256: `2f2f07efc938ea148172b088d3108169a8a7c1b6211081740104c77626b7dc1a`

The launcher is not Authenticode-signed. Its signed update feed is not a Windows
publisher certificate; keep the published SHA-256 verification and normal safety
checks in place.

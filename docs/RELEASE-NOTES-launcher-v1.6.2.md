# Project Reverie Launcher 1.6.2 — Heirloom r10 preparation

> **Correction published with 1.6.3:** the earlier WPF helper can fail before
> readiness. Do not rely on 1.6.1 or 1.6.2 to install the repair. Close the old
> launcher and extract the complete 1.6.3 ZIP into a fresh regular folder. Your
> selected client and preferences remain in your Windows profile.

This release prepares the client for Heirloom r10. Signed content 1.29.0 and the
matching Rebirth server catalog are now active for alpha testing. Players still
need to Update with WoW closed and run Prepare Client before entering the realm.

## Updating

The text below records what was believed at the time of release; the correction
above supersedes its self-update claim. A manual fresh-folder 1.6.3 installation
is required for every 1.6.2-or-older user.

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

The earlier process fixture used a renamed console smoke executable and did not
exercise packaged WPF helper startup; the correction above supersedes its update
claim. Actual packaged testing later reproduced failure before readiness.

`Project-Reverie-Launcher-1.6.2-win-x64.zip` is 61,654,575 bytes.

SHA-256: `2f2f07efc938ea148172b088d3108169a8a7c1b6211081740104c77626b7dc1a`

The launcher is not Authenticode-signed. Its signed update feed is not a Windows
publisher certificate; keep the published SHA-256 verification and normal safety
checks in place.

# Project Reverie Launcher 1.6.3 — durable self-update baseline

Launcher 1.6.3 replaces the unreliable WPF helper used by 1.6.1 and 1.6.2 with a
dedicated self-contained updater embedded inside the normal launcher. The public
download remains one ZIP containing exactly four files; players do not install a
separate updater.

## Required one-time installation

Every player on launcher 1.6.2 or older must close the old launcher, download the
complete 1.6.3 ZIP from this release, and extract every file into a fresh regular
folder outside WoW, Program Files, linked folders, and cloud-managed folders.
Run `ProjectReverie.Launcher.exe` from that folder. The selected WoW client and
launcher preferences are retained in the player's Windows profile.

Do not rely on the older launcher's in-app update prompt for this repair. Starting
with 1.6.3, later signed launcher updates can be accepted and installed in the
launcher without opening GitHub.

## What changed

- Embeds a dedicated non-WPF updater while preserving the exact four-file public
  package.
- Pins the parent process, updater, signed metadata, archive, target version, and
  exact old-file inventory before replacement.
- Uses durable journals, result/failure receipts, same-volume staging, exact
  backups, executable-last replacement, and bounded rollback.
- Refuses game folders, reparse paths, unknown package files, unsafe redirects,
  tampered downloads, concurrent installs, and unexpected file changes.
- Restarts only a launcher with a verified old or new identity.
- Preserves the selected client and settings in LocalAppData and does not modify
  accounts, server processes, base client archives, or gameplay content.

## Validation

The updater passed 48 unit/regression checks. A process test used the actual
packaged WPF 1.6.3 launcher, actual embedded-updater build, and signed private
1.6.4 fixture; it verified readiness, replacement, exact backups, receipts,
settings preservation, and actual WPF restart. A deliberately incorrect updater
hash failed closed while the original WPF launcher remained open.

Content remains version 1.29.0 byte-for-byte. This is a launcher-only release;
Rebirth server state, account permissions, and Skillful are unchanged.

`Project-Reverie-Launcher-1.6.3-win-x64.zip` is 94,809,867 bytes.

SHA-256: `741f2cf673d1cb79ee2a93c9e33322af68b608eae38470b39d7e4a30ed44eae1`

The executable is not yet Authenticode-signed, so Windows may display Unknown
publisher. Antivirus policy, permission changes, and sudden power loss remain
external failure modes; retain `.reverie-update-*` recovery data until a failed
attempt is resolved, and use a fresh signed ZIP if instructed.

# Project Reverie Launcher 2.0.2 — Longer updater validation and new Heritages

Updater validation now allows up to five minutes instead of about 20 seconds,
giving slower PCs more time to verify and unpack the update. Errors and
cancellation still stop the wait promptly; security and rollback checks remain
unchanged. This may help slow validation, but does not resolve every cause of
an updater failure.

If launcher 2.0.1 still times out while updating, close it and extract the entire
2.0.2 ZIP into a new folder outside your WoW folder, then open
`ProjectReverie.Launcher.exe` there. The old executable retains its old timeout
until replaced. Do not copy just the EXE into your WoW directory.

Adds the matching native spell data for the first new combat Heritage batch:
Vampire and Demonic. Their levels persist across Lives. The Heritage page shows
their current effects and signature abilities using server-provided values.
Other unfinished Heritage designs remain unavailable.

Update the launcher, close WoW, install the client update, and use **Prepare
Client** when prompted. Preparation upgrades the known previous Rebirth patch
and keeps a backup. Unknown custom patches remain refused. Your characters,
client settings, and existing Heirloom data are not reset.

The 2.0.1 portable startup fix, Void/Moonstone appearance, and content 0.1.32
Heirloom tooltip fixes are retained. Content generation 1 / version 0.1.33
requires launcher 2.0.2. There is no separate patch download: the launcher builds
the required native data from your own lawful local client.

This is a playable-alpha Heritage release, not a claim of exhaustive gameplay
testing. World Difficulty and Hunts remain disabled. No account permissions or
other realms are changed. The package includes no game client, DBCs or MPQs.

Validation: updater 68 (including five-minute deadline, early failure and
cancellation), portable startup 10, release policy 29, and package validation
53 checks passed for the updated build. The preceding Heritage candidate passed
native/update 90 and content generation 19 checks. Server unit tests and isolated
startup passed separately; real-player combat remains to be tested.

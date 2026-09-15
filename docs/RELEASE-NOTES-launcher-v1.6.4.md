# Project Reverie Launcher 1.6.4 — Rebirth quality-of-life update

Launcher 1.6.3 users can accept this signed update inside the launcher. Players on
1.6.2 or older should close the old launcher and extract the complete ZIP into a
new regular folder outside WoW, Program Files, linked folders, and cloud-managed
folders. Your selected client and preferences remain in your Windows profile.

## Launcher changes

- Windowed/fullscreen selection is visible beside the main launch controls and
  saves automatically; it is no longer necessary to search Settings.
- Preserves the dedicated, verified self-updater introduced in 1.6.3.
- When verified Rebirth content 1.30.0 is available, Prepare Client safely refreshes
  the item-query cache once for the new stack definitions. It backs up the old
  cache, requires WoW to be closed, and does not erase other client caches.

## Coordinated Rebirth content 1.30.0

Activated September 15, 2026: the matching server update is running and the signed
content feed now serves 1.30.0. The public feed signatures, all 35 addon payloads,
and the launcher ZIP were verified after publication. The launcher requires
verified 1.30.0 content before completing the new item-cache refresh.

The coordinated update contains fourth-specialization talent preview fixes,
Shift-click chat links for fourth-spec talents and Rebirth Skills, current-level
and level-80 Heirloom comparisons, Gladiator Stance persistence corrections,
two-handed Heirloom upgrade costs of 2/4/6/8/10 materials, and 200-item stacks for
eligible items previously limited to 20. Unique and other specially restricted
items keep their limits. Mixed native/fourth-tree talent commits use two phases;
they are not an atomic transaction across both systems.

Account approvals and Skillful are not changed by this release. Players still
need their own clean, lawful WoW 3.3.5a build 12340 client; no game archives are
included. After updating, close WoW, use Prepare Client if prompted, then Play.

## Validation and limitations

Offline checks cover the display controls, cache-refresh safety, public package,
and dedicated updater. A process test used the actual packaged 1.6.3 launcher and
its updater to install this exact signed 1.6.4 package in an isolated folder. It
verified replacement, exact backups, settings preservation, restart, and a
rejected update leaving the original launcher open. In-game gameplay checks are
still required after the coordinated server update.

The ZIP contains exactly four files and is 94,802,519 bytes.

SHA-256: `c9a5369434ce708751b671d47631700591095a777163630654c0542a67c464c9`

The executable is not Authenticode-signed yet; Windows may show Unknown publisher.
Signed update metadata and archive hashes are verified by the launcher. Keep
`.reverie-update-*` recovery files if an update fails and share its error report
with the operator.

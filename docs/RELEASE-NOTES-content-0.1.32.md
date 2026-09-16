# Rebirth content 0.1.32 — Heirloom tooltip pair restored

Fixes the missing level-80 panel introduced in 0.1.31. Heirlooms display your
current level on the left and level 80 at the same upgrade rank on the right.
Both panels remain visible at level 80, where matching stats are expected.

The preview is anchored before native rendering and rebuilt when the client
clears its contents after hiding. Linked-item tooltips clear their previous
native contents before rendering the same link again. The pair retains stable
positions across repeated merchant refreshes.

Close WoW and use the launcher's client **Update** action, then reopen the game.
Launcher 2.0.0 or newer supports this update; the latest launcher remains 2.0.1.
No new launcher download or Prepare Client rebuild is needed for this hotfix.

Only the tooltip Lua file and addon version changed. Item stats, rank scaling,
spells, private native data, and server gameplay are unchanged.

Validation: 61 Lua 5.1 tests passed. The three new native-lifecycle regressions
fail against 0.1.31. Live WoW 3.3.5a checks on a level-80 character confirmed both
panels for the Cloaks of Grace and the Hunt, stable hovering, switching items,
leaving and reopening the same hover, and a linked-item pair. Lower-level
characters were covered by automated tests, not a live visual check. No server
build, restart, or SQL migration was required for this addon-only correction.

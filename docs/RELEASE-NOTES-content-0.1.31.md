# Rebirth content 0.1.31 — Heirloom tooltip stability

Heirloom previews now consistently show **your current level on the left** and
**level 80, at the same upgrade rank, on the right**. Both panels remain visible
at level 80; matching stats at that level are expected.

The pair keeps its position during repeated merchant refreshes. When it is near
the screen edge, the pair shifts together to make room rather than swapping
sides. Native comparison panels no longer compete with this pair for recognized
Rebirth Heirlooms. Ordinary items and inspected-player comparisons retain their
native behavior.

Use the launcher's client **Update** action with WoW closed, then reopen the game.
Launcher 2.0.0 or newer supports this content; the latest launcher remains 2.0.1.
No new launcher download or Prepare Client rebuild is needed for this hotfix.

Only the tooltip Lua file and addon version changed. Item stats, rank scaling,
spells, native client data, and server gameplay are unchanged.

Validation: 58 Lua 5.1 tests passed, including stable repeated hovers, current/80
level rendering, level-up refreshes, item-cache events, native comparison fallback,
instance-link preservation, all 948 private catalog entries, and existing armor,
damage and on-use presentation checks. Six new regression cases fail against the
previous renderer. These checks do not substitute for visual acceptance in the
player's running client.

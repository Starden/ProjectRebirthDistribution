# Rebirth content 1.28.1 — Heirloom on-use tooltip hotfix

Corrects inverted displays such as Warmaster's `9 to 8`. These custom effects
grant a fixed, level-scaled base bonus; they are not random ranges.

All six ranks of the four active trinket families are covered: attack power,
caster spell power, tank absorb, and healer mana/spell power. Native duration,
cooldown and green text styling are preserved. Explicit item-link preview levels
are respected; ordinary tooltips use the viewer's level, capped at 80.

This changes item-tooltip presentation only, not spell/buff tooltip frames,
combat values, item stats, native client data, server configuration or account
access. Unknown items, native layouts and catalog revisions remain untouched.

Launcher 1.6.1 remains current. Close WoW, choose **Check Updates → Update**, then
reopen the game. No Prepare Client step or separate download is necessary.

Validation: 30 existing tooltip tests plus 12 on-use tests, including 1,920
item/level comparisons against the approved native spell data. This is automated
Lua/native-data parity testing; in-game visual confirmation remains a follow-up.

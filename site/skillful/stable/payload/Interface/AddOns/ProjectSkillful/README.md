# Project Skillful addon

WoW 3.3.5a progression display for Project Skillful (addon v0.12.0). Copy this directory under a legal
client's `Interface\AddOns` directory, enable it at character selection, and enter `/skillful` or use
the Skills button on the menu bar (between Talents and Achievements).

## Presentation

Every player-facing surface is built from the client's own templates and art, so it reads as part of
the stock interface rather than an addon:

- **Skills window.** A standard left-docked UI panel in the character frame's art: portrait ring,
  title bar, close button, bottom tabs, and the Skills tab's footer wells. It docks and shifts like the
  Spellbook or Talents, closes with Escape, and plays the stock open, close, and tab sounds.
  - *Skills tab:* all 22 server-authoritative skills and eight planned ones in a three-column grid of
    spellbook-style slots (icon, gold name, level beneath). Planned skills are greyed and desaturated.
    Tooltips give level, total experience, and experience to the next level. Total level sits in the
    footer well.
  - *Skill detail:* opened by clicking a skill. Shows the stock Skills-tab progress bar, experience to
    the next level, and, for professions, an **Open** button. That button is a secure action button,
    because casting a profession spell is protected and cannot be done from ordinary addon code.
  - *Combat tab:* the combat style set by the equipped weapon, and the server-authoritative experience
    training choices as spellbook-style check buttons (Attack/Strength/Defence, Ranged/Defence, or
    Magic/Defence).
- **Resource bars.** Mana takes the stock power bar's exact slot and frame level in the player frame.
  Rage and Energy hang beneath it in the art WoW uses for a shapeshifted druid's mana bar. All three
  follow the Interface Options status-text setting and show their numbers on hover.
- **Character sheet.** The stock attribute panel keeps its two stat columns, backing art, and tooltips,
  headed *Combat Skills* and *Hero*: Attack, Strength, Defence, Ranged, Magic, and Devotion; Vitality,
  maximum Health, Mana, Rage, Energy, and Style. The level line reads "Level N Race Hero" using combat
  level.
- **Equipment bonuses.** Opening the character equipment tab also shows an attached pane with
  Accuracy, Power, and Pierce/Slash/Crush/Ranged/Magic defense totals. These are the effective
  whole-point loadout totals supplied by the server, after aggregation, caps and rounding.
  Hover each row for its effect and related skill; hover the status for scope and readiness.
  Active, inactive and waiting states are distinct. Missing or inactive totals show a dash,
  while a confirmed zero shows `+0`. Bonuses apply only against configured Northshire test
  creatures; the current melee enemies do not exercise Ranged or Magic defense. Existing
  combat-skill/resource columns remain intact, with extra skill explanations on hover.
  The pane follows equipment, style and protocol changes, closes with the character sheet,
  and is hidden on other character tabs. The client never reconstructs combat totals from
  item previews or native WoW ratings, and no combat formula is changed.
- **Quest rewards.** Quest details, turn-in, quest log and map reward panels show one Bottle of
  Experience with the vial icon and normal item tooltip after the server confirms its reward policy.
  The addon keeps native rewards and choice buttons intact, including quests with no native rewards.
- **Messages.** Experience and level-ups use the client's own wording, and are routed to whichever chat
  windows show the Experience and Skill-ups message types, in the player's configured colours: "You gain
  48 Attack experience." and "Your skill in Attack has increased to 5." A training change is confirmed
  once the server accepts it ("You are now training Attack and Strength."), and a refused change
  appears as a red error message like any other.

`/skillful debug` opens a separate diagnostics window containing addon/protocol versions, snapshot
readiness, revision, combat level, training flags, resource values, received skill-row count, and
the latest XP gain. `/skillful trace` separately toggles malformed-payload chat logging.
`/skillful button` hides or shows the menu bar button. Debug telemetry is deliberately absent from
the player-facing surfaces.

## Protocol

The server sends protocol version 3 over the registered `PSKILL` addon prefix. A snapshot begins
with `H|3|revision|meleeSelection|rangedSelection|magicSelection|combatLevel|style` and contains one
`K|skillId|xp|level|nextLevelXp` message per catalog skill, followed by
`R|manaCurrent|manaMax|rageCurrentDisplayed|rageMaxDisplayed|energyCurrent|energyMax`.
The optional `Q|1|900000|1` row confirms one Bottle of Experience per completed quest;
`Q|1|0|0` disables that preview. Missing, malformed and unsupported policies display no promise.
The addon accepts whole-XP rows only after a supported header. An unsupported
header, including a differently shaped v4 header, blocks subsequent skill and
resource rows until a fresh v3 header arrives. Cached XP is preserved during rejection.
After a valid positive-maxima Hero row arrives, the addon shows the Hero resource bars and
suppresses the stock single-power bar and its text. Before
that row, or for an all-zero non-Hero row, the Hero bars stay hidden and the stock bar remains intact.
Indexed native WotLK power values are only a pre-snapshot fallback; they cannot overwrite an
authoritative R row. Rage is displayed directly from indexed native client points; the server
converts Wrath's internal units before serializing the R row. A
training selection request is sent as
`T|M|selection`, `T|R|selection`, or `T|G|selection` through a private addon whisper to the player;
the server validates melee bitsets 1–7 and ranged/magic bitsets 1–3,
persists the selection with a revision bump, and echoes a fresh authoritative snapshot. The addon
never calculates or persists authoritative XP, training state, or resource state.

## Equipment requirements

The optional `E|1` catalog adds tier and permanent trained-skill requirements to native
item tooltips. Requirements are red when unmet and white when met; the server enforces
them independently. Login and `/reload` request a complete catalog with `E|1|GET`.
The server's native self-whisper echo of this request is ignored by the catalog parser.
Definitions remain hidden until `BEGIN`, all rows, and a matching `END|count` arrive.

After an addon update, enter `/reload` and hover the item again. Cruel Barb should show
`Requires Attack 20 (yours: N)` for this slice. This is trained Attack, not combat level.

No patches or protected Blizzard assets are required or bundled.

## Profession repair (0.11.2)

The server now repairs missing base profession and action spells on login even when the native
skill row already exists. Profession ranks continue to mirror Skillful experience at 1–100.
Mining opens Smelting; gathering professions provide their native gathering action.
Secure profession buttons explicitly use a left-button release. Relog after this server update.

## Northshire equipment (0.12.0)

The approved v0.1 budgets now cover 165 static items and 167 exact physical
item/affix pairs across 20 more Northshire items. The two free test vendors still
supply all190 test items. The other347 affix pairs, four Magic/recovery items and
Tribal Pants remain held; unsupported equipment keeps the whole previous combat
path. Native templates, instances, rolled names, prices and weapon skills are preserved.

All supported items use the accepted Cruel Barb layout: native rarity/name/icon
and actual binding, equipment slot/type/material, then gold Tier N - Step directly
underneath. Offense and five defense styles appear in clear groups, with permanent
trained-skill gates and your current levels. Armor's active-family offense follows
the current physical style; this does not grant simultaneous melee and ranged bonuses.
The two ungated starter fixtures retain their approved Tier1/Entry presentation.
Only Cruel Barb shows its verified Edwin VanCleef source; no other drop sources,
sets or effects are fabricated. Item points retain two decimals; the character
pane shows the separately supplied effective whole-loadout totals.

The authenticated atomic A|1 extension identifies each supported host/property
pair alongside existing B|1 static definitions, E|1 gates and L|1 effective totals.
The hovered link's property ID must match exactly. A partial/malformed/unsupported
catalog clears stale data. Unexpected variants or added enchant/gem modifiers keep
the native tooltip and show an unmapped-state notice. Old addons ignore A|1 safely.
No DBC records or client art are bundled; identities and icons come from GetItemInfo.

The opaque navy body and icon refresh in place across bags, vendors, linked items
and comparison frames, retaining native owner/anchors and binding. Missing cached
identity restores native text. Hide, item changes and rejected data clear the custom
presentation. Bonuses apply only to configured Northshire test creatures; an orange
inactive notice means the current whole loadout is unsupported. Wider-world combat
continues to use existing item behavior. These points are not percentages or flat
added damage. No gameplay formula, HP/Mana rule or weapon skill is changed.

The owner accepted the Cruel Barb0.11.7 layout and character pane0.11.8. Expanded
armor/ranged/affix layouts and real-client equip/relog checks remain owner acceptance.
The rejected addon-free Cruel Barb description stays withdrawn. Enable ProjectSkillful
in AddOns for these tooltips.

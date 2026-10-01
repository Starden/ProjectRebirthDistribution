# Project Skillful addon

WoW 3.3.5a progression display for Project Skillful (addon v0.11.7). Copy this directory under a legal
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

## First item-balance slice

Supported equipment shows Northshire bonus previews for accuracy, power and five defence styles.
The first batch contains 164 static items, including starter equipment and Cruel Barb.
These bonuses apply against the existing Northshire test creatures. Other world combat keeps its current rules.
If your equipment has an unsupported item, random affix, special effect or enchant, your whole loadout keeps the existing rules; the tooltip reports that state.
The 26 held first-batch entries still need mappings. Native item text is retained for wider-world use.
Weapon skills are unchanged.

## Cruel Barb reference tooltip trial (0.11.7)

Only Cruel Barb (5191) replaces its normal tooltip with the requested item layout:
its own rarity-colored name/native icon and binding, One-Hand/Sword header,
then a gold `Tier N - Step` line directly underneath using the server's catalog
(Cruel Barb is currently `Tier 3 - Entry`),
grouped melee offense/five defense lines, trained Attack20 requirement with your current level, and
Edwin VanCleef drop source. Existing approved/authenticated server bonus data is
used; Stab/Slash/Crush/Ranged/Magic order is preserved (Stab displayed as Pierce).
Accuracy is labeled as hit chance and Power as maximum hit; these are bonus points,
not percentages or flat damage. All approved two-decimal values are retained.
A solid dark navy texture fills the body; tinting the stock background alone left
the scene visible in the owner's 0.11.5 screenshot. Requirements turn red when unmet and white
when met. The body refreshes in place, retaining the hovered item's binding and
native owner/anchors. Normal damage/AP/flavor rows are omitted from
this Northshire view. There is no fabricated set or effect. Other items retain
the existing preview/tooltips; actual combat values/requirements are unchanged.

The gray "Bonuses: Northshire test creatures only" and orange "Inactive: unsupported equipment" remain truthful:
these bonuses apply only against the configured Northshire test creatures with
supported equipment. Wider-world combat still uses the existing item behavior.
Both committed server catalogs and cached native identity are required; stale,
malformed/unsupported protocol or missing data restores the standard tooltip.
GameTooltip, linked items and both comparison tooltip frames are covered. Icon
and solid fill/custom colors are removed when changing items or hiding the tooltip. No
client artwork is bundled; the icon is supplied by the client's GetItemInfo.

The addon-free trial was visually rejected: stock WoW quotes descriptions below
its retained weapon/spell lines. Its description is withdrawn by the additive
2026_10_01_01 world migration. Enable ProjectSkillful in AddOns for this new trial.
The owner accepted the cleaned 0.11.6 layout and solid background. The new tier
line's real-client placement and comparison rendering still need the owner's check.

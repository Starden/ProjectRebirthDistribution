# Rebirth content 0.1.38

Close the game and choose **Update** in launcher 2.3.3, then Play. This addon
update does not require rebuilding matching native client data.

- **Nameplates:** `/splates` opens four live sliders: overall size (75–250%),
  name text, level text and rank badges (75–150%). Settings save automatically;
  Reset defaults restores the original sizes. `/rplates` remains an alias.
- **AddOns:** open **Esc → AddOns** to search and enable or disable third-party
  addons. Use **Reload UI** to apply changes, or **Undo changes** to revert them.
  Required dependencies enable together. Addon changes and reload wait for combat
  to finish. Built-in interface addons cannot be disabled from this menu.
- **Combat glow:** the stock flash stays hidden during combat; threat lights the
  custom halo while the frame keeps its gold color. This includes Claude's fix.

Disabling Project Reverie also removes these menus after reload. It can be enabled
again from AddOns at character selection. Character settings are retained.

Validation: 78 nameplate checks, 19 boundary cases, 16 options/menu cases, Lua 5.1
compilation of 27 public addon files, 175 progress checks and the existing panel,
menu, menu integration and 2,141-entry Glossary regressions pass. The packaged
launcher passed 229 signed-update checks with synthetic clients, including a
normal Update from 0.1.37 and preservation of private data and saved variables.
Live game layout and reload behavior remain to be checked.

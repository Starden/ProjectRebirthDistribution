# Rebirth content 0.1.39

Close WoW and choose **Update** in launcher 2.3.3, then Play. This addon-only
update does not require a client repair or rebuilding matching native data.

- Open **/splates** (or **/rplates**) and uncheck **Use Rebirth nameplates**.
  Choose **Reload UI** to use Blizzard's normal plates or another nameplate addon.
- Check the option and reload again to restore Rebirth's skin. Your plate sizes
  are retained. **Reset sizes** changes sizes only; it does not turn the skin on.
- The selection saves automatically. Existing players retain Rebirth's plates
  until they opt out. Reload UI becomes available after combat ends.

When the skin is disabled, Rebirth does not scan, restyle or suppress stock
nameplate regions. Normal nameplate visibility remains controlled by the game;
this option does not enable or disable any other addon. Use **Esc → AddOns**
or the character-selection AddOns menu for those selections.

Validation: 78 nameplate checks, 19 boundary cases and 26 options/menu cases
pass, including ten new opt-out/reload cases. All 27 public Lua files compile.
The actual packaged launcher passes 230 signed-update checks with synthetic
clients, including Update from 0.1.38 and preservation of private data and settings.
Live game visuals and specific third-party nameplate addons remain untested.

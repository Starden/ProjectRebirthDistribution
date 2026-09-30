# Project Reverie Launcher 2.1.0 — Choose your world

Home now offers Rebirth and Skillful cards, each with its own status, client
folder and Play button. Your existing Rebirth settings carry over. This is an
optional launcher update; the minimum supported launcher remains 2.0.3.

- Pick a world on Home; the launcher remembers your choice.
- Launcher updates download and verify in the background. Click **Restart to
  update** when the header says the update is ready. Installation still requires
  that click; the startup update pop-up has been removed.
- Updated game cards, selection highlighting, scrollbars and spacing support
  Void, Moonstone and Windows high contrast.
- Rebirth retains the complete 2.0.3 Heritage/native-data fixes and content 0.1.34.

Skillful remains **Awaiting first release / COMING SOON**. Its public gateway and
signed content feed are not part of this release. Skillful will require a
separate clean client folder. The Start Here tab still describes Rebirth onboarding.

Existing players can accept the launcher's update. For a manual install, close
the launcher and extract the complete ZIP into its own writable folder outside
WoW. Do not extract it over a running launcher.

Validation: the exact public package passed 53 checks. A saved process-test
receipt confirms the published 2.0.3 launcher handed off to its 2.0.3 updater,
installed this 2.1.0 package and restarted successfully; a rejected update plan
preserved the old launcher and settings. Release-policy, content-generation,
portable, setup, multi-game, self-update and UI-state suites passed during build
validation. The newly added background-download/restart interaction has automated
coverage but has not been clicked end to end against a newer published version.
No Skillful public connectivity or new server gameplay is claimed by this release.

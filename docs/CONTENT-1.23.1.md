# Rebirth content 1.23.1

Requires launcher 1.3.0 or later. UI-only hotfix for all thirty original class
talent trees: retain Blizzard's registered scroll child and native descendant
hierarchy instead of inserting a wrapper. This addresses icons and prerequisite
arrows drawing below the talent viewport over the points bar, tabs and chat.
The wider frame, native icon sizes, fourth trees and native vertical scrolling
are preserved. No server, account, gameplay or client archive changes.

Regression: the native ownership assertion fails against the previous version.
6044 layout checks across all ten classes, 15771 fourth-tree checks, 680 completion
checks and installed-file validation pass. These automated mocks do not render
the actual game client; final visual acceptance remains necessary.

All 28 managed files are authored UI code or previously supplied artwork. No
Blizzard source, game archives, database data, credentials or private keys ship.

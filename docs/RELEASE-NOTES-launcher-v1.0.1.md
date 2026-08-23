# Project Rebirth Launcher 1.0.1 — public gateway pilot

This launcher points only to the signed Project Rebirth HTTPS update feed. It
expects a lawful, clean ChromieCraft 3.3.5a client. No player-side VPN client or
separate networking package is required.

Included:

- self-contained Windows x64 launcher;
- ECDSA P-256 signed update-manifest verification;
- SHA-256 and size verification for every managed add-on file;
- strict `ProjectRebirthTooltips` path allowlist;
- rollback-safe staging and repair;
- public Rebirth gateway status checks for `134.122.124.150:3724` and `:8087`;
- updated player guidance for the launcher-only connection flow.

The VPS gateway forwards only the two legacy game services to the privately bound
Rebirth host. Account admission remains explicitly whitelisted and fail-closed.

Not included: World of Warcraft, MPQs, game data, account credentials, server VPN
profiles, signing keys, or Authenticode publisher identity.


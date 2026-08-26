# Project Rebirth Launcher 1.0.0 — private tester build

This launcher points only to the signed Project Rebirth HTTPS update feed. It
expects a lawful, clean ChromieCraft 3.3.5a client and a separately provisioned
private-network connection.

Included:

- self-contained Windows x64 launcher;
- ECDSA P-256 signed update-manifest verification;
- SHA-256 and size verification for every managed add-on file;
- strict `ProjectRebirthTooltips` path allowlist;
- rollback-safe staging and repair;
- private Rebirth backend status checks for the authentication and world services.

Not included: World of Warcraft, MPQs, game data, account credentials, VPN
profiles, signing keys, or Authenticode publisher identity.

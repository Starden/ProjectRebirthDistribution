# Project Reverie Launcher 1.6.1 — Built-in updates

> **Correction published with 1.6.3:** later testing with the actual packaged WPF
> launcher found that this version's helper can fail before readiness. Do not rely
> on 1.6.1 to update itself. Close it and install the complete 1.6.3 ZIP into a
> fresh regular folder. Starting with 1.6.3, a dedicated updater is embedded.

Future launcher updates no longer send you to GitHub. Choose **Yes** at
**Update and restart?** and the launcher downloads, verifies, installs and reopens
the new version. Choose No to wait and use **Update to...** in the header later.

## One-time upgrade

From 1.6.0 or older, download `Project-Reverie-Launcher-1.6.1-win-x64.zip`, close
the old launcher, extract the complete ZIP into a fresh folder, and run
`ProjectReverie.Launcher.exe`. Old versions cannot self-install this feature.
Your client selection and preferences are retained.

Keep the launcher separate from WoW in a regular writable folder, not a linked
or cloud-managed folder. Keep the executable name unchanged. No VPN or separate
updater installation is needed. Existing content 1.28.0 and fourth-spec/Feral Cat
preparation are unchanged; this update changes no server or account permissions.

## Verification and recovery

- Independently signed HTTPS release metadata, signed archive size/SHA-256,
  restricted HTTPS redirects, exact four-file package and executable-version checks.
- A separate helper verifies everything again, waits for the old launcher to
  exit, backs up the previous files, replaces the executable last and restarts it.
- Failed replacement attempts roll back where safe; unrelated files, game data,
  saved settings and concurrent external edits are not overwritten.
- Backups remain in `.reverie-update-*` inside the launcher folder. Power loss
  may require manual recovery or extracting a fresh ZIP. Never bypass warnings.

Release validation: 48 updater checks, 29 release checks, 35 onboarding/native-data
safeguard checks, package checks, and an isolated real-helper process test through
public-executable restart. Interactive future-version prompt acceptance remains
a follow-up when the next release exists.

The earlier process fixture used a renamed console smoke executable and did not
exercise packaged WPF helper startup; the correction above supersedes its update
claim. Actual packaged testing later reproduced failure before readiness.

The launcher is not yet Authenticode-signed. A signed update feed is not a Windows
publisher certificate. This ZIP contains no WoW client or game archives.

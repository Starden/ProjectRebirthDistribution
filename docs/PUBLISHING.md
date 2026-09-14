# Publishing the one-tester release

## Launcher 1.6.3 two-phase rollout

Prepare and validate launcher 1.6.3 before changing the active launcher feed.
This is a launcher-only release: keep content 1.29.0, its signed manifest pair,
and all 34 owned payloads byte-for-byte unchanged.

Phase one commits the release notes, corrected publishing/audit automation, and a
`pendingRelease` pin containing the exact launcher/content versions plus archive
SHA-256 and size. The ZIP and sidecar remain ignored under `release-assets/`.
Keep the active settings and both signed feeds unchanged while this commit is
pushed and the exact archive is uploaded as a GitHub Release.

After anonymously downloading and verifying that archive, phase two promotes the
already-reviewed signed launcher pair, changes active `launcherVersion` to 1.6.3,
and removes `pendingRelease`. Only then update current-version wording in public
README/onboarding. Never advertise a required upgrade before its exact archive is
publicly available. Do not alter content or server state during either phase.

## Launcher release and self-update feed

Game content and launcher binaries have independent versions. A launcher-only
release must not regenerate or roll back the live content manifest/payload.
Build a new launcher version, validate its public ZIP, and stage the exact hash
and size under `pendingRelease`; do not change active `launcherVersion` yet.
Publish and anonymously verify the ZIP plus checksum through GitHub Releases.
Only then update active `launcherVersion` and remove the pending object in the
feed-promotion commit. Never commit generated launcher archives to Git.

Use the protected workstation's `Publish-ProjectReverieLauncherFeed.ps1` with
the ZIP, Version, MinimumSupportedVersion and a staging OutputDirectory. It signs
`launcher.json` and `launcher.json.sig` using the existing non-exportable key.
The archive must be publicly downloadable and its SHA-256 verified **before**
copying this pair into `site/stable/` and committing them together. Re-run
`Test-PublicDistribution.ps1`, publish Pages, and verify the remote signed pair.

The feed has a 30-day default lifetime. Renew its signature/timestamps before
expiry, even when no binary changes. Preserve both files during content-only
publications; the current workstation content publisher does this automatically.
An incomplete pair must block publication. Choose the minimum version deliberately:
it blocks obsolete launchers from installing content or playing, whereas a newer
optional release only prompts. Because the 1.6.1/1.6.2 WPF helper was found to
fail before readiness, every 1.6.2-or-older user requires one final manual
fresh-folder upgrade to 1.6.3. Starting with 1.6.3, the dedicated updater is
embedded in the four-file package; players install no updater sidecar.

The workstation's `Publish-ProjectReverieGitHubRelease.ps1` can publish using the
repository's existing Git Credential Manager login without installing GitHub CLI.
It creates an unpublished draft, validates uploaded archive/checksum hashes, and
then marks the release latest. A failed upload remains a draft for review; do not
overwrite published assets or reuse a version for different bytes.

## Trust boundaries

GitHub Pages serves the signed update feed over HTTPS. GitHub Releases serves the
launcher-only ZIP. Neither location may contain a game client or secret. The
ECDSA private key stays in the publisher workstation's non-exportable Windows
certificate store; GitHub receives only already-signed bytes and the public key.

The launcher ZIP is not Authenticode-signed yet. Its SHA-256 sidecar detects
corruption but does not independently prove publisher identity when downloaded
from the same compromised source. Tell the tester to expect Windows' unknown
publisher warning and transmit the expected ZIP hash through the existing private
channel.

## One-time GitHub setup

1. Confirm the public repository `Starden/ProjectRebirthDistribution` is empty or
   contains only reviewed distribution files.
2. Push the contents of this directory to the repository's `main` branch. The
   ignored `release-assets/` directory is normally excluded from Git.
3. In **Settings > Pages**, set the source to **GitHub Actions**.
4. In **Settings > Actions > General**, keep workflow permissions read-only by
   default. The Pages job has only `pages: write` and `id-token: write`.
5. Protect `main`: require the `validate` check, reject force pushes, and require
   review when a second maintainer becomes available.
6. Confirm the Pages environment is restricted to `main`.

The Pages workflow requests first-run enablement through `configure-pages`; the
repository owner may still need to approve the Pages environment in Settings.

## Legacy combined content preparation

`Prepare-PublicRelease.ps1` is retained for deliberate combined content/setup
work, not launcher-only publication. It can regenerate signed content and must
not be used for the 1.6.3 updater release. Pass explicit reviewed versions rather
than relying on its historical defaults.

```powershell
$distributionRoot = (Resolve-Path '.').Path
$launcherRoot = '<LOCAL-LAUNCHER-SOURCE>'
$projectRoot = '<LOCAL-REBIRTH-PROJECT>'
$certificateThumbprint = '<LOCAL-ECDSA-CERTIFICATE-THUMBPRINT>'

pwsh -NoProfile -File "$distributionRoot\tools\Prepare-PublicRelease.ps1" `
  -DistributionRoot $distributionRoot `
  -LauncherRoot $launcherRoot `
  -ProjectRoot $projectRoot `
  -CertificateThumbprint $certificateThumbprint `
  -ContentVersion '<REVIEWED-CONTENT-VERSION>' `
  -LauncherVersion '<REVIEWED-LAUNCHER-VERSION>'
```

The resulting signed endpoint is `134.122.124.150:3724` and the world status
port is `134.122.124.150:8087`. Relative payload URLs in the signed manifest resolve against
the absolute HTTPS manifest URL; they cannot escape the signed channel directory.

## Publish a launcher archive safely

1. Run the public validator locally. Any failure is a release blocker.
2. Commit and push phase one with the exact `pendingRelease` pin while the active
   launcher feed and current-version README text remain unchanged.
3. Place the ignored ZIP and sidecar under `release-assets/` on the protected
   workstation and invoke the canonical publisher from the private launcher
   tooling:

```powershell
pwsh -NoProfile -File '<PROTECTED-LAUNCHER-ROOT>\tools\Publish-ProjectReverieGitHubRelease.ps1' `
  -DistributionRoot (Resolve-Path '.').Path `
  -Version '<REVIEWED-LAUNCHER-VERSION>'
```

That publisher requires the pending pin and a clean reviewed commit, creates an
unpublished draft, validates the uploaded archive/checksum digests, then publishes
latest without overwriting an existing version. The similarly named public
`tools/Publish-LauncherRelease.ps1` is a fail-closed deprecated shim and must not
be used. No GitHub CLI is required by the canonical path.

4. Download the published asset anonymously and repeat the exact hash, size,
   inventory, PE version, bootstrap and signed-downloader checks.
5. Commit and push phase two: promote only the signed launcher feed pair, active
   launcher version and public current-version wording; remove `pendingRelease`.
   Wait for Pages and verify the live signed pair. Content remains byte-exact.

Generated ZIPs must stay outside Git history. The release-published audit workflow
validates the uploaded public package independently.

## Rollback and key incidents

Do not decrement `contentVersion`; the launcher rejects rollback. For a bad
payload, publish a corrected feed with a higher version and sign it locally. If
the private key is lost or suspected compromised, stop publishing and distribute
a new launcher with a newly pinned public key through the established channel.

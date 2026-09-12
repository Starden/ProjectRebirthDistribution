# Publishing the one-tester release

## Launcher self-update feed (1.4.0 and later)

Game content and launcher binaries have independent versions. A launcher-only
release must not regenerate or roll back the live content manifest/payload.
Build a new launcher version, validate its public ZIP, update launcherVersion in
distribution.settings.json, and publish the ZIP plus checksum to GitHub Releases.
Never commit generated launcher archives to Git.

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
optional release only prompts. Pre-1.4.0 launchers require a one-time manual update.

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

## Prepare a signed feed and remote launcher locally

Run this on the protected Windows publisher workstation. The command signs the
exact manifest bytes with the local certificate, builds a launcher whose bootstrap
uses absolute HTTPS URLs, and writes only below this distribution repository.

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
  -ContentVersion 1.5.1 `
  -LauncherVersion 1.2.1
```

The resulting signed endpoint is `134.122.124.150:3724` and the world status
port is `134.122.124.150:8087`. Relative payload URLs in the signed manifest resolve against
the absolute HTTPS manifest URL; they cannot escape the signed channel directory.

## Publish atomically

1. Run `tools/Test-PublicDistribution.ps1` locally. Any warning or failure is a
   release blocker.
2. Inspect `git status` and confirm that only `site/`, documentation, public
   configuration, and automation are candidates for commit. Ensure the launcher
   ZIP remains ignored.
3. Commit and push the signed payload files first if they are new.
4. Publish `site/stable/manifest.json.sig` and `site/stable/manifest.json` in the
   same reviewed commit. GitHub Pages deploys the complete `site/` artifact as one
   release; the deploy job validates before upload.
5. Wait for `https://starden.github.io/ProjectRebirthDistribution/stable/manifest.json`
   to return HTTP 200. Download the manifest and signature and validate the exact
   remote bytes again.
6. Upload the ignored 61 MB launcher archive and sidecar directly from the
   publisher workstation:

```powershell
pwsh -NoProfile -File ./tools/Publish-LauncherRelease.ps1 -Version 1.2.1
```

The script uses the authenticated GitHub CLI; it never uploads credentials or a
signing key. If `gh` is not installed/authenticated, install it and run `gh auth
login` before this step.

The obsolete tag-triggered publisher has been removed. Generated ZIPs must stay
outside Git history; upload them directly to Releases. The release-published
audit workflow still validates the uploaded public package independently.

## Rollback and key incidents

Do not decrement `contentVersion`; the launcher rejects rollback. For a bad
payload, publish a corrected feed with a higher version and sign it locally. If
the private key is lost or suspected compromised, stop publishing and distribute
a new launcher with a newly pinned public key through the established channel.

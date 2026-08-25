# Publishing the one-tester release

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
$distributionRoot = 'C:\Users\PC\OneDrive\Desktop\Project Skillful\.rebirth-remote-stage\public-feed'
$launcherRoot = 'D:\Project Rebirth\launcher'
$projectRoot = 'D:\Project Rebirth'
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

For the first test release, the `publish-launcher-release` workflow also supports
a deliberately short-lived asset commit. Force-add only the ZIP and sidecar,
push them with a `launcher-v1.2.1` tag, wait for the workflow to publish the
release, then delete `release-assets/` in the next commit. This removes the files
from the branch tip but **not** from Git history; direct `gh release create` is
preferred for later releases.

```powershell
git add -f release-assets/Project-Reverie-Launcher-1.2.1-win-x64.zip
git add -f release-assets/Project-Reverie-Launcher-1.2.1-win-x64.zip.sha256
git commit -m "Stage Project Reverie launcher 1.2.1 release assets"
git tag launcher-v1.2.1
git push origin main launcher-v1.2.1
```

## Rollback and key incidents

Do not decrement `contentVersion`; the launcher rejects rollback. For a bad
payload, publish a corrected feed with a higher version and sign it locally. If
the private key is lost or suspected compromised, stop publishing and distribute
a new launcher with a newly pinned public key through the established channel.

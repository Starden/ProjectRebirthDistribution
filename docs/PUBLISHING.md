# Publishing the one-tester release

## Launcher 2.0.0 / content 0.1.30

This presentation-only release follows the same two-phase protocol: pin the
2.0.0 ZIP and content epoch 1 in pendingRelease while keeping active feeds
unchanged; publish and anonymously verify the archive; then promote both exact
signed feed pairs and active distribution settings together. Content 0.1.30
requires launcher 2.0.0; the independent launcher feed retains minimum 1.6.3
so existing working updaters can upgrade. Never disable rollback validation.

Content ordering is (contentEpoch, contentVersion). Missing epoch means legacy 0.
The first new generation is epoch 1 / 0.1.30; only epochs 0 and 1 are currently
supported. Within an epoch, versions must increase. Reject unknown generations,
legacy-generation rollback, and same-generation version rollback. New-generation
content metadata requires minimumLauncherVersion at least 2.0.0.

All 35 payloads remain identical to 1.30.0; native recipes, gameplay, account access,
and server processes are unchanged. Retain the physical QoL cache revision marker
1.30.0 so completed preparation is not invalidated by the display renumbering.

## Historical: Launcher 1.6.4 / content 1.30.0 coordinated rollout

This release changes both launcher and content and must be coordinated with the
reviewed Rebirth QoL server/SQL deployment. Preparing or installing the launcher
alone is not evidence that server deployment succeeded. Keep existing account
permissions and all other realms unchanged.

Phase one commits the release notes, corrected publishing/audit automation, and a
`pendingRelease` pin containing the exact launcher/content versions plus archive
SHA-256 and size. The ZIP and sidecar remain ignored under `release-assets/`.
Keep the active settings and both signed feeds unchanged while this commit is
pushed and the exact archive is uploaded as a GitHub Release.

After anonymously verifying the public 1.6.4 archive, prepare phase two locally:
the exact signed content 1.30.0 pair, 35 owned payloads, signed launcher pair,
active settings and current player guidance. Seven payloads are new/changed and
28 are byte-identical to content 1.29.0; native recipes, generated tooltip data
and Wardrobe payloads remain unchanged. Remove `pendingRelease` in this prepared
activation change. Do not commit/push this change until the operator confirms
the coordinated server/SQL deployment and runtime checks passed.

Then commit both feed pairs, their matching content and active documentation as
one reviewed activation change. Wait for Pages and verify both live signatures,
versions and all payload hashes. Never advertise a required upgrade before the
exact archive is public, and never complete the new item-cache revision against
the old content 1.29.0 feed. The launcher-release minimum remains 1.6.3 so it can
perform its built-in update; content 1.30.0 itself requires launcher 1.6.4.

Finally update the operator's launcher and complete **Prepare Client** with WoW
closed. The new cache-only operation backs up just enUS `itemcache.wdb` when
native data already match; it never clears the whole cache or rebuilds matching
archives. Preserve pending/backup files if interrupted. The operator's no-sync
direct-play helper requires the completed root-bound cache revision too.

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
fresh-folder upgrade to the current 1.6.4. Starting with 1.6.3, the dedicated updater is
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
not be used to regenerate the already-reviewed 1.30.0 signed candidate. Pass explicit reviewed versions rather
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
5. For a launcher-only release, promote only its signed feed pair, active version
   and public wording; remove `pendingRelease` and preserve content byte-for-byte.
   For this coordinated 1.6.4 / 1.30.0 release, follow the server-gated activation
   procedure above instead. Wait for Pages and verify the live signed feeds.

Generated ZIPs must stay outside Git history. The release-published audit workflow
validates the uploaded public package independently.

## Rollback and key incidents

Do not decrement `contentVersion`; the launcher rejects rollback. For a bad
payload, publish a corrected feed with a higher version and sign it locally. If
the private key is lost or suspected compromised, stop publishing and distribute
a new launcher with a newly pinned public key through the established channel.

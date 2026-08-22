# Project Rebirth Distribution

This repository is the public distribution edge for a small, controlled Project
Rebirth test. It contains only:

- the HTTPS update site under `site/`;
- a detached ECDSA P-256 signature for the exact update manifest bytes;
- Project Rebirth-owned add-on payload files;
- public verification and release automation;
- publisher and tester documentation.

The launcher archive is uploaded directly to GitHub Releases and is deliberately
ignored by Git. The repository never contains a World of Warcraft client,
`Wow.exe`, MPQ archives, extracted Blizzard data, game credentials, WireGuard
private keys, or publisher private-key material.

## Public endpoints

- Update manifest: `https://starden.github.io/ProjectRebirthDistribution/stable/manifest.json`
- Detached signature: `https://starden.github.io/ProjectRebirthDistribution/stable/manifest.json.sig`
- Launcher releases: `https://github.com/Starden/ProjectRebirthDistribution/releases`

The signed realm endpoint is the private WireGuard service address
`10.50.0.2:3724`; world service status uses `10.50.0.2:8087`. Publishing this
repository does **not** make those private services reachable. Each tester still
needs a separately delivered, unique VPN profile and an approved game account.

## Validate locally

```powershell
pwsh -NoProfile -File ./tools/Test-PublicDistribution.ps1
```

See [publishing](docs/PUBLISHING.md), [go-live checks](docs/GO-LIVE-CHECKLIST.md),
and [tester onboarding](docs/TESTER-ONBOARDING.md) before publishing anything.

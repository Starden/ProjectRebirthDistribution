# One-tester go-live checklist

The signed HTTPS distribution is only one layer. Do not send the tester package
until every required box below is independently proven.

## Public distribution

- [x] Public `Starden/ProjectRebirthDistribution` repository exists.
- [ ] GitHub Pages is configured to deploy from GitHub Actions.
- [ ] `validate` and `deploy-pages` workflows succeed on `main`.
- [ ] The live manifest and detached signature return HTTP 200 over HTTPS.
- [ ] The downloaded live manifest verifies against `site/update-signing-public-key.pem`.
- [ ] Every live payload size and SHA-256 matches the signed manifest.
- [ ] The launcher ZIP and `.sha256` sidecar are attached to `launcher-v1.0.0`.
- [ ] The ZIP hash is sent to the tester over a separate trusted private channel.
- [ ] No game client, MPQ, Data tree, password, VPN profile, or private key is public.

## Private network and server

- [ ] The VPS WireGuard hub is deployed with a stable public IPv4/hostname.
- [ ] The Rebirth host has VPN address `10.50.0.2/32` and the tester has a unique `/32`.
- [ ] Tester-to-host source address is preserved; there is no peer-to-peer NAT.
- [ ] Only TCP 3724 and 8087 are reachable by the tester through the VPN.
- [ ] MySQL 3306/33060, PlayerBots command service 8888, RDP, SMB, WinRM, SSH, and
      admin consoles are unreachable from the tester peer.
- [ ] No router port forward exposes home game, database, or administrative ports.
- [ ] Rebirth auth/world advertise and bind the intended VPN route.
- [ ] Skillful Beta and Skillful Dev remain unchanged and pass their local checks.

## Identity and revocation

- [ ] A unique tester WireGuard key is generated; no owner/shared profile is reused.
- [ ] The tester account is unique, least-privileged, and contains no GM access.
- [ ] Rebirth's account allowlist is enabled fail-closed and includes only the tester.
- [ ] A valid VPN identity plus password is insufficient without allowlist approval.
- [ ] VPN-peer removal and account-whitelist revocation are each tested separately.
- [ ] Account/VPN secrets are delivered separately from the public launcher URL.

## External proof

- [ ] From a non-home residential connection, VPN connects to the VPS.
- [ ] `10.50.0.2:3724` and `10.50.0.2:8087` are reachable after VPN connection.
- [ ] The home residential IP is absent from launcher files, DNS, docs, and logs
      given to the tester.
- [ ] The tester can locate a clean build-12340 client, update, log in, enter Rebirth,
      log out, reconnect, and preserve progression.
- [ ] Disconnecting the VPN immediately removes game reachability.

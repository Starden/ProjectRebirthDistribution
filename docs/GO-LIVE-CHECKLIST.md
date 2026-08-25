# One-tester public-gateway go-live checklist

The signed HTTPS distribution is only one layer. Do not send an account credential
until every required boundary below is proven.

## Public distribution

- [x] Public `Starden/ProjectRebirthDistribution` repository exists.
- [x] GitHub Pages serves the exact signed stable feed over HTTPS.
- [ ] Launcher 1.2.1 ZIP and checksum are published through GitHub Releases.
- [x] Signed content 1.5.1 advertises only `134.122.124.150:3724/8087`.
- [x] Live manifest, signature, and every payload hash verify after deployment.
- [x] Project Reverie Launcher 1.2.1 contains no client, MPQ, credential, VPN profile, or key and uses only the HTTPS public feed bootstrap.
- [ ] The ZIP hash is sent through a separate trusted private channel.

## VPS gateway and private transport

- [ ] DigitalOcean permits inbound IPv4 TCP 3724 and 8087 only for this Droplet.
- [ ] Public SSH, IPv6 game ingress, MySQL, RDP, SMB, WinRM, and port 8888 remain
      closed.
- [ ] nftables remains default-deny and applies per-source new-connection limits.
- [ ] HAProxy owns only TCP 3724 and 8087 and both backends are healthy.
- [ ] HAProxy sends PROXY protocol v2 to `10.50.0.2` over WireGuard.
- [ ] The home residential address is absent from launcher files and public docs.
- [ ] The VPS-to-home WireGuard peer remains private and healthy.

## Rebirth host

- [ ] Auth and world remain bound only to `10.50.0.2`.
- [ ] Auth `EnableProxyProtocol` and world `Network.EnableProxyProtocol` are 1.
- [ ] Windows Firewall allows backend TCP only from `10.50.0.1`.
- [ ] MySQL remains loopback-only; MySQL X and PlayerBots 8888 remain absent.
- [ ] Skillful Beta and Development remain loopback-only and unchanged.
- [ ] Realm 1 advertises `134.122.124.150:8087` with local mask
      `255.255.255.255`.
- [ ] Rebirth account access remains enabled, enforcing, and fail-closed.

## Identity, logging, and revocation

- [ ] The tester account is unique, non-GM, and explicitly whitelisted.
- [ ] Wrong-password bans and logs use the original public client address conveyed
      by PROXY v2, not `10.50.0.1`.
- [ ] HAProxy logs connection metadata but never payloads or credentials.
- [ ] Account-whitelist revocation is tested independently.
- [ ] Only the operator and active tester appear enabled in the whitelist.

## External proof

- [ ] From a non-home network, public TCP 3724 and 8087 connect without WireGuard.
- [ ] Public 22, 3306, 33060, 8085, 8086, and 8888 remain unreachable.
- [ ] A clean client can authenticate, enter Rebirth, move, chat, log out, reconnect,
      and preserve progression.
- [ ] The launcher alone applies the correct signed realm address.

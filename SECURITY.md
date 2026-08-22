# Security

Report update-signature failures, unexpected files, credential exposure, or
network-policy failures to the Project Rebirth owner through the established
private channel. Do not post VPN profiles, private keys, account names, passwords,
home addresses, residential IP addresses, or unredacted logs in a public issue.

The public ECDSA verification key is not secret. The matching private key remains
non-exportable in the publisher workstation's Windows certificate store and must
never be added to this repository, a GitHub secret, a release archive, or a tester
package.

This distribution is lightweight update-chain protection. It is not a kernel
anti-cheat system and does not replace server-side authorization, firewalling,
unique WireGuard identities, or account revocation.


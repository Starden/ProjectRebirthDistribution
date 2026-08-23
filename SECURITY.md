# Security

Report update-signature failures, unexpected files, credential exposure, or
network-policy failures to the Project Rebirth owner through the established
private channel. Do not post server VPN profiles, private keys, account names, passwords,
home addresses, residential IP addresses, or unredacted logs in a public issue.

The public ECDSA verification key is not secret. The matching private key remains
non-exportable in the publisher workstation's Windows certificate store and must
never be added to this repository, a GitHub secret, a release archive, or a tester
package.

This distribution is lightweight update-chain protection. It is not a kernel
anti-cheat system and does not replace server-side authorization, VPS and host
firewalling, connection-rate controls, PROXY-protocol validation, or account
revocation. The player-facing gateway exposes only the two legacy game TCP ports;
administration and database services remain private.

# Project Rebirth private-test onboarding

## What you receive

You will receive three things through separate channels:

1. the public Project Rebirth launcher download URL;
2. one WireGuard profile created only for you;
3. one non-GM Project Rebirth account credential.

Never share your VPN profile or account password. Report a lost device immediately
so both identities can be revoked.

## Requirements

- Windows 10 or 11 x64;
- your own lawful, clean ChromieCraft WoW 3.3.5a client (build 12340);
- the official WireGuard client for Windows;
- enough permission to update the selected game folder.

The Project Rebirth launcher does not include or download World of Warcraft.

## First connection

1. Download the launcher ZIP from the announced GitHub Release.
2. Compare its SHA-256 with the value the owner sent through the private channel.
3. Extract the ZIP to its own folder. Windows may show an unknown-publisher warning
   because the test launcher is not Authenticode-signed yet.
4. Import only your assigned WireGuard profile and activate it.
5. Optionally confirm the private services from PowerShell:

```powershell
Test-NetConnection 10.50.0.2 -Port 3724
Test-NetConnection 10.50.0.2 -Port 8087
```

6. Start `ProjectRebirth.Launcher.exe`, select **Locate Client**, and choose the
   folder containing your clean `Wow.exe`.
7. Select **Update**, then **Play**, and log in with your Rebirth test account.

## Safety and troubleshooting

- Keep the VPN connected while launching and playing.
- Do not bypass a manifest signature, expiry, rollback, or file-hash warning.
- Do not send screenshots containing your VPN configuration or account password.
- If the update feed is online but both private ports are unavailable, verify the
  VPN is active and contact the owner; do not change the realm address manually.
- The launcher manages only Project Rebirth-owned add-on files. It does not repair
  base client files or make another WoW version compatible.


# MAAD for Vectra (MAAD-VF)
![MAAD_Logo](images/MAAD_AF.png)

MAAD for Vectra is a PowerShell-based Microsoft 365 and Entra attack emulation tool intended to execute realistic tenant actions which can be validated independently in Microsoft Entra and M365 portals, and in other detections such as Defender or SIEM. MAAD is optimised for interactive operator workflows instead of custom scripting and useful for demonstrating identity attack paths which Vectra can detect and help investigate.

This repository is a separately maintained derivative of [vectra-ai-research/MAAD-AF](https://github.com/vectra-ai-research/MAAD-AF) and now relies on Microsoft Entra and Graph PowerShell modules rather than the retired AzureAD and MSOnline PowerShell modules.

## Requirements

- Windows host with PowerShell 5.1
- Administrator rights and PowerShell Gallery access for dependency installation
- Microsoft 365 / Entra test or approved customer tenant

## Quick Start

Clone the repository, open an elevated Windows PowerShell 5.1 session, and launch the tool:

```powershell
git clone https://github.com/dancrossley/MAAD-AF.git
cd .\MAAD-AF
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\MAAD_Attack.ps1
```

On first launch, MAAD-VF checks for and installs the required Entra, Graph, Exchange, Teams, SharePoint, and compliance modules.

## Environment Hygiene

Ideally start with a clean Windows VM snapshot. If that is not possible, clean the PowerShell environment before each operator run:

1. Close all Windows Terminal and PowerShell windows that were previously used for MAAD.
2. Open one fresh elevated Windows PowerShell 5.1 session.
3. Confirm no old modules are already loaded:

```powershell
Get-Module Microsoft.Graph*,Microsoft.Entra*,Az*,ExchangeOnlineManagement,MicrosoftTeams,PnP.PowerShell
```

4. If you suspect old Graph versions persist, list installed versions and remove the older copies before launching MAAD-VF:

```powershell
Get-InstalledModule Microsoft.Graph.Authentication -AllVersions | Sort Version
Get-InstalledModule Microsoft.Graph.Users -AllVersions | Sort Version
Get-InstalledModule Microsoft.Graph.Groups -AllVersions | Sort Version
Get-InstalledModule Microsoft.Graph.Applications -AllVersions | Sort Version
Get-InstalledModule Microsoft.Graph.Identity.SignIns -AllVersions | Sort Version
```

5. Relaunch MAAD-VF from that same fresh session.

If the environment has been heavily used for previous auth or module troubleshooting, a reboot is often faster and safer than trying to clean up partially loaded assemblies in-place.

## Example Operator Sequence

The sequence below is a simple example of how an operator can run a real-world attack chain using MAAD. Use only approved test users, groups, policies, and mailboxes, and complete cleanup afterwards.

1. `Access > Establish Access - Entra`
2. `Account > Deploy Backdoor Account`
3. `Account > Assign Entra Role to Account`
4. `Entra > Modify Trusted IP Config`
5. `Access > Establish Access - Exchange Online`
6. `Exchange > Disable Mailbox Auditing`
7. `Exchange > Disable Anti-Phishing Policy`
8. `Account > Reset Password`
9. `Access > Establish Access - Compliance (eDiscovery)`
10. `Compliance > Launch New eDiscovery Search`
11. `Account > Disable Account MFA`

## Testing & Safety Notes

- repo-local wiki pages start at [Home.md](./wiki/Home.md)
- automated and manual test documentation lives in [Tests/README.md](./Tests/README.md)
- use only in lab, test, or explicitly approved customer environments
- some workflows change tenant state and can affect access, policies, mailbox behaviour, or compliance data
- many actions require manual verification and cleanup
- always record the objects you changed during a run

The current repository includes the upstream GPL v3 license in [LICENSE.md](./LICENSE.md)

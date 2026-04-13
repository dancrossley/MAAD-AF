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

On first launch, MAAD-VF checks for and installs the required Entra, Graph, Exchange, Teams, SharePoint, and compliance modules. See the [MAAD-AF wiki](https://github.com/dancrossley/MAAD-AF/wiki) for more details on getting started.

## Example Operator Sequence

The sequence below is a simple example of how an operator can run a real-world attack chain using MAAD. Use only approved test users, groups, policies, and mailboxes, and complete cleanup afterwards.

- `2. Access > 5. Establish Access - Entra`
- `4. Account > 2. Deploy Backdoor Account`
- `4. Account > 3. Assign Entra Role to Account`
- `7. Entra > 1. Modify Trusted IP Config`
- `2. Access > 7. Establish Access - Exchange Online`
- `8. Exchange > 5. Disable Mailbox Auditing`
- `8. Exchange > 6. Disable Anti-Phishing Policy`
- `4. Account > 5. Reset Password`
- `2. Access > 11. Establish Access - Compliance (eDiscovery)`
- `11. Compliance > 1. Launch New eDiscovery Search`
- `4. Account > 7. Disable Account MFA`

The current repository includes the upstream GPL v3 license in [LICENSE.md](./LICENSE.md)

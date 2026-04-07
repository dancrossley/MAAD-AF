# MAAD Attack Framework
![MAAD_Logo](images/MAAD_AF.png)                                                                     
        
MAAD-AF is an open-source cloud attack tool for Microsoft 365 & Entra ID(Azure AD) environments.

MAAD-AF offers simple, fast and effective security testing. Validate Microsoft cloud controls and test detection & response capabilities with a virutally zero-setup process, complete with a fully interactive workflow for executing emulated attacks. 

MAAD-AF is developed natively in PowerShell.

## Usage
1. Clone or download MAAD-AF from GitHub
2. Start PowerShell as Admin and navigate to MAAD-AF directory
```
> git clone https://github.com/vectra-ai-research/MAAD-AF.git
> cd /MAAD-AF
```
3. Launch MAAD-AF
```
> MAAD_Attack.ps1 
# Launch and bypass dependency checks
> MAAD_Attack.ps1 -ForceBypassDependencyCheck
```

## Requirements
 1. Windows host
 2. Windows PowerShell 5.1
 3. PowerShell Gallery access and administrator rights to install required modules
 4. Microsoft Entra PowerShell for Entra ID operations. MAAD-AF now relies on `Microsoft.Entra`, `Microsoft.Entra.Applications`, `Microsoft.Entra.Groups`, `Microsoft.Entra.SignIns`, and `Microsoft.Entra.Beta.SignIns`
 5. Compatible Microsoft Graph PowerShell modules for Entra-backed cmdlets

## Installation Notes
- MAAD-AF now uses Microsoft Entra PowerShell instead of the retired AzureAD and MSOnline modules.
- On first launch, MAAD-AF will check for and install the required Entra, Graph, and service-specific PowerShell modules.
- Windows PowerShell 5.1 is still supported. MAAD-AF raises PowerShell session limits automatically to accommodate larger Entra and Graph modules.
- If you already have older Microsoft Graph PowerShell modules installed side-by-side, MAAD-AF can load an incompatible mix of Graph and Entra dependencies. This may cause import failures, missing-type errors, or method-not-found errors when Entra-backed commands run. Before first use, it can help to check for multiple installed versions of key Graph modules such as `Microsoft.Graph.Authentication`, `Microsoft.Graph.Users`, `Microsoft.Graph.Groups`, `Microsoft.Graph.Applications`, and `Microsoft.Graph.Identity.SignIns`, then remove any stale copies from an elevated Windows PowerShell 5.1 session. If PowerShell reports that a module is in use, close all PowerShell or Windows Terminal sessions and retry from a fresh elevated window before launching MAAD-AF.

## Authentication Notes
- Entra access uses interactive or device-code authentication by default.
- Stored access tokens must target Microsoft Graph. When adding a token credential, include a Microsoft Graph audience such as `https://graph.microsoft.com`.
- Username/password credentials can still be used for services that support them, but Entra access no longer relies on delegated username/password authentication.
- Saved password credentials can still be selected in the UI for convenience, but Entra access will continue with interactive or device-code sign-in instead of delegated password auth.

## Features
- Attack emulation tool
- Fully interactive (no-commands) workflow
- Zero-setup deployment
- Ability to revert actions for post-testing cleanup
- Leverage MITRE ATT&CK
- Emulate post-compromise attack techniques
- Attack techniques for Entra ID (Azure AD)
- Attack techniques for Exchange Online
- Attack techniques for Teams
- Attack techniques for SharePoint
- Attack techniques for eDiscovery

## MAAD-AF Techniques
- Recon data from various Microsoft services
- Backdoor Account Setup
- Trusted Network Modification
- Mailbox Audit Bypass
- Disable Anti-Phishing in Exchange
- Mailbox Deletion Rule Setup
- Exfiltration through Mail Forwarding
- Gain User Mailbox Access
- Setup External Teams Access
- Exploit Cross Tenant Synchronization 
- eDiscovery exploitation for data recon & exfil
- Bruteforce credentials
- MFA Manipulation
- User Account Deletion
- SharePoint exploitation for data recon & exfil
- [More...](https://openrec0n.github.io/maad-af-docs/)

## Contribute
 - Thanks for considering contributing to MAAD-AF! Your contributions will help make MAAD-AF better.
 - Submit your PR to the main branch.
 - Submit bugs & issues directly to [GitHub Issues](https://github.com/vectra-ai-research/MAAD-AF/issues)
 - Share ideas in [GitHub Discussions](https://github.com/vectra-ai-research/MAAD-AF/discussions)

## Contact
If you found MAAD-AF useful, want to share an interesting use-case or idea - reach out & share them
 - Maintainer : [Arpan Sarkar](https://www.linkedin.com/in/arpan-sarkar/)
 - Email : [MAAD-AF@vectra.ai](mailto:maad-af@vectra.ai)

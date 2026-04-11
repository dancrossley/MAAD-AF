# Feature to Session Matrix

This page maps MAAD-AF menu options to the access session they require before use.

## Legend

- `None`: no prior authenticated service session is required
- `Entra`: `Establish Access - Entra`
- `Az`: `Establish Access - Az`
- `Exchange`: `Establish Access - Exchange Online`
- `Teams`: `Establish Access - Teams`
- `SharePoint Admin`: `Establish Access - Sharepoint Admin Center`
- `SharePoint Site`: `Establish Access - Sharepoint Site`
- `Compliance`: `Establish Access - Compliance (eDiscovery)`
- `Mixed`: more than one service is involved
- `Internal`: the feature prompts and connects on its own instead of relying entirely on a pre-opened session

## Pre-Attack

| Menu option | Required session | Notes |
|---|---|---|
| Find Tenant ID of Organization | None | External recon only |
| Find DNS Info | None | External recon only |
| Recon User Login Info | None | External recon only |
| Check Account Validity in Target Tenant | None | External recon only |
| Enumerate Usernames to Find Valid Users in Tenant | None | External recon only |
| Brute-Force Credentials | None | Uses external authentication attempts, not a pre-opened admin session |

## Access

| Menu option | Required session | Notes |
|---|---|---|
| Show Available Credentials | None | Credential store only |
| Add Credentials | None | Credential store only |
| Get Access Info | None | Reports currently open sessions |
| Establish Access - All | None | Opens multiple sessions |
| Establish Access - Entra | None | Opens Entra session |
| Establish Access - Az | None | Opens Az session |
| Establish Access - Exchange Online | None | Opens Exchange session |
| Establish Access - Teams | None | Opens Teams session |
| Establish Access - Sharepoint Site | None | Opens SharePoint site session |
| Establish Access - Sharepoint Admin Center | None | Opens SharePoint admin session |
| Establish Access - Compliance (eDiscovery) | None | Opens compliance search session |
| Kill All Access | None | Closes sessions |
| Anonymize Access with TOR | None | Local proxy behavior |

## Recon

| Menu option | Required session | Notes |
|---|---|---|
| Entra : Find All Accounts | Entra | Uses `Get-EntraUser` |
| Entra : Find All Groups | Entra | Uses `Get-EntraGroup` |
| Entra : Find All Service Principals | Entra | Uses `Get-EntraServicePrincipal` |
| Entra : Find All Auth Policy | Entra | Uses Entra authorization policy cmdlets |
| Entra : Recon Named Locations | Entra | Uses Entra named location policy cmdlets |
| Entra : Recon Conditional Access Policy | Entra | Uses conditional access policy cmdlets |
| Entra : Recon Registered Devices for Account | Entra | Uses `Get-EntraUserRegisteredDevice` |
| Entra : Recon All Accessible Tenants | Az | Uses `Get-AzTenant` |
| Teams : Recon All Teams | Teams | Uses `Get-Team` |
| SP : Recon All Sharepoint Sites | SharePoint Admin | Uses `Get-SPOSite` |
| Exchange : Find All Mailboxes | Exchange | Uses `Get-Mailbox` |
| Entra : Recon All Directory Roles | Entra | Uses Entra directory role cmdlets |
| Entra : Recon Directory Role Members | Entra | Uses Entra directory role member cmdlets |
| Entra : Recon Directory Roles Assigned To User | Entra | Uses `Get-EntraUserRole` |
| Exchange : Recon All Role Groups | Exchange | Uses `Get-RoleGroup` |
| Exchange : Recon Role Group Members | Exchange | Uses `Get-RoleGroupMember` |
| Exchange : Recon All Management Roles | Exchange | Uses `Get-ManagementRole` |
| Exchange : Recon All eDiscovery Admins in Tenant | Compliance | Uses `Get-eDiscoveryCaseAdmin` |

## Account

| Menu option | Required session | Notes |
|---|---|---|
| List Accounts in Tenant | Entra | Reuses Entra recon |
| Deploy Backdoor Account | Entra | Creates user via Entra |
| Assign Entra Role to Account | Entra | Uses Entra user and governance cmdlets |
| Assign Management Role Account | Exchange | Uses Exchange role group cmdlets |
| Reset Password | Entra | Uses Entra password profile cmdlet |
| Brute-Force Credentials | Entra | Current code uses Entra account selector before brute force |
| Disable Account MFA | Entra | Uses Entra account lookup plus Entra beta sign-ins cmdlets |
| Delete User | Entra | Uses `Remove-EntraUser` |

## Group

| Menu option | Required session | Notes |
|---|---|---|
| List Groups in Tenant | Entra | Reuses Entra recon |
| Create Group | Entra | Group creation path belongs to Entra |
| Add user to Group | Entra | Uses account and group lookup plus group membership cmdlets |
| Assign Role to Group | Entra | Uses group lookup plus Entra governance |

## Application

| Menu option | Required session | Notes |
|---|---|---|
| List Applications in Tenant | Entra | Reuses service principal/application recon |
| Create Application | Entra | Uses Entra application cmdlets |
| Generate New Application Credentials | Entra | Uses Entra application credential cmdlets |

## Entra

| Menu option | Required session | Notes |
|---|---|---|
| Modify Trusted IP Config | Entra | Uses named location policy cmdlets |
| Download All Account List | Entra | Reuses Entra user recon |
| Exploit Cross Tenant Sync | Mixed | Uses Az tenant context and opens its own Microsoft Graph session |

## Exchange

| Menu option | Required session | Notes |
|---|---|---|
| List Mailboxes in Tenant | Exchange | Uses mailbox recon |
| Gain Access to Another Mailbox | Exchange | Uses mailbox permission cmdlets |
| Setup Email Forwarding | Exchange | Uses mailbox forwarding cmdlets |
| Setup Email Deletion Rule | Exchange | Uses mailbox rule cmdlets |
| Disable Mailbox Auditing | Exchange | Uses mailbox audit bypass cmdlets |
| Disable Anti-Phishing Policy | Exchange | Uses anti-phish rule cmdlets |

## Teams

| Menu option | Required session | Notes |
|---|---|---|
| List Teams in Tenant | Teams | Uses `Get-Team` |
| Invite External User to Teams | Mixed | Teams operation plus Entra invitation capability |

## SharePoint

| Menu option | Required session | Notes |
|---|---|---|
| List Sharepoint Sites | SharePoint Admin | Uses `Get-SPOSite` |
| Gain Access to Sharepoint Site | Mixed | Uses SharePoint admin cmdlets plus Entra account lookup |
| Search Files in Sharepoint | Internal / SharePoint Site | Prompts for credentials and connects directly to target site |
| Exfiltrate Data from Sharepoint | Internal / SharePoint Site | Prompts for credentials and connects directly to target site |

## Compliance

| Menu option | Required session | Notes |
|---|---|---|
| Launch New eDiscovery Search | Compliance | Uses `Get/New/Start-Compliance*` |
| Recon Existing eDiscovery Cases | Compliance | Uses `Get-ComplianceCase` |
| Recon Existing eDiscovery Searches | Compliance | Uses `Get-ComplianceSearch` |
| Find eDiscovery Search Details | Compliance | Uses compliance search and action cmdlets |
| Find eDiscovery Case Members | Compliance | Uses case membership cmdlets |
| Exfil Data with eDiscovery | Compliance | Uses compliance export/search action cmdlets |
| Escalate eDiscovery Privileges | Mixed | Uses Compliance plus Exchange role group cmdlets and account lookup |
| Delete compliance case | Compliance | Uses `Remove-ComplianceCase` |
| Install Unified Export Tool | None | Local installer only |

## MAAD-AF

| Menu option | Required session | Notes |
|---|---|---|
| Set MAAD-AF TOR Configuration | None | Local config only |
| Set Dependency Check Default Setting | None | Local config only |
| Reset & Disable Local Host Proxy Settings | None | Local host only |
| Launch New MAAD-AF Session | None | Local process launch |

## Quick Operator Rules

- If the action is about users, groups, apps, roles, MFA, or named locations, open `Entra`.
- If the action is about Azure tenant visibility or cross-tenant access setup, open `Az`.
- If the action is about mailboxes or Exchange policies, open `Exchange Online`.
- If the action is about teams, open `Teams`.
- If the action is about listing sites or granting site admin access, open `Sharepoint Admin Center`.
- If the action is about searching or exfiltrating files from one site, the feature can connect internally to the target SharePoint site.
- If the action is about cases, searches, or exports in Purview, open `Compliance (eDiscovery)`.

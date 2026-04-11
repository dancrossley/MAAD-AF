# Authentication and Access

This page explains why MAAD-AF has many `Establish Access` options and how the current authentication model works.

## The Core Idea

MAAD-AF does not open one universal Microsoft 365 session.

Instead, it:

1. selects credentials, token, or interactive username
2. opens a service-specific PowerShell session
3. runs features that depend on that session

That orchestration starts in [Access_Modules.ps1](../Library/Access_Modules.ps1) and [MAAD_Credential_Store_Manager.ps1](../Library/MAAD_Credential_Store_Manager.ps1).

## Why There Are So Many Access Options

Microsoft 365 administration is fragmented across several PowerShell modules and endpoints. Even if the same user account is used everywhere, the admin sessions are different.

Examples:

- Entra directory actions use `Connect-Entra`
- Azure resource actions use `Connect-AzAccount`
- Exchange uses `Connect-ExchangeOnline`
- Teams uses `Connect-MicrosoftTeams`
- SharePoint site access uses `Connect-PnPOnline`
- SharePoint admin uses `Connect-SPOService`
- eDiscovery uses `Connect-IPPSSession`

Those sessions are not interchangeable.

## Two Layers in the Access Flow

### Credential Selection

Handled by `UseCredential()` in [MAAD_Credential_Store_Manager.ps1](../Library/MAAD_Credential_Store_Manager.ps1).

Supported inputs:

- saved password credential
- saved Microsoft Graph token
- manual username/password
- interactive-only username prompt for compliance/eDiscovery

### Session Establishment

Handled by `EstablishAccess()` in [Access_Modules.ps1](../Library/Access_Modules.ps1).

That function routes to one service connector:

- `AccessEntra`
- `AccessAzAccount`
- `AccessExchangeOnline`
- `AccessTeams`
- `AccessSharepoint`
- `AccessSharepointAdmin`
- `ConnectEdiscovery`

## Service Session Map

| Access menu option | What it opens | Main cmdlets / module | Typical features | Auth behavior today | Reusable |
|---|---|---|---|---|---|
| `Establish Access - Entra` | Entra directory session | `Connect-Entra`, `Get-Entra*` | identity, users, groups, apps, policies, roles | Graph token or interactive/device-code | Yes |
| `Establish Access - Az` | Azure tenant/resource session | `Connect-AzAccount`, `Get-Az*` | accessible tenants, Az tenant context, cross-tenant support | token, credential, or interactive fallback | Yes |
| `Establish Access - Exchange Online` | Exchange admin session | `Connect-ExchangeOnline`, mailbox and Exchange cmdlets | mailbox, anti-phish, role groups, Exchange recon | token, credential, or interactive fallback | Yes |
| `Establish Access - Teams` | Teams admin session | `Connect-MicrosoftTeams`, `Get-Team` | team recon and team membership actions | token, credential, or interactive fallback | Yes |
| `Establish Access - Sharepoint Site` | Site-level PnP session | `Connect-PnPOnline` | site access, search, exfil | token, credential, or interactive fallback | Reused for one target site |
| `Establish Access - Sharepoint Admin Center` | SharePoint admin session | `Connect-SPOService`, `Get-SPOSite` | tenant-wide SharePoint admin actions | credential or interactive fallback | Separate from site session |
| `Establish Access - Compliance (eDiscovery)` | Purview / compliance search session | `Connect-IPPSSession`, `Get/New/Start-Compliance*` | cases, searches, exports | interactive-first, then limited fallback | Separate from Exchange |
| `Establish Access - All` | Convenience wrapper | mixed | broad session setup | mixed | Opens several sessions at once |

## Current Auth Behavior by Service

### Entra

- accepts stored Microsoft Graph token if valid
- otherwise prefers interactive browser auth
- falls back to device code auth
- no longer relies on delegated password-based Entra sign-in

### Az / Exchange / Teams / SharePoint

- still attempt token or credential paths where supported
- often fall back to interactive auth when MFA or policy blocks password auth

### Compliance / eDiscovery

- now prefers interactive authentication
- uses `Connect-IPPSSession -EnableSearchOnlySession`
- password-first flows are not reliable enough to be the primary path

## Reusable vs Isolated Sessions

Reusable sessions:

- Entra
- Az
- Exchange Online
- Teams

More specialized sessions:

- SharePoint Site
- SharePoint Admin Center
- Compliance (eDiscovery)

This is why opening Entra access does not automatically make eDiscovery work, and why Exchange access does not automatically give you a compliance search session.

## Current Mixed Cases

Some features cross service boundaries:

- Cross-tenant sync uses Az plus Microsoft Graph
- eDiscovery privilege escalation uses Compliance plus Exchange role groups and account lookup
- Teams external invite uses Teams plus Entra invitation capability
- SharePoint access grant uses SharePoint admin plus Entra account lookup

## Practical Rule of Thumb

- Use `Entra` for directory, identity, and policy actions
- Use `Az` for Azure tenant/resource context
- Use `Exchange Online` for mailbox and Exchange admin work
- Use `Teams` for Teams operations
- Use `Sharepoint Site` for site content operations
- Use `Sharepoint Admin Center` for tenant-wide SharePoint admin tasks
- Use `Compliance (eDiscovery)` for Purview cases, searches, and exports

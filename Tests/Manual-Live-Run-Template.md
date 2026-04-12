# MAAD Manual Live Regression Run Template

Copy this file for each live regression run and save it under `TestReports/` or another agreed results location.

## Run Metadata

- Date:
- Operator:
- Branch:
- Commit:
- Host:
- OS:
- PowerShell Version:
- Tenant:
- Validation Scope:
- Source of Truth for Cleanup Notes:

## Status Legend

- `Pass`
- `Pass with Notes`
- `Fail`
- `Blocked`
- `Not Run`

## Pre-Run Checks

- Clean host or VM snapshot used:
- `.\Tests\Invoke-MAADValidation.ps1 -Mode Static,Smoke` result:
- MAAD launched successfully on clean session:
- Execution policy notes:
- Known environment deviations:

## Installed Module Baseline

- Microsoft.Entra:
- Microsoft.Entra.Users:
- Microsoft.Entra.SignIns:
- Microsoft.Entra.Beta.SignIns:
- Microsoft.Graph.Authentication:
- Microsoft.Graph.Users:
- Microsoft.Graph.Groups:
- Microsoft.Graph.Applications:
- Microsoft.Graph.Identity.SignIns:
- ExchangeOnlineManagement:
- MicrosoftTeams:
- PnP.PowerShell:
- Microsoft.Online.SharePoint.PowerShell:
- Az.Accounts:
- Az.Resources:

## Named Test Objects For This Run

- Disposable user:
- Disposable group:
- Trusted named location:
- Test mailbox:
- eDiscovery case:
- eDiscovery search:
- Test team:
- External invite target:
- Test application:

## Session Baseline

- Entra access:
- Exchange access:
- Compliance access:
- Teams access:
- SharePoint admin access:
- SharePoint site access:
- Az access:

## Results Summary

| Test ID | Status | Notes | Cleanup Status |
|---|---|---|---|
| MLR-001 |  |  |  |
| MLR-002 |  |  |  |
| MLR-003 |  |  |  |
| MLR-004 |  |  |  |
| MLR-005 |  |  |  |
| MLR-006 |  |  |  |
| MLR-007 |  |  |  |
| MLR-008 |  |  |  |
| MLR-009 |  |  |  |
| MLR-010 |  |  |  |
| MLR-011 |  |  |  |
| MLR-012 |  |  |  |
| MLR-013 |  |  |  |
| MLR-101 |  |  |  |
| MLR-102 |  |  |  |
| MLR-103 |  |  |  |
| MLR-104 |  |  |  |
| MLR-105 |  |  |  |
| MLR-106 |  |  |  |

## Failures and Blockers

### Failures

- 

### Blockers

- 

## Cleanup Verification

- All created users removed or retained intentionally:
- All temporary roles removed:
- All temporary group memberships removed:
- All temporary policies or named locations removed:
- All temporary searches and cases removed:
- All mailbox or MFA settings restored:

## Follow-Up Actions

- 

## Sign-Off

- Ready to share with additional users: `Yes / No`
- Notes:

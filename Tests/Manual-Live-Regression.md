# MAAD Manual Live Regression Suite

This document defines the manual live tenant regression tests to run before sharing MAAD-AF with other operators.

It is designed for:

- a controlled Microsoft 365 / Entra test tenant
- Windows PowerShell 5.1
- an operator with the roles needed to exercise the covered features
- repeatable regression runs after auth, dependency, or feature changes

## Best Practice

The best way to manage live regression testing for MAAD-AF is to keep:

1. one stable test catalog in source control
2. one per-run results file copied from a template
3. one clean Windows test host or VM snapshot for release validation

This file is the stable test catalog. Use [Manual-Live-Run-Template.md](./Manual-Live-Run-Template.md) to record the results of each run.

## Recommended Release Workflow

Run the manual live suite the same way each time:

1. Start from a clean Windows test host or VM snapshot.
2. Launch Windows PowerShell 5.1, record the installed module baseline, and run the automated `Static` and `Smoke` validation first.
3. Execute the `P0` manual live cases in order, then complete the targeted regression cases that match recent code changes.
4. Record every created user, group, policy, case, search, role assignment, and invited guest as you go so cleanup is easy to verify.
5. Treat any failed cleanup as a release blocker until the tenant is back in a known-good state.

## Status Values

Use these values consistently in the per-run results file:

- `Pass`: the workflow completed and the expected result was confirmed
- `Pass with Notes`: the workflow completed, but behavior differed slightly from the ideal result
- `Fail`: the workflow did not complete or produced the wrong result
- `Blocked`: the workflow could not be exercised because of environment, permissions, or tenant prerequisites
- `Not Run`: intentionally skipped in that pass

## Test Environment Guidance

- Use a dedicated live test tenant, not a production tenant.
- Use disposable users, groups, cases, and policy names where possible.
- Prefer a fresh Windows PowerShell 5.1 session at the start of each run.
- Record the branch, commit, host OS, and installed module versions before testing.
- Capture both MAAD console output and portal-side verification where possible.
- If a test mutates tenant state, either use the built-in undo flow or record the manual cleanup step immediately.

## Suggested Run Order

1. Core access/session tests
2. Entra core workflows
3. Exchange workflows
4. Compliance workflows
5. Targeted regression cases for recently changed or historically fragile paths

## Pre-Run Checklist

- Use a disposable or well-documented test identity for mutating actions.
- Confirm you know how to revert password resets, MFA changes, role assignments, and mailbox or policy changes before starting.
- Confirm the tenant has at least one suitable anti-phish rule, test mailbox, and eDiscovery case or a safe plan to create them.
- Reserve unique names for the test run:
  - disposable user UPN
  - disposable group name
  - disposable trusted named location name
  - disposable eDiscovery case and search names
- Decide where the completed run notes and screenshots or portal evidence will be stored.

## Exit Criteria

A regression run is considered healthy when:

- every `P0` case passes
- no `P1` case fails without a documented known issue
- all tenant-mutating cases have either successful cleanup or a documented cleanup action
- no access flow regresses on a clean Windows host

## Core Regression Cases

### MLR-001

- ID: `MLR-001`
- Priority: `P0`
- Menu Path: `Access > Establish Access - Entra`
- Required Session Before Start: `None`
- Objective: verify Entra interactive access still opens successfully on a clean host
- Preconditions:
  - operator account can sign in interactively to Entra
- Steps:
  1. Launch MAAD-AF.
  2. Open `Access`.
  3. Select `Establish Access - Entra`.
  4. Complete the interactive sign-in flow.
- Expected Result:
  - MAAD reports `Success -> Established access -> Entra`
  - `Access > Get Access Info` shows `Entra`
- Cleanup:
  - none

### MLR-002

- ID: `MLR-002`
- Priority: `P0`
- Menu Path: `Account > List Accounts in Tenant`
- Required Session Before Start: `Entra`
- Objective: verify Entra account recon still returns tenant users
- Steps:
  1. Open `Account`.
  2. Select `List Accounts in Tenant`.
- Expected Result:
  - user list is displayed or exported successfully
  - no module load or command-not-found errors occur
- Cleanup:
  - none

### MLR-003

- ID: `MLR-003`
- Priority: `P0`
- Menu Path: `Account > Deploy Backdoor Account`
- Required Session Before Start: `Entra`
- Objective: verify Entra user creation and optional undo
- Preconditions:
  - choose a unique test UPN
  - choose a password that meets tenant policy
- Steps:
  1. Open `Account`.
  2. Select `Deploy Backdoor Account`.
  3. Create a disposable test user.
  4. If creation succeeds, test the undo path.
- Expected Result:
  - user is created successfully
  - output is saved
  - credential is stored
  - undo deletes the created user successfully
- Cleanup:
  - confirm the created user no longer exists if undo was used
  - if undo was skipped, delete the user manually

### MLR-004

- ID: `MLR-004`
- Priority: `P0`
- Menu Path: `Account > Assign Entra Role to Account`
- Required Session Before Start: `Entra`
- Objective: verify role assignment flow resolves the user and role correctly
- Preconditions:
  - test user exists
  - choose a low-risk test role appropriate for the tenant
- Steps:
  1. Open `Account`.
  2. Select `Assign Entra Role to Account`.
  3. Choose the test account.
  4. Assign the chosen role.
- Expected Result:
  - MAAD reports `Role Assigned`
  - role assignment can be confirmed in Entra or via recon
- Cleanup:
  - remove the assigned role manually after verification

### MLR-005

- ID: `MLR-005`
- Priority: `P0`
- Menu Path: `Entra > Modify Trusted IP Config`
- Required Session Before Start: `Entra`
- Objective: verify named location creation and undo
- Preconditions:
  - operator has the required Conditional Access / policy permissions
  - choose a disposable policy name
- Steps:
  1. Open `Entra`.
  2. Select `Modify Trusted IP Config`.
  3. create a named location using either a manual IP or current public IP.
  4. if successful, run the undo path.
- Expected Result:
  - policy is created successfully
  - MAAD displays the created policy name, id, and CIDR
  - undo removes the policy successfully
- Cleanup:
  - confirm the named location no longer exists if undo was used
  - otherwise delete it manually

### MLR-006

- ID: `MLR-006`
- Priority: `P0`
- Menu Path: `Access > Establish Access - Exchange Online`
- Required Session Before Start: `None`
- Objective: verify Exchange Online access still opens successfully
- Steps:
  1. Open `Access`.
  2. Select `Establish Access - Exchange Online`.
  3. complete the supported auth flow.
- Expected Result:
  - MAAD reports Exchange access success
  - `Access > Get Access Info` shows `Exchange Online`
- Cleanup:
  - none

### MLR-007

- ID: `MLR-007`
- Priority: `P0`
- Menu Path: `Exchange > Disable Anti-Phishing Policy`
- Required Session Before Start: `Exchange`
- Objective: verify anti-phishing rule recon, disable, and undo
- Preconditions:
  - at least one anti-phish rule exists in the tenant
  - operator has Exchange permissions to manage anti-phish rules
- Steps:
  1. Open `Exchange`.
  2. Select `Disable Anti-Phishing Policy`.
  3. run the recon prompt.
  4. disable a disposable or agreed test rule.
  5. if successful, run the undo path.
- Expected Result:
  - rule list is retrieved
  - selected rule state changes as expected
  - undo re-enables the rule successfully
- Cleanup:
  - confirm the rule is restored to its original state

### MLR-008

- ID: `MLR-008`
- Priority: `P0`
- Menu Path: `Exchange > Disable Mailbox Auditing`
- Required Session Before Start: `Exchange`
- Objective: verify mailbox audit bypass change and undo
- Preconditions:
  - test mailbox exists
- Steps:
  1. Open `Exchange`.
  2. Select `Disable Mailbox Auditing`.
  3. choose a disposable test mailbox.
  4. confirm the disable action.
  5. if successful, run the undo path.
- Expected Result:
  - MAAD shows current and updated audit bypass state
  - undo restores the original state
- Cleanup:
  - confirm mailbox audit bypass is restored to its prior value

### MLR-009

- ID: `MLR-009`
- Priority: `P0`
- Menu Path: `Account > Reset Password`
- Required Session Before Start: `Entra`
- Objective: verify password reset and credential-store write
- Preconditions:
  - use a disposable test account
  - know the original password or have a plan to restore it
- Steps:
  1. Open `Account`.
  2. Select `Reset Password`.
  3. choose the target account.
  4. set a known test password.
- Expected Result:
  - MAAD reports password reset success
  - output is written to `Outputs`
  - a password credential is added to the local store
- Cleanup:
  - reset the account back to its intended baseline password

### MLR-010

- ID: `MLR-010`
- Priority: `P0`
- Menu Path: `Access > Establish Access - Compliance (eDiscovery)`
- Required Session Before Start: `None`
- Objective: verify compliance search session access on the clean host
- Preconditions:
  - operator has the required Purview / compliance permissions
  - ExchangeOnlineManagement version meets the documented requirement
- Steps:
  1. Open `Access`.
  2. Select `Establish Access - Compliance (eDiscovery)`.
  3. complete the interactive sign-in flow.
- Expected Result:
  - MAAD reports compliance access success
  - later compliance search commands are available in the same session
- Cleanup:
  - none

### MLR-011

- ID: `MLR-011`
- Priority: `P0`
- Menu Path: `Compliance > Launch New eDiscovery Search` using `New Case`
- Required Session Before Start: `Compliance`
- Objective: verify new-case and search creation for an Exchange-targeted search
- Preconditions:
  - choose a disposable case name and search name
- Steps:
  1. Open `Compliance`.
  2. Select `Launch New eDiscovery Search`.
  3. choose `New Case`.
  4. create a new case.
  5. create a new Exchange search using a harmless keyword set.
- Expected Result:
  - new case creation succeeds
  - compliance search is created and started
  - search reaches `Completed`
- Cleanup:
  - delete the test search and test case if not needed

### MLR-012

- ID: `MLR-012`
- Priority: `P0`
- Menu Path: `Compliance > Launch New eDiscovery Search` using `Existing Case`
- Required Session Before Start: `Compliance`
- Objective: verify the existing-case branch no longer drops back to the menu silently
- Preconditions:
  - at least one usable eDiscovery case exists
- Steps:
  1. Open `Compliance`.
  2. Select `Launch New eDiscovery Search`.
  3. choose `Existing Case`.
  4. select the target case.
  5. create a new Exchange search.
- Expected Result:
  - existing cases are listed correctly
  - case selection works
  - search is created and starts successfully
- Cleanup:
  - delete the test search if no longer needed

### MLR-013

- ID: `MLR-013`
- Priority: `P0`
- Menu Path: `Account > Disable Account MFA`
- Required Session Before Start: `Entra`
- Objective: verify per-user MFA state disable and restore
- Preconditions:
  - test account exists
  - per-user MFA is enabled or enforced on the account, or baseline state is known
- Steps:
  1. Open `Account`.
  2. Select `Disable Account MFA`.
  3. choose the test account.
  4. if successful, run the undo path.
- Expected Result:
  - MAAD disables per-user MFA state successfully
  - undo restores the prior state
- Cleanup:
  - verify the test account MFA state matches baseline after undo

## Targeted Regression Cases

These cases cover recently changed or historically fragile paths that should be revalidated even if they are not part of the smallest smoke path.

### MLR-101

- ID: `MLR-101`
- Priority: `P0`
- Menu Path: `Group > Add user to Group`
- Related Risk: `P0.2 AddObjectToGroup`
- Required Session Before Start: `Entra`
- Objective: verify user-to-group membership changes still work with current user and group resolution
- Preconditions:
  - disposable test user exists
  - target group exists and is safe to modify
- Steps:
  1. Open `Group`.
  2. Select `Add user to Group`.
  3. choose the disposable test user.
  4. choose the target group.
  5. confirm the add operation.
- Expected Result:
  - MAAD resolves both the user and the group correctly
  - membership is added without parameter or id-resolution errors
  - group membership can be confirmed in Entra or by rerunning group membership recon
- Cleanup:
  - remove the user from the group after validation

### MLR-102

- ID: `MLR-102`
- Priority: `P1`
- Menu Path: `Group > Create Group`
- Related Risk: `P1.1 CreateNewEntraGroup`
- Required Session Before Start: `Entra`
- Objective: verify group creation still works and undo deletes the group
- Preconditions:
  - choose a unique disposable group name and mail nickname
- Steps:
  1. Open `Group`.
  2. Select `Create Group`.
  3. create a disposable group.
  4. if creation succeeds, run the undo path.
- Expected Result:
  - group is created successfully
  - no `MailNickname` validation or parameter errors occur
  - undo removes the group successfully
- Cleanup:
  - verify the created group no longer exists if undo was used
  - otherwise delete it manually

### MLR-103

- ID: `MLR-103`
- Priority: `P1`
- Menu Path: `Compliance > Escalate eDiscovery Privileges`
- Related Risk: `P1.2 E_Discovery_Priv_Esc`
- Required Session Before Start: `Mixed`
- Objective: verify account lookup, role-group assignment, and eDiscovery admin assignment all still work together
- Preconditions:
  - `Access > Establish Access - Entra` completed
  - `Access > Establish Access - Exchange Online` completed
  - `Access > Establish Access - Compliance (eDiscovery)` completed
  - disposable or approved test user exists
  - operator has rights to manage the target role group or case membership
- Steps:
  1. Open `Compliance`.
  2. Select `Escalate eDiscovery Privileges`.
  3. choose the test user.
  4. complete the role-group or case-admin assignment flow.
- Expected Result:
  - MAAD resolves the user correctly with current Entra lookup behavior
  - privilege escalation action completes without user-resolution or session errors
  - the new membership can be confirmed from Exchange or compliance recon
- Cleanup:
  - remove any granted role group membership and case admin assignment

### MLR-104

- ID: `MLR-104`
- Priority: `P2`
- Menu Path: `Application > Generate New Application Credentials`
- Related Risk: `P2.1 Enter/ValidateApp`
- Required Session Before Start: `Entra`
- Objective: verify application selection and app credential generation still work with current application lookup flow
- Preconditions:
  - a disposable or approved test application exists
- Steps:
  1. Open `Application`.
  2. Select `Generate New Application Credentials`.
  3. choose the target application.
  4. generate a disposable secret or credential.
- Expected Result:
  - application lookup works without validation errors
  - credential creation succeeds
  - the generated credential details are shown or exported as expected
- Cleanup:
  - remove the generated credential if appropriate

### MLR-105

- ID: `MLR-105`
- Priority: `P2`
- Menu Path: `Teams > Invite External User to Teams`
- Related Risk: `P2.2 ExternalTeamsInvite`
- Required Session Before Start: `Mixed`
- Objective: verify external invitation plus Teams membership flow still works
- Preconditions:
  - `Access > Establish Access - Entra` completed
  - `Access > Establish Access - Teams` completed
  - a test team exists
  - a disposable external email address is available
- Steps:
  1. Open `Teams`.
  2. Select `Invite External User to Teams`.
  3. choose the target team.
  4. invite the external address.
- Expected Result:
  - invitation succeeds without casing or cmdlet-name issues
  - the external account is added to the target team successfully
  - the invitation and team membership can be verified in the tenant
- Cleanup:
  - remove the invited account from the team

### MLR-106

- ID: `MLR-106`
- Priority: `P3`
- Menu Path: `Entra > Exploit Cross Tenant Sync`
- Related Risk: `P3.1 ExploitCTS`
- Required Session Before Start: `Mixed`
- Objective: verify the CTS flow still works without the old profile-selection behavior
- Preconditions:
  - `Access > Establish Access - Entra` completed
  - `Access > Establish Access - Az` completed
  - cross-tenant sync lab prerequisites are prepared in the test tenant
  - a safe target scope for the test has been agreed
- Steps:
  1. Open `Entra`.
  2. Select `Exploit Cross Tenant Sync`.
  3. complete the target selection and synchronization flow.
- Expected Result:
  - the flow completes without `Select-MgProfile` or Graph profile-selection errors
  - MAAD can resolve the needed tenant and synchronization objects
  - the expected sync-side effect is observable in the test environment
- Cleanup:
  - remove any test sync artifacts or group membership changes introduced during the test

## Suggested Evidence to Record

- test id
- date and operator
- branch and commit
- host OS and PowerShell version
- important installed module versions
- target object names used
- MAAD console output summary
- portal-side verification summary
- cleanup status
- pass, fail, blocked, or pass-with-notes

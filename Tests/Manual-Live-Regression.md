# MAAD Manual Live Regression Runbook

Use this runbook when you want an operator to re-test the most important live MAAD workflows and record a simple `Pass`, `Fail`, or `Blocked` result.

This document is intentionally written for operators with limited repo knowledge.

## Scope

This runbook covers the main tenant-facing workflows we currently care about before wider rollout:

- `Account`
- `Group`
- `Application`
- `Entra`
- `Exchange`
- `Teams`
- `Compliance`

This runbook does not include these menu categories:

- `Pre-Attack`
- `Access`
- `MAAD-AF`
- `Exit`

Those categories are treated as setup or operator controls, not part of this regression pack.

## How To Use This Runbook

1. Copy [Manual-Live-Run-Template.md](./Manual-Live-Run-Template.md) for the current test run.
2. Use a clean Windows PowerShell 5.1 test host or VM snapshot if possible.
3. Make sure the required service session is already connected before starting each test block.
4. For each test case below, follow the click path exactly, enter the test data, and record one result:
   - `Pass`
   - `Fail`
   - `Blocked`
5. If a test fails, record the exact MAAD error text.
6. If a test changes tenant state, complete the cleanup step before moving on.

## Result Rules

- `Pass`: the MAAD workflow completed and the expected tenant change or output was confirmed
- `Fail`: the workflow errored, stopped unexpectedly, or completed with the wrong result
- `Blocked`: the workflow could not be tested because the environment, permissions, or test data were not ready

## Before You Start

Prepare these test objects before the run:

- one disposable Entra user
- one disposable Entra group
- one test mailbox
- one test application
- one test team
- one external email address for Teams invite testing
- one disposable trusted named location name
- one disposable eDiscovery case name
- one disposable eDiscovery search name

## Session Prerequisites

This runbook does not test the `Access` menu. Before running each test block, make sure the required session is already established.

| Test Area | Required Session |
|---|---|
| Account | Entra |
| Group | Entra |
| Application | Entra |
| Entra | Entra |
| Exchange | Exchange Online |
| Teams | Entra and Teams |
| Compliance | Compliance (eDiscovery) |
| Cross Tenant Sync | Entra and Az |

## What To Record For Every Test

- test id
- result: `Pass`, `Fail`, or `Blocked`
- exact object name used
- exact error text if the test failed
- whether cleanup was completed

## Suggested Order

Run the tests in this order:

1. Account
2. Group
3. Application
4. Entra
5. Exchange
6. Teams
7. Compliance

## Test Cases

### REG-01 Account List

- Menu Path: `Account > List Accounts in Tenant`
- Required Session: `Entra`
- Test Data: `None`
- Steps:
  1. Open `Account`.
  2. Select `List Accounts in Tenant`.
- Pass if:
  - MAAD displays or exports tenant accounts.
  - no module-load or command-not-found error appears.
- Fail if:
  - the action errors or returns no usable account list unexpectedly.
- Cleanup:
  - none

### REG-02 Create Backdoor Account

- Menu Path: `Account > Deploy Backdoor Account`
- Required Session: `Entra`
- Test Data:
  - disposable user UPN
  - valid password that meets tenant policy
- Steps:
  1. Open `Account`.
  2. Select `Deploy Backdoor Account`.
  3. Create the disposable test user.
  4. If MAAD offers undo, run the undo step.
- Pass if:
  - the user is created successfully.
  - MAAD saves the result without error.
  - undo removes the user successfully if used.
- Fail if:
  - user creation fails.
  - undo fails.
- Cleanup:
  - if undo was skipped or failed, delete the user manually

### REG-03 Assign Entra Role To Account

- Menu Path: `Account > Assign Entra Role to Account`
- Required Session: `Entra`
- Test Data:
  - disposable user
  - one low-risk test role approved for the tenant
- Steps:
  1. Open `Account`.
  2. Select `Assign Entra Role to Account`.
  3. Choose the disposable user.
  4. Assign the approved test role.
- Pass if:
  - MAAD resolves the user and role correctly.
  - the role assignment succeeds.
- Fail if:
  - the user or role cannot be resolved.
  - the assignment fails.
- Cleanup:
  - remove the assigned role after verification

### REG-04 Reset Password

- Menu Path: `Account > Reset Password`
- Required Session: `Entra`
- Test Data:
  - disposable user
  - known temporary password
- Steps:
  1. Open `Account`.
  2. Select `Reset Password`.
  3. Choose the disposable user.
  4. Set the temporary password.
- Pass if:
  - the password reset succeeds.
  - MAAD records the new credential without error.
- Fail if:
  - MAAD cannot resolve the user.
  - the password reset fails.
- Cleanup:
  - reset the account back to its baseline password

### REG-05 Disable Account MFA

- Menu Path: `Account > Disable Account MFA`
- Required Session: `Entra`
- Test Data:
  - disposable user with a known baseline MFA state
- Steps:
  1. Open `Account`.
  2. Select `Disable Account MFA`.
  3. Choose the disposable user.
  4. If MAAD offers undo, run the undo step.
- Pass if:
  - the MFA change succeeds.
  - undo restores the prior state if used.
- Fail if:
  - the user cannot be resolved.
  - the MFA change or undo fails.
- Cleanup:
  - restore the user MFA state to baseline

### REG-06 Create Group

- Menu Path: `Group > Create Group`
- Required Session: `Entra`
- Test Data:
  - unique disposable group name
  - unique mail nickname
- Steps:
  1. Open `Group`.
  2. Select `Create Group`.
  3. Create the disposable group.
  4. If MAAD offers undo, run the undo step.
- Pass if:
  - the group is created successfully.
  - no `MailNickname` or parameter error appears.
  - undo removes the group successfully if used.
- Fail if:
  - group creation fails.
  - undo fails.
- Cleanup:
  - delete the created group if still present

### REG-07 Add User To Group

- Menu Path: `Group > Add user to Group`
- Required Session: `Entra`
- Test Data:
  - disposable user
  - disposable or approved test group
- Steps:
  1. Open `Group`.
  2. Select `Add user to Group`.
  3. Choose the disposable user.
  4. Choose the target group.
  5. Confirm the add operation.
- Pass if:
  - MAAD resolves the user and group correctly.
  - membership is added successfully.
- Fail if:
  - user or group lookup fails.
  - the add operation fails.
- Cleanup:
  - remove the user from the group

### REG-08 Generate New Application Credentials

- Menu Path: `Application > Generate New Application Credentials`
- Required Session: `Entra`
- Test Data:
  - test application
- Steps:
  1. Open `Application`.
  2. Select `Generate New Application Credentials`.
  3. Choose the test application.
  4. Generate a disposable credential.
- Pass if:
  - the application can be resolved.
  - a new credential is generated successfully.
- Fail if:
  - the application lookup fails.
  - credential creation fails.
- Cleanup:
  - remove the generated application credential if not needed

### REG-09 Modify Trusted IP Config

- Menu Path: `Entra > Modify Trusted IP Config`
- Required Session: `Entra`
- Test Data:
  - disposable trusted named location name
  - safe public IP or the current public IP
- Steps:
  1. Open `Entra`.
  2. Select `Modify Trusted IP Config`.
  3. Create the named location.
  4. If MAAD offers undo, run the undo step.
- Pass if:
  - the policy is created successfully.
  - MAAD shows the created name, id, and CIDR.
  - undo removes the policy successfully if used.
- Fail if:
  - creation fails.
  - undo fails.
- Cleanup:
  - delete the named location if still present

### REG-10 Exploit Cross Tenant Sync

- Menu Path: `Entra > Exploit Cross Tenant Sync`
- Required Session: `Entra and Az`
- Test Data:
  - prepared CTS lab scope and approved test target
- Steps:
  1. Open `Entra`.
  2. Select `Exploit Cross Tenant Sync`.
  3. Complete the target-selection flow.
- Pass if:
  - the flow runs without Graph profile-selection errors.
  - the expected lab-side change is visible.
- Fail if:
  - the flow errors.
  - required tenant or sync objects cannot be resolved.
- Cleanup:
  - remove any test sync artifacts or temporary membership changes

### REG-11 Disable Anti-Phishing Policy

- Menu Path: `Exchange > Disable Anti-Phishing Policy`
- Required Session: `Exchange Online`
- Test Data:
  - one approved anti-phish rule
- Steps:
  1. Open `Exchange`.
  2. Select `Disable Anti-Phishing Policy`.
  3. Run the recon prompt if MAAD asks.
  4. Disable the approved rule.
  5. If MAAD offers undo, run the undo step.
- Pass if:
  - MAAD lists the rules.
  - the selected rule is disabled successfully.
  - undo re-enables it successfully if used.
- Fail if:
  - the rules cannot be listed.
  - disable or undo fails.
- Cleanup:
  - confirm the rule is back in its original state

### REG-12 Disable Mailbox Auditing

- Menu Path: `Exchange > Disable Mailbox Auditing`
- Required Session: `Exchange Online`
- Test Data:
  - one test mailbox
- Steps:
  1. Open `Exchange`.
  2. Select `Disable Mailbox Auditing`.
  3. Choose the test mailbox.
  4. Confirm the disable action.
  5. If MAAD offers undo, run the undo step.
- Pass if:
  - MAAD shows the current and updated state.
  - undo restores the mailbox setting successfully if used.
- Fail if:
  - mailbox lookup fails.
  - the change or undo fails.
- Cleanup:
  - restore the mailbox setting to baseline

### REG-13 Invite External User To Teams

- Menu Path: `Teams > Invite External User to Teams`
- Required Session: `Entra and Teams`
- Test Data:
  - one test team
  - one disposable external email address
- Steps:
  1. Open `Teams`.
  2. Select `Invite External User to Teams`.
  3. Choose the target team.
  4. Invite the external address.
- Pass if:
  - the invitation succeeds.
  - the external account is added to the team successfully.
- Fail if:
  - the invitation fails.
  - the team membership step fails.
- Cleanup:
  - remove the external account from the team

### REG-14 Launch New eDiscovery Search In New Case

- Menu Path: `Compliance > Launch New eDiscovery Search`
- Required Session: `Compliance (eDiscovery)`
- Test Data:
  - disposable case name
  - disposable search name
  - harmless Exchange keyword query
- Steps:
  1. Open `Compliance`.
  2. Select `Launch New eDiscovery Search`.
  3. Choose `New Case`.
  4. Create the new case.
  5. Create an Exchange search with the harmless query.
- Pass if:
  - the case is created.
  - the search is created and started successfully.
- Fail if:
  - case creation fails.
  - search creation or start fails.
- Cleanup:
  - delete the test search and case if they are no longer needed

### REG-15 Launch New eDiscovery Search In Existing Case

- Menu Path: `Compliance > Launch New eDiscovery Search`
- Required Session: `Compliance (eDiscovery)`
- Test Data:
  - one existing test case
  - one disposable search name
  - harmless Exchange keyword query
- Steps:
  1. Open `Compliance`.
  2. Select `Launch New eDiscovery Search`.
  3. Choose `Existing Case`.
  4. Select the target case.
  5. Create the Exchange search.
- Pass if:
  - the case list appears.
  - the case can be selected.
  - the search is created and started successfully.
- Fail if:
  - MAAD drops back to the menu.
  - case selection fails.
  - search creation or start fails.
- Cleanup:
  - delete the test search if it is no longer needed

### REG-16 Escalate eDiscovery Privileges

- Menu Path: `Compliance > Escalate eDiscovery Privileges`
- Required Session: `Entra, Exchange Online, and Compliance (eDiscovery)`
- Test Data:
  - disposable or approved test user
- Steps:
  1. Open `Compliance`.
  2. Select `Escalate eDiscovery Privileges`.
  3. Choose the test user.
  4. Complete the privilege-assignment flow.
- Pass if:
  - MAAD resolves the user correctly.
  - the privilege assignment completes successfully.
- Fail if:
  - the user lookup fails.
  - role-group or case-admin assignment fails.
- Cleanup:
  - remove all granted memberships or elevated privileges

## Operator Notes

- If MAAD shows `[x] ...`, copy the full error into the run template.
- If the action succeeds in MAAD but the tenant state does not match the expected result, mark `Fail`.
- If the correct session was not connected before the test started, mark `Blocked` rather than `Fail`.

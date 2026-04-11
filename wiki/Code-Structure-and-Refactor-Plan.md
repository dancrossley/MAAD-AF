# Code Structure and Refactor Plan

This page explains the current repo structure and outlines a stability-first refactor plan.

## Current Shape

### Entrypoint

- [MAAD_Attack.ps1](../MAAD_Attack.ps1)

This is the bootstrap script. It dot-sources the `Library/` folder, initializes global paths, runs dependency/bootstrap steps, and launches the menu.

### Main Router

- [MAAD_Attack_Arsenal.ps1](../Library/MAAD_Attack_Arsenal.ps1)

This file defines:

- the visible menu structure
- the submenu structure
- the large `switch` that maps menu choices to functions

### Shared Core

- [MAAD_Basic_Modules.ps1](../Library/MAAD_Basic_Modules.ps1)
- [MAAD_Credential_Store_Manager.ps1](../Library/MAAD_Credential_Store_Manager.ps1)
- [Access_Modules.ps1](../Library/Access_Modules.ps1)

These files currently hold most of the shared machinery:

- bootstrap
- dependency installation
- console UI helpers
- prompts and selectors
- validation helpers
- output rendering
- credential selection
- service access/session setup

### Feature Files

The rest of `Library/` is mostly domain oriented:

- [ReconModules.ps1](../Library/ReconModules.ps1)
- [Compliance_Modules.ps1](../Library/Compliance_Modules.ps1)
- [SharepointModules.ps1](../Library/SharepointModules.ps1)
- smaller single-purpose feature files like [ResetPassword.ps1](../Library/ResetPassword.ps1), [DisableMFA.ps1](../Library/DisableMFA.ps1), and [ModifyTrustedNetworkConfig.ps1](../Library/ModifyTrustedNetworkConfig.ps1)

## What Is Working Well

- Features are discoverable by domain.
- The entrypoint is simple to follow.
- Most attack actions are isolated enough for targeted fixes.
- The menu model makes the tool easy to operate interactively.
- The validation framework in [Tests/Invoke-MAADValidation.ps1](../Tests/Invoke-MAADValidation.ps1) provides a growing safety net.

## What Is Structurally Fragile

### Heavy Global State

The code relies heavily on `$global:*` variables for:

- selected user, group, role, mailbox, site, case, and search
- current credentials and tokens
- current session context

This makes feature functions easy to write, but harder to reason about and easier to break indirectly.

### Large Mixed-Responsibility Files

The biggest hotspots are:

- [MAAD_Basic_Modules.ps1](../Library/MAAD_Basic_Modules.ps1)
- [Access_Modules.ps1](../Library/Access_Modules.ps1)

Both files currently act like several modules at once.

### Menu Routing Is Brittle

[MAAD_Attack_Arsenal.ps1](../Library/MAAD_Attack_Arsenal.ps1) hardcodes the menu and the execution switch together. That makes it easy for UI labels, prerequisites, and actual handlers to drift out of sync.

### Error Handling Is Inconsistent

Some paths now have strong explicit errors, but the repo still contains broad catches and some silent fall-through behavior. That makes debugging much harder than it needs to be.

## Recommended Refactor Plan

Treat this as a stability-first refactor, not a rewrite.

## Low Risk Changes

- Split [MAAD_Basic_Modules.ps1](../Library/MAAD_Basic_Modules.ps1) into `Bootstrap`, `Logging`, `UI`, and `Selectors` files while keeping the same public function names.
- Split [Access_Modules.ps1](../Library/Access_Modules.ps1) by service into `Access.Entra`, `Access.Exchange`, `Access.Teams`, `Access.SharePoint`, and `Access.Compliance`.
- Add one shared error-reporting helper and remove broad silent catches where safe.
- Add shared preflight helpers such as:
  - required module loaded
  - required session exists
  - supported auth path
- Expand [Tests/Invoke-MAADValidation.ps1](../Tests/Invoke-MAADValidation.ps1) before and after each refactor step.

## Medium Risk Changes

- Replace the giant `switch` in [MAAD_Attack_Arsenal.ps1](../Library/MAAD_Attack_Arsenal.ps1) with a command registry that stores:
  - label
  - handler
  - prerequisite session
  - optional notes
- Update selectors in [MAAD_Basic_Modules.ps1](../Library/MAAD_Basic_Modules.ps1) to return values instead of only mutating globals. Keep writing the globals temporarily for backward compatibility.
- Introduce a small context object for current auth/session state instead of spreading session state across many globals.
- Normalize feature functions to a common pattern:
  - preflight
  - prompt
  - execute
  - verify
  - optional undo

## High Risk Changes

- Replace repo-wide dot-sourcing with a real PowerShell module structure.
- Remove most `$global:*` state and pass objects explicitly between functions.
- Separate dependency/bootstrap logic from runtime operation.
- Introduce a cleaner abstraction for service access instead of calling provider-specific auth logic directly from many places.

## Suggested Order

1. Freeze current behavior with clean-host validation and test reports.
2. Do the low-risk file splits without changing public function names.
3. Improve error handling and preflight checks.
4. Replace the menu switch with a command registry.
5. Reduce global state gradually.
6. Consider full module-ization only after the tool is stable again.

## Bottom Line

The current structure is serviceable for an interactive PowerShell tool, but it is more fragile than ideal for ongoing change. The best path is incremental cleanup with tests, not a large rewrite.

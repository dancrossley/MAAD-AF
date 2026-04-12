# MAAD Validation Framework

This folder contains a lightweight PowerShell test harness for MAAD-AF. The framework inventories every function in `Library/`, validates that each function parses and loads, and produces a Markdown and JSON report showing which functions are:

- `Pass`: validated automatically
- `Fail`: parser, load, or smoke validation failed
- `Manual`: requires live tenant validation or interactive review
- `Skipped`: smoke-test capable, but smoke mode was not enabled

## Why This Framework Exists

MAAD-AF mixes pure helper functions, local configuration helpers, read-only live tenant recon, and highly destructive tenant-changing actions. A realistic test framework needs to distinguish between those categories instead of trying to execute every function blindly.

The harness therefore runs in layers:

1. Static validation for every discovered function
2. Safe smoke tests for selected helper and local-only functions
3. Opt-in live tests for a small safe subset of read-only functions
4. Manual/live classification for functions that still need prompts, tenant write access, or broader environment setup

## Files

- `Invoke-MAADValidation.ps1`
  Main runner. Discovers functions, parses menu bindings, executes smoke tests, and writes reports.
- `MAAD-TestProfile.ps1`
  Classification profile for every section of MAAD plus function-level overrides for smoke tests.
- `Manual-Live-Regression.md`
  Stable manual live tenant regression catalog for high-value workflows and targeted regression cases.
- `Manual-Live-Run-Template.md`
  Fill-in template for recording the result of each live regression run.

## Usage

Run from Windows PowerShell 5.1:

```powershell
.\Tests\Invoke-MAADValidation.ps1
```

Run static validation only:

```powershell
.\Tests\Invoke-MAADValidation.ps1 -Mode Static
```

Fail the process if any automated validation fails:

```powershell
.\Tests\Invoke-MAADValidation.ps1 -Mode Static,Smoke -FailOnFailure
```

Reports are written to `.\TestReports` by default.

## Live Validation

The harness also supports an opt-in `Live` mode for a safe subset of read-only functions. These tests are not enabled by default.

1. Connect the required services in the same Windows PowerShell 5.1 session.
   For example:

```powershell
Connect-Entra
Connect-AzAccount
```

2. Copy `.\Tests\live-config.sample.json` to your own config file and trim the `EnabledLiveTests` list to the functions you want to exercise.

3. Run the harness with live mode enabled:

```powershell
.\Tests\Invoke-MAADValidation.ps1 -Mode Static,Smoke,Live -LiveConfigPath .\Tests\live-config.sample.json
```

The current live catalog focuses on read-only functions such as:

- `MAADGetAllAADUsers`
- `MAADGetAllAADGroups`
- `MAADGetAllServicePrincipal`
- `ListAuthorizationPolicy`
- `MAADGetNamedLocations`
- `MAADGetConditionalAccessPolicies`
- `MAADGetAllDirectoryRoles`
- `MAADGetAccessibleTenants`

Live tests are only executed when:

- `-Mode Live` is specified
- the function is included in `EnabledLiveTests` or the allowlist is left empty
- the required service session is already connected in the current PowerShell process

## What Gets Tested Automatically

The default smoke catalog focuses on low-risk functions such as:

- Entra scope and token helper functions
- Credential-store formatting and local writes
- Output export helpers
- Local MAAD working-directory setup
- PowerShell session-limit initialization

These smoke tests run in an isolated temporary workspace so they do not modify a real MAAD local state directory.

## What Still Needs Manual Or Live Validation

Functions that establish live access, query a tenant, or mutate Microsoft 365 / Entra state are intentionally classified as `Manual` or `Live*` in the generated report. Those functions should be validated in a controlled tenant with known-good credentials and change-control around destructive actions.

## Manual Live Regression

For release validation on a live tenant, use:

- [`Manual-Live-Regression.md`](./Manual-Live-Regression.md) for the curated manual test cases
- [`Manual-Live-Run-Template.md`](./Manual-Live-Run-Template.md) to record a specific run

The intent is:

1. keep the test catalog stable in source control
2. copy the run template for each regression pass
3. attach or archive the completed results with the release or validation cycle

The recommended workflow is:

1. start from a clean Windows PowerShell 5.1 host or VM snapshot
2. run `Static` and `Smoke` validation first
3. execute the `P0` manual live cases in order
4. execute the targeted regression cases for recently changed code paths
5. verify cleanup before treating the build as ready for other operators

## CI

The included GitHub Actions workflow runs the safe `Static` and `Smoke` validation modes on a Windows runner and uploads the generated reports as artifacts.

# TODO

This is the post-freeze authentication and operator-flow backlog for MAAD-FV.
`main` is frozen; authentication changes should be implemented on short-lived branches and validated on a clean Windows PowerShell 5.1 VM.

## Current Baseline

The current clean baseline was validated on a clean Windows VM.

Passing flows:

- `Access > Establish Access - Entra`
- `Account > Deploy Backdoor Account`
- `Account > Assign Entra Role to Account`
- `Entra > Modify Trusted IP Config`
- `Access > Establish Access - Exchange Online`
- `Exchange > Disable Mailbox Auditing`
- `Exchange > Disable Anti-Phishing Policy`
- `Account > Reset Password`
- `Access > Establish Access - Compliance (eDiscovery)`
- `Compliance > Launch New eDiscovery Search`
- `Account > Disable Account MFA`

## P0 - Operator-Facing Authentication Cleanup

- Unify the Entra sign-in model.
  Decide and implement one supported default for customer-facing runs: browser-interactive sign-in.
  Remove or hide device code from the normal operator flow and keep it only as internal troubleshooting if still needed.
- Make credential selection service-aware.
  Entra should only offer valid Entra inputs for the intended model.
  Exchange, Teams, SharePoint, Az, and Compliance should only show credential types they can actually consume.
  Stop showing credential options that are later ignored or silently downgraded.
- Standardize single-account-per-run behavior.
  Make the intended operator model explicit in the tool, not just in docs.
  Prevent confusing account-switch behavior during a single run, or fail clearly with guidance to start a fresh session.
- Improve auth-path messaging.
  Before sign-in, tell the operator exactly which auth method will be used.
  On failure, tell the operator what to do next instead of falling through multiple auth modes silently.

## P1 - Session Robustness and Failure Handling

- Formalize service session state.
  Track whether Entra, Exchange, Compliance, Teams, SharePoint, and Az sessions are active, stale, or displaced.
  Use that state consistently before running feature modules.
- Handle Exchange and Compliance session collisions cleanly.
  Keep the existing warning that Compliance disconnects Exchange.
  Expand this into a predictable session-state model so later Exchange actions fail fast with a clear reconnect instruction.
- Add preflight checks before feature execution.
  Verify the required cmdlets and service session exist before entering a feature workflow.
  Fail before prompts where possible.
- Stabilize `Access > Get Access Info`.
  Keep it useful for operators without causing session instability.
  Make role, group, and ownership lookups reliable and avoid fragile identifier assumptions.
- Centralize auth exception handling.
  Use one shared helper for auth errors so the tool prints the full useful exception chain once and in a consistent format.

## P2 - Environment and Credential Hygiene

- Improve PowerShell 5.1 dependency resilience.
  Detect incompatible Entra/Graph module states earlier and show exact remediation guidance.
  Avoid auth-path behavior that works only on a perfectly clean host without telling the operator that constraint.
- Harden token handling.
  Validate token audience, expiry, and intended service before attempting connection.
  Show the operator why a stored token is invalid.
- Improve credential-store UX.
  Make saved credential listings clearer about what each entry is for.
  Distinguish password, Graph token, application credential, and service-specific usability.
- Document clean-session expectations.
  Keep the environment-hygiene guidance aligned with the actual auth flows and supported launch patterns.

## Validation Required For Any Auth Change

All authentication-flow changes must be validated on a clean Windows PowerShell 5.1 VM.

Minimum validation:

- `Access > Establish Access - Entra`
- `Access > Get Access Info`
- `Account > List Accounts in Tenant`
- `Access > Establish Access - Exchange Online`
- `Exchange > Disable Mailbox Auditing`
- `Access > Establish Access - Compliance (eDiscovery)`

Normal launch with `.\MAAD_Attack.ps1` is the primary validation path.
`-ForceBypassDependencyCheck` is secondary and should only be used to isolate startup or dependency behavior.

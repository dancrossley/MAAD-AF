param(
    [ValidateSet("Static", "Smoke", "Live")]
    [string[]]$Mode = @("Static", "Smoke"),
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$ProfilePath = (Join-Path $PSScriptRoot "MAAD-TestProfile.ps1"),
    [string]$OutputDirectory = (Join-Path (Split-Path -Parent $PSScriptRoot) "TestReports"),
    [string]$LiveConfigPath,
    [switch]$FailOnFailure
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-MAADCondition {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function ConvertTo-MAADMarkdownCell {
    param([AllowNull()][object]$Value)

    if ($null -eq $Value) {
        return ""
    }

    return ([string]$Value).Replace("|", "/").Replace("`r", " ").Replace("`n", " ").Trim()
}

function Get-MAADTimestampString {
    return (Get-Date).ToString("yyyyMMdd-HHmmss")
}

function Get-MAADRelativePath {
    param(
        [string]$BasePath,
        [string]$ChildPath
    )

    if ($ChildPath.StartsWith($BasePath, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $ChildPath.Substring($BasePath.Length).TrimStart("\", "/")
    }

    return $ChildPath
}

function New-MAADTestWorkspace {
    $workspace = Join-Path ([System.IO.Path]::GetTempPath()) ("MAAD-AF-Test-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $workspace -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $workspace "Local") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $workspace "Outputs") -Force | Out-Null
    return $workspace
}

function Reset-MAADHarnessState {
    param([string]$Workspace)

    $global:maad_credential_store = Join-Path $Workspace "Local/MAAD_Credential_Store.json"
    $global:maad_config_path = Join-Path $Workspace "Local/MAAD_AF_Global_Config.json"
    $global:maad_log_file = Join-Path $Workspace "Local/MAAD_AF_Log.txt"
    $global:current_username = $null
    $global:current_password = $null
    $global:current_access_token = $null
    $global:current_access_token_audience = $null
    $global:current_access_token_tenant_id = $null
    $global:current_credentials = $null
    $global:tor_proxy = $false

    "{}" | Set-Content -Path $global:maad_credential_store -Force

    $maad_config = [PSCustomObject]@{
        tor_config = @{
            tor_root_directory = "C:/Users/username/sub_folder/Tor Browser"
            tor_host = "127.0.0.1"
            tor_port = "9150"
            control_port = "9151"
        }
        DependecyCheckBypass = $false
    }

    $maad_config | ConvertTo-Json -Depth 5 | Set-Content -Path $global:maad_config_path -Force
    "" | Set-Content -Path $global:maad_log_file -Force
}

function Get-MAADLiveConfig {
    param([string]$ConfigPath)

    if ($ConfigPath -in "", $null) {
        return [PSCustomObject]@{
            EnabledLiveTests = @()
            DefaultReadHostResponse = "n"
        }
    }

    $resolved_path = $ConfigPath
    if (-not (Test-Path $resolved_path)) {
        throw "Live config file was not found: $ConfigPath"
    }

    $config = Get-Content -Path $resolved_path -Raw | ConvertFrom-Json

    if ($null -eq $config.EnabledLiveTests) {
        $config | Add-Member -MemberType NoteProperty -Name EnabledLiveTests -Value @()
    }

    if ($null -eq $config.DefaultReadHostResponse) {
        $config | Add-Member -MemberType NoteProperty -Name DefaultReadHostResponse -Value "n"
    }

    return $config
}

function Reset-MAADHarnessTelemetry {
    $script:MAADStartedProcesses = @()
    $script:MAADMessages = @()
    $script:MAADReadHostResponses = @()
}

function Add-MAADHarnessMessage {
    param(
        [string]$Level,
        [string]$Message
    )

    if ($null -eq $script:MAADMessages) {
        $script:MAADMessages = @()
    }

    $script:MAADMessages += [PSCustomObject]@{
        Level = $Level
        Message = [string]$Message
    }
}

function Install-MAADTestShims {
    Reset-MAADHarnessTelemetry

    function global:MAADPause {}
    function global:Start-Sleep {}
    function global:Clear-Host {}
    function global:Read-Host {
        param([string]$Prompt)

        if ($script:MAADReadHostResponses.Count -gt 0) {
            $response = $script:MAADReadHostResponses[0]

            if ($script:MAADReadHostResponses.Count -gt 1) {
                $script:MAADReadHostResponses = @($script:MAADReadHostResponses[1..($script:MAADReadHostResponses.Count - 1)])
            }
            else {
                $script:MAADReadHostResponses = @()
            }

            return $response
        }

        return "n"
    }
    function global:Start-Process {
        param(
            [string]$FilePath,
            [object[]]$ArgumentList
        )

        $script:MAADStartedProcesses += [PSCustomObject]@{
            FilePath = $FilePath
            ArgumentList = $ArgumentList
        }
    }
    function global:MAADWriteSuccess ([string]$message) {
        Add-MAADHarnessMessage -Level "Success" -Message $message
    }
    function global:MAADWriteProcess ([string]$message) {
        Add-MAADHarnessMessage -Level "Process" -Message $message
    }
    function global:MAADWriteInfo ([string]$message) {
        Add-MAADHarnessMessage -Level "Info" -Message $message
    }
    function global:MAADWriteError ([string]$message) {
        Add-MAADHarnessMessage -Level "Error" -Message $message
    }
}

function Get-MAADFunctionInventory {
    param([string]$LibraryPath)

    $function_inventory = @()
    $parse_issues = @{}

    foreach ($file in Get-ChildItem -Path $LibraryPath -Filter "*.ps1" | Sort-Object Name) {
        $tokens = $null
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)

        if ($errors.Count -gt 0) {
            $parse_issues[$file.FullName] = @($errors | ForEach-Object { $_.Message })
        }

        $functions = $ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst]
        }, $true)

        foreach ($function_ast in $functions) {
            $function_inventory += [PSCustomObject]@{
                Name = $function_ast.Name
                FilePath = $file.FullName
                RelativePath = Get-MAADRelativePath -BasePath $RepoRoot -ChildPath $file.FullName
                ParseStatus = if ($parse_issues.ContainsKey($file.FullName)) { "Fail" } else { "Pass" }
                ParseMessages = if ($parse_issues.ContainsKey($file.FullName)) { @($parse_issues[$file.FullName]) } else { @() }
            }
        }
    }

    return @{
        Functions = $function_inventory
        ParseIssues = $parse_issues
    }
}

function Get-MAADMenuBindings {
    param([string]$ArsenalPath)

    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($ArsenalPath, [ref]$tokens, [ref]$errors)
    $switch_statements = @($ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.SwitchStatementAst]
    }, $true))

    if ($switch_statements.Count -eq 0) {
        return @()
    }

    $primary_switch = $switch_statements | Sort-Object { $_.Clauses.Count } -Descending | Select-Object -First 1
    $bindings = @()

    foreach ($clause in $primary_switch.Clauses) {
        $label_ast = $clause.Item1
        $label_value = $label_ast.Extent.Text.Trim("'`"")

        if ($label_value -notmatch "^[A-Za-z-]+\.\d+$") {
            continue
        }

        $first_command = $clause.Item2.Find({
            param($node)
            $node -is [System.Management.Automation.Language.CommandAst]
        }, $true) | Select-Object -First 1

        $primary_function = $null
        if ($null -ne $first_command) {
            $primary_function = $first_command.GetCommandName()
        }

        $section, $option = $label_value -split "\.", 2

        $bindings += [PSCustomObject]@{
            ExecutionChoice = $label_value
            Section = $section
            Option = $option
            PrimaryFunction = $primary_function
            InvocationText = $clause.Item2.Extent.Text.Trim()
        }
    }

    return $bindings
}

function Get-MAADFunctionMetadata {
    param(
        [pscustomobject]$FunctionInfo,
        [hashtable]$Profile,
        [array]$Bindings
    )

    $matching_bindings = @($Bindings | Where-Object { $_.PrimaryFunction -eq $FunctionInfo.Name })
    $section = if ($matching_bindings.Count -gt 0) { $matching_bindings[0].Section } else { "Helper" }
    if ($section -ne "Helper" -and $Profile.SectionDefaults.ContainsKey($section)) {
        $profile_entry = @{} + $Profile.SectionDefaults[$section]
    }
    else {
        $profile_entry = @{} + $Profile.DefaultHelper
    }

    if ($Profile.FunctionOverrides.ContainsKey($FunctionInfo.Name)) {
        foreach ($key in $Profile.FunctionOverrides[$FunctionInfo.Name].Keys) {
            $profile_entry[$key] = $Profile.FunctionOverrides[$FunctionInfo.Name][$key]
        }
    }

    return [PSCustomObject]@{
        Section = $section
        MenuChoices = @($matching_bindings | ForEach-Object { $_.ExecutionChoice })
        ValidationMode = $profile_entry.ValidationMode
        Risk = $profile_entry.Risk
        Notes = $profile_entry.Notes
        SmokeTest = if ($profile_entry.ContainsKey("SmokeTest")) { $profile_entry.SmokeTest } else { $null }
        LiveTest = if ($profile_entry.ContainsKey("LiveTest")) { $profile_entry.LiveTest } else { $null }
        RequiredServices = if ($profile_entry.ContainsKey("RequiredServices")) { @($profile_entry.RequiredServices) } else { @() }
    }
}

function Test-MAADLiveRequirements {
    param([string[]]$RequiredServices)

    $missing_services = @()

    foreach ($service in $RequiredServices) {
        switch ($service) {
            "Entra" {
                try {
                    $entra_context = Get-EntraContext -ErrorAction Stop
                    if ($null -eq $entra_context) {
                        $missing_services += $service
                    }
                }
                catch {
                    $missing_services += $service
                }
            }
            "Az" {
                try {
                    $az_context = Get-AzContext -ErrorAction Stop
                    if ($null -eq $az_context) {
                        $missing_services += $service
                    }
                }
                catch {
                    $missing_services += $service
                }
            }
            Default {
                $missing_services += $service
            }
        }
    }

    return @($missing_services | Select-Object -Unique)
}

function Invoke-MAADLiveTest {
    param(
        [string]$LiveTest,
        [string]$Workspace,
        [pscustomobject]$LiveConfig
    )

    Reset-MAADHarnessTelemetry
    $script:MAADReadHostResponses = @($LiveConfig.DefaultReadHostResponse)

    switch ($LiveTest) {
        "MAADGetAllAADUsers" {
            $output_file = Join-Path $Workspace "Outputs/AAD_Accounts.txt"
            Remove-Item -Path $output_file -Force -ErrorAction SilentlyContinue
            MAADGetAllAADUsers
            Assert-MAADCondition (@($script:MAADMessages | Where-Object { $_.Level -eq "Error" }).Count -eq 0) "MAADGetAllAADUsers emitted an error."
            Assert-MAADCondition (Test-Path $output_file) "MAADGetAllAADUsers did not write its output file."
        }
        "MAADGetAllAADGroups" {
            $output_file = Join-Path $Workspace "Outputs/AAD_Groups.txt"
            Remove-Item -Path $output_file -Force -ErrorAction SilentlyContinue
            MAADGetAllAADGroups
            Assert-MAADCondition (@($script:MAADMessages | Where-Object { $_.Level -eq "Error" }).Count -eq 0) "MAADGetAllAADGroups emitted an error."
            Assert-MAADCondition (Test-Path $output_file) "MAADGetAllAADGroups did not write its output file."
        }
        "MAADGetAllServicePrincipal" {
            $output_file = Join-Path $Workspace "Outputs/AAD_Service_Princiapls.txt"
            Remove-Item -Path $output_file -Force -ErrorAction SilentlyContinue
            MAADGetAllServicePrincipal
            Assert-MAADCondition (@($script:MAADMessages | Where-Object { $_.Level -eq "Error" }).Count -eq 0) "MAADGetAllServicePrincipal emitted an error."
            Assert-MAADCondition (Test-Path $output_file) "MAADGetAllServicePrincipal did not write its output file."
        }
        "ListAuthorizationPolicy" {
            $output_file = Join-Path $Workspace "Outputs/AAD_Authorization_Policies.txt"
            Remove-Item -Path $output_file -Force -ErrorAction SilentlyContinue
            ListAuthorizationPolicy
            Assert-MAADCondition (@($script:MAADMessages | Where-Object { $_.Level -eq "Error" }).Count -eq 0) "ListAuthorizationPolicy emitted an error."
            Assert-MAADCondition (Test-Path $output_file) "ListAuthorizationPolicy did not write its output file."
        }
        "MAADGetNamedLocations" {
            $output_file = Join-Path $Workspace "Outputs/AAD_Named_Locations.txt"
            Remove-Item -Path $output_file -Force -ErrorAction SilentlyContinue
            MAADGetNamedLocations
            Assert-MAADCondition (@($script:MAADMessages | Where-Object { $_.Level -eq "Error" }).Count -eq 0) "MAADGetNamedLocations emitted an error."
            Assert-MAADCondition (Test-Path $output_file) "MAADGetNamedLocations did not write its output file."
        }
        "MAADGetConditionalAccessPolicies" {
            $output_file = Join-Path $Workspace "Outputs/All_CAP.txt"
            Remove-Item -Path $output_file -Force -ErrorAction SilentlyContinue
            MAADGetConditionalAccessPolicies
            Assert-MAADCondition (@($script:MAADMessages | Where-Object { $_.Level -eq "Error" }).Count -eq 0) "MAADGetConditionalAccessPolicies emitted an error."
            Assert-MAADCondition (Test-Path $output_file) "MAADGetConditionalAccessPolicies did not write its output file."
        }
        "MAADGetAllDirectoryRoles" {
            $output_file = Join-Path $Workspace "Outputs/AAD_Directory_Roles.txt"
            Remove-Item -Path $output_file -Force -ErrorAction SilentlyContinue
            MAADGetAllDirectoryRoles
            Assert-MAADCondition (@($script:MAADMessages | Where-Object { $_.Level -eq "Error" }).Count -eq 0) "MAADGetAllDirectoryRoles emitted an error."
            Assert-MAADCondition (Test-Path $output_file) "MAADGetAllDirectoryRoles did not write its output file."
        }
        "MAADGetAccessibleTenants" {
            $output_file = Join-Path $Workspace "Outputs/AAD_Accessible_Tenants.txt"
            Remove-Item -Path $output_file -Force -ErrorAction SilentlyContinue
            MAADGetAccessibleTenants
            Assert-MAADCondition (@($script:MAADMessages | Where-Object { $_.Level -eq "Error" }).Count -eq 0) "MAADGetAccessibleTenants emitted an error."
            Assert-MAADCondition (Test-Path $output_file) "MAADGetAccessibleTenants did not write its output file."
        }
        Default {
            throw "Unknown live test '$LiveTest'."
        }
    }
}

function Invoke-MAADSmokeTest {
    param(
        [string]$SmokeTest,
        [string]$Workspace
    )

    switch ($SmokeTest) {
        "InitializeMAADPowerShellLimits" {
            $starting_function_count = $MaximumFunctionCount
            $starting_variable_count = $MaximumVariableCount

            if (($PSVersionTable.PSVersion.Major) -eq 5) {
                Set-Variable -Name MaximumFunctionCount -Value 2048 -Scope Global -Force
                Set-Variable -Name MaximumVariableCount -Value 2048 -Scope Global -Force
                InitializeMAADPowerShellLimits
                Assert-MAADCondition ($MaximumFunctionCount -ge 32768) "MaximumFunctionCount was not raised."
                Assert-MAADCondition ($MaximumVariableCount -ge 32768) "MaximumVariableCount was not raised."
            }
            else {
                InitializeMAADPowerShellLimits
            }

            Set-Variable -Name MaximumFunctionCount -Value $starting_function_count -Scope Global -Force
            Set-Variable -Name MaximumVariableCount -Value $starting_variable_count -Scope Global -Force
        }
        "CreateLocalDir" {
            Remove-Item -Path (Join-Path $Workspace "Local") -Recurse -Force -ErrorAction SilentlyContinue
            CreateLocalDir
            Assert-MAADCondition (Test-Path (Join-Path $Workspace "Local")) "Local directory was not created."
            Assert-MAADCondition (Test-Path $global:maad_credential_store) "Credential store file was not created."
            Assert-MAADCondition (Test-Path $global:maad_config_path) "Config file was not created."
        }
        "CreateOutputsDir" {
            Remove-Item -Path (Join-Path $Workspace "Outputs") -Recurse -Force -ErrorAction SilentlyContinue
            CreateOutputsDir
            Assert-MAADCondition (Test-Path (Join-Path $Workspace "Outputs")) "Outputs directory was not created."
        }
        "GetMAADEntraScopes" {
            $scopes = @(GetMAADEntraScopes)
            Assert-MAADCondition ($scopes.Count -gt 0) "No Entra scopes were returned."
            Assert-MAADCondition ($scopes -contains "User.Invite.All") "Expected User.Invite.All in scope list."
            Assert-MAADCondition ($scopes -contains "Policy.ReadWrite.ConditionalAccess") "Expected Policy.ReadWrite.ConditionalAccess in scope list."
        }
        "GetMAADCredentialSummaryValue" {
            $password_summary = GetMAADCredentialSummaryValue ([pscustomobject]@{ type = "password"; username = "user@example.com" })
            $token_summary = GetMAADCredentialSummaryValue ([pscustomobject]@{ type = "token"; audience = "https://graph.microsoft.com" })
            $legacy_token_summary = GetMAADCredentialSummaryValue ([pscustomobject]@{ type = "token" })

            Assert-MAADCondition ($password_summary -eq "user@example.com") "Password summary did not return the username."
            Assert-MAADCondition ($token_summary -eq "https://graph.microsoft.com") "Token summary did not return the audience."
            Assert-MAADCondition ($legacy_token_summary -eq "Legacy token (missing audience)") "Legacy token summary was not returned."
        }
        "TestMAADGraphAudience" {
            Assert-MAADCondition (TestMAADGraphAudience "https://graph.microsoft.com") "Graph audience should be accepted."
            Assert-MAADCondition (-not (TestMAADGraphAudience "https://graph.windows.net")) "Azure AD Graph audience should be rejected."
        }
        "GetMAADTokenValidationMessage" {
            $legacy_message = GetMAADTokenValidationMessage ([pscustomobject]@{ type = "token"; token = "abc" })
            $invalid_message = GetMAADTokenValidationMessage ([pscustomobject]@{ type = "token"; token = "abc"; audience = "https://graph.windows.net" })
            $valid_message = GetMAADTokenValidationMessage ([pscustomobject]@{ type = "token"; token = "abc"; audience = "https://graph.microsoft.com" })

            Assert-MAADCondition ($legacy_message -match "retired Azure AD Graph") "Legacy token warning was not returned."
            Assert-MAADCondition ($invalid_message -match "not Microsoft Graph") "Invalid audience warning was not returned."
            Assert-MAADCondition ($null -eq $valid_message) "Valid Graph token should not return a warning."
        }
        "GetMAADValidGraphToken" {
            $global:current_access_token_audience = "https://graph.microsoft.com"
            Assert-MAADCondition ((GetMAADValidGraphToken "graph-token") -eq "graph-token") "Valid Graph token was not returned."

            $global:current_access_token_audience = "https://graph.windows.net"
            Assert-MAADCondition ($null -eq (GetMAADValidGraphToken "aad-graph-token")) "Invalid Graph token should have been rejected."
        }
        "GetMAADExceptionMessage" {
            try {
                $inner_exception = New-Object System.Exception("inner failure")
                $outer_exception = New-Object System.Exception("outer failure", $inner_exception)
                throw $outer_exception
            }
            catch {
                $message = GetMAADExceptionMessage $_
                Assert-MAADCondition ($message -match "outer failure") "Outer exception message was missing."
                Assert-MAADCondition ($message -match "inner failure") "Inner exception message was missing."
            }
        }
        "GetMAADReconErrorMessage" {
            try {
                $inner_exception = New-Object System.Exception("recon inner failure")
                $outer_exception = New-Object System.Exception("recon outer failure", $inner_exception)
                throw $outer_exception
            }
            catch {
                $message = GetMAADReconErrorMessage $_
                Assert-MAADCondition ($message -match "recon outer failure") "Outer recon exception message was missing."
                Assert-MAADCondition ($message -match "recon inner failure") "Inner recon exception message was missing."
            }
        }
        "AddCredentials" {
            "{}" | Set-Content -Path $global:maad_credential_store -Force
            AddCredentials "password" "smoke-password" "user@example.com" "Password123!" "" "" ""
            AddCredentials "token" "smoke-token" "" "" "token-value" "https://graph.microsoft.com" "tenant-id"

            $stored_credentials = Get-Content $global:maad_credential_store | ConvertFrom-Json

            Assert-MAADCondition ($stored_credentials.PSObject.Properties.Name -contains "smoke-password") "Password credential was not saved."
            Assert-MAADCondition ($stored_credentials.PSObject.Properties.Name -contains "smoke-token") "Token credential was not saved."
            Assert-MAADCondition ($stored_credentials."smoke-token".audience -eq "https://graph.microsoft.com") "Token audience was not preserved."
        }
        "ShowMAADOutput" {
            $script:MAADStartedProcesses = @()
            $file_path = Join-Path $Workspace "Outputs/show-maad-output.txt"
            $output_list = @([pscustomobject]@{ DisplayName = "Example User"; UserPrincipalName = "user@example.com" })

            Show-MAADOutput -large_limit 5 -output_list $output_list -file_path $file_path

            Assert-MAADCondition (Test-Path $file_path) "Show-MAADOutput did not export the output file."
            Assert-MAADCondition ($script:MAADStartedProcesses.Count -ge 1) "Show-MAADOutput did not attempt to open the output view."
        }
        Default {
            throw "Unknown smoke test '$SmokeTest'."
        }
    }
}

function Write-MAADMarkdownReport {
    param(
        [array]$Results,
        [string[]]$Modes,
        [string]$Path,
        [string]$RepoRoot
    )

    $lines = @()
    $lines += "# MAAD Validation Report"
    $lines += ""
    $lines += "- Generated: $(Get-Date -Format u)"
    $lines += "- Modes: $($Modes -join ", ")"
    $lines += "- Repository: $RepoRoot"
    $lines += ""
    $lines += "## Summary"
    $lines += ""
    $lines += "| Status | Count |"
    $lines += "| --- | ---: |"

    foreach ($status in @("Pass", "Fail", "Manual", "Skipped")) {
        $count = @($Results | Where-Object { $_.OverallStatus -eq $status }).Count
        $lines += "| $status | $count |"
    }

    $lines += ""
    $lines += "## By Section"
    $lines += ""
    $lines += "| Section | Pass | Fail | Manual | Skipped |"
    $lines += "| --- | ---: | ---: | ---: | ---: |"

    foreach ($section_group in ($Results | Group-Object Section | Sort-Object Name)) {
        $section_results = @($section_group.Group)
        $pass_count = @($section_results | Where-Object { $_.OverallStatus -eq "Pass" }).Count
        $fail_count = @($section_results | Where-Object { $_.OverallStatus -eq "Fail" }).Count
        $manual_count = @($section_results | Where-Object { $_.OverallStatus -eq "Manual" }).Count
        $skipped_count = @($section_results | Where-Object { $_.OverallStatus -eq "Skipped" }).Count
        $lines += "| $(ConvertTo-MAADMarkdownCell $section_group.Name) | $pass_count | $fail_count | $manual_count | $skipped_count |"
    }

    $lines += ""
    $lines += "## Function Results"
    $lines += ""
    $lines += "| Function | Section | Validation | Parse | Load | Smoke | Live | Overall | Notes |"
    $lines += "| --- | --- | --- | --- | --- | --- | --- | --- | --- |"

    foreach ($result in ($Results | Sort-Object Section, Name)) {
        $notes = @()
        $function_name = ([char]96) + $result.Name + ([char]96)

        if ($result.MenuChoices.Count -gt 0) {
            $notes += "Menu: $($result.MenuChoices -join ", ")"
        }
        if ($result.Notes -notin $null, "") {
            $notes += $result.Notes
        }
        if ($result.Error -notin $null, "") {
            $notes += "Error: $($result.Error)"
        }

        $lines += "| $function_name | $(ConvertTo-MAADMarkdownCell $result.Section) | $(ConvertTo-MAADMarkdownCell $result.ValidationMode) | $(ConvertTo-MAADMarkdownCell $result.ParseStatus) | $(ConvertTo-MAADMarkdownCell $result.LoadStatus) | $(ConvertTo-MAADMarkdownCell $result.SmokeStatus) | $(ConvertTo-MAADMarkdownCell $result.LiveStatus) | $(ConvertTo-MAADMarkdownCell $result.OverallStatus) | $(ConvertTo-MAADMarkdownCell ($notes -join " ")) |"
    }

    $lines | Set-Content -Path $Path -Force
}

$modes = @($Mode | ForEach-Object { $_.Trim() } | Where-Object { $_ -notin "", $null })
$timestamp = Get-MAADTimestampString
$library_path = Join-Path $RepoRoot "Library"
$arsenal_path = Join-Path $library_path "MAAD_Attack_Arsenal.ps1"
$profile = & $ProfilePath
$inventory = Get-MAADFunctionInventory -LibraryPath $library_path
$workspace = New-MAADTestWorkspace
$original_location = Get-Location
$live_requested = $modes -contains "Live"
$live_config = $null

if ($live_requested) {
    $live_config = Get-MAADLiveConfig -ConfigPath $LiveConfigPath
}

try {
    Push-Location $workspace
    Reset-MAADHarnessState -Workspace $workspace

    $load_issues = @{}
    foreach ($file in Get-ChildItem -Path $library_path -Filter "*.ps1" | Sort-Object Name) {
        try {
            . $file.FullName
        }
        catch {
            $load_issues[$file.FullName] = $_.Exception.Message
        }
    }

    Install-MAADTestShims

    $menu_bindings = Get-MAADMenuBindings -ArsenalPath $arsenal_path
    $results = @()

    foreach ($function_info in ($inventory.Functions | Sort-Object Name)) {
        $metadata = Get-MAADFunctionMetadata -FunctionInfo $function_info -Profile $profile -Bindings $menu_bindings
        $function_command = Get-Command -Name $function_info.Name -CommandType Function -ErrorAction SilentlyContinue

        $load_status = "Pass"
        $error_messages = @()

        if ($load_issues.ContainsKey($function_info.FilePath)) {
            $load_status = "Fail"
            $error_messages += $load_issues[$function_info.FilePath]
        }
        elseif ($null -eq $function_command) {
            $load_status = "Fail"
            $error_messages += "Function was not loaded into the validation session."
        }

        $smoke_status = "NotConfigured"
        $live_status = "NotConfigured"

        if ($function_info.ParseStatus -eq "Fail" -or $load_status -eq "Fail") {
            $smoke_status = "Blocked"
            $live_status = "Blocked"
        }
        elseif ($metadata.ValidationMode -eq "Smoke" -and $metadata.SmokeTest -in $null, "") {
            $smoke_status = "Skipped"
        }
        elseif ($metadata.SmokeTest -notin $null, "" -and $modes -contains "Smoke") {
            try {
                Reset-MAADHarnessState -Workspace $workspace
                Invoke-MAADSmokeTest -SmokeTest $metadata.SmokeTest -Workspace $workspace
                $smoke_status = "Pass"
            }
            catch {
                $smoke_status = "Fail"
                $error_messages += $_.Exception.Message
            }
        }
        elseif ($metadata.SmokeTest -notin $null, "" -and $modes -notcontains "Smoke") {
            $smoke_status = "Skipped"
        }
        else {
            $smoke_status = "Manual"
        }

        if ($function_info.ParseStatus -eq "Fail" -or $load_status -eq "Fail") {
            $live_status = "Blocked"
        }
        elseif ($metadata.LiveTest -in $null, "") {
            $live_status = "NotConfigured"
        }
        elseif (-not $live_requested) {
            $live_status = "NotRequested"
        }
        else {
            $enabled_live_tests = @($live_config.EnabledLiveTests)

            if ($enabled_live_tests.Count -gt 0 -and $function_info.Name -notin $enabled_live_tests) {
                $live_status = "Skipped"
            }
            else {
                $missing_services = @(Test-MAADLiveRequirements -RequiredServices $metadata.RequiredServices)

                if ($missing_services.Count -gt 0) {
                    $live_status = "Skipped"
                    $error_messages += "Live prerequisites unavailable: $($missing_services -join ", ")."
                }
                else {
                    try {
                        Reset-MAADHarnessState -Workspace $workspace
                        Invoke-MAADLiveTest -LiveTest $metadata.LiveTest -Workspace $workspace -LiveConfig $live_config
                        $live_status = "Pass"
                    }
                    catch {
                        $live_status = "Fail"
                        $error_messages += $_.Exception.Message
                    }
                }
            }
        }

        $overall_status = "Manual"

        if ($function_info.ParseStatus -eq "Fail" -or $load_status -eq "Fail" -or $smoke_status -eq "Fail" -or $live_status -eq "Fail") {
            $overall_status = "Fail"
        }
        elseif ($metadata.ValidationMode -eq "Smoke" -and $smoke_status -eq "Pass") {
            $overall_status = "Pass"
        }
        elseif ($metadata.LiveTest -notin $null, "" -and $live_status -eq "Pass") {
            $overall_status = "Pass"
        }
        elseif ($metadata.ValidationMode -eq "Static" -and $function_info.ParseStatus -eq "Pass" -and $load_status -eq "Pass") {
            $overall_status = "Pass"
        }
        elseif ($smoke_status -eq "Skipped" -and $metadata.ValidationMode -eq "Smoke") {
            $overall_status = "Skipped"
        }
        elseif ($smoke_status -eq "Manual") {
            $overall_status = "Manual"
        }

        $results += [PSCustomObject]@{
            Name = $function_info.Name
            RelativePath = $function_info.RelativePath
            Section = $metadata.Section
            MenuChoices = $metadata.MenuChoices
            ValidationMode = $metadata.ValidationMode
            Risk = $metadata.Risk
            ParseStatus = $function_info.ParseStatus
            LoadStatus = $load_status
            SmokeStatus = $smoke_status
            LiveStatus = $live_status
            OverallStatus = $overall_status
            Notes = $metadata.Notes
            Error = ($error_messages | Where-Object { $_ -notin "", $null } | Select-Object -Unique) -join " | "
        }
    }
}
finally {
    Pop-Location
}

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

$json_path = Join-Path $OutputDirectory ("maad-validation-report-" + $timestamp + ".json")
$markdown_path = Join-Path $OutputDirectory ("maad-validation-report-" + $timestamp + ".md")

$report_payload = [PSCustomObject]@{
    GeneratedAt = (Get-Date).ToString("u")
    Modes = $modes
    Repository = $RepoRoot
    Workspace = $workspace
    Results = $results
}

$report_payload | ConvertTo-Json -Depth 8 | Set-Content -Path $json_path -Force
Write-MAADMarkdownReport -Results $results -Modes $modes -Path $markdown_path -RepoRoot $RepoRoot

$pass_count = @($results | Where-Object { $_.OverallStatus -eq "Pass" }).Count
$fail_count = @($results | Where-Object { $_.OverallStatus -eq "Fail" }).Count
$manual_count = @($results | Where-Object { $_.OverallStatus -eq "Manual" }).Count
$skipped_count = @($results | Where-Object { $_.OverallStatus -eq "Skipped" }).Count

Write-Host "MAAD validation complete."
Write-Host "Pass: $pass_count"
Write-Host "Fail: $fail_count"
Write-Host "Manual: $manual_count"
Write-Host "Skipped: $skipped_count"
Write-Host "Markdown report: $markdown_path"
Write-Host "JSON report: $json_path"

if ($FailOnFailure -and $fail_count -gt 0) {
    exit 1
}

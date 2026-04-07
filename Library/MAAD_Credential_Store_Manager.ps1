#Credential Store Manager
function GetMAADCredentialSummaryValue ($CredentialValue) {
    if ($null -eq $CredentialValue) {
        return ""
    }

    switch ($CredentialValue.type) {
        "token" {
            if ($CredentialValue.PSObject.Properties.Name -contains "audience" -and $CredentialValue.audience -notin $null, "") {
                return $CredentialValue.audience
            }

            return "Legacy token (missing audience)"
        }
        "application" {
            if ($CredentialValue.PSObject.Properties.Name -contains "username" -and $CredentialValue.username -notin $null, "") {
                return $CredentialValue.username
            }

            if ($CredentialValue.PSObject.Properties.Name -contains "application" -and $CredentialValue.application -notin $null, "") {
                return $CredentialValue.application
            }

            return ""
        }
        Default {
            return $CredentialValue.username
        }
    }
}

function TestMAADGraphAudience ([string]$Audience) {
    if ($Audience -in $null, "") {
        return $false
    }

    $normalized_audience = $Audience.Trim().TrimEnd("/").ToLower()
    $graph_audiences = @(
        "https://graph.microsoft.com",
        "https://graph.microsoft.us",
        "https://dod-graph.microsoft.us",
        "https://microsoftgraph.chinacloudapi.cn",
        "00000003-0000-0000-c000-000000000000"
    )

    return $normalized_audience -in $graph_audiences
}

function GetMAADTokenValidationMessage ($CredentialValue) {
    if ($null -eq $CredentialValue) {
        return "Stored token is invalid."
    }

    if ($CredentialValue.PSObject.Properties.Name -notcontains "audience" -or $CredentialValue.audience -in $null, "") {
        return "Stored token is using the retired Azure AD Graph credential format. Re-add it with a Microsoft Graph audience."
    }

    if (-not (TestMAADGraphAudience $CredentialValue.audience)) {
        return "Stored token audience is not Microsoft Graph. Re-add it with a Microsoft Graph audience such as https://graph.microsoft.com."
    }

    return $null
}

function RetrieveCredentials{
    $credential_file_path = $global:maad_credential_store

    #Function to retrieve credentials in MAAD
    try {
        $available_credentials = Get-Content $credential_file_path | ConvertFrom-Json
    }
    catch {
        MAADWriteError "MCS -> Can't Access Credential Store"
        break
    }

    #Check if credential store is empty
    if ($null -eq $available_credentials) {
        MAADWriteError "MCS -> No Credentials Found"
        MAADWriteInfo "MCS -> Use 'ADD CREDS' to Save Credentials"
    }
    else {
        MAADWriteProcess "MCS -> Listing Credentials"

        $all_credentials = $available_credentials.PSObject.Properties

        #Display as table
        $all_credentials | Format-Table -Property @{Label="CID";Expression={$_.Name}}, @{Label="Cred Type";Expression={$_.Value.type}}, @{Label="Username / Audience";Expression={GetMAADCredentialSummaryValue $_.Value}} -Wrap
    }

    MAADPause
}

function AddCredentials ($new_cred_type, $name, $new_username, $new_password, $new_token, $new_token_audience, $new_token_tenant_id){

    #Sanitize user input - trim any leading & trailing spaces
    $new_cred_type = [string]$new_cred_type
    $name = [string]$name
    $new_username = [string]$new_username
    $new_password = [string]$new_password
    $new_token = [string]$new_token
    $new_token_audience = [string]$new_token_audience
    $new_token_tenant_id = [string]$new_token_tenant_id

    $new_cred_type = $new_cred_type.Trim()
    $name = $name.Trim()
    $new_username = $new_username.Trim()
    $new_password = $new_password.Trim()
    $new_token = $new_token.Trim()
    $new_token_audience = $new_token_audience.Trim()
    $new_token_tenant_id = $new_token_tenant_id.Trim()

    $credential_file_path = $global:maad_credential_store

    #Load latest stored credentials to global:all_credentials
    try {
        $all_credentials = Get-Content $credential_file_path | ConvertFrom-Json
    }
    catch {
        MAADWriteError "MCS -> Can't Access Credential Store"
        break
    }

    switch ($new_cred_type) {
        "password" {
            $new_credential_value = [PSCustomObject]@{
                type = $new_cred_type
                username = $new_username
                password = $new_password
            }
        }
        "token" {
            $new_credential_value = [PSCustomObject]@{
                type = $new_cred_type
                token = $new_token
                audience = $new_token_audience
                tenantId = $new_token_tenant_id
            }
        }
        "application" {
            $new_credential_value = [PSCustomObject]@{
                type = $new_cred_type
                username = $new_username
                application = $new_username
                password = $new_password
            }
        }
        Default {
            MAADWriteError "MCS -> Invalid Credential Type"
            break
        }
    }
    
    if ($null -ne $all_credentials){
        $all_credentials | Add-Member -MemberType NoteProperty -Name $name -Value $new_credential_value
    }
    else {
        $all_credentials = ([PSCustomObject]@{
            $name = $new_credential_value
        })
    }

    #Save new creds to file
    try {
        $all_credentials_json = $all_credentials | ConvertTo-Json
        $all_credentials_json | Set-Content -Path $credential_file_path -Force
        MAADWriteProcess "MCS -> Credential Stored in MAAD Credential Store"
    }
    catch {
        MAADWriteError "MCS -> Failed to Add Credentials"
    }
}

function UseCredential {
    param (
        [switch]$AllowTokenOnly
    )
    ###This function sets the global variables global:current_username + global:current_password or global:current_access_token to use with modules that require creds for authentication

    #Setting all variables as $null
    $global:current_username = $null
    $global:current_password = $null
    $global:current_access_token = $null
    $global:current_access_token_audience = $null
    $global:current_access_token_tenant_id = $null
    $global:current_credentials = $null
    Write-Host ""

    #Checking if saved credentials are available in credentials.json
    try {
        $credential_file_path = $global:maad_credential_store
        $available_credentials = Get-Content $credential_file_path | ConvertFrom-Json
    }
    catch {
        MAADWriteError "MCS -> Can't Access Credential Store"
    }

    if ($null -ne $available_credentials){
        MAADWriteProcess "MCS -> Listing Credentials"
        
        #Display available credentials
        $all_credentials = $available_credentials.PSObject.Properties
        $all_credentials | Format-Table -Property @{Label="CID";Expression={$_.Name}}, @{Label="Cred Type";Expression={$_.Value.type}}, @{Label="Username / Audience";Expression={GetMAADCredentialSummaryValue $_.Value}} -Wrap

        do{
            $retrived_creds = $false
            MAADWriteInfo "Select CID to choose credential"
            MAADWriteInfo "Enter [X] to continue without a saved credential"
            $credential_choice = Read-Host -Prompt "`n[?] Enter Credential (CID / x)"
            Write-Host ""
            if ($credential_choice.Trim().ToLower() -eq "x") {
                break
            }
            foreach ($credential in $available_credentials.PSObject.Properties){
                if ($credential.Name -eq $credential_choice){
                    if ($credential.Value.type -eq "password"){
                        $global:current_username  = $credential.Value.username
                        $global:current_password = $credential.Value.password
                        $retrived_creds = $true
                        break
                    }
                    elseif ($credential.Value.type -eq "token"){
                        $token_validation_message = GetMAADTokenValidationMessage $credential.Value

                        if ($null -ne $token_validation_message) {
                            MAADWriteError $token_validation_message
                            MAADWriteInfo "Add a new token credential that targets Microsoft Graph and includes its audience."
                        }
                        else {
                            $global:current_access_token = $credential.Value.token
                            $global:current_access_token_audience = $credential.Value.audience
                            if ($credential.Value.PSObject.Properties.Name -contains "tenantId") {
                                $global:current_access_token_tenant_id = $credential.Value.tenantId
                            }
                            $retrived_creds = $true
                        }
                        break
                    }
                    elseif ($credential.Value.type -eq "application") {
                        $global:current_username  = GetMAADCredentialSummaryValue $credential.Value
                        $global:current_password = $credential.Value.password
                        $retrived_creds = $true
                        break
                    }
                }
            }
        }while($retrived_creds -eq $false)
    }

    if ($AllowTokenOnly) {
        if ($global:current_access_token -notin "", $null) {
            MAADWriteProcess "MCS -> Retrieved Microsoft Graph token"
        }
        else {
            MAADWriteInfo "Entra access will continue with interactive authentication"
        }
        return
    }

    if ($global:current_access_token -notin "", $null -and ($global:current_username -in $null, "" -or $global:current_password -in "", $null)) {
        MAADWriteInfo "Token selected for Entra access. Enter credentials for services that still require username/password authentication."
    }

    #Get credentials if not found in config file
    if ($global:current_username -in $null,"" -or $global:current_password -in "",$null) {
        MAADWriteProcess "X -> Manual credential input"
        $global:current_username = Read-Host -Prompt "`n[?] Enter Username"
        $global:current_secure_pass = Read-Host -Prompt "`n[?] Enter Password [$global:current_username]" -AsSecureString 
        Write-Host ""
        $global:current_credentials = New-Object System.Management.Automation.PSCredential -ArgumentList ($global:current_username, $global:current_secure_pass)
        MAADWriteInfo "MCS -> Use 'ADD CREDS' to Save Credentials"
    }
    else {
        MAADWriteProcess "MCS -> Retrieved Credential"
        $global:current_secure_pass = ConvertTo-SecureString $global:current_password -AsPlainText -Force
        $global:current_credentials = New-Object System.Management.Automation.PSCredential -ArgumentList ($global:current_username, $global:current_secure_pass)
    }
}

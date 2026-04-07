function EstablishAccess ($target_service){
    Write-MAADLog "start" "EstablishAccess"

    if ($target_service -in "entra", "azure_ad") {
        UseCredential -AllowTokenOnly
    }
    else {
        UseCredential
    }
    
    switch ($target_service) {
        "entra"{AccessEntra $global:current_access_token}
        "azure_ad"{AccessEntra $global:current_access_token}
        "az"{AccessAzAccount $global:current_username $global:current_credentials $global:current_access_token}
        "exchange_online"{AccessExchangeOnline $global:current_username $global:current_credentials $global:current_access_token}
        "teams"{AccessTeams $global:current_username $global:current_credentials $global:current_access_token}
        "sharepoint_site"{AccessSharepoint $global:current_username $global:current_credentials $global:current_access_token}
        "sharepoint_admin_center"{AccessSharepointAdmin $global:current_username $global:current_credentials $global:current_access_token}
        "ediscovery"{ConnectEdiscovery $global:current_credentials}
        Default {
            AccessEntra $global:current_access_token
            AccessAzAccount $global:current_username $global:current_credentials $global:current_access_token
            AccessTeams $global:current_username $global:current_credentials $global:current_access_token
            AccessExchangeOnline $global:current_username $global:current_credentials $global:current_access_token
            AccessSharepoint $global:current_username $global:current_credentials $global:current_access_token
            AccessSharepointAdmin $global:current_username $global:current_credentials $global:current_access_token
            ConnectEdiscovery $global:current_credentials
        
            #Display access info after establishing connection
            MAADPause
            AccessInfo
        }
    }
}

function GetMAADEntraScopes {
    return @(
        "Application.Read.All",
        "Application.ReadWrite.All",
        "Directory.AccessAsUser.All",
        "Directory.Read.All",
        "Group.Read.All",
        "Group.ReadWrite.All",
        "User.Invite.All",
        "Policy.Read.All",
        "Policy.ReadWrite.AuthenticationMethod",
        "Policy.ReadWrite.ConditionalAccess",
        "RoleManagement.Read.Directory",
        "RoleManagement.ReadWrite.Directory",
        "User.Read.All",
        "User.ReadWrite.All"
    )
}

function GetMAADValidGraphToken ($AccessToken) {
    if ($AccessToken -in "", $null) {
        return $null
    }

    if (-not (TestMAADGraphAudience $global:current_access_token_audience)) {
        MAADWriteError "Stored access token is not a Microsoft Graph token"
        MAADWriteInfo "Re-add the token with a Microsoft Graph audience such as https://graph.microsoft.com"
        return $null
    }

    return $AccessToken
}

function GetMAADExceptionMessage ($ErrorRecord) {
    if ($null -eq $ErrorRecord) {
        return "Unknown error"
    }

    $messages = @()
    $current_exception = $ErrorRecord.Exception

    while ($current_exception -ne $null) {
        if ($current_exception.Message -notin "", $null) {
            if ($messages -notcontains $current_exception.Message) {
                $messages += $current_exception.Message
            }
        }

        $current_exception = $current_exception.InnerException
    }

    if ($messages.Count -eq 0) {
        return $ErrorRecord.ToString()
    }

    return ($messages -join " | ")
}

function AccessEntra{
    param (
        $AccessToken
    )

    $graph_access_token = GetMAADValidGraphToken $AccessToken
    if ($graph_access_token -notin "", $null) {
        try {
            $secure_access_token = ConvertTo-SecureString -String $graph_access_token -AsPlainText -Force
            Connect-Entra -AccessToken $secure_access_token -NoWelcome -ErrorAction Stop | Out-Null
            MAADWriteSuccess "Established access -> Entra"
            return
        }
        catch {
            MAADWriteError "Token authentication failed"
            MAADWriteError (GetMAADExceptionMessage $_)
            MAADWriteInfo "Stored access tokens must target Microsoft Graph and may need to be refreshed when they expire"
        }
    }

    MAADWriteInfo "Entra access now uses Microsoft Entra PowerShell with Microsoft Graph permissions"
    MAADWriteProcess "Launching interactive Entra authentication window to continue"

    try {
        Connect-Entra -Scopes (GetMAADEntraScopes) -NoWelcome -ErrorAction Stop | Out-Null
        MAADWriteSuccess "Established access -> Entra"
    }
    catch {
        MAADWriteError (GetMAADExceptionMessage $_)
        MAADWriteInfo "Browser-based Entra authentication was not available. Switching to device code authentication"
        try {
            Connect-Entra -UseDeviceCode -Scopes (GetMAADEntraScopes) -NoWelcome -ErrorAction Stop | Out-Null
            MAADWriteSuccess "Established access -> Entra"
        }
        catch {
            MAADWriteError "Failed to establish access -> Entra"
            MAADWriteError (GetMAADExceptionMessage $_)
        }
    }
}

function AccessAzAccount {
    param (
        [Parameter(Mandatory)]$AdminUsername,
        [Parameter(Mandatory)][PSCredential] $AdminCredential,
        $AccessToken
    )
    ###Connect AzAccount
    if ($AccessToken -notin "",$null ) {
        try {
        #Attempt token authentication  
        Connect-AzAccount -AccessToken $AccessToken -AccountId $AdminUsername -ErrorAction Stop | Out-Null
        MAADWriteSuccess "Established access -> Az"
        }
        catch {
            MAADWriteError "Token authentication failed"
            MAADWriteProcess "Attempting basic authentication"
            try {
                #Attempt basic authentication
                Connect-AzAccount -Credential $AdminCredential -WarningAction SilentlyContinue -ErrorAction Stop| Out-Null 
                MAADWriteSuccess "Established access -> Az"
            }
            catch [Microsoft.Azure.Commands.Common.Exceptions.AzPSAuthenticationFailedException]{
                #Check if account has MFA requirements for authentication
                if ($null -ne (Select-String -Pattern "multi-factor authentication" -InputObject $_.Exception.Message)) {
                    MAADWriteInfo "MFA required for authentication"
                    MAADWriteProcess "Launching interactive authentication window to continue"
                    try {
                        #Attempt interactive authentication  
                        Connect-AzAccount -ErrorAction Stop | Out-Null
                        MAADWriteSuccess "Established access -> Az"
                    }
                    catch {
                        MAADWriteError "Invalid credentials"
                    }
                }
                if ($null -ne (Select-String -Pattern "invalid username or password" -InputObject $_.Exception.Message)) {
                    MAADWriteError "Invalid credentials"
                }
            }
            catch [System.Exception]{
                if ($null -ne (Select-String -Pattern "multi-factor authentication" -InputObject $_.Exception.InnerException) -or $null -ne (Select-String -Pattern "multi-factor authentication" -InputObject $_.Exception)) {
                    MAADWriteInfo "MFA required for authentication"
                    MAADWriteProcess "Launching interactive authentication window to continue"
                    try {
                        #Attempt interactive authentication  
                        Connect-AzAccount -ErrorAction Stop | Out-Null
                        MAADWriteSuccess "Established access -> Az"
                    }
                    catch {
                        MAADWriteError "Invalid credentials"
                    }
                }
            }
            catch {
                MAADWriteError "Failed to establish access -> Az"
            }
        }
    }
    else {
        try {
            #Attempt basic authentication
            Connect-AzAccount -Credential $AdminCredential -WarningAction SilentlyContinue -ErrorAction Stop| Out-Null 
            MAADWriteSuccess "Established access -> Az"
        }
        catch [Microsoft.Azure.Commands.Common.Exceptions.AzPSAuthenticationFailedException]{
            #Check if account has MFA requirements for authentication
            if ($null -ne (Select-String -Pattern "multi-factor authentication" -InputObject $_.Exception.Message)) {
                MAADWriteInfo "MFA required for authentication"
                MAADWriteProcess "Launching interactive authentication window to continue"
                try {
                    #Attempt interactive authentication  
                    Connect-AzAccount -ErrorAction Stop | Out-Null
                    MAADWriteSuccess "Established access -> Az"
                }
                catch {
                    MAADWriteError "Invalid credentials"
                }
            }
            if ($null -ne (Select-String -Pattern "invalid username or password" -InputObject $_.Exception.Message)) {
                MAADWriteError "Invalid credentials"
            }
        }
        catch [System.Exception]{
            if ($null -ne (Select-String -Pattern "multi-factor authentication" -InputObject $_.Exception.InnerException) -or $null -ne (Select-String -Pattern "multi-factor authentication" -InputObject $_.Exception)) {
                MAADWriteInfo "MFA required for authentication"
                MAADWriteProcess "Launching interactive authentication window to continue"
                try {
                    #Attempt interactive authentication  
                    Connect-AzAccount -ErrorAction Stop | Out-Null
                    MAADWriteSuccess "Established access -> Az"
                }
                catch {
                    MAADWriteError "Invalid credentials"
                }
            }
        }
        catch {
            $_
            MAADWriteError "Failed to establish access -> Az"
        }
    }
}

function AccessTeams {
    param (
        [Parameter(Mandatory)]$AdminUsername,
        [Parameter(Mandatory)][PSCredential] $AdminCredential,
        $AccessToken
    )
    ###Connect Teams
    if ($AccessToken -notin "",$null ) {
        try {
        #Attempt token authentication  
        Connect-MicrosoftTeams -AadAccessToken $AccessToken -AccountId $AdminUsername -ErrorAction Stop | Out-Null
        MAADWriteSuccess "Established access -> Teams"
        }
        catch {
            MAADWriteError "Token authentication failed"
            MAADWriteProcess "Attempting basic authentication"
            try {
                #Attempt basic authentication
                Connect-MicrosoftTeams -Credential $AdminCredential -WarningAction SilentlyContinue -ErrorAction Stop| Out-Null 
                MAADWriteSuccess "Established access -> Teams"
            }
            catch [System.AggregateException]{
                #Check if account has MFA requirements for authentication
                if ($null -ne (Select-String -Pattern "multi-factor authentication" -InputObject $_.Exception.InnerException)) {
                    MAADWriteInfo "MFA required for authentication"
                    MAADWriteProcess "Launching interactive authentication window to continue"
                    try {
                        #Attempt interactive authentication  
                        Connect-MicrosoftTeams -ErrorAction Stop | Out-Null
                        MAADWriteSuccess "Established access -> Teams"
                    }
                    catch {
                        MAADWriteError "Invalid credentials"
                    }
                }
                if ($null -ne (Select-String -Pattern "invalid username or password" -InputObject $_.Exception.Message)) {
                    MAADWriteError "Invalid credentials"
                    $null = Read-Host "Exiting"
                    exit
                }
            }
            catch [System.Exception]{
                if ($null -ne (Select-String -Pattern "multi-factor authentication" -InputObject $_.Exception.InnerException) -or $null -ne (Select-String -Pattern "multi-factor authentication" -InputObject $_.Exception)) {
                    MAADWriteInfo "MFA required for authentication"
                    MAADWriteProcess "Launching interactive authentication window to continue"
                    try {
                        #Attempt interactive authentication  
                        Connect-MicrosoftTeams -ErrorAction Stop | Out-Null
                        MAADWriteSuccess "Established access -> Teams"
                    }
                    catch {
                        MAADWriteError "Invalid credentials"
                    }
                }
            }
            catch {
                MAADWriteError "Failed to establish access -> Teams"
            }
        }
    }
    else {
        try {
            #Attempt basic authentication
            Connect-MicrosoftTeams -Credential $AdminCredential -WarningAction SilentlyContinue -ErrorAction Stop| Out-Null 
            MAADWriteSuccess "Established access -> Teams"  
        }
        catch [System.AggregateException]{
            #Check if account has MFA requirements for authentication
            if ($null -ne (Select-String -Pattern "multi-factor authentication" -InputObject $_.Exception.InnerException)) {
                MAADWriteInfo "MFA required for authentication"
                MAADWriteProcess "Launching interactive authentication window to continue"
                try {
                    #Attempt interactive authentication  
                    Connect-MicrosoftTeams -ErrorAction Stop | Out-Null
                    MAADWriteSuccess "Established access -> Teams"
                }
                catch {
                    MAADWriteError "Invalid credentials"
                }
            }
            if ($null -ne (Select-String -Pattern "invalid username or password" -InputObject $_.Exception.Message)) {
                MAADWriteError "Invalid credentials"
                $null = Read-Host "Exiting"
                exit
            }
        }
        catch [System.Exception]{
            if ($null -ne (Select-String -Pattern "multi-factor authentication" -InputObject $_.Exception.InnerException) -or $null -ne (Select-String -Pattern "multi-factor authentication" -InputObject $_.Exception)) {
                MAADWriteInfo "MFA required for authentication"
                MAADWriteProcess "Launching interactive authentication window to continue"
                try {
                    #Attempt interactive authentication  
                    Connect-MicrosoftTeams -ErrorAction Stop | Out-Null
                    MAADWriteSuccess "Established access -> Teams"
                }
                catch {
                    MAADWriteError "Invalid credentials"
                }
            }
        }
        catch {
            MAADWriteError "Failed to establish access -> Teams"
        }       
    }
}

function AccessExchangeOnline {
    param (
        [Parameter(Mandatory)]$AdminUsername,
        [Parameter(Mandatory)][PSCredential] $AdminCredential,
        $AccessToken
    )
    ###Connect ExchangeOnline
    if ($AccessToken -notin "",$null ) {
        try {
        #Attempt token authentication  
        Connect-ExchangeOnline -AadAccessToken $AccessToken -AccountId $AdminUsername -ShowBanner:$false -ErrorAction Stop | Out-Null
        MAADWriteSuccess "Established access -> ExchangeOnline"
        }
        catch {
            MAADWriteError "Token authentication failed"
            MAADWriteProcess "Attempting basic authentication"
            try {
                #Attempt basic authentication
                Connect-ExchangeOnline -Credential $AdminCredential -WarningAction SilentlyContinue -ShowBanner:$false -ErrorAction Stop| Out-Null 
                MAADWriteSuccess "Established access -> ExchangeOnline"
            }
            catch [Microsoft.Identity.Client.MsalUiRequiredException]{
                #Check if account has MFA requirements for authentication
                if ($null -ne (Select-String -Pattern "multi-factor authentication" -InputObject $_.Exception.Message)) {
                    MAADWriteInfo "MFA required for authentication"
                    MAADWriteProcess "Launching interactive authentication window to continue"
                    try {
                        #Attempt interactive authentication  
                        Connect-ExchangeOnline -ErrorAction Stop -ShowBanner:$false | Out-Null
                        MAADWriteSuccess "Established access -> ExchangeOnline"
                    }
                    catch {
                        MAADWriteError "Invalid credentials"
                    }
                }
                if ($null -ne (Select-String -Pattern "invalid username or password" -InputObject $_.Exception.Message)) {
                    MAADWriteError "Invalid credentials"
                }
            }
            catch [System.Exception]{
                if ($null -ne (Select-String -Pattern "multi-factor authentication" -InputObject $_.Exception.InnerException) -or $null -ne (Select-String -Pattern "multi-factor authentication" -InputObject $_.Exception)) {
                    MAADWriteInfo "MFA required for authentication"
                    MAADWriteProcess "Launching interactive authentication window to continue"
                    try {
                        #Attempt interactive authentication  
                        Connect-ExchangeOnline -ErrorAction Stop -ShowBanner:$false | Out-Null
                        MAADWriteSuccess "Established access -> ExchangeOnline"
                    }
                    catch {
                        MAADWriteError "Invalid credentials"
                    }
                }
            }
            catch {
                MAADWriteError "Failed to establish access -> ExchangeOnline"
            }
        }
    }
    else {
        try {
            #Attempt basic authentication
            Connect-ExchangeOnline -Credential $AdminCredential -WarningAction SilentlyContinue -ShowBanner:$false -ErrorAction Stop | Out-Null 
            MAADWriteSuccess "Established access -> ExchangeOnline"  
        }
        catch [Microsoft.Identity.Client.MsalUiRequiredException]{
            #Check if account has MFA requirements for authentication
            if ($null -ne (Select-String -Pattern "multi-factor authentication" -InputObject $_.Exception.Message)) {
                MAADWriteInfo "MFA required for authentication"
                MAADWriteProcess "Launching interactive authentication window to continue"
                try {
                    #Attempt interactive authentication  
                    Connect-ExchangeOnline -ErrorAction Stop -ShowBanner:$false | Out-Null
                    MAADWriteSuccess "Established access -> ExchangeOnline"
                }
                catch {
                    MAADWriteError "Invalid credentials"
                }
            }
            if ($null -ne (Select-String -Pattern "invalid username or password" -InputObject $_.Exception.Message)) {
                MAADWriteError "Invalid credentials"
            }
        }
        catch [System.Exception]{
            if ($null -ne (Select-String -Pattern "multi-factor authentication" -InputObject $_.Exception.InnerException) -or $null -ne (Select-String -Pattern "multi-factor authentication" -InputObject $_.Exception)) {
                MAADWriteInfo "MFA required for authentication"
                MAADWriteProcess "Launching interactive authentication window to continue"
                try {
                    #Attempt interactive authentication  
                    Connect-ExchangeOnline -ErrorAction Stop -ShowBanner:$false | Out-Null
                    MAADWriteSuccess "Established access -> ExchangeOnline"
                }
                catch {
                    MAADWriteError "Invalid credentials"
                }
            }
        }
        catch {
            MAADWriteError "Failed to establish access -> ExchangeOnline"
        }
    }
}

function AccessMsol {
    param (
        $AdminUsername,
        [PSCredential] $AdminCredential,
        $AccessToken
    )
    MAADWriteInfo "MSOnline access has been retired. Reusing the Entra session instead."
    AccessEntra $AccessToken
}

function AccessSharepoint {
    param (
        [Parameter(Mandatory)]$AdminUsername,
        [Parameter(Mandatory)][PSCredential] $AdminCredential,
        $AccessToken
    )
    ###Connect Sharepoint
    MAADWriteProcess "Attempting access to SharePoint"

    #Find the sharepoint URL
    if ($sharepoint_url -notin "No","no","N","n"){
        try {
            $tenant = $AdminUsername.Split("@")[1]
            $tenant_intel = Invoke-AADIntReconAsOutsider -DomainName $tenant

            foreach ($domain in $tenant_intel){
                if ($domain.Name -match ".onmicrosoft.com" -and $domain.Name -notmatch ".mail.onmicrosoft.com"){
                    $global:sharepoint_tenant = $domain.Name.Split(".")[0]
                }
            }
            $sharepoint_url = "https://$global:sharepoint_tenant.sharepoint.com"
            MAADWriteProcess "SharePoint url -> $sharepoint_url"
        }
        catch {
            # Do nothing
            MAADWriteError "Failed to automatically discover SharePoint url"
        }
    }
    if ($sharepoint_url -eq $null){
        $sharepoint_url = Read-Host "`n[?] Manually enter SharePoint URL (https://tenant.sharepoint.com)"
    }
    if ($sharepoint_url -in $null,""){
        MAADWriteError "Sharepoint URL not found"
        break
    }
    
    if ($AccessToken -notin "",$null ) {
        #Set environment variable to disable PNP module version check 
        $env:PNPPOWERSHELL_UPDATECHECK= $false
        
        try {
        #Attempt token authentication  
        Connect-PnPOnline -Url $sharepoint_url -AccessToken $AccessToken -ErrorAction Stop | Out-Null
        MAADWriteSuccess "Established access -> SharePoint"
        }
        catch {
            MAADWriteError "Token authentication failed"
            MAADWriteProcess "Attempting basic authentication"
            try {
                #Attempt basic authentication
                Connect-PnPOnline -Url $sharepoint_url -Credentials $AdminCredential -ErrorAction Stop
                MAADWriteSuccess "Established access -> SharePoint"
            }
            catch [Microsoft.Identity.Client.MsalUiRequiredException]{
                #Check if account has MFA requirements for authentication
                if ($null -ne (Select-String -Pattern "multi-factor authentication" -InputObject $_.Exception.Message)) {
                    MAADWriteInfo "MFA required for authentication"
                    MAADWriteProcess "Launching interactive authentication window to continue"
                    try {
                        #Attempt interactive authentication  
                        Connect-PnPOnline -Url $sharepoint_url -Interactive -ErrorAction Stop | Out-Null
                        MAADWriteSuccess "Established access -> SharePoint"
                    }
                    catch {
                        MAADWriteError "Invalid credentials"
                    }
                }
                if ($null -ne (Select-String -Pattern "invalid username or password" -InputObject $_.Exception.Message)) {
                    MAADWriteError "Invalid credentials"
                }
            }
            catch [System.Exception]{
                if ($null -ne (Select-String -Pattern "multi-factor authentication" -InputObject $_.Exception.InnerException) -or $null -ne (Select-String -Pattern "multi-factor authentication" -InputObject $_.Exception)) {
                    MAADWriteInfo "MFA required for authentication"
                    MAADWriteProcess "Launching interactive authentication window to continue"
                    try {
                        #Attempt interactive authentication  
                        Connect-PnPOnline -Url $sharepoint_url -Interactive -ErrorAction Stop | Out-Null
                        MAADWriteSuccess "Established access -> SharePoint"
                    }
                    catch {
                        MAADWriteError "Invalid credentials"
                    }
                }
            }
            catch {
                MAADWriteError "Failed to establish access -> SharePoint"
            }
        }
    }
    else {
        #Set environment variable to disable PNP module version check 
        $env:PNPPOWERSHELL_UPDATECHECK= $false

        try {
            #Attempt basic authentication
            Connect-PnPOnline -Url $sharepoint_url -Credentials $AdminCredential -ErrorAction Stop
            MAADWriteSuccess "Established access -> SharePoint"
        }
        catch [Microsoft.Identity.Client.MsalUiRequiredException]{
            #Check if account has MFA requirements for authentication
            if ($null -ne (Select-String -Pattern "multi-factor authentication" -InputObject $_.Exception.Message)) {
                MAADWriteInfo "MFA required for authentication"
                MAADWriteProcess "Launching interactive authentication window to continue"
                try {
                    #Attempt interactive authentication  
                    Connect-PnPOnline -Url $sharepoint_url -Interactive -ErrorAction Stop | Out-Null
                    MAADWriteSuccess "Established access -> SharePoint"
                }
                catch {
                    MAADWriteError "Invalid credentials"
                }
            }
            if ($null -ne (Select-String -Pattern "invalid username or password" -InputObject $_.Exception.Message)) {
                MAADWriteError "Invalid credentials"
            }
            else {
                MAADWriteError "Failed to access SharePoint"
                #Accessing sharepoint via powershell requires explicit consent to allow access to sharepoint. Copy paste this URL in your browser and approve the prompt!
                #URL: https://login.microsoftonline.com/$tenant/adminconsent?client_id=$client_id
                MAADWriteProcess "Accessing SharePoint via powershell requires explicit consent to allow access to SharePoint"
                MAADWriteInfo "Launching authorization page in browser"
                MAADWriteInfo "Consent to the terms and choose authorize, then return here"
                $null = Read-Host "`n[?] Press [enter] to launch the browser authorization page" 
                Register-PnPManagementShellAccess
                MAADWriteInfo "If the browser does not launch automatically. Visit authorization page : https://login.microsoftonline.com/$tenant/adminconsent?client_id=9bc3ab49-b65d-410a-85ad-de819febfddc"
                
                $user_prompt = Read-Host "`n[?] Once you have completed the authorization in browser press [enter] to continue or type [exit] to quit the module" 
                
                if ($user_prompt.ToLower() -eq "exit") {
                    break
                }
            }
        }
        catch [System.Exception]{
            if ($null -ne (Select-String -Pattern "multi-factor authentication" -InputObject $_.Exception.InnerException) -or $null -ne (Select-String -Pattern "multi-factor authentication" -InputObject $_.Exception)) {
                MAADWriteInfo "MFA required for authentication"
                MAADWriteProcess "Launching interactive authentication window to continue"
                try {
                    #Attempt interactive authentication  
                    Connect-PnPOnline -Url $sharepoint_url -Interactive -ErrorAction Stop | Out-Null
                    MAADWriteSuccess "Established access -> SharePoint"
                }
                catch {
                    MAADWriteError "Invalid credentials"
                }
            }
        }
        catch {
            MAADWriteError "Failed to establish access -> SharePoint"
        }
    }
}


function AccessSharepointAdmin {
    param (
        [Parameter(Mandatory)]$AdminUsername,
        [Parameter(Mandatory)][PSCredential] $AdminCredential,
        $AccessToken
    )

    #Find the sharepoint URL
    if ($sharepoint_admin_url -eq $null){
        try {
            MAADWriteProcess "Attempting to discover target SharePoint Admin URL"
            $tenant = $AdminUsername.Split("@")[1]
            $tenant_intel = Invoke-AADIntReconAsOutsider -DomainName $tenant

            foreach ($domain in $tenant_intel){
                if ($domain.Name -match ".onmicrosoft.com" -and $domain.Name -notmatch ".mail.onmicrosoft.com"){
                    $global:sharepoint_tenant = $domain.Name.Split(".")[0]
                }
            }
            $sharepoint_url = "https://$global:sharepoint_tenant.sharepoint.com"
            MAADWriteProcess "SharePoint url -> $sharepoint_url"
            $sharepoint_admin_url = "https://$global:sharepoint_tenant-admin.sharepoint.com"
            MAADWriteProcess "SharePoint admin url -> $sharepoint_admin_url"
        }
        catch {
            #Do nothing
            MAADWriteError "Failed to automatically discover SharePoint Admin URL"
        }
    }
    if ($sharepoint_admin_url -eq $null){
        $sharepoint_admin_url = Read-Host "`n[?] Manually enter SharePoint Admin URL (https://tenant-admin.sharepoint.com)"
    }
    if ($sharepoint_admin_url -in $null,""){
        MAADWriteError "Sharepoint Admin URL not found"
        break
    }

    ###Connect SharePoint Online Administration Center 
    if ($AccessToken -notin "",$null) {
        try {
        #Attempt token authentication  
        Connect-SPOService -Url $sharepoint_admin_url -AccessToken $AccessToken -ErrorAction Stop | Out-Null
        #SPOService currently does not support token auth so this is intended to fail and rollover to other auth methods
        MAADWriteSuccess "Established access -> SharePoint Online Administration Center"
        }
        catch {
            MAADWriteError "Token authentication failed"
            MAADWriteProcess "Attempting basic authentication"
            try {
                #Attempt basic authentication
                Connect-SPOService -Url $sharepoint_admin_url -Credential $AdminCredential -ErrorAction Stop
                MAADWriteSuccess "Established access -> SharePoint Online Administration Center"
            }
            catch [Microsoft.Online.SharePoint.PowerShell.AuthenticationException]{
                #Check if account has MFA requirements for authentication
                if ($null -ne (Select-String -Pattern "multi-factor authentication" -InputObject $_.Exception.Message)) {
                    MAADWriteInfo "MFA required for authentication"
                    MAADWriteProcess "Launching interactive authentication window to continue"
                    try {
                        #Attempt interactive authentication  
                        Connect-SPOService -Url $sharepoint_admin_url -ErrorAction Stop | Out-Null
                        MAADWriteSuccess "Established access -> SharePoint Online Administration Center"
                    }
                    catch {
                        MAADWriteError "Invalid credentials"
                    }
                }
                if ($null -ne (Select-String -Pattern "invalid username or password" -InputObject $_.Exception.Message)) {
                    MAADWriteError "Invalid credentials"
                }
            }
            catch {
                MAADWriteError "Failed to establish access -> SharePoint Online Administration Center"
            }
        }
    }
    else {
        try {
            #Attempt basic authentication
            Connect-SPOService -Url $sharepoint_admin_url -Credential $AdminCredential -ErrorAction Stop
            MAADWriteSuccess "Established access -> SharePoint Online Administration Center" 
        }
        catch [Microsoft.Online.SharePoint.PowerShell.AuthenticationException]{
            #Check if account has MFA requirements for authentication
            if ($null -ne (Select-String -Pattern "multi-factor authentication" -InputObject $_.Exception.Message)) {
                MAADWriteInfo "MFA required for authentication"
                MAADWriteProcess "Launching interactive authentication window to continue"
                try {
                    #Attempt interactive authentication  
                    Connect-SPOService -Url $sharepoint_admin_url -ErrorAction Stop | Out-Null
                    MAADWriteSuccess "Established access -> SharePoint Online Administration Center"
                }
                catch {
                    MAADWriteError "Invalid credentials"
                }
            }
            if ($null -ne (Select-String -Pattern "invalid username or password" -InputObject $_.Exception.Message)) {
                MAADWriteError "Invalid credentials"
            }
        }
        catch {
            MAADWriteInfo "MFA required for authentication"
            MAADWriteProcess "Launching interactive authentication window to continue"
            try {
                #Attempt interactive authentication  
                Connect-SPOService -Url $sharepoint_admin_url -ErrorAction Stop | Out-Null
                MAADWriteSuccess "Established access -> SharePoint Online Administration Center"
            }
            catch {
                MAADWriteError "Failed to establish access -> SharePoint Online Administration Center"
            }
        }
    }
}

function ConnectSharepointSite ($target_site_url, [pscredential]$access_credential) {
    $global:sp_site_connected = $null
    try{
        MAADWriteProcess "Attempting access to SharePoint site"
        Connect-PnPOnline -Url $target_site_url -Credentials $access_credential
        MAADWriteSuccess "Connected to SharePoint site -> $target_site_url"
        $global:sp_site_connected = $true
    }
    catch [System.Exception]{
        if ($null -ne ($_.Exception.Message | Select-String -Pattern "Forbidden")){
            MAADWriteError "Can't get everything ;)"
            MAADWriteError "Account DOES NOT have access to SharePoint site"
            
            $global:sp_site_connected = $false
            return
        }
        else {
            Write-Host $_
            $global:sp_site_connected = $false
            return
        }
    }
    catch{
        MAADWriteError "Unable to access SharePoint site"
    }
}

function ConnectEdiscovery ([pscredential]$access_credential){
    MAADWriteProcess "Attempting access to Compliance portal"

    try {
        Connect-IPPSSession -ConnectionUri https://ps.compliance.protection.outlook.com/powershell-liveid -Credential $access_credential
        Start-Sleep -Seconds 5
        MAADWriteSuccess "Established access -> Compliance portal"
    }
    catch {
        MAADWriteError "Failed to establish access -> Compliance portal"
    }
}

function terminate_connection {

    MAADWriteProcess "Closing all active connections"
    try {
        Disconnect-Entra | Out-Null
    }
    catch {
        #do nothing
    }

    try {
        Disconnect-ExchangeOnline -Confirm:$false | Out-Null
    }
    catch {
        #do nothing
    }
    try {
        Disconnect-AzAccount -Confirm:$false | Out-Null
    }
    catch {
        #do nothing
    }
    try {
        Disconnect-MicrosoftTeams -Confirm:$false | Out-Null
    }
    catch {
        #do nothing
    }
    try {
        Disconnect-PnPOnline | Out-Null
    }
    catch {
        #do nothing
    }
    try {
        Disconnect-SPOService | Out-Null
    }
    catch {
        #do nothing
    }
    try {
        if($null -ne (Get-MgContext)){
            Disconnect-MgGraph | Out-Null
        }
    }
    catch {
        #do nothing
    }
    Write-MAADLog "info" "connections terminated"
}

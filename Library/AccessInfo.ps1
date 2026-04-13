#AccessInfo
function AccessInfo{
    Write-Host ""
    MAADWriteProcess "Fetching current access info"

    try {
        $entra_session_info = Get-EntraContext -ErrorAction Stop
        if ($null -eq $entra_session_info) {
            $access_status_entra = $false
        }
        else {
            $access_status_entra = $true
        }
    }
    catch {
        $access_status_entra = $false
    }

    try {
        $az_context = Get-AzContext -ErrorAction Stop
        if ($null -eq $az_context) {
            $access_status_az = $false
        }
        else {
            $access_status_az = $true
        }
    }
    catch {
        $access_status_az = $false
    }

    try {
        $teams_session_info = Get-AssociatedTeam -ErrorAction Stop
        $access_status_teams = $true
    }
    catch {
        $access_status_teams = $false
    }

    try {
        $access_status_exchange_online = $false
        $exchangle_online_session_info = Get-ConnectionInformation -ErrorAction Stop
        if ($null -eq $exchangle_online_session_info) {
            $access_status_exchange_online = $false
        }
        else {
            foreach ($connection in $exchangle_online_session_info){
                if ($connection.ConnectionUri -eq "https://outlook.office365.com") {
                    $access_status_exchange_online = $true
                }
            }
        }
    }
    catch {
        $access_status_exchange_online = $false
    }

    try {
        $sp_site_session_info = Get-PnPConnection -ErrorAction Stop
        $access_status_sp_site = $true
    }
    catch {
        $access_status_sp_site = $false
    }

    try {
        $spo_admin_session_info = Get-SPOTenant -ErrorAction Stop
        $access_status_spo_admin = $true
    }
    catch {
        $access_status_spo_admin = $false
    }

    try {
        $access_status_ediscovery = $false
        $ediscovery_session_info = Get-ConnectionInformation -ErrorAction Stop
        if ($null -eq $ediscovery_session_info) {
            $access_status_ediscovery = $false
        }
        else {
            foreach ($connection in $ediscovery_session_info){
                if ($connection.ConnectionUri -eq "https://nam10b.ps.compliance.protection.outlook.com") {
                    $access_status_ediscovery = $true
                }
            }
        }
    }
    catch {
        $access_status_ediscovery = $false
    }

    $connected_modules = @()
    if ($access_status_entra) {$connected_modules += "Entra"}
    if ($access_status_az) {$connected_modules += "Az"}
    if ($access_status_exchange_online) {$connected_modules += "Exchange Online"}
    if ($access_status_teams) {$connected_modules += "Teams"}
    if ($access_status_sp_site) {$connected_modules += "Sharepoint Site"}
    if ($access_status_spo_admin) {$connected_modules += "Sharepoint Admin"}
    if ($access_status_ediscovery) {$connected_modules += "Compliance Center"}
    Write-Host ""

    #Session Info
    $tenant_id = $null
    $logged_in_user = $null
    $logged_in_user_id = $null
    $account_role_name = @()
    $account_group_name = @()
    $account_owned_objects_name = @()

    if ($access_status_entra) {
        $tenant_id = $entra_session_info.TenantId
        $logged_in_user = $entra_session_info.Account

        try {
            Import-Module -Name Microsoft.Entra.Users -Force -WarningAction SilentlyContinue -ErrorAction Stop | Out-Null
            $logged_in_user_id = (Get-EntraUser -UserId $logged_in_user -ErrorAction Stop).Id
        }
        catch {
            $logged_in_user_id = $logged_in_user
        }

        try {
            Import-Module -Name Microsoft.Entra.Governance -Force -WarningAction SilentlyContinue -ErrorAction Stop | Out-Null
            $account_roles = Get-EntraUserRole -UserId $logged_in_user_id -All -ErrorAction Stop
            foreach ($role in $account_roles) {
                if ($role.DisplayName -notin "", $null) {
                    $account_role_name += $role.DisplayName
                }
            }
        }
        catch {}

        try {
            $account_membership = Get-EntraUserMembership -UserId $logged_in_user_id -All -ErrorAction Stop
            foreach ($membership in $account_membership) {
                if ($membership.'@odata.type' -eq "#microsoft.graph.group" -and $membership.DisplayName -notin "", $null) {
                    $account_group_name += $membership.DisplayName
                }
            }
        }
        catch {}

        try {
            $account_owned_objects = Get-EntraUserOwnedObject -UserId $logged_in_user_id -All -ErrorAction Stop
            foreach ($object in $account_owned_objects) {
                if ($object.DisplayName -notin "", $null) {
                    $account_owned_objects_name += $object.DisplayName
                }
            }
        }
        catch {}
    }

    #Display access info
    MAADWriteInfo "Tenant"
    if ($tenant_id -notin "", $null) {
        MAADWriteProcess "$tenant_id"
    }
    else {
        MAADWriteError "No Access"
    }
    Write-Host ""
    Start-Sleep -Seconds 1

    MAADWriteInfo "User"
    if ($logged_in_user -notin "", $null) {
        MAADWriteProcess "$logged_in_user"
    }
    else {
        MAADWriteError "No Access"
    }
    Write-Host ""
    Start-Sleep -Seconds 1

    MAADWriteInfo "Connected Services/ PS Modules"
    if ($connected_modules.Count -gt 0) {
        foreach ($connection in $connected_modules){
            MAADWriteProcess $connection
        }
    }
    else {
        MAADWriteError "No Access"
    }
    Write-Host ""
    Start-Sleep -Seconds 1

    MAADWriteInfo "Roles Assigned"
    if ($account_role_name.Count -gt 0) {
        foreach ($role in $account_role_name){
            MAADWriteProcess $role
        }
    }
    else {
        MAADWriteError "No Access"
    }
    Write-Host ""
    Start-Sleep -Seconds 1

    MAADWriteInfo "Group Membership"
    if ($account_group_name.Count -gt 0) {
        foreach ($group in $account_group_name){
            MAADWriteProcess $group
        }
    }
    else {
        MAADWriteError "No Access"
    }
    Write-Host ""
    Start-Sleep -Seconds 1

    MAADWriteInfo "Owner of"
    if ($account_owned_objects_name.Count -gt 0) {
        foreach ($object in $account_owned_objects_name){
            MAADWriteProcess $object
        }
    }
    else {
        MAADWriteError "No Access"
    }

    MAADPause
}

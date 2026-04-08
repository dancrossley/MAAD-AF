#Assign role 
function AssignRole ($target_object_type){
    mitre_details("AssignRole")

    try {
        Import-Module -Name Microsoft.Entra.Users -WarningAction SilentlyContinue -ErrorAction Stop | Out-Null
        Import-Module -Name Microsoft.Entra.Governance -WarningAction SilentlyContinue -ErrorAction Stop | Out-Null
    }
    catch {
        MAADWriteError "Required Entra role modules could not be loaded"
        MAADWriteError $_.Exception.Message
        MAADPause
        return
    }

    ###Select a target type
    if ($target_object_type -eq "account"){
        #Set a target account
        EnterAccount "`n[?] Enter account to assign role (user@org.com)"
        $target_display_name = $global:account_username

        try {
            $target_id = (Get-EntraUser -UserId $target_display_name -ErrorAction Stop).Id
        }
        catch {
            MAADWriteError "Failed to resolve target account"
            MAADWriteError $_.Exception.Message
            MAADPause
            return
        }
    }

    elseif ($target_object_type -eq "group"){
        try {
            Import-Module -Name Microsoft.Entra.Groups -WarningAction SilentlyContinue -ErrorAction Stop | Out-Null
        }
        catch {
            MAADWriteError "Required Entra group modules could not be loaded"
            MAADWriteError $_.Exception.Message
            MAADPause
            return
        }

        #Set a target group
        EnterGroup("`n[?] Enter target group name to assign role (press [enter] to find groups)")
        $target_display_name = $global:group_name

        try {
            $target_group = @(Get-EntraGroup -SearchString $target_display_name -ErrorAction Stop)
            if ($target_group.Count -eq 0) {
                MAADWriteError "Target group could not be resolved"
                MAADPause
                return
            }
            $target_id = $target_group[0].Id
        }
        catch {
            MAADWriteError "Failed to resolve target group"
            MAADWriteError $_.Exception.Message
            MAADPause
            return
        }
    }

    else{
        MAADWriteError "Unsupported role assignment target type"
        MAADPause
        return
    }

    EnterRole "`n[?] Enter role name to assign (press [enter] to find roles)"
    $target_role = $global:role_name

    try {
        $role_definition = @(Get-EntraDirectoryRoleDefinition -Filter "displayName eq '$target_role'" -ErrorAction Stop)
        if ($role_definition.Count -eq 0) {
            MAADWriteError "Role definition not found"
            MAADPause
            return
        }
        $role_definition_id = $role_definition[0].Id
    }
    catch {
        MAADWriteError "Failed to resolve target role"
        MAADWriteError $_.Exception.Message
        MAADPause
        return
    }
    
    #Assign role to target account
    try {
        MAADWriteProcess "Attempting to assign role"
        MAADWriteProcess "$target_role -> $target_display_name"
        $role_assignment = New-EntraDirectoryRoleAssignment -DirectoryScopeId '/' -RoleDefinitionId $role_definition_id -PrincipalId $target_id -ErrorAction Stop
        Start-Sleep -Seconds 10
        MAADWriteSuccess "Role Assigned"
        $allow_undo = $true
    }
    catch {
        MAADWriteError "Failed to assign role"
        MAADWriteError $_.Exception.Message
    }
    MAADPause
}

function AssignManagementRole {
    try {
        Import-Module -Name Microsoft.Entra.Users -WarningAction SilentlyContinue -ErrorAction Stop | Out-Null
    }
    catch {
        MAADWriteError "Required Entra user modules could not be loaded"
        MAADWriteError $_.Exception.Message
        MAADPause
        return
    }

    EnterAccount "`n[?] Enter account to assign role (user@org.com)"
    $target_account = $global:account_username
    try {
        $target_id = (Get-EntraUser -UserId $target_account -ErrorAction Stop).Id
    }
    catch {
        MAADWriteError "Failed to resolve target account"
        MAADWriteError $_.Exception.Message
        MAADPause
        return
    }


    EnterManagementRole "`n[?] Enter role name to assign (press [enter] to find roles)"
    $target_role = $global:management_role_name

    #Assign role to target account
    try {
        MAADWriteProcess "Attempting to assign role"
        MAADWriteProcess "$target_role -> $target_account"
        Add-RoleGroupMember -Identity $target_role -Member $target_account -ErrorAction Stop | Out-Null
        MAADWriteSuccess "Role Assigned"
    }
    catch {
        MAADWriteError "Failed to assign role"
    }
    MAADPause
}

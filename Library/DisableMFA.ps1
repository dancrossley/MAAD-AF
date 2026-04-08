function DisableMFA {

    mitre_details("DisableMFA")

    try {
        Import-Module -Name Microsoft.Entra.Users -WarningAction SilentlyContinue -ErrorAction Stop | Out-Null
        Import-Module -Name Microsoft.Entra.Beta.SignIns -WarningAction SilentlyContinue -ErrorAction Stop | Out-Null
    }
    catch {
        MAADWriteError "Required Entra MFA modules could not be loaded"
        MAADWriteError $_.Exception.Message
        MAADPause
        return
    }

    EnterAccount "`n[?] Enter account to disable MFA on (user@org.com)"
    $target_account = $global:account_username

    if ($null -ne $target_account){
        #Disabe MFA
        try {
            $current_auth_requirement = Get-EntraBetaUserAuthenticationRequirement -UserId $target_account -ErrorAction Stop
            $previous_mfa_state = [string]$current_auth_requirement.PerUserMfaState
            if ($previous_mfa_state -in $null, "") {
                $previous_mfa_state = "disabled"
            }
            MAADWriteProcess "Attempting to disable MFA on account -> $target_account"
            Update-EntraBetaUserAuthenticationRequirement -UserId $target_account -PerUserMfaState "disabled" -ErrorAction Stop
            Start-Sleep -s 5 
            MAADWriteSuccess "Guards Down: MFA disabled on account"
            $allow_undo = $true
        }
        catch {
            MAADWriteError "Failed to disable MFA"
            MAADWriteError $_.Exception.Message
        }   
    }
    else{
        MAADWriteProcess "Terminating module"
    }

    #Undo changes
    if ($allow_undo -eq $true) {
        #Restore MFA
        $user_choice = Read-Host -Prompt "`n[?] Undo: Re-enable MFA on the account (y/n)"

        if ($user_choice -notin "No","no","N","n") {
            $restored_mfa_state = $previous_mfa_state.ToLower()
            MAADWriteProcess "Restoring MFA state on account -> $target_account"
            try {
                Update-EntraBetaUserAuthenticationRequirement -UserId $target_account -PerUserMfaState $restored_mfa_state -ErrorAction Stop
                MAADWriteSuccess "Restored MFA state -> $restored_mfa_state"
            }
            catch {
                MAADWriteError "Failed to restore MFA state on account"
                MAADWriteError $_.Exception.Message
            }
        }
    }
    MAADPause
}

#Delete users
function RemoveAccess {
    mitre_details("RemoveAccess")

    try {
        Import-Module -Name Microsoft.Entra.Users -WarningAction SilentlyContinue -ErrorAction Stop | Out-Null
    }
    catch {
        MAADWriteError "Required Entra user modules could not be loaded"
        MAADWriteError $_.Exception.Message
        MAADPause
        return
    }

    MAADWriteInfo "Results of this action cannot be reversed"

    EnterAccount("`n[?] Enter account to delete from tenant")
    $target_account = $global:account_username

    if ($target_account -eq $global:AdminUsername){
        MAADWriteError "You are too great to destroy yourself"
        MAADWriteError "Failed to delete account"
        MAADWriteInfo "Cannot delete account currently in use"
        MAADWriteInfo "Create a backdoor account then use it to delete this account"
        break
    }

    #Delete account
    try {
        $user_confirm = Read-Host -Prompt "`n[?] Confirm account deletion [$target_account] (y/n)"
        Write-Host ""
        if ($user_confirm.ToUpper() -in "Y","YES"){
            MAADWriteProcess "Attempting to delete account" 
            Remove-EntraUser -UserId $target_account -ErrorAction Stop | Out-Null
            Start-Sleep -s 5 
            MAADWriteProcess "Deleted -> Account: $target_account"
            MAADWriteSuccess "Account Deleted from Tenant"
        }
        else {
            MAADWriteProcess "Deletion Aborted"
        }
    }
    catch {
        MAADWriteError "Failed to delete account"
        MAADWriteError $_.Exception.Message
    }
    MAADPause
}
    

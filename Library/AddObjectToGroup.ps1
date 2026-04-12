#Add user to group
function AddObjectToGroup {

    mitre_details "AddObjectToGroup"

    EnterAccount "`n[?] Enter account to add to group (user@org.com)"
    $target_account = $global:account_username
    $target_account_id = $global:account_id

    EnterGroup "`n[?] Enter group to add the account (press [enter] to find groups)"
    $target_group = $global:group_name
    $target_group_id = $global:group_id

    if ([string]::IsNullOrWhiteSpace($target_account_id) -or [string]::IsNullOrWhiteSpace($target_group_id)) {
        MAADWriteError "Resolved account or group ID is empty - cannot continue"
        MAADWriteInfo "account_id='$target_account_id' group_id='$target_group_id'"
        MAADPause
        return
    }

    #Add account to group
    try {
        MAADWriteProcess "Adding account to group"
        MAADWriteProcess "$target_account -> $target_group"
        Add-EntraGroupMember -GroupId $target_group_id -RefObjectId $target_account_id -ErrorAction Stop | Out-Null
        Start-Sleep -s 5
        MAADWriteSuccess "Account Added to Group"
        $allow_undo = $true
    }
    catch {
        MAADWriteError "Failed to add account to group"
        MAADWriteError (GetMAADExceptionMessage $_)
    }

    if ($allow_undo -eq $true) {
        #Remove user from Group
        $user_choice = Read-Host -Prompt "`n[?] Undo: Remove account from group (y/n)"
        Write-Host ""
        if ($user_choice -notin "No","no","N","n") {
            try {
                MAADWriteProcess "Removing account $target_account from group $target_group"
                Remove-EntraGroupMember -GroupId $target_group_id -MemberId $target_account_id -ErrorAction Stop | Out-Null
                Start-Sleep -s 5
                MAADWriteSuccess "Account Removed from Group"
            }
            catch {
                MAADWriteError "Failed to remove account from the group"
                MAADWriteError (GetMAADExceptionMessage $_)
            }
        }
    }
    MAADPause
}
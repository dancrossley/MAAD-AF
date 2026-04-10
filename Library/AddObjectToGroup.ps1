#Add user to group
function AddObjectToGroup {

    mitre_details "AddObjectToGroup"

    EnterAccount "`n[?] Enter account to add to group (user@org.com)"
    $target_account = $global:account_username
    $target_account_id = (Get-EntraUser -SearchString $target_account).Id

    EnterGroup "`n[?] Enter group to add the account (press [enter] to find groups)"
    $target_group = $global:group_name
    $target_group_id = (Get-EntraGroup -SearchString $target_group).Id

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
            }
        }
    }
    MAADPause
}
#Create new Entra Application
function CreateNewEntraApplication{
    [string]$new_app_display_name = Read-Host "`n[?] Enter a display name for the new application"
    Write-Host ""

    try {
        MAADWriteProcess "Attempting to create new application -> $new_app_display_name"
        New-EntraApplication -DisplayName $new_app_display_name | Out-Null
        MAADWriteSuccess "New Application Created"
        $allow_undo = $true
    }
    catch {
        MAADWriteError "Failed to create new application"
    }

    if ($allow_undo -eq $true){
        $user_confirm = Read-Host -Prompt "`n[?] Undo: Delete created application (y/n)"
        Write-Host ""

        if ($user_confirm -notin "No","no","N","n") {
            try {
                MAADWriteProcess "Attempting to delete application -> $new_app_display_name"
                $new_app_id = (Get-EntraApplication -Filter "displayName eq '$new_app_display_name'").Id
                Remove-EntraApplication -ApplicationId $new_app_id | Out-Null
                MAADWriteSuccess "New Application Deleted"
            }
            catch {
                MAADWriteError "Failed to delete new application"
            }
        }
    }
    MAADPause
}

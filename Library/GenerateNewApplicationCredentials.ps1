#Create new credentials for application

function GenerateNewApplicationCredentials{
    EnterApplication("`n[?] Enter Application name or AppId to generate credential for")
    if ($global:application_found -ne $true) {
        MAADPause
        return
    }
    $target_app = $global:application_name
    $target_app_object_id = $global:application_id

    #Generate credential and save credentials to file
    try {
        MAADWriteProcess "Attempting to generate new credential" 
        $app_credentials = New-EntraApplicationPasswordCredential -ApplicationId $target_app_object_id
        $new_secret = $app_credentials.SecretText
        if ($new_secret -in $null, "") {
            $new_secret = $app_credentials.Value
        }
        Start-Sleep -s 5 
        MAADWriteProcess "New secret generated for application"
        
        #Save to credential store
        AddCredentials "application" "GNAC_$target_app$(([DateTimeOffset](Get-Date)).ToUnixTimeSeconds())" $target_app $new_secret
        
        #Save output locally
        "$target_app :`n $app_credentials" | Out-File -FilePath .\Outputs\Application_Credentials.txt -Append
        MAADWriteProcess "Ouput Saved -> \MAAD-AF\Outputs\Application_Credentials.txt" 
        
        #Display output info
        MAADWriteProcess "Application Name: $target_app"
        MAADWriteProcess "New Secret: $new_secret"
        MAADWriteSuccess "Application Credentials Generated" 
    }
    catch {
        MAADWriteError "Failed to generate new credentials for application" 
    }
    MAADPause
}

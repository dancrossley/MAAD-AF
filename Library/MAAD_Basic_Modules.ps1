###Basic functions
function InitializeMAADPowerShellLimits {
    if ((($PSVersionTable).PSVersion.Major) -ne 5){
        return
    }

    $target_function_count = 32768
    $target_variable_count = 32768
    $limits_updated = $false

    if ($MaximumFunctionCount -lt $target_function_count) {
        Set-Variable -Name MaximumFunctionCount -Value $target_function_count -Scope Global -Force
        $limits_updated = $true
    }

    if ($MaximumVariableCount -lt $target_variable_count) {
        Set-Variable -Name MaximumVariableCount -Value $target_variable_count -Scope Global -Force
        $limits_updated = $true
    }

    if ($limits_updated) {
        MAADWriteProcess "Adjusted PowerShell session limits for large Entra/Graph modules"
    }
}

function RequiredModules {
    ###This function checks for required modules by MAAD and Installs them if unavailable. Some modules have specific version requirements specified in the dictionary values
    InitializeMAADPowerShellLimits
    $RequiredModules=@{"Az.Accounts" = "2.13.1";"Az.Resources" = "6.11.2"; "Microsoft.Entra" = "";"Microsoft.Entra.Applications" = "";"Microsoft.Entra.Groups" = "";"Microsoft.Entra.SignIns" = "";"Microsoft.Entra.Users" = "";"Microsoft.Entra.DirectoryManagement" = "";"Microsoft.Entra.Governance" = "";"Microsoft.Entra.Beta.SignIns" = "";"ExchangeOnlineManagement" = "3.9.0";"MicrosoftTeams" = "5.7.0";"Microsoft.Online.SharePoint.PowerShell" = "16.0.23710.12000";"PnP.PowerShell" = "1.12.0";"Microsoft.Graph.Authentication" = "";"Microsoft.Graph.Identity.SignIns" = "";"Microsoft.Graph.Applications" = "";"Microsoft.Graph.Users" = "";"Microsoft.Graph.Groups" = ""}
    $missing_modules = @{}
    $installed_modules = @{}
    $graph_modules = @("Microsoft.Graph.Identity.SignIns","Microsoft.Graph.Applications","Microsoft.Graph.Users","Microsoft.Graph.Groups")

    #Check for available modules
    MAADWriteProcess "Checking for dependencies"
    $installed_modules_count = 0
    foreach ($module in $RequiredModules.Keys) {
        try {
            if ($RequiredModules[$module] -ne "") {
                Get-InstalledModule -Name $module -RequiredVersion $RequiredModules[$module] -ErrorAction Stop
                $installed_modules_count+=1
                $installed_modules[$module] = $RequiredModules[$module]
            }
            else {
                Get-InstalledModule -Name $module -ErrorAction Stop
                $installed_modules_count+=1
                $installed_modules[$module] = $RequiredModules[$module]
            }
        }
        catch {
            #Add modules to missing modules dict
            $missing_modules[$module] = $RequiredModules[$module]
        }
    }

    #Display information and check user choice
    if ( $installed_modules_count -eq $RequiredModules.Count) {
        MAADWriteProcess "All required dependencies available"
        $allow = $null
    }
    elseif ($installed_modules_count -lt $RequiredModules.Count) {
        MAADWriteProcess "Modules currently installed -> $installed_modules_count / $($RequiredModules.Count)"
        MAADWriteProcess "MAAD-AF requires the following missing powershell modules"
        $missing_modules | Format-Table @{Label="PowerShell Module";Expression={$_.Name}}, @{Label="Required Version";Expression={$_.Value}}
        $allow = Read-Host -Prompt "`n[?] Install missing dependecies (y/n)"
    
        if ($null -eq $allow) {
            #Do nothing
        }
        elseif ($allow -notin "No","no","N","n") {
            MAADWriteProcess "Installing missing modules"

            try {
                Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction Stop
            }
            catch {
                MAADWriteInfo "Unable to change execution policy for this session"
                MAADWriteInfo $_.Exception.Message
            }

            try {
                Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false -ErrorAction Stop | Out-Null
            }
            catch {
                MAADWriteInfo "NuGet provider install was not completed automatically"
                MAADWriteInfo $_.Exception.Message
            }

            try {
                Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted -ErrorAction Stop
            }
            catch {
                MAADWriteInfo "Unable to set PSGallery as trusted"
                MAADWriteInfo $_.Exception.Message
            }

            $modules_to_install = @($missing_modules.Keys | Sort-Object `
                @{Expression = {
                    if ($_ -eq "Microsoft.Graph.Authentication") { 0 }
                    elseif ($_ -like "Microsoft.Graph.*") { 1 }
                    elseif ($_ -eq "Microsoft.Entra") { 2 }
                    elseif ($_ -like "Microsoft.Entra.*") { 3 }
                    else { 4 }
                }}, `
                @{Expression = { $_ }})

            #Install missing modules
            foreach ($module in $modules_to_install){
                MAADWriteProcess "Module missing -> $module"
                MAADWriteProcess "Installing -> $module"
                try {
                    if ($missing_modules[$module] -eq "") {
                        Install-Module -Name $module -Confirm:$False -WarningAction SilentlyContinue -AllowClobber -Force -ErrorAction Stop
                        #Add module to installed modules dict
                        $installed_modules[$module] = $RequiredModules[$module]
                        MAADWriteSuccess "Installed module -> $module"
                    }
                    else {
                        Install-Module -Name $module -RequiredVersion $missing_modules[$module] -Confirm:$False -WarningAction SilentlyContinue -AllowClobber -Force -ErrorAction Stop
                        $installed_modules[$module] = $RequiredModules[$module]
                        MAADWriteSuccess "Installed module -> $module"
                    }
                }
                catch {
                    MAADWriteError "Failed to install -> $module"
                    MAADWriteError $_.Exception.Message
                    MAADWriteProcess "Skipping module -> $module"
                }   
            }
        }
        else {
            MAADWriteInfo "Some MAAD-AF techniques may fail if required modules are missing"
        } 
    }

    MAADWriteProcess "Modules installed -> $($installed_modules.Count) / $($RequiredModules.Count)"

    foreach ($graph_module in $graph_modules) {
        try {
            $versions = @(Get-InstalledModule -Name $graph_module -AllVersions -ErrorAction Stop | Select-Object -ExpandProperty Version)
            if ($versions.Count -gt 1) {
                MAADWriteInfo "Multiple installed versions detected for $graph_module -> $($versions -join ', ')"
            }
        }
        catch {
            #Module can be intentionally missing if user skipped install.
        }
    }

    #Import all installed Modules
    MAADWriteProcess "Importing installed modules to current run space"
    $installed_module_names = @($installed_modules.Keys)
    $installed_module_names = @($installed_module_names | Sort-Object `
        @{Expression = {
            if ($_ -like "Microsoft.Graph.*") { 0 }
            elseif ($_ -like "Microsoft.Entra*") { 1 }
            else { 2 }
        }}, `
        @{Expression = { $_ }})

    foreach ($module in $installed_module_names){
        if ($module -eq "Microsoft.Graph.Authentication") {
            MAADWriteInfo "Skipping eager import -> Microsoft.Graph.Authentication"
            MAADWriteInfo "This dependency will be loaded on demand to reduce Entra authentication conflicts"
            continue
        }
        elseif ($module -like "Microsoft.Graph.*") {
            MAADWriteInfo "Skipping eager import -> $module"
            MAADWriteInfo "Microsoft.Graph modules will be loaded on demand to reduce Entra authentication conflicts"
            continue
        }

        #Remove any member of module from current run space
        try {
            Remove-Module -Name $module -ErrorAction Stop
        }
        catch {
            #Do nothing
        }
        
        try {
            if ($installed_modules[$module] -eq "") {
                Import-Module -Name $module -WarningAction SilentlyContinue -ErrorAction Stop | Out-Null
            }
            else {
                Import-Module -Name $module -RequiredVersion $installed_modules[$module] -WarningAction SilentlyContinue -ErrorAction Stop | Out-Null
            }
        }
        catch {
            MAADWriteError "Failed to import module"
            MAADWriteProcess "Skipping module import -> $module"
            if ($module -like "Microsoft.Graph.*" -or $module -like "Microsoft.Entra*") {
                MAADWriteInfo $_.Exception.Message
            }
        }
    }       

    MAADWriteProcess "Dependency check completed"
    #Prevents overwrite from any imported modules 
    $host.UI.RawUI.WindowTitle = "MAAD Attack Framework"
    Write-MAADLog "info" "Modules check completed"
} 

function InitializeMAADEntraCompatibility {
    try {
        Import-Module -Name Microsoft.Entra -WarningAction SilentlyContinue -ErrorAction Stop | Out-Null
    }
    catch {
        # Do nothing. Dependency checks or module autoload can handle installation state later.
    }

    try {
        Import-Module -Name Microsoft.Entra.Applications -WarningAction SilentlyContinue -ErrorAction Stop | Out-Null
    }
    catch {
        # Do nothing.
    }

    try {
        Import-Module -Name Microsoft.Entra.Groups -WarningAction SilentlyContinue -ErrorAction Stop | Out-Null
    }
    catch {
        # Do nothing.
    }

    try {
        Import-Module -Name Microsoft.Entra.SignIns -WarningAction SilentlyContinue -ErrorAction Stop | Out-Null
    }
    catch {
        # Do nothing.
    }

    try {
        Import-Module -Name Microsoft.Entra.Users -WarningAction SilentlyContinue -ErrorAction Stop | Out-Null
    }
    catch {
        # Do nothing.
    }

    try {
        Import-Module -Name Microsoft.Entra.DirectoryManagement -WarningAction SilentlyContinue -ErrorAction Stop | Out-Null
    }
    catch {
        # Do nothing.
    }

    try {
        Import-Module -Name Microsoft.Entra.Governance -WarningAction SilentlyContinue -ErrorAction Stop | Out-Null
    }
    catch {
        # Do nothing.
    }

    try {
        Import-Module -Name Microsoft.Entra.Beta.SignIns -WarningAction SilentlyContinue -ErrorAction Stop | Out-Null
    }
    catch {
        # Do nothing.
    }

}

function ClearActiveSessions {
    try {
        Get-PSSession | Remove-PSSession
    }
    catch {
        #Do nothing
    }
}

function DisplayCentre ($display_text,$text_colour) { 
    try {
        Write-Host ("{0}{1}" -f (' ' * (([Math]::Max(0, $Host.UI.RawUI.BufferSize.Width / 2) - [Math]::Floor($display_text.Length / 2)))), $display_text) -ForegroundColor $text_colour
    }
    catch {
        Write-Host $display_text -ForegroundColor $text_colour
    } 
}

function OptionDisplay ($menu_message, $option_list_dictionary){
    ###This function diplays a list of options from a dictionary.
    Write-Host "`n$menu_message"
    $option_list_array = $option_list_dictionary.GetEnumerator() |sort Name

    foreach ($item in $option_list_array){
        Write-Host $item.Name ":" $item.Value 
    } 
}

function CreateOutputsDir {
    if ((Test-Path -Path ".\Outputs") -eq $false){
        New-Item -ItemType Directory -Force -Path .\Outputs | Out-Null
    }
}

function CreateLocalDir {
    #check if the directory exists, if not, create it
    if (! (Test-Path -Path ".\Local")){
        New-Item -ItemType Directory -Force -Path .\Local | Out-Null
    }

    #Create Credentials store if not present
    if (! (Test-Path -Path $global:maad_credential_store)){
        Out-File $global:maad_credential_store
    }

    #Create config file if not present
    if(! (Test-Path -Path $global:maad_config_path)){
        $maad_config = ([PSCustomObject]@{
            "tor_config" = @{
                tor_root_directory = "C:/Users/username/sub_folder/Tor Browser"
                tor_host = "127.0.0.1"
                tor_port = "9150"
                control_port = "9151"
            }
            "DependecyCheckBypass" = $false
        })
        $maad_config_json = $maad_config | ConvertTo-Json
        $maad_config_json | Set-Content -Path $global:maad_config_path -Force
    }
}


function InitializationChecks{  
    if((($PSVersionTable).PSVersion.Major) -ne 5){
        MAADWriteError "Incompatible PS Version -> $($PSVersionTable.PSVersion.Major)"
        MAADWriteInfo "Switch to execute MAAD-AF in PowerShell 5"
        MAADPause
    }

    InitializeMAADPowerShellLimits

    #Create outputs & local files directory (if not present)
    CreateLocalDir
    CreateOutputsDir

    #Clear any active sessions to prevent reaching session limit
    ClearActiveSessions 

    #Log MAAD-AF start
    Write-MAADLog "Start" "MAAD-AF Initialized"
}

function EnterMailbox ($input_prompt){
    ###This function takes user input and checks for its validity. If invalid, then executes recon to show available options.If valid, returns mailbox address($input_mailbox_address)
    $repeat = $false
    do {
        $input_mailbox_address = Read-Host -Prompt $input_prompt

        if ($input_mailbox_address.ToUpper() -eq "RECON" -or $input_mailbox_address -eq "" -or $input_mailbox_address -eq $null) {
            try {
                Write-Host ""
                MAADWriteProcess "Recon -> Searching Mailboxes"
                $all_mailboxes = Get-Mailbox | Select-Object DisplayName, PrimarySmtpAddress 
                
                Show-MAADOptionsView -OptionsList $all_mailboxes -NewWindowMessage "Mailboxes in tenant"
                
                $repeat = $true
            }
            catch {
                MAADWriteError "Failed to find mailboxes"
                $repeat = $false
            }
        }
        else {
            ValidateMailbox($input_mailbox_address)
            if ($global:mailbox_found -eq $true) {
                $repeat = $false
            }
            if ($global:mailbox_found -eq $false){
                $repeat = $true
            }
        }  
    } while ($repeat -eq $true) 
}

function ValidateMailbox ($input_mailbox_address){
    ###This function returns if a mailbox address is valid ($mailbox_found = $true) or not ($mailbox_found = $false)
    $global:mailbox_found = $false
    Write-Host ""

    try {
        $fetch_mailbox = Get-Mailbox -Identity $input_mailbox_address -ErrorAction Stop
        $global:mailbox_address = $input_mailbox_address
        $global:mailbox_found = $true
        MAADWriteProcess "Mailbox Found : $global:mailbox_address"
    }
    catch {
        MAADWriteError "Mailbox Not Found"
        $global:mailbox_found = $false
    }
}

function EnterAccount ($input_prompt){
    ###This function takes user input and checks for its validity. If invalid, then executes recon to show available options. If valid, returns account name($account_username)
    $repeat = $false
    do {
        $input_user_account = Read-Host -Prompt $input_prompt

        if ($input_user_account.ToUpper() -eq "RECON" -or $input_user_account -eq "" -or $input_user_account -eq $null) {
            try {
                Write-Host ""
                MAADWriteProcess "Recon -> Searching Accounts"
                $all_users = Get-EntraUser -All -ErrorAction Stop | Select-Object DisplayName,UserPrincipalName,UserType
                Show-MAADOptionsView -OptionsList $all_users -NewWindowMessage "Accounts in tenant"
                $repeat = $true
            }
            catch {
                MAADWriteError "Failed to find account"
                MAADWriteError $_.Exception.Message
                $repeat = $false
            }
        }
        else {
            ValidateAccount($input_user_account)
            if ($global:account_found -eq $true) {
                $repeat = $false
            }
            if ($global:account_found -eq $false){
                $repeat = $true
            }
        }  
    } while ($repeat -eq $true)  
}

function ValidateAccount ($input_user_account){
    ###This function returns if an account exists in Azure AD ($account_found = $true) or not ($account_found = $false)
    $global:account_found = $false
    $global:account_id = $null
    Write-Host ""

    try {
        $check_account = @(Get-EntraUser -SearchString $input_user_account -ErrorAction Stop)
    }
    catch {
        MAADWriteError "Failed to search for account"
        MAADWriteError $_.Exception.Message
        $global:account_found = $false
        return
    }

    if ($check_account.Count -eq 0){
        MAADWriteError "Account Not Found"
        $global:account_found = $false
        return
    }

    # Prefer an exact (case-insensitive) UPN or DisplayName match when multiple results come back
    $exact_account = @($check_account | Where-Object {
        $_.UserPrincipalName -eq $input_user_account -or $_.DisplayName -eq $input_user_account
    })

    if ($exact_account.Count -eq 1) {
        $global:account_username = $exact_account[0].UserPrincipalName
        $global:account_id = $exact_account[0].Id
        $global:account_found = $true
        MAADWriteProcess "Account Found : $global:account_username"
        return
    }

    if ($check_account.Count -gt 1){
        MAADWriteError "Recon -> Multiple accounts found matching term"
        MAADWriteInfo "Lets take it slow ;) Try more specific search to target one account"

        Read-Host "`n[?] Press enter to view all matched accounts"
        Write-Host ""
        $check_account | Format-Table -Property UserPrincipalName, Id -AutoSize
        $global:account_found = $false
        return
    }

    $global:account_username = $check_account[0].UserPrincipalName
    $global:account_id = $check_account[0].Id
    $global:account_found = $true
    MAADWriteProcess "Account Found : $global:account_username"
}

function EnterGroup ($input_prompt){
    ###This function takes user input and checks for its validity. If invalid, then executes recon to show available options. If valid, returns group name($group_name)
    $repeat = $false
    do {
        $input_group = Read-Host -Prompt $input_prompt

        if ($input_group.ToUpper() -eq "RECON" -or $input_group -eq "" -or $input_group -eq $null) {
            try {
                Write-Host ""
                MAADWriteProcess "Recon -> Searching Groups"
                $all_groups = Get-EntraGroup -All -ErrorAction Stop | Select-Object DisplayName
                Show-MAADOptionsView -OptionsList $all_groups -NewWindowMessage "Groups in tenant"
                $repeat = $true
            }
            catch {
                MAADWriteError "Failed to find groups"
                MAADWriteError $_.Exception.Message
                $repeat = $false
            }
        }
        else {
            ValidateGroup($input_group)
            if ($global:group_found -eq $true) {
                $repeat = $false
            }
            if ($global:group_found -eq $false){
                $repeat = $true
            }
        }  
    } while ($repeat -eq $true)  
}

function ValidateGroup ($input_group){
    ###This function returns if a group exists in Azure AD ($group_found = $true) or not ($group_found = $false)
    $global:group_found = $false
    $global:group_id = $null
    Write-Host ""

    try {
        $check_group = @(Get-EntraGroup -SearchString $input_group -ErrorAction Stop)
    }
    catch {
        MAADWriteError "Failed to search for group"
        MAADWriteError $_.Exception.Message
        $global:group_found = $false
        return
    }

    if ($check_group.Count -eq 0){
        MAADWriteError "Group Not Found"
        $global:group_found = $false
        return
    }

    # Prefer an exact (case-insensitive) DisplayName match when the search returns substrings
    $exact_group = @($check_group | Where-Object { $_.DisplayName -eq $input_group })
    if ($exact_group.Count -eq 1) {
        $global:group_name = $exact_group[0].DisplayName
        $global:group_id = $exact_group[0].Id
        $global:group_found = $true
        MAADWriteProcess "Group Found : $global:group_name"
        return
    }

    if ($check_group.Count -gt 1){
        MAADWriteProcess "Recon -> Multiple groups found matching term"
        MAADWriteInfo "Lets take things slow ;) Be more specific to target one group"

        Read-Host "`n[?] Press enter to view all matched groups"
        Write-Host ""
        $check_group | Format-Table -Property DisplayName, Id -AutoSize
        $global:group_found = $false
        return
    }

    $global:group_name = $check_group[0].DisplayName
    $global:group_id = $check_group[0].Id
    $global:group_found = $true
    MAADWriteProcess "Group Found : $global:group_name"
}


function EnterRole ($input_prompt){
    ###This function takes user input and checks for its validity. If invalid, then executes recon to show available options. If valid, returns role name($input_role)
    $repeat = $false
    do {
        $input_role = Read-Host -Prompt $input_prompt

        if ($input_role.ToUpper() -eq "RECON" -or $input_role -eq "" -or $input_role -eq $null) {
            try {
                Write-Host ""
                MAADWriteProcess "Recon -> Searching Roles"
                $all_roles = Get-EntraDirectoryRoleDefinition -All -ErrorAction Stop | Select-Object DisplayName,Description
                Show-MAADOptionsView -OptionsList $all_roles -NewWindowMessage "Roles in tenant"
                $repeat = $true
            }
            catch {
                MAADWriteError "Failed to find role"
                MAADWriteError $_.Exception.Message
                $repeat = $false
            }
        }
        else {
            ValidateRole($input_role)
            if ($global:role_found -eq $true) {
                $repeat = $false
            }
            if ($global:role_found -eq $false){
                $repeat = $true
            }
        }  
    } while ($repeat -eq $true)  
}

function ValidateRole ($input_role){
    ###This function returns if a group exists in Azure AD ($role_found = $true) or not ($role_found = $false)
    $global:role_found = $false
    Write-Host ""

    try {
        $check_role = @(Get-EntraDirectoryRoleDefinition -SearchString $input_role -ErrorAction Stop)
    }
    catch {
        MAADWriteError "Failed to search for role"
        MAADWriteError $_.Exception.Message
        $global:role_found = $false
        return
    }
    
    if ($check_role.Count -eq 0){
        MAADWriteError "Role Not Found"
        $global:role_found = $false
    }
    
    else {
        if ($check_role.Count -gt 1){
            MAADWriteError "Recon -> Multiple roles found matching term"
            MAADWriteInfo "Lets take things slow ;) Be more specific to target one role!"

            Read-Host "`n[?] Press enter to view all mathced roles"
            Write-Host ""
            $check_role | Format-Table -Property DisplayName, Id -AutoSize
            $global:role_found = $false
        }
        else {
            $global:role_name = $check_role[0].DisplayName
            $global:role_found = $true
            MAADWriteProcess "Role Found : $global:role_name"
        }
    }
}

function EnterManagementRole ($input_prompt){
    ###This function takes user input and checks for its validity. If invalid, then executes recon to show available options. If valid, returns role name($management_role_name)
    $repeat = $false
    do {
        $input_mgmt_role = Read-Host -Prompt $input_prompt

        if ($input_mgmt_role.ToUpper() -eq "RECON" -or $input_mgmt_role -eq "" -or $input_mgmt_role -eq $null) {
            try {
                Write-Host ""
                MAADWriteProcess "Recon -> Searching Management Roles"
                # Get-RoleGroup | Format-Table -Property Name, Description
                $all_role_groups = Get-RoleGroup | Select-Object Name, Description
                Show-MAADOptionsView -OptionsList $all_role_groups -NewWindowMessage "Management Roles in tenant"
                $repeat = $true
            }
            catch {
                MAADWriteError "Failed to find management role"
                $repeat = $false
            }
        }
        else {
            ValidateManagementRole($input_mgmt_role)
            if ($global:mgmt_role_found -eq $true) {
                $repeat = $false
            }
            if ($global:mgmt_role_found -eq $false){
                $repeat = $true
            }
        }  
    } while ($repeat -eq $true)  
}

function ValidateManagementRole ($input_mgmt_role){
    ###This function returns if a group exists in Azure AD ($mgmt_role_found = $true) or not ($mgmt_role_found = $false)
    $global:mgmt_role_found = $false
    Write-Host ""

    $check_mgmt_role = Get-RoleGroup -Filter "Name -eq '$input_mgmt_role'"
    
    if ($check_mgmt_role -eq $null){
        MAADWriteError "Management role Not Found"
        $global:mgmt_role_found = $false
    }
    
    else {
        if ($check_mgmt_role.GetType().BaseType.Name -eq "Array"){
            MAADWriteError "Recon -> Multiple management roles found matching term"
            MAADWriteInfo "Lets take things slow ;) Be more specific to target one role"

            Read-Host "`n[?] Press enter to view all mathced management roles"
            Write-Host ""
            $check_mgmt_role | Format-Table -Property Name, Description -AutoSize
            $global:mgmt_role_found = $false
        }
        else {
            $global:management_role_name = $check_mgmt_role.Name
            $global:mgmt_role_found = $true
            MAADWriteProcess "Management role Found : $global:management_role_name"
        }
    }
}

function EnterTeam ($input_prompt){
    ###This function takes user input and checks for its validity. If invalid, then executes recon to show available options. If valid, returns team name($input_team)
    $repeat = $false
    do {
        $input_team = Read-Host -Prompt $input_prompt

        if ($input_team.ToUpper() -eq "RECON" -or $input_team -eq "" -or $input_team -eq $null) {
            try {
                Write-Host ""
                MAADWriteProcess "Recon -> Searching Teams"
                # Get-Team | Format-Table DisplayName,GroupID,Description,Visibility
                $all_teams = Get-Team | Select-Object DisplayName,GroupID,Description,Visibility
                Show-MAADOptionsView -OptionsList $all_teams -NewWindowMessage "Teams in tenant"
                $repeat = $true
            }
            catch {
                MAADWriteError "Failed to find teams"
                $repeat = $false
            }
        }
        else {
            ValidateTeam($input_team)
            if ($global:team_found -eq $true) {
                $repeat = $false
            }
            if ($global:team_found -eq $false){
                $repeat = $true
            }
        }  
    } while ($repeat -eq $true)  
}

function ValidateTeam ($input_team){
    ###This function returns if a group exists in Azure AD ($team_found = $true) or not ($team_found = $false)
    $global:team_found = $false
    Write-Host ""

    $check_team = Get-Team -DisplayName $input_team
    
    if ($check_team -eq $null){
        MAADWriteError "Team Not Found"
        $global:team_found = $false
    }
    
    else {
        if ($check_team.GetType().BaseType.Name -eq "Array"){
            MAADWriteError "Recon -> Multiple teams found matching term" 
            MAADWriteInfo "Lets take things slow ;) Be more specific to target one team"

            Read-Host "`n[?] Press enter to view all matched teams"
            Write-Host ""
            $check_team | Format-Table -Property DisplayName, GroupID -AutoSize
            $global:team_found = $false
        }
        else {
            $global:team_name = $check_team.DisplayName
            $global:team_found = $true
            MAADWriteProcess "Team Found : $global:team_name"
        }
    }
}

function EnterApplication ($input_prompt){
    ###This function takes user input and checks for its validity. If invalid, then executes recon to show available options. If valid, returns role name($input_application)
    $repeat = $false
    do {
        $input_application = Read-Host -Prompt $input_prompt

        if ($input_application.ToUpper() -eq "RECON" -or $input_application -eq "" -or $input_application -eq $null) {
            try {
                Write-Host ""
                MAADWriteProcess "Recon -> Searching Applications"
                # Get-AzureADApplication | Format-Table -Property DisplayName, AppId, ObjectId, Description
                $all_apps = Get-EntraApplication -All | Select-Object DisplayName, AppId, Id
                Show-MAADOptionsView -OptionsList $all_apps -NewWindowMessage "Applications in tenant"
                $repeat = $true
            }
            catch {
                MAADWriteError "Failed to find applications"
                $repeat = $false
            }
        }
        else {
            ValidateApplication($input_application)
            if ($global:application_found -eq $true) {
                $repeat = $false
            }
            if ($global:application_found -eq $false){
                $repeat = $true
            }
        }  
    } while ($repeat -eq $true)  
}

function ValidateApplication ($input_application){
    ###This function returns if an application exists in Entra ($application_found = $true) or not ($application_found = $false)
    $global:application_found = $false
    $global:application_id = $null
    $global:application_app_id = $null
    Write-Host ""

    # If the user typed an AppId GUID, query it directly before search-string flow
    if ($input_application -match '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') {
        try {
            $direct_application = Get-EntraApplication -ApplicationId $input_application -ErrorAction Stop
            if ($null -ne $direct_application) {
                $global:application_name = $direct_application.DisplayName
                $global:application_id = $direct_application.Id
                $global:application_app_id = $direct_application.AppId
                $global:application_found = $true
                MAADWriteProcess "Application Found : $global:application_name ($global:application_app_id)"
                return
            }
        }
        catch {
            # Fall back to search-string flow for non-AppId GUID-like input (e.g., ObjectId)
        }
    }

    try {
        $check_application = @(Get-EntraApplication -SearchString $input_application -ErrorAction Stop)
    }
    catch {
        MAADWriteError "Failed to search for applications"
        MAADWriteError $_.Exception.Message
        $global:application_found = $false
        return
    }

    if ($check_application.Count -eq 0){
        MAADWriteError "Application Not Found"
        $global:application_found = $false
        return
    }

    # Prefer an exact (case-insensitive) DisplayName match when multiple results come back
    $exact_application = @($check_application | Where-Object { $_.DisplayName -eq $input_application })
    if ($exact_application.Count -eq 1) {
        $global:application_name = $exact_application[0].DisplayName
        $global:application_id = $exact_application[0].Id
        $global:application_app_id = $exact_application[0].AppId
        $global:application_found = $true
        MAADWriteProcess "Application Found : $global:application_name ($global:application_app_id)"
        return
    }

    if ($check_application.Count -gt 1){
        MAADWriteProcess "Recon -> Multiple applications found matching your term"
        MAADWriteInfo "Multiple applications share this name. Enter AppId to disambiguate."
        Write-Host ""
        $check_application | Format-Table -Property DisplayName, AppId, Id -AutoSize -Wrap

        $selected_app_id = Read-Host -Prompt "`n[?] Enter AppId of the application to target (or press [enter] to cancel)"
        if ($selected_app_id -in "", $null) {
            $global:application_found = $false
            return
        }

        $picked = @($check_application | Where-Object { $_.AppId -eq $selected_app_id -or $_.Id -eq $selected_app_id })
        if ($picked.Count -eq 1) {
            $global:application_name = $picked[0].DisplayName
            $global:application_id = $picked[0].Id
            $global:application_app_id = $picked[0].AppId
            $global:application_found = $true
            MAADWriteProcess "Application Found : $global:application_name ($global:application_app_id)"
        }
        else {
            MAADWriteError "AppId not matched in the result set"
            $global:application_found = $false
        }
        return
    }

    # Single match
    $global:application_name = $check_application[0].DisplayName
    $global:application_id = $check_application[0].Id
    $global:application_app_id = $check_application[0].AppId
    $global:application_found = $true
    MAADWriteProcess "Application Found : $global:application_name ($global:application_app_id)"
}

function EnterSharepointSite ($input_prompt){
    ###This function takes user input and checks for its validity. If invalid, then executes recon to show available options. If valid, returns role name($input_site)
    $repeat = $false
    do {
        $input_site = (Read-Host -Prompt $input_prompt).Trim()

        if ($input_site.ToUpper() -eq "RECON" -or $input_site -eq "" -or $input_site -eq $null) {
            try {
                Write-Host ""
                MAADWriteProcess "Recon -> Searching SharePoint Sites"
                # Get-SPOSite | Format-Table -Property Title,URL,SharingCapability,ConditionalAccessPolicy 
                $all_sites = Get-SPOSite | Select-Object Title,URL,SharingCapability 
                Show-MAADOptionsView -OptionsList $all_sites -NewWindowMessage "SP Sites in tenant"
                $repeat = $true
            }
            catch {
                MAADWriteError "Failed to list SharePoint sites"
                $repeat = $false
            }
        }
        else {
            ValidateSharepointSite($input_site)
            if ($global:site_found -eq $true) {
                $repeat = $false
            }
            if ($global:site_found -eq $false){
                $repeat = $true
            }
        }  
    } while ($repeat -eq $true)  
}

function ValidateSharepointSite ($input_site){
    ###This function returns if a group exists in Azure AD ($site_found = $true) or not ($site_found = $false)
    $global:site_found = $false
    Write-Host ""

    $check_site = Get-SPOSite | ?{$_.Title -eq $input_site}
    
    if ($check_site -eq $null){
        MAADWriteError "Site Not Found"
        $global:site_found = $false
    }
    
    else {
        if ($check_site.GetType().BaseType.Name -eq "Array"){
            MAADWriteError "Recon -> Multiple sites found matching your term" 
            MAADWriteInfo "Lets take things slow ;) Be more specific to target one site"

            Read-Host "`n[?] Press enter to view all matched sites"
            Write-Host ""
            $check_site | Format-Table -Property Title, URL -AutoSize
            $global:site_found = $false
        }
        else {
            $global:sharepoint_site_name = $check_site.Title
            $global:sharepoint_site_url = $check_site.URL
            $global:site_found = $true
            MAADWriteProcess "Site Found : $global:sharepoint_site_name"
        }
    }
}

Function Write-MAADLog([string]$event_type, [String]$event_message ) {
    #Acceptable event types: START, END, SUCCESS, ERROR, INFO
    
    #Get log time stamp
    $event_time = (Get-Date).ToString("dd/MM/yyyy HH:mm:ss:fff tt")
    #Craft log message
    $log_message = "$event_time - [$($event_type.ToUpper())] - $event_message"
    #Write log
    Add-Content -Value $log_message -Path $global:maad_log_file 
}

function MAADHelp {
    $maad_commands = [ordered]@{
        "SHOW ALL" = "Expand all options in MAAD Attack Arsenal for a full list of options.";
        "ADD CREDS" = "Add new credentials to the MAAD-AF credentials store for quickly establishing access later.";
        "SHOW CREDS" = "Show all credentials collected in MAAD-AF credentials store.";
        "ESTABLISH ACCESS" = "Initiate access attempt to Micrsoft services using stored or new credentials.";
        "SWITCH ACCESS" = "Use another credential from Credential Store to establish access in modules"
        "ACCESS INFO" = "Display details about my current access session";
        "KILL ACCESS" = "Terminate all active connections";
        "ANONYMIZE" = "Enable TOR";
        "EXIT" = "Exit MAAD-AF without closing active access connections.";
        "FULL EXIT" = "Exit MAAD-AF and close all active connections."
    }

    #Display commands
    Write-Host ""
    DisplayCentre "##########################" "Red"
    DisplayCentre "MAAD-AF Help" "Red"
    DisplayCentre "##########################" "Red"
    Write-Host "`nExecute module"
    Write-Host "Select an option from the MAAD Attack Arsenal menu by typing the option number (eg: 1 for Pre-Attack)"

    Write-Host "`nQuick Command"
    Write-Host "Take quick actions using a quick action command in MAAD Atack Arsenal menu"

    #$maad_commands |Format-Table -HideTableHeaders -Wrap
    $maad_commands | Format-Table @{Label="Quick Command";Expression={$tf = "91"; $e = [char]27; "$e[${tf}m$($_.Name)${e}[0m"}}, @{Label="Description";Expression={$tf = "0"; $e = [char]27; "$e[${tf}m$($_.Value)${e}[0m"}} -Wrap

    MAADPause
}

function MAADWriteSuccess ([string]$message) {
    Write-Host "[+] Success -> $message" -ForegroundColor Yellow
}

function MAADWriteProcess ([string]$message) {
    Write-Host "[*] $message" -ForegroundColor Gray
    Start-Sleep -Seconds 1
}

function MAADWriteInfo ([string]$message) {
    Write-Host "[i] $message" -ForegroundColor Cyan
}

function MAADWriteError ([string]$message) {
    Write-Host "[x] $message" -ForegroundColor Red
}

function MAADPause {
    Write-Host ""
    Read-Host -Prompt "[?] Continue"
}

function Show-MAADOutput {
    param (
        [int]$large_limit,
        [array]$output_list,
        [string]$file_path
    )
    #This function displays a large output in a new powershell window
    MAADWriteProcess "Found $($output_list.Count) results"
    $script = {
        $name = 'MAAD-AF Output View'
        $host.ui.RawUI.WindowTitle = $name
    }

    if ($output_list.Count -gt 0) {
        
        MAADWriteProcess "Exporting results"
        $output_time_stamp = Get-Date -Format "MMM dd yyyy HH:mm:ss"
        "`n$output_time_stamp `n--------------------" | Out-File -FilePath $file_path -Append
        $output_list | Out-File -FilePath $file_path -Append -Width 10000
        MAADWriteProcess "Output Saved -> $file_path"

        if ($output_list.Count -gt $large_limit) {
            $user_input = Read-Host "`n[?] Display full results (y/n)"
            Write-Host ""
            if ($user_input -eq "y"){
                MAADWriteInfo "Large output"
                MAADWriteProcess "Checkout results in -> MAAD-AF Output view"
                Start-Process powershell -ArgumentList "-NoExit $script `"Get-Content -Path $file_path; Read-Host `"Press [enter] to exit`" ;exit`""
            }
        }
        else {
            MAADWriteProcess "Checkout results in -> MAAD-AF Output view"
            Start-Process powershell -ArgumentList "-NoExit $script `"Get-Content -Path $file_path; Read-Host `"Press [enter] to close output view`" ;exit`""
        }
    }
}

function Show-MAADOptionsView {
    param (
        [array]$OptionsList,
        [string]$NewWindowMessage
    )
    #This function displays options in a new powershell windows

    $temp_file = New-TemporaryFile

    if ($OptionsList.Count -gt 0) {
        $NewWindowMessage | Out-File -FilePath $temp_file
        $OptionsList | Out-File -FilePath $temp_file -Width 10000 -Append
        
        MAADWriteInfo "Select from options in Options View"

        $script = {
            $host.ui.RawUI.WindowTitle = 'MAAD-AF Options View'
        }
        Start-Process powershell -ArgumentList "-NoExit $script `"Get-Content -Path $temp_file; Read-Host `"Press [enter] to close options view`" ;exit`""
    }
}

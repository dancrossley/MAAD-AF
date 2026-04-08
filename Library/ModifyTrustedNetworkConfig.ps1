function ModifyTrustedNetworkConfig {
    mitre_details("TrustedNetworkConfig")
    $allow_undo = $false

    try {
        Import-Module -Name Microsoft.Entra.SignIns -WarningAction SilentlyContinue -ErrorAction Stop | Out-Null
    }
    catch {
        MAADWriteError "Required Entra sign-in policy modules could not be loaded"
        MAADWriteError $_.Exception.Message
        MAADPause
        return
    }

    #Get public IP
    $trusted_policy_name = Read-Host -Prompt "`n[?] Enter name for new Trusted Network Policy"
    Write-Host ""
    MAADWriteInfo "Leave blank and press [enter] to automatically use your public IP"

    $ip_addr = Read-Host -Prompt "`n[?] Enter IP to add as trusted named location"
    Write-Host ""

    if ($ip_addr -eq "") {
        MAADWriteProcess "Resolving your public IP"
        MAADWriteProcess "Querying DNS"
        $ip_addr = $(Resolve-DnsName -Name myip.opendns.com -Server 208.67.222.220).IPAddress
        MAADWriteProcess "Your public IP -> $ip_addr"
        MAADPause

        if ($ip_addr -eq "") {
            MAADWriteError "Failed to resolve IP automatically"
            $ip_addr = Read-Host -Prompt "`n[?] Manually enter IP address to add as trusted named location"
            Write-Host ""
        }
    }
    
    #Create trusted network policy
    try {
        $ip_range = New-Object -TypeName Microsoft.Open.MSGraph.Model.IpRange
        $ip_range.CidrAddress = "$ip_addr/32"
        $ip_ranges = New-Object 'System.Collections.Generic.List[Microsoft.Open.MSGraph.Model.IpRange]'
        $ip_ranges.Add($ip_range)
        MAADWriteProcess "Deploying policy -> $trusted_policy_name"
        $trusted_nw = New-EntraNamedLocationPolicy -OdataType "#microsoft.graph.ipNamedLocation" -DisplayName $trusted_policy_name -IsTrusted $true -IpRanges $ip_ranges -ErrorAction Stop
        MAADWriteProcess "Trusted network policy created"
        MAADWriteProcess "Retrieving details of deployed policy"
        MAADWriteProcess "Policy Name -> $($trusted_nw.DisplayName)"
        MAADWriteProcess "Policy ID -> $($trusted_nw.Id)"
        MAADWriteProcess "Trusted IP Range -> $($trusted_nw.IpRanges.CidrAddress)"
        MAADWriteSuccess "Deployed Trusted Network Policy"
        $allow_undo = $true
    }
    catch {
        MAADWriteError "Failed to deploy trusted network policy"
        MAADWriteError $_.Exception.Message
        MAADWriteInfo "This action requires Conditional Access policy permissions and a supported Entra admin role such as Security Administrator or Conditional Access Administrator"
    }
    
    #Undo changes
    if ($allow_undo -eq $true) {
        $user_confirm = Read-Host -Prompt "`n[?] Undo: Delete new trusted network policy (y/n)"
        Write-Host ""

        if ($user_confirm -notin "No","no","N","n") {
            try {
                MAADWriteProcess "Marking IP as untrusted"
                Set-EntraNamedLocationPolicy -OdataType "#microsoft.graph.ipNamedLocation" -PolicyId $trusted_nw.Id -DisplayName $trusted_nw.DisplayName -IsTrusted $false -IpRanges $trusted_nw.IpRanges -ErrorAction Stop
                MAADWriteProcess "Removing Trusted Network Policy"
                Remove-EntraNamedLocationPolicy -PolicyId $trusted_nw.Id -ErrorAction Stop
                MAADWriteSuccess "Deleted New Trusted Location Policy"
            }
            catch {
                MAADWriteError "Failed to delete new trusted network policy"
                MAADWriteError $_.Exception.Message
            }
        }
    }
    MAADPause
}

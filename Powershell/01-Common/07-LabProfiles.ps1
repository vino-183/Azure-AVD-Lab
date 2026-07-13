<#$LabProfiles = @{

    SessionHost = @{

        JoinType = "Entra"

        HostPool = "avd-hp-prod"

        Workspace = "avd-ws-prod"

        ApplicationGroup = "avd-dag-prod"

        InstallFSLogix = $true

        OptimizeAVD = $true

        RegisterToHostPool = $true

        Monitoring = "AzureMonitor"

    }

}#>
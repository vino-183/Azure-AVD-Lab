# Global variables for Azure AVD lab

#region Azure

$SubscriptionId = "abcf40e1-733b-4521-997a-3818412c23e3"

$TenantId = "188752e7-835a-41e7-a3e7-ae6a3f76e1aa"

$Location = "East US"

$Environment = "Dev" # Dev, Test, Prod

$ResourceGroupName = "rg-avdlab-eastus-001"

$Tags = @{
    Environment = $Environment
    Project     = "Azure-AVD-Lab"
    Owner       = "Vinodh"
    CreatedBy   = "PowerShell"
}

$LogFolderPath = "$PSScriptRoot\..\Logs"

$LogFile = "$LogFolderPath\AVD-Lab-Deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

#endregion

#region Resources

$StorageAccountName = 'stavdprofile001'

$HostPoolName = 'hp-avdlab-pooled-001'

$WorkspaceName = 'ws-avdlab-001'

$ApplicationGroupName = 'dag-avdlab-desktop-001'

#endregion

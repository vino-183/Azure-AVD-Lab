# ---------------------------------------------------------------------
# Azure Subscription
# ---------------------------------------------------------------------

$SubscriptionId = "54edc9dc-b9cc-417b-9064-fe06f3ca7fd6"
$TenantId       = "3d05c30c-7909-4145-bed0-2358f2fa3c39"

# ---------------------------------------------------------------------
# Environment
# ---------------------------------------------------------------------

$Environment       = "Dev"
$Location          = "East US"
$ResourceGroupName = "rg-avdlab-eastus-001"

# ---------------------------------------------------------------------
# Storage
# ---------------------------------------------------------------------

$StorageAccountName = "stavdprofile001"

# ---------------------------------------------------------------------
# AVD Variables
# ---------------------------------------------------------------------

$HostPoolName             = "hp-avdlab-pooled-001"

$HostPoolType             = "Pooled"

$LoadBalancerType         = "BreadthFirst"

$PreferredAppGroupType    = "Desktop"

$ApplicationGroupName     = "dag-avdlab-001"

$ApplicationGroupType     = "Desktop"

$WorkspaceName            = "ws-avdlab-001"

$WorkspaceFriendlyName    = "AVD Lab Workspace"

$WorkspaceDescription     = "Azure Virtual Desktop Lab Workspace"

$MaxSessionLimit          = 10

$StartVMOnConnect         = $true

# ---------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------

$LogFolderPath = Join-Path $PSScriptRoot "..\Logs"

$LogFile = Join-Path $LogFolderPath (
    "AVD-Lab-Deployment-{0}.log" -f (Get-Date -Format "yyyyMMdd-HHmmss")
)

# ---------------------------------------------------------------------
# Tags
# ---------------------------------------------------------------------

$Tags = @{
    Environment = $Environment
    Project     = "Azure-AVD-Lab"
    Owner       = "Vinodh"
    CreatedBy   = "PowerShell"
}

# Public IP Configuration
$EnablePublicIP = $false          # Default: No Public IP
$PublicIPSku    = "Standard"
$PublicIPAllocationMethod = "Static"
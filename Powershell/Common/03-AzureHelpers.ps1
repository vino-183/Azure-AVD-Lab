<#
    File    : AzureHelpers.ps1
    Version : 1.0.0
    Purpose : Shared helper functions for the Azure Migration Framework

    Change Log
    ----------
    1.0.0 - Initial release
            - Write-LabLog
            - Write-Step
            - Test-AzLogin
            - Test-Subscription
            - Test-ResourceIfExists
            - Test-VNetIfExists
            - Test-SubnetIfExists
            - Test-PublicIpIfExists
            - Invoke-WithRetry
#>

#---------------------------------------
# Logging
#---------------------------------------
#---------------------------------------    
    #Write-LabLog
#---------------------------------------

. "$PSScriptRoot\00-FrameworkRequirements.ps1"

function Write-LabLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet("INFO","WARNING","ERROR","SUCCESS")]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    switch ($Level) {
        "INFO"    { $color = "Cyan" }
        "WARNING" { $color = "Yellow" }
        "ERROR"   { $color = "Red" }
        "SUCCESS" { $color = "Green" }
    }

    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

#---------------------------------------
    #Write-Step
#---------------------------------------

function Write-Step {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Step
    )

    Write-Host ""
    Write-Host "====================================================" -ForegroundColor Cyan
    Write-Host " $Step" -ForegroundColor Cyan
    Write-Host "====================================================" -ForegroundColor Cyan
}

#---------------------------------------
# Azure Session and Subscription Management Functions
#---------------------------------------
#---------------------------------------
    # Test-AzLogin
#---------------------------------------


#---------------------------------------
    # Test-Subscription
#---------------------------------------
function Test-Subscription {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SubscriptionId
    )

    Set-AzContext -SubscriptionId $SubscriptionId -ErrorAction Stop

    Write-LabLog "Subscription selected successfully." -Level "SUCCESS"
}


function Validate-AzContext {
    [CmdletBinding()]
    param()

    $context = Get-AzContext

    if (-not $context) {
        throw "No active Azure context found. Please run Connect-AzAccount."
    }

    Write-LabLog "Azure context validated: $($context.Account.Id)" -Level Info

    return $context
}
<#
================================================================================
Test-LabPrerequisites
================================================================================
#>
function Test-LabPrerequisites {

    [CmdletBinding()]
    param()
    #--------------------------------------------------
    # Validate PowerShell Version
    #--------------------------------------------------

    if ($PSVersionTable.PSVersion -lt $FrameworkRequirements.PowerShell) {

        Write-LabLog "PowerShell $($PSVersionTable.PSVersion) detected." -Level ERROR
        Write-LabLog "Minimum required version is $($FrameworkRequirements.PowerShell)." -Level ERROR

        return $false
    }

    Write-LabLog "PowerShell $($PSVersionTable.PSVersion) verified." -Level SUCCESS


    #--------------------------------------------------
    # Validate Az Module Versions
    #--------------------------------------------------

    foreach ($module in $FrameworkRequirements.Modules.GetEnumerator()) {

        if (-not (Test-ModuleVersion `
            -ModuleName $module.Key `
            -MinimumVersion $module.Value))
        {
            return $false
        }
    }


    #--------------------------------------------------
    # Import Az Module
    #--------------------------------------------------

    try {

        Import-Module Az -ErrorAction Stop

        Write-LabLog "Az PowerShell module loaded successfully." -Level SUCCESS
    }
    catch {

        Write-LabLog "Unable to load the Az PowerShell module." -Level ERROR

        return $false
    }


    #--------------------------------------------------
    # Validate Azure Authentication
    #--------------------------------------------------

    try {

        Get-AzContext -ErrorAction Stop | Out-Null

        Write-LabLog "Azure authentication verified." -Level SUCCESS
    }
    catch {

        Write-LabLog "You are not connected to Azure." -Level ERROR

        return $false
    }

    return $true
}

#---------------------------------------
# Generic Helpers
#---------------------------------------
    #Get-ResourceIfExists
#---------------------------------------

function Test-ResourceGroupIfExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ResourceGroupName
    )

    Get-AzResourceGroup `
    -ResourceGroupName $ResourceGroupName `
    -ErrorAction SilentlyContinue
}

#---------------------------------------
    #Invoke-WithRetry
#---------------------------------------
function Invoke-WithRetry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$Script,

        [int]$RetryCount = 3,

        [int]$DelaySeconds = 5
    )

    for ($i = 1; $i -le $RetryCount; $i++) {

        try {
            return & $Script
        }
        catch {

            if ($i -eq $RetryCount) {
                throw
            }

            Write-LabLog "Retry $i failed. Waiting $DelaySeconds seconds..." -Level "WARNING"

            Start-Sleep -Seconds $DelaySeconds
        }
    }
}

#---------------------------------------
# Network Helpers
#---------------------------------------
    # Test-VNetIfExists
#---------------------------------------
function Test-VNetIfExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ResourceGroupName,

        [Parameter(Mandatory)]
        [string]$VNetName
    )

    Get-AzVirtualNetwork -Name $VNetName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
}

#---------------------------------------
    #Test-SubnetIfExists
#---------------------------------------

function Test-SubnetIfExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $VirtualNetwork,

        [Parameter(Mandatory)]
        [string]$SubnetName
    )

    return ($VirtualNetwork.Subnets.Name -contains $SubnetName)
}

#---------------------------------------
    #Test-PublicIpIfExists
#---------------------------------------
function Test-PublicIpIfExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ResourceGroupName,

        [Parameter(Mandatory)]
        [string]$PublicIpName
    )

    Get-AzPublicIpAddress -Name $PublicIpName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
}

#---------------------------------------
# Test-NSGIfExists
#---------------------------------------
function Test-NSGIfExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ResourceGroupName,

        [Parameter(Mandatory)]
        [string]$NSGName
    )

    Get-AzNetworkSecurityGroup -Name $NSGName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
}

#---------------------------------------
# Test-ResourceIfExists
#---------------------------------------
function Test-NicIfExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ResourceGroupName,

        [Parameter(Mandatory)]
        [string]$NicName
    )

    Get-AzNetworkInterface -Name $NicName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
}

#---------------------------------------
# Test-VMIfExists
#---------------------------------------
function Test-VMIfExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ResourceGroupName,

        [Parameter(Mandatory)]
        [string]$VMName
    )

    Get-AzVM -Name $VMName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
}

#---------------------------------------
# Test-DiskIfExists
#---------------------------------------
function Test-DiskIfExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ResourceGroupName,

        [Parameter(Mandatory)]
        [string]$DiskName
    )

    Get-AzDisk -Name $DiskName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
}

function Write-DeploymentSummary {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Properties
    )

    Write-Host ""
    Write-Host "Deployment Summary"
    Write-Host "------------------"

    foreach ($item in $Properties.GetEnumerator()) {
        Write-Host ("{0,-20}: {1}" -f $item.Key, $item.Value)
    }

    Write-Host ""
}

function Get-LabCredential {
    [CmdletBinding()]
    param(
        [string]$Message = "Enter local administrator credentials"
    )

    return Get-Credential -Message $Message
}

function Test-ModuleVersion {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName,

        [Parameter(Mandatory)]
        [version]$MinimumVersion
    )

    $module = Get-Module `
        -ListAvailable `
        -Name $ModuleName |
        Sort-Object Version -Descending |
        Select-Object -First 1

    if (-not $module) {

        Write-LabLog "$ModuleName is not installed." -Level ERROR
        return $false
    }

    if ($module.Version -lt $MinimumVersion) {

        Write-LabLog "$ModuleName version $($module.Version) detected. Minimum required version is $MinimumVersion." -Level ERROR
        return $false
    }

    Write-LabLog "$ModuleName version $($module.Version) verified." -Level SUCCESS
    return $true
}

function Test-StorageAccountIfExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$StorageAccountName,

        [Parameter(Mandatory)]
        [string]$ResourceGroupName
    )

    try {
        $null = Get-AzStorageAccount `
            -ResourceGroupName $ResourceGroupName `
            -Name $StorageAccountName `
            -ErrorAction Stop

        return $true
    }
    catch {
        return $false
    }
}

function Test-NetworkInterfaceIfExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$NetworkInterfaceName,

        [Parameter(Mandatory)]
        [string]$ResourceGroupName
    )

    try {
        $null = Get-AzNetworkInterface `
            -Name $NetworkInterfaceName `
            -ResourceGroupName $ResourceGroupName `
            -ErrorAction Stop

        return $true
    }
    catch {
        return $false
    }
}

function Get-LabVmSku
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [string]$Location,

        [Parameter()]
        [int]$vCPU = 2,

        [Parameter()]
        [int]$MemoryGB = 4,

        [Parameter()]
        [switch]$RequirePremiumStorage
    )

    Write-LabLog "Searching available VM SKUs in '$Location'..." -Level Info

    # Normalize location (e.g. "East US" -> "eastus")
$NormalizedLocation = ($Location -replace '\s','').ToLower()

$Skus = $Skus | Where-Object {

    $Locations = $_.Locations | ForEach-Object {
        ($_ -replace '\s','').ToLower()
    }

    $Locations -contains $NormalizedLocation
}
    # Step 1 – Retrieve all SKUs
    $Skus = Get-AzComputeResourceSku
    Write-LabLog "Total SKUs returned: $($Skus.Count)" -Level Info

    # Step 2 – Filter to virtual machines
    $Skus = $Skus | Where-Object {
        $_.ResourceType -eq "virtualMachines"
    }
    Write-LabLog "Virtual Machine SKUs: $($Skus.Count)" -Level Info

    # Step 3 – Filter by location
# Step 3 – Filter by location
$NormalizedLocation = ($Location -replace '\s','').ToLower()

$Skus = $Skus | Where-Object {

    $SkuLocations = $_.Locations | ForEach-Object {
        ($_ -replace '\s','').ToLower()
    }

    $SkuLocations -contains $NormalizedLocation
}

Write-LabLog "$Location SKUs: $($Skus.Count)" -Level Info

    # Step 4 – Filter x64 architecture
    $Skus = $Skus | Where-Object {
        ($_.Capabilities | Where-Object Name -eq "CpuArchitectureType").Value -contains "x64"
    }
    Write-LabLog "x64 SKUs: $($Skus.Count)" -Level Info

    # Step 5 – Remove restricted SKUs
    $Skus = $Skus | Where-Object {
        $_.Restrictions.Count -eq 0
    }
    Write-LabLog "Unrestricted SKUs: $($Skus.Count)" -Level Info

    # Candidate selection
    $Candidates = foreach ($Sku in $Skus)
    {
        $Cpu       = ($Sku.Capabilities | Where-Object Name -eq "vCPUs").Value
        $Memory    = ($Sku.Capabilities | Where-Object Name -eq "MemoryGB").Value
        $PremiumIO = ($Sku.Capabilities | Where-Object Name -eq "PremiumIO").Value

        if (-not $Cpu -or -not $Memory) { continue }

        if ($RequirePremiumStorage -and $PremiumIO -ne "True") { continue }

        if ([int]$Cpu -eq $vCPU -and [double]$Memory -ge $MemoryGB)
        {
            [PSCustomObject]@{
                Name      = $Sku.Name
                MemoryGB  = [double]$Memory
                PremiumIO = $PremiumIO
            }
        }
    }

    Write-LabLog "Candidate SKUs after vCPU/Memory filter: $($Candidates.Count)" -Level Info

    if (-not $Candidates)
    {
        throw "No suitable VM SKU found in '$Location'."
    }

    # Rank preferred VM families
    $FamilyOrder = @("Standard_D","Standard_B","Standard_E","Standard_F","Standard_A")

    foreach ($Family in $FamilyOrder)
    {
        $Match = $Candidates |
            Where-Object { $_.Name -like "$Family*" } |
            Sort-Object MemoryGB |
            Select-Object -First 1

        if ($Match)
        {
            Write-LabLog "Selected VM SKU: $($Match.Name)" -Level Success
            return $Match.Name
        }
    }

    # Fallback if no preferred family matched
    $Selected = $Candidates | Sort-Object MemoryGB | Select-Object -First 1
    Write-LabLog "Selected VM SKU: $($Selected.Name)" -Level Success

    return $Selected.Name
}

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
function Test-AzLogin {
    [CmdletBinding()]
    param()
    try {
        $null = Get-AzContext -ErrorAction Stop

        Write-LabLog "Azure session found." -Level "SUCCESS"
    }
    catch {
        Write-LabLog "No Azure session found. Signing in..." -Level "WARNING"
        Connect-AzAccount
    }
}

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


<#
================================================================================
Test-LabPrerequisites
================================================================================
#>
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

function Test-LabPrerequisites {

    [CmdletBinding()]
    param()

    Write-LabLog "Validating prerequisites..."

    # Verify Az PowerShell module
    try {
        if (-not (Get-Module -Name Az)) {
    Import-Module Az -ErrorAction Stop
}

Write-LabLog "Az PowerShell module loaded successfully." -Level SUCCESS
    }
    catch {
        Write-LabLog "Unable to load the Az PowerShell module." -Level ERROR
        return $false
    }

    # Verify Azure Login
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
        [Microsoft.Azure.Commands.Network.Models.PSVirtualNetwork]$VirtualNetwork,

        [Parameter(Mandatory)]
        [string]$SubnetName
    )

    $VirtualNetwork.Subnets | Where-Object { $_.Name -eq $SubnetName }
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
<#
    Title      : 05-New-NetworkInterface.ps1
    Author     : vinodh
    Date       : 2026-07-09
    Description: Module script to create a new Azure Network Interface.
#>

[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
param()

# import common modules
. "$PSScriptRoot\..\Common\01-GlobalVariables.ps1"
. "$PSScriptRoot\..\Common\02-NetworkVariables.ps1"
. "$PSScriptRoot\..\Common\03-AzureHelpers.ps1"

# validate prerequisites
Write-LabLog "Validating prerequisites..." -Level INFO
if (-not (Test-LabPrerequisites)) {
    Write-LabLog "Prerequisite validation failed. Deployment aborted." -Level ERROR
    throw "Prerequisite validation failed."
}

# verify resource group exists
if (-not (Test-ResourceGroupIfExists -ResourceGroupName $ResourceGroupName)) {
    Write-LabLog "Resource group '$ResourceGroupName' does not exist. Deployment aborted." -Level ERROR
    throw "Resource group validation failed."
}

# verify virtual network exists
if (-not (Test-VNetIfExists -VNetName $VNetName -ResourceGroupName $ResourceGroupName)) {
    Write-LabLog "Virtual network '$VNetName' does not exist in resource group '$ResourceGroupName'. Deployment aborted." -Level ERROR
    throw "Virtual network validation failed."
}

# retrieve the virtual network object
$vnet = Get-AzVirtualNetwork -Name $VNetName -ResourceGroupName $ResourceGroupName

# Explicitly define the subnet for session hosts
$SubnetName = "snet-sessionhosts"

# ✅ FIXED: subnet validation now uses vnet object
if (-not (Test-SubnetIfExists -VirtualNetwork $vnet -SubnetName $SubnetName)) {
    Write-LabLog "Subnet '$SubnetName' does not exist in Virtual Network '$VNetName'." -Level ERROR
    throw "Subnet validation failed."
}

# retrieve subnet object
$subnet = Get-AzVirtualNetworkSubnetConfig -Name $SubnetName -VirtualNetwork $vnet

# validate and retrieve NSG if specified
$nsg = $null
if ($NSGName) {
    if (-not (Test-NSGIfExists -NSGName $NSGName -ResourceGroupName $ResourceGroupName)) {
        Write-LabLog "Network Security Group '$NSGName' does not exist in resource group '$ResourceGroupName'. Deployment aborted." -Level ERROR
        throw "Network Security Group validation failed."
    }
    $nsg = Get-AzNetworkSecurityGroup -Name $NSGName -ResourceGroupName $ResourceGroupName
}

# check whether the network interface already exists
Write-LabLog "Checking if Network Interface '$NetworkInterfaceName' exists in Resource Group '$ResourceGroupName'..." -Level INFO
$nic = Get-AzNetworkInterface -Name $NetworkInterfaceName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
if ($nic) {
    Write-LabLog "Network Interface '$NetworkInterfaceName' already exists. Skipping deployment." -Level SUCCESS
}
else {
    if ($PSCmdlet.ShouldProcess($NetworkInterfaceName, "Create Network Interface")) {
        try {
            Write-LabLog "Creating Network Interface '$NetworkInterfaceName'..." -Level INFO

            $nicParams = @{
    Name                   = $NetworkInterfaceName
    ResourceGroupName      = $ResourceGroupName
    Location               = $Location
    SubnetId               = $subnet.Id
    EnableIPForwarding     = $EnableIPForwarding
    EnableAcceleratedNetworking = $EnableAcceleratedNetworking
}
        if ($EnableIPForwarding) {
    $nicParams.EnableIPForwarding = $true
}
            if ($nsg) {
                $nicParams.NetworkSecurityGroupId = $nsg.Id
            }

            $nic = New-AzNetworkInterface @nicParams -ErrorAction Stop

            Write-LabLog "Network Interface created successfully." -Level SUCCESS
        }
        catch {
            Write-LabLog "Failed to create Network Interface '$NetworkInterfaceName'." -Level ERROR
            Write-LabLog $_ -Level ERROR
            throw
        }
    }
}

# ✅ FIXED: Verification only runs if not in WhatIf mode
if (-not $WhatIfPreference) {
    Write-LabLog "Verifying the Network Interface '$NetworkInterfaceName'..." -Level INFO
    $nic = Get-AzNetworkInterface -Name $NetworkInterfaceName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    if ($nic) {
        Write-LabLog "Network Interface '$NetworkInterfaceName' verified successfully." -Level SUCCESS
    }
    else {
        Write-LabLog "Failed to verify Network Interface '$NetworkInterfaceName'." -Level ERROR
        throw "Failed to verify Network Interface '$NetworkInterfaceName'."
    }
}
else {
    Write-LabLog "WhatIf mode detected. Skipping deployment verification." -Level INFO
}

# Deployment Summary
Write-DeploymentSummary -Properties @{
    "Resource Group"     = $ResourceGroupName
    "Location"           = $Location
    "Virtual Network"    = $VNetName
    "Subnet"             = $SubnetName
    "Network Interface"  = $NetworkInterfaceName
    "NSG"                = if ($nsg) { $NSGName } else { "None" }
    "Provisioning"       = if ($WhatIfPreference) { "WhatIf (Not Deployed)" } else { $nic.ProvisioningState }
}

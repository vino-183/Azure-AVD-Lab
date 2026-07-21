<#
.SYNOPSIS
    Create a new Azure Network Interface for the Domain Controller.

.DESCRIPTION
    Uses individual variables defined in VMVariables.ps1.
    Deploys a NIC using the role’s network configuration.

.AUTHOR
    Vinodh

.DATE
    2026-07-13
#>

[CmdletBinding(SupportsShouldProcess)]
param()

# Import common modules
. "D:\Cloud-Labs\Azure-AVD-Lab\Powershell\01-Common\Import-Common.ps1"

# Validate prerequisites
Write-LabLog "Validating prerequisites..." -Level INFO
if (-not (Test-LabPrerequisites)) {
    throw "Prerequisite validation failed."
}

# Verify resource group exists
if (-not (Test-ResourceGroupIfExists -ResourceGroupName $ResourceGroupName)) {
    throw "Resource group '$ResourceGroupName' does not exist."
}

# Verify virtual network exists
if (-not (Test-VNetIfExists -VNetName $VNetName -ResourceGroupName $ResourceGroupName)) {
    throw "Virtual network '$VNetName' does not exist in resource group '$ResourceGroupName'."
}

# Retrieve the virtual network object
$vnet = Get-AzVirtualNetwork -Name $VNetName -ResourceGroupName $ResourceGroupName

# Validate subnet
if (-not (Test-SubnetIfExists -VirtualNetwork $vnet -SubnetName $SubnetName)) {
    throw "Subnet '$SubnetName' does not exist in Virtual Network '$VNetName'."
}

# Retrieve subnet object
$subnet = Get-AzVirtualNetworkSubnetConfig -Name $SubnetName -VirtualNetwork $vnet

# Validate and retrieve NSG if specified
$nsg = $null
if ($NSGName) {
    if (-not (Test-NSGIfExists -NSGName $NSGName -ResourceGroupName $ResourceGroupName)) {
        throw "Network Security Group '$NSGName' does not exist in resource group '$ResourceGroupName'."
    }
    $nsg = Get-AzNetworkSecurityGroup -Name $NSGName -ResourceGroupName $ResourceGroupName
}

# Check whether the NIC already exists
Write-LabLog "Checking if Network Interface '$NICName' exists..." -Level INFO
$nic = Get-AzNetworkInterface -Name $NICName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue

if ($nic) {
    Write-LabLog "Network Interface '$NICName' already exists. Skipping deployment." -Level SUCCESS
}
else {
    if ($PSCmdlet.ShouldProcess($NICName, "Create Network Interface")) {
        try {
            Write-LabLog "Creating Network Interface '$NICName'..." -Level INFO

            $nicParams = @{
                Name                        = $NICName
                ResourceGroupName           = $ResourceGroupName
                Location                    = $Location
                SubnetId                    = $subnet.Id
                PrivateIpAddress            = $PrivateIPAddress
                EnableIPForwarding          = $false
                EnableAcceleratedNetworking = $true
            }

            if ($nsg) {
                $nicParams.NetworkSecurityGroupId = $nsg.Id
            }

            $nic = New-AzNetworkInterface @nicParams -ErrorAction Stop

            Write-LabLog "Network Interface '$NICName' created successfully." -Level SUCCESS
        }
        catch {
            Write-LabLog "Failed to create Network Interface '$NICName'." -Level ERROR
            Write-LabLog $_.Exception.Message -Level ERROR
            throw
        }
    }
}

# Verification
if (-not $WhatIfPreference) {
    $nic = Get-AzNetworkInterface -Name $NICName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    if ($nic) {
        Write-LabLog "Network Interface '$NICName' verified successfully." -Level SUCCESS
    }
    else {
        throw "Failed to verify Network Interface '$NICName'."
    }
}
else {
    Write-LabLog "WhatIf mode detected. Skipping deployment verification." -Level INFO
}

# Deployment Summary
Write-DeploymentSummary -Properties @{
    "Network Interface" = $NICName
    "Private IP"        = $PrivateIPAddress
    "Subnet"            = $SubnetName
    "Virtual Network"   = $VNetName
    "Provisioning"      = if ($WhatIfPreference) { "WhatIf" } else { $nic.ProvisioningState }
}

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
if (-not (Test-SubnetIfExists -VirtualNetwork $vnet -SubnetName $DCSubnet)) {
    throw "Subnet '$DCSubnet' does not exist in Virtual Network '$VNetName'."
}

# Retrieve subnet object
$subnet = Get-AzVirtualNetworkSubnetConfig -Name $DCSubnet -VirtualNetwork $vnet

# Validate and retrieve NSG if specified
$nsg = $null
if ($DCNSGName) {
    if (-not (Test-NSGIfExists -NSGName $DCNSGName -ResourceGroupName $ResourceGroupName)) {
        throw "Network Security Group '$DCNSGName' does not exist in resource group '$ResourceGroupName'."
    }
    $nsg = Get-AzNetworkSecurityGroup -Name $DCNSGName -ResourceGroupName $ResourceGroupName
}

# Check whether the NIC already exists
Write-LabLog "Checking if Network Interface '$DCNICName' exists..." -Level INFO
$nic = Get-AzNetworkInterface -Name $DCNICName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue

if ($nic) {
    Write-LabLog "Network Interface '$DCNICName' already exists. Skipping deployment." -Level SUCCESS
}
else {
    if ($PSCmdlet.ShouldProcess($DCNICName, "Create Network Interface")) {
        try {
            Write-LabLog "Creating Network Interface '$DCNICName'..." -Level INFO

            $nicParams = @{
                Name                        = $DCNICName
                ResourceGroupName           = $ResourceGroupName
                Location                    = $Location
                SubnetId                    = $subnet.Id
                PrivateIpAddress            = $DCPrivateIP
                EnableIPForwarding          = $false
                EnableAcceleratedNetworking = $true
            }

            if ($nsg) {
                $nicParams.NetworkSecurityGroupId = $nsg.Id
            }

            $nic = New-AzNetworkInterface @nicParams -ErrorAction Stop

            Write-LabLog "Network Interface '$DCNICName' created successfully." -Level SUCCESS
        }
        catch {
            Write-LabLog "Failed to create Network Interface '$DCNICName'." -Level ERROR
            Write-LabLog $_.Exception.Message -Level ERROR
            throw
        }
    }
}

# Verification
if (-not $WhatIfPreference) {
    $nic = Get-AzNetworkInterface -Name $DCNICName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    if ($nic) {
        Write-LabLog "Network Interface '$DCNICName' verified successfully." -Level SUCCESS
    }
    else {
        throw "Failed to verify Network Interface '$DCNICName'."
    }
}
else {
    Write-LabLog "WhatIf mode detected. Skipping deployment verification." -Level INFO
}

# Deployment Summary
Write-DeploymentSummary -Properties @{
    "Network Interface" = $DCNICName
    "Private IP"        = $DCPrivateIP
    "Subnet"            = $DCSubnet
    "Virtual Network"   = $VNetName
    "Provisioning"      = if ($WhatIfPreference) { "WhatIf" } else { $nic.ProvisioningState }
}

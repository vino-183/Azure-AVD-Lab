<#
.SYNOPSIS
    Create a new Azure Network Interface for the selected lab role.

.DESCRIPTION
    Reads the VM profile from VMCatalog based on the role provided.
    Deploys a NIC using the profile’s network configuration.

.AUTHOR
    Vinodh

.DATE
    2026-07-13
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$Role
)

# Import common modules
. "$PSScriptRoot\..\01-Common\Import-Common.ps1"

# Validate role
if (-not $VMCatalog.ContainsKey($Role)) {
    throw "Unknown VM Role '$Role'."
}

# Retrieve profile
$VMProfile = $VMCatalog[$Role]
$Network   = $VMProfile.Network

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
$SubnetName = $Network.SubnetName
if (-not (Test-SubnetIfExists -VirtualNetwork $vnet -SubnetName $SubnetName)) {
    throw "Subnet '$SubnetName' does not exist in Virtual Network '$VNetName'."
}

# Retrieve subnet object
$subnet = Get-AzVirtualNetworkSubnetConfig -Name $SubnetName -VirtualNetwork $vnet

# Validate and retrieve NSG if specified
$nsg = $null
if ($Network.NSGName) {
    if (-not (Test-NSGIfExists -NSGName $Network.NSGName -ResourceGroupName $ResourceGroupName)) {
        throw "Network Security Group '$($Network.NSGName)' does not exist in resource group '$ResourceGroupName'."
    }
    $nsg = Get-AzNetworkSecurityGroup -Name $Network.NSGName -ResourceGroupName $ResourceGroupName
}

# Check whether the NIC already exists
Write-LabLog "Checking if Network Interface '$($Network.NICName)' exists..." -Level INFO
$nic = Get-AzNetworkInterface -Name $Network.NICName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue

if ($nic) {
    Write-LabLog "Network Interface '$($Network.NICName)' already exists. Skipping deployment." -Level SUCCESS
}
else {
    if ($PSCmdlet.ShouldProcess($Network.NICName, "Create Network Interface")) {
        try {
            Write-LabLog "Creating Network Interface '$($Network.NICName)'..." -Level INFO

            $nicParams = @{
                Name                        = $Network.NICName
                ResourceGroupName           = $ResourceGroupName
                Location                    = $Location
                SubnetId                    = $subnet.Id
                PrivateIpAddress            = $Network.PrivateIP
                EnableIPForwarding          = $Network.EnableIPForwarding
                EnableAcceleratedNetworking = $Network.EnableAcceleratedNetworking
            }

            if ($nsg) {
                $nicParams.NetworkSecurityGroupId = $nsg.Id
            }

            $nic = New-AzNetworkInterface @nicParams -ErrorAction Stop

            Write-LabLog "Network Interface '$($Network.NICName)' created successfully." -Level SUCCESS
        }
        catch {
            Write-LabLog "Failed to create Network Interface '$($Network.NICName)'." -Level ERROR
            Write-LabLog $_.Exception.Message -Level ERROR
            throw
        }
    }
}

# Verification
if (-not $WhatIfPreference) {
    $nic = Get-AzNetworkInterface -Name $Network.NICName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    if ($nic) {
        Write-LabLog "Network Interface '$($Network.NICName)' verified successfully." -Level SUCCESS
    }
    else {
        throw "Failed to verify Network Interface '$($Network.NICName)'."
    }
}
else {
    Write-LabLog "WhatIf mode detected. Skipping deployment verification." -Level INFO
}

# Deployment Summary
Write-DeploymentSummary -Properties @{
    "Role"              = $Role
    "Network Interface" = $Network.NICName
    "Private IP"        = $Network.PrivateIP
    "Subnet"            = $Network.SubnetName
    "Virtual Network"   = $VNetName
    "Provisioning"      = if ($WhatIfPreference) { "WhatIf" } else { $nic.ProvisioningState }
}

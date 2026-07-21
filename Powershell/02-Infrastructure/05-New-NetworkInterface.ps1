<#
.SYNOPSIS
    Create a new Azure Network Interface.

.DESCRIPTION
    Deploys a NIC using the VM’s network configuration.
    Optionally creates and attaches a Public IP if enabled.
    Supports static or dynamic IP assignment, configurable features,
    and robust verification.

.AUTHOR
    Vinodh

.DATE
    2026-07-21
#>

[CmdletBinding(SupportsShouldProcess)]
param()

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

# Initialize Public IP reference
$PublicIP = $null

# Check whether the NIC already exists
Write-LabLog "Checking if Network Interface '$NICName' exists..." -Level INFO
$nic = Get-AzNetworkInterface -Name $NICName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue

if ($nic) {
    Write-LabLog "Network Interface '$NICName' already exists. Skipping deployment." -Level SUCCESS

    if ($EnablePublicIP) {
        $PublicIP = Get-AzPublicIpAddress -Name $PublicIPName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    }
}
else {
    if ($PSCmdlet.ShouldProcess($NICName, "Create Network Interface")) {
        try {
            # Optional Public IP (idempotent)
            if ($EnablePublicIP) {
                $PublicIP = Get-AzPublicIpAddress -Name $PublicIPName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
                if (-not $PublicIP) {
                    $PublicIP = New-LabPublicIPAddress `
                        -ResourceGroupName $ResourceGroupName `
                        -Location $Location `
                        -PublicIPName $PublicIPName
                }
            }

            # NIC parameters
            $nicParams = @{
                Name                        = $NICName
                ResourceGroupName           = $ResourceGroupName
                Location                    = $Location
                SubnetId                    = $subnet.Id
                EnableIPForwarding          = $EnableIPForwarding
                EnableAcceleratedNetworking = $EnableAcceleratedNetworking
                PrivateIpAddressVersion     = "IPv4"
                PrivateIpAllocationMethod   = $PrivateIPAllocationMethod
            }

            if ($PrivateIPAllocationMethod -eq "Static" -and $PrivateIPAddress) {
                $nicParams.PrivateIpAddress = $PrivateIPAddress
            }

            if ($nsg) {
                $nicParams.NetworkSecurityGroupId = $nsg.Id
            }

            if ($PublicIP) {
                $nicParams.PublicIpAddressId = $PublicIP.Id
            }

            $nic = New-AzNetworkInterface @nicParams -ErrorAction Stop

            # Verify Public IP attachment
            if ($EnablePublicIP -and -not $nic.IpConfigurations[0].PublicIpAddress) {
                throw "Public IP was not attached to the Network Interface."
            }

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

    if ($PublicIP -and $PublicIP.ProvisioningState -ne "Succeeded") {
        throw "Public IP '$($PublicIP.Name)' is not in a Succeeded state."
    }
}
else {
    Write-LabLog "WhatIf mode detected. Skipping deployment verification." -Level INFO
}

# Deployment Summary
$AssignedPrivateIP = if ($nic) { $nic.IpConfigurations[0].PrivateIpAddress } else { $PrivateIPAddress }

Write-DeploymentSummary -Properties @{
    "Network Interface" = $NICName
    "Private IP"        = $AssignedPrivateIP
    "Public IP"         = if ($PublicIP) { "$($PublicIP.Name) ($($PublicIP.IpAddress))" } else { "None" }
    "Subnet"            = $SubnetName
    "Virtual Network"   = $VNetName
    "NSG"               = if ($nsg) { $nsg.Name } else { "None" }
    "Accelerated Net"   = $EnableAcceleratedNetworking
    "IP Forwarding"     = $EnableIPForwarding
    "Provisioning"      = if ($WhatIfPreference) { "WhatIf" } else { $nic.ProvisioningState }
}

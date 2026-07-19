[CmdletBinding(SupportsShouldProcess = $true)]
param ()

# Import common modules
. "D:\Cloud-Labs\Azure-AVD-Lab\Powershell\01-Common\Import-Common.ps1"

# Validate prerequisites
if (-not (Test-LabPrerequisites)) {
    Write-LabLog "Prerequisite validation failed. Deployment aborted." -Level ERROR
    throw "Prerequisite validation failed."
}

# Verify Resource Group exists
Write-LabLog "Checking if Resource Group '$ResourceGroupName' exists..."
$resourceGroup = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue

if (-not $resourceGroup) {
    Write-LabLog "Resource Group '$ResourceGroupName' does not exist." -Level ERROR
    throw "Resource Group '$ResourceGroupName' does not exist."
}

# Verify Virtual Network
Write-LabLog "Checking if Virtual Network '$VNetName' exists in Resource Group '$ResourceGroupName'..."
$vnet = Get-AzVirtualNetwork -Name $VNetName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue

if (-not $vnet) {
    Write-LabLog "Virtual Network '$VNetName' not found." -Level WARNING

    if ($PSCmdlet.ShouldProcess($VNetName, "Create Virtual Network")) {
        try {
            # Build subnet configurations
            $subnets = foreach ($subnetName in $SubnetNames) {
                New-AzVirtualNetworkSubnetConfig `
                    -Name $subnetName `
                    -AddressPrefix $SubnetAddressSpaces[$subnetName]
            }

            # Create Virtual Network
            Write-LabLog "Creating Virtual Network '$VNetName' in Resource Group '$ResourceGroupName'..."
            $vnet = New-AzVirtualNetwork `
                -Name $VNetName `
                -ResourceGroupName $ResourceGroupName `
                -Location $Location `
                -AddressPrefix $AddressSpace `
                -Subnet $subnets `
                -Tag $Tags `
                -ErrorAction Stop

            Write-LabLog "Virtual Network created successfully." -Level SUCCESS
        }
        catch {
            Write-LabLog "Failed to create Virtual Network '$VNetName'." -Level ERROR
            Write-LabLog $_ -Level ERROR
            throw
        }
    }
}

# Final validation
if (-not $vnet) {
    if ($WhatIfPreference) {
        Write-LabLog "WhatIf validation completed successfully." -Level SUCCESS
    }
    else {
        throw "Virtual Network verification failed."
    }
}
else {
    Write-LabLog "Virtual Network verification completed successfully." -Level SUCCESS
}

# Deployment summary
Write-LabLog "Deployment Summary:"
Write-LabLog "  - Resource Group: $ResourceGroupName"
Write-LabLog "  - Virtual Network: $VNetName"
Write-LabLog "  - Location: $Location"
Write-LabLog "  - Address Space: $AddressSpace"
foreach ($subnetName in $SubnetNames) {
    Write-LabLog "  - Subnet: $subnetName ($($SubnetAddressSpaces[$subnetName]))"
}
Write-LabLog "  - Status: Success"
Write-LabLog "  - Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

return $vnet

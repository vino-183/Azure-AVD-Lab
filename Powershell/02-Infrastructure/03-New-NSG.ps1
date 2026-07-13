[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param()

# Import common variables and helper functions
. "$PSScriptRoot\..\01-Common\Import-Common.ps1"

foreach ($moduleName in $requiredModules) {
    if (-not (Get-Module -ListAvailable -Name $moduleName)) {
        throw "Required PowerShell module '$moduleName' is not installed."
    }

    Import-Module $moduleName -ErrorAction Stop
}

# Validate Prerequisites
if (-not (Get-AzContext -ErrorAction SilentlyContinue)) {
    throw 'No active Azure context found. Run Connect-AzAccount before running this script.'
}

# Verify Resource Group
$resourceGroup = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
if (-not $resourceGroup) {
    throw "Resource group '$ResourceGroupName' was not found."
}

if (-not $Location) {
    $Location = $resourceGroup.Location
}

# Check Existing NSG
$existingNsg = Get-AzNetworkSecurityGroup -Name $NSGName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
if ($existingNsg) {
    Write-Host "NSG '$NSGName' already exists in resource group '$ResourceGroupName'. Returning existing object."
    return $existingNsg
}

# ShouldProcess
$target = "NSG '$NSGName' in resource group '$ResourceGroupName'"
$createParams = @{
    Name                = $NSGName
    ResourceGroupName   = $ResourceGroupName
    Location            = $Location
}

if ($PSBoundParameters.ContainsKey('Tags')) {
    $createParams.Tag = $Tags
}

if ($PSCmdlet.ShouldProcess($target, 'Create NSG')) {
    try {
        $newNsg = New-AzNetworkSecurityGroup @createParams -ErrorAction Stop
    }
    catch {
        throw "Failed to create NSG '$NSGName'. $($_.Exception.Message)"
    }
}
else {
    return $null
}

# Verify NSG
$verifiedNsg = Get-AzNetworkSecurityGroup -Name $NSGName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
if (-not $verifiedNsg) {
    throw "NSG '$NSGName' was not found after creation."
}

# Deployment Summary
Write-Host 'Deployment Summary'
Write-Host '------------------'
Write-Host "NSG Name         : $($verifiedNsg.Name)"
Write-Host "Resource Group   : $($verifiedNsg.ResourceGroupName)"
Write-Host "Location         : $($verifiedNsg.Location)"
Write-Host "ProvisioningState: $($verifiedNsg.ProvisioningState)"
Write-Host "Id               : $($verifiedNsg.Id)"

# Return NSG Object
return $verifiedNsg

<#
 .SYNOPSIS
    Creates a new session host virtual machine in Azure Virtual Desktop (AVD) environment.
 .DESCRIPTION
    This script creates a new session host VM in an Azure Virtual Desktop (AVD) environment.
    It configures the VM using the specified parameters, including name, size, image, OS disk, and network settings.
 .AUTHOR
    Vinodh
 .DATE
    2026-07-09
 .NOTES
    Part of the Azure-AVD-Lab project. Assumes prerequisites (RG, VNet, Subnet, NIC, Storage) already exist.
 .EXAMPLE
    .\06-New-SessionHostVM.ps1 -WhatIf
#>

#CmdletBinding(SupportsShouldProcess)
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
param()

# Import common modules
. "$PSScriptRoot\..\Common\01-CommonVariables.ps1"
. "$PSScriptRoot\..\Common\02-NetworkVariables.ps1"
. "$PSScriptRoot\..\Common\03-AzureHelpers.ps1"
. "$PSScriptRoot\..\Common\04-VM-Variables.ps1"
. "$PSScriptRoot\..\Common\05-StorageVariables.ps1"

# Validate prerequisites
if (-not (Test-LabPrerequisites)) {
    throw "Prerequisite validation failed."
}

# Resource group validation
if (-not (Test-ResourceGroupIfExists -ResourceGroupName $ResourceGroupName)) {
    throw "Resource group validation failed."
}

# VNet validation
if (-not (Test-VNetIfExists -VNetName $VNetName -ResourceGroupName $ResourceGroupName)) {
    throw "Virtual network validation failed."
}

$vnet = Get-AzVirtualNetwork -Name $VNetName -ResourceGroupName $ResourceGroupName

# Subnet validation
$vnet = Get-AzVirtualNetwork -Name $VNetName -ResourceGroupName $ResourceGroupName
if (-not (Test-SubnetIfExists -VirtualNetwork $vnet -SubnetName $SubnetName)) {
    throw "Subnet validation failed."
}

# NSG validation
if ($NSGName) {
    if (-not (Test-NSGIfExists -NSGName $NSGName -ResourceGroupName $ResourceGroupName)) {
        throw "NSG validation failed."
    }
}

# Storage validation
if ($StorageAccountName) {
    if (-not (Test-StorageAccountIfExists -StorageAccountName $StorageAccountName -ResourceGroupName $ResourceGroupName)) {
        throw "Storage account validation failed."
    }
}

# NIC validation
if ($NetworkInterfaceName) {
    if (-not (Test-NetworkInterfaceIfExists -NetworkInterfaceName $NetworkInterfaceName -ResourceGroupName $ResourceGroupName)) {
        throw "NIC validation failed."
    }
}

# VM existence check
if (Get-AzVM -Name $VMName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue) {
    Write-LabLog "VM '$VMName' already exists." -Level WARNING

throw "VM already exists."
}

# Prompt for credentials
if ($PSCmdlet.ShouldProcess($VMName, "Create Session Host VM")) {
# Determine the best available VM SKU
Write-LabLog "Searching for an available VM SKU..." -Level Info

$VMSize = Get-LabVmSku `
    -Location $Location `
    -vCPU 2 `
    -MemoryGB 4 `
    -RequirePremiumStorage

Write-LabLog "Using VM Size '$VMSize'." -Level Info

# Prompt for credentials only after a valid SKU is found
$AdminCredential = Get-LabCredential -Message "Enter credentials for the new session host VM '$VMName'"

# Build VM configuration
$vmConfig = New-AzVMConfig -VMName $VMName -VMSize $VMSize
$vmConfig = Set-AzVMOperatingSystem -VM $vmConfig -Windows -ComputerName $ComputerName -Credential $AdminCredential -ProvisionVMAgent -EnableAutoUpdate
$vmConfig = Set-AzVMSourceImage -VM $vmConfig -PublisherName $ImagePublisher -Offer $ImageOffer -Skus $ImageSku -Version $ImageVersion
$vmConfig = Set-AzVMOSDisk -VM $vmConfig -Name $OSDiskName -CreateOption FromImage -StorageAccountType $OSDiskType

# Disable Boot Diagnostics to prevent Azure from creating a new stbootdiagxxxxx storage account for every VM
$vmConfig = Set-AzVMBootDiagnostic `
    -VM $vmConfig `
    -Disable

# Attach NIC
$nic = Get-AzNetworkInterface -Name $NetworkInterfaceName -ResourceGroupName $ResourceGroupName
$vmConfig = Add-AzVMNetworkInterface -VM $vmConfig -Id $nic.Id

# Create VM

Write-LabLog "Creating Session Host VM '$VMName'..."

New-AzVM -ResourceGroupName $ResourceGroupName -Location $Location -VM $vmConfig -ErrorAction Stop

Write-LabLog "VM '$VMName' created successfully." -Level SUCCESS
}

else
{
    Write-LabLog "WhatIf mode detected. Skipping actual VM creation." -Level Info
}

# Verification only if not WhatIf
if (-not $WhatIfPreference) {
    $vm = Get-AzVM -Name $VMName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    if ($vm -and $vm.ProvisioningState -eq "Succeeded") {
        Write-LabLog "VM '$VMName' verified successfully. Provisioning state is Succeeded." -Level SUCCESS
    }
    else {
        Write-LabLog "VM '$VMName' verification failed. Provisioning state is $($vm.ProvisioningState)." -Level ERROR
        throw "VM creation failed or provisioning did not succeed."
    }
}
else {
    Write-LabLog "WhatIf mode detected. Skipping deployment verification." -Level INFO
}


# Deployment Summary
$summary = @{
    "VM Name" = $VMName
    "Resource Group" = $ResourceGroupName
    "Location" = $Location
    "VM Size" = $VMSize
    "OS Disk Type" = $OSDiskType
    "Image" = "$ImagePublisher $ImageOffer $ImageSku $ImageVersion"
    "NIC Name" = $NetworkInterfaceName
    "Subnet Name" = $SubnetName
    "VNet Name" = $VNetName
}

Write-DeploymentSummary -Properties $summary
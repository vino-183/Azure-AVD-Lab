<#
 .SYNOPSIS
    Creates a new Azure virtual machine in Azure Virtual Desktop (AVD) environment.
 .DESCRIPTION
    This script creates a new Virtual Machine.
    It configures the VM using the specified parameters, including name, size, image, OS disk, and network settings.
 .AUTHOR
    Vinodh
 .DATE
    2026-07-09
 .NOTES
    Part of the Azure-AVD-Lab project. Assumes prerequisites (RG, VNet, Subnet, NIC, Storage) already exist.
 .EXAMPLE
    .\06-New-VirtualMachine.ps1 -WhatIf
#>

#CmdletBinding(SupportsShouldProcess)
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
param()

# Import common modules
. "$PSScriptRoot\..\01-Common\Import-Common.ps1"

# Load the Session Host profile from the VM Catalog
$VMProfile = $VMCatalog.SessionHost

$VM      = $VMProfile.VM
$Network = $VMProfile.Network
$Image   = $VMProfile.Image
$OSDisk  = $VMProfile.OSDisk
$Tags    = $VMProfile.Tags

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
if (Get-AzVM -Name $VM.Name -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue) {
    Write-LabLog "VM '$VM.Name' already exists." -Level WARNING

throw "VM already exists."
}

# Prompt for credentials
if ($PSCmdlet.ShouldProcess($VM.Name, "Create Virtual Machine")) {
# Determine the best available VM SKU
Write-LabLog "Searching for an available VM SKU..." -Level Info

$VM.Size = Get-LabVmSku `
    -Location $Location `
    -vCPU 2 `
    -MemoryGB 4 `
    -RequirePremiumStorage

Write-LabLog "Using VM Size '$VM.Size'." -Level Info

# Prompt for credentials only after a valid SKU is found
$AdminCredential = Get-LabCredential -Message "Enter credentials for the new Virtual Machine '$VM.Name'"

# Build VM configuration
$vmConfig = New-AzVMConfig -VMName $VM.Name -VMSize $VM.Size
$vmConfig = Set-AzVMOperatingSystem -VM $vmConfig -Windows -ComputerName $ComputerName -Credential $AdminCredential -ProvisionVMAgent -EnableAutoUpdate
$vmConfig = Set-AzVMSourceImage -VM $vmConfig -PublisherName $Image.Publisher -Offer $Image.Offer -Skus $Image.SKU -Version $Image.Version
$vmConfig = Set-AzVMOSDisk -VM $vmConfig -Name $OSDiskName -CreateOption FromImage -StorageAccountType $OSDiskType

# Disable Boot Diagnostics to prevent Azure from creating a new stbootdiagxxxxx storage account for every VM
$vmConfig = Set-AzVMBootDiagnostic `
    -VM $vmConfig `
    -Disable

# Attach NIC
$nic = Get-AzNetworkInterface -Name $NetworkInterfaceName -ResourceGroupName $ResourceGroupName
$vmConfig = Add-AzVMNetworkInterface -VM $vmConfig -Id $nic.Id

# Create VM

Write-LabLog "Creating Virtual Machine '$VM.Name'..."

New-AzVM -ResourceGroupName $ResourceGroupName -Location $Location -VM $vmConfig -ErrorAction Stop

Write-LabLog "VM '$VM.Name' created successfully." -Level SUCCESS
}

else
{
    Write-LabLog "WhatIf mode detected. Skipping actual VM creation." -Level Info
}

# Verification only if not WhatIf
if (-not $WhatIfPreference) {
    $vm = Get-AzVM -Name $VM.Name -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    if ($vm -and $vm.ProvisioningState -eq "Succeeded") {
        Write-LabLog "VM '$VM.Name' verified successfully. Provisioning state is Succeeded." -Level SUCCESS
    }
    else {
        Write-LabLog "VM '$VM.Name' verification failed. Provisioning state is $($vm.ProvisioningState)." -Level ERROR
        throw "VM creation failed or provisioning did not succeed."
    }
}
else {
    Write-LabLog "WhatIf mode detected. Skipping deployment verification." -Level INFO
}


# Deployment Summary
$summary = @{
    "VM Name" = $VM.Name
    "Resource Group" = $ResourceGroupName
    "Location" = $Location
    "VM Size" = $VM.Size
    "OS Disk Type" = $OSDiskType
    "Image" = "$Image.Publisher $Image.Offer $Image.SKU $Image.Version"
    "NIC Name" = $NetworkInterfaceName
    "Subnet Name" = $SubnetName
    "VNet Name" = $VNetName
}

Write-DeploymentSummary -Properties $summary
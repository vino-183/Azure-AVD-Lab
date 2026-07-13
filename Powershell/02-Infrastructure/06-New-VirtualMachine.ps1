<#
.SYNOPSIS
    Create a new Azure Virtual Machine for the selected lab role.

.DESCRIPTION
    Builds a VM configuration using catalog-driven values (VM, Image, OSDisk, Network, Tags).
    Deploys the VM using the standard Azure PowerShell pipeline.

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
$VM        = $VMProfile.VM
$Image     = $VMProfile.Image
$OSDisk    = $VMProfile.OSDisk
$Network   = $VMProfile.Network
$Tags      = $VMProfile.Tags

# Validate prerequisites
Write-LabLog "Validating prerequisites..." -Level INFO
if (-not (Test-LabPrerequisites)) {
    throw "Prerequisite validation failed."
}

# Check whether the VM already exists
Write-LabLog "Checking if Virtual Machine '$($VM.Name)' exists..." -Level INFO
$existingVm = Get-AzVM -Name $VM.Name -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue

if ($existingVm) {
    Write-LabLog "Virtual Machine '$($VM.Name)' already exists. Skipping deployment." -Level SUCCESS
}
else {
    if ($PSCmdlet.ShouldProcess($VM.Name, "Create Virtual Machine")) {
        try {
            Write-LabLog "Creating Virtual Machine '$($VM.Name)'..." -Level INFO

            # Resolve VM size dynamically (skip in WhatIf for speed)
            if (-not $WhatIfPreference) {
                $VM.Size = Get-LabVmSku -Location $Location -vCPU $VM.vCPU -MemoryGB $VM.MemoryGB -RequirePremiumStorage:$VM.RequirePremiumStorage
            }
            else {
                Write-LabLog "WhatIf mode detected. Skipping dynamic SKU lookup." -Level INFO
            }

            # Prompt for credentials (skip in WhatIf)
            if (-not $WhatIfPreference) {
                $AdminCredential = Get-LabCredential -Message "Enter credentials for '$($VM.Name)'"
            }

            # Resolve NIC (skip in WhatIf)
            if (-not $WhatIfPreference) {
                $nic = Get-AzNetworkInterface -Name $Network.NICName -ResourceGroupName $ResourceGroupName -ErrorAction Stop
            }

            # Build VM config
            $vmConfig = New-AzVMConfig -VMName $VM.Name -VMSize $VM.Size

            if (-not $WhatIfPreference) {
                $vmConfig = Set-AzVMOperatingSystem `
                    -VM $vmConfig `
                    -Windows `
                    -ComputerName $VM.ComputerName `
                    -Credential $AdminCredential `
                    -ProvisionVMAgent `
                    -EnableAutoUpdate
            }

            $vmConfig = Set-AzVMSourceImage `
                -VM $vmConfig `
                -PublisherName $Image.Publisher `
                -Offer $Image.Offer `
                -Skus $Image.Sku `
                -Version $Image.Version

            $vmConfig = Set-AzVMOSDisk `
                -VM $vmConfig `
                -Name $OSDisk.Name `
                -CreateOption FromImage `
                -StorageAccountType $OSDisk.SKU `
                -DiskSizeInGB $OSDisk.SizeGB

            if (-not $WhatIfPreference) {
                $vmConfig = Add-AzVMNetworkInterface -VM $vmConfig -Id $nic.Id
            }

            # Disable boot diagnostics for now
            $vmConfig = Set-AzVMBootDiagnostic -VM $vmConfig -Disable

            # Deploy VM
            $vm = New-AzVM `
                -ResourceGroupName $ResourceGroupName `
                -Location $Location `
                -VM $vmConfig `
                -Tag $Tags `
                -ErrorAction Stop

            Write-LabLog "Virtual Machine '$($VM.Name)' created successfully." -Level SUCCESS
        }
        catch {
            Write-LabLog "Failed to create Virtual Machine '$($VM.Name)'." -Level ERROR
            Write-LabLog $_.Exception.Message -Level ERROR
            throw
        }
    }
}

# Verification
if (-not $WhatIfPreference) {
    $vm = Get-AzVM -Name $VM.Name -ResourceGroupName $ResourceGroupName -ErrorAction Stop
    Write-LabLog "Virtual Machine '$($VM.Name)' verified successfully." -Level SUCCESS
}
else {
    Write-LabLog "WhatIf mode detected. Skipping deployment verification." -Level INFO
}

# Deployment Summary
Write-DeploymentSummary -Properties @{
    "Role"        = $Role
    "VM Name"     = $VM.Name
    "Size"        = $VM.Size
    "Image"       = "$($Image.Publisher) $($Image.Offer) $($Image.Sku) $($Image.Version)"
    "OS Disk"     = "$($OSDisk.Name) ($($OSDisk.SizeGB) GB, $($OSDisk.SKU))"
    "NIC"         = $Network.NICName
    "Tags"        = ($Tags.Keys | ForEach-Object { "$_=$($Tags[$_])" }) -join "; "
    "Provisioning" = if ($WhatIfPreference) { "WhatIf" } else { $vm.ProvisioningState }
}

# Return structured result
return [PSCustomObject]@{
    Role        = $Role
    DisplayName = $VMProfile.DisplayName
    VMName      = $VM.Name
    Status      = "Succeeded"
}

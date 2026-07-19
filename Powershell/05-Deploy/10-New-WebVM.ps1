<#
.SYNOPSIS
    Create a new Azure Virtual Machine.

.DESCRIPTION
    Builds a virtual machine using the current configuration loaded from the lab variables.

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

# Check whether the VM already exists
Write-LabLog "Checking if Virtual Machine '$($VMName)' exists..." -Level INFO
$existingVm = Get-AzVM -Name $VMName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue

if ($existingVm) {
    Write-LabLog "Virtual Machine '$($VMName)' already exists. Skipping deployment." -Level SUCCESS
}
else {
    if ($PSCmdlet.ShouldProcess($VMName, "Create Virtual Machine")) {
        try {
            Write-LabLog "Creating Virtual Machine '$($VMName)'..." -Level INFO

            # Resolve VM size dynamically (skip in WhatIf for speed)
            if (-not $WhatIfPreference) {
                $VM.Size = Get-LabVmSku -Location $Location -vCPU $VM.vCPU -MemoryGB $VM.MemoryGB -RequirePremiumStorage:$VM.RequirePremiumStorage
            }
            else {
                Write-LabLog "WhatIf mode detected. Skipping dynamic SKU lookup." -Level INFO
            }

            # Prompt for credentials (skip in WhatIf)
            if (-not $WhatIfPreference) {
                $AdminCredential = Get-LabCredential -Message "Enter credentials for '$($VMName)'"
            }

            # Resolve NIC (skip in WhatIf)
            if (-not $WhatIfPreference) {
                $nic = Get-AzNetworkInterface -Name $Network.NICName -ResourceGroupName $ResourceGroupName -ErrorAction Stop
            }

            # Build VM config
            $vmConfig = New-AzVMConfig -VMName $VMName -VMSize $VM.Size

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

            Write-LabLog "Virtual Machine '$($VMName)' created successfully." -Level SUCCESS
        }
        catch {
            Write-LabLog "Failed to create Virtual Machine '$($VMName)'." -Level ERROR
            Write-LabLog $_.Exception.Message -Level ERROR
            throw
        }
    }
}

# Verification
if (-not $WhatIfPreference) {
    $vm = Get-AzVM -Name $VMName -ResourceGroupName $ResourceGroupName -ErrorAction Stop
    Write-LabLog "Virtual Machine '$($VMName)' verified successfully." -Level SUCCESS
}
else {
    Write-LabLog "WhatIf mode detected. Skipping deployment verification." -Level INFO
}

# Deployment Summary
Write-DeploymentSummary -Properties @{
    "VM Name"     = $VMName
    "Size"        = $VM.Size
    "Image"       = "$($Image.Publisher) $($Image.Offer) $($Image.Sku) $($Image.Version)"
    "OS Disk"     = "$($OSDisk.Name) ($($OSDisk.SizeGB) GB, $($OSDisk.SKU))"
    "NIC"         = $Network.NICName
    "Tags"        = ($Tags.Keys | ForEach-Object { "$_=$($Tags[$_])" }) -join "; "
    "Provisioning" = if ($WhatIfPreference) { "WhatIf" } else { $vm.ProvisioningState }
}

# Return structured result
return [PSCustomObject]@{
    VMName            = $VMName
    ResourceGroupName = $ResourceGroupName
    Location          = $Location
    VM                = $vm
    Status            = "Succeeded"
}

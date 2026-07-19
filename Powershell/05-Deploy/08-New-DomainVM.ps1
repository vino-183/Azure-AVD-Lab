<#
.SYNOPSIS
    Create a new Azure Virtual Machine for Domain Controller.

.DESCRIPTION
    Builds a domain controller VM using the configuration defined in lab variables.
    Ensures the NIC exists by calling the NIC deployment script if needed.

.AUTHOR
    Vinodh

.DATE
    2026-07-18
#>

[CmdletBinding(SupportsShouldProcess)]
param()

# Import common modules
. "D:\Cloud-Labs\Azure-AVD-Lab\Powershell\01-Common\Import-Common.ps1"

try {
    # Validate prerequisites
    Write-LabLog "Validating prerequisites..." -Level INFO
    if (-not (Test-LabPrerequisites)) {
        throw "Prerequisite validation failed."
    }

    # Ensure NIC exists
    Write-LabLog "Checking if NIC '$DCNICName' exists..." -Level INFO
    $nic = Get-AzNetworkInterface -Name $DCNICName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    if (-not $nic) {
        Write-LabLog "NIC '$DCNICName' not found. Running NIC deployment script..." -Level INFO
        . "D:\Cloud-Labs\Azure-AVD-Lab\Powershell\02-Infrastructure\05-New-NetworkInterface.ps1"
        $nic = Get-AzNetworkInterface -Name $DCNICName -ResourceGroupName $ResourceGroupName -ErrorAction Stop
        Write-LabLog "NIC '$DCNICName' created successfully." -Level SUCCESS
    }

    # Check whether the VM already exists
    Write-LabLog "Checking if Virtual Machine '$DCVMName' exists..." -Level INFO
    $existingVm = Get-AzVM -Name $DCVMName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue

    if ($existingVm) {
        Write-LabLog "Virtual Machine '$DCVMName' already exists. Skipping deployment." -Level SUCCESS
    }
    else {
        if ($PSCmdlet.ShouldProcess($DCVMName, "Create Virtual Machine")) {
            Write-LabLog "Creating Virtual Machine '$DCVMName'..." -Level INFO

            # Resolve VM size dynamically (skip in WhatIf for speed)
            if (-not $WhatIfPreference) {
                $resolvedSize = Get-LabVmSku -Location $Location -vCPU $DCvCPU -MemoryGB $DCMemGB -RequirePremiumStorage:($DCOSDiskType -eq "Premium_LRS")
            }
            else {
                Write-LabLog "WhatIf mode detected. Skipping dynamic SKU lookup." -Level INFO
                $resolvedSize = $DCVMSize
            }

            # Prompt for credentials (skip in WhatIf)
            if (-not $WhatIfPreference) {
                $AdminCredential = Get-LabCredential -Message "Enter credentials for '$DCVMName'"
            }

            # Build VM config
            $vmConfig = New-AzVMConfig -VMName $DCVMName -VMSize $resolvedSize

            if (-not $WhatIfPreference) {
                $vmConfig = Set-AzVMOperatingSystem `
                    -VM $vmConfig `
                    -Windows `
                    -ComputerName $DCCompName `
                    -Credential $AdminCredential `
                    -ProvisionVMAgent `
                    -EnableAutoUpdate
            }

            $vmConfig = Set-AzVMSourceImage `
                -VM $vmConfig `
                -PublisherName $DCImgPub `
                -Offer $DCImgOffer `
                -Skus $DCImgSku `
                -Version $DCImgVer

            $vmConfig = Set-AzVMOSDisk `
                -VM $vmConfig `
                -Name $DCOSDisk `
                -CreateOption FromImage `
                -StorageAccountType $DCOSDiskType

            if (-not $WhatIfPreference) {
                $vmConfig = Add-AzVMNetworkInterface -VM $vmConfig -Id $nic.Id
            }

            # Boot diagnostics toggle
            if ($DCBootDiag) {
                $vmConfig = Set-AzVMBootDiagnostic -VM $vmConfig -Enable
            }
            else {
                $vmConfig = Set-AzVMBootDiagnostic -VM $vmConfig -Disable
            }

            # Deploy VM
            $vm = New-AzVM `
                -ResourceGroupName $ResourceGroupName `
                -Location $Location `
                -VM $vmConfig `
                -Tag $Tags `
                -ErrorAction Stop

            Write-LabLog "Virtual Machine '$DCVMName' created successfully." -Level SUCCESS
        }
    }

    # Verification
    if (-not $WhatIfPreference) {
        $vm = Get-AzVM -Name $DCVMName -ResourceGroupName $ResourceGroupName -ErrorAction Stop
        Write-LabLog "Virtual Machine '$DCVMName' verified successfully." -Level SUCCESS
    }
    else {
        Write-LabLog "WhatIf mode detected. Skipping deployment verification." -Level INFO
    }

    # Deployment Summary
    Write-DeploymentSummary -Properties @{
        "VM Name"     = $DCVMName
        "Size"        = $resolvedSize
        "Image"       = "$DCImgPub $DCImgOffer $DCImgSku $DCImgVer"
        "OS Disk"     = "$DCOSDisk ($DCOSDiskType)"
        "NIC"         = $DCNICName
        "Subnet"      = $DCSubnet
        "Tags"        = ($Tags.Keys | ForEach-Object { "$_=$($Tags[$_])" }) -join "; "
        "Provisioning" = if ($WhatIfPreference) { "WhatIf" } else { $vm.ProvisioningState }
    }

    # Return structured result
    return [PSCustomObject]@{
        VMName            = $DCVMName
        ResourceGroupName = $ResourceGroupName
        Location          = $Location
        VM                = $vm
        Status            = "Succeeded"
    }
}
catch {
    Write-LabLog "Failed to create Domain Controller VM." -Level ERROR
    Write-LabLog $_.Exception.Message -Level ERROR
    throw
}

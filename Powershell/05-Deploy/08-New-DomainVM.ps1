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

$DeploymentType = "DomainController"

# Import common modules
. "D:\Cloud-Labs\Azure-AVD-Lab\Powershell\01-Common\Import-Common.ps1"
. "D:\Cloud-Labs\Azure-AVD-Lab\Powershell\02-Infrastructure\05-New-NetworkInterface.ps1"
. "D:\Cloud-Labs\Azure-AVD-Lab\Powershell\02-Infrastructure\03-New-NSG.ps1"

try {
    # Validate prerequisites
    Write-LabLog "Validating prerequisites..." -Level INFO
    if (-not (Test-LabPrerequisites)) {
        throw "Prerequisite validation failed."
    }

    # Ensure NIC exists
    Write-LabLog "Checking if NIC '$NICName' exists..." -Level INFO
    $nic = Get-AzNetworkInterface -Name $NICName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    if (-not $nic) {
        Write-LabLog "NIC '$NICName' not found. Running NIC deployment script..." -Level INFO
        $nic = Get-AzNetworkInterface -Name $NICName -ResourceGroupName $ResourceGroupName -ErrorAction Stop
        Write-LabLog "NIC '$NICName' created successfully." -Level SUCCESS
    }

    # Check whether the VM already exists
    Write-LabLog "Checking if Virtual Machine '$VMName' exists..." -Level INFO
    $existingVm = Get-AzVM -Name $VMName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue

    if ($existingVm) {
        Write-LabLog "Virtual Machine '$VMName' already exists. Skipping deployment." -Level SUCCESS
    }
    else {
        if ($PSCmdlet.ShouldProcess($VMName, "Create Virtual Machine")) {
            Write-LabLog "Creating Virtual Machine '$VMName'..." -Level INFO

            # Resolve VM size
            if ([string]::IsNullOrWhiteSpace($VMSize)) {
                Write-LabLog "VMSize not specified. Resolving compatible SKU..." -Level INFO
                $resolvedSize = Get-LabVmSku -Location $Location -RequirePremiumStorage:($OSDiskSku -eq "Premium_LRS")
            }
            else {
                $resolvedSize = $VMSize
                Write-LabLog "Using configured VM SKU '$resolvedSize'." -Level INFO
            }

            # Prompt for credentials (skip in WhatIf)
            if (-not $WhatIfPreference) {
                $AdminCredential = Get-LabCredential -Message "Enter credentials for '$VMName'"
            }

            # Build VM config
            $vmConfig = New-AzVMConfig -VMName $VMName -VMSize $resolvedSize

            if (-not $WhatIfPreference) {
                $vmConfig = Set-AzVMOperatingSystem `
                    -VM $vmConfig `
                    -Windows `
                    -ComputerName $ComputerName `
                    -Credential $AdminCredential `
                    -ProvisionVMAgent `
                    -EnableAutoUpdate
            }

            $vmConfig = Set-AzVMSourceImage `
                -VM $vmConfig `
                -PublisherName $ImagePublisher `
                -Offer $ImageOffer `
                -Skus $ImageSku `
                -Version $ImageVersion

            $vmConfig = Set-AzVMOSDisk `
                -VM $vmConfig `
                -Name "$VMName-OSDisk" `
                -CreateOption FromImage `
                -StorageAccountType $OSDiskSku

            if (-not $WhatIfPreference) {
                $vmConfig = Add-AzVMNetworkInterface -VM $vmConfig -Id $nic.Id
            }

            # Boot diagnostics toggle
            if ($BootDiagnostics) {
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

            Write-LabLog "Virtual Machine '$VMName' created successfully." -Level SUCCESS
        }
    }

    # Verification
    if (-not $WhatIfPreference) {
        $vm = Get-AzVM -Name $VMName -ResourceGroupName $ResourceGroupName -ErrorAction Stop
        Write-LabLog "Virtual Machine '$VMName' verified successfully." -Level SUCCESS
    }
    else {
        Write-LabLog "WhatIf mode detected. Skipping deployment verification." -Level INFO
    }

    # Deployment Summary
    Write-DeploymentSummary -Properties @{
        "VM Name"      = $VMName
        "Size"         = $resolvedSize
        "Image"        = "$ImagePublisher $ImageOffer $ImageSku $ImageVersion"
        "OS Disk"      = "$VMName-OSDisk ($OSDiskSku)"
        "NIC"          = $NICName
        "Subnet"       = $SubnetName
        "Tags"         = ($Tags.Keys | ForEach-Object { "$_=$($Tags[$_])" }) -join "; "
        "Provisioning" = if ($WhatIfPreference) { "WhatIf" } else { $vm.ProvisioningState }
    }

    return [PSCustomObject]@{
        VMName            = $VMName
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

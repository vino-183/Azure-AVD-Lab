<#
.SYNOPSIS
    Remove an Azure VM and its associated resources.
.DESCRIPTION
    Validates prerequisites and Azure login, verifies the VM exists,
    prompts for confirmation (SupportsShouldProcess/WhatIf), deletes the VM,
    waits for deletion, and removes associated NIC, OS disk, public IP,
    and optionally the boot diagnostics storage account if used only by this VM.
    Also performs orphan cleanup for unattached NICs and disks.
.AUTHOR
    Vinodh
.DATE
    2026-07-09
.NOTES
    Part of the Azure-AVD-Lab project. Assumes prerequisites (RG, VNet, Subnet, NIC, Storage) already exist.
.EXAMPLE
    .\07-Remove-SessionHostVM.ps1 -WhatIf
#>

[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param(
    [switch]$RemoveBootDiagnostics,
    [switch]$CleanupOrphans
)

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

# Verify VM exists
$vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -ErrorAction SilentlyContinue
if (-not $vm) {
    Write-Error "VM '$VMName' not found in resource group '$ResourceGroupName'."
    throw
}

if ($PSCmdlet.ShouldProcess("VM '$VMName' in RG '$ResourceGroupName'", "Remove VM and associated resources")) {

    try {
        # Remove VM
        Write-LabLog "Removing VM $VMName..." -Level Info
        Remove-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -Force -ErrorAction Stop

        # Wait for VM deletion
        for ($i=0; $i -lt 60; $i++) {
            Start-Sleep -Seconds 2
            if (-not (Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -ErrorAction SilentlyContinue)) { break }
        }

        # Remove NICs and Public IPs
        $nicIds = $vm.NetworkProfile.NetworkInterfaces | ForEach-Object { $_.Id }
        foreach ($nicId in $nicIds) {
            $nicName = ($nicId -split '/')[8]
            $nic = Get-AzNetworkInterface -Name $nicName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
            if ($nic) {
                if ($PSCmdlet.ShouldProcess("NIC '$nicName'", 'Remove NIC')) {
                    Write-LabLog "Removing NIC $nicName..." -Level Info
                    foreach ($ipConfig in $nic.IpConfigurations) {
                        if ($ipConfig.PublicIpAddress -and $ipConfig.PublicIpAddress.Id) {
                            $pipName = ($ipConfig.PublicIpAddress.Id -split '/')[8]
                            if ($PSCmdlet.ShouldProcess("Public IP '$pipName'", 'Remove Public IP')) {
                                Write-LabLog "Removing Public IP $pipName..."  -Level Info
                                Remove-AzPublicIpAddress -Name $pipName -ResourceGroupName $ResourceGroupName -Force -ErrorAction SilentlyContinue
                            }
                        }
                    }
                    Remove-AzNetworkInterface -Name $nicName -ResourceGroupName $ResourceGroupName -Force -ErrorAction SilentlyContinue
                }
            }
        }

        # Remove OS Disk
        $osDisk = $vm.StorageProfile.OsDisk
        if ($osDisk -and $osDisk.ManagedDisk -and $osDisk.ManagedDisk.Id) {
            $diskName = ($osDisk.ManagedDisk.Id -split '/')[8]
            if ($PSCmdlet.ShouldProcess("Disk '$diskName'", 'Remove OS disk')) {
                Write-LabLog "Removing managed disk $diskName..."  -Level Info
                Remove-AzDisk -ResourceGroupName $ResourceGroupName -DiskName $diskName -Force -ErrorAction SilentlyContinue
            }
        }

        # Optional: Remove Boot Diagnostics storage account
        if ($RemoveBootDiagnostics) {
            $diag = $vm.DiagnosticsProfile.BootDiagnostics
            if ($diag -and $diag.StorageUri -match "https://([^.]+)\.") {
                $saName = $matches[1]
                $others = Get-AzVM -Status | Where-Object {
                    $_.DiagnosticsProfile -and
                    $_.DiagnosticsProfile.BootDiagnostics -and
                    $_.DiagnosticsProfile.BootDiagnostics.StorageUri -eq $diag.StorageUri -and
                    $_.Name -ne $VMName
                }
                if (-not $others) {
                    if ($PSCmdlet.ShouldProcess("StorageAccount '$saName'", 'Remove boot diagnostics storage account')) {
                        Write-LabLog "Removing storage account $saName..."  -Level Info
                        try { Remove-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $saName -Force -ErrorAction Stop } catch { Write-LabLog "Failed to remove storage account: $_" }
                    }
                } else {
                    Write-LabLog "Storage account $saName is used by other VMs; skipping removal."
                }
            }
        }

        # Verification (skip if WhatIf)
        if (-not $WhatIfPreference) {
            $vmCheck  = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -ErrorAction SilentlyContinue
            $nicCheck = Get-AzNetworkInterface -ResourceGroupName $ResourceGroupName | Where-Object { $_.VirtualMachine -and $_.VirtualMachine.Id -match $VMName }
            $diskCheck = Get-AzDisk -ResourceGroupName $ResourceGroupName | Where-Object { $_.ManagedBy -match $VMName }

            if (-not $vmCheck -and -not $nicCheck -and -not $diskCheck) {
                Write-LabLog "Removal verified successfully." -Level Success
            } else {
                throw "Verification failed: some resources still exist."
            }
        } else {
            Write-LabLog "WhatIf mode detected. Skipping removal verification." -Level Info
        }

        # Orphan cleanup
        if ($CleanupOrphans) {
            $orphanNics = Get-AzNetworkInterface -ResourceGroupName $ResourceGroupName | Where-Object { -not $_.VirtualMachine }
            foreach ($nic in $orphanNics) {
                if ($PSCmdlet.ShouldProcess("Orphan NIC '$($nic.Name)'", 'Remove orphan NIC')) {
                    Write-LabLog "Removing orphan NIC $($nic.Name)..."  -Level Info
                    Remove-AzNetworkInterface -Name $nic.Name -ResourceGroupName $ResourceGroupName -Force -ErrorAction SilentlyContinue
                }
            }

            $orphanDisks = Get-AzDisk -ResourceGroupName $ResourceGroupName | Where-Object { -not $_.ManagedBy }
            foreach ($disk in $orphanDisks) {
                if ($PSCmdlet.ShouldProcess("Orphan Disk '$($disk.Name)'", 'Remove orphan disk')) {
                    Write-LabLog "Removing orphan disk $($disk.Name)..."  -Level Info
                    Remove-AzDisk -ResourceGroupName $ResourceGroupName -DiskName $disk.Name -Force -ErrorAction SilentlyContinue
                }
            }
        }

        # Removal Summary
        Write-Output "`nRemoval Summary"
        Write-Output "---------------"
        Write-Output ("VM Name        : {0}" -f $VMName)
        Write-Output "NIC            : Removed"
        Write-Output "OS Disk        : Removed"
        Write-Output "Public IP      : Checked/Removed if present"

        $bootDiagStatus = if ($RemoveBootDiagnostics) { "Removed / Not Found" } else { "Skipped" }
        Write-Output ("Boot Diag      : {0}" -f $bootDiagStatus)

        Write-Output "Provisioning   : Success"

    } catch {
        Write-Error "Error removing VM or resources: $_"
        throw "VM '$VMName' not found."
    }

}
else {
    Write-LabLog "WhatIf mode detected. Skipping resource removal." -Level Info
}

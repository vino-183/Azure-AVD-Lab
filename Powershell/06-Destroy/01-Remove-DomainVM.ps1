<#
.SYNOPSIS
    Remove an Azure Virtual Machine and associated resources.

.DESCRIPTION
    Stops and deletes the VM, NIC, disks, and public IP (if any).
    Waits for disks to detach before removal.
    Performs cleanup verification before returning a summary.

.AUTHOR
    Vinodh

.DATE
    2026-07-20
#>

[CmdletBinding(SupportsShouldProcess)]
param()

$DeploymentType = "DomainController"

# Import common modules
. "D:\Cloud-Labs\Azure-AVD-Lab\Powershell\01-Common\Import-Common.ps1"

try {
    # Validate prerequisites
    Write-LabLog "Validating prerequisites..." -Level INFO
    if (-not (Test-LabPrerequisites)) {
        throw "Prerequisite validation failed."
    }
    Write-LabLog "Azure connection verified." -Level SUCCESS

    # Check VM existence
    Write-LabLog "Checking if VM '$VMName' exists..." -Level INFO
    $vm = Get-AzVM -Name $VMName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue

    if ($vm) {
        # Stop VM
        if ($PSCmdlet.ShouldProcess($VMName, "Stop VM")) {
            Write-LabLog "Stopping VM '$VMName'..." -Level INFO
            Stop-AzVM -Name $VMName -ResourceGroupName $ResourceGroupName -Force -ErrorAction Stop
        }

        # Delete VM
        if ($PSCmdlet.ShouldProcess($VMName, "Delete VM")) {
            Write-LabLog "Deleting VM '$VMName'..." -Level INFO
            Remove-AzVM -Name $VMName -ResourceGroupName $ResourceGroupName -Force -ErrorAction Stop
        }

        # Wait until VM is deleted
        do {
            Start-Sleep -Seconds 5
            $vmCheck = Get-AzVM -Name $VMName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
        } while ($vmCheck)

        Write-LabLog "VM '$VMName' deleted successfully." -Level SUCCESS

        # Capture disk names
        $osDiskName = $vm.StorageProfile.OsDisk.Name
        $dataDisks  = $vm.StorageProfile.DataDisks
    }
    else {
        Write-LabLog "VM '$VMName' does not exist. Skipping VM deletion." -Level WARNING
        $osDiskName = "$VMName-osdisk"
        $dataDisks  = @(Get-AzDisk -ResourceGroupName $ResourceGroupName | Where-Object { $_.Name -like "$VMName-data*" })
    }

    # Wait for OS disk to detach and delete
    if ($osDiskName) {
        Write-LabLog "Waiting for OS disk '$osDiskName' to become unattached..." -Level INFO
        do {
            Start-Sleep -Seconds 5
            $disk = Get-AzDisk -Name $osDiskName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
        } while ($disk -and $disk.DiskState -ne "Unattached")

        if ($disk) {
            Write-LabLog "Deleting OS disk '$osDiskName'..." -Level INFO
            Remove-AzDisk -Name $osDiskName -ResourceGroupName $ResourceGroupName -Force -ErrorAction Stop
            Write-LabLog "OS disk '$osDiskName' removed successfully." -Level SUCCESS
        }
    }

    # Delete Data Disks
    foreach ($disk in $dataDisks) {
        Write-LabLog "Waiting for data disk '$($disk.Name)' to become unattached..." -Level INFO
        do {
            Start-Sleep -Seconds 5
            $dataDisk = Get-AzDisk -Name $disk.Name -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
        } while ($dataDisk -and $dataDisk.DiskState -ne "Unattached")

        if ($dataDisk) {
            Write-LabLog "Deleting data disk '$($disk.Name)'..." -Level INFO
            Remove-AzDisk -Name $disk.Name -ResourceGroupName $ResourceGroupName -Force -ErrorAction Stop
            Write-LabLog "Data disk '$($disk.Name)' removed successfully." -Level SUCCESS
        }
    }

    # Delete NIC
    if ($PSCmdlet.ShouldProcess($NICName, "Delete NIC")) {
        Write-LabLog "Deleting NIC '$NICName'..." -Level INFO
        Remove-AzNetworkInterface -Name $NICName -ResourceGroupName $ResourceGroupName -Force -ErrorAction Stop
    }

    # Delete Public IP
    $nic = Get-AzNetworkInterface -Name $NICName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    if ($nic) {
        $pipConfig = $nic.IpConfigurations | Where-Object { $_.PublicIpAddress }
        if ($pipConfig) {
            $publicIpName = $pipConfig.PublicIpAddress.Id.Split("/")[-1]
            if ($PSCmdlet.ShouldProcess($publicIpName, "Delete Public IP")) {
                Write-LabLog "Deleting Public IP '$publicIpName'..." -Level INFO
                Remove-AzPublicIpAddress -Name $publicIpName -ResourceGroupName $ResourceGroupName -Force -ErrorAction Stop
            }
        }
    }

    # Verify cleanup
    Write-LabLog "Verifying cleanup..." -Level INFO
    $vmExists       = Test-VMIfExists -VMName $VMName -ResourceGroupName $ResourceGroupName
    $nicExists      = Test-NicIfExists -Name $NICName -ResourceGroupName $ResourceGroupName
    $osDiskExists   = Test-DiskIfExists -Name $osDiskName -ResourceGroupName $ResourceGroupName
    $publicIpExists = if ($publicIpName) { Test-PublicIpIfExists -Name $publicIpName -ResourceGroupName $ResourceGroupName } else { $false }

    if (-not $vmExists -and -not $nicExists -and -not $osDiskExists -and -not $publicIpExists) {
        Write-LabLog "VM cleanup verified successfully." -Level SUCCESS
    }
    else {
        Write-LabLog "Cleanup incomplete. Some resources still exist." -Level WARNING
    }

    # Destroy Summary
    Write-LabLog "========== Destroy Summary ==========" -Level INFO
    Write-LabLog "VM:        $VMName     => $(if ($vmExists) { 'Still Exists' } else { 'Removed' })" -Level INFO
    Write-LabLog "NIC:       $NICName    => $(if ($nicExists) { 'Still Exists' } else { 'Removed' })" -Level INFO
    Write-LabLog "OS Disk:   $osDiskName => $(if ($osDiskExists) { 'Still Exists' } else { 'Removed' })" -Level INFO
    Write-LabLog "Public IP: $publicIpName => $(if ($publicIpExists) { 'Still Exists' } else { 'Removed' })" -Level INFO
    Write-LabLog "=====================================" -Level INFO

    # Return summary object
    return [PSCustomObject]@{
        VMName   = $VMName
        NICName  = $NICName
        OSDisk   = $osDiskName
        PublicIP = $publicIpName
        Status   = if (-not $vmExists -and -not $nicExists -and -not $osDiskExists -and -not $publicIpExists) { "Removed" } else { "Partial" }
    }
}
catch {
    Write-LabLog "VM removal failed." -Level ERROR
    Write-LabLog $_.Exception.Message -Level ERROR
    throw
}
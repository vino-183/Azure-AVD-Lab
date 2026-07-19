<#
.SYNOPSIS
    Remove the Domain Controller VM and associated resources.

.DESCRIPTION
    Stops and deletes the Domain Controller VM, NIC, disks, and public IP (if any).
    Performs validation and cleanup verification before returning a summary.

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

    # Verify Azure connection
    Write-LabLog "Verifying Azure connection..." -Level INFO
    if (-not (Test-AzContext)) {
        throw "No active Azure context found. Please run Connect-AzAccount."
    }

    # Verify VM exists
    Write-LabLog "Checking if VM '$DCVMName' exists..." -Level INFO
    $vm = Get-AzVM -Name $DCVMName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    if (-not $vm) {
        Write-LabLog "VM '$DCVMName' does not exist. Nothing to remove." -Level WARN
        return
    }

    # Stop VM
    if ($PSCmdlet.ShouldProcess($DCVMName, "Stop VM")) {
        Write-LabLog "Stopping VM '$DCVMName'..." -Level INFO
        Stop-AzVM -Name $DCVMName -ResourceGroupName $ResourceGroupName -Force -ErrorAction SilentlyContinue
    }

    # Delete VM
    if ($PSCmdlet.ShouldProcess($DCVMName, "Delete VM")) {
        Write-LabLog "Deleting VM '$DCVMName'..." -Level INFO
        Remove-AzVM -Name $DCVMName -ResourceGroupName $ResourceGroupName -Force -ErrorAction Stop
    }

    # Wait until deleted
    do {
        Start-Sleep -Seconds 5
        $vmCheck = Get-AzVM -Name $DCVMName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    } while ($vmCheck)

    Write-LabLog "VM '$DCVMName' deleted successfully." -Level SUCCESS

    # Delete NIC
    if ($PSCmdlet.ShouldProcess($DCNICName, "Delete NIC")) {
        Write-LabLog "Deleting NIC '$DCNICName'..." -Level INFO
        Remove-AzNetworkInterface -Name $DCNICName -ResourceGroupName $ResourceGroupName -Force -ErrorAction SilentlyContinue
    }

    # Delete OS Disk (discovered from VM object)
    $osDiskName = $vm.StorageProfile.OsDisk.Name
    if ($PSCmdlet.ShouldProcess($osDiskName, "Delete OS Disk")) {
        Write-LabLog "Deleting OS Disk '$osDiskName'..." -Level INFO
        Remove-AzDisk -Name $osDiskName -ResourceGroupName $ResourceGroupName -Force -ErrorAction SilentlyContinue
    }

    # Delete Data Disks (if any)
    Write-LabLog "Checking for data disks..." -Level INFO
    $dataDisks = $vm.StorageProfile.DataDisks
    foreach ($disk in $dataDisks) {
        if ($PSCmdlet.ShouldProcess($disk.Name, "Delete Data Disk")) {
            Write-LabLog "Deleting Data Disk '$($disk.Name)'..." -Level INFO
            Remove-AzDisk -Name $disk.Name -ResourceGroupName $ResourceGroupName -Force -ErrorAction SilentlyContinue
        }
    }

    # Delete Public IP (discovered via NIC)
    $nic = Get-AzNetworkInterface -Name $DCNICName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    if ($nic) {
        $pipConfig = $nic.IpConfigurations | Where-Object { $_.PublicIpAddress }
        if ($pipConfig) {
            $publicIpName = $pipConfig.PublicIpAddress.Id.Split("/")[-1]
            if ($PSCmdlet.ShouldProcess($publicIpName, "Delete Public IP")) {
                Write-LabLog "Deleting Public IP '$publicIpName'..." -Level INFO
                Remove-AzPublicIpAddress -Name $publicIpName -ResourceGroupName $ResourceGroupName -Force -ErrorAction SilentlyContinue
            }
        }
    }

    # Verify cleanup
    Write-LabLog "Verifying cleanup..." -Level INFO
    $vmExists   = Get-AzVM -Name $DCVMName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    $nicExists  = Get-AzNetworkInterface -Name $DCNICName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    $osDiskExists = Get-AzDisk -Name $osDiskName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    $publicIpExists = if ($publicIpName) { Get-AzPublicIpAddress -Name $publicIpName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue } else { $null }

    if (-not $vmExists -and -not $nicExists -and -not $osDiskExists -and -not $publicIpExists) {
        Write-LabLog "Domain Controller cleanup verified successfully." -Level SUCCESS
    }
    else {
        Write-LabLog "Cleanup incomplete. Some resources still exist." -Level WARN
    }

    # Return summary
    return [PSCustomObject]@{
        VMName     = $DCVMName
        NICName    = $DCNICName
        OSDisk     = $osDiskName
        PublicIP   = $publicIpName
        Status     = if (-not $vmExists -and -not $nicExists -and -not $osDiskExists -and -not $publicIpExists) { "Removed" } else { "Partial" }
    }
}
catch {
    Write-LabLog "Domain Controller removal failed." -Level ERROR
    Write-LabLog $_.Exception.Message -Level ERROR
    throw
}

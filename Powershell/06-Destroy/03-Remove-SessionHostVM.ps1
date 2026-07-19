<#
.SYNOPSIS
    Destroy Session Host VM in Azure
.DESCRIPTION
    - Verifies Azure connection
    - Removes Session Host from Host Pool (matching by ComputerName/FQDN)
    - Stops VM (if running)
    - Deletes VM
    - Deletes NIC
    - Deletes OS Disk
    - Deletes Data Disk(s)
    - Deletes Public IP
    - Verifies Host Pool is clean
    - Returns summary object
.NOTES
    Keeps Resource Group, VNet, NSG, Storage Account
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory=$true)]
    [string]$VMName,

    [Parameter(Mandatory=$false)]
    [string]$HostPoolName
)

# --- 1. Verify Azure connection ---
$context = Get-AzContext
if (-not $context) {
    throw "Please run Connect-AzAccount first."
}

# --- 2. Remove Session Host from Host Pool (match by ComputerName/FQDN) ---
if ($HostPoolName) {
    try {
        $hosts = Get-AzWvdSessionHost -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName
        $targetHost = $hosts | Where-Object {
            $_.Name -like "*$VMName*" -or $_.FriendlyName -like "*$VMName*"
        }
        if ($targetHost) {
            if ($PSCmdlet.ShouldProcess($targetHost.Name,"Remove from Host Pool")) {
                Write-LabLog "Removing $($targetHost.Name) from Host Pool $HostPoolName..."
                Remove-AzWvdSessionHost -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName -Name $targetHost.Name -Force
            }
        }
    } catch {
        Write-LabLog "Host Pool cleanup skipped: $_"
    }
}

# --- 3. Collect VM + NIC + IP info before deletion ---
$vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status -ErrorAction SilentlyContinue
if (-not $vm) {
    throw "VM $VMName not found in $ResourceGroupName."
}

$nicId = $vm.NetworkProfile.NetworkInterfaces[0].Id
$nicName = ($nicId -split "/")[-1]
$nic = Get-AzNetworkInterface -ResourceGroupName $ResourceGroupName -Name $nicName -ErrorAction SilentlyContinue

$publicIpName = $null
if ($nic) {
    foreach ($ipConfig in $nic.IpConfigurations) {
        if ($ipConfig.PublicIpAddress) {
            $publicIpName = ($ipConfig.PublicIpAddress.Id -split "/")[-1]
        }
    }
}

$osDiskName = $vm.StorageProfile.OsDisk.Name
$dataDisks  = $vm.StorageProfile.DataDisks

# --- 4. Stop VM if running ---
if ($vm.Statuses.Code -contains "PowerState/running") {
    if ($PSCmdlet.ShouldProcess($VMName,"Stop VM")) {
        Write-LabLog "Stopping VM $VMName..."
        Stop-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -Force
    }
}

# --- 5. Delete VM ---
if ($PSCmdlet.ShouldProcess($VMName,"Delete VM")) {
    Write-LabLog "Deleting VM $VMName..."
    Remove-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -Force
}

# --- 6. Wait until VM is gone (eventual consistency with timeout) ---
$timeout = 300
$elapsed = 0
do {
    Start-Sleep -Seconds 5
    $elapsed += 5
    $vmCheck = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -ErrorAction SilentlyContinue
    if (-not $vmCheck) { break }
} while ($elapsed -lt $timeout)

if ($vmCheck) {
    throw "Timed out waiting for VM deletion."
}

# --- 7. Delete NIC ---
if ($nicName) {
    try {
        if ($PSCmdlet.ShouldProcess($nicName,"Delete NIC")) {
            Write-LabLog "Deleting NIC $nicName..."
            Remove-AzNetworkInterface -ResourceGroupName $ResourceGroupName -Name $nicName -Force
        }
    } catch {
        Write-LabLog "NIC deletion failed: $_"
    }
}

# --- 8. Delete OS Disk ---
try {
    if ($PSCmdlet.ShouldProcess($osDiskName,"Delete OS Disk")) {
        Write-LabLog "Deleting OS Disk $osDiskName..."
        Remove-AzDisk -ResourceGroupName $ResourceGroupName -DiskName $osDiskName -Force
    }
} catch {
    Write-LabLog "OS Disk deletion failed: $_"
}

# --- 9. Delete Data Disks ---
$deletedDataDisks = @()
foreach ($disk in $dataDisks) {
    try {
        if ($PSCmdlet.ShouldProcess($disk.Name,"Delete Data Disk")) {
            Write-LabLog "Deleting Data Disk $($disk.Name)..."
            Remove-AzDisk -ResourceGroupName $ResourceGroupName -DiskName $disk.Name -Force
            $deletedDataDisks += $disk.Name
        }
    } catch {
        Write-LabLog "Data Disk deletion failed: $_"
    }
}

# --- 10. Delete Public IP ---
if ($publicIpName) {
    try {
        if ($PSCmdlet.ShouldProcess($publicIpName,"Delete Public IP")) {
            Write-LabLog "Deleting Public IP $publicIpName..."
            Remove-AzPublicIpAddress -ResourceGroupName $ResourceGroupName -Name $publicIpName -Force
        }
    } catch {
        Write-LabLog "Public IP deletion failed: $_"
    }
}

# --- 11. Verify Host Pool is clean ---
if ($HostPoolName) {
    $remainingHost = Get-AzWvdSessionHost -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName | Where-Object {
        $_.Name -like "*$VMName*" -or $_.FriendlyName -like "*$VMName*"
    }
    if ($remainingHost) {
        Write-LabLog "Warning: Host Pool still has stale entry for $VMName."
    } else {
        Write-LabLog "Host Pool $HostPoolName is clean."
    }
}

# --- 12. Return summary object ---
[PSCustomObject]@{
    VMDeleted         = (-not $vmCheck)
    NICDeleted        = (-not (Get-AzNetworkInterface -ResourceGroupName $ResourceGroupName -Name $nicName -ErrorAction SilentlyContinue))
    OSDiskDeleted     = (-not (Get-AzDisk -ResourceGroupName $ResourceGroupName -DiskName $osDiskName -ErrorAction SilentlyContinue))
    DataDisksDeleted  = $deletedDataDisks
    PublicIPRemoved   = if ($publicIpName) {
                            (-not (Get-AzPublicIpAddress -ResourceGroupName $ResourceGroupName -Name $publicIpName -ErrorAction SilentlyContinue))
                        } else {
                            $false
                        }
}

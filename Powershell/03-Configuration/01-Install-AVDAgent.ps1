<#
.SYNOPSIS
    Install AVD Agent on Azure VM.
.DESCRIPTION
    Validates Azure connection, resource group, and VM.
    Ensures VM is running, checks if agent is installed,
    downloads and installs agent if needed, and verifies installation.
.AUTHOR
    Vinodh
.DATE
    2026-07-12
.NOTES
    Part of Azure-AVD-Lab project.
.EXAMPLE
    .\12-Install-AVDAgent.ps1 -VMName vm-avdlab-sessionhost01
#>

[CmdletBinding()]
param(
    [string]$ResourceGroupName,
    [string]$VMName
)

# Import modules
. "$PSScriptRoot\..\01-Common\Import-Common.ps1"

# Apply defaults if parameters not provided
if (-not $ResourceGroupName) { $ResourceGroupName = $Global:ResourceGroupName }

function Get-VmPowerState {
    param([string]$ResourceGroupName,[string]$VMName)
    $status = (Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status).Statuses |
              Where-Object { $_.Code -like "PowerState/*" } |
              Select-Object -ExpandProperty DisplayStatus
    return $status
}

try {
    Write-LabLog "Validating Azure connection..." -Level Info
    if (-not (Test-AzureConnection)) {
        throw "Azure connection not established. Please login first."
    }

    # Validate Resource Group
    if (-not (Test-ResourceGroupIfExists -ResourceGroupName $ResourceGroupName)) {
        throw "Resource Group '$ResourceGroupName' not found."
    }

    # Validate VM
    $vm = Get-SessionHostVMIfExists -ResourceGroupName $ResourceGroupName -Name $VMName
    if (-not $vm) {
        throw "VM '$VMName' not found in resource group '$ResourceGroupName'."
    }

    # Check VM power state
    $vmStatus = Get-VmPowerState -ResourceGroupName $ResourceGroupName -VMName $VMName
    if ($vmStatus -ne "VM running") {
        Write-LabLog "VM '$VMName' is currently in state: $vmStatus." -Level Warning

        Write-LabLog "Attempting to start VM '$VMName'..." -Level Info
        Start-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -ErrorAction Stop

        $timeout = 300; $elapsed = 0
        do {
            if ($elapsed -ge $timeout) {
                throw "VM '$VMName' failed to start within $timeout seconds."
            }
            Write-LabLog "Waiting for VM '$VMName' to start... elapsed $elapsed seconds (current state: $vmStatus)" -Level Info
            Start-Sleep 10; $elapsed += 10
            $vmStatus = Get-VmPowerState -ResourceGroupName $ResourceGroupName -VMName $VMName
        } while ($vmStatus -ne "VM running")

        Write-LabLog "VM '$VMName' is now running." -Level Success
    }
    else {
        Write-LabLog "VM '$VMName' is already running." -Level Info
    }

    # Check if agent already installed
    if (Test-AvdAgentInstalled -VMName $VMName -ResourceGroupName $ResourceGroupName) {
        Write-LabLog "AVD Agent already installed on VM '$VMName'." -Level Success
        $result = [PSCustomObject]@{
            Success     = $true
            Version     = Get-AvdAgentVersion -VMName $VMName -ResourceGroupName $ResourceGroupName
            InstallTime = $null
        }
    }
    else {
        Write-LabLog "Installing AVD Agent on VM '$VMName'..." -Level Info
        $result = Install-AvdAgent -VMName $VMName -ResourceGroupName $ResourceGroupName

        if (-not (Test-AvdAgentInstalled -VMName $VMName -ResourceGroupName $ResourceGroupName)) {
            throw "AVD Agent installation failed on VM '$VMName'."
        }

        $result.Version = Get-AvdAgentVersion -VMName $VMName -ResourceGroupName $ResourceGroupName
        Write-LabLog "AVD Agent installed successfully (Version $($result.Version))." -Level Success
    }

    # Deployment Summary
    Show-DeploymentSummary @{
        "VM Name"        = $VMName
        "Resource Group" = $ResourceGroupName
        "Agent"          = if ($result.Success) { "Installed" } else { "Not Installed" }
        "Version"        = $result.Version
        "Status"         = if ($result.Success) { "Success" } else { "Failed" }
        "Install Time"   = $result.InstallTime
    }

    # Return object for consumption by other scripts
    [PSCustomObject]@{
        VMName         = $VMName
        ResourceGroup  = $ResourceGroupName
        AgentInstalled = $result.Success
        Version        = $result.Version
        InstallTime    = $result.InstallTime
    }
}
catch {
    Write-LabLog $_.Exception.Message -Level Error
    throw
}

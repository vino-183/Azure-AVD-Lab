<#
.SYNOPSIS
    Register an existing Azure VM as an Azure Virtual Desktop Session Host.
.DESCRIPTION
    Validates prerequisites, ensures VM is running, verifies agent/boot loader,
    retrieves registration token if needed, registers the VM, waits for completion,
    and outputs a structured result.
.AUTHOR
    Vinodh
.DATE
    2026-07-12
.NOTES
    Part of Azure-AVD-Lab project.
.EXAMPLE
    .\14-Register-SessionHost.ps1 -VMName vm-avdlab-sessionhost01 -HostPoolName avdlab-hostpool01
#>

[CmdletBinding()]
param(
    [string]$ResourceGroupName,
    [string]$HostPoolName,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$VMName,

    [string]$RegistrationToken
)

# Import framework and helpers
. "$PSScriptRoot\..\Common\00-FrameworkRequirements.ps1"
. "$PSScriptRoot\..\Common\01-CommonVariables.ps1"
. "$PSScriptRoot\..\Common\03-AzureHelpers.ps1"
. "$PSScriptRoot\..\Common\06-AvdHelpers.ps1"

# Apply defaults if parameters not provided
if (-not $ResourceGroupName) { $ResourceGroupName = $Global:ResourceGroupName }
if (-not $HostPoolName)      { $HostPoolName      = $Global:HostPoolName }

try {
    Write-LabLog "Validating Azure connection..." -Level Info
    if (-not (Test-AzureConnection)) {
        throw "Azure connection not established. Please login first."
    }

    # Validate Resource Group
    if (-not (Test-ResourceGroupIfExists -ResourceGroupName $ResourceGroupName)) {
        throw "Resource Group '$ResourceGroupName' not found."
    }

    # Validate Host Pool
    if (-not (Test-HostPoolIfExists -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName)) {
        throw "Host Pool '$HostPoolName' not found."
    }

    # Validate VM
    $vm = Get-SessionHostVMIfExists -ResourceGroupName $ResourceGroupName -Name $VMName
    if (-not $vm) {
        throw "VM '$VMName' not found in resource group '$ResourceGroupName'."
    }

    # Ensure VM is running (poll with timeout)
    if (-not (Test-VMRunning -ResourceGroupName $ResourceGroupName -VMName $VMName)) {
        Write-LabLog "VM '$VMName' is not running. Starting VM..." -Level Info
        Start-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -ErrorAction Stop

        $timeout = 300; $elapsed = 0
        while (-not (Test-VMRunning -ResourceGroupName $ResourceGroupName -VMName $VMName)) {
            if ($elapsed -ge $timeout) {
                throw "VM '$VMName' failed to start within $timeout seconds."
            }
            Start-Sleep 10; $elapsed += 10
        }
    }
    Write-LabLog "VM '$VMName' is running." -Level Info

    # Verify Agent and Boot Loader
    if (-not (Test-AvdAgentInstalled -VMName $VMName -ResourceGroupName $ResourceGroupName)) {
        throw "AVD Agent not installed on VM '$VMName'."
    }
    if (-not (Test-AvdBootLoaderInstalled -VMName $VMName -ResourceGroupName $ResourceGroupName)) {
        throw "Boot Loader not installed on VM '$VMName'."
    }

    # Get Registration Token if not provided
    if (-not $RegistrationToken) {
        Write-LabLog "Retrieving registration token..." -Level Info
        $RegistrationToken = Get-OrCreateAvdRegistrationToken -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName
    }

    # Register Session Host
    $result = Register-AvdSessionHost -VMName $VMName -HostPoolName $HostPoolName -ResourceGroupName $ResourceGroupName -Token $RegistrationToken

    # Wait for Registration
    $waitResult = Wait-AvdSessionHostRegistration -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName -VMName $VMName

    Write-LabLog "Session Host '$VMName' registered successfully." -Level Success

    # Deployment Summary
    Show-DeploymentSummary @{
        "VM Name"            = $VMName
        "Host Pool"          = $HostPoolName
        "Resource Group"     = $ResourceGroupName
        "Registration Status"= if ($waitResult.Success) { "Success" } else { "Failed" }
        "Registered Time"    = $waitResult.RegisteredTime
    }

    # Return object
    [PSCustomObject]@{
        VMName             = $VMName
        HostPool           = $HostPoolName
        ResourceGroup      = $ResourceGroupName
        RegistrationStatus = $waitResult.Success
        RegisteredTime     = $waitResult.RegisteredTime
    }
}
catch {
    Write-LabLog $_.Exception.Message -Level Error
    throw
}

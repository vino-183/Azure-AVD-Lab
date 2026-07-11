<#
.SYNOPSIS
    Register an Azure VM as an AVD Session Host.
.DESCRIPTION
    Validates prerequisites and Azure login, verifies the VM exists and is running,
    ensures host pool exists, validates or creates registration token,
    installs AVD agent if required, registers the session host,
    and verifies registration.
.AUTHOR
    Vinodh
.DATE
    2026-07-11
.NOTES
    Part of the Azure-AVD-Lab project. Assumes prerequisites (RG, Host Pool, VM) already exist.
.EXAMPLE
    .\08-Register-SessionHost.ps1 -VMName vm-avdlab-sh01
#>

[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
param(
    [string]$ResourceGroupName = $Global:ResourceGroupName,
    [string]$HostPoolName      = $Global:HostPoolName,
    [string]$VMName,
    [switch]$Force
)

# Import common modules
. "$PSScriptRoot\..\Common\00-FrameworkRequirements.ps1"
. "$PSScriptRoot\..\Common\01-CommonVariables.ps1"
. "$PSScriptRoot\..\Common\02-NetworkVariables.ps1"
. "$PSScriptRoot\..\Common\03-AzureHelpers.ps1"
. "$PSScriptRoot\..\Common\04-VM-Variables.ps1"
. "$PSScriptRoot\..\Common\05-StorageVariables.ps1"
. "$PSScriptRoot\..\Common\06-AvdHelpers.ps1

# Initialize logging
Write-LabLog "Starting Session Host registration..." -Level Info

# Validate prerequisites
Write-LabLog "Validating prerequisites..." -Level Info
if (-not (Test-LabPrerequisites)) {
    throw "Prerequisite validation failed."
}

# Validate Resource Group
if (-not (Test-ResourceGroup -Name $ResourceGroupName)) {
    throw "Resource Group '$ResourceGroupName' not found."
}
Write-LabLog "Resource Group '$ResourceGroupName' found." -Level Info

# Validate Host Pool
if (-not (Test-HostPool -Name $HostPoolName -ResourceGroupName $ResourceGroupName)) {
    throw "Host Pool '$HostPoolName' not found."
}
Write-LabLog "Host Pool '$HostPoolName' found." -Level Info

# Get VM
$vm = Get-SessionHostVM -Name $VMName -ResourceGroupName $ResourceGroupName
if (-not $vm) {
    throw "VM '$VMName' not found in resource group '$ResourceGroupName'."
}
Write-LabLog "VM '$VMName' found." -Level Info

# Validation checks
if ($vm.PowerState -ne "VM running") {
    throw "VM '$VMName' is not running. Start the VM before registration."
}
Write-LabLog "VM is running." -Level Info

if (-not $vm.HasAgent) {
    throw "Azure VM Agent not detected on '$VMName'. Install the agent before registration."
}
Write-LabLog "Azure VM Agent detected." -Level Info

# Registration token logic
Write-LabLog "Validating registration token..." -Level Info
$token = Get-AvdRegistrationToken -HostPoolName $HostPoolName -ResourceGroupName $ResourceGroupName
if (-not $token -or $token.Expiration -lt (Get-Date)) {
    Write-LabLog "No valid token found. Creating new registration token..." -Level Info
    $token = New-AvdRegistrationToken -HostPoolName $HostPoolName -ResourceGroupName $ResourceGroupName -Force:$Force
}
Write-LabLog "Registration token validated." -Level Info

# Install AVD Agent if missing
if (-not $vm.HasAvdAgent) {
    Write-LabLog "Installing AVD Agent on '$VMName'..." -Level Info
    Install-AvdAgent -VMName $VMName -ResourceGroupName $ResourceGroupName
}
Write-LabLog "AVD Agent installed." -Level Info

# Install AVD Boot Loader if missing
if (-not $vm.HasAvdBootLoader) {
    Write-LabLog "Installing AVD Boot Loader on '$VMName'..." -Level Info
    Install-AvdBootLoader -VMName $VMName -ResourceGroupName $ResourceGroupName
}
Write-LabLog "AVD Boot Loader installed." -Level Info

# Register Session Host
if ($PSCmdlet.ShouldProcess("VM '$VMName'", "Register as Session Host in Host Pool '$HostPoolName'")) {
    Write-LabLog "Registering Session Host '$VMName'..." -Level Info
    Register-AvdSessionHost -VMName $VMName -HostPoolName $HostPoolName -ResourceGroupName $ResourceGroupName -Token $token.Token
}

# Verify Registration
Write-LabLog "Waiting for Session Host heartbeat..." -Level Info
Start-Sleep -Seconds 10
$sessionHost = Get-AvdSessionHost -HostPoolName $HostPoolName -ResourceGroupName $ResourceGroupName -Name $VMName
if ($sessionHost -and $sessionHost.Status -eq "Available") {
    Write-LabLog "Session Host registered successfully." -Level Success
} else {
    throw "Session Host registration failed or heartbeat not detected."
}

# Deployment Summary
Show-DeploymentSummary @{
    "VM Name"            = $VMName
    "Host Pool"          = $HostPoolName
    "Session Host"       = "Registered"
    "Registration Token" = "Valid"
    "Provisioning"       = "Success"
}

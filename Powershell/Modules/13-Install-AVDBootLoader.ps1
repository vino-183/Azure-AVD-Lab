<#
.SYNOPSIS
    Install AVD Boot Loader on Azure VM.
.DESCRIPTION
    Validates Azure connection, resource group, and VM.
    Ensures VM is running, checks if Boot Loader is installed,
    downloads and installs if needed, and verifies installation.
.AUTHOR
    Vinodh
.DATE
    2026-07-12
.NOTES
    Part of Azure-AVD-Lab project.
.EXAMPLE
    .\13-Install-AVDBootLoader.ps1 -VMName vm-avdlab-sessionhost01
#>

[CmdletBinding()]
param(
    [string]$ResourceGroupName,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$VMName
)

# Import framework and helpers
. "$PSScriptRoot\..\Common\00-FrameworkRequirements.ps1"
. "$PSScriptRoot\..\Common\01-CommonVariables.ps1"
. "$PSScriptRoot\..\Common\03-AzureHelpers.ps1"
. "$PSScriptRoot\..\Common\06-AvdHelpers.ps1"

# Apply defaults if parameters not provided
if (-not $ResourceGroupName) { $ResourceGroupName = $Global:ResourceGroupName }

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

    # Check if Boot Loader already installed
    if (Test-AvdBootLoaderInstalled -VMName $VMName -ResourceGroupName $ResourceGroupName) {
        Write-LabLog "Boot Loader already installed on VM '$VMName'." -Level Success
        $result = [PSCustomObject]@{
            Success     = $true
            Version     = Get-AvdBootLoaderVersion -VMName $VMName -ResourceGroupName $ResourceGroupName
            InstallTime = $null
        }
    }
    else {
        Write-LabLog "Copying Boot Loader installer to VM '$VMName'..." -Level Info
        $installer = Get-AvdBootLoaderInstaller
        Copy-AvdBootLoaderInstallerToVM -VMName $VMName -ResourceGroupName $ResourceGroupName -InstallerPath $installer

        Write-LabLog "Installing Boot Loader on VM '$VMName'..." -Level Info
        $result = Install-AvdBootLoader -VMName $VMName -ResourceGroupName $ResourceGroupName

        Write-LabLog "Verifying Boot Loader installation..." -Level Info
        if (-not (Test-AvdBootLoaderInstalled -VMName $VMName -ResourceGroupName $ResourceGroupName)) {
            throw "Boot Loader installation failed on VM '$VMName'."
        }

        # Always retrieve version after verification
        $result.Version = Get-AvdBootLoaderVersion -VMName $VMName -ResourceGroupName $ResourceGroupName
        Write-LabLog "Boot Loader installed successfully (Version $($result.Version))." -Level Success
    }

    # Deployment Summary
    Show-DeploymentSummary @{
        "VM Name"        = $VMName
        "Resource Group" = $ResourceGroupName
        "Boot Loader"    = "Installed"
        "Version"        = $result.Version
        "Status"         = if ($result.Success) { "Success" } else { "Failed" }
        "Install Time"   = $result.InstallTime
    }

    # Return object for consumption by other scripts
    [PSCustomObject]@{
        VMName              = $VMName
        ResourceGroup       = $ResourceGroupName
        BootLoaderInstalled = $result.Success
        Version             = $result.Version
        InstallTime         = $result.InstallTime
    }
}
catch {
    Write-LabLog $_.Exception.Message -Level Error
    throw
}

<#
.SYNOPSIS
    Deploy a Virtual Machine for the selected lab role.

.DESCRIPTION
    Orchestrates the deployment of Azure networking and the virtual machine.
    This script does not create Azure resources directly; it coordinates the
    infrastructure deployment scripts.

.AUTHOR
    Vinodh

.DATE
    2026-07-13
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$Role
)

# Import common modules (catalog, logging, helpers, etc.)
. "$PSScriptRoot\..\01-Common\Import-Common.ps1"

# Validate prerequisites
Write-LabLog "Validating prerequisites..." -Level INFO
if (-not (Test-LabPrerequisites)) {
    throw "Prerequisite validation failed."
}

# Validate role
if (-not $VMCatalog.ContainsKey($Role)) {
    throw "Unknown VM Role '$Role'."
}

# Retrieve profile
$VMProfile = $VMCatalog[$Role]

# Log start
Write-LabLog "Starting deployment of '$($VMProfile.DisplayName)'..." -Level INFO

# Orchestration
if ($PSCmdlet.ShouldProcess($VMProfile.DisplayName, "Deploy Lab Virtual Machine")) {
    try {
        & "$PSScriptRoot\05-New-NetworkInterface.ps1" -Role $Role -ErrorAction Stop
        & "$PSScriptRoot\06-New-VirtualMachine.ps1" -Role $Role -ErrorAction Stop

        Write-LabLog "Deployment of '$($VMProfile.DisplayName)' completed successfully." -Level SUCCESS

        Write-DeploymentSummary -Properties @{
            "Role"        = $Role
            "DisplayName" = $VMProfile.DisplayName
            "Status"      = "Succeeded"
        }

        return [PSCustomObject]@{
            Role        = $Role
            DisplayName = $VMProfile.DisplayName
            Status      = "Succeeded"
        }
    }
    catch {
        Write-LabLog "Deployment failed for role '$Role'" -Level ERROR
        Write-LabLog $_.Exception.Message -Level ERROR
        throw
    }
}

# Future:
# Configure VM
# Validate deployment

<#
.SYNOPSIS
    Configure a Virtual Machine for the selected lab role.

.DESCRIPTION
    Applies role-specific configuration steps after VM deployment.
    Keeps deployment and configuration concerns separate.

.AUTHOR
    Vinodh

.DATE
    2026-07-13
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateSet("DomainController","SessionHost","SQLServer","WebServer")]
    [string]$Role
)

# Import common modules
. "$PSScriptRoot\..\01-Common\Import-Common.ps1"

# Retrieve profile
$VMProfile = $VMCatalog[$Role]

try {
    Write-LabLog "Role selected : $Role" -Level INFO
    Write-LabLog "Starting configuration for '$($VMProfile.DisplayName)'..." -Level INFO

    switch ($Role) {
        "DomainController" {
            Configure-DomainController
            Write-LabLog "Domain Controller configuration completed." -Level SUCCESS
        }

        "SessionHost" {
            Configure-SessionHost
            Write-LabLog "Session Host configuration completed." -Level SUCCESS
        }

        "SQLServer" {
            Configure-SqlServer
            Write-LabLog "SQL Server configuration completed." -Level SUCCESS
        }

        "WebServer" {
            Configure-WebServer
            Write-LabLog "Web Server configuration completed." -Level SUCCESS
        }
    }

    Write-LabLog "Configuration completed for '$($VMProfile.DisplayName)'." -Level SUCCESS

    Write-DeploymentSummary -Properties @{
        Role        = $Role
        DisplayName = $VMProfile.DisplayName
        Stage       = "Configuration"
        Status      = "Succeeded"
        Timestamp   = (Get-Date)
        RoleType    = $VMProfile.Role
    }

    return [PSCustomObject]@{
        Role        = $Role
        DisplayName = $VMProfile.DisplayName
        Stage       = "Configuration"
        Status      = "Succeeded"
        Timestamp   = Get-Date
        RoleType    = $VMProfile.Role
    }
}
catch {
    Write-LabLog $_.Exception.Message -Level ERROR

    Write-DeploymentSummary -Properties @{
        Role        = $Role
        DisplayName = $VMProfile.DisplayName
        Stage       = "Configuration"
        Status      = "Failed"
        Timestamp   = (Get-Date)
        RoleType    = $VMProfile.Role
    }

    throw
}
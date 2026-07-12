<#
.SYNOPSIS
    Retrieve or create a valid AVD registration token.
.DESCRIPTION
    Imports framework, validates Resource Group and Host Pool,
    checks existing registration token, creates new token if expired or forced,
    and outputs token details.
.AUTHOR
    Vinodh
.DATE
    2026-07-11
.NOTES
    Part of Azure-AVD-Lab project.
.EXAMPLE
    .\11-Get-RegistrationToken.ps1 -HostPoolName avdlab-hostpool01
#>

[CmdletBinding()]
param(
    [string]$ResourceGroupName,
    [string]$HostPoolName,
    [switch]$Force
)

# Import framework and helpers
. "$PSScriptRoot\..\Common\00-FrameworkRequirements.ps1"
. "$PSScriptRoot\..\Common\01-CommonVariables.ps1"
. "$PSScriptRoot\..\Common\06-AvdHelpers.ps1"

# Apply defaults if parameters not provided
if (-not $ResourceGroupName) { $ResourceGroupName = $Global:ResourceGroupName }
if (-not $HostPoolName)      { $HostPoolName      = $Global:HostPoolName }

try {
    Write-LabLog "Validating prerequisites..." -Level Info

    # Validate Resource Group
    if (-not (Test-ResourceGroupIfExists -ResourceGroupName $ResourceGroupName)) {
        throw "Resource Group '$ResourceGroupName' not found."
    }

    # Validate Host Pool
    if (-not (Test-HostPoolIfExists -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName)) {
        throw "Host Pool '$HostPoolName' not found."
    }

    # Retrieve or create token using helper
    Write-LabLog "Retrieving registration token..." -Level Info
    $token = Get-OrCreateAvdRegistrationToken -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName -Force:$Force

    Write-LabLog "Registration token retrieved successfully." -Level Success

    # Output token details
    [PSCustomObject]@{
        HostPoolName      = $HostPoolName
        RegistrationToken = $token.Token
        ExpiryTime        = $token.Expiration
    }
}
catch {
    Write-LabLog $_.Exception.Message -Level Error
    throw
}

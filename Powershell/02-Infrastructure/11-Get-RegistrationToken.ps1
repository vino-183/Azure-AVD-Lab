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
    [switch]$Force,
    [int]$TokenValidityHours = 4
)

# Import modules
. "$PSScriptRoot\..\01-Common\Import-Common.ps1"

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

    Write-LabLog "Retrieving registration token..." -Level Info

    $tokenInfo = Get-AzWvdRegistrationInfo -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName

    if ($Force -or -not $tokenInfo.Token) {
        Write-LabLog "Generating new registration token..." -Level Warning
        $tokenInfo = New-AzWvdRegistrationInfo -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName -ExpirationTime (Get-Date).AddHours($TokenValidityHours)
    }

    if ($tokenInfo.Token) {
        Write-LabLog "Registration token retrieved successfully." -Level Success
        [PSCustomObject]@{
            HostPoolName      = $HostPoolName
            RegistrationToken = $tokenInfo.Token
            ExpiryTime        = $tokenInfo.ExpirationTime
        } | Format-Table -AutoSize
    }
    else {
        Write-LabLog "Failed to retrieve or generate a registration token." -Level Error
    }
}
catch {
    Write-LabLog $_.Exception.Message -Level Error
    throw
}

<#
.SYNOPSIS
    Create an AVD Application Group if it does not already exist.
.DESCRIPTION
    Imports modules and variables, validates prerequisites, connects to Azure,
    verifies resource group and host pool, checks if application group exists,
    and creates it if missing. Ends with a deployment summary.
.AUTHOR
    Vinodh
.DATE
    2026-07-11
.NOTES
    Part of the Azure-AVD-Lab project.
.EXAMPLE
    .\09-New-AppGroup.ps1 -HostPoolName hp-avdlab-pooled-001 -AppGroupName dag-avdlab-001
#>

[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
param(
    [string]$ResourceGroupName = $Global:ResourceGroupName,
    [string]$HostPoolName      = $Global:HostPoolName,
    [string]$ApplicationGroupName = $Global:ApplicationGroupName,
    [string]$Location = $Global:Location,
    [bool]$ValidationEnvironment = $false
)

# Import modules
. "$PSScriptRoot\..\Common\03-AzureHelpers.ps1"
. "$PSScriptRoot\..\Common\06-AvdHelpers.ps1"

# Import global variables
. "$PSScriptRoot\..\Common\01-CommonVariables.ps1"

Write-LabLog "Starting Application Group creation..." -Level INFO

try {
    # Validate prerequisites
    Write-LabLog "Validating prerequisites..." -Level INFO
    if (-not (Test-LabPrerequisites)) { throw "Prerequisite validation failed." }

    # Connect to Azure
    Validate-AzContext | Out-Null

    # Verify Resource Group
    $rg = Test-ResourceGroupIfExists -ResourceGroupName $ResourceGroupName
    if (-not $rg) { throw "Resource Group '$ResourceGroupName' not found." }
    Write-LabLog "Resource Group '$ResourceGroupName' verified." -Level SUCCESS

    # Verify Host Pool exists
    $hostPool = Get-AzWvdHostPool -ResourceGroupName $ResourceGroupName -Name $HostPoolName -ErrorAction SilentlyContinue
    if (-not $hostPool) { throw "Host Pool '$HostPoolName' not found in resource group '$ResourceGroupName'." }
    Write-LabLog "Host Pool '$HostPoolName' verified." -Level SUCCESS

    # Check if App Group exists
    $appGroup = Get-AzWvdApplicationGroup -ResourceGroupName $ResourceGroupName -Name $ApplicationGroupName -ErrorAction SilentlyContinue
    if ($appGroup) {
        Write-LabLog "Application Group '$ApplicationGroupName' already exists." -Level INFO

        Write-Output "`nDeployment Summary"
        Write-Output "------------------"
        Write-Output ("Application Group : {0}" -f $ApplicationGroupName)
        Write-Output "Type              : Desktop"
        Write-Output ("Host Pool         : {0}" -f $HostPoolName)
        Write-Output ("Resource Group    : {0}" -f $ResourceGroupName)
        Write-Output ("Location          : {0}" -f $Location)
        Write-Output "Provisioning      : Already Exists"

        return
    }

    # Create Application Group
    if ($PSCmdlet.ShouldProcess("Application Group '$ApplicationGroupName'", "Create Application Group")) {
        Write-LabLog "Creating Application Group '$ApplicationGroupName'..." -Level INFO
        $appGroup = New-AzWvdApplicationGroup `
            -ResourceGroupName $ResourceGroupName `
            -Name $ApplicationGroupName `
            -Location $Location `
            -HostPoolArmPath $hostPool.Id `
            -ApplicationGroupType $Global:ApplicationGroupType `
            -ErrorAction Stop
        Write-LabLog "Application Group '$ApplicationGroupName' created successfully." -Level SUCCESS
    }

    if ([string]::IsNullOrWhiteSpace($ApplicationGroupName)) {
    throw "ApplicationGroupName is not configured. Please set it in 01-GlobalVariables.ps1 or pass it as a parameter."
}

    # Verify only if not running in WhatIf mode
    if (-not $WhatIfPreference) {
        $verify = Get-AzWvdApplicationGroup -ResourceGroupName $ResourceGroupName -Name $ApplicationGroupName -ErrorAction Stop
        if (-not $verify) { throw "Application Group verification failed." }
    }
    else {
        Write-LabLog "WhatIf mode detected. Skipping application group verification." -Level INFO
    }

    # Deployment Summary
    Write-Output "`nDeployment Summary"
    Write-Output "------------------"
    Write-Output ("Application Group : {0}" -f $ApplicationGroupName)
    Write-Output "Type              : Desktop"
    Write-Output ("Host Pool         : {0}" -f $HostPoolName)
    Write-Output ("Resource Group    : {0}" -f $ResourceGroupName)
    Write-Output ("Location          : {0}" -f $Location)
    $provisioningStatus = if ($WhatIfPreference) { "Skipped (WhatIf)" } else { "Succeeded" }
    Write-Output ("Provisioning      : {0}" -f $provisioningStatus)
}
catch {
    Write-LabLog $_.Exception.Message -Level ERROR
    throw
}
finally {
    Write-LabLog "09-New-AppGroup completed." -Level INFO
}

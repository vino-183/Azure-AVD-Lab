<#
.SYNOPSIS
    Create an AVD Host Pool if it does not already exist.
.DESCRIPTION
    Imports modules and variables, validates prerequisites, connects to Azure,
    verifies resource group, checks if host pool exists, and creates it if missing.
    Ends with a deployment summary.
.AUTHOR
    Vinodh
.DATE
    2026-07-11
.NOTES
    Part of the Azure-AVD-Lab project.
.EXAMPLE
    .\08-New-HostPool.ps1 -HostPoolName hp-avdlab-prod
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [string]$ResourceGroupName = $Global:ResourceGroupName,
    [string]$HostPoolName      = $Global:HostPoolName,
    [string]$Location          = $Global:Location,

    [bool]$ValidationEnvironment = $false
)

# Import common modules
. "$PSScriptRoot\..\01-Common\Import-Common.ps1"

Write-LabLog "Starting Host Pool creation..." -Level INFO

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

    # Check if Host Pool exists
    $hostPool = Get-AzWvdHostPool -ResourceGroupName $ResourceGroupName -Name $HostPoolName -ErrorAction SilentlyContinue
    if ($hostPool) {
        Write-LabLog "Host Pool '$HostPoolName' already exists." -Level INFO

        Write-Output "`nDeployment Summary"
        Write-Output "------------------"
        Write-Output ("Host Pool       : {0}" -f $HostPoolName)
        Write-Output ("Resource Group  : {0}" -f $ResourceGroupName)
        Write-Output ("Location        : {0}" -f $Location)
        Write-Output "Status          : Already Exists"

        return
    }

    # Create Host Pool
    if ($PSCmdlet.ShouldProcess("Host Pool '$HostPoolName'", "Create Host Pool")) {
        Write-LabLog "Creating Host Pool '$HostPoolName'..." -Level INFO
        $hostPool = New-AzWvdHostPool `
    -ResourceGroupName $ResourceGroupName `
    -Name $HostPoolName `
    -Location $Location `
    -HostPoolType $Global:HostPoolType `
    -PreferredAppGroupType $Global:PreferredAppGroupType `
    -LoadBalancerType $Global:LoadBalancerType `
    -MaxSessionLimit $Global:MaxSessionLimit `
    -StartVMOnConnect:$Global:StartVMOnConnect `
    -ErrorAction Stop
        Write-LabLog "Host Pool '$HostPoolName' created successfully." -Level SUCCESS
    }

# Verify only if not running in WhatIf mode
    if (-not $WhatIfPreference) {
        $verify = Get-AzWvdHostPool -ResourceGroupName $ResourceGroupName -Name $HostPoolName -ErrorAction Stop
        if (-not $verify) { throw "Host Pool verification failed." }
    }
    else {
        Write-LabLog "WhatIf mode detected. Skipping host pool verification." -Level INFO
    }

 # Deployment Summary
Write-Output "`nDeployment Summary"
Write-Output "------------------"
Write-Output ("Host Pool        : {0}" -f $HostPoolName)
Write-Output ("Type             : Pooled")
Write-Output ("Load Balancer    : BreadthFirst")
Write-Output ("Preferred App    : Desktop")
Write-Output ("Resource Group   : {0}" -f $ResourceGroupName)
Write-Output ("Location         : {0}" -f $Location)
Write-Output "Provisioning     : Succeeded"

} catch {
    # Better logging in catch
    Write-LabLog $_.Exception.Message -Level ERROR
    throw
} finally {
    Write-LabLog "08-New-HostPool completed." -Level INFO
}


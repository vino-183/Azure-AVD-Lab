<#
.SYNOPSIS
    Create an AVD Workspace and associate an Application Group.
.DESCRIPTION
    Imports modules and variables, validates prerequisites, connects to Azure,
    verifies resource group, verifies/creates workspace, verifies app group,
    associates app group, and ends with a deployment summary.
.EXAMPLE
    .\10-New-Workspace.ps1 -WorkspaceName ws-avdlab-001 -ApplicationGroupName dag-avdlab-001 -WhatIf
#>

[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
param(
    [string]$ResourceGroupName     = $Global:ResourceGroupName,
    [string]$WorkspaceName         = $Global:WorkspaceName,
    [string]$WorkspaceFriendlyName = $Global:WorkspaceFriendlyName,
    [string]$WorkspaceDescription  = $Global:WorkspaceDescription,
    [string]$ApplicationGroupName  = $Global:ApplicationGroupName,
    [string]$HostPoolName          = $Global:HostPoolName,
    [string]$Location              = $Global:Location
)

# Import modules
# Import common helpers
. "D:\Cloud-Labs\Azure-AVD-Lab\Powershell\01-Common\00-FrameworkRequirements.ps1"
. "D:\Cloud-Labs\Azure-AVD-Lab\Powershell\01-Common\00-VMCatalog.ps1"
. "D:\Cloud-Labs\Azure-AVD-Lab\Powershell\01-Common\01-CommonVariables.ps1"
. "D:\Cloud-Labs\Azure-AVD-Lab\Powershell\01-Common\02-NetworkVariables.ps1"
. "D:\Cloud-Labs\Azure-AVD-Lab\Powershell\01-Common\04-VM-Variables.ps1"
. "D:\Cloud-Labs\Azure-AVD-Lab\Powershell\01-Common\05-StorageVariables.ps1"
. "D:\Cloud-Labs\Azure-AVD-Lab\Powershell\01-Common\06-AvdHelpers.ps1"
. "D:\Cloud-Labs\Azure-AVD-Lab\Powershell\01-Common\03-AzureHelpers.ps1"

# Validate required values
if ([string]::IsNullOrWhiteSpace($WorkspaceName)) { throw "WorkspaceName is required." }
if ([string]::IsNullOrWhiteSpace($ApplicationGroupName)) { throw "ApplicationGroupName is required." }
if ([string]::IsNullOrWhiteSpace($HostPoolName)) { throw "HostPoolName is required." }


Write-LabLog "Starting Workspace creation..." -Level INFO

try {
    Write-LabLog "Validating prerequisites..." -Level INFO
    if (-not (Test-LabPrerequisites)) { throw "Prerequisite validation failed." }

    $rg = Test-ResourceGroupIfExists -ResourceGroupName $ResourceGroupName
    if (-not $rg) { throw "Resource Group '$ResourceGroupName' not found." }
    Write-LabLog "Resource Group '$ResourceGroupName' verified." -Level SUCCESS

    $workspace = Test-WorkspaceIfExists -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName
    if (-not $workspace) {
        if ($PSCmdlet.ShouldProcess("Workspace '$WorkspaceName'", "Create Workspace")) {
            Write-LabLog "Creating Workspace '$WorkspaceName'..." -Level INFO
            $workspace = New-AzWvdWorkspace `
                -ResourceGroupName $ResourceGroupName `
                -Name $WorkspaceName `
                -Location $Location `
                -FriendlyName $WorkspaceFriendlyName `
                -Description $WorkspaceDescription `
                -ErrorAction Stop
            Write-LabLog "Workspace '$WorkspaceName' created successfully." -Level SUCCESS
        }
    }
    else {
        Write-LabLog "Workspace '$WorkspaceName' already exists." -Level INFO
    }

    $appGroup = Test-AppGroupIfExists -ResourceGroupName $ResourceGroupName -AppGroupName $ApplicationGroupName
    if (-not $appGroup) { throw "Application Group '$ApplicationGroupName' not found." }
    Write-LabLog "Application Group '$ApplicationGroupName' verified." -Level SUCCESS

    if ($PSCmdlet.ShouldProcess("Workspace '$WorkspaceName'", "Associate App Group '$ApplicationGroupName'")) {
        Write-LabLog "Associating Application Group '$ApplicationGroupName' with Workspace '$WorkspaceName'..." -Level INFO
         Register-AzWvdApplicationGroup `
            -ResourceGroupName $ResourceGroupName `
            -WorkspaceName $WorkspaceName `
            -ApplicationGroupPath $appGroup.Id `
            -ErrorAction Stop
        Write-LabLog "Application Group '$ApplicationGroupName' associated successfully." -Level SUCCESS
    }

    if (-not $WhatIfPreference) {
        $verify = Get-WorkspaceIfExists -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName
        if (-not $verify) { throw "Workspace association verification failed." }
    }
    else {
        Write-LabLog "WhatIf mode detected. Skipping workspace verification." -Level INFO
    }

    Write-Output "`nDeployment Summary"
    Write-Output "------------------"
    Write-Output ("Workspace         : {0}" -f $WorkspaceName)
    Write-Output ("Application Group : {0}" -f $ApplicationGroupName)
    Write-Output ("Host Pool         : {0}" -f $HostPoolName)
    Write-Output ("Location          : {0}" -f $Location)
    $provisioningStatus = if ($WhatIfPreference) { "Skipped (WhatIf)" } else { "Succeeded" }
    Write-Output ("Provisioning      : {0}" -f $provisioningStatus)
}
catch {
    Write-LabLog $_.Exception.Message -Level ERROR
    throw
}
finally {
    Write-LabLog "10-New-Workspace completed." -Level INFO
}

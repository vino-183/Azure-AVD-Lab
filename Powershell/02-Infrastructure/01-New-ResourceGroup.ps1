<#
================================================================================
Script:     01-New-ResourceGroup.ps1
Purpose:    Creates an Azure Resource Group if it does not already exist.
Author:     Vinodh Azure-AVD-Lab
Version:    1.0.0
================================================================================
Learning Objectives
-------------------
✓ Dot sourcing
✓ Parameter validation
✓ Azure Resource Groups
✓ Idempotent scripting
✓ Error handling
================================================================================
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param()
# Import common modules

. "D:\Cloud-Labs\Azure-AVD-Lab\Powershell\01-Common\Import-Common.ps1"

# Validate prerequisites

if (-not (Test-LabPrerequisites)) {
    Write-LabLog "Prerequisite validation failed. Deployment aborted." -Level ERROR
    throw "Prerequisite validation failed."
}

# Verify Resource Group Exists

Write-LabLog "Checking if Resource Group '$ResourceGroupName' exists..."

$resourceGroup = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue

if ($null -eq $resourceGroup) {

    if ($PSCmdlet.ShouldProcess($ResourceGroupName, "Create Resource Group")) {

        Write-LabLog "Creating Resource Group '$ResourceGroupName'..."

        try {
            $resourceGroup = New-AzResourceGroup `
                -Name $ResourceGroupName `
                -Location $Location `
                -ErrorAction Stop

            return $resourceGroup

            Write-LabLog "Resource Group created successfully." -Level SUCCESS
        }
        catch {
            Write-LabLog "Failed to create Resource Group '$ResourceGroupName'."

Write-LabLog $_

throw
        }
    }
}
else {
    Write-LabLog "Resource Group '$ResourceGroupName' already exists." -Level WARNING
}
<#
.SYNOPSIS
    Deploys or verifies a Storage Account in the lab environment.

.DESCRIPTION
    Validates prerequisites, checks for existing resources, creates the storage account if needed,
    and returns a deployment summary.
#>

[CmdletBinding(SupportsShouldProcess)]
param()

# Import common variables and helper functions
. "D:\Cloud-Labs\Azure-AVD-Lab\Powershell\01-Common\Import-Common.ps1"

# ================================
# Validate Prerequisites
# ================================
Test-LabPrerequisites
Validate-AzContext   # logs success internally

# ================================
# Deployment Body
# ================================
$finalAccount = $null

try {
    # Verify Resource Group
    $resourceGroup = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
    if (-not $resourceGroup) { throw "Resource Group '$ResourceGroupName' not found." }
    Write-LabLog "Resource Group verified: $ResourceGroupName" -Level INFO

    # Verify Existing Resource First
    $existingAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction SilentlyContinue
    if ($existingAccount) {
        Write-LabLog "Storage Account '$StorageAccountName' already exists." -Level INFO
        $finalAccount = $existingAccount
    }
    else {
        # Check Global Name Availability
        $nameAvailable = Get-AzStorageAccountNameAvailability -Name $StorageAccountName
        if (-not $nameAvailable.NameAvailable) {
            throw "Storage Account name '$StorageAccountName' is not available. Reason: $($nameAvailable.Reason)"
        }

        # Validate parameters
        if (-not $StorageSku -or -not $StorageKind) {
            throw "Storage account parameters are missing (Sku/Kind)."
        }

        if ($PSCmdlet.ShouldProcess("Storage Account: $StorageAccountName", "Create")) {
            Write-LabLog "Creating Storage Account '$StorageAccountName'..." -Level INFO
            $storageAccount = New-AzStorageAccount -ResourceGroupName $ResourceGroupName `
                -Name $StorageAccountName `
                -Location $Location `
                -SkuName $StorageSku `
                -Kind $StorageKind `
                -AccessTier $StorageAccessTier

            $finalAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName
            if ($finalAccount.ProvisioningState -ne "Succeeded") {
                throw "Provisioning failed. Current state: $($finalAccount.ProvisioningState)"
            }
        }
    }

    if ($finalAccount) {
        Write-LabLog "Storage Account '$($finalAccount.StorageAccountName)' deployment succeeded." -Level INFO

        Write-Output @"
Deployment Summary
------------------
Storage Account : $($finalAccount.StorageAccountName)
Resource Group  : $($finalAccount.ResourceGroupName)
Location        : $($finalAccount.Location)
SKU             : $($finalAccount.Sku.Name)
Kind            : $($finalAccount.Kind)
Access Tier     : $($finalAccount.AccessTier)
Provisioning    : $($finalAccount.ProvisioningState)
Timestamp       : $(Get-Date)
"@
    }

    return $finalAccount
}
catch {
    Write-LabLog "Storage account deployment failed." -Level ERROR
    Write-LabLog $_.Exception.Message -Level ERROR
    Write-LabLog $_.ScriptStackTrace -Level ERROR
    throw
}
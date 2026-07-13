[CmdletBinding(SupportsShouldProcess)]
param()

# Import common variables and helper functions
. "$PSScriptRoot\..\01-Common\Import-Common.ps1"

# ================================
# Validate Prerequisites
# ================================
Test-LabPrerequisites
Validate-AzContext   # <-- already logs success internally, no need to log again

# ================================
# Deployment Body
# ================================
$finalAccount = $null

try {
    # Verify Resource Group
    $resourceGroup = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
    if (-not $resourceGroup) { throw "Resource Group '$ResourceGroupName' not found." }
    Write-LabLog "Resource Group verified: $ResourceGroupName"

    # Verify Existing Resource First
    $existingAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction SilentlyContinue
    if ($existingAccount) {
        Write-LabLog "Storage Account '$StorageAccountName' already exists."
        $finalAccount = $existingAccount
    }
    else {
        # Check Global Name Availability
        $nameAvailable = Get-AzStorageAccountNameAvailability -Name $StorageAccountName
        if (-not $nameAvailable.NameAvailable) {
            throw "Storage Account name '$StorageAccountName' is not available. Reason: $($nameAvailable.Reason)"
        }

        if ($PSCmdlet.ShouldProcess("Storage Account: $StorageAccountName", "Create")) {
            Write-LabLog "Creating Storage Account '$StorageAccountName'..."
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
"@
    }

    return $finalAccount
}
catch {
    Write-LabLog $_.Exception.Message -Level Error
    throw
}

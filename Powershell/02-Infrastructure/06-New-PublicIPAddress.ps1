function New-LabPublicIPAddress {

    param(
        [string]$ResourceGroupName,
        [string]$Location,
        [string]$PublicIPName,
        [string]$Sku = "Standard",
        [string]$AllocationMethod = "Static"
    )

    $existing = Get-AzPublicIpAddress `
        -ResourceGroupName $ResourceGroupName `
        -Name $PublicIPName `
        -ErrorAction SilentlyContinue

    if ($existing) {
        Write-LabLog "Public IP '$PublicIPName' already exists." -Level INFO
        return $existing
    }

    Write-LabLog "Creating Public IP '$PublicIPName'..." -Level INFO

    New-AzPublicIpAddress `
        -ResourceGroupName $ResourceGroupName `
        -Location $Location `
        -Name $PublicIPName `
        -Sku $Sku `
        -AllocationMethod $AllocationMethod
}
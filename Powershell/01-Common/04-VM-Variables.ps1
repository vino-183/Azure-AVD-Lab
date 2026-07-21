<#
.SYNOPSIS
    VM Configuration Variables

.DESCRIPTION
    Defines VM configurations and maps the selected VM
    to generic deployment variables used by the infrastructure scripts.

.NOTES
    Infrastructure scripts should ONLY reference generic variables:
        $VMName
        $ComputerName
        $NICName
        $PrivateIPAddress
        $SubnetName
        $NSGName
        $VMSize
        $ImagePublisher
        $ImageOffer
        $ImageSku
        $ImageVersion
        $OSDiskSizeGB
        $OSDiskSku
#>

# ============================================================
# VM Catalog
# ============================================================

$DomainController = @{
    VMName           = "vm-avdlab-dc01"
    ComputerName     = "AVDDC01"
    NICName          = "nic-avdlab-dc01"
    PrivateIPAddress = "10.20.1.4"
    VMSize           = "Standard_D2als_v7"
    ImagePublisher   = "MicrosoftWindowsServer"
    ImageOffer       = "WindowsServer"
    ImageSku         = "2025-datacenter-azure-edition"
    ImageVersion     = "latest"
    OSDiskSizeGB     = 128
    OSDiskSku        = "Premium_LRS"
    SubnetName       = $InfrastructureSubnet
    NSGName          = $NSGName
}

$WebVM = @{
    VMName           = "vm-avdlab-web01"
    ComputerName     = "AVDWEB01"
    NICName          = "nic-avdlab-web01"
    PrivateIPAddress = "10.20.2.4"
    VMSize           = "Standard_D2als_v7"
    ImagePublisher   = "MicrosoftWindowsServer"
    ImageOffer       = "WindowsServer"
    ImageSku         = "2025-datacenter-azure-edition"
    ImageVersion     = "latest"
    OSDiskSizeGB     = 128
    OSDiskSku        = "Premium_LRS"
    SubnetName       = $WebSubnet
    NSGName          = $NSGName
}

$SessionHost = @{
    VMName           = "vm-avdlab-sh01"
    ComputerName     = "AVDSH01"
    NICName          = "nic-avdlab-sh01"
    PrivateIPAddress = "10.20.3.4"
    VMSize           = "Standard_D2als_v7"
    ImagePublisher   = "MicrosoftWindowsDesktop"
    ImageOffer       = "Windows-11"
    ImageSku         = "win11-24h2-avd"
    ImageVersion     = "latest"
    OSDiskSizeGB     = 128
    OSDiskSku        = "Premium_LRS"
    SubnetName       = $SessionHostSubnet
    NSGName          = $NSGName
}

# ============================================================
# Select Deployment Type
# ============================================================

if (-not $DeploymentType) {
    $DeploymentType = "DomainController"
}

switch ($DeploymentType) {
    "DomainController" { $VM = $DomainController }
    "WebVM"            { $VM = $WebVM }
    "SessionHost"      { $VM = $SessionHost }
    default { throw "Unknown DeploymentType '$DeploymentType'." }
}

# ============================================================
# Generic Deployment Variables
# ============================================================

$VMName           = $VM.VMName
$ComputerName     = $VM.ComputerName
$NICName          = $VM.NICName
$PrivateIPAddress = $VM.PrivateIPAddress
$SubnetName       = $VM.SubnetName
$NSGName          = $VM.NSGName
$VMSize           = $VM.VMSize
$ImagePublisher   = $VM.ImagePublisher
$ImageOffer       = $VM.ImageOffer
$ImageSku         = $VM.ImageSku
$ImageVersion     = $VM.ImageVersion
$OSDiskSizeGB     = $VM.OSDiskSizeGB
$OSDiskSku        = $VM.OSDiskSku

# ============================================================
# Validation
# ============================================================

if ([string]::IsNullOrWhiteSpace($VMName))           { throw "VMName was not initialized." }
if ([string]::IsNullOrWhiteSpace($NICName))          { throw "NICName was not initialized." }
if ([string]::IsNullOrWhiteSpace($SubnetName))       { throw "SubnetName was not initialized." }
if ([string]::IsNullOrWhiteSpace($NSGName))          { throw "NSGName was not initialized." }

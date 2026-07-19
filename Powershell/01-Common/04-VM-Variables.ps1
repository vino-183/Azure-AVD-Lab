# ============================
# Network Variables
# ============================

# NSG
$NSGName = "nsg-avdlab-eastus-001"

# Virtual Network
$VNetName     = "vnet-avdlab-eastus-001"
$AddressSpace = "10.20.0.0/16"

# Subnet catalog (for automation/loops)
$SubnetNames = @(
    "snet-infrastructure",
    "snet-sessionhosts",
    "snet-privateendpoints",
    "snet-futureservices",
    "snet-domain",
    "snet-web"
)

$SubnetAddressSpaces = @{
    "snet-infrastructure"   = "10.20.1.0/24"
    "snet-sessionhosts"     = "10.20.2.0/24"
    "snet-privateendpoints" = "10.20.3.0/24"
    "snet-futureservices"   = "10.20.4.0/24"
    "snet-domain"           = "10.20.5.0/24"
    "snet-web"              = "10.20.6.0/24"
}

# Frequently used subnet variables
$InfrastructureSubnet   = "snet-infrastructure"
$SessionHostSubnet      = "snet-sessionhosts"
$PrivateEndpointSubnet  = "snet-privateendpoints"
$FutureServicesSubnet   = "snet-futureservices"
$DomainSubnet           = "snet-domain"
$WebSubnet              = "snet-web"

# NIC defaults
$EnabledAcceleratedNetworking = $false
$EnableIPForwarding           = $false
$PrivateIPAllocationMethod    = "Dynamic" # Options: "Dynamic", "Static"
# $CreatePublicIP = $false

# ============================
# Web VM Variables
# ============================
$WebVMName     = "vm-avdlab-web01"
$WebVMSize     = "Standard_D2alds_v7"
$WebCompName   = "AVDWEB01"
$WebOSDisk     = "osdisk-avdlab-web01"
$WebOSDiskType = "Premium_LRS"
$WebImgPub     = "MicrosoftWindowsServer"
$WebImgOffer   = "WindowsServer"
$WebImgSku     = "2022-datacenter-azure-edition"
$WebImgVer     = "latest"
$WebBootDiag   = $true
$WebSubnet     = $WebSubnet
$WebNICName    = "nic-avdlab-web01"
$WebvCPU       = 2
$WebMemGB      = 4

# ============================
# Domain Controller VM Variables
# ============================
$DCVMName     = "vm-avdlab-dc01"
$DCVMSize     = "Standard_D2alds_v7"
$DCCompName   = "AVDDC01"
$DCOSDisk     = "osdisk-avdlab-dc01"
$DCOSDiskType = "Premium_LRS"
$DCImgPub     = "MicrosoftWindowsServer"
$DCImgOffer   = "WindowsServer"
$DCImgSku     = "2022-datacenter-azure-edition"
$DCImgVer     = "latest"
$DCBootDiag   = $true
$DCvCPU       = 2
$DCMemGB      = 4
$DCNICName    = "nic-avdlab-dc01"
$DCSubnet     = $DomainSubnet   # ✅ references the defined subnet variable
$DCPrivateIP  = "10.20.5.4"
$DCNSGName    = "nsg-domain"

$Domain = @{
    Name             = "contoso.local"
    NetBIOS          = "CONTOSO"
    SafeModePassword = "<SecureString>"
    OU               = "OU=AVD,DC=contoso,DC=local"
}

# ============================
# Session Host VM Variables
# ============================
$SHVMName     = "vm-avdlab-sh01"
$SHVMSize     = "Standard_D2alds_v7"
$SHCompName   = "AVDSH01"
$SHOSDisk     = "osdisk-avdlab-sh01"
$SHOSDiskType = "Premium_LRS"
$SHImgPub     = "MicrosoftWindowsServer"
$SHImgOffer   = "WindowsServer"
$SHImgSku     = "2022-datacenter-azure-edition"
$SHImgVer     = "latest"
$SHBootDiag   = $true
$SHSubnet     = $SessionHostSubnet   # ✅ references the defined subnet variable
$SHNICName    = "nic-avdlab-sh01"
$SHvCPU       = 2
$SHMemGB      = 4

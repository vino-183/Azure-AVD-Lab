# region NSG
$NSGName = "nsg-avdlab-eastus-001"
# endregion NSG

# region Virtual Network
$VNetName      = "vnet-avdlab-eastus-001"
$AddressSpace  = "10.20.0.0/16"

# Subnet catalog (for loops/automation)

$SubnetNames = @(
    "snet-infrastructure",
    "snet-sessionhosts",
    "snet-privateendpoints",
    "snet-futureservices"
)

$SubnetAddressSpaces = @{
    "snet-infrastructure"   = "10.20.1.0/24"
    "snet-sessionhosts"     = "10.20.2.0/24"
    "snet-privateendpoints" = "10.20.3.0/24"
    "snet-futureservices"   = "10.20.4.0/24"
}

# Frequently used subnet variables (for readability in scripts)
$InfrastructureSubnet   = "snet-infrastructure"
$SessionHostSubnet      = "snet-sessionhosts"
$PrivateEndpointSubnet  = "snet-privateendpoints"
$FutureServicesSubnet   = "snet-futureservices"
#endregion

# region NIC Defaults
$EnabledAcceleratedNetworking = $false
$EnableIPForwarding           = $false
$PrivateIPAllocationMethod    = "Dynamic" # Options: "Dynamic", "Static"
# $CreatePublicIP = $false
#endregion

# region VM NIC Names
$DCVMName  = "vm-avdlab-dc01"
$DCNICName = "nic-avdlab-dc01"

$SHVMName  = "vm-avdlab-sh01"
$SHNICName = "nic-avdlab-sh01"
#endregion
#region Network Security

$NSGName = "nsg-avdlab-eastus-001"

#endregion

#region Virtual Network

$VNetName = "vnet-avdlab-eastus-001"
$AddressSpace = "10.20.0.0/16"

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

#endregion

# Network Interface Variables
$NetworkInterfaceName = "nic-avdlab-eastus-001"
$EnabledAcceleratedNetworking = $false
$EnableIPForwarding = $false
$PrivateIPAllocationMethod = "Dynamic" # Options: "Dynamic", "Static"
#$CreatePublicIP = $false
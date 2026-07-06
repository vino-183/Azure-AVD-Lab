#endregion

#region Subnets
$NetworkSecurityGroup = 'nsg-avdlab-sessionhosts-eastus-001'

$InfrastructureSubnetName = "snet-infrastructure"

$SessionHostSubnetName = "snet-sessionhosts"

$PrivateEndpointSubnetName = "snet-privateendpoints"

$FutureServicesSubnetName = "snet-futureservices"
#endregion

#region Network Security Groups

$SessionHostNSGName = "nsg-avdlab-sessionhosts-eastus-001"
$InfrastructureNSGName = "nsg-avdlab-infrastructure-eastus-001"

#endregion

$NetworkConfig = @{
    VNetName = "vnet-avdlab-eastus-001"
    AddressSpace = "10.20.0.0/16"

    Subnets = @{
        Infrastructure   = "10.20.1.0/24"
        SessionHosts     = "10.20.2.0/24"
        PrivateEndpoints = "10.20.3.0/24"
        FutureServices   = "10.20.4.0/24"
    }
}


NSGs
Route tables (later)
NAT Gateway (later)
DNS Servers (later)
Private DNS Zones (later)
Bastion subnet (optional, later
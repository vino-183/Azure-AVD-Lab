$VMCatalog = @{

    SessionHost = @{

        DisplayName = "AVD Session Host"

        VM = @{
            Name         = "vm-avdlab-sh01"
            ComputerName = "AVDSH01"
            Size         = "Standard_D2alds_v7"
            vCPU = 2
            MemoryGB = 4
        }

        Network = @{
            NICName                     = "nic-avdlab-sh01"
            SubnetName                  = "snet-sessionhosts"
            PrivateIP                   = "10.0.1.40"
            NSGName                     = "nsg-avdlab-eastus-001"
            EnableIPForwarding          = $false
            EnableAcceleratedNetworking = $true
        }

        Image = @{
            Publisher = "MicrosoftWindowsDesktop"
            Offer     = "Windows-11"
            SKU       = "win11-23h2-avd"
            Version   = "latest"
        }

        OSDisk = @{
            SizeGB = 128
            SKU    = "Premium_LRS"
        }

        Tags = @{
            Role        = "SessionHost"
            Environment = "Lab"
        }
    }
}
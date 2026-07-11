# Session Host VM

$VMName = "vm-avdlab-sh01"

$VMSize = "Standard_D2s_v5"

$ComputerName = "AVDSH01"

$OSDiskName = "osdisk-avdlab-sh01"

$OSDiskType = "Premium_LRS"

$ImagePublisher = "MicrosoftWindowsServer"

$ImageOffer = "WindowsServer"

$ImageSku = "2022-datacenter-azure-edition"

$ImageVersion = "latest"

$EnableBootDiagnostics = $true

$SubnetName = "snet-sessionhosts"

$Global:VmvCPU    = 2

$Global:VmMemoryGB = 4
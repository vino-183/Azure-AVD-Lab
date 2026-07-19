Powershell
├── 01-Common
├── 02-Infrastructure
├── 03-Configuration
├── 04-Management
└── AVD Build
    ├── 01-New-HostPool.ps1
    ├── 02-New-AppGroup.ps1
    ├── 03-New-Workspace.ps1
    ├── 04-Get-RegistrationToken.ps1
    └── 05-New-SessionHost.ps1

05-New-SessionHost.ps1
        │
        ├── Calls 07-Deploy-VirtualMachine.ps1
        │         │
        │         ├── 05-New-NetworkInterface.ps1
        │         └── 06-New-VirtualMachine.ps1
        │
        ├── Gets Registration Token
        ├── Installs/Configures the AVD extension
        ├── Waits for provisioning
        └── Verifies Session Host registration

#-----------------------------------------------------
V1.0
#--------------------------------------------------

At this point, the framework is starting to come together:

01-Common
│
├── CommonVariables
├── AzureHelpers
├── AvdHelpers
│     ├── Get-LabRegistrationToken
│     ├── Install-LabAvdExtension   ✅
│     └── Test-LabSessionHostRegistration
│
└── Import-Common

02-Infrastructure
│
├── New-ResourceGroup
├── New-VirtualNetwork
├── New-NSG
├── New-Storage
├── New-NetworkInterface
└── New-VirtualMachine

05-AVD
│
├── New-HostPool
├── New-AppGroup
├── New-Workspace
├── Get-RegistrationToken
└── New-SessionHost
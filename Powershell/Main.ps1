<#
    Title      : Main.ps1
    Author     : vinodh
    Date       : 2026-07-13
    Description: Entry point for Azure Lab Automation Framework.
                 Orchestrates Infrastructure, Configuration, and Management menus.
#>

# Import common modules (catalog, logging, helpers, etc.)
. "$PSScriptRoot\01-Common\Import-Common.ps1"

function Show-MainMenu {
    Clear-Host
    Write-Host "Azure Lab Automation Framework"
    Write-Host "==============================="
    Write-Host "1. Infrastructure"
    Write-Host "2. Configuration"
    Write-Host "3. Management"
    Write-Host "0. Exit"
    Write-Host "==============================="
}

function Show-InfrastructureMenu {
    Clear-Host
    Write-Host "Infrastructure"
    Write-Host "=============="
    Write-Host "1. Create Resource Group"
    Write-Host "2. Create Virtual Network"
    Write-Host "3. Create Network Security Group"
    Write-Host "4. Create Storage Account"
    Write-Host "5. Deploy Virtual Machine"
    Write-Host "0. Back"
    Write-Host "=============="
}

function Show-VMProfiles {
    Clear-Host
    Write-Host "Virtual Machine Profiles"
    Write-Host "========================"

    $i = 1
    $profiles = $VMCatalog.Keys | Sort-Object
    foreach ($profile in $profiles) {
        Write-Host "$i. $($VMCatalog[$profile].DisplayName)"
        $i++
    }

    Write-Host "0. Back"
    Write-Host "========================"
}

# --- Main Loop ---
do {
    Show-MainMenu
    $Choice = Read-Host "Select an option"

    switch ($Choice) {
        1 {
            do {
                Show-InfrastructureMenu
                $InfraChoice = Read-Host "Select an Infrastructure option"

                switch ($InfraChoice) {
                    1 { & "$PSScriptRoot\02-Infrastructure\01-New-ResourceGroup.ps1" }
                    2 { & "$PSScriptRoot\02-Infrastructure\02-New-VirtualNetwork.ps1" }
                    3 { & "$PSScriptRoot\02-Infrastructure\03-New-NetworkSecurityGroup.ps1" }
                    4 { & "$PSScriptRoot\02-Infrastructure\04-New-Storage.ps1" }
                    5 {
                        do {
                            Show-VMProfiles
                            $VMChoice = Read-Host "Select a VM profile"

                            if ($VMChoice -eq 0) { break }

                            $profiles = $VMCatalog.Keys | Sort-Object
                            if ($VMChoice -gt 0 -and $VMChoice -le $profiles.Count) {
                                $Role = $profiles[$VMChoice - 1]
                                Write-Host "Deploying role: $Role"

                                try {
                                    & "$PSScriptRoot\02-Infrastructure\07-New-LabVirtualMachine.ps1" -Role $Role -ErrorAction Stop
                                }
                                catch {
                                    Write-LabLog "Deployment failed: $_" -Level ERROR
                                }
                            }
                            else {
                                Write-Host "Invalid selection. Please try again."
                            }
                        } while ($VMChoice -ne 0)
                    }
                    0 { break }
                    default { Write-Host "Invalid selection. Please try again." }
                }
            } while ($InfraChoice -ne 0)
        }
        2 {
            # TODO: Show-ConfigurationMenu
        }
        3 {
            # TODO: Show-ManagementMenu
        }
        0 { return }
        default { Write-Host "Invalid selection. Please try again." }
    }
} while ($Choice -ne 0)

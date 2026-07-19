function Configure-DomainController {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$VMName,

        [Parameter(Mandatory)]
        [pscredential]$SafeModeAdministratorCredential,

        [Parameter(Mandatory)]
        [string]$DomainName,

        [Parameter(Mandatory)]
        [string]$NetBIOSName
    )

    try {
        Write-LabLog "Starting Domain Controller configuration for '$VMName'..." -Level INFO

        #region Check Current Role
        Write-LabLog "Checking current server role..." -Level INFO
        $cs = Get-CimInstance Win32_ComputerSystem
        if ($cs.DomainRole -ge 4) {
            Write-LabLog "Server is already a Domain Controller." -Level INFO
            return [PSCustomObject]@{
                Role        = "DomainController"
                VMName      = $VMName
                Stage       = "Configuration"
                Status      = "AlreadyDC"
                DomainName  = $DomainName
                NetBIOSName = $NetBIOSName
                Timestamp   = Get-Date
            }
        }
        #endregion

        #region Install ADDS
        Write-LabLog "Checking ADDS installation..." -Level INFO
        $feature = Get-WindowsFeature AD-Domain-Services
        if (-not $feature.Installed) {
            if ($PSCmdlet.ShouldProcess($VMName, "Install Active Directory Domain Services")) {
                Write-LabLog "Installing ADDS feature..." -Level INFO
                Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools -ErrorAction Stop
                $feature = Get-WindowsFeature AD-Domain-Services
                if (-not $feature.Installed) {
                    throw "ADDS installation verification failed."
                }
                Write-LabLog "ADDS feature installed and verified." -Level SUCCESS
            }
        }
        else {
            Write-LabLog "ADDS already installed." -Level INFO
        }
        #endregion

        #region Promote Server
        Import-Module ADDSDeployment -ErrorAction Stop
        if ($PSCmdlet.ShouldProcess($VMName, "Promote to Domain Controller")) {
            Write-LabLog "Starting forest creation..." -Level INFO
            Install-ADDSForest `
                -DomainName $DomainName `
                -DomainNetbiosName $NetBIOSName `
                -SafeModeAdministratorPassword $SafeModeAdministratorCredential.Password `
                -Force `
                -NoRebootOnCompletion
            Write-LabLog "Forest creation completed. Server restart required." -Level WARN

            return [PSCustomObject]@{
                Role        = "DomainController"
                VMName      = $VMName
                Stage       = "Configuration"
                Status      = "RestartRequired"
                DomainName  = $DomainName
                NetBIOSName = $NetBIOSName
                Timestamp   = Get-Date
            }
        }
        #endregion
    }
    catch {
        Write-LabLog "Domain Controller configuration failed: $_" -Level ERROR

        Write-DeploymentSummary -Properties @{
            Role        = "DomainController"
            VMName      = $VMName
            Stage       = "Configuration"
            Status      = "Failed"
            DomainName  = $DomainName
            NetBIOSName = $NetBIOSName
            Timestamp   = Get-Date
        }

        throw
    }
}
function Configure-DomainJoin {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$VMName,

        [Parameter(Mandatory)]
        [string]$DomainName,

        [Parameter(Mandatory)]
        [pscredential]$DomainCredential
    )

    try {
        Write-LabLog "Starting domain join configuration for '$VMName'..." -Level INFO

        #region Check Current Domain
        Write-LabLog "Checking current domain membership..." -Level INFO
        $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
        if ($cs.PartOfDomain -and $cs.Domain -eq $DomainName) {
            Write-LabLog "Server already joined to '$DomainName'." -Level INFO

            Write-DeploymentSummary -Properties @{
                Role       = "DomainJoin"
                VMName     = $VMName
                Stage      = "Configuration"
                Status     = "AlreadyJoined"
                DomainName = $DomainName
                Timestamp  = Get-Date
            }

            return [PSCustomObject]@{
                Role       = "DomainJoin"
                VMName     = $VMName
                Stage      = "Configuration"
                Status     = "AlreadyJoined"
                DomainName = $DomainName
                Timestamp  = Get-Date
            }
        }
        #endregion

        #region Test Domain Reachability
        Write-LabLog "Testing reachability of domain '$DomainName'..." -Level INFO
        if (-not (Test-Connection -ComputerName $DomainName -Count 1 -Quiet)) {
            throw "Domain '$DomainName' is not reachable."
        }
        Write-LabLog "Domain '$DomainName' is reachable." -Level SUCCESS
        #endregion

        #region Join Computer
        if ($PSCmdlet.ShouldProcess($VMName, "Join domain '$DomainName'")) {
            Write-LabLog "Joining computer to domain '$DomainName'..." -Level INFO
            Add-Computer `
                -DomainName $DomainName `
                -Credential $DomainCredential `
                -Force `
                -ErrorAction Stop

            Write-LabLog "Domain join initiated. Restart required." -Level WARN

            Write-DeploymentSummary -Properties @{
                Role       = "DomainJoin"
                VMName     = $VMName
                Stage      = "Configuration"
                Status     = "RestartRequired"
                DomainName = $DomainName
                Timestamp  = Get-Date
            }

            return [PSCustomObject]@{
                Role       = "DomainJoin"
                VMName     = $VMName
                Stage      = "Configuration"
                Status     = "RestartRequired"
                DomainName = $DomainName
                Timestamp  = Get-Date
            }
        }
        #endregion
    }
    catch {
        Write-LabLog "Domain join configuration failed: $_" -Level ERROR

        Write-DeploymentSummary -Properties @{
            Role       = "DomainJoin"
            VMName     = $VMName
            Stage      = "Configuration"
            Status     = "Failed"
            DomainName = $DomainName
            Timestamp  = Get-Date
        }

        throw
    }
}


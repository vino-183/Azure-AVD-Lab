<#
.SYNOPSIS
    Promote server to Domain Controller.

.DESCRIPTION
    Installs AD DS and DNS roles, validates prerequisites, creates a new forest,
    and ensures idempotency by checking if the server is already a DC.

.PARAMETER DomainName
    The FQDN of the new forest root domain.

.PARAMETER NetBIOSName
    The NetBIOS name of the domain.

.PARAMETER SafeModePassword
    The password for Directory Services Restore Mode (DSRM).

.PARAMETER ForestMode
    Forest functional level (default: WinThreshold).

.PARAMETER DomainMode
    Domain functional level (default: WinThreshold).
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$DomainName,

    [Parameter(Mandatory)]
    [string]$NetBIOSName,

    [Parameter(Mandatory)]
    [SecureString]$SafeModePassword,

    [string]$ForestMode = "WinThreshold",
    [string]$DomainMode = "WinThreshold"
)

try {
    Write-Host "Starting Domain Controller promotion..."
    Write-Host "Computer Name : $env:COMPUTERNAME"
    Write-Host "Domain        : $DomainName"
    Write-Host "NetBIOS       : $NetBIOSName"

    # 1. Validate OS
    $os = Get-CimInstance Win32_OperatingSystem
    if ($os.ProductType -eq 1) {
        throw "Active Directory Domain Services can only be installed on Windows Server."
    }

    # 2. Check for pending reboot
    $pendingReboot = Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"
    if ($pendingReboot) {
        throw "A reboot is pending. Restart the server before promoting it to a Domain Controller."
    }

    # 3. Check if already a Domain Controller
    $DomainRole = (Get-CimInstance Win32_ComputerSystem).DomainRole
    if ($DomainRole -ge 4) {
        Write-Host "Already a Domain Controller. Skipping promotion."
        return
    }

    # 4. Verify networking
    $ip = Get-NetIPAddress -AddressFamily IPv4 |
          Where-Object {
              $_.IPAddress -notlike "169.254*" -and
              $_.PrefixOrigin -ne "WellKnown"
          } |
          Select-Object -First 1
    if (-not $ip) {
        throw "No valid IPv4 address found."
    }
    Write-Host "IPv4 Address : $($ip.IPAddress)"

    # 5. Install AD DS + DNS roles
    Write-Host "Installing AD DS and DNS roles..."
    Install-WindowsFeature AD-Domain-Services, DNS -IncludeManagementTools -ErrorAction Stop

    # 6. Validate role installation
    $ADDSRole = Get-WindowsFeature AD-Domain-Services
    $DNSRole  = Get-WindowsFeature DNS
    if (-not $ADDSRole.Installed -or -not $DNSRole.Installed) {
        throw "Role installation failed. AD DS or DNS not installed."
    }

    # 7. Import ADDSDeployment module
    Import-Module ADDSDeployment -ErrorAction Stop

    # 8. Promote to Domain Controller
    if ($PSCmdlet.ShouldProcess($DomainName, "Create new AD DS forest")) {
        Write-Host "Creating forest '$DomainName'..."
        Install-ADDSForest `
            -DomainName $DomainName `
            -DomainNetbiosName $NetBIOSName `
            -ForestMode $ForestMode `
            -DomainMode $DomainMode `
            -InstallDNS `
            -SafeModeAdministratorPassword $SafeModePassword `
            -Force `
            -NoRebootOnCompletion

        Write-Host "Active Directory forest installation completed successfully."
        Write-Host "Forest creation completed. Restart required."
    }

    # 9. Return structured result
    return [PSCustomObject]@{
        ComputerName = $env:COMPUTERNAME
        DomainName   = $DomainName
        Status       = "PromotionCompleted"
        Restart      = $true
    }
}
catch {
    Write-Error "Domain Controller promotion failed: $($_.Exception.Message)"
    throw
}

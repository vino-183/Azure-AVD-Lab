<#
    File    : 04-AvdHelpers.ps1
    Version : 1.1.0
    Purpose : AVD-specific helper functions for Session Host registration

    Change Log
    ----------
    1.0.0 - Initial release
    1.1.0 - Improvements
            - Dot-source by numbered filename
            - Throw exceptions instead of swallowing
            - Use -ErrorAction Stop consistently
            - Ensure C:\Temp exists before downloads
            - Adjust registration logic (installer vs rdinfraagent)
            - Remove/clarify Force parameter
            - Return values for install functions
#>

. "$PSScriptRoot\03-AzureHelpers.ps1"

#---------------------------------------
# Session Host VM Helpers
#---------------------------------------

function Get-SessionHostVM {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$ResourceGroupName
    )

    try {
        $vm = Get-AzVM -Name $Name -ResourceGroupName $ResourceGroupName -Status -ErrorAction Stop
        Write-LabLog "VM '$Name' retrieved successfully." -Level SUCCESS
        return $vm
    }
    catch {
        Write-LabLog "Failed to retrieve VM '$Name': $_" -Level ERROR
        throw
    }
}

#---------------------------------------
# Registration Token Helpers
#---------------------------------------

function Get-AvdRegistrationToken {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$HostPoolName,
        [Parameter(Mandatory)][string]$ResourceGroupName
    )

    try {
        $token = Get-AzWvdRegistrationInfo -HostPoolName $HostPoolName -ResourceGroupName $ResourceGroupName -ErrorAction Stop
        Write-LabLog "Registration token retrieved for Host Pool '$HostPoolName'." -Level SUCCESS
        return $token
    }
    catch {
        Write-LabLog "Failed to retrieve registration token: $_" -Level ERROR
        throw
    }
}

function New-AvdRegistrationToken {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$HostPoolName,
        [Parameter(Mandatory)][string]$ResourceGroupName,
        [switch]$ForceNewToken
    )

    try {
        $token = New-AzWvdRegistrationInfo -HostPoolName $HostPoolName -ResourceGroupName $ResourceGroupName -ExpirationTime (Get-Date).AddHours(4) -ErrorAction Stop
        Write-LabLog "New registration token created for Host Pool '$HostPoolName'." -Level SUCCESS
        return $token
    }
    catch {
        Write-LabLog "Failed to create registration token: $_" -Level ERROR
        throw
    }
}

#---------------------------------------
# Agent & Boot Loader Installation
#---------------------------------------

function Install-AvdAgent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$VMName,
        [Parameter(Mandatory)][string]$ResourceGroupName
    )

    try {
        Write-LabLog "Installing AVD Agent on VM '$VMName'..." -Level INFO
        Invoke-AzVMRunCommand `
            -ResourceGroupName $ResourceGroupName `
            -Name $VMName `
            -CommandId 'RunPowerShellScript' `
            -ScriptString @'
                if (-not (Test-Path C:\Temp)) { New-Item C:\Temp -ItemType Directory | Out-Null }
                Invoke-WebRequest -Uri "https://aka.ms/avdagent" -OutFile "C:\Temp\AVDAgent.msi"
                Start-Process msiexec.exe -ArgumentList "/i C:\Temp\AVDAgent.msi /quiet /norestart" -Wait
'@ `
            -ErrorAction Stop
        Write-LabLog "AVD Agent installation initiated on VM '$VMName'." -Level SUCCESS
        return $true
    }
    catch {
        Write-LabLog "Failed to install AVD Agent: $_" -Level ERROR
        throw
    }
}

function Install-AvdBootLoader {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$VMName,
        [Parameter(Mandatory)][string]$ResourceGroupName
    )

    try {
        Write-LabLog "Installing AVD Boot Loader on VM '$VMName'..." -Level INFO
        Invoke-AzVMRunCommand `
            -ResourceGroupName $ResourceGroupName `
            -Name $VMName `
            -CommandId 'RunPowerShellScript' `
            -ScriptString @'
                if (-not (Test-Path C:\Temp)) { New-Item C:\Temp -ItemType Directory | Out-Null }
                Invoke-WebRequest -Uri "https://aka.ms/avdbootloader" -OutFile "C:\Temp\AVDBootLoader.msi"
                Start-Process msiexec.exe -ArgumentList "/i C:\Temp\AVDBootLoader.msi /quiet /norestart" -Wait
'@ `
            -ErrorAction Stop
        Write-LabLog "AVD Boot Loader installation initiated on VM '$VMName'." -Level SUCCESS
        return $true
    }
    catch {
        Write-LabLog "Failed to install AVD Boot Loader: $_" -Level ERROR
        throw
    }
}

#---------------------------------------
# Session Host Registration
#---------------------------------------

function Register-AvdSessionHost {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$VMName,
        [Parameter(Mandatory)][string]$HostPoolName,
        [Parameter(Mandatory)][string]$ResourceGroupName,
        [Parameter(Mandatory)][string]$Token
    )

    try {
        Write-LabLog "Registering VM '$VMName' as Session Host in Host Pool '$HostPoolName'..." -Level INFO

        # NOTE: Modern AVD agent registration typically uses the token during installation.
        # Verify in your lab whether rdinfraagent.exe /register works reliably.
        Invoke-AzVMRunCommand `
            -ResourceGroupName $ResourceGroupName `
            -Name $VMName `
            -CommandId 'RunPowerShellScript' `
            -ScriptString @"
                & "C:\Program Files\Microsoft RDInfra\RDInfraAgent\rdinfraagent.exe" /register $Token
"@ `
            -ErrorAction Stop

        Write-LabLog "Session Host registration initiated for VM '$VMName'." -Level SUCCESS
        return $true
    }
    catch {
        Write-LabLog "Failed to register Session Host: $_" -Level ERROR
        throw
    }
}

function Get-AvdSessionHost {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$HostPoolName,
        [Parameter(Mandatory)][string]$ResourceGroupName,
        [Parameter(Mandatory)][string]$Name
    )

    try {
        $sessionHost = Get-AzWvdSessionHost -HostPoolName $HostPoolName -ResourceGroupName $ResourceGroupName -Name $Name -ErrorAction Stop
        Write-LabLog "Session Host '$Name' retrieved successfully." -Level SUCCESS
        return $sessionHost
    }
    catch {
        Write-LabLog "Failed to retrieve Session Host '$Name': $_" -Level ERROR
        throw
    }
}

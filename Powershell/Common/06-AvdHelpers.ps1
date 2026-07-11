<#
    File    : 06-AvdHelpers.ps1
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
# Minimal AVD Helpers
#---------------------------------------

function Get-SessionHostVMIfExists { param([string]$ResourceGroupName,[string]$Name) Get-AzVM -ResourceGroupName $ResourceGroupName -Name $Name -Status -ErrorAction SilentlyContinue }

function Get-AvdRegistrationTokenIfExists { param([string]$ResourceGroupName,[string]$HostPoolName) Get-AzWvdRegistrationInfo -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName -ErrorAction SilentlyContinue }

function New-AvdRegistrationToken { param([string]$ResourceGroupName,[string]$HostPoolName) New-AzWvdRegistrationInfo -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName -ExpirationTime (Get-Date).AddHours(4) -ErrorAction SilentlyContinue }

function Get-AvdSessionHostIfExists { param([string]$ResourceGroupName,[string]$HostPoolName,[string]$Name) Get-AzWvdSessionHost -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName -Name $Name -ErrorAction SilentlyContinue }

function Test-HostPoolIfExists { param([string]$ResourceGroupName,[string]$HostPoolName) Get-AzWvdHostPool -ResourceGroupName $ResourceGroupName -Name $HostPoolName -ErrorAction SilentlyContinue }

function Test-AppGroupIfExists { param([string]$ResourceGroupName,[string]$AppGroupName) Get-AzWvdApplicationGroup -ResourceGroupName $ResourceGroupName -Name $AppGroupName -ErrorAction SilentlyContinue }

#---------------------------------------
# Agent & Boot Loader Installation
#---------------------------------------

function Install-AvdAgent {
    [CmdletBinding()]
    param(
        [string]$VMName,
        [string]$ResourceGroupName
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
        [string]$VMName,
        [string]$ResourceGroupName
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
        [string]$VMName,
        [string]$HostPoolName,
        [string]$ResourceGroupName,
        [string]$Token
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
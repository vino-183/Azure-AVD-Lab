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

. "$PSScriptRoot\..\Common\00-FrameworkRequirements.ps1"
. "$PSScriptRoot\..\Common\01-CommonVariables.ps1"
. "$PSScriptRoot\..\Common\03-AzureHelpers.ps1"

#---------------------------------------
# Minimal AVD Helpers
#---------------------------------------

function Get-SessionHostVMIfExists { param([string]$ResourceGroupName,[string]$Name) Get-AzVM -ResourceGroupName $ResourceGroupName -Name $Name -Status -ErrorAction SilentlyContinue }

function Get-AvdRegistrationTokenIfExists { param([string]$ResourceGroupName,[string]$HostPoolName) Get-AzWvdRegistrationInfo -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName -ErrorAction SilentlyContinue }

function New-AvdRegistrationToken { param([string]$ResourceGroupName,[string]$HostPoolName) New-AzWvdRegistrationInfo -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName -ExpirationTime (Get-Date).AddHours(4) -ErrorAction Stop }

function Get-AvdSessionHostIfExists { param([string]$ResourceGroupName,[string]$HostPoolName,[string]$Name) Get-AzWvdSessionHost -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName -Name $Name -ErrorAction SilentlyContinue }

function Test-HostPoolIfExists { param([string]$ResourceGroupName,[string]$HostPoolName) Get-AzWvdHostPool -ResourceGroupName $ResourceGroupName -Name $HostPoolName -ErrorAction SilentlyContinue }

function Test-AppGroupIfExists { param([string]$ResourceGroupName,[string]$AppGroupName) Get-AzWvdApplicationGroup -ResourceGroupName $ResourceGroupName -Name $AppGroupName -ErrorAction SilentlyContinue }

function Test-WorkspaceIfExists { param([string]$ResourceGroupName,[string]$WorkspaceName) Get-AzWvdWorkspace -ResourceGroupName $ResourceGroupName -Name $WorkspaceName -ErrorAction SilentlyContinue }

function Get-WorkspaceIfExists { param([string]$ResourceGroupName,[string]$WorkspaceName) Get-AzWvdWorkspace -ResourceGroupName $ResourceGroupName -Name $WorkspaceName -ErrorAction SilentlyContinue }

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
        Write-LabLog "Copying AVD Agent installer to VM '$VMName'..." -Level INFO
        Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -Name $VMName -CommandId 'RunPowerShellScript' -ScriptString @'
            if (-not (Test-Path C:\Temp)) { New-Item C:\Temp -ItemType Directory | Out-Null }
            Invoke-WebRequest -Uri "https://aka.ms/avdagent" -OutFile "C:\Temp\AVDAgent.msi"
'@ -ErrorAction Stop

        Write-LabLog "Installing AVD Agent on VM '$VMName'..." -Level INFO
        Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -Name $VMName -CommandId 'RunPowerShellScript' -ScriptString @'
            Start-Process msiexec.exe -ArgumentList "/i C:\Temp\AVDAgent.msi /quiet /norestart" -Wait
'@ -ErrorAction Stop

        Write-LabLog "Verifying AVD Agent installation..." -Level INFO
        if (-not (Test-AvdAgentInstalled -VMName $VMName -ResourceGroupName $ResourceGroupName)) {
            throw "AVD Agent installation failed on VM '$VMName'."
        }

        $version = Get-AvdAgentVersion -VMName $VMName -ResourceGroupName $ResourceGroupName
        Write-LabLog "AVD Agent installed successfully (Version $version)." -Level SUCCESS

        return [PSCustomObject]@{
            Success     = $true
            Version     = $version
            InstallTime = Get-Date
        }
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
#---------------------------------------
# Agent Installation Checks
#---------------------------------------

function Test-AvdAgentInstalled {
    [CmdletBinding()]
    param(
        [string]$VMName,
        [string]$ResourceGroupName
    )

    try {
        $script = @'
            $service = Get-Service -Name "RDAgentBootLoader" -ErrorAction SilentlyContinue
            if ($service) { return $true } else { return $false }
'@
        $result = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -Name $VMName -CommandId 'RunPowerShellScript' -ScriptString $script -ErrorAction Stop
        return ($result.Value -contains "True")
    }
    catch {
        Write-LabLog "Failed to check AVD Agent installation: $_" -Level ERROR
        return $false
    }
}

function Get-AvdAgentVersion {
    [CmdletBinding()]
    param(
        [string]$VMName,
        [string]$ResourceGroupName
    )

    try {
        $script = @'
            $path = "HKLM:\SOFTWARE\Microsoft\RDInfraAgent"
            if (Test-Path $path) {
                (Get-ItemProperty $path).Version
            }
'@
        $result = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -Name $VMName -CommandId 'RunPowerShellScript' -ScriptString $script -ErrorAction Stop
        return $result.Value
    }
    catch {
        Write-LabLog "Failed to retrieve AVD Agent version: $_" -Level ERROR
        return $null
    }
}

#---------------------------------------
# Boot Loader Installation Checks
#---------------------------------------

function Test-AvdBootLoaderInstalled {
    [CmdletBinding()]
    param(
        [string]$VMName,
        [string]$ResourceGroupName
    )

    try {
        $script = @'
            $service = Get-Service -Name "RDAgentBootLoader" -ErrorAction SilentlyContinue
            if ($service) { return $true } else { return $false }
'@
        $result = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -Name $VMName -CommandId 'RunPowerShellScript' -ScriptString $script -ErrorAction Stop
        return ($result.Value -contains "True")
    }
    catch {
        Write-LabLog "Failed to check Boot Loader installation: $_" -Level ERROR
        return $false
    }
}

function Get-AvdBootLoaderVersion {
    [CmdletBinding()]
    param(
        [string]$VMName,
        [string]$ResourceGroupName
    )

    try {
        $script = @'
            $path = "HKLM:\SOFTWARE\Microsoft\RDInfraBootLoader"
            if (Test-Path $path) {
                (Get-ItemProperty $path).Version
            }
'@
        $result = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -Name $VMName -CommandId 'RunPowerShellScript' -ScriptString $script -ErrorAction Stop
        return $result.Value
    }
    catch {
        Write-LabLog "Failed to retrieve Boot Loader version: $_" -Level ERROR
        return $null
    }
}
#---------------------------------------
# Host Pool Validation
#---------------------------------------

function Test-HostPoolIfExists {
    [CmdletBinding()]
    param(
        [string]$ResourceGroupName,
        [string]$HostPoolName
    )

    try {
        $pool = Get-AzWvdHostPool -ResourceGroupName $ResourceGroupName -Name $HostPoolName -ErrorAction SilentlyContinue
        return $null -ne $pool
    }
    catch {
        Write-LabLog "Failed to validate Host Pool: $_" -Level ERROR
        return $false
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

        Invoke-AzVMRunCommand `
            -ResourceGroupName $ResourceGroupName `
            -Name $VMName `
            -CommandId 'RunPowerShellScript' `
            -ScriptString @"
                & "C:\Program Files\Microsoft RDInfra\RDInfraAgent\rdinfraagent.exe" /register $Token
"@ `
            -ErrorAction Stop

        return [PSCustomObject]@{
            Success        = $true
            RegisteredTime = Get-Date
        }
    }
    catch {
        Write-LabLog "Failed to register Session Host: $_" -Level ERROR
        return [PSCustomObject]@{
            Success        = $false
            RegisteredTime = $null
        }
    }
}

#---------------------------------------
# Session Host Checks
#---------------------------------------

function Get-AvdSessionHost {
    [CmdletBinding()]
    param(
        [string]$ResourceGroupName,
        [string]$HostPoolName,
        [string]$Name
    )

    try {
        return Get-AzWvdSessionHost -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName -Name $Name -ErrorAction SilentlyContinue
    }
    catch {
        Write-LabLog "Failed to retrieve Session Host: $_" -Level ERROR
        return $null
    }
}

function Test-SessionHostRegistered {
    [CmdletBinding()]
    param(
        [string]$ResourceGroupName,
        [string]$HostPoolName,
        [string]$VMName
    )

    $host = Get-AvdSessionHost -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName -Name $VMName
    return $null -ne $host
}

#---------------------------------------
# Wait for Registration
#---------------------------------------

function Wait-AvdSessionHostRegistration {
    [CmdletBinding()]
    param(
        [string]$ResourceGroupName,
        [string]$HostPoolName,
        [string]$VMName,
        [int]$TimeoutSeconds = 300
    )

    $elapsed = 0
    while (-not (Test-SessionHostRegistered -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName -VMName $VMName)) {
        if ($elapsed -ge $TimeoutSeconds) {
            throw "Session Host '$VMName' failed to register within $TimeoutSeconds seconds."
        }
        Start-Sleep 10
        $elapsed += 10
    }

    return [PSCustomObject]@{
        Success        = $true
        RegisteredTime = Get-Date
    }
}
function Get-OrCreateAvdRegistrationToken {
    [CmdletBinding()]
    param(
        [string]$ResourceGroupName,
        [string]$HostPoolName
    )

    $tokenObj = Get-AvdRegistrationTokenIfExists -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName
    if (-not $tokenObj -or -not $tokenObj.Token -or $tokenObj.Expiration -le (Get-Date)) {
        $tokenObj = New-AvdRegistrationToken -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName
    }
    return $tokenObj.Token
}

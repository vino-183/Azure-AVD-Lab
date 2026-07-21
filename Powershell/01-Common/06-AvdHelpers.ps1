#---------------------------------------
# HostPool
#---------------------------------------
function Test-HostPoolIfExists {
    param([string]$ResourceGroupName,[string]$HostPoolName)
    Get-AzWvdHostPool -ResourceGroupName $ResourceGroupName -Name $HostPoolName -ErrorAction SilentlyContinue
}

#---------------------------------------
# AppGroup
#---------------------------------------
function Test-AppGroupIfExists {
    param([string]$ResourceGroupName,[string]$AppGroupName)
    Get-AzWvdApplicationGroup -ResourceGroupName $ResourceGroupName -Name $AppGroupName -ErrorAction SilentlyContinue
}

#---------------------------------------
# Workspace
#---------------------------------------
function Test-WorkspaceIfExists {
    param([string]$ResourceGroupName,[string]$WorkspaceName)
    Get-AzWvdWorkspace -ResourceGroupName $ResourceGroupName -Name $WorkspaceName -ErrorAction SilentlyContinue
}

function Get-WorkspaceIfExists {
    param([string]$ResourceGroupName,[string]$WorkspaceName)
    Get-AzWvdWorkspace -ResourceGroupName $ResourceGroupName -Name $WorkspaceName -ErrorAction SilentlyContinue
}

#---------------------------------------
# Registration Token
#---------------------------------------
function Get-OrCreateAvdRegistrationToken {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ResourceGroupName,
        [Parameter(Mandatory)][string]$HostPoolName,
        [switch]$Force,
        [int]$TokenValidityHours = 4
    )

    $tokenObj = Get-AvdRegistrationInfo -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName

    if (-not $tokenObj -or [string]::IsNullOrWhiteSpace($tokenObj.Token) -or -not $tokenObj.ExpirationTime -or $tokenObj.ExpirationTime -le (Get-Date)) {
        Write-LabLog "Creating new AVD registration token for Host Pool '$HostPoolName'."
        $tokenObj = New-AvdRegistrationToken -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName
    }
    else {
        Write-LabLog "Using existing AVD registration token for Host Pool '$HostPoolName'."
    }

    return $tokenObj.Token
}

function New-AvdRegistrationToken {
    param([string]$ResourceGroupName,[string]$HostPoolName)
    New-AzWvdRegistrationInfo -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName -ExpirationTime (Get-Date).AddHours(4) -ErrorAction Stop
}

function Get-AvdRegistrationInfo {
    param([string]$ResourceGroupName,[string]$HostPoolName)
    Get-AzWvdRegistrationInfo -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName -ErrorAction SilentlyContinue
}

#---------------------------------------
# Session Host
#---------------------------------------
function Get-SessionHostVMIfExists {
    param([string]$ResourceGroupName,[string]$Name)
    Get-AzVM -ResourceGroupName $ResourceGroupName -Name $Name -Status -ErrorAction SilentlyContinue
}

function Get-AvdSessionHostIfExists {
    param([string]$ResourceGroupName,[string]$HostPoolName,[string]$Name)
    Get-AzWvdSessionHost -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName -Name $Name -ErrorAction SilentlyContinue
}

function Get-AvdSessionHost {
    [CmdletBinding()]
    param([string]$ResourceGroupName,$HostPoolName,[string]$Name)
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
    param([string]$ResourceGroupName,$HostPoolName,[string]$VMName)
    $host = Get-AvdSessionHost -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName -Name $VMName
    return $null -ne $host
}

function Register-AvdSessionHost { ... }   # (kept as-is, registration logic)

function Wait-AvdSessionHostRegistration { ... }   # (kept as-is)

function Test-AvdSessionHostRegistration { ... }   # (kept as-is)

#---------------------------------------
# Agent / Boot Loader Checks
#---------------------------------------
function Get-AvdAgentVersion {
    [CmdletBinding()]
    param([string]$VMName,[string]$ResourceGroupName)
    try {
        $script = @'
            $path = "HKLM:\SOFTWARE\Microsoft\RDInfraAgent"
            if (Test-Path $path) { (Get-ItemProperty $path).Version }
'@
        $result = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -Name $VMName -CommandId 'RunPowerShellScript' -ScriptString $script -ErrorAction Stop
        return $result.Value
    }
    catch {
        Write-LabLog "Failed to retrieve AVD Agent version: $_" -Level ERROR
        return $null
    }
}

function Get-AvdBootLoaderVersion {
    [CmdletBinding()]
    param([string]$VMName,[string]$ResourceGroupName)
    try {
        $script = @'
            $path = "HKLM:\SOFTWARE\Microsoft\RDInfraBootLoader"
            if (Test-Path $path) { (Get-ItemProperty $path).Version }
'@
        $result = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -Name $VMName -CommandId 'RunPowerShellScript' -ScriptString $script -ErrorAction Stop
        return $result.Value
    }
    catch {
        Write-LabLog "Failed to retrieve Boot Loader version: $_" -Level ERROR
        return $null
    }
}

<#
    File    : AzureHelpers.ps1
    Version : 1.1.0
    Purpose : Shared helper functions for the Azure Migration Framework

    Change Log
    ----------
    1.0.0 - Initial release
            - Write-LabLog, Write-Step, Test-AzLogin, Test-Subscription,
              Test-ResourceIfExists, Test-VNetIfExists, Test-SubnetIfExists,
              Test-PublicIpIfExists, Invoke-WithRetry
    1.1.0 - Cleanup & consolidation
            - Consistent logging
            - Removed duplicate code blocks
            - Grouped helpers by category
#>

#---------------------------------------
# Logging Helpers
#---------------------------------------

function Write-LabLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet("INFO","WARNING","ERROR","SUCCESS")]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    switch ($Level) {
        "INFO"    { $color = "Cyan" }
        "WARNING" { $color = "Yellow" }
        "ERROR"   { $color = "Red" }
        "SUCCESS" { $color = "Green" }
    }

    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Write-Step {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Step)

    Write-Host ""
    Write-Host "====================================================" -ForegroundColor Cyan
    Write-Host " $Step" -ForegroundColor Cyan
    Write-Host "====================================================" -ForegroundColor Cyan
}

#---------------------------------------
# Azure Context & Subscription
#---------------------------------------

function Test-Subscription {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$SubscriptionId)

    Set-AzContext -SubscriptionId $SubscriptionId -ErrorAction Stop
    Write-LabLog "Subscription selected successfully." -Level SUCCESS
}

function Validate-AzContext {
    [CmdletBinding()]
    param()

    $context = Get-AzContext
    if (-not $context) { throw "No active Azure context found. Please run Connect-AzAccount." }

    Write-LabLog "Azure context validated: $($context.Account.Id)" -Level INFO
    return $context
}

function Test-LabPrerequisites {
    [CmdletBinding()]
    param()

    # PowerShell version
    if ($PSVersionTable.PSVersion -lt $FrameworkRequirements.PowerShell) {
        Write-LabLog "PowerShell $($PSVersionTable.PSVersion) detected. Minimum required version is $($FrameworkRequirements.PowerShell)." -Level ERROR
        return $false
    }
    Write-LabLog "PowerShell $($PSVersionTable.PSVersion) verified." -Level SUCCESS

    # Az module versions
    foreach ($module in $FrameworkRequirements.Modules.GetEnumerator()) {
        if (-not (Test-ModuleVersion -ModuleName $module.Key -MinimumVersion $module.Value)) { return $false }
    }

    # Import Az
    try {
        Import-Module Az -ErrorAction Stop
        Write-LabLog "Az PowerShell module loaded successfully." -Level SUCCESS
    } catch {
        Write-LabLog "Unable to load the Az PowerShell module." -Level ERROR
        return $false
    }

    # Authentication
    try {
        Get-AzContext -ErrorAction Stop | Out-Null
        Write-LabLog "Azure authentication verified." -Level SUCCESS
    } catch {
        Write-LabLog "You are not connected to Azure." -Level ERROR
        return $false
    }

    return $true
}

#---------------------------------------
# Generic Helpers
#---------------------------------------

function Invoke-WithRetry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][scriptblock]$Script,
        [int]$RetryCount = 3,
        [int]$DelaySeconds = 5
    )

    for ($i = 1; $i -le $RetryCount; $i++) {
        try { return & $Script }
        catch {
            if ($i -eq $RetryCount) { throw }
            Write-LabLog "Retry $i failed. Waiting $DelaySeconds seconds..." -Level WARNING
            Start-Sleep -Seconds $DelaySeconds
        }
    }
}

function Write-DeploymentSummary {
    param([Parameter(Mandatory)][hashtable]$Properties)

    Write-Host ""
    Write-Host "Deployment Summary"
    Write-Host "------------------"
    foreach ($item in $Properties.GetEnumerator()) {
        Write-Host ("{0,-20}: {1}" -f $item.Key, $item.Value)
    }
    Write-Host ""
}

function Get-LabCredential {
    [CmdletBinding()]
    param([string]$Message = "Enter local administrator credentials")
    return Get-Credential -Message $Message
}

function Test-ModuleVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ModuleName,
        [Parameter(Mandatory)][version]$MinimumVersion
    )

    $module = Get-Module -ListAvailable -Name $ModuleName | Sort-Object Version -Descending | Select-Object -First 1
    if (-not $module) {
        Write-LabLog "$ModuleName is not installed." -Level ERROR
        return $false
    }
    if ($module.Version -lt $MinimumVersion) {
        Write-LabLog "$ModuleName version $($module.Version) detected. Minimum required version is $MinimumVersion." -Level ERROR
        return $false
    }
    Write-LabLog "$ModuleName version $($module.Version) verified." -Level SUCCESS
    return $true
}

#---------------------------------------
# Resource Existence Helpers
#---------------------------------------

function Test-ResourceGroupIfExists { param([string]$ResourceGroupName) Get-AzResourceGroup -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue }
function Test-VNetIfExists          { param([string]$ResourceGroupName,[string]$VNetName) Get-AzVirtualNetwork -Name $VNetName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue }
function Test-SubnetIfExists        { param($VirtualNetwork,[string]$SubnetName) return ($VirtualNetwork.Subnets.Name -contains $SubnetName) }
function Test-PublicIpIfExists      { param([string]$ResourceGroupName,[string]$PublicIpName) Get-AzPublicIpAddress -Name $PublicIpName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue }
function Test-NSGIfExists           { param([string]$ResourceGroupName,[string]$NSGName) Get-AzNetworkSecurityGroup -Name $NSGName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue }
function Test-NicIfExists           { param([string]$ResourceGroupName,[string]$NicName) Get-AzNetworkInterface -Name $NicName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue }
function Test-VMIfExists {

    param(
        [Parameter(Mandatory)]
        [string]$ResourceGroupName,

        [Parameter(Mandatory)]
        [string]$VMName
    )

    if ([string]::IsNullOrWhiteSpace($VMName)) {
        throw "Test-VMIfExists: VMName cannot be null or empty."
    }

    Get-AzVM `
        -Name $VMName `
        -ResourceGroupName $ResourceGroupName `
        -ErrorAction SilentlyContinue
}
function Test-DiskIfExists          { param([string]$ResourceGroupName,[string]$DiskName) Get-AzDisk -Name $DiskName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue }
function Test-StorageAccountIfExists{ param([string]$StorageAccountName,[string]$ResourceGroupName) try { Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction Stop; return $true } catch { return $false } }
function Test-NetworkInterfaceIfExists { param([string]$NetworkInterfaceName,[string]$ResourceGroupName) try { Get-AzNetworkInterface -Name $NetworkInterfaceName -ResourceGroupName $ResourceGroupName -ErrorAction Stop; return $true } catch { return $false } }

#---------------------------------------
# VM SKU Selection
#---------------------------------------

function Get-LabVmSku {
    <#
    .SYNOPSIS
        Returns the best matching VM SKU for the specified Azure region.

    .DESCRIPTION
        Filters Azure VM SKUs by location, CPU, memory and Premium SSD
        capability, then returns the preferred SKU based on family order.

    .PARAMETER Location
        Azure region display name (Example: East US)

    .PARAMETER vCPU
        Minimum required vCPUs.

    .PARAMETER MemoryGB
        Minimum required memory in GB.

    .PARAMETER RequirePremiumStorage
        Return only Premium SSD capable SKUs.

    .OUTPUTS
        String
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Location,

        [ValidateRange(1,128)]
        [int]$vCPU = 2,

        [ValidateRange(1,2048)]
        [int]$MemoryGB = 4,

        [switch]$RequirePremiumStorage
    )

    $NormalizedLocation = ($Location -replace '\s','').ToLower()

    $Candidates = foreach ($Sku in Get-AzComputeResourceSku) {
        if ($Sku.ResourceType -ne "virtualMachines") { continue }

        $Locations = $Sku.Locations | ForEach-Object {
            ($_ -replace '\s','').ToLower()
        }
        if ($Locations -notcontains $NormalizedLocation) { continue }

        $Caps = @{}
        foreach ($Cap in $Sku.Capabilities) { $Caps[$Cap.Name] = $Cap.Value }

        if (-not $Caps.ContainsKey("vCPUs")) { continue }
        if (-not $Caps.ContainsKey("MemoryGB")) { continue }

        $Cpu = [int]$Caps["vCPUs"]
        $Mem = [double]$Caps["MemoryGB"]

        if ($Cpu -lt $vCPU) { continue }
        if ($Mem -lt $MemoryGB) { continue }

        $Premium = $false
        if ($Caps.ContainsKey("PremiumIO")) {
            $Premium = ($Caps["PremiumIO"] -eq "True")
        }
        if ($RequirePremiumStorage -and -not $Premium) { continue }

        [PSCustomObject]@{
            Name      = $Sku.Name
            CPU       = $Cpu
            MemoryGB  = $Mem
            PremiumIO = $Premium
        }
    }

    if (-not $Candidates) {
        throw "No VM SKU found in '$Location' matching CPU >= $vCPU and Memory >= $MemoryGB GB."
    }

    $PreferredFamilies = @("Standard_D","Standard_B","Standard_E","Standard_F","Standard_A")

    foreach ($Family in $PreferredFamilies) {
        $Match = $Candidates |
            Where-Object Name -like "$Family*" |
            Sort-Object CPU, MemoryGB |
            Select-Object -First 1
        if ($Match) { return $Match.Name }
    }

    $Fallback = $Candidates | Sort-Object CPU, MemoryGB | Select-Object -First 1
    return $Fallback.Name
}


function New-LabNetworkInterface {
    [CmdletBinding()]
    param(
        [string]$Role,
        [string]$ResourceGroupName,
        [string]$Location,
        [string]$SubnetId,
        [string]$NicName = $null
    )

    if (-not $NicName) {
        $NicName = "nic-$Role-$(Get-Random)"
    }

    Write-LabLog "Creating NIC '$NicName' for role '$Role'..." -Level INFO

    Write-Host "----- New-LabNetworkInterface -----"
Write-Host "Role              : '$Role'"
Write-Host "ResourceGroupName : '$ResourceGroupName'"
Write-Host "Location          : '$Location'"
Write-Host "SubnetId          : '$SubnetId'"
Write-Host "-----------------------------------"

    $nic = New-AzNetworkInterface `
        -Name $NicName `
        -ResourceGroupName $ResourceGroupName `
        -Location $Location `
        -SubnetId $SubnetId `
        -ErrorAction Stop

    return $nic
}

function New-LabVirtualMachine {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$VMName,

        [Parameter(Mandatory)]
        [string]$VMSize,

        [Parameter(Mandatory)]
        [pscredential]$Credential,

        [Parameter(Mandatory)]
        [string]$ResourceGroupName,

        [Parameter(Mandatory)]
        [string]$Location,

        [Parameter(Mandatory)]
        [string]$VNetName,

        [Parameter(Mandatory)]
        [string]$SubnetName,

        [Parameter(Mandatory)]
        [string]$ImagePublisher,

        [Parameter(Mandatory)]
        [string]$ImageOffer,

        [Parameter(Mandatory)]
        [string]$ImageSku,

        [string]$ImageVersion = "latest",

        [string]$OSDiskSku = "Premium_LRS"
    )

    try {

        Write-LabLog "Resolving subnet..." -Level INFO

        $vnet = Get-AzVirtualNetwork `
            -ResourceGroupName $ResourceGroupName `
            -Name $VNetName `
            -ErrorAction Stop

        $subnet = $vnet.Subnets |
            Where-Object Name -eq $SubnetName

        if (-not $subnet) {
            throw "Subnet '$SubnetName' not found."
        }

        Write-LabLog "Creating NIC..." -Level INFO

        $nic = New-LabNetworkInterface `
            -ResourceGroupName $ResourceGroupName `
            -Location $Location `
            -SubnetId $subnet.Id `
            -NicName "nic-$VMName"

        Write-LabLog "Building VM configuration..." -Level INFO

        $vmConfig = New-AzVMConfig `
            -VMName $VMName `
            -VMSize $VMSize

        $vmConfig = Set-AzVMOperatingSystem `
            -VM $vmConfig `
            -Windows `
            -ComputerName $VMName `
            -Credential $Credential `
            -ProvisionVMAgent `
            -EnableAutoUpdate

        $vmConfig = Set-AzVMSourceImage `
            -VM $vmConfig `
            -PublisherName $ImagePublisher `
            -Offer $ImageOffer `
            -Skus $ImageSku `
            -Version $ImageVersion

        $vmConfig = Add-AzVMNetworkInterface `
            -VM $vmConfig `
            -Id $nic.Id

        $vmConfig = Set-AzVMOSDisk `
            -VM $vmConfig `
            -CreateOption FromImage `
            -StorageAccountType $OSDiskSku

        if ($PSCmdlet.ShouldProcess($VMName, "Create Virtual Machine")) {

          Write-LabLog "Azure Context:" -Level INFO

$ctx = Get-AzContext

Write-LabLog "Subscription : $($ctx.Subscription.Name)" -Level INFO
Write-LabLog "SubscriptionId : $($ctx.Subscription.Id)" -Level INFO
Write-LabLog "Tenant : $($ctx.Tenant.Id)" -Level INFO
Write-LabLog "Account : $($ctx.Account.Id)" -Level INFO
  
            New-AzVM `
                -ResourceGroupName $ResourceGroupName `
                -Location $Location `
                -VM $vmConfig `
                -ErrorAction Stop
        }

        Write-LabLog "VM '$VMName' created successfully." -Level SUCCESS

        return Get-AzVM `
            -ResourceGroupName $ResourceGroupName `
            -Name $VMName

    }
    catch {

        Write-LabLog $_.Exception.Message -Level ERROR
        throw
    }
}
#---------------------------------------
# End of AzureHelpers.ps1
#---------------------------------------

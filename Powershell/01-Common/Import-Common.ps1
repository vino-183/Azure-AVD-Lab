if (-not $script:CommonLoaded)
{
    $CommonFiles = @(
        "00-FrameworkRequirements.ps1",
        #"00-VMCatalog.ps1",
        "01-CommonVariables.ps1",
        "02-NetworkVariables.ps1",
        "03-AzureHelpers.ps1",
        "04-VM-Variables.ps1",
        "05-StorageVariables.ps1",
        "06-AvdHelpers.ps1"
    )

foreach ($File in $CommonFiles)
{
    Write-Host "Loading $File"
    . (Join-Path $PSScriptRoot $File)
}

    $script:CommonLoaded = $true
}
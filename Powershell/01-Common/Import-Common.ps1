if (-not $script:CommonLoaded)
{
    $CommonFolder = Split-Path $MyInvocation.MyCommand.Path

    Get-ChildItem $CommonFolder -Filter "*.ps1" |
        Where-Object Name -ne "Import-Common.ps1" |
        Sort-Object Name |
        ForEach-Object {
            . $_.FullName
        }

    $script:CommonLoaded = $true
}
[CmdletBinding(SupportsShouldProcess = $true)]
param()

$TimeoutSeconds = 600

# Import common helpers
. "D:\Cloud-Labs\Azure-AVD-Lab\Powershell\01-Common\Import-Common.ps1"

try {
    Write-LabLog "Starting AVD Session Host deployment." -Level INFO

    # 1. Test Azure connection
    Test-AzureConnection

    # 2. Verify Host Pool
    $HostPool = Test-HostPoolIfExists `
        -ResourceGroupName $ResourceGroupName `
        -HostPoolName $HostPoolName

    if (-not $HostPool) {
        throw "Host Pool '$HostPoolName' was not found."
    }

    if ($PSCmdlet.ShouldProcess($HostPoolName, "Deploy new AVD Session Host")) {

        # 3. Get registration token
        $RegistrationToken = Get-OrCreateAvdRegistrationToken `
            -ResourceGroupName $ResourceGroupName `
            -HostPoolName $HostPoolName

        # 4. Deploy VM
        $VmDeployment = New-LabVirtualMachine `
            -VMName $VMName `
            -VMSize $VMSize `
            -Credential $LocalAdminCredential `
            -ResourceGroupName $ResourceGroupName `
            -Location $Location `
            -VNetName $VNetName `
            -SubnetName $SubnetName `
            -ImagePublisher $ImagePublisher `
            -ImageOffer $ImageOffer `
            -ImageSku $ImageSku `
            -ImageVersion $ImageVersion `
            -OSDiskSku $OSDiskSku

        if (-not $VmDeployment) {
            throw "VM deployment failed."
        }

        # 5. Install AVD extensions
        $BootLoaderExtensionResult = Install-AvdExtension `
            -ResourceGroupName $ResourceGroupName `
            -VMName $VMName `
            -RegistrationToken $RegistrationToken `
            -ExtensionName $BootLoaderExtension.Name `
            -Publisher $BootLoaderExtension.Publisher `
            -ExtensionType $BootLoaderExtension.Type `
            -TypeHandlerVersion $BootLoaderExtension.TypeHandlerVersion `
            -EnableAutomaticUpgrade

        $AgentExtensionResult = Install-AvdExtension `
            -ResourceGroupName $ResourceGroupName `
            -VMName $VMName `
            -RegistrationToken $RegistrationToken `
            -ExtensionName $AgentExtension.Name `
            -Publisher $AgentExtension.Publisher `
            -ExtensionType $AgentExtension.Type `
            -TypeHandlerVersion $AgentExtension.TypeHandlerVersion `
            -EnableAutomaticUpgrade

        if (-not $BootLoaderExtensionResult -or -not $AgentExtensionResult) {
            throw "AVD extension installation failed."
        }

        # 6. Register Session Host
        $RegistrationResult = Register-AvdSessionHost `
            -VMName $VMName `
            -HostPoolName $HostPoolName `
            -ResourceGroupName $ResourceGroupName `
            -Token $RegistrationToken

        if (-not $RegistrationResult.Success) {
            throw "Session Host registration failed."
        }

        $WaitResult = Wait-AvdSessionHostRegistration `
            -ResourceGroupName $ResourceGroupName `
            -HostPoolName $HostPoolName `
            -VMName $VMName

        if (-not $WaitResult.Success) {
            throw "Session Host failed to appear in Host Pool."
        }

        # 7. Validate registration
        $RegistrationValidation = Test-AvdSessionHostRegistration `
            -VMName $VmDeployment.VMName `
            -ResourceGroupName $VmDeployment.ResourceGroup `
            -HostPoolName $HostPoolName `
            -TimeoutSeconds $TimeoutSeconds

        Write-LabLog "Session Host '$($VmDeployment.VMName)' successfully registered with Host Pool '$HostPoolName'." -Level INFO

        return [PSCustomObject]@{
            VMName          = $VmDeployment.VMName
            ResourceGroup   = $ResourceGroupName
            HostPoolName    = $HostPoolName
            DeploymentState = "Succeeded"
            Timestamp       = Get-Date
        }
    } # closes ShouldProcess block
}
catch {
    Write-LabLog "Session Host deployment failed." -Level ERROR
    Write-LabLog $_.Exception.Message -Level ERROR
    throw
} # closes try/catch

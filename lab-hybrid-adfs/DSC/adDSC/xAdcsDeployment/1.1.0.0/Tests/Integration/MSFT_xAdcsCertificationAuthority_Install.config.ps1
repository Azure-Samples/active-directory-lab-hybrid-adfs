configuration MSFT_xADCSCertificationAuthority_Install_Config {
    Import-DscResource -ModuleName xAdcsDeployment

    node localhost {
        xADCSCertificationAuthority Integration_Test {
            CAType     = 'StandaloneRootCA'
            Credential = $Node.AdminCred
            Ensure     = 'Present'
        }
    }
}

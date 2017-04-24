configuration MSFT_xADCSCertificationAuthority_Uninstall_Config {
    Import-DscResource -ModuleName xAdcsDeployment

    node localhost {
        xADCSCertificationAuthority Integration_Test {
            CAType     = 'StandaloneRootCA'
            Credential = $Node.AdminCred
            Ensure     = 'Absent'
        }
    }
}

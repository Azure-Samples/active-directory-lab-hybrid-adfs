Configuration MSFT_xPfxImport_Add_Config {
    param
    (
        $Thumbprint,
        $Path,
        $Credential
    )
    Import-DscResource -ModuleName xCertificate
    node localhost {
        xPfxImport Integration_Test {
            Thumbprint   = $Thumbprint
            Path         = $Path
            Location     = 'LocalMachine'
            Store        = 'My'
            Ensure       = 'Present'
            Credential   = $Credential
        }
    }
}

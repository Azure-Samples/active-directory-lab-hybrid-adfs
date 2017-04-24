Configuration MSFT_xPfxImport_Remove_Config {
    param
    (
        $Thumbprint,
        $Path
    )
    Import-DscResource -ModuleName xCertificate
    node localhost {
        xPfxImport Integration_Test {
            Thumbprint = $Thumbprint
            Path       = $Path
            Location   = 'LocalMachine'
            Store      = 'My'
            Ensure     = 'Absent'
        }
    }
}

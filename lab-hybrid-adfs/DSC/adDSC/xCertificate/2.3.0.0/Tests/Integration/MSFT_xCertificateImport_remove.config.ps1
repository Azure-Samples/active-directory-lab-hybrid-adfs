Configuration MSFT_xCertificateImport_Remove_Config {
    param
    (
        $Thumbprint,
        $Path
    )
    Import-DscResource -ModuleName xCertificate
    node localhost {
        xCertificateImport Integration_Test {
            Thumbprint = $Thumbprint
            Path       = $Path
            Location   = 'LocalMachine'
            Store      = 'My'
            Ensure     = 'Absent'
        }
    }
}

# Import public key certificate into Trusted Root store.
Configuration Sample_xCertificateImport_MinimalUsage
{
    Import-DscResource -ModuleName xCertificate

    Node $AllNodes.NodeName
    {
        xCertificateImport MyTrustedRoot
        {
            Thumbprint = 'c81b94933420221a7ac004a90242d8b1d3e5070d'
            Location   = 'LocalMachine'
            Store      = 'Root'
            Path       = '\\Server\Share\Certificates\MyTrustedRoot.cer'
        }
    }
}
Sample_xCertificateImport_MinimalUsage `
    -OutputPath 'c:\Sample_xCertificateImport_MinimalUsage'
Start-DscConfiguration -Wait -Force -Verbose -Path 'c:\Sample_xCertificateImport_MinimalUsage'

# Validate results
Get-ChildItem Cert:\LocalMachine\My

# Import a PFX into the WebHosting store and bind it to an IIS Web Site.
Configuration Sample_xPfxImport_IIS_WebSite
{
    param
    (
        [PSCredential]
        $PfxPassword = (Get-Credential -Message 'Enter PFX extraction password.' -UserName 'Ignore')
    )

    Import-DscResource -ModuleName xCertificate
    Import-DscResource -ModuleName xWebAdministration

    Node $AllNodes.NodeName
    {
        WindowsFeature IIS
        {
            Ensure = 'Present'
            Name   = 'Web-Server'
        }

        xPfxImport CompanyCert
        {
            Thumbprint = 'c81b94933420221a7ac004a90242d8b1d3e5070d'
            Path       = '\\Server\Share\Certificates\CompanyCert.pfx'
            Store      = 'WebHosting'
            Credential = $PfxPassword
            DependsOn  = '[WindowsFeature]IIS'
        }

        xWebsite CompanySite
        {
            Ensure          = 'Present'
            Name            = 'CompanySite'
            State           = 'Started'
            PhysicalPath    = "B:\Web\CompanySite"
            ApplicationPool = "CompanyPool"
            BindingInfo     =
                    MSFT_xWebBindingInformation {
                        Protocol = 'HTTPS'
                        Port = 443
                        CertificateThumbprint = 'c81b94933420221a7ac004a90242d8b1d3e5070d'
                        CertificateStoreName = 'WebHosting'
                        HostName = "www.example.com"
                    }
            DependsOn       = '[WindowsFeature]Web-Server','[xPfxImport]CompanyCert'
        }
    }
}
Sample_xPfxImport_IIS_WebSite `
    -OutputPath 'c:\Sample_xPfxImport_IIS_WebSite'
Start-DscConfiguration -Wait -Force -Verbose -Path 'c:\Sample_xPfxImport_IIS_WebSite'

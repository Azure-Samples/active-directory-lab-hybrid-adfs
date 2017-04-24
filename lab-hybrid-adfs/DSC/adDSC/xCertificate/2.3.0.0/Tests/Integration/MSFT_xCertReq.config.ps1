# This will fail if the machine does not have a CA Configured.
$CertUtilResult       = & "$ENV:SystemRoot\system32\certutil.exe" @('-dump')
$CAServerFQDN         = ([regex]::matches($CertUtilResult,'Server:[ \t]+`([A-Za-z0-9._-]+)''','IgnoreCase')).Groups[1].Value
$CARootName           = ([regex]::matches($CertUtilResult,'Name:[ \t]+`([\sA-Za-z0-9._-]+)''','IgnoreCase')).Groups[1].Value
$KeyLength            = '1024'
$Exportable           = $true
$ProviderName         = '"Microsoft RSA SChannel Cryptographic Provider"'
$OID                  = '1.3.6.1.5.5.7.3.1'
$KeyUsage             = '0xa0'
$CertificateTemplate  = 'WebServer'
$SubjectAltName       = 'dns=contoso.com&dns=fabrikam.com'

# If automated testing with a real CA can be performed then the credentials should be
# obtained non-interactively way - do not do this in a production environment.
$Credential = Get-Credential
$TestCertReq = [PSObject]@{
    Subject             = 'CertReq Test'
    CAServerFQDN        = $CAServerFQDN
    CARootName          = $CARootName
    Credential          = $Credential
    KeyLength           = $KeyLength
    Exportable          = $($Exportable.ToString().ToUpper())
    ProviderName        = $ProviderName
    OID                 = $OID
    KeyUsage            = $KeyUsage
    CertificateTemplate = $CertificateTemplate
    SubjectAltName      = $SubjectAltName
}

Configuration MSFT_xCertReq_Config {
    Import-DscResource -ModuleName xCertificate
    node localhost {
        xCertReq Integration_Test {
            Subject             = $TestCertReq.Subject
            CAServerFQDN        = $TestCertReq.CAServerFQDN
            CARootName          = $TestCertReq.CARootName
            Credential          = $TestCertReq.Credential
            KeyLength           = $TestCertReq.KeyLength
            Exportable          = $TestCertReq.Exportable
            ProviderName        = $TestCertReq.ProviderName
            OID                 = $TestCertReq.OID
            KeyUsage            = $TestCertReq.KeyUsage
            CertificateTemplate = $TestCertReq.CertificateTemplate
            SubjectAltName      = $TestCertReq.SubjectAltName
        }
    }
}

# Import a PFX into the My store.
Configuration Sample_xPfxImport_MinimalUsage
{
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String] $PfxThumbprint,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String] $PfxPath,

        [PSCredential]
        $PfxPassword = (Get-Credential -Message 'Enter PFX extraction password.' -UserName 'Ignore')
    )

    Import-DscResource -ModuleName xCertificate

    Node $AllNodes.NodeName
    {
        xPfxImport CompanyCert
        {
            Thumbprint = $PfxThumbprint
            Path       = $PfxPath
            Credential = $PfxPassword
        }
    }
}

$Thumbprint = 'c81b94933420221a7ac004a90242d8b1d3e5070d'

Sample_xPfxImport_MinimalUsage `
    -PfxThumbprint $Thumbprint `
    -PfxPath '\\Server\Share\Certificates\CompanyCert.pfx' `
    -OutputPath 'c:\Sample_xPfxImport_MinimalUsage'
Start-DscConfiguration -Wait -Force -Verbose -Path 'c:\Sample_xPfxImport_MinimalUsage'

# Validate results - a Certificate with a thumbprint matching $Thumbprint should be returned
Get-ChildItem -Path Cert:\LocalMachine\My |
    Where-Object -FilterScript  { $_.Thumbprint -eq $Thumbprint }

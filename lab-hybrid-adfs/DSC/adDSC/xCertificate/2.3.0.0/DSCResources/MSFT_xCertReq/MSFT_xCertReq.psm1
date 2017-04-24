#Requires -Version 4.0

#region localizeddata
if (Test-Path "${PSScriptRoot}\${PSUICulture}")
{
    Import-LocalizedData `
        -BindingVariable LocalizedData `
        -Filename MSFT_xCertReq.strings.psd1 `
        -BaseDirectory "${PSScriptRoot}\${PSUICulture}"
}
else
{
    #fallback to en-US
    Import-LocalizedData `
        -BindingVariable LocalizedData `
        -Filename MSFT_xCertReq.strings.psd1 `
        -BaseDirectory "${PSScriptRoot}\en-US"
}
#endregion

# Import the common certificate functions
Import-Module -Name ( Join-Path `
    -Path (Split-Path -Path $PSScriptRoot -Parent) `
    -ChildPath 'CertificateCommon\CertificateCommon.psm1' )

<#
    .SYNOPSIS
    Returns the current state of the certificate that may need to be requested.

    .PARAMETER Subject
    Provide the text string to use as the subject of the certificate.

    .PARAMETER CAServerFQDN
    The FQDN of the Active Directory Certificate Authority on the local area network.

    .PARAMETER CARootName
    The name of the certificate authority, by default this will be in format domain-servername-ca.

    .PARAMETER KeyLength
    The bit length of the encryption key to be used.

    .PARAMETER Exportable
    The option to allow the certificate to be exportable, by default it will be true.

    .PARAMETER ProviderName
    The selection of provider for the type of encryption to be used.

    .PARAMETER OID
    The Object Identifier that is used to name the object.

    .PARAMETER KeyUsage
    The Keyusage is a restriction method that determines what a certificate can be used for.

    .PARAMETER CertificateTemplate
    The template used for the definiton of the certificate.

    .PARAMETER SubjectAltName
    The subject alternative name used to createthe certificate.

    .PARAMETER Credential
    The credentials that will be used to access the template in the Certificate Authority.

    .PARAMETER AutoRenew
    Determines if the resource will also renew a certificate within 7 days of expiration.
#>
function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Subject,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $CAServerFQDN,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $CARootName,

        [Parameter()]
        [ValidateSet("1024","2048","4096","8192")]
        [System.String]
        $KeyLength = '1024',

        [Parameter()]
        [System.Boolean]
        $Exportable = $true,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ProviderName = '"Microsoft RSA SChannel Cryptographic Provider"',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $OID = '1.3.6.1.5.5.7.3.1',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $KeyUsage = '0xa0',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $CertificateTemplate = 'WebServer',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $SubjectAltName,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $Credential,

        [Parameter()]
        [System.Boolean]
        $AutoRenew
    )

    # The certificate authority, accessible on the local area network
    $ca = "'$CAServerFQDN\$CARootName'"

    Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.GettingCertReqStatusMessage -f $Subject,$CA)
        ) -join '' )

    $cert = Get-Childitem -Path Cert:\LocalMachine\My |
        Where-Object -FilterScript {
            $_.Subject -eq "CN=$Subject" -and `
            $_.Issuer.split(',')[0] -eq "CN=$CARootName"
        }

    # If multiple certs have the same subject and were issued by the CA, return the newest
    $cert = $cert |
        Sort-Object -Property NotBefore -Descending |
        Select-Object -First 1

    if ($cert)
    {
        Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.CertificateExistsMessage -f $Subject,$ca,$cert.Thumbprint)
            ) -join '' )

        $returnValue = @{
            Subject              = $Cert.Subject.split(',')[0].replace('CN=','')
            CAServerFQDN         = $null # This value can't be determined from the cert
            CARootName           = $Cert.Issuer.split(',')[0].replace('CN=','')
            KeyLength            = $Cert.Publickey.Key.KeySize
            Exportable           = $null # This value can't be determined from the cert
            ProviderName         = $null # This value can't be determined from the cert
            OID                  = $null # This value can't be determined from the cert
            KeyUsage             = $null # This value can't be determined from the cert
            CertificateTemplate  = $null # This value can't be determined from the cert
            SubjectAltName       = $null # This value can't be determined from the cert
        }
    }
    else
    {
        $returnValue = @{}
    }

    $returnValue
} # end function Get-TargetResource

<#
    .SYNOPSIS
    Requests a new certificate based on the parameters provided.

    .PARAMETER Subject
    Provide the text string to use as the subject of the certificate.

    .PARAMETER CAServerFQDN
    The FQDN of the Active Directory Certificate Authority on the local area network.

    .PARAMETER CARootName
    The name of the certificate authority, by default this will be in format domain-servername-ca.

    .PARAMETER KeyLength
    The bit length of the encryption key to be used.

    .PARAMETER Exportable
    The option to allow the certificate to be exportable, by default it will be true.

    .PARAMETER ProviderName
    The selection of provider for the type of encryption to be used.

    .PARAMETER OID
    The Object Identifier that is used to name the object.

    .PARAMETER KeyUsage
    The Keyusage is a restriction method that determines what a certificate can be used for.

    .PARAMETER CertificateTemplate
    The template used for the definiton of the certificate.

    .PARAMETER SubjectAltName
    The subject alternative name used to createthe certificate.

    .PARAMETER Credential
    The credentials that will be used to access the template in the Certificate Authority.

    .PARAMETER AutoRenew
    Determines if the resource will also renew a certificate within 7 days of expiration.
#>
function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Subject,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $CAServerFQDN,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $CARootName,

        [Parameter()]
        [ValidateSet("1024","2048","4096","8192")]
        [System.String]
        $KeyLength = '1024',

        [Parameter()]
        [System.Boolean]
        $Exportable = $true,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ProviderName = '"Microsoft RSA SChannel Cryptographic Provider"',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $OID = '1.3.6.1.5.5.7.3.1',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $KeyUsage = '0xa0',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $CertificateTemplate = 'WebServer',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $SubjectAltName,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $Credential,

        [Parameter()]
        [System.Boolean]
        $AutoRenew
    )

    # The certificate authority, accessible on the local area network
    $ca = "'$CAServerFQDN\$CARootName'"

    Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.StartingCertReqMessage -f $Subject,$ca)
        ) -join '' )

    # If the Subject does not contain a full X500 path, construct just the CN
    if (($Subject.split('=').Count) -eq 1)
    {
        $Subject = "CN=$Subject"
    } # if

    # If we should look for renewals, check for existing certs
    if ($AutoRenew)
    {
        $certs = Get-Childitem -Path Cert:\LocalMachine\My |
            Where-Object -FilterScript {
                $_.Subject -eq $Subject -and `
                $_.Issuer.split(',')[0] -eq "CN=$CARootName" -and `
                $_.NotAfter -lt (Get-Date).AddDays(30)
            }

        # If multiple certs have the same subject and were issued by the CA and are 30 days from expiration, return the newest
        $firstCert = $certs |
            Sort-Object -Property NotBefore -Descending |
            Select-Object -First 1
        $thumbprint = $firstCert |
            ForEach-Object -Process { $_.Thumbprint }
    } # if

    # Information that will be used in the INF file to generate the certificate request
    # In future versions, select variables from the list below could be moved to parameters!
    $Subject             = "`"$Subject`""
    $keySpec             = '1'
    $machineKeySet       = 'TRUE'
    $smime               = 'FALSE'
    $privateKeyArchive   = 'FALSE'
    $userProtected       = 'FALSE'
    $useExistingKeySet   = 'FALSE'
    $providerType        = '12'
    $requestType         = 'CMC'

    # A unique identifier for temporary files that will be used when interacting with the command line utility
    $guid = [system.guid]::NewGuid().guid
    $workingPath = Join-Path -Path $ENV:Temp -ChildPath "xCertReq-$guid"
    $infPath = [System.IO.Path]::ChangeExtension($workingPath,'.inf')
    $reqPath = [System.IO.Path]::ChangeExtension($workingPath,'.req')
    $cerPath = [System.IO.Path]::ChangeExtension($workingPath,'.cer')
    $rspPath = [System.IO.Path]::ChangeExtension($workingPath,'.rsp')

    # Create INF file
    $requestDetails = @"
[NewRequest]
Subject = $Subject
KeySpec = $keySpec
KeyLength = $KeyLength
Exportable = $($Exportable.ToString().ToUpper())
MachineKeySet = $MachineKeySet
SMIME = $smime
PrivateKeyArchive = $privateKeyArchive
UserProtected = $userProtected
UseExistingKeySet = $useExistingKeySet
ProviderName = $ProviderName
ProviderType = $providerType
RequestType = $requestType
KeyUsage = $KeyUsage
[RequestAttributes]
CertificateTemplate = $CertificateTemplate
[EnhancedKeyUsageExtension]
OID = $OID
"@
    if ($PSBoundParameters.ContainsKey('SubjectAltName'))
    {
        # If a Subject Alt Name was specified, add it.
        $requestDetails += @"

[Extensions]
2.5.29.17 = `"{text}$SubjectAltName`"
"@
    }
    if ($thumbprint)
    {
        $requestDetails += @"

RenewalCert = $Thumbprint
"@
    }
    Set-Content -Path $infPath -Value $requestDetails

    # Certreq.exe:
    # Syntax: https://technet.microsoft.com/en-us/library/cc736326.aspx
    # Reference: https://support2.microsoft.com/default.aspx?scid=kb;EN-US;321051

    # NEW: Create a new request as directed by PolicyFileIn
    Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.CreateRequestCertificateMessage -f $infPath,$reqPath)
        ) -join '' )

    $createRequest = & certreq.exe @('-new','-q',$infPath,$reqPath)

    Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.CreateRequestResultCertificateMessage -f $createRequest)
        ) -join '' )

    # SUBMIT: Submit a request to a Certification Authority.
    # DSC runs in the context of LocalSystem, which uses the Computer account in Active Directory
    # to authenticate to network resources
    # The Credential paramter with xPDT is used to impersonate a user making the request
    if (Test-Path -Path $reqPath)
    {
        Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.SubmittingRequestCertificateMessage -f $reqPath,$cerPath,$ca)
            ) -join '' )

        if ($Credential)
        {
            Import-Module -Name $PSScriptRoot\..\PDT\PDT.psm1 -Force

            # Assemble the command and arguments to pass to the powershell process that
            # will request the certificate
            $certReqOutPath = [System.IO.Path]::ChangeExtension($workingPath,'.out')
            $command = "$PSHOME\PowerShell.exe"
            $arguments = "-Command ""& $ENV:SystemRoot\system32\certreq.exe" + `
                " @('-submit','-q','-config',$ca,'$reqPath','$cerPath')" + `
                " | Set-Content -Path '$certReqOutPath'"""

            # This may output a win32-process object, but it often does not because of
            # a timing issue in PDT (the process has often completed before the
            # process can be read in).
            $null = Start-Win32Process `
                -Path $command `
                -Arguments $arguments `
                -Credential $Credential

            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.SubmittingRequestProcessCertificateMessage)
            ) -join '' )

            $null = Wait-Win32ProcessEnd `
                -Path $command `
                -Arguments $arguments `
                -Credential $Credential

            if (Test-Path -Path $certReqOutPath)
            {
                $submitRequest = Get-Content -Path $certReqOutPath
                Remove-Item -Path $certReqOutPath -Force
            }
            else
            {
                New-InvalidArgumentError `
                    -ErrorId 'CertReqOutNotFoundError' `
                    -ErrorMessage ($LocalizedData.CertReqOutNotFoundError -f $certReqOutPath)
            } # if
        }
        else
        {
            $submitRequest = & certreq.exe @('-submit','-q','-config',$CA,$ReqPath,$CerPath)
        } # if

        Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.SubmittingRequestResultCertificateMessage -f $submitRequest)
            ) -join '' )
    }
    else
    {
        New-InvalidArgumentError `
            -ErrorId 'CertificateReqNotFoundError' `
            -ErrorMessage ($LocalizedData.CertificateReqNotFoundError -f $reqPath)
    } # if

    # ACCEPT: Accept the request
    if (Test-Path -Path $cerPath)
    {
        Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.AcceptingRequestCertificateMessage -f $cerPath,$ca)
            ) -join '' )

        $acceptRequest = & certreq.exe @('-accept','-machine','-q',$cerPath)

        Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.AcceptingRequestResultCertificateMessage -f $acceptRequest)
            ) -join '' )
    }
    else
    {
        New-InvalidArgumentError `
            -ErrorId 'CertificateCerNotFoundError' `
            -ErrorMessage ($LocalizedData.CertificateCerNotFoundError -f $cerPath)
    } # if

    Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.CleaningUpRequestFilesMessage -f "$($workingPath).*")
        ) -join '' )
    Remove-Item -Path "$($workingPath).*" -Force
} # end function Set-TargetResource

<#
    .SYNOPSIS
    Tests if a new certificate should be requested.

    .PARAMETER Subject
    Provide the text string to use as the subject of the certificate.

    .PARAMETER CAServerFQDN
    The FQDN of the Active Directory Certificate Authority on the local area network.

    .PARAMETER CARootName
    The name of the certificate authority, by default this will be in format domain-servername-ca.

    .PARAMETER KeyLength
    The bit length of the encryption key to be used.

    .PARAMETER Exportable
    The option to allow the certificate to be exportable, by default it will be true.

    .PARAMETER ProviderName
    The selection of provider for the type of encryption to be used.

    .PARAMETER OID
    The Object Identifier that is used to name the object.

    .PARAMETER KeyUsage
    The Keyusage is a restriction method that determines what a certificate can be used for.

    .PARAMETER CertificateTemplate
    The template used for the definiton of the certificate.

    .PARAMETER SubjectAltName
    The subject alternative name used to createthe certificate.

    .PARAMETER Credential
    The credentials that will be used to access the template in the Certificate Authority.

    .PARAMETER AutoRenew
    Determines if the resource will also renew a certificate within 7 days of expiration.
#>
function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Subject,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $CAServerFQDN,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $CARootName,

        [Parameter()]
        [ValidateSet("1024","2048","4096","8192")]
        [System.String]
        $KeyLength = '1024',

        [Parameter()]
        [System.Boolean]
        $Exportable = $true,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ProviderName = '"Microsoft RSA SChannel Cryptographic Provider"',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $OID = '1.3.6.1.5.5.7.3.1',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $KeyUsage = '0xa0',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $CertificateTemplate = 'WebServer',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $SubjectAltName,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $Credential,

        [Parameter()]
        [System.Boolean]
        $AutoRenew
    )

    # The certificate authority, accessible on the local area network
    $ca = "'$CAServerFQDN\$CARootName'"

    # If the Subject does not contain a full X500 path, construct just the CN
    if (($Subject.split('=').count) -eq 1)
    {
        $Subject = "CN=$Subject"
    }

    Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.TestingCertReqStatusMessage -f $Subject,$ca)
        ) -join '' )

    $cert = Get-Childitem -Path Cert:\LocalMachine\My |
        Where-Object -FilterScript {
            $_.Subject -eq $Subject -and `
            $_.Issuer.split(',')[0] -eq "CN=$CARootName"
        }

    # If multiple certs have the same subject and were issued by the CA, return the newest
    $cert = $cert |
        Sort-Object -Property NotBefore -Descending |
        Select-Object -First 1

    if ($cert)
    {
        Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.CertificateExistsMessage -f $Subject,$ca,$cert.Thumbprint)
            ) -join '' )

        if ($AutoRenew) {
            if ($Cert.NotAfter -le (Get-Date).AddDays(-30))
            {
                # The certificate was found but it is expiring within 30 days or has expired
                Write-Verbose -Message ( @(
                        "$($MyInvocation.MyCommand): "
                        $($LocalizedData.ExpiringCertificateMessage -f $Subject,$ca,$cert.Thumbprint)
                    ) -join '' )
                return $false
            } # if
        }
        else
        {
            if ($cert.NotAfter -le (Get-Date))
            {
                # The certificate has expired
                Write-Verbose -Message ( @(
                        "$($MyInvocation.MyCommand): "
                        $($LocalizedData.ExpiredCertificateMessage -f $Subject,$ca,$cert.Thumbprint)
                    ) -join '' )
                return $false
            } # if
        } # if

        # The certificate was found and is OK - so no change required.
        Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.ValidCertificateExistsMessage -f $Subject,$ca,$cert.Thumbprint)
            ) -join '' )
        return $true
    } # if

    # A valid certificate was not found
    Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.NoValidCertificateMessage -f $Subject,$ca)
        ) -join '' )
    return $false
} # end function Test-TargetResource

#Requires -Version 4.0

#region localizeddata
if (Test-Path "${PSScriptRoot}\${PSUICulture}")
{
    Import-LocalizedData `
        -BindingVariable LocalizedData `
        -Filename MSFT_xPfxImport.strings.psd1 `
        -BaseDirectory "${PSScriptRoot}\${PSUICulture}"
}
else
{
    #fallback to en-US
    Import-LocalizedData `
        -BindingVariable LocalizedData `
        -Filename MSFT_xPfxImport.strings.psd1 `
        -BaseDirectory "${PSScriptRoot}\en-US"
}
#endregion

# Import the common certificate functions
Import-Module -Name ( Join-Path `
    -Path (Split-Path -Path $PSScriptRoot -Parent) `
    -ChildPath 'CertificateCommon\CertificateCommon.psm1' )

<#
    .SYNOPSIS
    Returns the current state of the PFX Certificte file that should be imported.

    .PARAMETER Thumbprint
    The thumbprint (unique identifier) of the PFX file you're importing.

    .PARAMETER Path
    The Windows Certificate Store Location to import the PFX file to.

    .PARAMETER Location
    The Windows Certificate Store Location to import the PFX file to.

    .PARAMETER Store
    The Windows Certificate Store Name to import the PFX file to.

    .PARAMETER Exportable
    Determines whether the private key is exportable from the machine after it has been imported.

    .PARAMETER Credential
    A [PSCredential] object that is used to decrypt the PFX file. Only the password is used, so any user name is valid.

    .PARAMETER Ensure
    Specifies whether the PFX file should be present or absent.
#>
function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateScript( { $_ | Test-Thumbprint } )]
        [System.String]
        $Thumbprint,

        [Parameter(Mandatory = $true)]
        [ValidateScript( { $_ | Test-CertificatePath } )]
        [System.String]
        $Path,

        [Parameter(Mandatory = $true)]
        [ValidateSet('CurrentUser', 'LocalMachine')]
        [System.String]
        $Location,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Store,

        [Parameter()]
        [Boolean]
        $Exportable = $false,

        [Parameter()]
        [PSCredential]
        $Credential,

        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure = 'Present'
    )

    $certificateStore = 'Cert:' |
        Join-Path -ChildPath $Location |
        Join-Path -ChildPath $Store

    Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.GettingPfxStatusMessage -f $Thumbprint,$certificateStore)
        ) -join '' )

    if ((Test-Path $certificateStore) -eq $false)
    {
        New-InvalidArgumentError `
            -ErrorId 'CertificateStoreNotFound' `
            -ErrorMessage ($LocalizedData.CertificateStoreNotFoundError -f $certificateStore)
    }

    $checkEnsure = [Bool](
        $certificateStore |
        Get-ChildItem |
        Where-Object -FilterScript {$_.Thumbprint -ieq $Thumbprint}
    )
    if ($checkEnsure)
    {
        $Ensure = 'Present'
    }
    else
    {
        $Ensure = 'Absent'
    }

    @{
        Thumbprint = $Thumbprint
        Path       = $Path
        Location   = $Location
        Store      = $Store
        Exportable = $Exportable
        Ensure     = $Ensure
    }
} # end function Get-TargetResource

<#
    .SYNOPSIS
    Tests if the PFX Certificate file needs to be imported or removed.

    .PARAMETER Thumbprint
    The thumbprint (unique identifier) of the PFX file you're importing.

    .PARAMETER Path
    The Windows Certificate Store Location to import the PFX file to.

    .PARAMETER Location
    The Windows Certificate Store Location to import the PFX file to.

    .PARAMETER Store
    The Windows Certificate Store Name to import the PFX file to.

    .PARAMETER Exportable
    Determines whether the private key is exportable from the machine after it has been imported.

    .PARAMETER Credential
    A [PSCredential] object that is used to decrypt the PFX file. Only the password is used, so any user name is valid.

    .PARAMETER Ensure
    Specifies whether the PFX file should be present or absent.
#>
function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateScript( { $_ | Test-Thumbprint } )]
        [System.String]
        $Thumbprint,

        [Parameter(Mandatory = $true)]
        [ValidateScript( { $_ | Test-CertificatePath } )]
        [System.String]
        $Path,

        [Parameter(Mandatory = $true)]
        [ValidateSet('CurrentUser', 'LocalMachine')]
        [System.String]
        $Location,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Store,

        [Parameter()]
        [Boolean]
        $Exportable = $false,

        [Parameter()]
        [PSCredential]
        $Credential,

        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure = 'Present'
    )

    $result = @(Get-TargetResource @PSBoundParameters)

    $certificateStore = 'Cert:' |
        Join-Path -ChildPath $Location |
        Join-Path -ChildPath $Store

    Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.TestingPfxStatusMessage -f $Thumbprint,$certificateStore)
        ) -join '' )


    if ($Ensure -ne $result.Ensure)
    {
        return $false
    }
    return $true
} # end function Test-TargetResource

<#
    .SYNOPSIS
    Imports or removes the specified PFX Certifiicate file.

    .PARAMETER Thumbprint
    The thumbprint (unique identifier) of the PFX file you're importing.

    .PARAMETER Path
    The Windows Certificate Store Location to import the PFX file to.

    .PARAMETER Location
    The Windows Certificate Store Location to import the PFX file to.

    .PARAMETER Store
    The Windows Certificate Store Name to import the PFX file to.

    .PARAMETER Exportable
    Determines whether the private key is exportable from the machine after it has been imported.

    .PARAMETER Credential
    A [PSCredential] object that is used to decrypt the PFX file. Only the password is used, so any user name is valid.

    .PARAMETER Ensure
    Specifies whether the PFX file should be present or absent.
#>
function Set-TargetResource
{
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateScript( { $_ | Test-Thumbprint } )]
        [System.String]
        $Thumbprint,

        [Parameter(Mandatory = $true)]
        [ValidateScript( { $_ | Test-CertificatePath } )]
        [System.String]
        $Path,

        [Parameter(Mandatory = $true)]
        [ValidateSet('CurrentUser', 'LocalMachine')]
        [System.String]
        $Location,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Store,

        [Parameter()]
        [Boolean]
        $Exportable = $false,

        [Parameter()]
        [PSCredential]
        $Credential,

        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure = 'Present'
    )

    $certificateStore = 'Cert:' |
        Join-Path -ChildPath $Location |
        Join-Path -ChildPath $Store

    Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.SettingPfxStatusMessage -f $Thumbprint,$certificateStore)
        ) -join '' )

    if ($Ensure -ieq 'Present')
    {
        if ($PSCmdlet.ShouldProcess(($LocalizedData.ImportingPfxShould `
            -f $Path,$certificateStore)))
        {
            # Import the certificate into the Store
            Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.ImportingPfxMessage -f $Path,$certificateStore)
                ) -join '' )

            $param = @{
                Exportable        = $Exportable
                CertStoreLocation = $certificateStore
                FilePath          = $Path
            }
            if ($Credential)
            {
                $param['Password'] = $Credential.Password
            }
            Import-PfxCertificate @param
        }
    }
    elseif ($Ensure -ieq 'Absent')
    {
        # Remove the certificate from the Store
        Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.RemovingPfxMessage -f $Thumbprint,$certificateStore)
            ) -join '' )

        Get-ChildItem -Path $certificateStore |
            Where-Object { $_.Thumbprint -ieq $thumbprint } |
            Remove-Item -Force
    }
} # end function Set-TargetResource

Export-ModuleMember -Function *-TargetResource

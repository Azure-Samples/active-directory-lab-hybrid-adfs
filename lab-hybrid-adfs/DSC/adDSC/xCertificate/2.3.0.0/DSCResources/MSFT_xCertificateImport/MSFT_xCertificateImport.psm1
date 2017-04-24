#Requires -Version 4.0

#region localizeddata
if (Test-Path "${PSScriptRoot}\${PSUICulture}")
{
    Import-LocalizedData `
        -BindingVariable LocalizedData `
        -Filename MSFT_xCertificateImport.strings.psd1 `
        -BaseDirectory "${PSScriptRoot}\${PSUICulture}"
}
else
{
    #fallback to en-US
    Import-LocalizedData `
        -BindingVariable LocalizedData `
        -Filename MSFT_xCertificateImport.strings.psd1 `
        -BaseDirectory "${PSScriptRoot}\en-US"
}
#endregion

# Import the common certificate functions
Import-Module -Name ( Join-Path `
    -Path (Split-Path -Path $PSScriptRoot -Parent) `
    -ChildPath 'CertificateCommon\CertificateCommon.psm1' )

<#
    .SYNOPSIS
    Returns the current state of the CER Certificte file that should be imported.

    .PARAMETER Thumbprint
    The thumbprint (unique identifier) of the certificate you're importing.

    .PARAMETER Path
    The path to the CER file you want to import.

    .PARAMETER Location
    The Windows Certificate Store Location to import the certificate to.

    .PARAMETER Store
    The Windows Certificate Store Name to import the certificate to.

    .PARAMETER Ensure
    Specifies whether the certificate should be present or absent.
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
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure = 'Present'
    )

    $certificateStore = 'Cert:' |
        Join-Path -ChildPath $Location |
        Join-Path -ChildPath $Store

    Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.GettingCertificateStatusMessage -f $Thumbprint,$certificateStore)
        ) -join '' )

    if ((Test-Path $certificateStore) -eq $false)
    {
        New-InvalidArgumentError `
            -ErrorId 'CertificateStoreNotFound' `
            -ErrorMessage ($LocalizedData.CertificateStoreNotFoundError -f $certificateStore)
    }

    $checkEnsure = [Bool] (
        $certificateStore |
        Get-ChildItem |
        Where-Object -FilterScript { $_.Thumbprint -ieq $Thumbprint }
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
        Ensure     = $Ensure
    }
} # end function Get-TargetResource

<#
    .SYNOPSIS
    Tests if the CER Certificate file needs to be imported or removed.

    .PARAMETER Thumbprint
    The thumbprint (unique identifier) of the certificate you're importing.

    .PARAMETER Path
    The path to the CER file you want to import.

    .PARAMETER Location
    The Windows Certificate Store Location to import the certificate to.

    .PARAMETER Store
    The Windows Certificate Store Name to import the certificate to.

    .PARAMETER Ensure
    Specifies whether the certificate should be present or absent.
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
            $($LocalizedData.TestingCertificateStatusMessage -f $Thumbprint,$CertificateStore)
        ) -join '' )

    if ($Ensure -ne $result.Ensure)
    {
        return $false
    }
    return $true
} # end function Test-TargetResource

<#
    .SYNOPSIS
    Imports or removes the specified CER Certifiicate file.

    .PARAMETER Thumbprint
    The thumbprint (unique identifier) of the certificate you're importing.

    .PARAMETER Path
    The path to the CER file you want to import.

    .PARAMETER Location
    The Windows Certificate Store Location to import the certificate to.

    .PARAMETER Store
    The Windows Certificate Store Name to import the certificate to.

    .PARAMETER Ensure
    Specifies whether the certificate should be present or absent.
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
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure = 'Present'
    )

    $certificateStore = 'Cert:' |
        Join-Path -ChildPath $Location |
        Join-Path -ChildPath $Store

    Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.SettingCertificateStatusMessage -f $Thumbprint,$certificateStore)
        ) -join '' )

    if ($Ensure -ieq 'Present')
    {
        if ($PSCmdlet.ShouldProcess(($LocalizedData.ImportingCertificateShould `
            -f $Path,$certificateStore)))
        {
            # Import the certificate into the Store
            Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.ImportingCertficateMessage -f $Path,$certificateStore)
                ) -join '' )

            $param = @{
                CertStoreLocation = $certificateStore
                FilePath          = $Path
                Verbose           = $VerbosePreference
            }

            Import-Certificate @param
        }
    }
    elseif ($Ensure -ieq 'Absent')
    {
        # Remove the certificate from the Store
        Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.RemovingCertficateMessage -f $Thumbprint,$certificateStore)
            ) -join '' )

        Get-ChildItem -Path $certificateStore |
            Where-Object { $_.Thumbprint -ieq $Thumbprint } |
            Remove-Item -Force
    }
}  # end function Test-TargetResource

Export-ModuleMember -Function *-TargetResource

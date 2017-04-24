$script:DSCModuleName   = 'xCertificate'
$script:DSCResourceName = 'MSFT_xCertificateImport'

#region HEADER
# Integration Test Template Version: 1.1.0
[String] $script:moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if ( (-not (Test-Path -Path (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests'))) -or `
     (-not (Test-Path -Path (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1'))) )
{
    & git @('clone','https://github.com/PowerShell/DscResource.Tests.git',(Join-Path -Path $script:moduleRoot -ChildPath '\DSCResource.Tests\'))
}

Import-Module (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1') -Force
$TestEnvironment = Initialize-TestEnvironment `
    -DSCModuleName $script:DSCModuleName `
    -DSCResourceName $script:DSCResourceName `
    -TestType Integration
#endregion

# Using try/finally to always cleanup even if something awful happens.
try
{
    # Generate a self-signed certificate, export it and remove it from the store
    # to use for testing.
    # Don't use CurrentUser certificates for this test because they won't be found because
    # DSC LCM runs under a different context (Local System).
    $Certificate = New-SelfSignedCertificate `
        -DnsName $ENV:ComputerName `
        -CertStoreLocation Cert:\LocalMachine\My
    $CertificatePath = Join-Path `
        -Path $ENV:Temp `
        -ChildPath "xCertificateImport-$($Certificate.Thumbprint).cer"
    $null = Export-Certificate `
        -Cert $Certificate `
        -Type CERT `
        -FilePath $CertificatePath
    $null = Remove-Item `
        -Path $Certificate.PSPath `
        -Force

    #region Integration Tests
    $ConfigFile = Join-Path -Path $PSScriptRoot -ChildPath "$($script:DSCResourceName)_Add.config.ps1"
    . $ConfigFile

    Describe "$($script:DSCResourceName)_Add_Integration" {
        #region DEFAULT TESTS
        It 'Should compile without throwing' {
            {
                & "$($script:DSCResourceName)_Add_Config" `
                    -OutputPath $TestDrive `
                    -Path $CertificatePath `
                    -Thumbprint $Certificate.Thumbprint
                Start-DscConfiguration -Path $TestDrive -ComputerName localhost -Wait -Verbose -Force
            } | Should not throw
        }

        It 'should be able to call Get-DscConfiguration without throwing' {
            { Get-DscConfiguration -Verbose -ErrorAction Stop } | Should Not throw
        }
        #endregion

        It 'Should have set the resource and all the parameters should match' {
            # Get the Certificate details
            $CertificateNew = Get-Item `
                -Path "Cert:\LocalMachine\My\$($Certificate.Thumbprint)"
            $CertificateNew                             | Should BeOfType System.Security.Cryptography.X509Certificates.X509Certificate2
            $CertificateNew.Thumbprint                  | Should Be $Certificate.Thumbprint
            $CertificateNew.Subject                     | Should Be $Certificate.Subject
        }
    }
    #endregion

    #region Integration Tests
    $ConfigFile = Join-Path -Path $PSScriptRoot -ChildPath "$($script:DSCResourceName)_Remove.config.ps1"
    . $ConfigFile

    Describe "$($script:DSCResourceName)_Remove_Integration" {
        #region DEFAULT TESTS
        It 'Should compile without throwing' {
            {
                & "$($script:DSCResourceName)_Remove_Config" `
                    -OutputPath $TestDrive `
                    -Path $CertificatePath `
                    -Thumbprint $Certificate.Thumbprint
                Start-DscConfiguration -Path $TestDrive -ComputerName localhost -Wait -Verbose -Force
            } | Should not throw
        }

        It 'should be able to call Get-DscConfiguration without throwing' {
            { Get-DscConfiguration -Verbose -ErrorAction Stop } | Should Not throw
        }
        #endregion

        It 'Should have set the resource and all the parameters should match' {
            # Get the Certificate details
            $CertificateNew = Get-Item `
                -Path "Cert:\LocalMachine\My\$($Certificate.Thumbprint)" `
                -ErrorAction SilentlyContinue
            $CertificateNew                             | Should BeNullOrEmpty
        }
    }
    #endregion
}
finally
{
    # Clean up
    $null = Remove-Item `
        -Path $CertificatePath `
        -Force `
        -ErrorAction SilentlyContinue
    $null = Remove-Item `
        -Path $Certificate.PSPath `
        -Force `
        -ErrorAction SilentlyContinue

    #region FOOTER
    Restore-TestEnvironment -TestEnvironment $TestEnvironment
    #endregion
}

<#
 IMPORTANT INFORMATION:
 Running these tests requires access to a AD CS Certificate Authority.
 These integration tests are configured to use credentials to connect to the CA.
 Therefore, automation of these tests shouldn't be performed using a production CA.
#>

$script:DSCModuleName   = 'xCertificate'
$script:DSCResourceName = 'MSFT_xCertReq'

<#
 These tests can only be run if a CA is available and configured to be used on the
 computer running these tests. This is usually required to be a domain joined computer.
#>
$CertUtilResult = & "$ENV:SystemRoot\system32\certutil.exe" @('-dump')
$Result = ([regex]::matches($CertUtilResult,'Name:[ \t]+`([\sA-Za-z0-9._-]+)''','IgnoreCase'))
if ([String]::IsNullOrEmpty($Result))
{
    Describe "$($script:DSCResourceName)_Integration" {
        It 'should complete integration tests' {
        } -Skip
    }
    return
} # if

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
    #region Integration Tests
    $ConfigFile = Join-Path -Path $PSScriptRoot -ChildPath "$($script:DSCResourceName).config.ps1"
    . $ConfigFile

    Describe "$($script:DSCResourceName)_Integration" {
        #region DEFAULT TESTS
        It 'Should compile without throwing' {
            {
                # This is to allow the testing of certreq with domain credentials
                $ConfigData = @{
                    AllNodes = @(
                        @{
                            NodeName = 'localhost'
                            PsDscAllowDomainUser = $true
                            PsDscAllowPlainTextPassword = $true
                        }
                    )
                }

                & "$($script:DSCResourceName)_Config" `
                    -OutputPath $TestDrive `
                    -ConfigurationData $ConfigData
                Start-DscConfiguration -Path $TestDrive -ComputerName localhost -Wait -Verbose -Force
            } | Should not throw
        }

        It 'should be able to call Get-DscConfiguration without throwing' {
            { Get-DscConfiguration -Verbose -ErrorAction Stop } | Should Not throw
        }
        #endregion

        It 'Should have set the resource and all the parameters should match' {
            # Get the Certificate details
            $CertificateNew = Get-Childitem -Path Cert:\LocalMachine\My |
                Where-Object -FilterScript {
                    $_.Subject -eq "CN=$($TestCertReq.Subject)" -and `
                    $_.Issuer.split(',')[0] -eq "CN=$($TestCertReq.CARootName)"
                }
            $CertificateNew.Subject                        | Should Be "CN=$($TestCertReq.Subject)"
            $CertificateNew.Issuer.split(',')[0]           | Should Be "CN=$($TestCertReq.CARootName)"
            $CertificateNew.Publickey.Key.KeySize          | Should Be $TestCertReq.KeyLength
        }

        AfterAll {
            # Cleanup
            $CertificateNew = Get-Childitem -Path Cert:\LocalMachine\My |
                Where-Object -FilterScript {
                    $_.Subject -eq "CN=$($TestCertReq.Subject)" -and `
                    $_.Issuer.split(',')[0] -eq "CN=$($TestCertReq.CARootName)"
                }

            Remove-Item `
                -Path $CertificateNew.PSPath `
                -Force `
                -ErrorAction SilentlyContinue
        }
   }
    #endregion
}
finally
{
    #region FOOTER
    Restore-TestEnvironment -TestEnvironment $TestEnvironment
    #endregion
}

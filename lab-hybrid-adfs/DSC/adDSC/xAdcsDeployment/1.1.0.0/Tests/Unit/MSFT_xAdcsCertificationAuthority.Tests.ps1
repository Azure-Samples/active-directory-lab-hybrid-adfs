$script:DSCModuleName   = 'xAdcsDeployment'
$script:DSCResourceName = 'MSFT_xAdcsCertificationAuthority'

#region HEADER
# Integration Test Template Version: 1.1.0
[String] $script:moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if ( (-not (Test-Path -Path (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests'))) -or `
     (-not (Test-Path -Path (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1'))) )
{
    & git @('clone','https://github.com/PowerShell/DscResource.Tests.git',(Join-Path -Path $script:moduleRoot -ChildPath '\DSCResource.Tests\'))
}

Import-Module -Name (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1') -Force
$TestEnvironment = Initialize-TestEnvironment `
    -DSCModuleName $script:DSCModuleName `
    -DSCResourceName $script:DSCResourceName `
    -TestType Unit
#endregion

# Begin Testing
try
{
    #region Pester Tests
    InModuleScope $($script:DSCResourceName) {
        if (-not ([System.Management.Automation.PSTypeName]'Microsoft.CertificateServices.Deployment.Common.CA.CertificationAuthoritySetupException').Type)
        {
            # Define the exception class:
            # Microsoft.CertificateServices.Deployment.Common.CA.CertificationAuthoritySetupException
            # so that unit tests can be run without ADCS being installed.

            $ExceptionDefinition = @'
namespace Microsoft.CertificateServices.Deployment.Common.CA {
    public class CertificationAuthoritySetupException: System.Exception {
    }
}
'@
            Add-Type -TypeDefinition $ExceptionDefinition
        }
        $DSCResourceName = 'MSFT_xAdcsCertificationAuthority'

        $DummyCredential = New-Object System.Management.Automation.PSCredential ("Administrator",(New-Object -Type SecureString))

        $TestParametersPresent = @{
            Ensure     = 'Present'
            CAType     = 'StandaloneRootCA'
            Credential = $DummyCredential
            Verbose    = $true
        }

        $TestParametersAbsent = @{
            Ensure     = 'Absent'
            CAType     = 'StandaloneRootCA'
            Credential = $DummyCredential
            Verbose    = $true
        }

        Describe "$DSCResourceName\Get-TargetResource" {

            function Install-AdcsCertificationAuthority {
                [CmdletBinding()]
                param (
                    [Parameter(Mandatory = $True)]
                    [ValidateSet('EnterpriseRootCA','EnterpriseSubordinateCA','StandaloneRootCA','StandaloneSubordinateCA')]
                    [string] $CAType,

                    [Parameter(Mandatory = $True)]
                    [pscredential] $Credential,

                    [string] $CACommonName,

                    [string] $CADistinguishedNameSuffix,

                    [string] $CertFile,

                    [pscredential] $CertFilePassword,

                    [string] $CertificateID,

                    [string] $CryptoProviderName,

                    [string] $DatabaseDirectory,

                    [string] $HashAlgorithmName,

                    [boolean] $IgnoreUnicode,

                    [string] $KeyContainerName,

                    [uint32] $KeyLength,

                    [string] $LogDirectory,

                    [string] $OutputCertRequestFile,

                    [boolean] $OverwriteExistingCAinDS,

                    [boolean] $OverwriteExistingDatabase,

                    [boolean] $OverwriteExistingKey,

                    [string] $ParentCA,

                    [ValidateSet('Hours','Days','Months','Years')]
                    [string] $ValidityPeriod,

                    [uint32] $ValidityPeriodUnits,

                    [Switch] $Force,

                    [Switch] $WhatIf
                )
            }

            #region Mocks
            Mock `
                -CommandName Install-AdcsCertificationAuthority `
                -MockWith { Throw (New-Object -TypeName 'Microsoft.CertificateServices.Deployment.Common.CA.CertificationAuthoritySetupException') } `
                -Verifiable
            #endregion

            Context 'CA is installed' {
                $Result = Get-TargetResource @TestParametersPresent

                It 'should return Ensure set to Present' {
                    $Result.Ensure  | Should Be 'Present'
                }

                It 'should call expected mocks' {
                    Assert-VerifiableMocks
                    Assert-MockCalled `
                        -CommandName Install-AdcsCertificationAuthority `
                        -Exactly 1
                }
            }

            #region Mocks
            Mock `
                -CommandName Install-AdcsCertificationAuthority
            #endregion

            Context 'CA is not installed' {
                $Result = Get-TargetResource @TestParametersPresent

                It 'should return Ensure set to Absent' {
                    $Result.Ensure  | Should Be 'Absent'
                }

                It 'should call expected mocks' {
                    Assert-MockCalled `
                        -CommandName Install-AdcsCertificationAuthority `
                        -Exactly 1
                }
            }
        }

        Describe "$DSCResourceName\Set-TargetResource" {

            function Install-AdcsCertificationAuthority {
                [CmdletBinding()]
                param (
                    [Parameter(Mandatory = $True)]
                    [ValidateSet('EnterpriseRootCA','EnterpriseSubordinateCA','StandaloneRootCA','StandaloneSubordinateCA')]
                    [string] $CAType,

                    [Parameter(Mandatory = $True)]
                    [pscredential] $Credential,

                    [string] $CACommonName,

                    [string] $CADistinguishedNameSuffix,

                    [string] $CertFile,

                    [pscredential] $CertFilePassword,

                    [string] $CertificateID,

                    [string] $CryptoProviderName,

                    [string] $DatabaseDirectory,

                    [string] $HashAlgorithmName,

                    [boolean] $IgnoreUnicode,

                    [string] $KeyContainerName,

                    [uint32] $KeyLength,

                    [string] $LogDirectory,

                    [string] $OutputCertRequestFile,

                    [boolean] $OverwriteExistingCAinDS,

                    [boolean] $OverwriteExistingDatabase,

                    [boolean] $OverwriteExistingKey,

                    [string] $ParentCA,

                    [ValidateSet('Hours','Days','Months','Years')]
                    [string] $ValidityPeriod,

                    [uint32] $ValidityPeriodUnits,

                    [Switch] $Force,

                    [Switch] $WhatIf
                )
            }
            function Uninstall-AdcsCertificationAuthority {
                [CmdletBinding()]
                param (
                    [Switch] $Force
                )
            }

            #region Mocks
            Mock -CommandName Install-AdcsCertificationAuthority
            Mock -CommandName Uninstall-AdcsCertificationAuthority
            #endregion

            Context 'CA is not installed but should be' {
                Set-TargetResource @TestParametersPresent

                It 'should call expected mocks' {
                    Assert-MockCalled `
                        -CommandName Install-AdcsCertificationAuthority `
                        -Exactly 1
                    Assert-MockCalled `
                        -CommandName Uninstall-AdcsCertificationAuthority `
                        -Exactly 0
                }
            }

            Context 'CA is installed but should not be' {
                Set-TargetResource @TestParametersAbsent

                It 'should call expected mocks' {
                    Assert-MockCalled `
                        -CommandName Install-AdcsCertificationAuthority `
                        -Exactly 0
                    Assert-MockCalled `
                        -CommandName Uninstall-AdcsCertificationAuthority `
                        -Exactly 1
                }
            }
        }

        Describe "$DSCResourceName\Test-TargetResource" {

            function Install-AdcsCertificationAuthority {
                [CmdletBinding()]
                param (
                    [Parameter(Mandatory = $True)]
                    [ValidateSet('EnterpriseRootCA','EnterpriseSubordinateCA','StandaloneRootCA','StandaloneSubordinateCA')]
                    [string] $CAType,

                    [Parameter(Mandatory = $True)]
                    [pscredential] $Credential,

                    [string] $CACommonName,

                    [string] $CADistinguishedNameSuffix,

                    [string] $CertFile,

                    [pscredential] $CertFilePassword,

                    [string] $CertificateID,

                    [string] $CryptoProviderName,

                    [string] $DatabaseDirectory,

                    [string] $HashAlgorithmName,

                    [boolean] $IgnoreUnicode,

                    [string] $KeyContainerName,

                    [uint32] $KeyLength,

                    [string] $LogDirectory,

                    [string] $OutputCertRequestFile,

                    [boolean] $OverwriteExistingCAinDS,

                    [boolean] $OverwriteExistingDatabase,

                    [boolean] $OverwriteExistingKey,

                    [string] $ParentCA,

                    [ValidateSet('Hours','Days','Months','Years')]
                    [string] $ValidityPeriod,

                    [uint32] $ValidityPeriodUnits,

                    [Switch] $Force,

                    [Switch] $WhatIf
                )
            }

            #region Mocks
            Mock -CommandName Install-AdcsCertificationAuthority `
                -MockWith { Throw (New-Object -TypeName 'Microsoft.CertificateServices.Deployment.Common.CA.CertificationAuthoritySetupException') } `
                -Verifiable
            #endregion

            Context 'CA is installed and should be' {
                $Result = Test-TargetResource @TestParametersPresent

                It 'should return true' {
                    $Result | Should be $True
                }
                It 'should call expected mocks' {
                    Assert-VerifiableMocks
                    Assert-MockCalled `
                        -CommandName Install-AdcsCertificationAuthority `
                        -Exactly 1
                }
            }

            Context 'CA is installed but should not be' {
                $Result = Test-TargetResource @TestParametersAbsent

                It 'should return false' {
                    $Result | Should be $False
                }
                It 'should call expected mocks' {
                    Assert-VerifiableMocks
                    Assert-MockCalled `
                        -CommandName Install-AdcsCertificationAuthority `
                        -Exactly 1
                }
            }

            #region Mocks
            Mock -CommandName Install-AdcsCertificationAuthority `
                -Verifiable
            #endregion

            Context 'CA is not installed but should be' {
                $Result = Test-TargetResource @TestParametersPresent

                It 'should return false' {
                    $Result | Should be $false
                }
                It 'should call expected mocks' {
                    Assert-VerifiableMocks
                    Assert-MockCalled `
                        -CommandName Install-AdcsCertificationAuthority `
                        -Exactly 1
                }
            }

            Context 'CA is not installed and should not be' {
                $Result = Test-TargetResource @TestParametersAbsent

                It 'should return true' {
                    $Result | Should be $True
                }
                It 'should call expected mocks' {
                    Assert-VerifiableMocks
                    Assert-MockCalled `
                        -CommandName Install-AdcsCertificationAuthority `
                        -Exactly 1
                }
            }
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

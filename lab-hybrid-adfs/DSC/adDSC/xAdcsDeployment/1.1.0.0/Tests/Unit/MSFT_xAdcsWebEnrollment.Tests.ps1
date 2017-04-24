$script:DSCModuleName   = 'xAdcsDeployment'
$script:DSCResourceName = 'MSFT_xAdcsWebEnrollment'

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
    InModuleScope $script:DSCResourceName {
        if (-not ([System.Management.Automation.PSTypeName]'Microsoft.CertificateServices.Deployment.Common.WEP.WebEnrollmentSetupException').Type)
        {
            # Define the exception class:
            # Microsoft.CertificateServices.Deployment.Common.WEP.WebEnrollmentSetupException
            # so that unit tests can be run without ADCS being installed.

            $ExceptionDefinition = @'
namespace Microsoft.CertificateServices.Deployment.Common.WEP {
    public class WebEnrollmentSetupException: System.Exception {
    }
}
'@
            Add-Type -TypeDefinition $ExceptionDefinition
        }

        $DSCResourceName = 'MSFT_xAdcsWebEnrollment'

        $DummyCredential = New-Object System.Management.Automation.PSCredential ("Administrator",(New-Object -Type SecureString))

        $TestParametersPresent = @{
            IsSingleInstance = 'Yes'
            Ensure           = 'Present'
            CAConfig         = 'CAConfig'
            Credential       = $DummyCredential
            Verbose          = $true
        }

        $TestParametersAbsent = @{
            IsSingleInstance = 'Yes'
            Ensure           = 'Absent'
            Credential       = $DummyCredential
            Verbose          = $true
        }

        Describe "$DSCResourceName\Get-TargetResource" {

            function Install-AdcsWebEnrollment {
                [CmdletBinding()]
                param(
                    [String] $CAConfig,

                    [PSCredential] $Credential,

                    [Switch] $Force,

                    [Switch] $WhatIf
                )
            }

            #region Mocks
            Mock `
                -CommandName Install-AdcsWebEnrollment `
                -MockWith { Throw (New-Object -TypeName 'Microsoft.CertificateServices.Deployment.Common.WEP.WebEnrollmentSetupException') } `
                -Verifiable
            #endregion

            Context 'Web Enrollment is installed' {
                $Result = Get-TargetResource @TestParametersPresent

                It 'should return Ensure set to Present' {
                    $Result.Ensure  | Should Be 'Present'
                }

                It 'should call expected mocks' {
                    Assert-VerifiableMocks
                    Assert-MockCalled `
                        -CommandName Install-AdcsWebEnrollment `
                        -Exactly 1
                }
            }

            #region Mocks
            Mock `
                -CommandName Install-AdcsWebEnrollment
            #endregion

            Context 'Web Enrollment is not installed' {
                $Result = Get-TargetResource @TestParametersPresent

                It 'should return Ensure set to Absent' {
                    $Result.Ensure  | Should Be 'Absent'
                }

                It 'should call expected mocks' {
                    Assert-MockCalled `
                        -CommandName Install-AdcsWebEnrollment `
                        -Exactly 1
                }
            }
        }

        Describe "$DSCResourceName\Set-TargetResource" {

            function Install-AdcsWebEnrollment {
                [CmdletBinding()]
                param(
                    [String] $CAConfig,

                    [PSCredential] $Credential,

                    [Switch] $Force,

                    [Switch] $WhatIf
                )
            }
            function Uninstall-AdcsWebEnrollment {
                [CmdletBinding()]
                param(
                    [Switch] $Force
                )
            }

            #region Mocks
            Mock -CommandName Install-AdcsWebEnrollment
            Mock -CommandName Uninstall-AdcsWebEnrollment
            #endregion

            Context 'Web Enrollment is not installed but should be' {
                Set-TargetResource @TestParametersPresent

                It 'should call expected mocks' {
                    Assert-MockCalled `
                        -CommandName Install-AdcsWebEnrollment `
                        -Exactly 1
                    Assert-MockCalled `
                        -CommandName Uninstall-AdcsWebEnrollment `
                        -Exactly 0
                }
            }

            Context 'Web Enrollment is installed but should not be' {
                Set-TargetResource @TestParametersAbsent

                It 'should call expected mocks' {
                    Assert-MockCalled `
                        -CommandName Install-AdcsWebEnrollment `
                        -Exactly 0
                    Assert-MockCalled `
                        -CommandName Uninstall-AdcsWebEnrollment `
                        -Exactly 1
                }
            }
        }

        Describe "$DSCResourceName\Test-TargetResource" {

            function Install-AdcsWebEnrollment {
                [CmdletBinding()]
                param(
                    [String] $CAConfig,

                    [PSCredential] $Credential,

                    [Switch] $Force,

                    [Switch] $WhatIf
                )
            }

            #region Mocks
            Mock -CommandName Install-AdcsWebEnrollment `
                -MockWith { Throw (New-Object -TypeName 'Microsoft.CertificateServices.Deployment.Common.WEP.WebEnrollmentSetupException') } `
                -Verifiable
            #endregion

            Context 'Web Enrollment is installed and should be' {
                $Result = Test-TargetResource @TestParametersPresent

                It 'should return true' {
                    $Result | Should be $True
                }
                It 'should call expected mocks' {
                    Assert-VerifiableMocks
                    Assert-MockCalled `
                        -CommandName Install-AdcsWebEnrollment `
                        -Exactly 1
                }
            }

            Context 'Web Enrollment is installed but should not be' {
                $Result = Test-TargetResource @TestParametersAbsent

                It 'should return false' {
                    $Result | Should be $False
                }
                It 'should call expected mocks' {
                    Assert-VerifiableMocks
                    Assert-MockCalled `
                        -CommandName Install-AdcsWebEnrollment `
                        -Exactly 1
                }
            }

            #region Mocks
            Mock -CommandName Install-AdcsWebEnrollment `
                -Verifiable
            #endregion

            Context 'Web Enrollment is not installed but should be' {
                $Result = Test-TargetResource @TestParametersPresent

                It 'should return false' {
                    $Result | Should be $false
                }
                It 'should call expected mocks' {
                    Assert-VerifiableMocks
                    Assert-MockCalled `
                        -CommandName Install-AdcsWebEnrollment `
                        -Exactly 1
                }
            }

            Context 'Web Enrollment is not installed and should not be' {
                $Result = Test-TargetResource @TestParametersAbsent

                It 'should return true' {
                    $Result | Should be $True
                }
                It 'should call expected mocks' {
                    Assert-VerifiableMocks
                    Assert-MockCalled `
                        -CommandName Install-AdcsWebEnrollment `
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

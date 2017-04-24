$script:DSCModuleName   = 'xAdcsDeployment'
$script:DSCResourceName = 'MSFT_xAdcsOnlineResponder'

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
        if (-not ([System.Management.Automation.PSTypeName]'Microsoft.CertificateServices.Deployment.Common.OCSP.OnlineResponderSetupException').Type)
        {
            # Define the exception class:
            # Microsoft.CertificateServices.Deployment.Common.OCSP.OnlineResponderSetupException
            # so that unit tests can be run without ADCS being installed.

            $ExceptionDefinition = @'
namespace Microsoft.CertificateServices.Deployment.Common.OCSP {
    public class OnlineResponderSetupException: System.Exception {
    }
}
'@
            Add-Type -TypeDefinition $ExceptionDefinition
        }

        $DSCResourceName = 'MSFT_xAdcsOnlineResponder'

        $DummyCredential = New-Object System.Management.Automation.PSCredential ("Administrator",(New-Object -Type SecureString))

        $TestParametersPresent = @{
            IsSingleInstance = 'Yes'
            Ensure           = 'Present'
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

            function Install-AdcsOnlineResponder {
                [CmdletBinding()]
                param(
                    [PSCredential] $Credential,

                    [Switch] $Force,

                    [Switch] $WhatIf
                )
            }

            #region Mocks
            Mock `
                -CommandName Install-AdcsOnlineResponder `
                -MockWith { Throw (New-Object -TypeName 'Microsoft.CertificateServices.Deployment.Common.OCSP.OnlineResponderSetupException') } `
                -Verifiable
            #endregion

            Context 'Online Responder is installed' {
                $Result = Get-TargetResource @TestParametersPresent

                It 'should return Ensure set to Present' {
                    $Result.Ensure  | Should Be 'Present'
                }

                It 'should call expected mocks' {
                    Assert-VerifiableMocks
                    Assert-MockCalled `
                        -CommandName Install-AdcsOnlineResponder `
                        -Exactly 1
                }
            }

            #region Mocks
            Mock `
                -CommandName Install-AdcsOnlineResponder
            #endregion

            Context 'Online Responder is not installed' {
                $Result = Get-TargetResource @TestParametersPresent

                It 'should return Ensure set to Absent' {
                    $Result.Ensure  | Should Be 'Absent'
                }

                It 'should call expected mocks' {
                    Assert-MockCalled `
                        -CommandName Install-AdcsOnlineResponder `
                        -Exactly 1
                }
            }
        }

        Describe "$DSCResourceName\Set-TargetResource" {

            function Install-AdcsOnlineResponder {
                [CmdletBinding()]
                param(
                    [PSCredential] $Credential,

                    [Switch] $Force,

                    [Switch] $WhatIf
                )
            }
            function Uninstall-AdcsOnlineResponder {
                [CmdletBinding()]
                param(
                    [Switch] $Force
                )
            }

            #region Mocks
            Mock -CommandName Install-AdcsOnlineResponder
            Mock -CommandName Uninstall-AdcsOnlineResponder
            #endregion

            Context 'Online Responder is not installed but should be' {
                Set-TargetResource @TestParametersPresent

                It 'should call expected mocks' {
                    Assert-MockCalled `
                        -CommandName Install-AdcsOnlineResponder `
                        -Exactly 1
                    Assert-MockCalled `
                        -CommandName Uninstall-AdcsOnlineResponder `
                        -Exactly 0
                }
            }

            Context 'Online Responder is installed but should not be' {
                Set-TargetResource @TestParametersAbsent

                It 'should call expected mocks' {
                    Assert-MockCalled `
                        -CommandName Install-AdcsOnlineResponder `
                        -Exactly 0
                    Assert-MockCalled `
                        -CommandName Uninstall-AdcsOnlineResponder `
                        -Exactly 1
                }
            }
        }

        Describe "$DSCResourceName\Test-TargetResource" {

            function Install-AdcsOnlineResponder {
                [CmdletBinding()]
                param(
                    [PSCredential] $Credential,

                    [Switch] $Force,

                    [Switch] $WhatIf
                )
            }

            #region Mocks
            Mock -CommandName Install-AdcsOnlineResponder `
                -MockWith { Throw (New-Object -TypeName 'Microsoft.CertificateServices.Deployment.Common.OCSP.OnlineResponderSetupException') } `
                -Verifiable
            #endregion

            Context 'Online Responder is installed and should be' {
                $Result = Test-TargetResource @TestParametersPresent

                It 'should return true' {
                    $Result | Should be $True
                }
                It 'should call expected mocks' {
                    Assert-VerifiableMocks
                    Assert-MockCalled `
                        -CommandName Install-AdcsOnlineResponder `
                        -Exactly 1
                }
            }

            Context 'Online Responder is installed but should not be' {
                $Result = Test-TargetResource @TestParametersAbsent

                It 'should return false' {
                    $Result | Should be $False
                }
                It 'should call expected mocks' {
                    Assert-VerifiableMocks
                    Assert-MockCalled `
                        -CommandName Install-AdcsOnlineResponder `
                        -Exactly 1
                }
            }

            #region Mocks
            Mock -CommandName Install-AdcsOnlineResponder `
                -Verifiable
            #endregion

            Context 'Online Responder is not installed but should be' {
                $Result = Test-TargetResource @TestParametersPresent

                It 'should return false' {
                    $Result | Should be $false
                }
                It 'should call expected mocks' {
                    Assert-VerifiableMocks
                    Assert-MockCalled `
                        -CommandName Install-AdcsOnlineResponder `
                        -Exactly 1
                }
            }

            Context 'Online Responder is not installed and should not be' {
                $Result = Test-TargetResource @TestParametersAbsent

                It 'should return true' {
                    $Result | Should be $True
                }
                It 'should call expected mocks' {
                    Assert-VerifiableMocks
                    Assert-MockCalled `
                        -CommandName Install-AdcsOnlineResponder `
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

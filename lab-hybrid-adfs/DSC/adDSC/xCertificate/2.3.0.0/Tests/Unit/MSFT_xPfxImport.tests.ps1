[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '')]
param ()

$script:DSCModuleName      = 'xCertificate'
$script:DSCResourceName    = 'MSFT_xPfxImport'

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
    -TestType Unit
#endregion

# Begin Testing
try
{
    InModuleScope $script:DSCResourceName {
        $DSCResourceName = 'MSFT_xPfxImport'
        $validThumbprint = (
            [System.AppDomain]::CurrentDomain.GetAssemblies().GetTypes() | Where-Object {
                $_.BaseType.BaseType -eq [System.Security.Cryptography.HashAlgorithm] -and
                ($_.Name -cmatch 'Managed$' -or $_.Name -cmatch 'Provider$')
            } | Select-Object -First 1 | ForEach-Object {
                (New-Object $_).ComputeHash([String]::Empty) | ForEach-Object {
                    '{0:x2}' -f $_
                }
            }
        ) -join ''

        $testFile = 'test.pfx'

        $testUsername = 'DummyUsername'
        $testPassword = 'DummyPassword'
        $testCredential = New-Object System.Management.Automation.PSCredential $testUsername, (ConvertTo-SecureString $testPassword -AsPlainText -Force)

        $validPath = "TestDrive:\$testFile"
        $validCertPath = "Cert:\LocalMachine\My"

        $PresentParams = @{
            Thumbprint = $validThumbprint
            Path       = $validPath
            Ensure     = 'Present'
            Location   = 'LocalMachine'
            Store      = 'My'
            Exportable = $True
            Credential = $testCredential
        }

        $AbsentParams = @{
            Thumbprint = $validThumbprint
            Path       = $validPath
            Ensure     = 'Absent'
            Location   = 'LocalMachine'
            Store      = 'My'
        }

        Describe "$DSCResourceName\Get-TargetResource" {
            $null | Set-Content -Path $validPath

            $result = Get-TargetResource @PresentParams
            It 'should return a hashtable' {
                ($result -is [hashtable]) | Should Be $true
            }
            It 'should contain the input values' {
                $result.Thumbprint | Should BeExactly $validThumbprint
                $result.Path | Should BeExactly $validPath
            }
        }
        Describe "$DSCResourceName\Test-TargetResource" {
            $null | Set-Content -Path $validPath

            It 'should return a bool' {
                Test-TargetResource @PresentParams | Should BeOfType Boolean
            }
            It 'returns false when valid path + thumbprint and certificate is not in store but should be' {
                Mock Get-TargetResource {
                    return @{
                        Thumbprint = $validThumbprint
                        Path       = $validPath
                        Ensure     = 'Absent'
                    }
                }
                Test-TargetResource @PresentParams | Should Be $false
            }
            It 'returns true when valid path + thumbprint and PFX is not in store and should not be' {
                Mock Get-TargetResource {
                    return @{
                        Thumbprint = $validThumbprint
                        Path       = $validPath
                        Ensure     = 'Absent'
                    }
                }
                Test-TargetResource @AbsentParams | Should Be $true
            }
            It 'returns true when valid path + thumbprint and PFX is in store and should be' {
                Mock Get-TargetResource {
                    return @{
                        Thumbprint = $validThumbprint
                        Path       = $validPath
                        Ensure     = 'Present'
                    }
                }
                Test-TargetResource @PresentParams | Should Be $true
            }
            It 'returns false when valid path + thumbprint and PFX is in store but should not be' {
                Mock Get-TargetResource {
                    return @{
                        Thumbprint = $validThumbprint
                        Path       = $validPath
                        Ensure     = 'Present'
                    }
                }
                Test-TargetResource @AbsentParams | Should Be $false
            }
        }
        Describe "$DSCResourceName\Set-TargetResource" {
            $null | Set-Content -Path $validPath

            Mock Import-PfxCertificate
            Mock Get-ChildItem
            Mock Remove-Item

            Context "Valid path + thumbprint and Ensure is Present" {
                Set-TargetResource @PresentParams

                It 'calls Import-PfxCertificate with the parameters supplied' {
                    Assert-MockCalled Import-PfxCertificate -Exactly 1 -ParameterFilter {
                        $CertStoreLocation -eq $validCertPath -and `
                        $FilePath -eq $validPath -and `
                        $Exportable -eq $True -and `
                        $Password -eq $testCredential.Password
                    }
                }
                It 'does not call Get-ChildItem' {
                    Assert-MockCalled Get-ChildItem -Exactly 0
                }
                It 'does not call Remove-Item' {
                    Assert-MockCalled Remove-Item -Exactly 0
                }
            }

            Mock Get-ChildItem -MockWith { Get-Item -Path $validPath }
            Mock Where-Object -MockWith { Get-Item -Path $validPath }
            Mock Remove-Item

            Context "Valid path + thumbprint and Ensure is Absent" {
                Set-TargetResource @AbsentParams

                It 'does not call Import-PfxCertificate' {
                    Assert-MockCalled Import-PfxCertificate -Exactly 0
                }
                It 'calls Get-ChildItem' {
                    Assert-MockCalled Get-ChildItem -Exactly 1
                }
                It 'calls Remove-Item' {
                    Assert-MockCalled Remove-Item -Exactly 1
                }
            }

        }
    }
}
finally
{
    #region FOOTER
    Restore-TestEnvironment -TestEnvironment $TestEnvironment
    #endregion
}

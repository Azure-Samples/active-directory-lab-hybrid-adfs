[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '')]
param ()

$script:DSCModuleName      = 'xCertificate'
$script:DSCResourceName    = 'MSFT_xCertReq'

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
        $DSCResourceName = 'MSFT_xCertReq'
        function Get-InvalidOperationError
        {
            [CmdletBinding()]
            param
            (
                [Parameter(Mandatory)]
                [ValidateNotNullOrEmpty()]
                [System.String]
                $ErrorId,

                [Parameter(Mandatory)]
                [ValidateNotNullOrEmpty()]
                [System.String]
                $ErrorMessage
            )

            $exception = New-Object -TypeName System.InvalidOperationException `
                -ArgumentList $ErrorMessage
            $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidOperation
            $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                -ArgumentList $exception, $ErrorId, $errorCategory, $null
            return $errorRecord
        } # end function Get-InvalidOperationError

        function Get-InvalidArgumentError
        {
            [CmdletBinding()]
            param
            (
                [Parameter(Mandatory)]
                [ValidateNotNullOrEmpty()]
                [System.String]
                $ErrorId,

                [Parameter(Mandatory)]
                [ValidateNotNullOrEmpty()]
                [System.String]
                $ErrorMessage
            )

            $exception = New-Object -TypeName System.ArgumentException `
                -ArgumentList $ErrorMessage
            $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
            $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                -ArgumentList $exception, $ErrorId, $errorCategory, $null
            return $errorRecord
        } # end function Get-InvalidArgumentError

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
        $CAServerFQDN          = 'rootca.contoso.com'
        $CARootName            = 'contoso-CA'
        $validSubject          = 'Test Subject'
        $validIssuer           = "CN=$CARootName, DC=contoso, DC=com"
        $KeyLength             = '1024'
        $Exportable            = $true
        $ProviderName          = '"Microsoft RSA SChannel Cryptographic Provider"'
        $OID                   = '1.3.6.1.5.5.7.3.1'
        $KeyUsage              = '0xa0'
        $CertificateTemplate   = 'WebServer'
        $SubjectAltName        = 'dns=contoso.com'

        $validCert      = New-Object -TypeName PSObject -Property @{
            Thumbprint  = $validThumbprint
            Subject     = "CN=$validSubject"
            Issuer      = $validIssuer
            NotBefore   = (Get-Date).AddDays(-30) # Issued on
            NotAfter    = (Get-Date).AddDays(31) # Expires after
        }
        Add-Member -InputObject $validCert -MemberType ScriptMethod -Name Verify -Value {
            return $true
        }
        $expiringCert   = New-Object -TypeName PSObject -Property @{
            Thumbprint  = $validThumbprint
            Subject     = "CN=$validSubject"
            Issuer      = $validIssuer
            NotBefore   = (Get-Date).AddDays(-30) # Issued on
            NotAfter    = (Get-Date).AddDays(30) # Expires after
        }
        Add-Member -InputObject $expiringCert -MemberType ScriptMethod -Name Verify -Value {
            return $true
        }
        $expiredCert    = New-Object -TypeName PSObject -Property @{
            Thumbprint  = $validThumbprint
            Subject     = "CN=$validSubject"
            Issuer      = $validIssuer
            NotBefore   = (Get-Date).AddDays(-30) # Issued on
            NotAfter    = (Get-Date).AddDays(-1) # Expires after
        }
        Add-Member -InputObject $expiredCert -MemberType ScriptMethod -Name Verify -Value {
            return $true
        }

        $testUsername   = 'DummyUsername'
        $testPassword   = 'DummyPassword'
        $testCredential = New-Object System.Management.Automation.PSCredential $testUsername, (ConvertTo-SecureString $testPassword -AsPlainText -Force)
        $Params = @{
            Subject               = $validSubject
            CAServerFQDN          = $CAServerFQDN
            CARootName            = $CARootName
            KeyLength             = $KeyLength
            Exportable            = $Exportable
            ProviderName          = $ProviderName
            OID                   = $OID
            KeyUsage              = $KeyUsage
            CertificateTemplate   = $CertificateTemplate
            Credential            = $testCredential
            AutoRenew             = $False
        }
        $ParamsAutoRenew = @{
            Subject               = $validSubject
            CAServerFQDN          = $CAServerFQDN
            CARootName            = $CARootName
            KeyLength             = $KeyLength
            Exportable            = $Exportable
            ProviderName          = $ProviderName
            OID                   = $OID
            KeyUsage              = $KeyUsage
            CertificateTemplate   = $CertificateTemplate
            Credential            = $testCredential
            AutoRenew             = $True
        }
        $ParamsNoCred = @{
            Subject               = $validSubject
            CAServerFQDN          = $CAServerFQDN
            CARootName            = $CARootName
            KeyLength             = $KeyLength
            Exportable            = $Exportable
            ProviderName          = $ProviderName
            OID                   = $OID
            KeyUsage              = $KeyUsage
            CertificateTemplate   = $CertificateTemplate
            Credential            = $null
            AutoRenew             = $False
        }
        $ParamsAutoRenewNoCred = @{
            Subject               = $validSubject
            CAServerFQDN          = $CAServerFQDN
            CARootName            = $CARootName
            KeyLength             = $KeyLength
            Exportable            = $Exportable
            ProviderName          = $ProviderName
            OID                   = $OID
            KeyUsage              = $KeyUsage
            CertificateTemplate   = $CertificateTemplate
            Credential            = $null
            AutoRenew             = $True
        }
        $ParamsKeyLength4096NoCred = @{
            Subject               = $validSubject
            CAServerFQDN          = $CAServerFQDN
            CARootName            = $CARootName
            KeyLength             = '4096'
            Exportable            = $Exportable
            ProviderName          = $ProviderName
            OID                   = $OID
            KeyUsage              = $KeyUsage
            CertificateTemplate   = $CertificateTemplate
            Credential            = $null
            AutoRenew             = $False
        }
        $ParamsKeyLength4096AutoRenewNoCred = @{
            Subject               = $validSubject
            CAServerFQDN          = $CAServerFQDN
            CARootName            = $CARootName
            KeyLength             = '4096'
            Exportable            = $Exportable
            ProviderName          = $ProviderName
            OID                   = $OID
            KeyUsage              = $KeyUsage
            CertificateTemplate   = $CertificateTemplate
            Credential            = $null
            AutoRenew             = $True
        }
        $ParamsSubjectAltNameNoCred = @{
            Subject               = $validSubject
            CAServerFQDN          = $CAServerFQDN
            CARootName            = $CARootName
            KeyLength             = $KeyLength
            Exportable            = $Exportable
            ProviderName          = $ProviderName
            OID                   = $OID
            KeyUsage              = $KeyUsage
            CertificateTemplate   = $CertificateTemplate
            Credential            = $null
            SubjectAltName        = $SubjectAltName
            AutoRenew             = $False
        }

        $CertInf = @"
[NewRequest]
Subject = "CN=$validSubject"
KeySpec = 1
KeyLength = $KeyLength
Exportable = $($Exportable.ToString().ToUpper())
MachineKeySet = TRUE
SMIME = FALSE
PrivateKeyArchive = FALSE
UserProtected = FALSE
UseExistingKeySet = FALSE
ProviderName = $ProviderName
ProviderType = 12
RequestType = CMC
KeyUsage = $KeyUsage
[RequestAttributes]
CertificateTemplate = $CertificateTemplate
[EnhancedKeyUsageExtension]
OID = $OID
"@

        $CertInfKey = $CertInf -Replace 'KeyLength = ([0-z]*)', 'KeyLength = 4096'
        $CertInfRenew = $Certinf
        $CertInfRenew += @"

RenewalCert = $validThumbprint
"@
        $CertInfKeyRenew = $CertInfRenew -Replace 'KeyLength = ([0-z]*)', 'KeyLength = 4096'
        $CertInfSubjectAltName = $Certinf
        $CertInfSubjectAltName += @"

[Extensions]
2.5.29.17 = "{text}$SubjectAltName"
"@

        Describe "$DSCResourceName\Get-TargetResource" {
            Mock Get-ChildItem -ParameterFilter { $Path -eq 'Cert:\LocalMachine\My' } `
                -Mockwith { $validCert }
            $result = Get-TargetResource @Params
            It 'should return a hashtable' {
                ($result -is [hashtable]) | Should Be $true
            }
            It 'should contain the input values' {
                $result.Subject              | Should BeExactly $validSubject
                $result.CAServerFQDN         | Should BeNullOrEmpty
                $result.CARootName           | Should BeExactly $CARootName
                $result.KeyLength            | Should BeNullOrEmpty
                $result.Exportable           | Should BeNullOrEmpty
                $result.ProviderName         | Should BeNullOrEmpty
                $result.OID                  | Should BeNullOrEmpty
                $result.KeyUsage             | Should BeNullOrEmpty
                $result.CertificateTemplate  | Should BeNullOrEmpty
                $result.SubjectAltName       | Should BeNullOrEmpty
            }
        }
        #endregion

        #region Set-TargetResource
        Describe "$DSCResourceName\Set-TargetResource" {
            Mock -CommandName Join-Path -MockWith { 'xCertReq-Test' } `
                -ParameterFilter { $Path -eq $ENV:Temp }
            Mock -CommandName Test-Path -MockWith { $true } `
                -ParameterFilter { $Path -eq 'xCertReq-Test.req' }
            Mock -CommandName Test-Path -MockWith { $true } `
                -ParameterFilter { $Path -eq 'xCertReq-Test.cer' }
            Mock -CommandName CertReq.exe
            Mock -CommandName Set-Content `
                -ParameterFilter {
                    $Path -eq 'xCertReq-Test.inf' -and `
                    $Value -eq $CertInf
                }

            Context 'autorenew is false, credentials not passed' {
                Mock -CommandName Get-ChildItem -Mockwith { } `
                    -ParameterFilter { $Path -eq 'Cert:\LocalMachine\My' }

                It 'should not throw' {
                    { Set-TargetResource @ParamsNoCred } | Should Not Throw
                }

                It 'should call expected mocks' {
                    Assert-MockCalled -CommandName Join-Path -Exactly 1
                    Assert-MockCalled -CommandName Test-Path -Exactly 1 `
                        -ParameterFilter { $Path -eq 'xCertReq-Test.req' }
                    Assert-MockCalled -CommandName Test-Path  -Exactly 1 `
                        -ParameterFilter { $Path -eq 'xCertReq-Test.cer' }
                    Assert-MockCalled -CommandName Set-Content -Exactly 1 `
                        -ParameterFilter {
                            $Path -eq 'xCertReq-Test.inf' -and `
                            $Value -eq $CertInf
                        }
                    Assert-MockCalled -CommandName CertReq.exe -Exactly 3
                }
            }

            Context 'autorenew is true, credentials not passed and certificate does not exist' {
                Mock -CommandName Get-ChildItem -Mockwith { } `
                    -ParameterFilter { $Path -eq 'Cert:\LocalMachine\My' }

                It 'should not throw' {
                    { Set-TargetResource @ParamsAutoRenewNoCred } | Should Not Throw
                }

                It 'should call expected mocks' {
                    Assert-MockCalled -CommandName Join-Path -Exactly 1
                    Assert-MockCalled -CommandName Test-Path -Exactly 1 `
                        -ParameterFilter { $Path -eq 'xCertReq-Test.req' }
                    Assert-MockCalled -CommandName Test-Path  -Exactly 1 `
                        -ParameterFilter { $Path -eq 'xCertReq-Test.cer' }
                    Assert-MockCalled -CommandName Get-ChildItem -Exactly 1 `
                        -ParameterFilter { $Path -eq 'Cert:\LocalMachine\My' }
                    Assert-MockCalled -CommandName Set-Content -Exactly 1 `
                        -ParameterFilter {
                            $Path -eq 'xCertReq-Test.inf' -and `
                            $Value -eq $CertInf
                        }
                    Assert-MockCalled -CommandName CertReq.exe -Exactly 3
                }
            }

            Context 'autorenew is true, credentials not passed and valid certificate exists' {
                Mock -CommandName Get-ChildItem -Mockwith { $validCert } `
                    -ParameterFilter { $Path -eq 'Cert:\LocalMachine\My' }

                It 'should not throw' {
                    { Set-TargetResource @ParamsAutoRenewNoCred } | Should Not Throw
                }
                It 'should call expected mocks' {
                    Assert-MockCalled -CommandName Join-Path -Exactly 1
                    Assert-MockCalled -CommandName Test-Path -Exactly 1 `
                        -ParameterFilter { $Path -eq 'xCertReq-Test.req' }
                    Assert-MockCalled -CommandName Test-Path  -Exactly 1 `
                        -ParameterFilter { $Path -eq 'xCertReq-Test.cer' }
                    Assert-MockCalled -CommandName Get-ChildItem -Exactly 1 `
                        -ParameterFilter { $Path -eq 'Cert:\LocalMachine\My' }
                    Assert-MockCalled -CommandName Set-Content -Exactly 1 `
                        -ParameterFilter {
                            $Path -eq 'xCertReq-Test.inf' -and `
                            $Value -eq $CertInf
                        }
                    Assert-MockCalled -CommandName CertReq.exe -Exactly 3
                }
            }

            Mock -CommandName Set-Content `
                -ParameterFilter {
                    $Path -eq 'xCertReq-Test.inf' -and `
                    $Value -eq $CertInfRenew
                }
            Context 'autorenew is true, credentials not passed and expiring certificate exists' {
                Mock -CommandName Get-ChildItem -Mockwith { $expiringCert } `
                    -ParameterFilter { $Path -eq 'Cert:\LocalMachine\My' }

                It 'should not throw' {
                    { Set-TargetResource @ParamsAutoRenewNoCred } | Should Not Throw
                }
                It 'should call expected mocks' {
                    Assert-MockCalled -CommandName Join-Path -Exactly 1
                    Assert-MockCalled -CommandName Test-Path -Exactly 1 `
                        -ParameterFilter { $Path -eq 'xCertReq-Test.req' }
                    Assert-MockCalled -CommandName Test-Path  -Exactly 1 `
                        -ParameterFilter { $Path -eq 'xCertReq-Test.cer' }
                    Assert-MockCalled -CommandName Get-ChildItem -Exactly 1 `
                        -ParameterFilter { $Path -eq 'Cert:\LocalMachine\My' }
                    Assert-MockCalled -CommandName Set-Content -Exactly 1 `
                        -ParameterFilter {
                            $Path -eq 'xCertReq-Test.inf' -and `
                            $Value -eq $CertInfRenew
                        }
                    Assert-MockCalled -CommandName CertReq.exe -Exactly 3
                }
            }

            Context 'autorenew is true, credentials not passed and expired certificate exists' {
                Mock -CommandName Get-ChildItem -Mockwith { $expiredCert } `
                    -ParameterFilter { $Path -eq 'Cert:\LocalMachine\My' }

                It 'should not throw' {
                    { Set-TargetResource @ParamsAutoRenewNoCred } | Should Not Throw
                }
                It 'should call expected mocks' {
                    Assert-MockCalled -CommandName Join-Path -Exactly 1
                    Assert-MockCalled -CommandName Test-Path -Exactly 1 `
                        -ParameterFilter { $Path -eq 'xCertReq-Test.req' }
                    Assert-MockCalled -CommandName Test-Path  -Exactly 1 `
                        -ParameterFilter { $Path -eq 'xCertReq-Test.cer' }
                    Assert-MockCalled -CommandName Get-ChildItem -Exactly 1 `
                        -ParameterFilter { $Path -eq 'Cert:\LocalMachine\My' }
                    Assert-MockCalled -CommandName Set-Content -Exactly 1 `
                        -ParameterFilter {
                            $Path -eq 'xCertReq-Test.inf' -and `
                            $Value -eq $CertInfRenew
                        }
                    Assert-MockCalled -CommandName CertReq.exe -Exactly 3
                }
            }

            Mock -CommandName Set-Content `
                -ParameterFilter {
                    $Path -eq 'xCertReq-Test.inf' -and `
                    $Value -eq $CertInfKeyRenew
                }

            Context 'autorenew is true, credentials not passed, keylength passed and expired certificate exists' {
                Mock -CommandName Get-ChildItem -Mockwith { $expiredCert } `
                    -ParameterFilter { $Path -eq 'Cert:\LocalMachine\My' }

                It 'should not throw' {
                    { Set-TargetResource @ParamsKeyLength4096AutoRenewNoCred } | Should Not Throw
                }
                It 'should call expected mocks' {
                    Assert-MockCalled -CommandName Join-Path -Exactly 1
                    Assert-MockCalled -CommandName Test-Path -Exactly 1 `
                        -ParameterFilter { $Path -eq 'xCertReq-Test.req' }
                    Assert-MockCalled -CommandName Test-Path  -Exactly 1 `
                        -ParameterFilter { $Path -eq 'xCertReq-Test.cer' }
                    Assert-MockCalled -CommandName Get-ChildItem -Exactly 1 `
                        -ParameterFilter { $Path -eq 'Cert:\LocalMachine\My' }
                    Assert-MockCalled -CommandName Set-Content -Exactly 1 `
                        -ParameterFilter { $Path -eq 'xCertReq-Test.inf' }
                    Assert-MockCalled -CommandName CertReq.exe -Exactly 3
                    Assert-MockCalled -CommandName Set-Content -Exactly 1 `
                        -ParameterFilter {
                            $Path -eq 'xCertReq-Test.inf' -and `
                            $Value -eq $CertInfKeyRenew
                        }
                }
            }

            Mock -CommandName Test-Path -MockWith { $false } `
                -ParameterFilter { $Path -eq 'xCertReq-Test.req' }
            Mock -CommandName Set-Content `
                -ParameterFilter {
                    $Path -eq 'xCertReq-Test.inf' -and `
                    $Value -eq $CertInf
                }

            Context 'autorenew is false, credentials not passed, certificate request creation failed' {
                Mock -CommandName Get-ChildItem -Mockwith { } `
                    -ParameterFilter { $Path -eq 'Cert:\LocalMachine\My' }

                $errorRecord = Get-InvalidArgumentError `
                    -ErrorId 'CertificateReqNotFoundError' `
                    -ErrorMessage ($LocalizedData.CertificateReqNotFoundError -f 'xCertReq-Test.req')

                It 'should throw CertificateReqNotFoundError exception' {
                    { Set-TargetResource @ParamsNoCred } | Should Throw $errorRecord
                }

                It 'should call expected mocks' {
                    Assert-MockCalled -CommandName Join-Path -Exactly 1
                    Assert-MockCalled -CommandName Test-Path -Exactly 1 `
                        -ParameterFilter { $Path -eq 'xCertReq-Test.req' }
                    Assert-MockCalled -CommandName Test-Path -Exactly 0 `
                        -ParameterFilter { $Path -eq 'xCertReq-Test.cer' }
                    Assert-MockCalled -CommandName Set-Content -Exactly 1 `
                        -ParameterFilter {
                            $Path -eq 'xCertReq-Test.inf' -and `
                            $Value -eq $CertInf
                        }
                    Assert-MockCalled -CommandName CertReq.exe -Exactly 1
                }
            }

            Mock -CommandName Test-Path -MockWith { $true } `
                -ParameterFilter { $Path -eq 'xCertReq-Test.req' }
            Mock -CommandName Test-Path -MockWith { $false } `
                -ParameterFilter { $Path -eq 'xCertReq-Test.cer' }

            Context 'autorenew is false, credentials not passed, certificate creation failed' {
                Mock -CommandName Get-ChildItem -Mockwith { } `
                    -ParameterFilter { $Path -eq 'Cert:\LocalMachine\My' }

                $errorRecord = Get-InvalidArgumentError `
                    -ErrorId 'CertificateCerNotFoundError' `
                    -ErrorMessage ($LocalizedData.CertificateCerNotFoundError -f 'xCertReq-Test.cer')

                It 'should throw CertificateCerNotFoundError exception' {
                    { Set-TargetResource @ParamsNoCred } | Should Throw $errorRecord
                }

                It 'should call expected mocks' {
                    Assert-MockCalled -CommandName Join-Path -Exactly 1
                    Assert-MockCalled -CommandName Test-Path -Exactly 1 `
                        -ParameterFilter { $Path -eq 'xCertReq-Test.req' }
                    Assert-MockCalled -CommandName Test-Path -Exactly 1 `
                        -ParameterFilter { $Path -eq 'xCertReq-Test.cer' }
                    Assert-MockCalled -CommandName Set-Content -Exactly 1 `
                        -ParameterFilter {
                            $Path -eq 'xCertReq-Test.inf' -and `
                            $Value -eq $CertInf
                        }
                    Assert-MockCalled -CommandName CertReq.exe -Exactly 2
                }
            }

            Mock -CommandName Test-Path -MockWith { $true } `
                -ParameterFilter { $Path -eq 'xCertReq-Test.req' }
            Mock -CommandName Test-Path -MockWith { $true } `
                -ParameterFilter { $Path -eq 'xCertReq-Test.cer' }
            Mock -CommandName Test-Path -MockWith { $true } `
                -ParameterFilter { $Path -eq 'xCertReq-Test.out' }

            Context 'autorenew is false, credentials passed' {
                Mock -CommandName Get-ChildItem -Mockwith { } `
                    -ParameterFilter { $Path -eq 'Cert:\LocalMachine\My' }
                Mock -CommandName Get-Content -Mockwith { 'Output' } `
                    -ParameterFilter { $Path -eq 'xCertReq-Test.out' }
                Mock -CommandName Remove-Item `
                    -ParameterFilter { $Path -eq 'xCertReq-Test.out' }
                Mock -CommandName Import-Module

                function Start-Win32Process { param ( $Path,$Arguments,$Credential ) }
                function Wait-Win32ProcessEnd { param ( $Path,$Arguments,$Credential ) }

                Mock -CommandName Start-Win32Process -ModuleName MSFT_xCertReq
                Mock -CommandName Wait-Win32ProcessEnd -ModuleName MSFT_xCertReq

                It 'should not throw' {
                    { Set-TargetResource @Params } | Should Not Throw
                }

                It 'should call expected mocks' {
                    Assert-MockCalled -CommandName Join-Path -Exactly 1
                    Assert-MockCalled -CommandName Test-Path -Exactly 1 `
                        -ParameterFilter { $Path -eq 'xCertReq-Test.req' }
                    Assert-MockCalled -CommandName Test-Path  -Exactly 1 `
                        -ParameterFilter { $Path -eq 'xCertReq-Test.cer' }
                    Assert-MockCalled -CommandName Set-Content -Exactly 1 `
                        -ParameterFilter {
                            $Path -eq 'xCertReq-Test.inf' -and `
                            $Value -eq $CertInf
                        }
                    Assert-MockCalled -CommandName CertReq.exe -Exactly 2
                    Assert-MockCalled -CommandName Start-Win32Process -ModuleName MSFT_xCertReq -Exactly 1
                    Assert-MockCalled -CommandName Wait-Win32ProcessEnd -ModuleName MSFT_xCertReq -Exactly 1
                    Assert-MockCalled -CommandName Test-Path  -Exactly 1 `
                        -ParameterFilter { $Path -eq 'xCertReq-Test.out' }
                    Assert-MockCalled -CommandName Get-Content -Exactly 1 `
                        -ParameterFilter { $Path -eq 'xCertReq-Test.out' }
                    Assert-MockCalled -CommandName Remove-Item -Exactly 1 `
                        -ParameterFilter { $Path -eq 'xCertReq-Test.out' }
                }
            }

            Mock -CommandName Set-Content `
                -ParameterFilter {
                    $Path -eq 'xCertReq-Test.inf' -and `
                    $Value -eq $CertInfSubjectAltName
                }

            Context 'autorenew is false, subject alt name passed, credentials not passed' {
                Mock -CommandName Get-ChildItem -Mockwith { } `
                    -ParameterFilter { $Path -eq 'Cert:\LocalMachine\My' }

                It 'should not throw' {
                    { Set-TargetResource @ParamsSubjectAltNameNoCred } | Should Not Throw
                }

                It 'should call expected mocks' {
                    Assert-MockCalled -CommandName Join-Path -Exactly 1
                    Assert-MockCalled -CommandName Test-Path -Exactly 1 `
                        -ParameterFilter { $Path -eq 'xCertReq-Test.req' }
                    Assert-MockCalled -CommandName Test-Path  -Exactly 1 `
                        -ParameterFilter { $Path -eq 'xCertReq-Test.cer' }
                    Assert-MockCalled -CommandName Set-Content -Exactly 1 `
                        -ParameterFilter {
                            $Path -eq 'xCertReq-Test.inf' -and `
                            $Value -eq $CertInfSubjectAltName
                        }
                    Assert-MockCalled -CommandName CertReq.exe -Exactly 3
                }
            }
        }
        #endregion

        Describe "$DSCResourceName\Test-TargetResource" {
            It 'should return a bool' {
                Test-TargetResource @Params | Should BeOfType Boolean
            }
            It 'should return false when a valid certificate does not exist' {
                Mock Get-ChildItem -ParameterFilter { $Path -eq 'Cert:\LocalMachine\My' } `
                    -Mockwith { }
                Test-TargetResource @Params | Should Be $false
            }
            It 'should return true when a valid certificate already exists and is not about to expire' {
                Mock Get-ChildItem -ParameterFilter { $Path -eq 'Cert:\LocalMachine\My' } `
                    -Mockwith { $validCert }
                Test-TargetResource @Params | Should Be $true
            }
            It 'should return true when a valid certificate already exists and is about to expire and autorenew set' {
                Mock Get-ChildItem -ParameterFilter { $Path -eq 'Cert:\LocalMachine\My' } `
                    -Mockwith { $expiringCert }
                Test-TargetResource @ParamsAutoRenew | Should Be $true
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

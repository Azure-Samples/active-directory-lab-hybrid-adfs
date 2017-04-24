# Suppressed as per PSSA Rule Severity guidelines for unit/integration tests:
# https://github.com/PowerShell/DscResources/blob/master/PSSARuleSeverities.md
[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
param ()

Import-Module -Name (Join-Path -Path (Split-Path $PSScriptRoot -Parent) `
    -ChildPath 'CommonResourceHelper.psm1')

# Localized messages for Write-Verbose statements in this resource
$script:localizedData = Get-LocalizedData -ResourceName 'MSFT_xAdcsWebEnrollment'

<#
    .SYNOPSIS
        Returns an object containing the current state information for the ADCS Web Enrollment.
    .PARAMETER IsSingleInstance
        Specifies the resource is a single instance, the value must be 'Yes'.
    .PARAMETER CAConfig
        CAConfig parameter string. Do not specify this if there is a local CA installed.
    .PARAMETER Credential
        If the Web Enrollment service is configured to use Standalone certification authority, then
        an account that is a member of the local Administrators on the CA is required. If the
        Web Enrollment service is configured to use an Enterprise CA, then an account that is a
        member of Domain Admins is required.
    .PARAMETER Ensure
        Specifies whether the Web Enrollment feature should be installed or uninstalled.
    .OUTPUTS
        Returns an object containing the ADCS Web Enrollment state information.
#>
Function Get-TargetResource
{
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSShouldProcess', '')]
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([System.Collections.Hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Yes')]
        [String]
        $IsSingleInstance,

        [Parameter()]
        [String]
        $CAConfig,

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential,

        [Parameter()]
        [ValidateSet('Present','Absent')]
        [String]
        $Ensure = 'Present'
    )

    Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.GettingAdcsWebEnrollmentStatusMessage)
        ) -join '' )

    $ADCSParams = @{} + $PSBoundParameters
    $null = $ADCSParams.Remove('IsSingleInstance')
    $null = $ADCSParams.Remove('Ensure')
    $null = $ADCSParams.Remove('Debug')
    $null = $ADCSParams.Remove('ErrorAction')

    try
    {
        $null = Install-AdcsWebEnrollment @ADCSParams -WhatIf
        # CA is not installed
        $Ensure = 'Absent'
    }
    catch [Microsoft.CertificateServices.Deployment.Common.WEP.WebEnrollmentSetupException]
    {
        # CA is already installed
        $Ensure = 'Present'
    }
    catch
    {
        # Something else went wrong
        Throw $_
    }

    return @{
        Ensure     = $Ensure
        CAType     = $CAType
        Credential = $Credential
    }
} # Function Get-TargetResource

<#
    .SYNOPSIS
        Installs or uinstalls the ADCS Web Enrollment from the server.
    .PARAMETER IsSingleInstance
        Specifies the resource is a single instance, the value must be 'Yes'.
    .PARAMETER CAConfig
        CAConfig parameter string. Do not specify this if there is a local CA installed.
    .PARAMETER Credential
        If the Web Enrollment service is configured to use Standalone certification authority, then
        an account that is a member of the local Administrators on the CA is required. If the
        Web Enrollment service is configured to use an Enterprise CA, then an account that is a
        member of Domain Admins is required.
    .PARAMETER Ensure
        Specifies whether the Web Enrollment feature should be installed or uninstalled.
#>
Function Set-TargetResource
{
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSShouldProcess', '')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Yes')]
        [String]
        $IsSingleInstance,

        [Parameter()]
        [String]
        $CAConfig,

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential,

        [Parameter()]
        [ValidateSet('Present','Absent')]
        [String]
        $Ensure = 'Present'
    )

    Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.SettingAdcsWebEnrollmentStatusMessage)
        ) -join '' )

    $ADCSParams = @{} + $PSBoundParameters
    $null = $ADCSParams.Remove('IsSingleInstance')
    $null = $ADCSParams.Remove('Ensure')
    $null = $ADCSParams.Remove('Debug')
    $null = $ADCSParams.Remove('ErrorAction')

    switch ($Ensure)
    {
        'Present'
        {
            Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.InstallingAdcsWebEnrollmentMessage)
                ) -join '' )

            (Install-AdcsWebEnrollment @ADCSParams -Force).ErrorString
        }
        'Absent'
        {
            Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.UninstallingAdcsWebEnrollmentMessage)
                ) -join '' )

            (Uninstall-AdcsWebEnrollment -Force).ErrorString
        }
    } # switch
} # Function Set-TargetResource

<#
    .SYNOPSIS
        Tests is the ADCS Web Enrollment is in the desired state.
    .PARAMETER IsSingleInstance
        Specifies the resource is a single instance, the value must be 'Yes'.
    .PARAMETER CAConfig
        CAConfig parameter string. Do not specify this if there is a local CA installed.
    .PARAMETER Credential
        If the Web Enrollment service is configured to use Standalone certification authority, then
        an account that is a member of the local Administrators on the CA is required. If the
        Web Enrollment service is configured to use an Enterprise CA, then an account that is a
        member of Domain Admins is required.
    .PARAMETER Ensure
        Specifies whether the Web Enrollment feature should be installed or uninstalled.
    .OUTPUTS
        Returns true if the ADCS Web Enrollment is in the desired state.
#>
Function Test-TargetResource
{
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSShouldProcess', '')]
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Yes')]
        [String]
        $IsSingleInstance,

        [Parameter()]
        [String]
        $CAConfig,

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential,

        [Parameter()]
        [ValidateSet('Present','Absent')]
        [String]
        $Ensure = 'Present'
    )


    Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.TestingAdcsWebEnrollmentStatusMessage -f $CAType)
        ) -join '' )

    $ADCSParams = @{} + $PSBoundParameters
    $null = $ADCSParams.Remove('IsSingleInstance')
    $null = $ADCSParams.Remove('Ensure')
    $null = $ADCSParams.Remove('Debug')
    $null = $ADCSParams.Remove('ErrorAction')

    try
    {
        $null = Install-AdcsWebEnrollment @ADCSParams -WhatIf
        # Web Enrollment is not installed
        switch ($Ensure)
        {
            'Present'
            {
                # Web Enrollment is not installed but should be - change required
                Write-Verbose -Message ( @(
                        "$($MyInvocation.MyCommand): "
                        $($LocalizedData.AdcsWebEnrollmentNotInstalledButShouldBeMessage)
                    ) -join '' )

                return $false
            }
            'Absent'
            {
                # Web Enrollment is not installed and should not be - change not required
                Write-Verbose -Message ( @(
                        "$($MyInvocation.MyCommand): "
                        $($LocalizedData.AdcsWebEnrollmentNotInstalledAndShouldNotBeMessage)
                    ) -join '' )

                return $true
            }
        } # switch
    }
    catch [Microsoft.CertificateServices.Deployment.Common.WEP.WebEnrollmentSetupException]
    {
        # Web Enrollment is already installed
        switch ($Ensure)
        {
            'Present'
            {
                # Web Enrollment is installed and should be - change not required
                Write-Verbose -Message ( @(
                        "$($MyInvocation.MyCommand): "
                        $($LocalizedData.AdcsWebEnrollmentInstalledAndShouldBeMessage)
                    ) -join '' )

                return $true
            }
            'Absent'
            {
                # Web Enrollment is installed and should not be - change required
                Write-Verbose -Message ( @(
                        "$($MyInvocation.MyCommand): "
                        $($LocalizedData.AdcsWebEnrollmentInstalledButShouldNotBeMessage)
                    ) -join '' )

                return $false
            }
        } # switch
    }
    catch
    {
        # Something else went wrong
        Throw $_
    } # try
} # Function Test-TargetResource

Export-ModuleMember -Function *-TargetResource

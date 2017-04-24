<#
    .SYNOPSIS
        Tests if a specific Server Feature is installed on this OS.

    .OUTPUTS
        False if this is a non-Windows Server OS.
        True if a specific Server feature is installed, otherwise False is returned.

#>
function Test-WindowsFeature
{
    [CmdletBinding()]
    [OutputType([String])]
    param
    (
        [String] $Name
    )

    # Ensure that the tests can be performed on this computer
    $ProductType = (Get-CimInstance Win32_OperatingSystem).ProductType
    if ($ProductType -ne 3)
    {
        # Unsupported OS type for testing
        Write-Verbose -Message "Integration tests cannot be run on this operating system." -Verbose
        Return $false
    }
    # Server OS
    if (-not (Get-WindowsFeature @PSBoundParameters).Installed)
    {
        Write-Verbose -Message "Integration tests cannot be run because $Name is not installed." -Verbose
        Return $false
    }
    Return $True
} # end function Test-WindowsFeature

@{
# Version number of this module.
ModuleVersion = '1.1.0.0'

# ID used to uniquely identify this module
GUID = 'f8ddd7fc-c6d6-469e-8a80-c96efabe2fcc'

# Author of this module
Author = 'Microsoft Corporation'

# Company or vendor of this module
CompanyName = 'Microsoft Corporation'

# Copyright statement for this module
Copyright = '(c) 2013 Microsoft Corporation. All rights reserved.'

# Description of the functionality provided by this module
Description = 'The xCertificateServices module can be used to install or uninstall Certificate Services components in Windows Server.  All of the resources in the DSC Resource Kit are provided AS IS, and are not supported through any Microsoft standard support program or service.'

# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = '4.0'

# Minimum version of the common language runtime (CLR) required by this module
CLRVersion = '4.0'

# Functions to export from this module
FunctionsToExport = '*'

# Cmdlets to export from this module
CmdletsToExport = '*'

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        Tags = @('DesiredStateConfiguration', 'DSC', 'DSCResourceKit', 'DSCResource')

        # A URL to the license for this module.
        LicenseUri = 'https://github.com/PowerShell/xAdcsDeployment/blob/master/LICENSE'

        # A URL to the main website for this project.
        ProjectUri = 'https://github.com/PowerShell/xAdcsDeployment'

        # A URL to an icon representing this module.
        # IconUri = ''

        # ReleaseNotes of this module
        ReleaseNotes = '- Converted AppVeyor.yml to pull Pester from PSGallery instead of Chocolatey.
- Changed AppVeyor.yml to use default image.
- xAdcsCertificateAuthority:
  - Change property format in Readme.md to be standard layout.
  - Converted style to meet HQRM guidelines.
  - Added verbose logging support.
  - Added string localization.
  - Fixed Get-TargetResource by removing IsCA and changing Ensure to return whether or not CA is installed.
  - Added unit tests.
  - Updated parameter format to meet HQRM guidelines.
- xAdcsOnlineResponder:
  - Change property format in Readme.md to be standard layout.
  - Added unit test header to be latest version.
  - Added function help.
  - Updated parameter format to meet HQRM guidelines.
  - Updated resource to meet HQRM guidelines.
- xAdcsWebEnrollment:
  - Change property format in Readme.md to be standard layout.
  - Added unit test header to be latest version.
  - Added function help.
  - Updated parameter format to meet HQRM guidelines.
  - Updated resource to meet HQRM guidelines.
- Added CommonResourceHelper.psm1 (copied from xPSDesiredStateConfiguration).
- Removed Technet Documentation HTML file from root folder.
- Removed redundant code from AppVeyor.yml.
- Fix markdown violations in Readme.md.
- Updated readme.md to match DSCResource.Template\Readme.md.

'

    } # End of PSData hashtable

} # End of PrivateData hashtable
}





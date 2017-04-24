param (
    [Parameter(Mandatory)]
    [string]$DCFQDN,

    [Parameter(Mandatory)]
    [string]$adminuser,

    [Parameter(Mandatory)]
    [string]$password,

	[Parameter(Mandatory)]
	[int]$instance,

	[Parameter(Mandatory)]
	[string]$WapFqdn
)

$ErrorActionPreference = "Stop"
$arr = $DCFQDN.split('.')
$DomainName = $arr[1]
$SecPW=ConvertTo-SecureString $password -AsPlainText -Force
$File=$null
$Subject=$null

[System.Management.Automation.PSCredential]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($adminuser)", $SecPW)

$completeFile="c:\temp\prereqsComplete"
md "c:\temp" -ErrorAction Ignore
md "c:\AADLab" -ErrorAction Ignore

if (!(Test-Path -Path "$($completeFile)0")) {
    $PathToCert="\\$DCFQDN\src"
    net use "\\$DCFQDN\src" $password /USER:$adminuser
    Copy-Item -Path "$PathToCert\*.pfx" -Destination "c:\temp\" -Recurse -Force
    Copy-Item -Path "$PathToCert\*.cer" -Destination "c:\temp\" -Recurse -Force
    #record that we got this far
    New-Item -ItemType file "$($completeFile)0"
}

if (!(Test-Path -Path "$($completeFile)1")) {
	#install root cert
    $RootFile  = Get-ChildItem -Path "c:\temp\*.cer"
    $RootPath  = $RootFile.FullName
    $rootCert  = Import-Certificate -CertStoreLocation Cert:\LocalMachine\Root -FilePath $RootPath

	#install the certificate that will be used for ADFS Service
    $CertFile  = Get-ChildItem -Path "c:\temp\*.pfx"
	for ($file=0;$file -lt $CertFile.Count;$file++)
	{
		$Subject   = $CertFile[$file].BaseName
		$CertPath  = $CertFile[$file].FullName
		$cert      = Import-PfxCertificate -Exportable -Password $SecPW -CertStoreLocation cert:\localmachine\my -FilePath $CertPath
	}

	$Subject = $WapFqdn -f $instance
    $cert      = Get-ChildItem Cert:\LocalMachine\My | where {$_.Subject -eq "CN=$Subject"} -ErrorAction SilentlyContinue

    Install-WebApplicationProxy `
        -FederationServiceTrustCredential $DomainCreds `
        -CertificateThumbprint $cert.Thumbprint`
        -FederationServiceName $Subject

    #record that we got this far
    New-Item -ItemType file "$($completeFile)1"
}

if (!(Test-Path -Path "$($completeFile)2")) {
	$Subject = $WapFqdn -f $instance
	$str = @"
#https://blogs.technet.microsoft.com/rmilne/2015/04/20/adfs-2012-r2-web-application-proxy-re-establish-proxy-trust/
`$DomainCreds = Get-Credential
`$File      = Get-ChildItem -Path "c:\temp\*.pfx"
`$Subject   = "$Subject"

`$cert      = Get-ChildItem Cert:\LocalMachine\My | where {`$_.Subject -eq "CN=`$Subject"} -ErrorAction SilentlyContinue

Install-WebApplicationProxy ``
	-FederationServiceTrustCredential `$DomainCreds ``
	-CertificateThumbprint `$cert.Thumbprint ``
	-FederationServiceName `$Subject

Start-Service -Name appproxysvc
"@

	$scriptBlock = [Scriptblock]::Create($str)
	$scriptBlock.ToString() | out-file C:\AADLab\resetWAPTrust.ps1

    #record that we got this far
    New-Item -ItemType file "$($completeFile)2"
}

if (!(Test-Path -Path "$($completeFile)3")) {
    # Shortcuts

	$WshShell = New-Object -comObject WScript.Shell
	$dt="C:\Users\Public\Desktop\"
	$ieicon="%ProgramFiles%\Internet Explorer\iexplore.exe, 0"
	$Subject = $WapFqdn -f $instance

	$links = @(
		@{site="http://connect.microsoft.com/site1164";name="Azure AD Connect Home";icon=$ieicon},
		@{site="https://docs.microsoft.com/en-us/azure/active-directory/connect/active-directory-aadconnect";name="Azure AD Docs";icon=$ieicon},
		@{site="https://$Subject/adfs/ls/idpinitiatedsignon.aspx";name="ADFS IDP Signon";icon=$ieicon},
		@{site="%windir%\system32\WindowsPowerShell\v1.0\PowerShell_ISE.exe";name="PowerShell ISE";icon="%SystemRoot%\system32\WindowsPowerShell\v1.0\powershell_ise.exe, 0"},
		@{site="%windir%\system32\services.msc";name="Services";icon="%windir%\system32\filemgmt.dll, 0"},
		@{site="%windir%\system32\RAMgmtUI.exe";name="Remote Access Management";icon="%SystemRoot%\System32\damgmtres.dll, 0"},
		@{site="c:\AADLab";name="AAD Lab Files";icon="%windir%\explorer.exe, 13"}
	)

	foreach($link in $links){
		$Shortcut = $WshShell.CreateShortcut("$($dt)$($link.name).lnk")
		$Shortcut.TargetPath = $link.site
		$Shortcut.IconLocation = $link.icon
		$Shortcut.Save()
	}

    #record that we got this far
    New-Item -ItemType file "$($completeFile)3"
}


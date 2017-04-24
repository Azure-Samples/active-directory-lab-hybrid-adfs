param (
    [Parameter(Mandatory)]
    [string]$Acct,

    [Parameter(Mandatory)]
    [string]$PW,

	[Parameter(Mandatory)]
	[string]$WapFqdn
)

$wmiDomain = Get-WmiObject Win32_NTDomain -Filter "DnsForestName = '$( (Get-WmiObject Win32_ComputerSystem).Domain)'"
$DCName = $wmiDomain.DomainControllerName
$ComputerName = $wmiDomain.PSComputerName
$Subject = $WapFqdn -f $instance

$DomainName=$wmiDomain.DomainName
$DomainNetbiosName = $DomainName.split('.')[0]
$SecPw = ConvertTo-SecureString $PW -AsPlainText -Force
[System.Management.Automation.PSCredential]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($Acct)", $SecPW)

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()  
$principal = new-object Security.Principal.WindowsPrincipal $identity 
$elevated = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)  

if (-not $elevated) {
    $a = $PSBoundParameters
    $cl = "-Acct $($a.Acct) -PW $($a.PW)"
    $arglist = (@("-file", (join-path $psscriptroot $myinvocation.mycommand)) + $args + $cl)
    Write-host "Not elevated, restarting as admin..."
    Start-Process cmd.exe -Credential $DomainCreds -NoNewWindow -ArgumentList “/c powershell.exe $arglist”
} else {
    Write-Host "Elevated, continuing..." -Verbose

    #Configure ADFS Farm
    Import-Module ADFS
    $wmiDomain = Get-WmiObject Win32_NTDomain -Filter "DnsForestName = '$( (Get-WmiObject Win32_ComputerSystem).Domain)'"
    $DCName = $wmiDomain.DomainControllerName
    $ComputerName = $wmiDomain.PSComputerName
    $DomainName=$wmiDomain.DomainName
    $DomainNetbiosName = $DomainName.split('.')[0]
    $SecPw = ConvertTo-SecureString $PW -AsPlainText -Force

    [System.Management.Automation.PSCredential]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($Acct)", $SecPW)

    $Index = $ComputerName.Substring($ComputerName.Length-1,1)
	$Subject = $WapFqdn -f $Index
	Write-Host "Subject: $Subject"

    #get thumbprint of certificate
    $cert = Get-ChildItem Cert:\LocalMachine\My | where {$_.Subject -eq "CN=$Subject"}
	try {
	    Get-ADfsProperties -ErrorAction Stop
        Write-Host "Farm already configured" -Verbose
	}
	catch {
        Install-AdfsFarm `
            -Credential $DomainCreds `
            -CertificateThumbprint $cert.thumbprint `
            -FederationServiceName $Subject `
            -FederationServiceDisplayName "ADFS $Index" `
            -ServiceAccountCredential $DomainCreds `
            -OverwriteConfiguration

        Write-Host "Farm configured" -Verbose
	}
 
	# Install AAD Tools
	md c:\temp -ErrorAction Ignore
	Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force

	#Install-Module -Name Azure -AllowClobber -Force
	#Install-Module -Name AzureRM -AllowClobber -Force

	Install-Module -Name MSOnline -Force

	Install-Module -Name AzureAD -Force

	Install-Module -Name AzureADPreview -AllowClobber -Force

    # Setup Shortcuts
	md c:\AADLab -ErrorAction Ignore

	$WshShell = New-Object -comObject WScript.Shell
	$dt="C:\Users\Public\Desktop\"
	$ieicon="%ProgramFiles%\Internet Explorer\iexplore.exe, 0"

	$links = @(
		@{site="http://connect.microsoft.com/site1164";name="Azure AD Connect Home";icon=$ieicon},
		@{site="https://docs.microsoft.com/en-us/azure/active-directory/connect/active-directory-aadconnect";name="Azure AD Docs";icon=$ieicon},
		@{site="http://connect.microsoft.com/site1164/Downloads/DownloadDetails.aspx?DownloadID=59185";name="Download Azure AD Powershell";icon=$ieicon},
		@{site="https://$Subject/adfs/ls/idpinitiatedsignon.aspx";name="ADFS IDP Signon";icon=$ieicon},
		@{site="%windir%\system32\WindowsPowerShell\v1.0\PowerShell_ISE.exe";name="PowerShell ISE";icon="%SystemRoot%\system32\WindowsPowerShell\v1.0\powershell_ise.exe, 0"},
		@{site="%windir%\ADFS\Microsoft.IdentityServer.msc";name="AD FS Management";icon="%windir%\ADFS\Microsoft.IdentityServer.NativeResources.dll, 0"},
		@{site="%windir%\system32\services.msc";name="Services";icon="%windir%\system32\filemgmt.dll, 0"},
		@{site="c:\AADLab";name="AAD Lab Files";icon="%windir%\explorer.exe, 13"}
	)
	foreach($link in $links){
		$Shortcut = $WshShell.CreateShortcut("$($dt)$($link.name).lnk")
		$Shortcut.TargetPath = $link.site
		$Shortcut.IconLocation = $link.icon
		$Shortcut.Save()
	}
}

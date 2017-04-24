#
# ADSnippets.ps1
#
function ResetWAPTrust
{
	$DomainCreds = Get-Credential
	$File      = Get-ChildItem -Path "c:\temp\*.pfx"
	$Subject   = $File.BaseName

	$cert      = Get-ChildItem Cert:\LocalMachine\My | where {$_.Subject -eq "CN=$Subject"} -ErrorAction SilentlyContinue

	Install-WebApplicationProxy `
		-FederationServiceTrustCredential $DomainCreds `
		-CertificateThumbprint $cert.Thumbprint `
		-FederationServiceName $Subject
	
	Start-Service -Name appproxysvc
}

function DownloadAADConnect
{
	#download and deploy AAD Connect
	$AADConnectDLUrl="https://download.microsoft.com/download/B/0/0/B00291D0-5A83-4DE7-86F5-980BC00DE05A/AzureADConnect.msi"

	$exe="c:\windows\system32\msiexec.exe"
	$tempfile = [System.IO.Path]::GetTempFileName()
	$folder = [System.IO.Path]::GetDirectoryName($tempfile)
	$webclient = New-Object System.Net.WebClient
	$webclient.DownloadFile($AADConnectDLUrl, $tempfile)
	Rename-Item -Path $tempfile -NewName "AzureADConnect.msi"
	$MSIPath = $folder + "\AzureADConnect.msi"
	Invoke-Expression "& `"$exe`" /i $MSIPath"
}

#https://technet.microsoft.com/windows-server-docs/identity/ad-fs/operations/ad-fs-user-sign-in-customization
#https://technet.microsoft.com/windows-server-docs/identity/ad-fs/operations/advanced-customization-of-ad-fs-sign-in-pages
function Get-ADFSCustomTheme
{
    md c:\theme -ErrorAction Ignore
	New-AdfsWebTheme -name Custom -SourceName default
	Export-AdfsWebTheme -name default -DirectoryPath c:\theme
	#edit theme
	<#Example onload.js mod:

	//place at the end of the file
	function AdjustName() {
		var el = document.getElementById("userNameInput");
		el.value = el.value.split('@')[0] + "@gtppoc.com"
	}
	
	//Then at the end of "computeLoadIllustration" (already set to fire onload), add:
	//Custom Call Onload
	AdjustName();
	#>
}
function Set-ADFSCustomTheme
{
	Set-AdfsWebTheme -TargetName Custom -AdditionalFileResource @{Uri='/adfs/portal/script/onload.js';path="c:\theme\script\onload.js"}
	Set-AdfsWebConfig -ActiveThemeName Custom
}

function Set-O365AzureDNS 
{
    param (
        [Parameter(Mandatory=$True)]
        [string]$RGName,

        [Parameter(Mandatory=$True)]
        [string]$ZoneName
    )

    $MX = @{
        "value"     = "$FirstLevel-$RootDomain.mail.protection.outlook.com";
        "name"      = "@"; 
        "priority"  = 0;
        "ttl"       = 3600;
    };

    $CNAME = @(
        @{"name" = "autodiscover";           "value" = "autodiscover.outlook.com";                  "ttl" = 3600;}
        @{"name" = "sip";                    "value" = "sipdir.online.lync.com";                    "ttl" = 3600;}
        @{"name" = "lyncdiscover";           "value" = "webdir.online.lync.com";                    "ttl" = 3600;}
        @{"name" = "msoid";                  "value" = "clientconfig.microsoftonline-p.net";        "ttl" = 3600;}
        @{"name" = "enterpriseregistration"; "value" = "enterpriseregistration.windows.net";        "ttl" = 3600;}
        @{"name" = "enterpriseenrollment";   "value" = "enterpriseenrollment.manage.microsoft.com"; "ttl" = 3600;}
    )

    $TXT = @{
        "name"   = "@"; 
        "value"  = "v=spf1 include:spf.protection.outlook.com -all";
        "ttl"    = 3600;
    };

    $SRV = @(
        @{"service" = "_sip";              "protocol" = "_tls"; "port" = 443;  "weight" = 1; "priority" = 100; "ttl" = 3600; "name" = "@"; "target" = "sipdir.online.lync.com";}
        @{"service" = "_sipfederationtls"; "protocol" = "_tcp"; "port" = 5061; "weight" = 1; "priority" = 100; "ttl" = 3600; "name" = "@"; "target" = "sipfed.online.lync.com";}
    )

    #MX Records
    $Record    = New-AzureRmDnsRecordConfig -Exchange $MX.value -Preference $MX.ttl
    $MXRecord  = New-AzureRmDnsRecordSet -Name $MX.name -RecordType MX -ResourceGroupName $RGName -TTL $MX.ttl -ZoneName $ZoneName -DnsRecords $Record -Overwrite -Force -Verbose

    #CNAME Records
    foreach($rec in $CNAME) {
        $Record       = New-AzureRmDnsRecordConfig -Cname $rec.value
        $CNameRecord  = New-AzureRmDnsRecordSet -Name $rec.name -RecordType CNAME -ResourceGroupName $RGName -TTL $rec.ttl -ZoneName $ZoneName -DnsRecords $Record -Overwrite -Force -Verbose
    }

    #TXT Records
    $Record    = New-AzureRmDnsRecordConfig -Value $TXT.value
    $TXTRecord = New-AzureRmDnsRecordSet -Name $TXT.name -RecordType TXT -ResourceGroupName $RGName -TTL $TXT.ttl -ZoneName $ZoneName -DnsRecords $Record -Overwrite -Force -Verbose

    #SRV Records
    foreach($rec in $SRV) {
        $Record    = New-AzureRmDnsRecordConfig -Priority $rec.priority -Weight $rec.weight -Port $rec.port -Target $rec.target
        $SRVRecord = New-AzureRmDnsRecordSet -Name "$($rec.service).$($rec.protocol)" -RecordType SRV -ResourceGroupName $RGName -TTL $rec.ttl -ZoneName $ZoneName -DnsRecords $Record -Overwrite -Force -Verbose
    }
}
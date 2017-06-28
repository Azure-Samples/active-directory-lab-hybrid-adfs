function Get-AuthHeader() {
    Param(
        [string]$Resource="https://management.core.windows.net/"
    )
    $ctx = Get-AzureRMContext -ErrorAction Stop

    $TenantId = $ctx.Tenant.TenantId
	$authUrl = "https://login.microsoftonline.com/${tenantId}"
 
	$AuthContext = [Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext]$authUrl

    #well-known appid for Powershell Azure
	$result = $AuthContext.AcquireToken($Resource,
	    "1950a258-227b-4e31-a9cf-717495945fc2",
	    [Uri]"urn:ietf:wg:oauth:2.0:oob",
	    [Microsoft.IdentityModel.Clients.ActiveDirectory.PromptBehavior]::Auto)
 
	$authHeader = @{
	'Content-Type'='application\json'
	'Authorization'=$result.CreateAuthorizationHeader()
	}
	return $authHeader
}

function New-RDPConnectoid
{
    Param(
        [Parameter(Mandatory=$True,Position=1)]
        [string]$RDPName,

        [Parameter(Mandatory=$True,Position=2)]
        [string]$OutputDirectory,

        [Parameter(Mandatory=$False,Position=3)]
        [string]$ServerName,

        [Parameter(Mandatory=$False,Position=4)]
        [string]$LoginName,

        [Parameter(Mandatory=$False,Position=5)]
        [string]$Width="1400",

        [Parameter(Mandatory=$False,Position=6)]
        [string]$Height="1050"
    )

    $res = @"
full address:s:$ServerName
prompt for credentials:i:1
administrative session:i:1
screen mode id:i:1
use multimon:i:0
desktopwidth:i:$Width
desktopheight:i:$Height
session bpp:i:32
winposstr:s:0,3,0,0,800,600
compression:i:1
keyboardhook:i:2
audiocapturemode:i:0
videoplaybackmode:i:1
connection type:i:7
networkautodetect:i:1
bandwidthautodetect:i:1
displayconnectionbar:i:1
username:s:$LoginName
enableworkspacereconnect:i:0
disable wallpaper:i:0
allow font smoothing:i:0
allow desktop composition:i:0
disable full window drag:i:1
disable menu anims:i:1
disable themes:i:0
disable cursor setting:i:0
bitmapcachepersistenable:i:1
audiomode:i:0
redirectprinters:i:1
redirectcomports:i:0
redirectsmartcards:i:1
redirectclipboard:i:1
redirectposdevices:i:0
autoreconnection enabled:i:1
authentication level:i:2
negotiate security layer:i:1
remoteapplicationmode:i:0
alternate shell:s:
shell working directory:s:
gatewayhostname:s:
gatewayusagemethod:i:4
gatewaycredentialssource:i:4
gatewayprofileusagemethod:i:0
promptcredentialonce:i:0
gatewaybrokeringtype:i:0
use redirection server name:i:0
rdgiskdcproxy:i:0
kdcproxyname:s:
"@

    if ($OutputDirectory) {
    $res | Out-File -FilePath "$($OutputDirectory)$($RDPName).rdp"
    } else {
        return $res
    }
}

function Get-FQDNForVM() {
    param(
        [Parameter(Mandatory=$True,Position=1)]
        [string]$ResourceGroupName,

        [Parameter(Mandatory=$False,Position=2)]
        [string]$VMName,

        [Parameter(Mandatory=$False,Position=3)]
        [string]$IPConfigName
    )
    if (-not $VMName -and -not $IPConfigName) {
        Write-Host "ERROR: Must supply either -VMName or -IPConfigName"
        return
    }

    try {
        $apiver="2016-09-01"
        $computeapiver="2017-03-30"
        $ctx = Get-AzureRMContext -ErrorAction Stop

        $subid = $ctx.Subscription.SubscriptionId
        $mgmtUrl = $ctx.Environment.ResourceManagerUrl
        $Headers = Get-AuthHeader -Resource "https://management.azure.com/" -TenantId $ctx.Tenant.TenantId

        if (-not $IPConfigName) {
            #good grief...VM
            $vmurl="$mgmtUrl/subscriptions/$subid/resourceGroups/$ResourceGroupName/providers/Microsoft.Compute/virtualMachines/$($VMName)?api-version=$computeapiver"
            $res = Invoke-WebRequest -Uri $vmurl -Method Get -Headers $Headers
            $vm = ConvertFrom-Json $res.Content
            $nicarr=$vm.properties.networkProfile.networkInterfaces[0].id.Split('/')
            $nicname=$nicarr[$nicarr.Length-1]

            #...to get the NIC...
            $nicurl="$mgmtUrl/subscriptions/$subid/resourceGroups/$ResourceGroupName/providers/Microsoft.Network/networkInterfaces/$($nicname)?api-version=$apiver"
            $res = Invoke-WebRequest -Uri $nicurl -Method Get -Headers $Headers
            $nic = ConvertFrom-Json $res.Content
            $iparr=$nic.properties.ipConfigurations[0].properties.publicIPAddress.id.split('/')
            $IPConfigName=$iparr[$iparr.length-1]
        }

        #...to get the IP config...
        $ipurl="$mgmtUrl/subscriptions/$subid/resourceGroups/$ResourceGroupName/providers/Microsoft.Network/publicIPAddresses/$($IPConfigName)?api-version=$apiver"
        $res = Invoke-WebRequest -Uri $ipurl -Method Get -Headers $Headers

        #...to get the FQDN
        $data = ConvertFrom-Json $res.Content
        return $data.properties.dnssettings.fqdn
    }
    Catch { 
        Write-Error $_.Exception.Message
    }
}

#MISC
function Get-EscapedString {
    param (
        [string]$UnescapedString
    )
    #$key="lNFS3h0EWmV6CEleP/cyut/a6Rh6/5lwxMwN5VzmCSs="
    return [uri]::EscapeDataString($UnescapedString)
}

function Get-UnEscapedString {
    param (
        [string]$EscapedString
    )
    #$t="https%3A%2F%2Fefs.disney.com&data=02%7C01%7CBrett.Hacker%40microsoft.com%7C98735cc14b5047a1ffcb08d4505bbea3%7C72f988bf86f141af91ab2d7cd011db47%7C1%7C0%7C636221802348425267&sdata=kJpCjR0wbDswSZDevtke6ZmlCSHUyrIh21hvqgGjykE%3D&reserved=0"
    return [uri]::UnescapeDataString($EscapedString)
}

function New-ClientSecret
{
    $bytes = New-Object Byte[] 32
    $rand = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $rand.GetBytes($bytes)
    $newClientSecret = [System.Convert]::ToBase64String($bytes)
    return $newClientSecret
}


Function Set-OSCPin
{
<#
 	.SYNOPSIS
        Set-OSCPin is an advanced function which can be used to pin a item or more items to the Start menu.
    .DESCRIPTION
        Set-OSCPin is an advanced function which can be used to pin a item or more items to the Start menu.
    .PARAMETER  <Path>
		Specifies a path to one or more locations.
    .EXAMPLE
        C:\PS> Set-OSCPin -Path "C:\Windows"
		
        Pin "Windows" to the Start menu sucessfully.

		This command shows how to pin the "shutdown.exe" file to the Start menu.
    .EXAMPLE
        C:\PS> Set-OSCPin -Path "C:\Windows","C:\Windows\System32\shutdown.exe"
		
        Pin "Windows" to the Start menu sucessfully.
        Pin "shutdown.exe" to the Start menu sucessfully.

		This command shows how to pin the "Windows" folder and "shutdown.exe" file to the Start menu.
#>
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory,Position=0)]
        [Alias('p')]
        [String[]]$Path
    )

    $Shell = New-Object -ComObject Shell.Application
	$Desktop = $Shell.NameSpace(0X0)
    $WshShell = New-Object -comObject WScript.Shell
    $Flag=0

    Foreach($itemPath in $Path)
    {
        $itemName = Split-Path -Path $itemPath -Leaf
        #pin application to windows Start menu
        $ItemLnk = $Desktop.ParseName($itemPath)
        $ItemVerbs = $ItemLnk.Verbs()
        Foreach($ItemVerb in $ItemVerbs)
        {
            If($ItemVerb.Name.Replace("&","") -match "Pin to Start")
            {
                $ItemVerb.DoIt()
                $Flag=1
            }
        }
        
        If($Flag=1)
        {
            Write-Host "Pin ""$ItemName"" to the Start menu sucessfully." -ForegroundColor Green
        }
        Else
        {
            Write-Host "The ""$ItemName"" cannot pin to the Start menu." -ForegroundColor Red
        }
    }
}
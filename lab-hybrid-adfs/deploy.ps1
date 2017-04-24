$startTime=Get-Date
Write-Host "Beginning deployment at $starttime"

Import-Module Azure -ErrorAction SilentlyContinue

#DEPLOYMENT OPTIONS
    $templateToDeploy        = "FullDeploy.json"
    # MUST be unique for all your simultaneous/co-existing deployments of this ADName in the same region
    $VNetAddrSpace2ndOctet   = "<ENTER A UNIQUE DEPLOYMENT NUMBER, 0-9>"

    # Must be unique for simultaneous/co-existing deployments
    #"master" or "dev"
    $RGName                  = "<YOUR RESOURCE GROUP>"
    $DeployRegion            = "<SELECT AZURE REGION>"

    $Branch                  = "master"
    $AssetLocation           = "https://raw.githubusercontent.com/Azure-Samples/active-directory-lab-hybrid-adfs/$Branch/lab-hybrid-adfs/"

    $userName                = "<AD ADMINISTRATOR LOGIN>"
    $secpasswd               = “<AD ADMINISTRATOR PASSWORD>”
    $adDomainName            = "<2-PART AD DOMAIN NAME, LIKE CONTOSO.COM>"
    $usersArray              = @(
                                @{ "FName"= "Bob";  "LName"= "Jones";    "SAM"= "bjones" },
                                @{ "FName"= "Bill"; "LName"= "Smith";    "SAM"= "bsmith" },
                                @{ "FName"= "Mary"; "LName"= "Phillips"; "SAM"= "mphillips" },
                                @{ "FName"= "Sue";  "LName"= "Jackson";  "SAM"= "sjackson" }
                               )
    $defaultUserPassword     = "P@ssw0rd"

    # ClientsToDeploy, array, possible values: "7","8","10-1607","10-1511","10-1703"
    # Examples: Single Win7 VM = @("7")
    #           Two Win7, one Win10 Creators = "7","7","10-1703"
    $clientsToDeploy         = @("7")
    $RDPWidth                = 1920
    $RDPHeight               = 1080

    #Enter the full Azure ARM resource string to the location where you store your client images.
    #Your images MUST be named: OSImage_Win<version>
    #Path will be like: "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/<RG holding your images>/providers/Microsoft.Compute/images/"
    $clientImageBaseResource = "<ARM resource path to your VM Client image base>"

    # This will deploy X number of distinct ADFS farms, each with a single WAP proxy deployed in the DMZ.
    $AdfsFarmCount           = "1";

#END DEPLOYMENT OPTIONS

#Dot-sourced variable override (optional, comment out if not using)
. C:\dev\A_CustomDeploySettings\lab-hybrid-adfs.ps1

#ensure we're logged in
Get-AzureRmContext -ErrorAction Stop

#deploy
$parms=@{
    "adminPassword"               = $secpasswd;
    "adminUsername"               = $userName;
    "adDomainName"                = $ADDomainName;
    "assetLocation"               = $assetLocation;
    "virtualNetworkAddressRange"  = "10.$VNetAddrSpace2ndOctet.0.0/16";
    #The first IP deployed in the AD subnet, for the DC
    "adIP"                        = "10.$VNetAddrSpace2ndOctet.1.4";
    #The first ADFS server deployed in the AD subnet - multiple farms will increment beyond this
    "adfsIP"                      = "10.$VNetAddrSpace2ndOctet.1.5";
    "adSubnetAddressRange"        = "10.$VNetAddrSpace2ndOctet.1.0/24";
    "dmzSubnetAddressRange"       = "10.$VNetAddrSpace2ndOctet.2.0/24";
    "cliSubnetAddressRange"       = "10.$VNetAddrSpace2ndOctet.3.0/24";
    #if multiple deployments will need to route between vNets, be sure to make this distinct between them
    "deploymentNumber"            = $VNetAddrSpace2ndOctet;
    "clientsToDeploy"             = $clientsToDeploy;
    "clientImageBaseResource"     = $clientImageBaseResource;
    "AdfsFarmCount"               = $AdfsFarmCount;
    "usersArray"                  = $usersArray;
    "defaultUserPassword"         = "P@ssw0rd";
}

$TemplateFile = "$($assetLocation)$templateToDeploy" + "?x=5"

try {
    Get-AzureRmResourceGroup -Name $RGName -ErrorAction Stop
    Write-Host "Resource group $RGName exists, updating deployment"
}
catch {
    $RG = New-AzureRmResourceGroup -Name $RGName -Location $DeployRegion -Tag @{ Shutdown = "true"; Startup = "false"}
    Write-Host "Created new resource group $RGName."
}
$version ++
$deployment = New-AzureRmResourceGroupDeployment -ResourceGroupName $RGName -TemplateParameterObject $parms -TemplateFile $TemplateFile -Name "adfsDeploy$version"  -Force -Verbose

if ($deployment) {
    if (-not (Get-Command Get-FQDNForVM -ErrorAction SilentlyContinue)) {
        #load add-on functions to facilitate the RDP connectoid creation below
        $url="$($assetLocation)Scripts/Addons.ps1"
        $tempfile = "$env:TEMP\Addons.ps1"
        $webclient = New-Object System.Net.WebClient
        $webclient.DownloadFile($url, $tempfile)
        . $tempfile
    }

    $RDPFolder = "$env:USERPROFILE\desktop\$RGName\"
    if (!(Test-Path -Path $RDPFolder)) {
        md $RDPFolder
    }
    $ADName = $ADDomainName.Split('.')[0]
    $vms = Find-AzureRmResource -ResourceGroupNameContains $RGName | where {($_.ResourceType -like "Microsoft.Compute/virtualMachines")}
    $pxcount=0
    if ($vms) {
        foreach ($vm in $vms) {
            $fqdn=Get-FQDNForVM -ResourceGroupName $RGName -VMName $vm.Name
            New-RDPConnectoid -ServerName $fqdn -LoginName "$($ADName)\$($userName)" -RDPName $vm.Name -OutputDirectory $RDPFolder -Width $RDPWidth -Height $RDPHeight
            if ($vm.Name.IndexOf("PX") -gt -1) {
                $pxcount++
                $WshShell = New-Object -comObject WScript.Shell
                $Shortcut = $WshShell.CreateShortcut("$($RDPFolder)ADFSTest$pxcount.lnk")
                $Shortcut.TargetPath = "https://$fqdn/adfs/ls/idpinitiatedsignon.aspx"
                $Shortcut.IconLocation = "%ProgramFiles%\Internet Explorer\iexplore.exe, 0"
                $Shortcut.Save()
            }
        }
    }

    start $RDPFolder
}

$endTime=Get-Date

Write-Host ""
Write-Host "Total Deployment time:"
New-TimeSpan -Start $startTime -End $endTime | Select Hours, Minutes, Seconds

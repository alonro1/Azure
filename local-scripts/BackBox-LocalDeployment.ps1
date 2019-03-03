<#
.Synopsis
   This Script will deploy backbox vm in Azure
.DESCRIPTION
   This Script will deploy backbox vm in Azure
.EXAMPLE
   .\ClientDeployments\local-scripts\BackBox-LocalDeployment.ps1 -location eastus -vnetStatus New
.EXAMPLE
   .\ClientDeployments\local-scripts\BackBox-LocalDeployment.ps1 -location westus -vnetStatus Existing
#>
#Requires -Modules AzureRM
[Cmdletbinding()]

Param(
    $location,
    [ValidateSet(“Existing”, ”New”)][string]$vnetStatus
)

# Login to Azure
Login-AzureRmAccount

# Select Azure subscription
Get-AzureRmSubscription | ogv -PassThru | Select-AzureRmSubscription
$ErrorActionPreference = 'Stop'


# Define variables
if (!$location) {$location = (cat $TemplateParametersFile | ConvertFrom-Json).parameters.location.value}

$resourceGroupName = "Backbox-rg"
# Generate storage account name
$storageaccountname = "backboxstg" + ( -join (1..100 |Get-Random -Count 6))
$contname = "$storageaccountname-cont"

$sourceVHDURI = 'https://backboxstgeastus.blob.core.windows.net/eastus-cont/BackBoxv6tryFixed.vhd'
$vhd = Split-Path -Leaf $sourceVHDURI 

$templateFolder = $PSScriptRoot.substring(0, $PSScriptRoot.LastIndexOf('\'))
$templateFolder = (Get-ChildItem $templateFolder | where name -like "*$vnetStatus*").FullName
$TemplateFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($templateFolder, "AzureDeploy.json"))
$TemplateParametersFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($templateFolder, "AzureDeploy.parameters.json"))

write-output "Creating $resourceGroupName Resource Group"
$RG= New-AzureRmResourceGroup -Name $resourceGroupName -Location $location

write-output "Creating $storageaccountname storage account"
$stg= New-AzureRmStorageAccount -ResourceGroupName $rg.ResourceGroupName -Name $storageaccountname -SkuName Standard_LRS -Location $location -Kind StorageV2 -AccessTier Cool

write-output "Creating $contname container"
$cont= New-AzureRmStorageContainer -StorageAccountName $storageaccountname -ResourceGroupName $rg.ResourceGroupName -Name $contname -PublicAccess Container -ErrorAction SilentlyContinue
if (!$cont)
{
$cont= New-AzureStorageContainer -StorageAccountName $storageaccountname -ResourceGroupName $rg.ResourceGroupName -Name $contname -PublicAccess Container
}
#$sas= New-AzureStorageBlobSASToken -Container $cont.Name -Blob $blob -Context $stg.Context -ExpiryTime 10000

Write-Output "Start Time: $(get-date)"
Write-Output "Start copy backbox VHD"

$blob = Start-AzureStorageBlobCopy -AbsoluteUri $sourceVHDURI  -DestContainer $cont.Name -DestBlob $vhd -DestContext $stg.Context
$blob| Get-AzureStorageBlobCopyState

Do {Write-Output "copy status is: $(($blob| Get-AzureStorageBlobCopyState).Status)"; sleep -Seconds 10} Until (($blob| Get-AzureStorageBlobCopyState).Status -ne "Pending")
Write-Output "End Time: $(get-date)"

$newUri = "$($blob.context.BlobEndPoint)" + "$($cont.name)/" + "$vhd"# + $sas

if (($blob| Get-AzureStorageBlobCopyState).Status -eq "Success") {
    $deployment= New-AzureRmResourceGroupDeployment -ResourceGroupName $rg.ResourceGroupName `
        -TemplateFile $TemplateFile `
        -TemplateParameterFile $TemplateParametersFile -osDiskVhdUri $newUri -location $location -Verbose
}
else {Write-Error "Something went wrong, blob copy was not completed successfully"}

if ($deployment.ProvisioningState -eq "Succeeded") {Write-Output "BackBox deployment completed successfully"}
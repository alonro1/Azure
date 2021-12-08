    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param
    (
        # VHD source URI
        $sourceVHDURI = 'https://alon1111.blob.core.windows.net/imagestore/newVHDimage.vhd',
        
        # VHD sas token
        $sasToken = 'sp=racw&st=2021-12-08T10:00:00Z&se=2022-12-08T10:00:00Z&sv=2020-08-04&sr=b&sig=NANALj3hVOqAO%2BZEpros8K0mjUs5%2BPCdfc7wEIClACU%3D'
    )
    
    
    $location= read-host "Please enter location"
    $ErrorActionPreference = 'stop'
    $resourceGroupName = "Backbox-rg"
    $storageaccountname = "backboxstg" + ( -join (1..100 |Get-Random -Count 6))
    $contname = "$storageaccountname-cont"
    $vhd = Split-Path -Leaf $sourceVHDURI 
   
    if (!(Get-AzureRmResourceGroup -name $resourceGroupName -ErrorAction SilentlyContinue )) {
        write-output "Creating New Resource group: $resourceGroupName"
        $RG = New-AzureRmResourceGroup -Name $resourceGroupName -Location $location
    } else {$RG = Get-AzureRmResourceGroup -name $resourceGroupName}
    
    write-output "Creating New Storageaccount: $storageaccountname"
    $stg = New-AzureRmStorageAccount -ResourceGroupName $rg.ResourceGroupName -Name $storageaccountname -SkuName Standard_LRS -Location $location -Kind StorageV2 -AccessTier Cool
    write-output "Creating New Container: $contname"
    $cont = New-AzureRmStorageContainer -StorageAccountName $storageaccountname -ResourceGroupName $rg.ResourceGroupName -Name $contname

    Write-Output "Start Time: $(get-date)"
    Write-Output "Start copy backbox VHD"

    $blob = Start-AzureStorageBlobCopy -AbsoluteUri ($sourceVHDURI + "?" + $sasToken) -DestContainer $cont.Name -DestBlob $vhd -DestContext $stg.Context
    $blob| Get-AzureStorageBlobCopyState

    Do {Write-Output "copy status is: $(($blob| Get-AzureStorageBlobCopyState).Status)"; sleep -Seconds 10} Until (($blob| Get-AzureStorageBlobCopyState).Status -ne "Uploading The BackBox VHD Image File To Your Azure Account.")
    Write-Output "End Time: $(get-date)"

    $newUri = "$($blob.context.BlobEndPoint)" + "$($cont.name)/" + "$vhd" #+ $sas
    Write-Output "New URI: $newUri"  


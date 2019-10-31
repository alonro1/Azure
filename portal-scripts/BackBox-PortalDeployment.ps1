    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param
    (
        # VHD source URI
        $sourceVHDURI = 'https://alon111.blob.core.windows.net/bbimage/BackBoxv6tryFixed.vhd',
        
        # VHD sas token
        $sasToken = 'sp=rcw&st=2019-10-31T08:32:37Z&se=2020-10-31T16:32:37Z&spr=https&sv=2019-02-02&sr=b&sig=PxjGxKWG1mD3jS8DQWHa9Rbv%2FoHs0JgQlD2rtWh4bBw%3D'
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

    Do {Write-Output "copy status is: $(($blob| Get-AzureStorageBlobCopyState).Status)"; sleep -Seconds 10} Until (($blob| Get-AzureStorageBlobCopyState).Status -ne "Pending")
    Write-Output "End Time: $(get-date)"

    $newUri = "$($blob.context.BlobEndPoint)" + "$($cont.name)/" + "$vhd" #+ $sas
    Write-Output "New URI: $newUri"  


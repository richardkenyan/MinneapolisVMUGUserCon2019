# RK - 09-06-2014
# From: USE THIS !! https://communities.vmware.com/message/1828708#1828708

# RK - 04-07-2015
# just added some notes

# Time to run:
# When I was using this to do the vc01.opal to bufvcenter.synbuf.local move, it took ~9 hours to run (~900 VMs)!
# The first script (export) was pretty quick, if I remember correctly.
# The second script (import) I remember I left it to run overnight.
# This was after I had imported the VMs to the new vCenter (as the import script simply uses the VM Name).

# There are two scripts here:
# 1)	Export the VMs and the folder structure of the old vCenter.
# 2)	Import (recreate) the old folder structure and move existing VMs for the new vCenter.
# 	2a)	When you run the import section, the VMs should already be in the new vCenter Inventory.


########################################################################################

# Export the VMs and the folderstructure.
# The script uses a New-VIProperty to fetch the blue folderpath for a VM.

Connect-VIServer "your vcenter here"

New-VIProperty -Name 'BlueFolderPath' -ObjectType 'VirtualMachine' -Value {
    param($vm)

    function Get-ParentName{
        param($object)

        if($object.Folder){
            $blue = Get-ParentName $object.Folder
            $name = $object.Folder.Name
        }
        elseif($object.Parent -and $object.Parent.GetType().Name -like "Folder*"){
            $blue = Get-ParentName $object.Parent
            $name = $object.Parent.Name
        }
        elseif($object.ParentFolder){
            $blue = Get-ParentName $object.ParentFolder
            $name = $object.ParentFolder.Name
        }
        if("vm","Datacenters" -notcontains $name){
            $blue + "/" + $name
        }
        else{
            $blue
        }
    }

    (Get-ParentName $vm).Remove(0,1)
} -Force | Out-Null 
$dcName = "DC"

Get-VM -Location (Get-Datacenter -Name $dcName) | 
Select Name,BlueFolderPath |
Export-Csv "C:\vm-folder-list.csv" -NoTypeInformation -UseCulture 


########################################################################################

# Import the folder structure and move existing VMs.
# The complete folder structure that was exported will now be imported in datacenter MyNewDC under the folder Folder1.

Connect-VIServer "your vcenter here"

$newDatacenter = "DC"
$newFolder = "down one from root"

$startFolder = New-Folder -Name $newFolder -Location (Get-Folder -Name vm -Location (Get-Datacenter -Name $newDatacenter))

Import-Csv "C:\vm-folder-list.csv" -UseCulture | %{
    $location = $startFolder
    $_.BlueFolderPath.TrimStart('/').Split('/') | %{
        $tgtFolder = Get-Folder -Name $_ -Location $location -ErrorAction SilentlyContinue
        if(!$tgtFolder){
            $location = New-Folder -Name $_ -Location $location
        }
        else{
            $location = $tgtFolder
        }
    }
    
    $vm = Get-VM -Name $_.Name -ErrorAction SilentlyContinue
    if($vm){
        Move-VM -VM $vm -Destination $location -Confirm:$false 
    }
}

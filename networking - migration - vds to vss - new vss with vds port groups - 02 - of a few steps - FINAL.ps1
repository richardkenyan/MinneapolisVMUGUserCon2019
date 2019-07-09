$starttime = get-date -Format g
# RK - 04-25-2017
# part of getting VDS to VSS

# Moves 4 Physical VMNICs from a host from a dvSwitch to the host's vSwitch (evens first)
# ALSO creates and then migrates the VMKernel portgroups of that host.
# VMNICS ARE MOVING HERE
# VMKERNELS ARE MOVING/MIGRATING HERE
# NO VM NETWORK MIGRATIONS ARE HAPPENING HERE

# This is for a WHOLE DC (per cluster per host):
# If you want to use a single host, you can. You just have to comment out the proper loops and hard code a hostname.

# Automate the reverse, migrating from vSphere Distributed Switch to Virtual Standard Switch using PowerCLI 5.5
# Written by: William Lam
# http://www.virtuallyghetto.com/2013/11/automate-reverse-migrating-from-vsphere.html

# Modified in this instance by: Richard Kenyan

<#
The PowerCLI example script below uses the Add-VirtualSwitchPhysicalNetworkAdapter cmdlet which accepts a list of pNICs, VMkernel interfaces and the portgroups to migrate from VDS to VSS.
The order in which the VMkernel and portgroups are specified is critically important as they will be assigned based on the provided ordering. 
The script also create the necessary portgroups on the VSS which of course can be modified based on your environment. 
Once the migration has been completed, it will then use the Remove-VDSwitchVMHost cmdlet to remove the ESXi hosts from the VDS.
#>

<#
I modified the script slighty.
I changed the vmkernel port group names.
I also had to add the use of Remove-VDSwitchPhysicalNetworkAdapter.
William's 5.5 script was just 5.5 to 5.5. I believe the Add-VirtualSwitchPhysicalNetworkAdapter cmdlet takes care of checking and dealing with physical NICs that are already assigned to another switch.
Without removing the specified adapters first, it will fail.
I also added a VLANID to the storage vmkernel upon creation, as that is required in our network. 
#>

# Make the connection to vCenter
Connect-VIServer -Server "your vcenter here"

# VARIABLES

# VDS to migrate from
$vds_name = "your dvswitch here"
$vds = Get-VDSwitch -Name $vds_name

# VSS to migrate to
$vss_name = "vSwitch0" # This should already be here per your other script that did the vSwitch0 creation and creating of the portgroups

# Name of portgroups to create on VSS
$mgmt_name = "esx - mgmt and vmotion"
$storage_name = "esx - nas"
$vmotion_name = "esx - vmotion only"

# ESXi hosts to migrate from VDS-VSS
# Loop through Clusters, and then hosts.
# I manually setup these as I don't care about others.
# Also, when I do OTHER DATACENTERS, I don't want to get too forgetful about different clusters.
# I can also go slower instead of doing a while DC at once.
$cluster_array = @("")
#$cluster_array = Get-Cluster -Name "Cluster1","Cluster2" | Select -ExpandProperty Name | Sort
$cluster_array = Get-Cluster -Name "Cluster3" | Select -ExpandProperty Name | Sort

Write-Host "Here are the clusters to be acted on: "
$cluster_array

#FOR EACH CLUSTER in ARRAY
foreach ($cluster in $cluster_array)
    {
    # Grab hosts in this cluster
    $vmhost_array = Get-Cluster -Name $cluster | Get-VMHost | Select -ExpandProperty Name | Sort
    #$vmhost_array = @("esx01-local-lab.com") # If you want to use just 1 host.
    
    Write-Host "Here are the hosts in the $cluster cluster we will act on: "
    $vmhost_array


    #FOR EACH HOST in ARRAY
    foreach ($vmhost in $vmhost_array)
        {
        Write-Host "`nProcessing" $vmhost

        # pNICs to migrate to VSS
        # grabbing every other one to span the hosts that have multiple network cards (evens first)
        # just in case...
        Write-Host "Retrieving pNIC info for vmnic0,vmnic2,vmnic4,vmnic6 for usage"
        $vmnic0 = Get-VMHostNetworkAdapter -VMHost $vmhost -Name "vmnic0"
        $vmnic2 = Get-VMHostNetworkAdapter -VMHost $vmhost -Name "vmnic2"
        $vmnic4 = Get-VMHostNetworkAdapter -VMHost $vmhost -Name "vmnic4"
        $vmnic6 = Get-VMHostNetworkAdapter -VMHost $vmhost -Name "vmnic6"

        # Array of pNICs to migrate to VSS
        Write-Host "Creating pNIC array"
        $pnic_array = @($vmnic0,$vmnic2,$vmnic4,$vmnic6)
        $pnic_array = $pnic_array | Sort Name

        # Remove physical pNICs from VDS
        Write-Host "Removing the following pNICs from " $vds_name " : " $vmnic0 $vmnic2 $vmnic4 $vmnic6
        Get-VMHostNetworkAdapter -VMHost $vmhost -Physical -Name $pnic_array | Remove-VDSwitchPhysicalNetworkAdapter -Confirm:$false 

        # VSS to migrate to
        $vss = Get-VMHost -Name $vmhost | Get-VirtualSwitch -Name $vss_name

        # Create destination network portgroups on VSS
        Write-Host "`Creating" $mgmt_name "Network portrgroup on" $vss_name
        $mgmt_pg = New-VirtualPortGroup -VirtualSwitch $vss -Name $mgmt_name

        Write-Host "`Creating" $storage_name "Network portrgroup with vlan 160 on" $vss_name
        $storage_pg = New-VirtualPortGroup -VirtualSwitch $vss -Name $storage_name -VLanId 160

        Write-Host "`Creating" $vmotion_name "Network portrgroup on" $vss_name
        $vmotion_pg = New-VirtualPortGroup -VirtualSwitch $vss -Name $vmotion_name

        # Array of portgroups to map VMkernel interfaces (order matters!)
        Write-Host "Creating portgroup array"
        $pg_array = @($mgmt_pg,$storage_pg,$vmotion_pg)

        # VMkernel interfaces to migrate to VSS
        Write-Host "`Retrieving VMkernel interface details for vmk0,vmk1,vmk2"
        $mgmt_vmk = Get-VMHostNetworkAdapter -VMHost $vmhost -Name "vmk0"
        $storage_vmk = Get-VMHostNetworkAdapter -VMHost $vmhost -Name "vmk1"
        $vmotion_vmk = Get-VMHostNetworkAdapter -VMHost $vmhost -Name "vmk2"

        # Array of VMkernel interfaces to migrate to VSS (order matters!)
        Write-Host "Creating VMkernel interface array"
        $vmk_array = @($mgmt_vmk,$storage_vmk,$vmotion_vmk)

        # Perform the migration
        Write-Host "Migrating from " $vds_name " to " $vss_name "`n and turning Network portgroups into vmkernels"
        Add-VirtualSwitchPhysicalNetworkAdapter -VirtualSwitch $vss -VMHostPhysicalNic $pnic_array -VMHostVirtualNic $vmk_array -VirtualNicPortgroup $pg_array -Confirm:$false

        Write-Host "Done transferring" $vmhost "to its" $vss_name
        Write-Host " "
        Write-Host "I still have to fling the other physical network adapters over from the $vds_name to $vss_name"
        Write-Host "I still have to remove $vmhost from $vds_name"
        Write-Host " "
        

        }#end foreach host

        # Remove the hosts ($vmhost_array) from the VDS ($vds_name)
        # This is done in another script AFTER we move the VM Networks over.
        # I needed a way to rollback, and doing this separately was the way to go.
        # Doing it here because your $vmhost_array will change when you jump clusters.
    
        #Write-Host "`nIn " $cluster "Removing hosts " $vmhost_array "from the dvSwitch" $vds_name
        #$vds | Remove-VDSwitchVMHost -VMHost $vmhost_array -Confirm:$false


    }#end foreach cluster
    

#Disconnect-VIServer -Server $global:DefaultVIServers -Force -Confirm:$false

Write-Host "Next Step is to run the script to move all VMs to standard vSwitch0 and vm portgroups"
Write-Host "Script DONE"
$endtime = get-date -Format g

Write-Host "Script Start time:" $starttime 
Write-Host "Script End time:" $endtime 

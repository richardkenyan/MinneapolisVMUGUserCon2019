$starttime = get-date -Format g
# RK - 04-27-2017
# part of getting VDS to VSS

# Remove the final physical adapters from a host's dvSwitch, and put it on its own vSwitch.
# Then remove the host(s) from the dvSwitch.

# VMNICS ARE MOVING HERE
# NO VMKERNELS ARE MOVING/MIGRATING HERE -> They have been done in another script
# NO VM NETWORK MIGRATIONS ARE HAPPENING HERE -> They have been done in another script
# YOU ARE REMOVING A HOST FROM A DVSWITCH

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
I modified the script above.
I basically duplicated the script mentioned above, and split it into two pieces.
This second piece removes the remaining physical vmnics from the dvSwitch, and puts them on the host's vSwitch.
This script also removes the hosts from the dvSwitch.
I needed a way to rollback, and doing this separately was the way to go.
#>

# Make the connection to vCenter
Connect-VIServer -Server "your vcenter here"

# VARIABLES

# VDS to migrate from
$vds_name = "your dvSwitch here"
$vds = Get-VDSwitch -Name $vds_name

# VSS to migrate to
$vss_name = "vSwitch0" # This should already be here per your other script that did the vSwitch0 creation and creating of the portgroups

# ESXi hosts to migrate from VDS-VSS
# Loop through Clusters, and then hosts.
# I manually setup these as I don't care about others.
# Also, when I do OTHER DATACENTERS, I don't want to get too forgetful about different clusters.
# I can also go slower instead of doing a while DC at once.
$cluster_array = @("")
$cluster_array = Get-Cluster -Name "Cluster1","Cluster2" | Select -ExpandProperty Name | Sort
#$cluster_array = Get-Cluster -Name "Cluster3" | Select -ExpandProperty Name | Sort

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
        # grabbing every other one to span the hosts that have multiple network cards (odds second)
        # just in case...
        Write-Host "Retrieving pNIC info for vmnic1,vmnic3,vmnic5,vmnic7 for usage"
        $vmnic1 = Get-VMHostNetworkAdapter -VMHost $vmhost -Name "vmnic1"
        $vmnic3 = Get-VMHostNetworkAdapter -VMHost $vmhost -Name "vmnic3"
        $vmnic5 = Get-VMHostNetworkAdapter -VMHost $vmhost -Name "vmnic5"
        $vmnic7 = Get-VMHostNetworkAdapter -VMHost $vmhost -Name "vmnic7"

        # Array of pNICs to migrate to VSS
        Write-Host "Creating pNIC array"
        $pnic_array = @($vmnic1,$vmnic3,$vmnic5,$vmnic7)
        $pnic_array = $pnic_array | Sort Name

        # Remove physical pNICs from VDS
        Write-Host "Removing the following pNICs from " $vds_name " : " $vmnic1 $vmnic3 $vmnic5 $vmnic7
        Get-VMHostNetworkAdapter -VMHost $vmhost -Physical -Name $pnic_array | Remove-VDSwitchPhysicalNetworkAdapter -Confirm:$false 

        # VSS to migrate to
        $vss = Get-VMHost -Name $vmhost | Get-VirtualSwitch -Name $vss_name

        # Perform the migration
        Write-Host "Migrating pNICS from " $vds_name " to " $vss_name "`n"
        Add-VirtualSwitchPhysicalNetworkAdapter -VirtualSwitch $vss -VMHostPhysicalNic $pnic_array -Confirm:$false

        Write-Host "Done flinging the remaining host adapters over"
        Write-Host "Done transferring $vmhost to its $vss_name."
        Write-Host "I still have to remove host from $vds_name."
        Write-Host " "

        Write-Host " "

        # I'm choosing to do this OUTSIDE the per host loop. The Remove-VDSwitchVMHost can accept a variable.
        #Write-Host "`nRemoving $vmhost from $vds_name."
        #$vds | Remove-VDSwitchVMHost -VMHost $vmhost -Confirm:$false
        

        }#end foreach host


        # Remove the hosts ($vmhost_array) from the VDS ($vds_name)
        # Doing it here because your $vmhost_array will change when you jump clusters.
        Write-Host "`nIn" $cluster ", removing these hosts below from the dvSwitch $vds_name."
        Write-Host $vmhost_array

        $vds | Remove-VDSwitchVMHost -VMHost $vmhost_array -Confirm:$false
        Write-Host " "
        Write-Host "DONE"
        Write-Host " "


    }#end foreach cluster


#Disconnect-VIServer -Server $global:DefaultVIServers -Force -Confirm:$false

Write-Host "If I choose to script moving pNICs back to a dvSwitch, make sure to setup the dvSwitch with proper UpLink names and tie the pNICs 0-8 to uplinks 0-8."
Write-Host " "
Write-Host "Script DONE"

$endtime = get-date -Format g

Write-Host "Script Start time:" $starttime 
Write-Host "Script End time:" $endtime 
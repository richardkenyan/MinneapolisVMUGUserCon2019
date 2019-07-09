#### THIS IS THE REVERSED VERSION
#### VSS TO VDS


$starttime = get-date -Format g
# RK - 04-26-2017
# Migrate VMs from dvSwitch port group names to vSwitch port group names of roughly the same name.
# The script wasn't setup to deliniate between dvSwitch Port Groups and vSwitch Port Groups named exactly the same.

# Original script started from this these:
# Migrating distributed vSwitch configurations from one vCenter to a new vCenter
# Written by: Gabrie van Zanten
# http://www.gabesvirtualworld.com/migrating-distributed-vswitch-to-new-vcenter/

# I also used this guy's script:
# This was incredibly useful in simplying this migration step vs the guy above, whose steps I'm still using in other places.
# https://nutzandbolts.wordpress.com/2013/11/15/migrate-host-and-guests-vds-to-ss-using-powercli-5-5/


# REVERSIBLE SCRIPT! - NICE!
# This script will go from a dvSwitch Portgroup to a vSwitch Portgroup.
# If you want to do the reverse, from a vSwitch Portgroup to a dvSwitch Portgroup,
# just flip the If check from $row.olddvPG to $row.tmpvPG
# AND do Set-NetworkAdapter -Portgroup $row.olddvPG instead of Set-NetworkAdapter -NetworkName $row.tmpvPG
# This is because you'll get a warning if you set an adapter to a dvSwitch PortGroup:
# WARNING: Specifying a distributed port group name as network name is no longer supported. Use the -Portgroup parameter.


# Make the connection to vCenter
Connect-VIServer -Server "your vcenter here"


# Import the csv file with the switch info
# You already should have this from one the other scripts I used.
# This script can be easily modified if you don't need this piece.
$report = Import-Csv "C:\step01-switch-list.csv"


# Loop through Clusters, and then hosts, then build a vSwitch0 with portgroups from the dvSwitch.
# Loop through Clusters, and then hosts.
# I manually setup these as I don't care about others.
# Also, when I do OTHER DATACENTERS, I don't want to get too forgetful about different clusters.
# I can also go slower instead of doing a while DC at once.
$cluster_array = ""
$cluster_array = Get-Cluster -Name "Cluster1","Cluster2" | Select -ExpandProperty Name | Sort
#$cluster_array = Get-Cluster -Name "Cluster3" | Select -ExpandProperty Name | Sort

Write-Host "Here are the clusters to be acted on: "
$cluster_array

#FOR EACH CLUSTER in ARRAY
foreach ($cluster in $cluster_array)
    {
    # Grab hosts in this cluster.
    $vmhost_array = Get-Cluster -Name $cluster | Get-VMHost | Select -ExpandProperty Name | Sort
    #$vmhost_array = @("esx01-local-lab.com") # If you want to use just 1 host.
    
    Write-Host "Here are the hosts in the $cluster cluster we will act on: "
    $vmhost_array


    #FOR EACH HOST in ARRAY
    foreach ($vmhost in $vmhost_array)
        {
        # Grab VMs on this Host.
        # I could get the VMs outside of the host, but I want to do host by host migrations, so this makes the most sense.
        $vmhostobj = Get-VMHost $vmhost
        $vmlist = $vmhostobj | Get-VM | Select -ExpandProperty Name
        $vmlist = $vmlist | Sort
        
        Write-Host "In the $cluster cluster, migrate $vmhost's following VMs' Network Adapter settings:"
        $vmlist


        #FOR EACH VM in ARRAY (Loop through your VMs)
        foreach($vm in $vmlist)
            {
            # For the VM you are on, grab its network adapters, which may be 1 or many.
            # Blank out this variable at the start of each VM, just in case.
            $AdapterList = ""
            $AdapterList = Get-NetworkAdapter $vm

            # Write the VM name to the console for record keeping.
            write-host " "
            write-host "VM Name:" $vm "(on $vmhost)"


            #FOR EACH NETWORK ADAPTER in your ARRAY (Loop through your VM's adapters)
            foreach($adapter in $AdapterList)
                {


                # FOR EACH ROWS in your ARRAY (Loop through each Excel row)
                foreach($row in $report)
                    {
                    # Match the specific adapter you are on to its networkname to the olddvPG in the Excel sheet.
                    # If the current adapter's network name matches the Excel row you are on, grab that same row's column of tmpvPG and apply it to the adapter.
                    # I've adjusted things to do clusters and hosts.
                    # Yes, there ended up being a lot fo duplicate info in the csv, but it allows me to break things down by cluster and host.
                    # So for the If logic, I'm now also matching cluster and esx host.
                    # Original: If ($adapter.NetworkName -match $row.olddvPG)
                    If ($cluster -eq $row.cluster -and $vmhost -eq $row.movinghost -and $adapter.NetworkName -match $row.tmpvPG)
                        {
                            Write-Host "`tAdapter Name:" $adapter.Name
                            Write-Host "`t`tCurrently" $adapter.Name "has portgroup" $adapter.NetworkName "and that matches the Excel Row of tmpvPG to" $row.tmpvPG
                            Write-Host "`t`tSo," $vm $adapter.Name "will be set to the new dv portgroup of" $row.olddvPG
                            Write-Host "`t`tThus, I'll do my set here."
                            Write-Host "`t`tSetting VM" $vm $adapter.Name "to the new dv portgroup of" $row.olddvPG

                            # You have to grab the specific network adapter you want from the VM you want.
                            # You can grab by network adapter name (i.e., Network adapter 1) or NetworkName (i.e., "vmnetwork1").
                            # If you have more than one adapter, you need to use the where-ojbect to get the adapter you want.
                            # If you have more than one adapter, with the same NetworkName, just use NetworkName (i.e., vmnetwork1) and it will grab them all.
                            # If you just want to get ALL the VMs, you can ALSO do that, and then just do a where NetworkName -eq $old, then set to new, as all the hosts' vSwitch0s will have the same port groups.
                              # That honestly freaks me out, and I'd rather do it vm by vm, and then adapter by adapter, and then check the names against the matching row, and then change.
                              # I know, this is ends up not being very efficent, but I understand the code better, and it isn't as terrifying.
                            # https://www.reddit.com/r/PowerShell/comments/4zl3ft/unable_to_convert_value_of_system_string_for/ - what I figured I'd need to do when I was testing and found it didn't work. Woo Hoo on me.
                            # https://communities.vmware.com/thread/297347/ - info by LucD
                            # https://communities.vmware.com/thread/314710/ - info by LucD
                   
                            # Go dvSwitch to vSwitch if you set the IF statement above correctly.
                            # This line is the actual moving of network name on the network adapter of the VM:
                            # Get the Network Adapters by the Name of the VM you are currently looped on, and grab the adapter by the Name of the adapter you are currently looped on.
                            # Having already checked this specific adapter's network name to one that matches the Excel Row you are currently looped on, set it to the new value of that same row.
                            
							#Get-NetworkAdapter -VM $vm | where {$_.Name -eq $adapter.Name} | Set-NetworkAdapter -NetworkName $row.tmpvPG -Confirm:$false | Out-Null
							
                            # The more terrifying way to do this, with less loops, and all at once in the environment once it is properly configured, is as follows.
                            # You'd only need to loop through the Excel Rows looking for the old value and picking the new value to use based on that.
                            # I'm choosing NOT to do this, as again, terrifying.
                            # I'd rather do it host by host, vm by vm, adapter by adapter.
                            #Get-VM | Get-NetworkAdapter | Where {$_.NetworkName -eq "vmnetwork1"} #| Set-NetworkAdapter -NetworkName "Mig-vmnetwork1" -Confirm:$false

                            # REVERSE
                            # Go vSwitch to dvSwitch if you set the IF statement above correctly.
                            Get-NetworkAdapter -VM $vm | where {$_.Name -eq $adapter.Name} | Set-NetworkAdapter -Portgroup $row.olddvPG -Confirm:$false | Out-Null
                        }
                    Else
                        {
                            # Nothing, just keep whipping through the Excel sheet until the adapter you are currently on matches one of the old portgroup names.
                        }


                    }#end Excel loop


                }#end VM Adapters loop


            }#end List of VMs loop

            Write-Host " "
            Write-Host $vmhost "DONE"
            Write-Host "All VMs on $vmhost have now been moved from the old dvSwitch to the standard vSwitch on $vmhost."
            Write-Host "You can now remove this host from the old vCenter and then add it to the new vCenter."
            Write-Host " "
            Write-Host " "


        }#end foreach host loop


    }#end foreach cluster loop


Write-Host " "
Write-Host "Script DONE"

$endtime = get-date -Format g

Write-Host "Script Start time:" $starttime 
Write-Host "Script End time:" $endtime 
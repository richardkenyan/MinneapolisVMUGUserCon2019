# RK - 04-24-2017
# part of getting VDS to VSS

# CREATES vswitch0 with port groups copied from a dvSwitch on hosts per cluster.
# Dumps info to an excel sheet for later use in migrating the VMs to the vSwitch0 and re-creating the dvSwitch in a new vCenter
# Yes, I'm aware everything into the Excel sheet is the same, except for the cluster and host name.
# However, I WANTED it this way, so I could split it up between clusters/hosts for our CCRBs.
# NO VMNICS ARE MOVING HERE
# NO VMKERNELS ARE MOVING/MIGRATING HERE
# NO VM NETWORK MIGRATIONS ARE HAPPENING HERE
# That is why it is step 1
# THIS IS JUST BUILDING OUT THE STANDARD VSWITCHES ON THE HOSTS.

# This is for a WHOLE DC (per cluster per host):
# If you want to use a single host, you can. You just have to comment out the proper loops and hard code a hostname.

# Migrating distributed vSwitch configurations from one vCenter to a new vCenter
# Written by: Gabrie van Zanten
# http://www.GabesVirtualWorld.com

# Modified in this instance by: Richard Kenyan

function fnGet-dvSwitch{

	# This function was written by Luc Dekens
	# See: http://www.lucd.info/2009/10/12/dvswitch-scripting-part-2-dvportgroup/

	param([parameter(Position = 0, Mandatory = $true)][string]$DatacenterName,
	[parameter(Position = 1, Mandatory = $true)][string]$dvSwitchName)

	$dcNetFolder = Get-View (Get-Datacenter $DatacenterName | Get-View).NetworkFolder
	$found = $null
	foreach($net in $dcNetFolder.ChildEntity){
		if($net.Type -eq "VmwareDistributedVirtualSwitch"){
			$temp = Get-View $net
			if($temp.Name -eq $dvSwitchName){
				$found = $temp
			}
		}
	}
	$found
}

function fnSet-dvSwPgVLAN{

	# This function was written by Luc Dekens
	# See: http://www.lucd.info/2009/10/12/dvswitch-scripting-part-2-dvportgroup/

	param($dvSw, $dvPg, $vlanNr)

	$spec = New-Object VMware.Vim.DVPortgroupConfigSpec
	$spec.defaultPortConfig = New-Object VMware.Vim.VMwareDVSPortSetting
	$spec.DefaultPortConfig.vlan = New-Object VMware.Vim.VmwareDistributedVirtualSwitchVlanIdSpec
	$spec.defaultPortConfig.vlan.vlanId = $vlanNr

	$dvPg.UpdateViewData()
	$spec.ConfigVersion = $dvPg.Config.ConfigVersion

	$taskMoRef = $dvPg.ReconfigureDVPortgroup_Task($spec)

	$task = Get-View $taskMoRef
	while("running","queued" -contains $task.Info.State){
		$task.UpdateViewData("Info")
	}
}

function fnGet-dvSwPg{
	param($dvSw )

# Search for Portgroups
	$dvSw.Portgroup | %{Get-View -Id $_} 

}

# Ask what vCenter, datacenter and dvSwitch we're talking about
<#
#RK commenting this out - doing it in script vs asking
Disconnect-VIServer "*" -Force:$true
$vCenterOld = Read-Host "What is the name of the OLD vCenter: "
$DatacenterName = Read-Host "What is the name of the datacenter on the OLD vCenter: "
$OlddvSwitch = Read-Host "What is the name of the distributed vSwitch (dvSwitch) you want to move: "
$MovingHost = Read-Host "What is the name of the host you want to move: "
#>


# Variables to set
$vCenterOld = "your vcenter here"
$DatacenterName = "your datacenter here"
$OlddvSwitch = "your dvswitch here"
#$MovingHost = "esx01-local-lab.com" #use this if you want to just do a single host
$standard_vSwitch_Name = "vSwitch0" #RK added this variable

# Report will be used to store the changes
$report=@()

# Make the connection to vCenter
Connect-VIServer -Server $vCenterOld

# Read the dvSwitch and and grab the dvPortGroups into an array
$dvSwitch = fnGet-dvSwitch $DatacenterName $OlddvSwitch
$dvPG = fnGet-dvSwPg $dvSwitch

# Sorting so I have an idea of progress and it nicely orders things on the vSwitch in the GUI (RK).
$dvPG = $dvPG | Sort Name


# Loop through Clusters, and then hosts, then build a vSwitch0 with portgroups from the dvSwitch.
# I manually setup these as I don't care about others.
# Also, when I do OTHER DATACENTERS, I don't want to get too forgetful about different clusters.
# I can also go slower instead of doing a while DC at once.
$clusters = ""
$clusters = Get-Cluster -Name "Cluster1","Cluster2" | Select -ExpandProperty Name | Sort
#$clusters = Get-Cluster -Name "Cluster3" | Select -ExpandProperty Name | Sort

Write-Host "Here are the clusters to be acted on: "
$clusters

#FOR EACH CLUSTER in ARRAY
foreach ($cluster in $clusters)
    {
    # Grab hosts in this cluster.
    $MovingHosts = Get-Cluster -Name $cluster | Get-VMHost | Select -ExpandProperty Name | Sort
    
    Write-Host "Here are the hosts in the $cluster cluster we will act on: "
    $MovingHosts

    #FOR EACH HOST in ARRAY
    foreach ($MovingHost in $MovingHosts)
        {
        # Create Standard vSwitch

        # Now create a (temporary) standard vSwitch with 128 ports. Remember, each VM needs one port and 128 might not be enough for you.
        # The name of this temporary standard vSwitch will be 'vSwitch-Migrate' #author's preference - RK used vSwitch0
        New-VirtualSwitch -Name $standard_vSwitch_Name -NumPorts 128 -VMHost $MovingHost

        # Grab the vSwitch you just created. You'll use it as an object below.
        $vSwitch = Get-VirtualSwitch -VMHost $MovingHost -Name $standard_vSwitch_Name

        #FOR EACH dvSwitch Portgroup in ARRAY
        foreach ($dvPGroup in $dvPG)
            {
            $VLANID = ""
            $VLANID = $dvPGroup.Config.DefaultPortConfig.Vlan.VlanId
            $numPorts = ""
            $numPorts = $dvPGroup.Config.NumPorts
    
            # Somehow the first line in $dvPGroup is some kind of header with 'VMware.Vim.NumericRange' in it. So I skip it.
	        If ($VLANID -notmatch 'VMware.Vim.NumericRange')
		        {

		        # I want the new standard Portgroup to be named 'Mig-VLAN100' instead of 'VLAN100' #original author's preference
                    # UGH - discovered when you grab, you get the shitty / ascii value - and then when inserting, you have the actual / ascii value in the damn name instead of the character /...
                    # This means the port names won't ever match (well...they will, but I don't feel like working on it).
                    # I simply just manually removed all / characters from the network names in cmh on 04-26-2017
		        $NewPG = 'Mig-' + $dvPGroup.Name

		        # Create a New standard vm portgroup
		        #Get-VirtualSwitch -VMHost $MovingHost -Name $standard_vSwitch_Name | New-VirtualPortGroup -Name $NewPG -VLanId $VLANID #original author's line - why is this here? Just use the name I have already!
                $vSwitch | New-VirtualPortGroup -Name $NewPG -VLanId $VLANID 

		        # Just to always know what was what, I keep track of old and new names
		        # This is where you could add more settings from the olddvPG, like load balancing, number of ports, etc.
                $Conversion = "" | Select cluster, movinghost, olddvSwitch, olddvPG, tmpvSwitch, tmpvPG, NumPorts, VLANID
                $Conversion.cluster = $cluster #RK added this for later use in re-creating the dvSwitch in a new vCenter as a double/triple check
                $Conversion.movinghost = $MovingHost #RK added this for later use in re-creating the dvSwitch in a new vCenter as a double/triple check
		        $Conversion.olddvswitch = $dvSwitch.Name
		        $Conversion.olddvPG = $dvPGroup.Name
		        $Conversion.tmpvSwitch = $vSwitch.Name #Get-VirtualSwitch -VMHost $MovingHost -Name $standard_vSwitch_Name #original author's line - why is this here? Just use the name I have already!
		        $Conversion.tmpvPG = $NewPG
                $Conversion.NumPorts = $numPorts #RK added this for later use in re-creating the dvSwitch in a new vCenter as reference
		        $Conversion.VLANID = $VLANID
		        $report += $Conversion

		        }#end if


	        }#end foreach dvPortGroup


        }#end foreach host


    }#end foreach cluster


# Writing the info to CSV file

Write-Host "`nProcessing dumping to csv"
$report | sort cluster,movinghost,olddvSwitch,olddvPG,tmpvSwitch,tmpvPG,NumPorts,VLANID | Export-Csv "C:\step01-switch-list.csv" -NoTypeInformation
Write-Host "DONE"

Write-Host " "

Write-Host "The dvSwitch and dvPortGroups have been exported to CSV file and standard vSwitches with vm portgroups has been created."
Write-Host "Next Step is to get a porition of physical adapters off the dvswitch and onto the vSwitch0s, AND MIGRATE the vmkernels in the same step"
Write-Host "Next Step would then be to run the script which will move all VMs to standard vSwitches and portgroups"

Write-Host " "
Write-Host "Script DONE"

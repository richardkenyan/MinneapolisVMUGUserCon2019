# RK - 05-11-2017
# References here:
# https://blogs.vmware.com/PowerCLI/2016/04/powercli-6-3-r1-get-esxcli-why-the-v2.html
# https://vaddicted.wordpress.com/2016/03/21/how-to-update-esxi-via-cli/
# http://www.lucd.info/2012/10/15/update-a-remote-server-to-esxi-5-1/ (before v2 above)

# RK - 07-14-2017
# updated some instructions

# RK - 08-02-2017
# added a small section about listing the profile to use from the depot you have

# If you wanna use the script, just update lines 100/101/102. Then uncomment 139 when you are REALLY ready to run.
# I've got the dryrun area first regardless, then it runs the dryrun, which if it suceeds, runs the update (which is manually off by me).
# What I should really do is set a starter line/dryrun/option if statement (just simple dryrun - true/false) to make less changes to just run it.


# CONNECT TO YOUR VCENTER
Connect-VIServer "your vcenter here"

# CLEAN - if you were playing around here or in another script
$vmhosts = ""
$vmhost = ""
$esxcli2 = ""
$arguments = ""

# CONNECT TO YOUR HOSTS
#$vmhosts = Get-VMHost "esxnamehere","esxnamehere" | select -ExpandProperty Name
$vmhosts = $vmhosts | sort
#$vmhosts

# INTERACTIVE HOST SELECTION AREA
<#
    # Found this piece here: http://www.thelowercasew.com/place-a-vsphere-host-into-maintenance-mode-via-powercli
    # Makes rolling through stuff easier as it looks like I'll be doing these one at a time.
    # Choose which host to place into maintenance mode (you MUST connect to vCenter first)
    Write-host "Choose which vSphere host to place into Maintenance Mode."
    write-host ""
    $IHOST = Get-VMhost | Select Name | Sort-object Name
    $i = 1
    $IHOST | %{Write-Host $i":" $_.Name; $i++} #shortcut to writing out a foreach loop
    $DSHost = Read-host "Enter the number for the host to place into Maintenance Mode:"
    $SHOST = $IHOST[$DSHost -1].Name
    write-host "You have selected" $SHOST"."

    $vmhosts = $SHOST
#>

# MAINTENANCE MODE AREA - commented off by default internally to this code block as well, just in case ;-)
<#
    # Moving host(s) into Maintenance Mode FIRST - then doing dryrun, followed by a real run, followed by a reboot.
    # If I'm able to, I really should do Maintenance Mode first.
    # Just safer.
    # For whatever reason, the vmkernels flipped around and removed and moved vmotion and management settings to different vmkernels.
    # I can't remember if I did maintenance mode first.
	
	# UPDATE: 05-17-2017
	# Putting hosts (G7s and G8s - 5.0 -> 5.5u3e) into Maintenance Mode first doesn't make a difference.
	# They are fine before the reboot, but the VMkernels get all screwed up afterwards.
	# No idea why!
	# You'll have to check them. Basically, "esx - mgmt and vmotion" and "esx - vmotion only" end up with "vmotion" disabled.
	# "esx - nas" has been ok for the most part. Only once did I have to delete it and recreate it because it literally lost its IP! And twice it had mgmt traffic enabled, which I then set back to disabled.
	# =(
	# This is the only page on the net (yes, really) that I could find that describes my exact problem: https://communities.vmware.com/message/2297309#2297309

    # The Maintenance Mode command will not complete until the VMs are done being moved off.

    $getdate = Get-Date -Format g
    $vmhosts | %{Write-Host $_ "moving into Maintenance Mode at $getdate";} #shortcut to writing out a foreach loop
    ###Set-VMHost $vmhosts -State Maintenance | Out-Null
#>

# FYI: GET THE NAME OF THE PROFILE IN THE DEPOT
# I kept forgetting how to look this up, so I just it here =)
# esxcli software sources profile list -d /vmfs/volumes/<UUID OR datastore_name>/<folder>/<.zip>
# Example output:
<#
[root@esxbc01b01:~] esxcli software sources profile list -d /vmfs/volumes/14aaa293-23aa7a7a/VMware/VMware-ESXi-6.5.0-Update1-5969303-HPE-650.U1.10.1.0.14-Jul2017-depot.zip
Name                                     Vendor                      Acceptance Level
---------------------------------------  --------------------------  ----------------
HPE-ESXi-6.5.0-Update1-650.U1.10.1.0.14  Hewlett Packard Enterprise  PartnerSupported
#>

foreach ($vmhost in $vmhosts){
    
    # Actual ESXCLI Command you are doing:
        # esxcli software profile update -d /vmfs/volumes/14aaa293-23aa7a7a/VMware/VMware-ESXi-5.5.0-Update3-3568722-HPE-550.9.6.5.9-Dec2016-depot-RK-fixed.zip -p HPE-ESXi-5.5.0-Update3-550.9.6.5.9-RK-Fixed --dry-run
    $esxcli2 = Get-ESXCLI -VMHost (Get-VMhost $vmhost) -V2

    # INSTALL
    ###$esxcli2.software.profile.install.CreateArgs()
    
    # UPDATE
    $arguments = $esxcli2.software.profile.update.CreateArgs()

    #$arguments # test - outputs what they are before you change values
    $arguments.dryrun = $true
    $arguments.depot = “/vmfs/volumes/14aaa293-23aa7a7a/VMware/VMware-ESXi-5.5.0-Update3-3568722-HPE-550.9.6.5.9-Dec2016-depot-RK-fixed.zip”
    $arguments.profile = "HPE-ESXi-5.5.0-Update3-550.9.6.5.9-RK-Fixed"
    #$arguments # test - outputs what they are after you change values

    write-host " "
    write-host "$vmhost Processing DryRun..."

    Try # DRYRUN
        {
            # DRYRUN SET TO TRUE
            
            # INSTALL (wipe whatever esxi is already there)
            # The Install DryRun will probably fail, even if you just are doing base-install stuff.
            # This is because it'll most likely detect VIBs to remove, and force you to use the oktoremove option/argument.
            ###$esxcli2.software.profile.install.Invoke($arguments)
            
            # UPDATE (if esxi is already there - update it)
            $esxcli2.software.profile.update.Invoke($arguments)
            
            write-host "$vmhost W00t! DryRun worked fine."
            write-host " "
            
            Try # INSTALL/UPDATE
                {
                    # Timer Start
                    $starttime = get-date -Format g
                    write-host "$vmhost Processing Offline Depot (started at $starttime)..."
                    
                    # DRYRUN SET TO FALSE
                    $arguments.dryrun = $false

                    # I won't leave these uncommented - dangerous if you aren't wanting to actually do it. ;-)

                    # INSTALL (wipe whatever esxi is already there)
                    ###$arguments.oktoremove = $true
                    ###$esxcli2.software.profile.install.Invoke($arguments)

                    #UPDATE (if esxi is already there - update it - uncomment me when ready to actually deploy - you can run all the code safely with this commented out)
                    ###$esxcli2.software.profile.update.Invoke($arguments)

                    # Timer End
                    $endtime = get-date -Format g
                    write-host "$vmhost W00t! Offline Depot completed (at $endtime). It'll need a reboot."
                    
                    # REBOOT AREA - commented off by default internally to this try statement as well as the comment block, just in case ;-)
                    <#
                    Try
                        {
                            $getdate = Get-Date -Format g
                            write-host "$vmhost rebooting at $getdate"
                            ###Restart-VMHost $vmhost -Confirm:$false | Out-Null # Doing a -RunAsync here allows the script to keep processing more things. I removed it and it kept going anyway, but feel free to add it back.
                        }
                    Catch
                        {
                            write-host "$vmhost Oh no! Reboot failed!"
                        }
                    #>
                }
            Catch
                {
                    write-host "$vmhost Oh no! Offline Depot failed!"
                }
        }
    Catch
        {
            write-host "$vmhost Oh no! DryRun failed."
            write-host " "
        }

}#end for

write-host "DONE w/Script"

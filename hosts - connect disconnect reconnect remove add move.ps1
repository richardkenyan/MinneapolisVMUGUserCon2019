# RK - 05-10-2017
# Created for CCRB
# RK - 07-26-2017
# added remove and adjusted the title to move easily find the script when I need it =)
# RK - 03-28-2018
# added how I did the tickets

# Notes:
# https://communities.vmware.com/thread/537308 - LucD of course!


##############################################################################
# Reconnect disconnected hosts
# If you need this, it is helpful.
# Doesn't prompt for PW from host
#######################################
Connect-VIServer "<whatever vCenter you need goes here>"

$VMHosts = @()
$VMHosts = Get-Cluster "<whatever you need>" | Get-VMHost | where { $_.ConnectionState -eq "Disconnected" }

foreach ($vmhost in $VMHosts) {
 write-host "reconnecting $vmhost"
  Set-VMHost -VMHost $vmhost -State "Connected"
}

Write-Host "DONE"

Write-Host " "


##############################################################################


##############################################################################
# Disconnect hosts from old vCenter
#######################################
Connect-VIServer "<whatever vCenter you need goes here>"

$vmhosts = @("")

# I did them by cluster.
$vmhosts = Get-VMHost -Location "your cluster name" | Select -ExpandProperty Name | Sort

$vmhosts


# I specified a vCenter here so I knew which vCenter I was working with.
Set-VMHost $vmhosts -Server "your vcenter here" -State "Disconnected"


# Disconnect when done so you don't get confused which vCenter you are working on
Try
{
    Disconnect-VIServer "your vcenter here" -Force -Confirm:$False
}
Catch
{
    # Nothing to do - no open connections!
}


##############################################################################


##############################################################################
# Add hosts to swing vCenter, under the datacenter, not a cluster, then move them to the proper cluster
# I discovered that adding them directly into a cluster doesn't really work well for some reason.
#######################################
Connect-VIServer "your vcenter here"

$vmhosts = @("")
#$vmhosts = @("esx01-local-lab.com")
$vmhosts = @("esx01-local-lab.com","esx02-local.lab.com","esx03-local-lab.com")
$vmhosts 

foreach($vmhost in $vmhosts){
    write-host "adding $vmhost to datacenter"

    # I specified a vCenter here so I knew which vCenter I was working with.
    Add-VMHost $vmhost -Server "your vcenter here" -User "root" -Password "<pw>" -Location "your datacenter here" -Force -RunAsync
}

foreach($vmhost in $vmhosts){
    write-host "moving $vmhost into proper cluster of whatever"
    # I specified a vCenter here so I knew which vCenter I was working with.
    # You don't have to do this in a for loop. Move-Host will accept an array, I just chose to spit out the names as I do it.
    Move-VMHost $VMHost -Server "your vcenter here" -Location "your datacenter here" -Confirm:$False -RunAsync
}

# Disconnect when done so you don't get confused which vCenter you are working on
Try
{
    Disconnect-VIServer "your vcenter here" -Force -Confirm:$False
}
Catch
{
    # Nothing to do - no open connections!
}


##############################################################################









<#
# Reconnect disconnected hosts
# If you need this, it is helpful.
# Doesn't prompt for PW from host
# However, it won't work if you are regenerating your certs. It fails with "Authenticity of the host's SSL Certificate is not verified."

Connect-VIServer "<whatever vCenter you need goes here>"

$VMHosts = @()
$VMHosts = Get-Cluster "CMH_Prod1" | Get-VMHost | where { $_.ConnectionState -eq "Disconnected" }

foreach ($vmhost in $VMHosts) {
 write-host "reconnecting $vmhost"
  Set-VMHost -VMHost $vmhost -State "Connected"

}


Write-Host "DONE"

Write-Host " "




# Disconnect hosts from old vCenter

#Connect-VIServer "vc01.cmh.synacor.com"

$vmhosts = @("")

# I did them by cluster.
$vmhosts = Get-VMHost -Location "CMH_Prod1" | Where {$_.Name -NotMatch "esx39" -and $_.Name -Notmatch "esx40" -and $_.Name -NotMatch "esx41"} | Select -ExpandProperty Name| Sort

$vmhosts


# I specified a vCenter here so I knew which vCenter I was working with.
Set-VMHost $vmhosts -Server "vc01.cmh.synacor.com" -State "Disconnected"

# Remove: Disconnect won't remove it from vCenter, you have to use Remove-VMHost
# It'll prompt you yes/yesall/no/noall if you don't set the confirm value.
#Remove-VMHost $vmhosts -Server "vc01.cmh.synacor.com" -Confirm:$False


# Disconnect when done so you don't get confused which vCenter you are working on
Try
{
    Disconnect-VIServer "vc01.cmh.synacor.com" -Force -Confirm:$False
}
Catch
{
    # Nothing to do - no open connections!
}


# Add hosts to swing vCenter, under the datacenter, not a cluster, then move them to the proper cluster
# I discovered that adding them directly into a cluster doesn't really work well for some reason.

#Connect-VIServer "vc02-cmh.cmh.synacor.com" -User "administrator@vsphere.swing" -Password "<pw>"

$vmhosts = @("")
#$vmhosts = @("esx01.cmh.synacor.com","esx02.cmh.synacor.com","esx03.cmh.synacor.com","esx08.cmh.synacor.com")
#$vmhosts = @("esx10.cmh.synacor.com","esx11.cmh.synacor.com","esx12.cmh.synacor.com","esx13.cmh.synacor.com","esx14.cmh.synacor.com")
#$vmhosts = @("esx21.cmh.synacor.com","esx22.cmh.synacor.com","esx23.cmh.synacor.com","esx24.cmh.synacor.com","esx25.cmh.synacor.com","esx26.cmh.synacor.com","esx27.cmh.synacor.com","esx28.cmh.synacor.com","esx29.cmh.synacor.com","esx30.cmh.synacor.com","esx31.cmh.synacor.com","esx33.cmh.synacor.com","esx34.cmh.synacor.com","esx35.cmh.synacor.com","esx36.cmh.synacor.com","esx37.cmh.synacor.com","esx38.cmh.synacor.com")
$vmhosts = ("esx15.cmh.synacor.com","esx16.cmh.synacor.com","esx17.cmh.synacor.com","esx18.cmh.synacor.com","esx19.cmh.synacor.com","esx20.cmh.synacor.com")
$vmhosts 


foreach($vmhost in $vmhosts){
    write-host "adding $vmhost to vc02-cmh datacenter Columbus-swing"

    # I specified a vCenter here so I knew which vCenter I was working with.
    Add-VMHost $vmhost -Server "vc02-cmh.cmh.synacor.com" -User root -Password "<pw>" -Location Columbus-swing -Force -RunAsync
}

foreach($vmhost in $vmhosts){
    write-host "moving $vmhost into proper cluster of CMH_Prod1_evc_westmere"
    # I specified a vCenter here so I knew which vCenter I was working with.
    # You don't have to do this in a for loop. Move-Host will accept an array, I just chose to spit out the names as I do it.
    Move-VMHost $VMHost -Server "vc02-cmh.cmh.synacor.com" -Location CMH_Prod1_evc_westmere -Confirm:$False -RunAsync
}

# Disconnect when done so you don't get confused which vCenter you are working on
Try
{
    Disconnect-VIServer "vc02-cmh.cmh.synacor.com" -Force -Confirm:$False
}
Catch
{
    # Nothing to do - no open connections!
}
#>


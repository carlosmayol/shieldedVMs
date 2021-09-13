# https://docs.microsoft.com/en-us/windows-server/security/guarded-fabric-shielded-vm/guarded-fabric-create-a-shielded-vm-using-powershell#provision-shielded-vm-on-a-guarded-host

#---  Pre-Req -----------------

Install-Module GuardedFabricTools -Repository PSGallery -MinimumVersion 1.0.0
#or 
# Save-Module GuardedFabricTools -Repository PSGallery -MinimumVersion 1.0.0 -Path C:\temp\

# --------------------------------

$specializationValues = @{
    "@IP4Addr-1@" = "192.168.180.111"
    "@MacAddr-1@" = "Ethernet"
    "@Prefix-1-1@" = "24"
    "@NextHop-1-1@" = "192.168.180.1"
}
New-ShieldedVM -Name 'VM-S-01' -TemplateDiskPath '.\CoreOS2019Template.vhdx' -ShieldingDataFilePath '.\CoreOS2019BLOnly.pdk' -SpecializationValues $specializationValues -VmPath c:\ClusterStorage\Volume1\ -SwitchName 'LSwitch-SET' -Wait

#WithOut Specialization

New-ShieldedVM -Name 'VM-S-01' -TemplateDiskPath 'C:\ClusterStorage\Volume1\ShieldedTEST\CoreOS2019Template.vhdx' -ShieldingDataFilePath 'C:\ClusterStorage\Volume1\ShieldedTEST\CoreOS2019BLOnly.pdk' -VmPath c:\ClusterStorage\Volume1\ -SwitchName 'LSwitch-SET' -Wait

New-ShieldedVM -Name 'VM-S-01' -TemplateDiskPath '\\lab6_ws2019_02\Temp\CoreOS2019Template.vhdx' -ShieldingDataFilePath '\\lab6_ws2019_02\Temp\CoreOS2019Template.pdk' -VmPath c:\ClusterStorage\Volume1\ -SwitchName 'LSwitch-SET' -Wait


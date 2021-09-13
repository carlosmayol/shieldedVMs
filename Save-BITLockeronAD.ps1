Get-BitLockerVolume -MountPoint "C:" | Add-BitLockerKeyProtector -RecoveryPasswordProtector

#Enable using GPO or Force using PoSH using below:

$Volume = Get-BitLockerVolume -MountPoint "C:" -ErrorAction Stop
$BLV = $Volume.keyprotector | where-object {$_.KeyProtectorType -eq "RecoveryPassword"}
#Backup recovery key to AD DS.
Backup-BitLockerKeyProtector -MountPoint "C:" -KeyProtectorId $BLV.KeyProtectorId 


<#
HOW to TEST the recovery:

Manage-bde –-forcerecovery C:

Recovery Password:
	141757-538219-194271-234553-002156-302467-426371-046541

Computer: SVMTEST1.ws2019.com
Date: 2020-10-30 13:52:25 -0800
Password ID: 89596A04-D353-4FE6-8C61-303B15A157D6

Then we can add a new TPM Protector:
Get-BitLockerVolume -MountPoint "C:" | Add-BitLockerKeyProtector -TpmProtector

System will start/reboot normally again.
#>
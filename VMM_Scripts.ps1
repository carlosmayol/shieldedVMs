# AD/VMM - HOST (LAB3_SHVMs2)
#A
get-childitem -path 'Cert:\LocalMachine\Shielded VM Local Certificates\' | Remove-Item
get-childitem -path Cert:\LocalMachine\* -Recurse | Where-Object {$_.Subject -match ".hgs.com"} | Remove-Item
get-childitem -path Cert:\LocalMachine\* -Recurse | Where-Object {$_.Subject -eq "CN=publisher.contoso.com"} | Remove-Item
Get-HgsGuardian | Remove-HgsGuardian


#B VMM Powershell
$role = Get-SCUserRole
$creds = Get-Credential
New-SCRunAsAccount -Name 'Domain Admin' -Credential $creds -UserRole $role

New-SCVMHostGroup -Name 'Guarded Hosts'

$runAsAccount = Get-SCRunAsAccount -Name 'Domain Admin'
$hostGroup = Get-SCVMHostGroup -Name 'Guarded Hosts'
Add-SCVMHost -ComputerName "lab3_shvms1.contoso.com" -RunAsynchronously -VMHostGroup $hostGroup -Credential $runAsAccount

#C
New-SelfSignedCertificate -DnsName publisher.contoso.com


# Sign the VHDX using the Shielded Template Disk Creation Wizard tool 

#or with the PowerShell below:
#$cert = New-SelfSignedCertificate -DnsName publisher.contoso.com
#Protect-TemplateDisk -Path ‘C:\ServerOS.vhdx’ -TemplateName "ServerOSTemplate" -Version 1.0.0.1 -Certificate $cert


Move 'c:\labfiles\testvm.vhdx' 'C:\ProgramData\Virtual Machine Manager Library Files\'

# At this point you need to create the VMM template with specific values that matches the values of the signed VHD/VHDX

#E

<# Powershell to create the self-signed certificate for RDP
$rdpCertificate = New-SelfSignedCertificate -DnsName '*.contoso.com'
$password = ConvertTo-SecureString -AsPlainText 'Password1' –Force
Export-PfxCertificate –Cert $RdpCertificate -FilePath c:\labfiles\rdpCert.pfx -Password $password

#Powershell to create the unattend file using the GuardedFabricTools Module

$myadminpwd = ConvertTo-SecureString "Password1" -AsPlainText -Force
$myRDPCertpwd = ConvertTo-SecureString "Password1" -AsPlainText -Force
New-ShieldingDataAnswerFile -AdminPassword $myadminpwd -ProductKey UserSupplied -RDPCertificateFilePath C:\labfiles\rdpCert.pfx -RDPCertificatePassword $myRDPCertpwd -Path c:\labfiles\unattend.xml
#>


$disk = Get-SCVirtualHardDisk -Name "testvm.vhdx"
$vsc = Get-SCVolumeSignatureCatalog -VirtualHardDisk $disk
$vsc.WriteToFile("c:\labfiles\testvm.vsc")

$relecloudmetadata = Get-SCGuardianConfiguration
$relecloudmetadata.InnerXml | Out-File c:\labfiles\HGS.xml -Encoding UTF8

#Import the Certificates (Signing and Encryption) to be used later
Get-childitem -path Cert:\LocalMachine\* -Recurse | Where-Object {$_.Subject -match ".hgs.com"}

#Finish E section

#F VMM Powershell
New-SCVMShieldingData -Name "Shielded VM" -VMShieldingDataPath "C:\labfiles\ShieldedNanoVMs.pdk" -Description "WS 2016 Nano"

#G
Set-Item wsman:localhost\client\trustedhosts -Value * -Force #Clear-Item WSMan:\localhost\Client\TrustedHosts 
$nanocreds = Get-Credential
 
Enter-PSSession -computername 192.168.100.101 -Credential $nanocreds 

get-computerinfo | fl windows*

get-process

#from the Hyper-V HOST:

Get-VMSecurity -VMName NanoVM

#Stop the VM & Try to mount the VHDX

$path = get-vm -Name NanoVM | Get-VMHardDiskDrive | %{$_.path}
mount-vhd -Path $path 

Get-BitLockerVolume



#Shielded VM Template Setup (VMM HOST)

Install-WindowsFeature RSAT-Shielded-VM-Tools
Install-Module GuardedFabricTools -Repository PSGallery -MinimumVersion 1.0.0

# PoSH Modules:
Get-Command -Module Shieldedvmdatafile
Get-Command -Module Shieldedvmtemplate
Get-Command -Module Shieldedvmprovisioning #-> (Available on the Guarded HOST only, part of the "Host Guardian Hyper-V Support"?)

<# Powershell to create the self-signed certificate for RDP
$rdpCertificate = New-SelfSignedCertificate -DnsName '*.contoso.com' #use your domain name
$password = ConvertTo-SecureString -AsPlainText 'Password1' –Force
Export-PfxCertificate –Cert $RdpCertificate -FilePath .\rdpCert.pfx -Password $password

https://docs.microsoft.com/en-us/windows-server/security/guarded-fabric-shielded-vm/guarded-fabric-tenant-creates-shielding-data#create-an-answer-file
https://docs.microsoft.com/en-us/windows-server/security/guarded-fabric-shielded-vm/guarded-fabric-sample-unattend-xml-file
#>

#PowerShell to create the unattended file using the GuardedFabricTools Module
#Basic
$adminCred = Get-Credential -Message "Local administrator account"
New-ShieldingDataAnswerFile -Path '.\ShieldedVMAnswerFile.xml' -AdminCredentials $adminCred -Force

#Domain Joined / No RDP Certificate
$adminCred = Get-Credential -Message "Local administrator account"
$domainCred = Get-Credential -Message "Domain join credentials"
New-ShieldingDataAnswerFile -Path '.\ShieldedVMAnswerFile.xml' -AdminCredentials $adminCred -ProductKeyRequired -DomainName 'ws2019.com' -DomainJoinCredentials $domainCred -StaticIPPool IPv4Address -force

<#
Shielding Data is created/owned by tenants/VM owners and contains secrets that must be protected from the fabric admin and that is needed to create shielded VMs, e.g. the shielded VM’s administrator password.  
Shielding Data is contained in a PDK file which is also encrypted.  
Once created by the tenant/VM owner, the resulting PDK file must be copied to the guarded fabric.
From <https://blogs.technet.microsoft.com/datacentersecurity/2016/06/06/step-by-step-creating-shielded-vms-without-vmm/> 
#>

# 0 - Pre-requisites

#Signing certificate for the virtual hard disk
$cert = New-SelfSignedCertificate -DnsName vmpublisher.contoso.com #use your domain name

# Create owner certificate
$Owner = New-HgsGuardian –Name 'Owner' -GenerateCertificates

# Import the HGS guardian
# If you used self-signed certificates or the certificates registered with HGS are expired, you may need to use the -AllowUntrustedRoot 
# and/or -AllowExpired flags with the Import-HgsGuardian command to bypass the security checks.
Invoke-WebRequest http://hgsservice.hgs.com/KeyProtection/service/metadata/2014-07/metadata.xml -OutFile "D:\VMShielding\HGSGuardian.xml"
$Guardian = Import-HgsGuardian -Path .\HGSGuardian.xml -Name 'HGSGuardian' -AllowUntrustedRoot

#Check the created Certificates
# Signing and Encryption certificate, used to create the PDK file (defines who is the owner of the Shielded VM -Owner parameter)
Get-childitem -path Cert:\LocalMachine\My  #VMPublisher certificate used to protect the VHDX (sign)
Get-childitem -path Cert:\LocalMachine\'Shielded VM Local Certificates' #With this certificate and the priv key you can unshield the VM!

#  1 - Protect the template VHDX
$cert = Get-childitem -path Cert:\LocalMachine\My\85B3E1410520EB3CA026E0D07E768C05510D52E1 #this is my publisher certificate
Protect-TemplateDisk -Path ".\CoreOS2019Template.vhdx" -TemplateName "CoreOS2019Template" -Version 1.0.0.1 -Certificate $cert -ProtectedTemplateTargetDiskType MicrosoftWindows

#  2 - Create a VolumeSignatureCatalog file for the template disk, to ensure the template disk is not being tampered by anyone at the deployment time
Save-VolumeSignatureCatalog -TemplateDiskPath "CoreOS2019Template.vhdx" –VolumeSignatureCatalogPath ".\Core2019OSTemplate.vsc"

#  3 - Create the  shielding data file (pdk), represent the VM owner shielded data (the organization/tenant who own the VM)
$owner = Get-HgsGuardian -Name Owner
$guardian = Get-HgsGuardian -Name HGSGuardian
$viq = New-VolumeIDQualifier -VolumeSignatureCatalogFilePath '.\Core2019OSTemplate.vsc' -VersionRule Equals
#Shielded:
New-ShieldingDataFile -ShieldingDataFilePath '.\CoreOS2019Template.pdk' -Owner $Owner -Guardian $guardian –VolumeIDQualifier $viq -AnswerFile '.\ShieldedVMAnswerFile.xml' -policy Shielded
#EncryptionOnly
New-ShieldingDataFile -ShieldingDataFilePath '.\CoreOS2019BLOnly.pdk' -Owner $Owner -Guardian $guardian –VolumeIDQualifier $viq -AnswerFile '.\ShieldedVMAnswerFile.xml' -policy EncryptionSupported

#Shielded domain Join:
New-ShieldingDataFile -ShieldingDataFilePath '.\CoreOS2019Template-djoin.pdk' -Owner $Owner -Guardian $guardian –VolumeIDQualifier $viq -AnswerFile '.\ShieldedVMAnswerFile_DomainJoin.xml' -policy Shielded
#EncryptionOnly domain Join:
New-ShieldingDataFile -ShieldingDataFilePath '.\CoreOS2019BLOnly-djoin.pdk' -Owner $Owner -Guardian $guardian –VolumeIDQualifier $viq -AnswerFile '.\ShieldedVMAnswerFile_DomainJoin.xml' -policy EncryptionSupported

# VMM Part

# Import the shielded data file (*.PDK) into VMM From the VMM PowerShell Window:
New-SCVMShieldingData -Name "CoreOS2019Template" -VMShieldingDataPath "d:\VMshielding\CoreOS2019Template.pdk" -Description "WS 2019 Core Shielded"
New-SCVMShieldingData -Name "CoreOS2019BLOnly" -VMShieldingDataPath "d:\VMshielding\CoreOS2019BLOnly.pdk" -Description "WS 2019 Core BTOnly"
New-SCVMShieldingData -Name "CoreOS2019Template-djoin" -VMShieldingDataPath "d:\VMshielding\CoreOS2019Template-djoin.pdk" -Description "WS 2019 Core Shielded Domain Joined"
New-SCVMShieldingData -Name "CoreOS2019BLOnly-djoin" -VMShieldingDataPath "d:\VMshielding\CoreOS2019BLOnly-djoin.pdk" -Description "WS 2019 Core BTOnly Domain Joined"

# Create the Template:
# Create a new template, once there Set the Name, Family and Version (Family and Version must match the information you provided while protecting the VHDX

# Define the vhdx properties in the VMM library UI:
# PTE Using Posh: 
	# From VMM "View Script":
	$libraryObject = Get-SCVirtualHardDisk -ID "73661bb8-0483-45f8-a537-0ce32ede1f81"
	# Get Operating System 'Windows Server 2016 Standard'
	$os = Get-SCOperatingSystem -ID "b808453f-f2b5-451f-894f-001c49db255a"
	Set-SCVirtualHardDisk -VirtualHardDisk $libraryObject -OperatingSystem $os -VirtualizationPlatform "HyperV" -Name "CoreOS2016Template.vhdx" -Description "" -Release "1.0.0.1" -FamilyName "CoreOS2016Template"


# Proceed to create a VM Template UI:
# PTE Using PoSH: https://docs.microsoft.com/en-us/powershell/module/virtualmachinemanager/new-scvmtemplate?view=systemcenter-ps-2019
#HyperV - HOST (LAB3_SHVMs1)
<#
PRE-REQUISITES

Hyper-V Nested VM
Get-VM lab3_shvms1 | Set-VMProcessor -ExposeVirtualizationExtensions $true
Get-VMNetworkAdapter -VMName lab3_shvms1 | Set-VMNetworkAdapter -MacAddressSpoofing On
Get-VM lab3_shvms1 | Set-VMMemory -DynamicMemoryEnabled $false -StartupBytes 8GB
Enable SecureBoot & Enable TPM - GUI

Enable SecureBoot & Enable TPM - Posh:
	#Enable SecureBoot & Enable TPM - Use GUI or:
	
	#Creating HGS Guardian
	New-HgsGuardian -Name 'UntrustedGuardian' -GenerateCertificates

	#Checking with guardian
	get-hgsguardian

	#assigning variable $owner to guardian
	$owner = get-hgsguardian 'UntrustedGuardian'

	#Generating key protector for TPM to enable it.
	$kp = New-HgsKeyProtector -Owner $owner -AllowUntrustedRoot
	 
	#Setting key protector for TPM to enable it.
	Set-VMKeyProtector -VMName 'LAB3_SHVMs1' -KeyProtector $kp.RawData

	#Enabling virtual TPM on VMName 
	Enable-VMTPM -VMNAME 'LAB3_SHVMs1'


Install Feature:
Install-WindowsFeature HostGuardian -IncludeManagementTools

#>

#A
Get-VMSwitch | Remove-VMSwitch -Force
$nic = Get-NetAdapter -Name ethernet* | %{$_.InterfaceAlias}
Set-NetIPInterface -InterfaceAlias $nic -dhcp Disabled
Start-Sleep 3

New-NetIPAddress -PrefixLength 24 -InterfaceAlias $nic -IPAddress 192.168.100.2 -DefaultGateway 192.168.100.1
Set-DnsClientServerAddress -InterfaceAlias $nic -ServerAddresses 192.168.100.1
New-VMSwitch 'External' -NetAdapterName $nic -AllowManagementOS 1
$nic = Get-NetAdapter -Name ethernet* | %{$_.InterfaceAlias}
Remove-NetIPAddress -IPAddress 169.254.* -IncludeAllCompartments

restart-computer

Get-NetIPConfiguration

#B
# One EKPUB per system, as EKPUB are unique per TPM device
(Get-PlatformIdentifier -Name $env:COMPUTERNAME).InnerXml | Out-file "c:\temp\$env:COMPUTERNAME"+"_TPM_EKpub.xml" -Encoding UTF8

#C
New-CIPolicy -Level FilePublisher -Fallback Hash -ScanPath 'c:\windows\system32\drivers' -FilePath 'C:\labfiles\HW1CodeIntegrity.xml'
ConvertFrom-CIPolicy –XmlFilePath 'C:\labfiles\CodeIntegrity.xml' –BinaryFilePath 'C:\labfiles\CodeIntegrity.p7b'

#D
# One CIPolicy per applied to Hyper-V hosts
Copy 'C:\labfiles\CodeIntegrity.p7b' C:\Windows\System32\CodeIntegrity\SIPolicy.p7b

restart-computer

#E
#Enabling DG/VBS
reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v "Locked" /t REG_DWORD /d 0 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v "EnableVirtualizationBasedSecurity" /t REG_DWORD /d 1 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v "RequireMicrosoftSignedBootChain" /t REG_DWORD /d 1 /f #New addition from GPOs enabled process
reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v "RequirePlatformSecurityFeatures" /t REG_DWORD /d 1 /f #For Nested VMs (PoC)
# reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v "RequirePlatformSecurityFeatures" /t REG_DWORD /d 3 /f #For Prod - Enable IOMMU which requires DMA in the device guard
#Enable Credential Guard too:
#reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\CredentialGuard" /v "Enabled" /t REG_DWORD /d 1 /f #(OLD)
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v "LsaCfgFlags" /t REG_DWORD /d 2 /f
#Enabling HVCI
reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" /v "Enabled" /t REG_DWORD /d 1 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" /v "Locked" /t REG_DWORD /d 0 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" /v "HVCIMATRequired" /t REG_DWORD /d 1 /f #New addition from GPOs enablement process (Require UEFI Memory Attributes Table)

#Credential Guard should be enabled and reflected here:
# reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v "LsaCfgFlags" /t REG_DWORD /d 1 /f # with UEFI Lock
# reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v "LsaCfgFlags" /t REG_DWORD /d 2 /f # with NO UEFI Lock

restart-computer

#F
# One TCGLOG for each unique class of hardware in your datacenter fabric
Get-HgsAttestationBaselinePolicy -Path 'c:\temp\HW1TPMBaseline.tcglog' -SkipValidation 
Copy 'C:\labfiles\HW1TPMBaseline.tcglog' \\192.168.100.3\c$\labfiles\


#PROCEED TO CONFIGURE THE HGS NOW AND REGISTER YOUR HYPER-V HOST 

#PLEASE CONTINUE HERE AFTER YOU HAVE REGISTERED THE HYPER-V HOST IN THE HGS

#G
Set-HgsClientConfiguration -AttestationServerUrl 'http://hgsservice.hgs.com/Attestation' -KeyProtectionServerUrl 'http://hgsservice.hgs.com/KeyProtection'

Get-HgsClientConfiguration
<#You should see:
		IsHostGuarded            : True
		Mode                     : HostGuardianService
		KeyProtectionServerUrl   : http://hgsservice.hgs.com/KeyProtection
		AttestationServerUrl     : http://hgsservice.hgs.com/Attestation
		AttestationOperationMode : Tpm
		AttestationStatus        : Passed
		AttestationSubstatus     : NoInformation
#>
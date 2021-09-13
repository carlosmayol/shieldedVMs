# HGS - HOST (LAB3_SHVMs3)

#A
Install-WindowsFeature –Name HostGuardianServiceRole –IncludeManagementTools -Restart

$dsrmPassword = ConvertTo-SecureString -AsPlainText Password1 -Force ; Install-HgsServer -HgsDomainName 'HGS.COM' -SafeModeAdministratorPassword $dsrmPassword –Restart

#B
$certificatePassword = ConvertTo-SecureString -AsPlainText SecurePass -Force

$signingCert = New-SelfSignedCertificate -DnsName "signing.HGS.COM" ; Export-PfxCertificate -Cert $signingCert -Password $certificatePassword -FilePath 'C:\labfiles\signingCert.pfx'

$encryptionCert = New-SelfSignedCertificate -DnsName "encryption.HGS.COM" ; Export-PfxCertificate -Cert $encryptionCert -Password $certificatePassword -FilePath 'C:\labfiles\encryptionCert.pfx'

#C
Copy "C:\labfiles\encryptionCert.pfx" \\192.168.100.1\c$\labfiles\
Copy "C:\labfiles\signingCert.pfx" \\192.168.100.1\c$\labfiles\

#D
$certificatePassword = ConvertTo-SecureString -AsPlainText SecurePass -Force
Initialize-HGSServer -HgsServiceName HgsService -SigningCertificatePath 'C:\labfiles\signingCert.pfx' -SigningCertificatePassword $certificatePassword -EncryptionCertificatePath 'C:\labfiles\encryptionCert.pfx' -EncryptionCertificatePassword $certificatePassword -TrustTPM

#E
Get-HgsAttestationPolicy ; Disable-HgsAttestationPolicy -Name Hgs_IommuEnabled ; Get-HgsAttestationPolicy 

#F
Get-HgsServer

<#
	Output should be:
	AttestationOperationMode       Tpm
	AttestationUrl                 {http://hgsservice.hgs.com/Attestation}
	KeyProtectionUrl               {http://hgsservice.hgs.com/KeyProtection}
#>

#PROCEED TO CONFIGURE THE HYPER-V HOST 

#PLEASE CONTINUE HERE AFTER YOU HAVE COLLECTED THE ATTESTATION FILES FROM THE HYPER-V HOST

#G
# Every individual EK needs to be added
# Only one copy of the baseline and CI policy, since they should be identical on both hosts

Add-HgsAttestationCIPolicy -Path 'c:\labfiles\CodeIntegrity.p7b' -Name 'CIPolicy' -PolicyVersion v1
Add-HgsAttestationTpmHost -Path 'c:\labfiles\LAB6_WS2019_04_TPM_EKpub.xml' -Name LAB6_WS2019_04 -PolicyVersion v1 -Force
Add-HgsAttestationTpmPolicy -Path 'c:\labfiles\HW1TPMBaseline.tcglog' -Name 'HW1TPMBaseline' -PolicyVersion v1


Get-HgsTrace -RunDiagnostics #The result should be: "Overall Result: Pass"

#PROCEED TO FINISH TO CONFIGURE THE HYPER-V HOST

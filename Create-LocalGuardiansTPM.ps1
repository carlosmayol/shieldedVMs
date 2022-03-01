#This script creates local guardian protected by TPM

$servers = "lab6_ws2019_05" , "lab6_ws2019_06"

Foreach ($srv in $servers) {

    $session = New-PSSession -ComputerName $srv

        # Create the guardian

        Invoke-Command -Session $session -ScriptBlock {

        $encCert = New-SelfSignedCertificate -Subject "$env:COMPUTERNAME  Guardian (Encryption)" -Provider "Microsoft Platform Crypto Provider" -KeyUsage DataEncipherment

        $sigCert = New-SelfSignedCertificate -Subject "$env:COMPUTERNAME  Guardian (Signing)" -Provider "Microsoft Platform Crypto Provider" -KeyUsage DigitalSignature 

        $Guardian = New-HgsGuardian -Name "$env:COMPUTERNAME Guardian (vTPM)" -EncryptionCertificateThumbprint $encCert.Thumbprint -SigningCertificateThumbprint $sigCert.Thumbprint -AllowUntrustedRoot
  
        # certutil -store  "Shielded VM Local Certificates" # to check the provider associated to the certs
               
        # Export-HgsGuardian -InputObject $Guardian -Path  $exportpath

        }

Remove-PSSession -Session $session

} #End srv loop

# You can use instead of below, create a PDK and create/convert a VM using the PDK

<#

# This below cannot be run remotely (needs double hope)

# VM Hosted in NODE [0]

$g1 = Get-HgsGuardian -CimSession  $servers[0] -Name "LAB6_WS2019_05 Guardian (vTPM)"
$g2 = Get-HgsGuardian -CimSession  $servers[1] -Name "LAB6_WS2019_06 Guardian (vTPM)"

$kp = New-HgsKeyProtector -Owner $g1 -Guardian $g2 -AllowUntrustedRoot 
# 1 owner, always required. 0+ guardians optional 

Set-VMKeyProtector -VMName "VMTEST" -KeyProtector $kp.RawData

Enable-VMTPM -VMName "VMTEST"
#>





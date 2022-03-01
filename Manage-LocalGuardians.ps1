#START Local Guarded SelfSigned.

Remove-VM -Name VMTEST -Force

New-VM -Name VMTEST -NoVHD -Generation 2

$UntrutedGuardian = New-HgsGuardian -Name "UntrustedGuardian" -GenerateCertificates #owner
# VTPM Guardian previously created by "Create Local Guardians.ps1" priv key protected by pTPM and not exportable
$vTPMGuardian = Get-HgsGuardian -Name "$env:COMPUTERNAME Guardian (vTPM)" #guardian

#owner is removed the priv and stored somewhere safe, so to modify Guardians you need to bring it back
#guardian is the bind to the host TPM - so the VM can only run in this host

$kp = New-HgsKeyProtector -Owner $UntrutedGuardian -Guardian $vTPMGuardian  -AllowUntrustedRoot 

Set-VMKeyProtector -VMName "VMTEST" -KeyProtector $kp.RawData

Enable-VMTPM -VMName "VMTEST"

Get-VM VMTEST | Get-VMSecurity


#Check

(ConvertTo-HgsKeyProtector -Bytes (Get-VMKeyProtector -VMName "VMTEST")).Owner

(ConvertTo-HgsKeyProtector -Bytes (Get-VMKeyProtector -VMName "VMTEST")).Guardians

&.\Get-VMKeyProtectors.ps1 #Needs to exist in destination.


#Update KP with new Guardian (none by default)
    $kp = ConvertTo-HgsKeyProtector -Bytes (Get-VMKeyProtector -VMName "VMTEST")

    # Add KP access to new guardian
    #$guardian = Get-HgsGuardian -Name "$env:COMPUTERNAME Guardian (vTPM)"
    $UntrutedGuardian = New-HgsGuardian -Name "UntrustedGuardian" -GenerateCertificates

    # Add KP access to new guardian
    #$guardian = Get-HgsGuardian -Name "$env:COMPUTERNAME Guardian (vTPM)"
    $UntrutedGuardian = Get-HgsGuardian -Name "UntrustedGuardian" 

    #$newkeyprotector = Grant-HgsKeyProtectorAccess -KeyProtector $kp -Guardian $guardian -AllowUntrustedRoot -AllowExpired
    $newkeyprotector = Grant-HgsKeyProtectorAccess -KeyProtector $kp -Guardian $UntrutedGuardian -AllowUntrustedRoot -AllowExpired

    # Apply the KP back to the VM
    Set-VMKeyProtector -VMName "VMTEST" -KeyProtector $newkeyprotector.RawData -Verbose

#ANYHTING BELOW  breaks the Vm ability to start (new-HgsKeyprotector can only be used before adding TPM for the first time)
<#
    Notes:
    Once you set a KP, you can only work with modified versions of it (e.g. versions that use Add-...keyprotector/Remove...keyprotector). 
    Even if you re-create the same KP using the same guardians, it will have a different symmetric transport key, which will prevent it from decrypting the vTPM state.
    The authentication tag error means the machine could decrypt the key protector, but the TK in it is not the one that was used to encrypt the TPM state
#>

#New-KP Only Owner 
    $kp = New-HgsKeyProtector -Owner $guardian  -AllowUntrustedRoot
    Set-VMKeyProtector -VMName "VMTEST" -KeyProtector $kp.RawData

#New-KP Old Owner and New Guardian
    $oldguardian = Get-HgsGuardian -Name "UntrustedGuardian"
    $kp = New-HgsKeyProtector -Owner $oldguardian -Guardian $guardian -AllowUntrustedRoot
    Set-VMKeyProtector -VMName "VMTEST" -KeyProtector $kp.RawData

# Remove guardians you no longer want:
    $newguardian = Get-HgsGuardian -Name "UntrustedGuardian"
    $guardian = Get-HgsGuardian -Name "$env:COMPUTERNAME Guardian (vTPM)"
    $kp = ConvertTo-HgsKeyProtector -Bytes (Get-VMKeyProtector -VMName "VMTEST")
    $newkeyprotector  = Revoke-HgsKeyProtectorAccess -KeyProtector $kp -Guardian $newguardian -Verbose # we can remove additional Guardians but not the primary one (owner)
    Set-VMKeyProtector -VMName "VMTEST" -KeyProtector $newkeyprotector.RawData


# Removing Priv Key for owner Guardian
#https://docs.microsoft.com/en-us/windows/win32/seccng/key-storage-and-retrieval?redirectedfrom=MSDN
certutil -store "Shielded VM Local Certificates" # I dont see the key Container path
Get-ChildItem -Path 'Cert:\LocalMachine\Shielded VM Local Certificates\'
# Remove-Item 'Cert:\LocalMachine\Shielded VM Local Certificates\192F2F0B2C19C9FEA4A2BB540DF70F29E89E9339' -deletekey  #this deletes the cert and the priv key

<# If I remove the Certs then we see this:
WARNING: The following guardians are available locally but are missing private keys. Shielded VMs will not be able to use these guardians.

	- LAB6_WS2019_05 Guardian (vTPM)
	- UntrustedGuardian
#>


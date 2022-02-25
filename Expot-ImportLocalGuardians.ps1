#Credits to lars Iwer https://gist.github.com/larsiwer


#region Export Local Guardian

$GuardianName = 'UntrustedGuardian'
#$GuardianName = "$env:COMPUTERNAME Guardian (vTPM)"

$CertificatePassword = Read-Host -Prompt 'Please enter a password to secure the certificate files' -AsSecureString

$guardian = Get-HgsGuardian -Name $GuardianName

if (-not $guardian)
{
    throw "Guardian '$GuardianName' could not be found on the local system."
}

$encryptionCertificate = Get-Item -Path "Cert:\LocalMachine\Shielded VM Local Certificates\$($guardian.EncryptionCertificate.Thumbprint)"
$signingCertificate = Get-Item -Path "Cert:\LocalMachine\Shielded VM Local Certificates\$($guardian.SigningCertificate.Thumbprint)"

if (-not ($encryptionCertificate.HasPrivateKey -and $signingCertificate.HasPrivateKey))
{
    throw 'One or both of the certificates in the guardian do not have private keys. ' + `
          'Please ensure the private keys are available on the local system for this guardian.'
}

Export-PfxCertificate -Cert $encryptionCertificate -FilePath ".\$GuardianName-encryption.pfx" -Password $CertificatePassword
Export-PfxCertificate -Cert $signingCertificate -FilePath ".\$GuardianName-signing.pfx" -Password $CertificatePassword
#endregion


#region Import Local Guardian
$NameOfGuardian = 'UntrustedGuardian'
#$NameOfGuardian =  "$env:COMPUTERNAME Guardian (vTPM)"
$CertificatePassword = Read-Host -Prompt 'Please enter the password that was used to secure the certificate files' -AsSecureString
New-HgsGuardian -Name $NameOfGuardian -SigningCertificate ".\$NameOfGuardian-signing.pfx" -SigningCertificatePassword $CertificatePassword -EncryptionCertificate ".\$NameOfGuardian-encryption.pfx" -EncryptionCertificatePassword $CertificatePassword -AllowExpired -AllowUnt
#endregion


#region Update-KeyProtector
$destinationguardianname = "$env:COMPUTERNAME Guardian (vTPM)"

# Get destination guardian
$destinationguardian = Get-HgsGuardian -Name $destinationguardianname

# Check if system is running in HGS local mode
If ((Get-HgsClientConfiguration | select -ExpandProperty Mode) -ne "Local")
{
    throw "HGS local mode required to update the key protector"
}

# Loop through all VMs existing on the local system
foreach ($vm in (Get-VM)) 
{
    # If the VM has the vTPM enabled, update the key protector
    If ((Get-VMSecurity -VM $vm).TpmEnabled -eq $true)
    {
        # Retrieve the current key protector for the virtual machine
        $keyprotector = ConvertTo-HgsKeyProtector -Bytes (Get-VMKeyProtector -VM $vm)

        # Check if the current system has the right owner keys present
        If ($keyprotector.Owner.HasPrivateSigningKey)
        {
            # Add the destination UntrustedGuardian to the key protector
            $newkeyprotector = Grant-HgsKeyProtectorAccess -KeyProtector $keyprotector -Guardian $destinationguardian `
                                                           -AllowUntrustedRoot -AllowExpired

            Write-Output "Updating key protector for $($vm.Name)"
            # Apply the updated key protector to VM
            Set-VMKeyProtector -VM $vm -KeyProtector $newkeyprotector.RawData
        }
        else
        {
            # Owner key information is not present 
            Write-Warning "Skipping $($vm.Name) - Owner key information is not present"
        }
    }
}
#endregion
$servers = "lab6_ws2019_05" , "lab6_ws2019_06"

Foreach ($srv in $servers) {

    $session = New-PSSession -ComputerName $srv

        # Create the guardian

        Invoke-Command -Session $session -ScriptBlock {

        $encCert = New-SelfSignedCertificate -Subject "$env:COMPUTERNAME  Guardian (Encryption)" -Provider "Microsoft Platform Crypto Provider" -KeyUsage DataEncipherment

        $sigCert = New-SelfSignedCertificate -Subject "$env:COMPUTERNAME  Guardian (Signing)" -Provider "Microsoft Platform Crypto Provider" -KeyUsage DigitalSignature 

        $Guardian = New-HgsGuardian -Name "$env:COMPUTERNAME Guardian (vTPM)" -EncryptionCertificateThumbprint $encCert.Thumbprint -SigningCertificateThumbprint $sigCert.Thumbprint -AllowUntrustedRoot

        $exportpath = "c:\temp\"+"$env:COMPUTERNAME Guardian (vTPM).xml"

        Export-HgsGuardian -InputObject $Guardian -Path  $exportpath

        # Get-HgsGuardian | ? {$_.Name -match "vtpm"} | Export-HgsGuardian -Path "c:\temp\Guardian (vTPM).xml"
        }

Remove-PSSession -Session $session

} #End srv loop

<#
Dont use below, rather create a PDK and convert the VM so the Owner does not become the guardians.
# Then, to create a vTPM using these guardian:

$kp = New-HgsKeyProtector -Owner (Get-HgsGuardian -CimSession -Name $servers[0] "$env:COMPUTERNAME Guardian (TPM)"), (Get-HgsGuardian -CimSession -Name $servers[0] "$env:COMPUTERNAME Guardian (TPM)") -AllowUntrustedRoot

Set-VMKeyProtector -VMName "YOURVMNAME" -KeyProtector $kp.RawData

Enable-VMTPM -VMName "YOURVMNAME"
#>



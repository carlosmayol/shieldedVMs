<# https://gist.githubusercontent.com/rpsqrd/0e0f0ede2c20aea47518d9f88a388a6b/raw/b358caca80aafc754da090b441bbaa73aa7beefd/KPCheck.ps1


.SYNOPSIS
Checks a VM key protector to see if it can successfully be unwrapped.

.PARAMETER VMName
Name of the VM to analyze

#>

#requires -Modules Hyper-V
#requires -RunAsAdministrator

param(
    [Parameter(Mandatory=$true)]
    [string]
    $VMName
)

# Get the VM KP
Write-Host "Getting the VM key protector"
$vm = Get-VM -VMName $VMName -ErrorAction Stop
$rawKP = Get-VMKeyProtector -VM $vm

# Check if KP is valid
if ($rawKP.Length -eq 4) {
    Write-Warning "The VM does not have a key protector configured. Nothing to check."
    exit 0
}

# Parse the KP
$hgsKP = ConvertTo-HgsKeyProtector -Bytes $rawKP

# Get all guardian certificates
Write-Host "Checking HGS client configuration"
$hgscc = Get-HgsClientConfiguration
$hgsGuardianTempName = "Primary HGS Guardian"

if (Get-HgsGuardian $hgsGuardianTempName -ErrorAction SilentlyContinue) {
    Write-Host "Removing temporary HGS guardian 'Primary HGS Guardian'"
    Remove-HgsGuardian $hgsGuardianTempName
}

if ($hgscc.Mode -eq 'HostGuardianService') {
    Write-Host "Querying HGS for the primary guardian certificate information. Additional certificates configured on HGS will not be evaluated."
    $metadataFile = New-TemporaryFile
    Invoke-RestMethod -Method Get -UseBasicParsing -Uri ($hgscc.KeyProtectionServerUrl + "/service/metadata/2014-07/metadata.xml") -OutFile $metadataFile -ErrorAction Continue -ErrorVariable "kpserr"
    
    if ($kpserr) {
        Write-Error "Key Protection URL is not valid or the server is not responding."
        exit 1
    }

    Write-Host "Importing the HGS certificate information locally as '$($hgsGuardianTempName)'"
    $serverName = ([uri]$hgscc.KeyProtectionServerUrl).DnsSafeHost
    $null = Import-HgsGuardian -Path $metadataFile -Name $hgsGuardianTempName -AllowExpired -AllowUntrustedRoot
}

$guardians = Get-HgsGuardian

# Enumerate guardians in the KP
Write-Host "`n"
Write-Host "Guardians configured in the VM key protector:"
$allKPGuardians = $hgsKP.Owner, $hgsKP.Guardians
$guardianFormatColumns = "Name", @{ Name = "Encryption Certificate Thumbprint"; Expression = { $_.EncryptionCertificate.Thumbprint }}, @{ Name = "Signing Certificate Thumbprint"; Expression = { $_.SigningCertificate.Thumbprint }}, @{ Name = "Local Private Key"; Expression = { $_.HasPrivateSigningKey }}
$allKPGuardians | Format-Table -Property $guardianFormatColumns

# Enumerate local guardians
Write-Host "Guardians available for this host to use:"
$guardians | Format-Table -Property $guardianFormatColumns

# Compare available guardians
$goodGuardians = @()
foreach ($kpGuardian in $hgsKP.Owner, $hgsKP.Guardians) {
    foreach ($localGuardian in $guardians) {
        if ($kpGuardian.EncryptionCertificate.Thumbprint -eq $localGuardian.EncryptionCertificate.Thumbprint) {
            $goodGuardians += $localGuardian
        }
    }
}

Write-Host "The following guardians can decrypt this VM key protector:"
$goodGuardians | Format-Table -Property $guardianFormatColumns

if ($hgscc.AttestationOperationMode -eq "HostGuardianService") {
    if ($goodGuardians.Name -notcontains $hgsGuardianTempName) {
        Write-Warning "This host is configured to use an HGS server that is not authorized to decrypt the VM key protector. Check the shielding data file to ensure the HGS guardian is included in the VM key protector."
    }

    $unavailableGuardians = $goodGuardians | Where-Object Name -ne $hgsGuardianTempName
    $unavailableNames = $unavailableGuardians.Name -join "`n`t- "
    elseif ($unavailableGuardians) {
        Write-Warning "The following local guardians will not be used by Hyper-V because HGS Client is configured to use HGS for keys. In a production environment, it's important to ensure there are no local guardians with private keys, since they can be used to disable VM protections.`n`n`t- $unavailableNames"
    }
}

$localGuardiansWithoutPK = $goodGuardians | Where-Object -FilterScript { $_.Name -ne $hgsGuardianTempName -and -not $_.HasPrivateSigningKey }
if ($localGuardiansWithoutPK) {
    $nopknames = $localGuardiansWithoutPK.Name -join "`n`t- "
    Write-Warning "The following guardians are available locally but are missing private keys. Shielded VMs will not be able to use these guardians.`n`n`t- $nopknames"
}

if (-not $goodGuardians) {
    Write-Error "There are no guardians available to decrypt the VM Key Protector. The host may be using an incorrect HGS server or the shielding data file may need to be updated with the correct guardian information for your local or HGS certificates."
}

if (Get-HgsGuardian $hgsGuardianTempName -ErrorAction SilentlyContinue) {
    Write-Host "Removing temporary HGS guardian 'Primary HGS Guardian'"
    Remove-HgsGuardian $hgsGuardianTempName
}
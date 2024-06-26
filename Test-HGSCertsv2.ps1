# https://techcommunity.microsoft.com/t5/data-center-security/frequently-asked-questions-about-hgs-certificates/ba-p/372272

<#
Instructions: Run the full script below on your HGS server to analyze your certificate configuration.
Output: Summary of all certificates tested. For test-by-test information, inspect the Tests property of the $results object
#>

Write-Host ""
Write-Host ""
Write-Host "Beginning Certificate tests" -ForegroundColor Green
Write-Host ""
 
# Get all KPS certificates
$AllKpsCertificates = Get-HgsKeyProtectionCertificate
$CommunicationsCertificate = Get-HgsKeyProtectionConfiguration
$AllKpsCertificates += [pscustomobject] @{
    Certificate = $CommunicationsCertificate.CommunicationsCertificate
    CertificateData = $CommunicationsCertificate.CommunicationsCertificateData
    CertificateType = "Communications"
}
 
$results = @()
 
foreach ($cert in $AllKpsCertificates) {
    $certResult = @{
        Thumbprint = $cert.Certificate.Thumbprint
        CertificateType = $cert.CertificateType
        Tests = @{}
    }
    $errprefix = "TEST FAILURE: The {0} certificate with thumbprint {1}" -f $cert.CertificateType.ToString(), $cert.Certificate.Thumbprint
 
    # Check basic certificare requirements
    if ($cert.Certificate.GetKeyAlgorithm() -eq '1.2.840.113549.1.1.1') {
        $certResult.Tests.RsaAlgorithm = 'Passed'
    }
    else {
        $certResult.Tests.RsaAlgorithm = 'Failed'
        Write-Warning "$errprefix does use the RSA algorithm."
    }
 
    if ($cert.Certificate.Version -eq 3) {
        $certResult.Tests.CertificateVersion = 'Passed'
    }
    else {
        $certResult.Tests.CertificateVersion = 'Failed'
        Write-Warning "$errprefix is not a version 3 certificate."
    }
 
    if ($cert.Certificate.PublicKey.Key.KeySize -ge 2048) {
        $certResult.Tests.KeySize = 'Passed'
    }
    else {
        $certResult.Tests.KeySize = 'Failed'
        Write-Warning "$errprefix has a key length shorter than 2048 bits."
    }
 
    # Check key usage
    if ($cert.CertificateType -eq 'Encryption' -or $cert.CertificateType -eq 'Communications') {
        if ($cert.Certificate.Extensions['2.5.29.15'].KeyUsages.HasFlag([System.Security.Cryptography.X509Certificates.X509KeyUsageFlags]::DataEncipherment)) {
            $certResult.Tests.KeyUsage = 'Passed'
        }
        else {
            $certResult.Tests.KeyUsage = 'Failed'
            Write-Warning "$errprefix does not allow the DataEncipherment key usage."
        }
        if ($cert.Certificate.Issuer -eq $cert.Certificate.Subject) {
            $certResult.Tests.KeyUsage = 'Skipped'
            Write-Warning "$errprefix this seems to be a self-signed certificate, don't use it in production."
        }
    }
    else {
        if ($cert.Certificate.Extensions['2.5.29.15'].KeyUsages.HasFlag([System.Security.Cryptography.X509Certificates.X509KeyUsageFlags]::DigitalSignature)) {
            $certResult.Tests.KeyUsage = 'Passed'
        }
        else {
            $certResult.Tests.KeyUsage = 'Failed'
            Write-Warning "$errprefix does not allow the DigitalSignature key usage."
        }
    }
 
    # Check if certificate was added by thumbprint for additional tests
    if ($cert.CertificateData -is [Microsoft.Windows.KpsServer.Common.CertificateManagement.CertificateReference]) {
        if ($cert.Certificate.HasPrivateKey) {
            $certResult.Tests.PrivateKeyPresent = 'Passed'
            
 
            # Try getting CNG info the "real" way
            if ((Get-TypeData -TypeName System.Security.Cryptography.X509Certificates.X509CertificateExtensionMethods)) {
                if ([System.Security.Cryptography.X509Certificates.X509CertificateExtensionMethods]::HasCngKey($cert.Certificate)) {
                    $providertype = 0
 
                    $cngKeyInfo = [System.Security.Cryptography.X509Certificates.X509Certificate2ExtensionMethods]::GetCngPrivateKey($cert.Certificate)
                    $provider = $cngKeyInfo.Provider
                    $container = $cngKeyInfo.UniqueName
                }
                else {
                    $providertype = 'CAPI'
                    $provider = $null
                    $container = $null
                }
            }
            else {
                # Try to replicate test using regex parsing
                $certutiloutput = certutil.exe -v -store `"$($cert.CertificateData.StoreName)`" $cert.Thumbprint
                $providertyperegex = [regex]'^ *ProviderType = (.*)$'
                $providerregex = [regex]'^ *Provider = (.*)$'
                $containerregex = [regex]'^ *Unique container name: (.*)$'
                $providertype = $provider = $container = $null
                foreach ($line in $certutiloutput) {
                    if (-not $providertype -and $providertyperegex.IsMatch($line)) {
                        $providertype = $providertyperegex.Match($line).Groups[1].Value
                    }
                    elseif (-not $provider -and $providerregex.IsMatch($line)) {
                        $provider = $providerregex.Match($line).Groups[1].Value
                    }
                    elseif (-not $container -and $containerregex.IsMatch($line)) {
                        $container = $containerregex.Match($line).Groups[1].Value
                    }
                }
            }
 
            if ($providertype -eq 0) {
                $certResult.Tests.CngKey = 'Passed'
 
                if ($provider -eq 'Microsoft Software Key Storage Provider') {
                    $keyFilePaths = Join-Path "$env:ALLUSERSPROFILEMicrosoftCryptoKeys", "$env:ALLUSERSPROFILEMicrosoftCryptoSystemKeys" -ChildPath $container
        
                    if (Test-Path $keyFilePaths[0]) {
                        $keyFile = $keyFilePaths[0]
                    }
                    elseif ((Test-Path $keyFilePaths[1])) {
                        $keyFile = $keyFilePaths[1]
                    }
                    else {
                        $certResult.Tests.PrivateKeyPermissions = 'Failed'
                        Write-Warning "$errprefix has a private key that could not be found. Please verify the HGS gMSA has access to the private key."
                    }
        
                    if ($keyFile) {
                        $keyAcl = Get-Acl $keyFile
                        $gmsaAccount = (Get-IISAppPool -Name KeyProtection).ProcessModel.UserName
                        $accessRule = $keyAcl.Access | Where-Object IdentityReference -eq $gmsaAccount
                        if ($accessRule -and $accessRule.AccessControlType -eq 'Allow' -and $accessRule.FileSystemRights.HasFlag([System.Security.AccessControl.FileSystemRights]::Read)) {
                            $certResult.Tests.PrivateKeyPermissions = 'Passed'
                        }
                        else {
                            $certResult.Tests.PrivateKeyPermissions = 'Failed'
                            Write-Warning "$errprefix is not configured to allow the HGS gMSA account access to the private key."
                        }
                    }
                }
                else {
                    $certResult.Tests.PrivateKeyPermissions = 'Skipped'
                    Write-Warning ("TEST SKIPPED: The {0} certificate with thumbprint {1} uses a custom key storage provider. This script cannot check if the HGS gMSA has access to the private key." -f $cert.CertificateType, $cert.Certificate.Thumbprint)
                }
            }
            else {
                $certResult.Tests.CngKey = 'Failed'
                $certResult.Tests.PrivateKeyPermissions = 'Skipped'
                Write-Warning "$errprefix is using a legacy crypto service provider to access its private key instead of a key storage provider."
            }
        }
        else {
            $certResult.Tests.PrivateKeyPresent = 'Failed'
            $certResult.Tests.PrivateKeyPermissions = 'Skipped'
            $certResult.Tests.CngKey = 'Skipped'
            Write-Warning "$errprefix does not have a private key associated with it."
        }
 
        
    }
    else {
        # The certificate was added by PFX
        $certResult.Tests.PrivateKeyPresent = 'Passed'
        $certResult.Tests.PrivateKeyPermissions = 'Passed'
        $certResult.Tests.CngKey = 'Passed'
    }
 
    # Compute final result
    if ($certResult.Tests.Values -contains 'Failed') {
        $certResult.Result = 'Failed'
    }
    elseif ($certResult.Tests.Values -contains 'Skipped') {
        $certResult.Result = 'Passed (some tests skipped)'
    }
    else {
        $certResult.Result = 'Passed'
    }
 
     #$results += [pscustomobject] $certResult
    $h = New-Object psobject
    $h | Add-Member -MemberType NoteProperty -name "Thumbprint" -Value $certResult.Thumbprint
    $h | Add-Member -MemberType NoteProperty -name "CertificateType" -value $certResult.CertificateType
    $h | Add-Member -MemberType NoteProperty -name "Overall" -value $certResult.Result
    $h | Add-Member -MemberType NoteProperty -name "Test1" -value RsaAlgorithm
    $h | Add-Member -MemberType NoteProperty -name "Value1" -value $certResult.Tests.RsaAlgorithm
    $h | Add-Member -MemberType NoteProperty -name "Test2" -value CertificateVersion
    $h | Add-Member -MemberType NoteProperty -name "Value2" -value $certResult.Tests.CertificateVersion
    $h | Add-Member -MemberType NoteProperty -name "Test3" -value KeySize
    $h | Add-Member -MemberType NoteProperty -name "Value3" -value $certResult.Tests.KeySize
    $h | Add-Member -MemberType NoteProperty -name "Test4" -value KeyUsage
    $h | Add-Member -MemberType NoteProperty -name "Value4" -value $certResult.Tests.KeyUsage
    $h | Add-Member -MemberType NoteProperty -name "Test5" -value PrivateKeyPresent
    $h | Add-Member -MemberType NoteProperty -name "Value5" -value $certResult.Tests.PrivateKeyPresent
    $h | Add-Member -MemberType NoteProperty -name "Test6" -value CngKey
    $h | Add-Member -MemberType NoteProperty -name "Value6" -value $certResult.Tests.CngKey
    $h | Add-Member -MemberType NoteProperty -name "Test7" -value PrivateKeyPermissions
    $h | Add-Member -MemberType NoteProperty -name "Value7" -value $certResult.Tests.PrivateKeyPermissions
    $results += $h
}
 
#Format-Table -InputObject $results -AutoSize -Property 'Thumbprint', 'CertificateType', 'Result' #Original Output

#$results | fl

$results | Format-List Thumbprint,CertificateType, `
 @{ Label = "Overall"
    Expression =
    {
        switch ($_.Overall)
        {
            'Passed' { $color = "92"; break }
            'Failed' { $color = '91'; break }
            'Passed (some tests skipped)' { $color = "93"; break }
           default { $color = "90" }
        }
        $e = [char]27
       "$e[${color}m$($_.Overall)${e}[0m"
    }
 }, `
 @{Label = "RsaAlgorithm";Expression ={$_.Value1}},`
 @{Label = "CertificateVersion";Expression ={$_.Value2}},`
 @{Label = "KeySize";Expression ={$_.Value3}},`
 @{Label = "KeyUsage";Expression ={$_.Value4}},`
 @{Label = "PrivateKeyPresent";Expression ={$_.Value5}},`
 @{Label = "CngKey";Expression ={$_.Value6}},`
 @{Label = "PrivateKeyPermissions";Expression ={$_.Value7}}
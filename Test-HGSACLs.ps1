#Requires -module GuardedFabricTools
# This process is not useful if the certificates in use are PFX as they do not exist in the certificate local store

import-module GuardedFabricTools

$certs = HgsKeyProtectionCertificate
foreach ($cert in $certs) {

$cert.Certificate.Acl

}
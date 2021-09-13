#A.	Add DNS resolution from Hgs.com to Contoso.com
Add-DnsServerConditionalForwarderZone -Name "contoso.com" -ReplicationScope "Forest" -MasterServers 192.168.100.1
#B.	Add one-way trust relationship between Hgs.com and Contoso.com
netdom trust HGS.COM /domain:contoso.com /userD:contoso.com\Administrator /passwordD:Password1 /add
#C.	Change Attestation type from TPM to Admin-trust
Set-HgsServer -TrustActiveDirectory
#D.	Add the Global Security Group to be validated (for simplicity will use Domain computers).
Add-HgsAttestationHostGroup -Name "Domain Computers" -Identifier "S-1-5-21-3988143385-3841595786-2883746965-515"
#E.	Verify the group was added correctly
Get-HgsAttestationHostGroup

#Now on the Hyper-V Host (LAB3_SHVMS1):
#A.	Initiate an attestation attempt:	
Get-HgsClientConfiguration
#B.	If IsHostGuarded property does not return True, you can run the HGS diagnostics tool, Get-HgsTrace, to investigate:
Get-HgsTrace -RunDiagnostics -Detailed

<#
 -------------------------------------- Standard disclaimer ----------------------------------------------------------------------
    THIS CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, 
    INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.  

    You have the right to modify it for your own purposes, provided that You agree: 
    (i) to not distribute, publish or market this code; 
    and (ii) to indemnify, hold harmless, and defend Us and Our suppliers from and against any claims or 
    lawsuits, including attorneys’ fees, that arise or result from the use or distribution of the Sample Code.
    ---------------------------------------------------------------------------------------------------------------------------------
    The sample scripts provided here are not supported under any Microsoft standard support program or service.   
    All scripts are provided AS IS without warranty of any kind. 
    Microsoft further disclaims all implied warranties including, without limitation, any implied warranties of merchantability 
    or of fitness for a particular purpose. The entire risk arising out of the use or performance of the sample scripts and documentation remains with you.
    In no event shall Microsoft, its authors, or anyone else involved in the creation, production, or delivery of the scripts be liable for any damages 
    whatsoever (including, without limitation, damages for loss of business profits, business interruption, loss of business information, or other pecuniary loss)
    arising out of the use of or inability to use the sample scripts or documentation, even if Microsoft has been advised of the possibility of such damages. 

 ---------------------------------------------------------------------------------------------------------------------------------

#>


# Source from GitHUB
# https://github.com/MicrosoftDocs/windows-itpro-docs/tree/public/windows/security/threat-protection/windows-defender-application-control
#-----------------------------------------------------------------------------------------------------------
# UMCI enabled & & Driver blocked rules merge  -> AUDIT MODE

#Get current date/time
$Date = Get-Date -f yyyyMMdd

#Blocked UMCI Apps:
$content=Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/MicrosoftDocs/windows-itpro-docs/master/windows/security/threat-protection/windows-defender-application-control/microsoft-recommended-block-rules.md
#find start and end

$XMLStart=$content.Content.IndexOf("<?xml version=")
$XMLEnd=$content.Content.IndexOf("</SiPolicy>")+11 # 11 is lenght of string
#create xml
[xml]$XML=$content.Content.Substring($xmlstart,$XMLEnd-$XMLStart) #find XML part
($XML).Save("c:\temp\Microsoft-recommended-block-rules.xml")

#Blocked Drivers:
$content2=Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/MicrosoftDocs/windows-itpro-docs/public/windows/security/threat-protection/windows-defender-application-control/microsoft-recommended-driver-block-rules.md
 
#find start and end
$XMLStart=$content2.Content.IndexOf("<?xml version=")
$XMLEnd=$content2.Content.IndexOf("</SiPolicy>")+11 # 11 is length of string
#create xml
[xml]$XML=$content2.Content.Substring($xmlstart,$XMLEnd-$XMLStart) #find XML part
($XML).Save("c:\temp\Microsoft-recommended-driver-block-rules.xml")


#Create mergedPolicy
#Copy the example policy from “C:\Windows\schemas\CodeIntegrity\ExamplePolicies\AllowMicrosoft.xml”
$AllowMicrosoft = "c:\temp\AllowMicrosoft.xml"
$RecommendedBlockRules = "c:\temp\Microsoft-recommended-block-rules.xml"
$RecommendedDriverBlockRules = "c:\temp\Microsoft-recommended-driver-block-rules.xml"
$Cipolicy = "c:\temp\AllowMicrosoft_DenyDrivers_and_Apps_Audit.xml"

Merge-CIPolicy -PolicyPaths $AllowMicrosoft,$RecommendedBlockRules,$RecommendedDriverBlockRules  -OutputFilePath $Cipolicy

Set-RuleOption -FilePath $cipolicy -Option 3
Set-HVCIOptions -FilePath $Cipolicy -Enabled

#Setting Metadata
#Set-CIPolicyIdInfo $Cipolicy -ResetPolicyID # not compatible with WS2016/WS2019, CI needs PolicyTypeID after some tests.
Set-CIPolicyVersion -FilePath $Cipolicy -Version '1.0.0'
Set-CIPolicyIdInfo -FilePath $Cipolicy -PolicyId "AllowMicrosoft_DenyDrivers_and_Apps_Audit_$date" -PolicyName "AllowMicrosoft_DenyDrivers_and_Apps_Audit"


$bin = ConvertFrom-CIPolicy -XmlFilePath $cipolicy -BinaryFilePath "$cipolicy.bin"
# WARNING: "Warning: Please use new policy format which has PolicyID and BasePolicyID, but no PolicyTypeID. You can use -MultiplePolicyFormat with New-CIPolicy or use -Reset with Set-CIPolicyIdInfo
# Examples policies do not have PolicyTypeID, Recommended Blocked Rules policy does HAVE PolicyTypeID.

#Creating HASH of the binary file
#New Crypto Obj for Hash gattering
$sha2 = New-Object -TypeName System.Security.Cryptography.SHA256CryptoServiceProvider
$sha2Hash = [System.BitConverter]::ToString( $sha2.ComputeHash( [System.IO.File]::ReadAllBytes("$bin") ) ) 
$sha2Hash = $sha2Hash.Replace("-", "")
$sha2Hash | Set-Content -Path "$Cipolicy.txt"
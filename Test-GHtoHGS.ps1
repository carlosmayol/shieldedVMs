# Retrieving the current Host Guardian Service client configuration
$HgsClientConfiguration = Get-HgsClientConfiguration

If (($HgsClientConfiguration| Select-Object -ExpandProperty Mode) -eq "HostGuardianService") { 
  # The destination system is configured to use a Host Guardian Service
  # Build the URLs to check
  $AttestationUrl = $HgsClientConfiguration.AttestationServerUrl, "Getinfo" -join "/"
  $KeyProtectionlUrl = $HgsClientConfiguration.KeyProtectionServerUrl, "service/metadata/2014-07/metadata.xml" -join "/"
  $ats = $null
  $kps = $null
  Write-Host ""
  write-host "Testing Attestation webservice ...." -ForegroundColor Yellow
  #$ats = Invoke-WebRequest -UseBasicParsing -Uri $AttestationUrl | Select-Object -ExpandProperty StatusDescription
  try{$ats = Invoke-WebRequest -UseBasicParsing -Uri $AttestationUrl | Select-Object -ExpandProperty StatusDescription }
  catch{write-host "Runtime Error"} 
  write-host "Testing Keyprotector webservice ...." -ForegroundColor Yellow
  Write-Host ""
  #$kps = Invoke-WebRequest -UseBasicParsing -Uri $KeyProtectionlUrl | Select-Object -ExpandProperty StatusDescription 
  try{$kps = Invoke-WebRequest -UseBasicParsing -Uri $KeyProtectionlUrl | Select-Object -ExpandProperty StatusDescription }
  catch{"Runtime Error"}
  }
  
else 
{ # Destination system is running in local mode
  write-host "Your system is not Guarded..." -ForegroundColor Cyan 
}

#Print status of HGS connectivity test
If ($ats -ne "OK") {
  Write-Host "Your connection to HGS attestation service is not working" -ForegroundColor Red -BackgroundColor Black
  Write-Host "" 
}
Elseif ($kps -ne "OK") {
  Write-Host "Your connection to HGS keyprotector service is not working" -ForegroundColor Red -BackgroundColor Black
  Write-Host ""   
  } 
else 
{
  write-host "Your connection to $AttestationUrl is $ats" -ForegroundColor Green
  write-host "Your connection to $KeyProtectionlUrl is $kps" -ForegroundColor Green
}

#Connectivity section

$action = Read-Host "Do you want to lunch a HGS client connectivity test? (Y/N)" 
switch ($action) {
  Y {[string]$version = Get-WmiObject -Class win32_operatingsystem | Select-Object -ExpandProperty version -First 1
    switch ($version) {
      10.0.17763 {
                Write-Host "--> WS 2019 LTSC detected " -ForegroundColor Yellow
                Test-HgsClientConfiguration
                Get-service HgClientService | format-table Name, status
                Write-host " Ready to start a tcp connection loop"
                Pause
                  do
                  {
                    $x= $x++
                    Get-NetTCPConnection -RemotePort 80 -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 2
                  }
                until ($x -gt 10 )
                }
        10.0.14393 {

                Write-Host "--> WS 2016 LTSC detected " -ForegroundColor Yellow
                #Test-HgsClientConfiguration #not applicable to WS2016
                #forcing a dummy change in the HGS client settings
                Set-HgsClientConfiguration -AttestationServerUrl 'http://dummy' -KeyProtectionServerUrl 'http://dummy'
                Set-HgsClientConfiguration -AttestationServerUrl $HgsClientConfiguration.AttestationServerUrl -KeyProtectionServerUrl $HgsClientConfiguration.KeyProtectionServerUrl
                Get-service HgClientService | format-table Name, status
                Write-host " Ready to start a tcp connection loop"
                Pause
                do
                {
                    $x= $x++
                    Get-NetTCPConnection -RemotePort 80 -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 2
                }
                until ($x -gt 10)
                }
      Default {write-host "OS not supported...finishing"; exit}
      } }
  N {write-host "Finishing...."; exit }
  Default {write-host "Selection not supported...finishing"; exit}
}  #end switch "action"
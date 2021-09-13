#v1.0 Script

$CIquery = @"
<QueryList>
  <Query Id="0" Path="Microsoft-Windows-CodeIntegrity/Operational">
    <Select Path="Microsoft-Windows-CodeIntegrity/Operational">*[System[Provider[@Name='Microsoft-Windows-CodeIntegrity'] and (EventID=3076 or EventID=3077) and TimeCreated[timediff(@SystemTime) &lt;= 2592000000]]]</Select>
  </Query>
</QueryList>
"@

#Get current date/time
$Date = Get-Date -f yyyy_MM_dd_hhmmss

$cluster = Read-Host "Input ClusterName"
#$servers = "lab6_ws2019_03", "lab6_ws2019_04"
$servers = (Get-ClusterNode -cluster $cluster).Name

ForEach ($server in $servers) {
    $events = Get-WinEvent -FilterXml $CIQuery -ComputerName $server

    ForEach ($Event in $Events) {
        # Convert the event to XML
        $eventXML = ([xml]$Event.ToXml()).Event.EventData.Data
        Add-Member -InputObject $Event -MemberType NoteProperty -Force -Name  AffectedFile -Value $eventXML[1].'#text'
        Add-Member -InputObject $Event -MemberType NoteProperty -Force -Name  Process -Value $eventXML[3].'#text'
        Add-Member -InputObject $Event -MemberType NoteProperty -Force -Name  SignedLevelReq -Value $eventXML[4].'#text'
        Add-Member -InputObject $Event -MemberType NoteProperty -Force -Name  SignedLevelVal -Value $eventXML[5].'#text'
        Add-Member -InputObject $Event -MemberType NoteProperty -Force -Name  Process -Value $eventXML[3].'#text'
	      Add-Member -InputObject $Event -MemberType NoteProperty -Force -Name  Status -Value $eventXML[6].'#text'
	      Add-Member -InputObject $Event -MemberType NoteProperty -Force -Name  OriginalFileName -Value $eventXML[24].'#text'
        Add-Member -InputObject $Event -MemberType NoteProperty -Force -Name  InternalName -Value $eventXML[26].'#text'
	      Add-Member -InputObject $Event -MemberType NoteProperty -Force -Name  PolicyName -Value $eventXML[18].'#text'
	      Add-Member -InputObject $Event -MemberType NoteProperty -Force -Name  PolicyId -Value $eventXML[20].'#text'

    }
    write-host "Showing last 30 days events for 3076 & 3077 for server $server" -ForegroundColor Yellow
    $Events | fl TimeCreated, Id, MachineName,Process, AffectedFile, Status,SignedLevelReq ,SignedLevelVal, OriginalFileName,InternalName,PolicyName,PolicyId  #Message ommited in the output
    #$Events | Select TimeCreated, Id, MachineName,Process, AffectedFile, Status,SignedLevelReq ,SignedLevelVal, OriginalFileName,InternalName,PolicyName,PolicyId|  Export-Csv -Path .\$date-CIPolicyEvents.csv -Append -NoTypeInformation
}


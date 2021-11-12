<#

#Resources to extract the event data
#https://docs.microsoft.com/en-us/windows/win32/wes/consuming-events#xpath-10-limitations
#https://docs.microsoft.com/en-us/dotnet/api/system.diagnostics.eventing.reader.eventlogrecord.toxml?view=netframework-4.8#System_Diagnostics_Eventing_Reader_EventLogRecord_ToXml
#https://powershell.anovelidea.org/powershell/windows-event-logs-eventdata/

#Looking to the template event structure
$cievent = Get-Winevent -ListProvider Microsoft-Windows-CodeIntegrity
$cievent.Events | ? {$_.id -eq 3099}

#>

#v1.1 Script

$CIquery = @"
<QueryList>
  <Query Id="0" Path="Microsoft-Windows-CodeIntegrity/Operational">
    <Select Path="Microsoft-Windows-CodeIntegrity/Operational">*[System[Provider[@Name='Microsoft-Windows-CodeIntegrity'] and (EventID=3099)]]</Select>
  </Query>
</QueryList>
"@

#Get current date/time
$Date = Get-Date -f yyyy_MM_dd_hhmmss

$cluster = Read-Host "Input ClusterName"
#$servers = "lab6_ws2019_03", "lab6_ws2019_04"
$servers = (Get-ClusterNode -cluster $cluster).Name

ForEach ($server in $servers) {
    $events = Get-WinEvent -FilterXml $CIQuery -ComputerName $server -MaxEvents 10

    ForEach ($Event in $Events) {
        # Convert the event to XML
        $eventXML = ([xml]$Event.ToXml()).Event.EventData.Data
        Add-Member -InputObject $Event -MemberType NoteProperty -Force -Name  PolicyHash -Value $eventXML[8].'#text'
        Add-Member -InputObject $Event -MemberType NoteProperty -Force -Name  PolicyNameBuffer -Value $eventXML[1].'#text'
        Add-Member -InputObject $Event -MemberType NoteProperty -Force -Name  PolicyIdBuffer -Value $eventXML[3].'#text'
        Add-Member -InputObject $Event -MemberType NoteProperty -Force -Name  TypeOfPolicy -Value $eventXML[4].'#text'
        Add-Member -InputObject $Event -MemberType NoteProperty -Force -Name  Status -Value $eventXML[5].'#text'

        $hex = $eventXML[6].'#text'
        $Audit = ([system.convert]::ToString($hex ,2)).substring(0, 16)[15]
        $UMCI = ([system.convert]::ToString($hex ,2)).substring(0, 16)[3]

        Add-Member -InputObject $Event -MemberType NoteProperty -Force -Name  Options -Value $hex
        Add-Member -InputObject $Event -MemberType NoteProperty -Force -Name  AuditMode -Value $Audit
        Add-Member -InputObject $Event -MemberType NoteProperty -Force -Name  UMCI -Value $UMCI
        
    }
    write-host "Showing the last 10 events 3099 for server $server" -ForegroundColor Yellow
    #$Events | ft TimeCreated, Id, MachineName, PolicyNameBuffer, PolicyIdBuffer, TypeOfPolicy, Status -AutoSize 
    $Events | ft TimeCreated, Id, MachineName, PolicyNameBuffer, PolicyIdBuffer, Status, Options, AuditMode, UMCI  -AutoSize
}


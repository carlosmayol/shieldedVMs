#Take a look at the settings

Get-ItemProperty –Path HKLM:\System\CurrentControlSet\Control\CrashControl –Name CrashDumpEnabled

Get-ItemProperty –Path HKLM:\System\CurrentControlSet\Control\CrashControl\ForceDumpsDisabled -Name GuardedHost

Get-ItemProperty –Path HKLM:\System\CurrentControlSet\Control\CrashControl –Name FilterPages

#Configure Active memory dump and Removing GuardedHost restriction

Set-ItemProperty –Path HKLM:\System\CurrentControlSet\Control\CrashControl\ForceDumpsDisabled –Name GuardedHost –value 0

Set-ItemProperty –Path HKLM:\System\CurrentControlSet\Control\CrashControl –Name CrashDumpEnabled –value 1

Set-ItemProperty –Path HKLM:\System\CurrentControlSet\Control\CrashControl –Name FilterPages –value 1

#Set it back to Automatic memory dump (default)
Set-ItemProperty –Path HKLM:\System\CurrentControlSet\Control\CrashControl\ForceDumpsDisabled –Name GuardedHost –value 1

Set-ItemProperty –Path HKLM:\System\CurrentControlSet\Control\CrashControl –Name CrashDumpEnabled –value 7

Remove-ItemProperty –Path HKLM:\System\CurrentControlSet\Control\CrashControl –Name FilterPages –value 1
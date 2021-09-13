@echo off
ECHO These commands will enable tracing:
@echo on

logman create trace "HGSATS" -ow -o c:\HGSATS.etl -p "Microsoft-Windows-HostGuardianService-Attestation" 0xffffffffffffffff 0xff -nb 16 16 -bs 1024 -mode Circular -f bincirc -max 4096 -ets

@echo off
echo
ECHO Reproduce your issue and enter any key to stop tracing
@echo on
pause
logman stop "HGSATS" -ets

@echo off
echo Tracing has been captured and saved successfully at c:\HGSATS.etl
pause


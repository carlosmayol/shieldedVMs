::ShieldedVM Provisioning Providers

@echo off
ECHO These commands will enable tracing:
@echo on

logman create trace "ShieldedVMProvision" -ow -o c:\ShieldedVMProvision.etl -p "Microsoft-Windows-ShieldedVM-ProvisioningSecureProcess" 0xffffffffffffffff 0xff -nb 16 16 -bs 1024 -mode Circular -f bincirc -max 4096 -ets
logman update trace "ShieldedVMProvision" -p "Microsoft-Windows-ShieldedVM-ProvisioningService" 0xffffffffffffffff 0xff -ets

@echo off
echo
ECHO Reproduce your issue and enter any key to stop tracing
@echo on
pause
logman stop "ShieldedVMProvision" -ets

@echo off
echo Tracing has been captured and saved successfully at c:\ShieldedVMProvision.etl
pause
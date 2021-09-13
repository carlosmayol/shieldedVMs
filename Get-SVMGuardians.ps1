#(ConvertTo-HgsKeyProtector -Bytes (Get-VMKeyProtector -VMName "SVMTEST1")).Owner
#(ConvertTo-HgsKeyProtector -Bytes (Get-VMKeyProtector -VMName "SVMTEST1")).Guardians


(ConvertTo-HgsKeyProtector -Bytes (Get-VMKeyProtector -VMName "VMTEST")).Owner
(ConvertTo-HgsKeyProtector -Bytes (Get-VMKeyProtector -VMName "VMTEST")).Guardians
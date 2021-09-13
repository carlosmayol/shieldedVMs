$name = (Get-Cluster).Name

Stop-ClusterResource -Name "Cluster Name"

New-ClusterNameAccount -Name $name -Domain hgs.com -ManagementPointNetworkType Singleton -Verbose

#Add cluster IP resource:

Add-ClusterResource -Name "Cluster IP Address" -Group "Cluster Group" -ResourceType "IP Address"

#Then configure the resource (network and IP setting (static / dynamic) and set dependency.

$ClusterNets = Get-ClusterNetwork | Where-Object {$_.role -eq "3"}

$ClusterCAPNet = $ClusterNets[0] | select -ExpandProperty Name 

#Get-ClusterResource -Name "Cluster IP Address" | Set-ClusterParameter -Multiple @{"Address"="192.168.180.0";"Network"="Cluster Network 1";"EnableDhcp"=1} #disabling as I want static IP

Get-ClusterResource -Name "Cluster IP Address"  | Set-ClusterParameter -Multiple @{"Address"="192.168.180.131";"SubnetMask"="255.255.255.0";"Network"="$ClusterCAPNet";"EnableDhcp"=0}

Set-ClusterResourceDependency -Resource "Cluster Name" -Dependency "[Cluster IP Address]"

Start-ClusterResource -Name "cluster name"

#Checking
Get-Cluster
Get-ClusterGroup
Get-ClusterResource
Get-Clusterresource | Get-ClusterResourceDependency
Resolve-DnsName -Name $name -NoHostsFile
Test-NetConnection $name
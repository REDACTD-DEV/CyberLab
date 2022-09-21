## Deploy the VM
```posh
#Create VM
$VMName = "DHCP"
$Params = @{
	Name				=	$VMName
	MemoryStartupBytes	=	1GB
	Path				=	"E:\VM\$VMName"
	Generation			=	2
	SwitchName			=	"NATSwitch"
}
New-VM @Params

#Edit VM
$Params = @{
	Name				=	$VMName
	ProcessorCount		=	4
	DynamicMemory		=	$true
	MemoryMinimumBytes	=	1GB
	MemoryMaximumBytes	=	4GB
}
Set-VM @Params

#Specify CPU settings
$Params = @{
	VMName			=	$VMName
	Count			=	8
	Maximum			=	100
	RelativeWeight	=	100
}
Set-VMProcessor @Params

#Add Installer ISO
$Params = @{
	VMName	=	$VMName
	Path	=	"E:\ISO\WINSERVER.ISO"
}
Add-VMDvdDrive @Params

#Create OS Drive
$Params = @{
	Path		=	"E:\VHD\$VMName-OS.vhdx"
	SizeBytes	=	60GB
	Dynamic		=	$true
}
New-VHD @Params

#Add OS Drive to VM
$Params = @{
	VMName	=	$VMName
	Path	=	"E:\VHD\$VMName-OS.vhdx"
}
Add-VMHardDiskDrive @Params

#Set boot priority
Set-VMFirmware -VMName $VMName -BootOrder $(Get-VMDvdDrive -VMName $VMName), $(Get-VMHardDiskDrive -VMName $VMName | where Path -match "OS")

Start-VM -Name $VMName
``` 

## Inital configuration on all servers
```posh
#Rename the server
Rename-Computer -NewName DHCP

#Restart the server
Restart-Computer -Force

#Set IP Address (Change InterfaceIndex param if there's more than one NIC)
$Params = @{
  IPAddress         = "192.168.10.12"
  DefaultGateway    = "192.168.10.1"
  PrefixLength      = "24"
  InterfaceIndex    = (Get-NetAdapter).InterfaceIndex
}
New-NetIPAddress @Params

#Configure DNS Settings
$Params = @{
  ServerAddresses   = "192.168.10.10"
  InterfaceIndex    = (Get-NetAdapter).InterfaceIndex
}
Set-DNSClientServerAddress @Params

## Join server to an existing domain
```posh
$Params = @{
	DomainName	=	"ad.contoso.com"
	OUPath		=	"OU=Servers,OU=Devices,OU=Contoso,DC=ad,DC=contoso,DC=com"
	Credential	=	"ad.contoso.com\Administrator"
	Force		=	$true
	Restart		=	$true
}
Add-Computer @Params
```

## Install and configure DHCP server
```posh
#Install DCHP server role
Install-WindowsFeature DHCP -IncludeManagementTools

#Add required DHCP security groups on server and restart service
netsh dhcp add securitygroups
Restart-Service dhcpserver

#Authorize DHCP Server in AD
Add-DhcpServerInDC -DnsName ad.contoso.com

#Notify Server Manager that DCHP installation is complete, since it doesn't do this automatically
$Params = @{
    Path  = "registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\ServerManager\Roles\12"
    Name  = "ConfigurationState"
    Value = "2"
}
Set-ItemProperty @Params

#Configure DHCP Scope
Add-DhcpServerv4Scope -name "Corpnet" -StartRange 192.168.10.50 -EndRange 192.168.10.254 -SubnetMask 255.255.255.0 -State Active

#Exclude address range
Add-DhcpServerv4ExclusionRange -ScopeID 192.168.10.0 -StartRange 192.168.10.1 -EndRange 192.168.10.49

#Specify default gateway 
Set-DhcpServerv4OptionValue -OptionID 3 -Value 192.168.10.1 -ScopeID 192.168.10.0 -ComputerName DC1.ad.contoso.com

#Specify default DNS server
Set-DhcpServerv4OptionValue -DnsDomain ad.contoso.com -DnsServer 192.168.10.10

#Set a DHCP reservation
Set-DhcpServerv4Reservation -ComputerName "dc1.ad.contoso.com" -IPAddress 192.168.10.11 -ScopeID 192.168.10.0 -Description "WSUS" -Name "wsus.ad.contoso.com"
```
## Inital configuration
```posh
#Set IP Address (Change InterfaceIndex param if there's more than one NIC)
$Params = @{
  IPAddress = "192.168.10.12"
  DefaultGateway = "192.168.10.1"
  PrefixLength = "24"
  InterfaceIndex = (Get-NetAdapter).InterfaceIndex
}
New-NetIPAddress @Params

#Configure DNS Settings
$Params = @{
  ServerAddresses = "192.168.10.10"
  InterfaceIndex = (Get-NetAdapter).InterfaceIndex
}
Set-DNSClientServerAddress @Params

## Join server to an existing domain
```posh
$Params = @{
	DomainName = "ad.contoso.com"
	OUPath = "OU=Servers,OU=Devices,OU=Contoso,DC=ad,DC=contoso,DC=com"
	Credential = "ad.contoso.com\Administrator"
	NewName = "DHCP"
	Force = $true
	Restart = $true
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
Add-DhcpServerInDC -DnsName dhcp.ad.contoso.com

#Notify Server Manager that DCHP installation is complete, since it doesn't do this automatically
$Params = @{
    Path = "registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\ServerManager\Roles\12"
    Name = "ConfigurationState"
    Value = "2"
}
Set-ItemProperty @Params

#Configure DHCP Scope
Add-DhcpServerv4Scope -name "Corpnet" -StartRange 192.168.10.50 -EndRange 192.168.10.254 -SubnetMask 255.255.255.0 -State Active

#Exclude address range
Add-DhcpServerv4ExclusionRange -ScopeID 192.168.10.0 -StartRange 192.168.10.1 -EndRange 192.168.10.49

#Specify default gateway 
Set-DhcpServerv4OptionValue -OptionID 3 -Value 192.168.10.1 -ScopeID 192.168.10.0 -ComputerName dhcp.ad.contoso.com

#Specify default DNS server
Set-DhcpServerv4OptionValue -DnsDomain ad.contoso.com -DnsServer 192.168.10.10

#Set a DHCP reservation
Set-DhcpServerv4Reservation -ComputerName "dc1.ad.contoso.com" -IPAddress 192.168.10.11 -ScopeID 192.168.10.0 -Description "WSUS" -Name "wsus.ad.contoso.com"
```

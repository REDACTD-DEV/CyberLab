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


$usr = "ad\Administrator"
$pwd = ConvertTo-SecureString "1Password" -AsPlainText -Force
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $usr, $pwd
$Params = @{
	DomainName = "ad.contoso.com"
	OUPath = "OU=Servers,OU=Devices,OU=Contoso,DC=ad,DC=contoso,DC=com"
	Credential = $cred
	Force = $true
	Restart = $true
}
Add-Computer @Params
## Join a computer to an existing domain
```posh
#Set computer name as Serial
Rename-Computer -NewName (Get-WmiObject Win32_BIOS).SerialNumber

#Restart
Restart-Computer -Force

#Run from an elevated powershell console
$Params = @{
	DomainName = "ad.contoso.com"
	OUPath = "OU=Workstations,OU=Devices,OU=Contoso,DC=ad,DC=contoso,DC=com"
	Credential = "ad.contoso.com\Administrator"
	Force = $true
	Restart = $true
}
Add-Computer @Params
```

## Install RSAT
```posh
Get-WindowsCapability -Name RSAT* -Online | Add-WindowsCapability -Online
```

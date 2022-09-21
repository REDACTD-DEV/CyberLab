## Join a computer to an existing domain
```posh
#Run from an elevated powershell console
$Params = @{
	DomainName	=	"ad.contoso.com"
	OUPath		=	"OU=Workstations,OU=Devices,OU=Contoso,DC=ad,DC=contoso,DC=com"
	Credential	=	"ad.contoso.com\Administrator"
	NewName		=	(Get-WmiObject Win32_BIOS).SerialNumber #Sets Name as Serial
	Force		=	$true
	Restart		=	$true
}
Add-Computer @Params
```

## Install RSAT
```posh
Get-WindowsCapability -Name RSAT* -Online | Add-WindowsCapability -Online
```
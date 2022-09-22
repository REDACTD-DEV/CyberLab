## Deploy the VM
```posh
#Create VM
$VMName = "WinClient"
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
	Path	=	"E:\ISO\Windows.iso"
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

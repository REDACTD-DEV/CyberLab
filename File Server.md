## Deploy the VM
```posh
#Create VM
$VMName = "FS01"
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

#Create Data Drive
$Params = @{
	Path		=	"E:\VHD\$VMName-Data.vhdx"
	SizeBytes	=	500GB
	Dynamic		=	$true
}
New-VHD @Params

#Add OS Drive to VM
$Params = @{
	VMName	=	$VMName
	Path	=	"E:\VHD\$VMName-OS.vhdx"
}
Add-VMHardDiskDrive @Params

#Add Data Drive to VM
$Params = @{
	VMName	=	$VMName
	Path	=	"E:\VHD\$VMName-Data.vhdx"
}
Add-VMHardDiskDrive @Params

#Set boot priority
Set-VMFirmware -VMName $VMName -BootOrder $(Get-VMDvdDrive -VMName $VMName), $(Get-VMHardDiskDrive -VMName $VMName | where Path -match "OS"), $(Get-VMHardDiskDrive -VMName $VMName | where Path -match "Data")

Start-VM -Name $VMName
``` 


## Initial Server Configuration
```posh
#Rename the server
Rename-Computer -NewName FS01

#Set IP Address (Change InterfaceIndex param if there's more than one NIC)
$Params = @{
  IPAddress         = "192.168.10.13"
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
```

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

## Setup data disk
```posh
#Bring data disk online
Initialize-Disk -Number 1
#Partition and format
New-Partition -DiskNumber 1 -UseMaximumSize | Format-Volume -FileSystem "NTFS" -NewFileSystemLabel "Data"
#Set drive letter 
Set-Partition -DiskNumber 1 -PartitionNumber 2 -NewDriveLetter E
```

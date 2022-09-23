## Deploy the VM
```posh
#Create VM
$VMName = "WSUS"
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
Rename-Computer -NewName WSUS

#Restart the server
Restart-Computer -Force

#Set IP Address (Change InterfaceIndex param if there's more than one NIC)
$Params = @{
  IPAddress         = "192.168.10.11"
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

## Install WSUS
```posh
Install-WindowsFeature -Name UpdateServices -IncludeManagementTools
New-Item "E:\WSUS_Content" -Type Directory
CD "C:\Program Files\Update Services\Tools"
.\wsusutil.exe postinstall CONTENT_DIR=E:\WSUS_Content

#Set WSUS to pull updates from MS
Set-WsusServerSynchronization -SyncFromMU

#Only download English updates
$wsusConfig = (Get-WsusServer).GetConfiguration()
$wsusConfig.AllUpdateLanguagesEnabled = $false
$wsusConfig.SetEnabledUpdateLanguages("en")
$wsusConfig.Save()


# Get WSUS Subscription and perform initial synchronization to get latest categories
$wsus = Get-WsusServer
$subscription = $wsus.GetSubscription()
$subscription.StartSynchronizationForCategoryOnly()

#Disable all products before explicity setting products as some are enabled by default
Get-WsusProduct | Set-WsusProduct -Disable

#Set products to get updates for
Get-WsusProduct | where-Object {
	$_.Product.Title -in (
		'Microsoft Defender Antivirus',
		'Windows 10 Feature On Demand',
		'Windows 10, version 1903 and later',
		'Windows Server 2019')
}  | Set-WsusProduct

#Set Classification
Get-WsusClassification | Where-Object {
    $_.Classification.Title -in (
		'Critical Updates',
		'Definition Updates',
		'Feature Packs',
		'Security Updates',
		'Service Packs',
		'Update Rollups',
		'Updates')
} | Set-WsusClassification

#Configure synchronization
$subscription.SynchronizeAutomatically = $true

#Sync at midnight
$subscription.SynchronizeAutomaticallyTimeOfDay= (New-TimeSpan -Hours 0)
$subscription.NumberOfSynchronizationsPerDay=1
$subscription.Save()


#Configuring default automatic approval rule
[void][reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration")
$rule = $wsus.GetInstallApprovalRules() | Where {
    $_.Name -eq "Default Automatic Approval Rule"}
$class = $wsus.GetUpdateClassifications()
$class_coll = New-Object Microsoft.UpdateServices.Administration.UpdateClassificationCollection
$class_coll.AddRange($class)
$rule.SetUpdateClassifications($class_coll)
$rule.Enabled = $True
$rule.Save()

#Run rule
$Apply = $rule.ApplyRule()

```

## Create GPO to force computers to use WSUS instead of Windows Update
```posh
#Create GPO
$Params = @{
    Name    = "WSUS"
    Comment = "Group policy settings for WSUS"  
}
New-GPO @Params

#Link to workstations OU
$Params = @{
	Name    = "WSUS"
	Target	= "OU=Workstations,OU=Devices,OU=Contoso,DC=ad,DC=contoso,DC=com"
}
new-gplink @Params

#Set registry entries to point to WSUS server
#DWORD's and Strings cannot be set together, so two commands are needed.
$Params = @{
    Name      = "WSUS"
    Key       = "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate"
    Type      = "String"
    ValueName = "WUServer","WUStatusServer","UpdateServiceUrlAlternate"
    Value     = "http://wsus.ad.contoso.com:8530","http://wsus.ad.contoso.com:8530","http://wsus.ad.contoso.com:8530"
}
set-GPRegistryValue @Params

$Params = @{
    Name      = "WSUS"
    Key       = "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU"
    Type      = "DWORD"
    ValueName = "UseWUServer"
    Value     = 1
}
set-GPRegistryValue @Params
```

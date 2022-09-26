## NAT Adapter to provide internet to guest VMs
```posh
New-VMSwitch -SwitchName "NATSwitch" -SwitchType Internal
New-NetIPAddress -IPAddress 192.168.10.1 -PrefixLength 24 -InterfaceAlias "vEthernet (NATSwitch)"
New-NetNAT -Name "NATNetwork" -InternalIPInterfaceAddressPrefix 192.168.10.0/24
```

## Deploy all VMs
```posh
$VMNames = @(‘DC1’,’DHCP’,’WinClient’)
Foreach ($VMName in $VMNames) {
#Create VM
    $Params = @{
        Name				=	$VMName
        MemoryStartupBytes		=	1GB
        Path				=	"E:\VM\$VMName"
        Generation			=	2
        SwitchName			=	"NATSwitch"
    }
    New-VM @Params

    #Edit VM
    $Params = @{
        Name			=	$VMName
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
        RelativeWeight		=	100
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
}
```

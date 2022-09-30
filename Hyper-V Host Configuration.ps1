## NAT Adapter to provide internet to guest VMs
New-VMSwitch -SwitchName "NATSwitch" -SwitchType Internal
New-NetIPAddress -IPAddress 192.168.10.1 -PrefixLength 24 -InterfaceAlias "vEthernet (NATSwitch)"
New-NetNAT -Name "NATNetwork" -InternalIPInterfaceAddressPrefix 192.168.10.0/24

## Edit Windows Server ISO to boot without pressing a key
#Mount ISO
Mount-DiskImage -ImagePath "E:\ISO\WINSERVER-22.iso"

#Copy ISO
$Path = (Get-DiskImage -ImagePath "E:\ISO\WINSERVER-22.iso" | Get-Volume).DriveLetter + ":\"
New-Item -Type Directory -Path "E:\ISOBuild"
Copy-Item -Path $Path -Destination "E:\ISOBuild"

#Create ISO
New-ISOFile -source "E:\ISOBuild" -destinationISO "E:\ISO\WINSERVER-22-Auto.iso" -bootfile "E:\ISOBuild\efi\microsoft\boot\efisys_noprompt.bin" -title "WINSERVER-22-Auto" -Verbose

## Deploy VMs
$VMNames = @("FS01","WSUS","DC1","DHCP","WinClient")
Foreach ($VMName in $VMNames) {
    $Params = @{
        Name = $VMName
        MemoryStartupBytes = 1GB
        Path = "E:\$VMName"
        Generation = 2
        SwitchName = "Private Virtual Switch"
    }
    New-VM @Params

    #Edit VM
    $Params = @{
        Name = $VMName
        ProcessorCount = 4
        DynamicMemory = $true
        MemoryMinimumBytes = 1GB
        MemoryMaximumBytes = 4GB
    }
    Set-VM @Params

    #Specify CPU settings
    $Params = @{
        VMName = $VMName
        Count = 8
        Maximum = 100
        RelativeWeight = 100
    }
    Set-VMProcessor @Params

    #Add Installer ISO
    $Params = @{
        VMName = $VMName
        Path = "E:\ISO\WINSERVER.ISO"
    }
    if($VMName -eq "WinClient") {$Params['Path'] = "E:\ISO\Windows.iso"}
    if($VMName -eq "pfSense") {$Params['Path'] = "E:\ISO\pfSense.iso"}
    Add-VMDvdDrive @Params

    #Create OS Drive
    $Params = @{
        Path = "E:\$VMName\Virtual Hard Disks\$VMName-OS.vhdx"
        SizeBytes = 60GB
        Dynamic = $true
    }
    New-VHD @Params

    #Create Data Drive
    $Params = @{
        Path = "E:\$VMName\Virtual Hard Disks\$VMName-Data.vhdx"
        SizeBytes = 500GB
        Dynamic = $true
    }
    New-VHD @Params

    #Add OS Drive to VM
    $Params = @{
        VMName = $VMName
        Path = "E:\$VMName\Virtual Hard Disks\$VMName-OS.vhdx"
    }
    Add-VMHardDiskDrive @Params

    #Add Data Drive to VM
    $Params = @{
        VMName = $VMName
        Path = "E:\$VMName\Virtual Hard Disks\$VMName-Data.vhdx"
    }
    Add-VMHardDiskDrive @Params

    #Set boot priority
    Set-VMFirmware -VMName $VMName -BootOrder $(Get-VMDvdDrive -VMName $VMName), $(Get-VMHardDiskDrive -VMName $VMName | Where-Object Path -match "OS"), $(Get-VMHardDiskDrive -VMName $VMName | Where-Object Path -match "Data")

    Start-VM -Name $VMName
}


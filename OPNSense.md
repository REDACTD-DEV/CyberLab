## FreeBSD build environment
```posh
$Params = @{
    $url = "https://download.freebsd.org/releases/VM-IMAGES/12.3-RELEASE/amd64/Latest/FreeBSD-12.3-RELEASE-amd64.vhd.xz"
    $dest = "E:\FreeBSD\FreeBSD-12.3-RELEASE-amd64.vhd.xz"
    UseBasicParsing = $true
}
Invoke-WebRequest @Params

$Params = @{
    URI = "https://jaist.dl.sourceforge.net/project/bsdtar/bsdtar-3.2.0_win32.zip"
    OutFile = "E:\FreeBSD\bsdtar-3.2.0_win32.zip"
    UseBasicParsing = $true
}
Invoke-WebRequest @Params

#Download 7z
cd E:\FreeBSD
'C:\Program Files\7-Zip\7z.exe' e .\FreeBSD-12.3-RELEASE-amd64.vhd.xz
Convert-VHD

Convert-VHD -Path "E:\FreeBSD\FreeBSD-12.3-RELEASE-amd64.vhd" -DestinationPath "E:\FreeBSD\FreeBSD-12.3-RELEASE-amd64.vhdx"


$VMName = "FreeBSD-Build-Environment"
    $Params = @{
        Name = $VMName
        MemoryStartupBytes = 1GB
        Path = "E:\$VMName"
        Generation = 2
        SwitchName = "Default Switch"
    }
    New-VM @Params

    #Edit VM
    $Params = @{
        Name = $VMName
        ProcessorCount = 4
        DynamicMemory = $true
        MemoryMinimumBytes = 1GB
        MemoryMaximumBytes = 8GB
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

    #Add OS Drive to VM
    $Params = @{
        VMName = $VMName
        Path = "E:\FreeBSD\FreeBSD-12.3-RELEASE-amd64.vhdx"
    }
    Add-VMHardDiskDrive @Params
    
    $VMIPv4 = (get-vm "FreeBSD-Build-Environment").NetworkAdapters.IPAddresses[0]
    
```

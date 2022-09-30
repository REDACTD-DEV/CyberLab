## NAT Adapter configuration
New-VMSwitch -name "Private vSwitch" -SwitchType Private

## Edit Windows Server ISO to boot without pressing a key
#Mount ISO
Mount-DiskImage -ImagePath "E:\ISO\WINSERVER-22.iso"

#Copy ISO
$Path = (Get-DiskImage -ImagePath "E:\ISO\WINSERVER-22.iso" | Get-Volume).DriveLetter + ":\"
New-Item -Type Directory -Path "E:\ISOBuild"
Copy-Item -Path $Path -Destination "E:\ISOBuild"

#Create ISO
New-ISOFile -source "E:\ISOBuild" -destinationISO "E:\ISO\WINSERVER-22-Auto.iso" -bootfile "E:\ISOBuild\efi\microsoft\boot\efisys_noprompt.bin" -title "WINSERVER-22-Auto" -Verbose

#Cleanup
Remove-Item -Recurse -Path "E:\ISOBuild"

#Create folder for autounattend ISO
New-Item -Type Directory -Path "E:\autounattend"

#Create base autounattend.xml file
$data = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="windowsPE">
        <component name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <SetupUILanguage>
                <UILanguage>en-US</UILanguage>
            </SetupUILanguage>
            <InputLocale>en-US</InputLocale>
            <SystemLocale>en-US</SystemLocale>
            <UILanguage>en-US</UILanguage>
            <UILanguageFallback>en-US</UILanguageFallback>
            <UserLocale>en-US</UserLocale>
        </component>
        <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <DiskConfiguration>
            <Disk wcm:action="add">
                <DiskID>0</DiskID> 
                <WillWipeDisk>true</WillWipeDisk> 
                    <CreatePartitions>
                        <CreatePartition wcm:action="add">
                            <Order>1</Order>
                            <Type>EFI</Type>
                            <Size>200</Size>
                        </CreatePartition>
                        <CreatePartition wcm:action="add">
                            <Order>2</Order>
                            <Size>128</Size>
                            <Type>MSR</Type>
                        </CreatePartition>
                        <CreatePartition wcm:action="add">
                            <Order>3</Order>
                            <Extend>true</Extend>
                            <Type>Primary</Type>
                        </CreatePartition>
                    </CreatePartitions>
                    <ModifyPartitions>
                        <ModifyPartition wcm:action="add">
                            <Format>NTFS</Format>
                            <Label>OS</Label>
                            <Letter>C</Letter>
                            <Order>2</Order>
                            <PartitionID>3</PartitionID>
                        </ModifyPartition>
                        <ModifyPartition wcm:action="add">
                            <Order>1</Order>
                            <PartitionID>1</PartitionID>
                            <Format>FAT32</Format>
                            <Label>System</Label>
                        </ModifyPartition>
                    </ModifyPartitions>
            </Disk>

            <WillShowUI>OnError</WillShowUI> 
            </DiskConfiguration>
            <ImageInstall>
                <OSImage>
                    <InstallFrom>
                    <MetaData wcm:action="add">
                        <Key>/IMAGE/INDEX</Key>
                        <Value>3</Value>
                    </MetaData>
                    </InstallFrom>
                    <InstallTo>
                        <DiskID>0</DiskID>
                        <PartitionID>3</PartitionID>
                    </InstallTo>
                </OSImage>
            </ImageInstall>
            <UserData>
                <ProductKey>
                    <WillShowUI>OnError</WillShowUI>
                </ProductKey>
                <AcceptEula>true</AcceptEula>
                <Organization>Contoso</Organization>
            </UserData>
        </component>
    </settings>
    <settings pass="generalize">
        <component name="Microsoft-Windows-Security-SPP" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <SkipRearm>1</SkipRearm>
        </component>
        <component name="Microsoft-Windows-PnpSysprep" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <PersistAllDeviceInstalls>false</PersistAllDeviceInstalls>
            <DoNotCleanUpNonPresentDevices>false</DoNotCleanUpNonPresentDevices>
        </component>
    </settings>
	<settings pass="specialize">
		<component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
			<ComputerName>1ComputerName</ComputerName>
		 </component>
	</settings>
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <InputLocale>en-US</InputLocale>
            <SystemLocale>en-US</SystemLocale>
            <UILanguage>en-US</UILanguage>
            <UserLocale>en-US</UserLocale>
        </component>
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <HideLocalAccountScreen>true</HideLocalAccountScreen>
                <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
                <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
                <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
                <NetworkLocation>Home</NetworkLocation>
                <ProtectYourPC>3</ProtectYourPC>
                <SkipMachineOOBE>true</SkipMachineOOBE>
                <SkipUserOOBE>true</SkipUserOOBE>
            </OOBE>       
            <TimeZone>UTC</TimeZone>
            <UserAccounts>
                <AdministratorPassword>
                    <Value>1Password</Value>
                    <PlainText>true</PlainText>
                </AdministratorPassword>
            </UserAccounts>
            <AutoLogon>
                <Password>
                    <Value>1Password</Value>
                    <PlainText>true</PlainText>
                </Password>
                <Username>Administrator</Username>
                <Enabled>true</Enabled>
            </AutoLogon>
            <FirstLogonCommands>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>cmd.exe /c powershell -Command "echo "Hello World!!!""</CommandLine>
                    <Description>Run a command here</Description>
                    <Order>1</Order>
                    <RequiresUserInput>true</RequiresUserInput>
                </SynchronousCommand>
            </FirstLogonCommands>
        </component>
    </settings>
    <cpi:offlineImage cpi:source="wim:e:/iso/winserver-22.wim#Windows Server 2019 SERVERDATACENTERCORE" xmlns:cpi="urn:schemas-microsoft-com:cpi" />
</unattend>
"@
#Write XML
$data | out-file "E:\autounattend" -Encoding "utf8"


## Deploy VMs
$VMNames = @("FS01","WSUS","DC01","DHCP","WinClient")
Foreach ($VMName in $VMNames) {

    #Create New VM
    $Params = @{
        Name = $VMName
        MemoryStartupBytes = 1GB
        Path = "E:\$VMName"
        Generation = 2
        SwitchName = "Private vSwitch"
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
        Path = "E:\ISO\WINSERVER-22-Auto.iso"
    }
    if($VMName -eq "WinClient") {$Params['Path'] = "E:\ISO\Windows.iso"}
    if($VMName -eq "pfSense") {$Params['Path'] = "E:\ISO\pfSense.iso"}
    Add-VMDvdDrive @Params

    #Copy autounattend.xml to VM Folder
    Copy-Item -Path "E:\autounattend\" -Destination E:\$VMName -Recurse

    #Edit autounattend.xml to customize ComputerName
    (Get-Content "E:\$VMName\autounattend\autounattend.xml").replace("1ComputerName", $VMName) | Set-Content "E:\$VMName\autounattend\autounattend.xml"

    #Create the ISO
    New-ISOFile -source "E:\$VMName\autounattend\" -destinationIso "E:\$VMName\autounattend.iso" -title autounattend -Verbose

    #Cleanup
    Remove-Item -Recurse -Path "E:\$VMName\autounattend\"

    #Add autounattend ISO
    $Params = @{
        VMName = $VMName
        Path = "E:\$VMName\autounattend.iso"
    }
    Add-VMDvdDrive @Params

    #Create OS Drive
    $Params = @{
        Path = "E:\$VMName\Virtual Hard Disks\$VMName-OS.vhdx"
        SizeBytes = "60GB"
        Dynamic = $true
    }
    New-VHD @Params

    #Create Data Drive
    $Params = @{
        Path = "E:\$VMName\Virtual Hard Disks\$VMName-Data.vhdx"
        SizeBytes = "500GB"
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


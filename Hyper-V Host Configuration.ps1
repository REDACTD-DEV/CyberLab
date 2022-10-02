function New-ISOFile {
    <#
    .SYNOPSIS
        Create an ISO file from a source folder.
    .DESCRIPTION
        #https://github.com/TheDotSource
        Create an ISO file from a source folder.
        Optionally speicify a boot image and media type.
        Based on original function by Chris Wu.
        https://gallery.technet.microsoft.com/scriptcenter/New-ISOFile-function-a8deeffd (link appears to be no longer valid.)
        Changes:
            - Updated to work with PowerShell 7
            - Added a bit more error handling and verbose output.
            - Features removed to simplify code:
                * Clipboard support.
                * Pipeline input.
    .PARAMETER source
        The source folder to add to the ISO.
    .PARAMETER destinationIso
        The ISO file to create.
    .PARAMETER bootFile
        Optional. Boot file to add to the ISO.
    .PARAMETER media
        Optional. The media type of the resulting ISO (BDR, CDR etc). Defaults to DVDPLUSRW_DUALLAYER.
    .PARAMETER title
        Optional. Title of the ISO file. Defaults to "untitled".
    .PARAMETER force
        Optional. Force overwrite of an existing ISO file.
    .INPUTS
        None.
    .OUTPUTS
        None.
    .EXAMPLE
        New-ISOFile -source c:\forIso\ -destinationIso C:\ISOs\testiso.iso
        Simple example. Create testiso.iso with the contents from c:\forIso
    .EXAMPLE
        New-ISOFile -source f:\ -destinationIso C:\ISOs\windowsServer2019Custom.iso -bootFile F:\efi\microsoft\boot\efisys.bin -title "Windows2019"
        Example building Windows media. Add the contents of f:\ to windowsServer2019Custom.iso. Use efisys.bin to make the disc bootable.
    .LINK
    .NOTES
        01           Alistair McNair          Initial version.
    #>
    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="Low")]
    Param
    (
        [parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$source,
        [parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$destinationIso,
        [parameter(Mandatory=$false,ValueFromPipeline=$false)]
        [string]$bootFile = $null,
        [Parameter(Mandatory=$false,ValueFromPipeline=$false)]
        [ValidateSet("CDR","CDRW","DVDRAM","DVDPLUSR","DVDPLUSRW","DVDPLUSR_DUALLAYER","DVDDASHR","DVDDASHRW","DVDDASHR_DUALLAYER","DISK","DVDPLUSRW_DUALLAYER","BDR","BDRE")]
        [string]$media = "DVDPLUSRW_DUALLAYER",
        [Parameter(Mandatory=$false,ValueFromPipeline=$false)]
        [string]$title = "untitled",
        [Parameter(Mandatory=$false,ValueFromPipeline=$false)]
        [switch]$force
      )

    begin {

        Write-Verbose ("Function start.")

    } # begin

    process {

        Write-Verbose ("Processing nested system " + $vmName)

        ## Set type definition
        Write-Verbose ("Adding ISOFile type.")

        $typeDefinition = @'
        public class ISOFile  {
            public unsafe static void Create(string Path, object Stream, int BlockSize, int TotalBlocks) {
                int bytes = 0;
                byte[] buf = new byte[BlockSize];
                var ptr = (System.IntPtr)(&bytes);
                var o = System.IO.File.OpenWrite(Path);
                var i = Stream as System.Runtime.InteropServices.ComTypes.IStream;
                if (o != null) {
                    while (TotalBlocks-- > 0) {
                        i.Read(buf, BlockSize, ptr); o.Write(buf, 0, bytes);
                    }
                    o.Flush(); o.Close();
                }
            }
        }
'@

        ## Create type ISOFile, if not already created. Different actions depending on PowerShell version
        if (!('ISOFile' -as [type])) {

            ## Add-Type works a little differently depending on PowerShell version.
            ## https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/add-type
            switch ($PSVersionTable.PSVersion.Major) {

                ## 7 and (hopefully) later versions
                {$_ -ge 7} {
                    Write-Verbose ("Adding type for PowerShell 7 or later.")
                    Add-Type -CompilerOptions "/unsafe" -TypeDefinition $typeDefinition
                } # PowerShell 7

                ## 5, and only 5. We aren't interested in previous versions.
                5 {
                    Write-Verbose ("Adding type for PowerShell 5.")
                    $compOpts = New-Object System.CodeDom.Compiler.CompilerParameters
                    $compOpts.CompilerOptions = "/unsafe"

                    Add-Type -CompilerParameters $compOpts -TypeDefinition $typeDefinition
                } # PowerShell 5

                default {
                    ## If it's not 7 or later, and it's not 5, then we aren't doing it.
                    throw ("Unsupported PowerShell version.")

                } # default

            } # switch

        } # if


        ## Add boot file to image
        if ($bootFile) {

            Write-Verbose ("Optional boot file " + $bootFile + " has been specified.")

            ## Display warning if Blu Ray media is used with a boot file.
            ## Not sure why this doesn't work.
            if(@('BDR','BDRE') -contains $media) {
                    Write-Warning ("Selected boot image may not work with BDR/BDRE media types.")
            } # if

            if (!(Test-Path -Path $bootFile)) {
                throw ($bootFile + " is not valid.")
            } # if

            ## Set stream type to binary and load in boot file
            Write-Verbose ("Loading boot file.")

            try {
                $stream = New-Object -ComObject ADODB.Stream -Property @{Type=1} -ErrorAction Stop
                $stream.Open()
                $stream.LoadFromFile((Get-Item -LiteralPath $bootFile).Fullname)

                Write-Verbose ("Boot file loaded.")
            } # try
            catch {
                throw ("Failed to open boot file. " + $_.exception.message)
            } # catch


            ## Apply the boot image
            Write-Verbose ("Applying boot image.")

            try {
                $boot = New-Object -ComObject IMAPI2FS.BootOptions -ErrorAction Stop
                $boot.AssignBootImage($stream)

                Write-Verbose ("Boot image applied.")
            } # try
            catch {
                throw ("Failed to apply boot file. " + $_.exception.message)
            } # catch


            Write-Verbose ("Boot file applied.")

        }  # if

        ## Build array of media types
        $mediaType = @(
            "UNKNOWN",
            "CDROM",
            "CDR",
            "CDRW",
            "DVDROM",
            "DVDRAM",
            "DVDPLUSR",
            "DVDPLUSRW",
            "DVDPLUSR_DUALLAYER",
            "DVDDASHR",
            "DVDDASHRW",
            "DVDDASHR_DUALLAYER",
            "DISK",
            "DVDPLUSRW_DUALLAYER",
            "HDDVDROM",
            "HDDVDR",
            "HDDVDRAM",
            "BDROM",
            "BDR",
            "BDRE"
        )

        Write-Verbose ("Selected media type is " + $media + " with value " + $mediaType.IndexOf($media))

        ## Initialise image
        Write-Verbose ("Initialising image object.")
        try {
            $image = New-Object -ComObject IMAPI2FS.MsftFileSystemImage -Property @{VolumeName=$title} -ErrorAction Stop
            $image.ChooseImageDefaultsForMediaType($mediaType.IndexOf($media))

            Write-Verbose ("initialised.")
        } # try
        catch {
            throw ("Failed to initialise image. " + $_.exception.Message)
        } # catch


        ## Create target ISO, throw if file exists and -force parameter is not used.
        if ($PSCmdlet.ShouldProcess($destinationIso)) {

            if (!($targetFile = New-Item -Path $destinationIso -ItemType File -Force:$Force -ErrorAction SilentlyContinue)) {
                throw ("Cannot create file " + $destinationIso + ". Use -Force parameter to overwrite if the target file already exists.")
            } # if

        } # if


        ## Get source content from specified path
        Write-Verbose ("Fetching items from source directory.")
        try {
            $sourceItems = Get-ChildItem -LiteralPath $source -ErrorAction Stop
            Write-Verbose ("Got source items.")
        } # try
        catch {
            throw ("Failed to get source items. " + $_.exception.message)
        } # catch


        ## Add these to our image
        Write-Verbose ("Adding items to image.")

        foreach($sourceItem in $sourceItems) {

            try {
                $image.Root.AddTree($sourceItem.FullName, $true)
            } # try
            catch {
                throw ("Failed to add " + $sourceItem.fullname + ". " + $_.exception.message)
            } # catch

        } # foreach

        ## Add boot file, if specified
        if ($boot) {
            Write-Verbose ("Adding boot image.")
            $Image.BootImageOptions = $boot
        }

        ## Write out ISO file
        Write-Verbose ("Writing out ISO file to " + $targetFile)

        try {
            $result = $image.CreateResultImage()
            [ISOFile]::Create($targetFile.FullName,$result.ImageStream,$result.BlockSize,$result.TotalBlocks)
        } # try
        catch {
            throw ("Failed to write ISO file. " + $_.exception.Message)
        } # catch

        Write-Verbose ("File complete.")

        ## Return file details
        return $targetFile

    } # process

    end {
        Write-Verbose ("Function complete.")
    } # end

} # function

#Set Default Switch host adapter to an IP address in range
#Variable settings for adapter.
$IP = "192.168.10.2"
$MaskBits = 24 # This means subnet mask = 255.255.255.0
$Gateway = "192.168.10.2"
$Dns = "1.1.1.1"
$IPType = "IPv4"

# Retrieve the network adapter
$adapter = Get-NetAdapter -InterfaceAlias "vEthernet (Default Switch)"

# Remove any existing IP
If (($adapter | Get-NetIPConfiguration).IPv4Address.IPAddress) {
 $adapter | Remove-NetIPAddress -AddressFamily $IPType -Confirm:$false
}

#Removing any previous IP Address Gateway.
If (($adapter | Get-NetIPConfiguration).Ipv4DefaultGateway) {
 $adapter | Remove-NetRoute -AddressFamily $IPType -Confirm:$false
}
 #Configure the IP address and default gateway
$adapter | New-NetIPAddress -AddressFamily $IPType -IPAddress $IP -PrefixLength $MaskBits -DefaultGateway $Gateway

# Configure the DNS client server IP addresses
$adapter | Set-DnsClientServerAddress -ServerAddresses $DNS

## Edit Windows Server ISO to boot without pressing a key
#Mount ISO
Mount-DiskImage -ImagePath "E:\ISO\WINSERVER-22.iso"

#Copy ISO
$Path = (Get-DiskImage -ImagePath "E:\ISO\WINSERVER-22.iso" | Get-Volume).DriveLetter + ":\"
New-Item -Type Directory -Path "E:\ISOBuild"
Copy-Item -Path $Path* -Destination "E:\ISOBuild" -Recurse

#Create ISO
New-ISOFile -source "E:\ISOBuild" -destinationISO "E:\ISO\WINSERVER-22-Auto.iso" -bootfile "E:\ISOBuild\efi\microsoft\boot\efisys_noprompt.bin" -title "WINSERVER-22-Auto" -Verbose

#Cleanup
Dismount-DiskImage -ImagePath "E:\ISO\WINSERVER-22.iso"
#Remove-Item -Recurse -Path "E:\ISOBuild"

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
        <component xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" name="Microsoft-Windows-TCPIP" processorArchitecture="x86" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <Interfaces>
                <Interface wcm:action="add">
                    <Ipv4Settings>
                        <DhcpEnabled>false</DhcpEnabled>
                    </Ipv4Settings>
                    <UnicastIpAddresses>
                        <IpAddress wcm:action="add" wcm:keyValue="1">1IPAddress</IpAddress>
                    </UnicastIpAddresses>
                    <Identifier>Local Area Connection</Identifier>
                    <Routes>
                        <Route wcm:action="add">
                            <Identifier>0</Identifier>
                            <Prefix>0.0.0.0/0</Prefix>
                            <NextHopAddress>192.168.10.1</NextHopAddress>
                            <Metric>20</Metric>
                        </Route>
                    </Routes>
                </Interface>
            </Interfaces>
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
                    <CommandLine>cmd.exe /c powershell -Command 1Script"</CommandLine>
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
$data | out-file "E:\autounattend\autounattend.xml" -Encoding "utf8"


## Deploy VMs
$VMConfigs = @(
    [PSCustomObject]@{Name = "DC01"; IP = "192.168.10.10/24"; MAC = "00155da182d1"; Script = "DC01.ps1"}
    [PSCustomObject]@{Name = "DHCP"; IP = "192.168.10.12/24"; MAC = "00155da182d2"; Script = "DHCP.ps1"}
    [PSCustomObject]@{Name = "FS01"; IP = "192.168.10.13/24"; MAC = "00155da182d3"; Script = "FS01.ps1"}
    [PSCustomObject]@{Name = "WSUS"; IP = "192.168.10.14/24"; MAC = "00155da182d4"; Script = "WSUS.ps1"}
    [PSCustomObject]@{Name = "CL01"; IP = "192.168.10.50/24"; MAC = "00155da182d5"; Script = "CL01.ps1"}
)

function Create-CustomVM {
	[CmdletBinding()]
	param(
		[Parameter()]
		[String]$VMName,
		[Parameter()]
		[String]$IP,
		[Parameter()]
		[String]$MAC,
		[Parameter()]
		[String]$Script
	)
	

    process {
        #Create New VM
        $Params = @{
            Name = $VMName
            MemoryStartupBytes = 1GB
            Path = "E:\$VMName"
            Generation = 2
            SwitchName = "Default Switch"
        }
        New-VM @Params

        Set-VMNetworkAdapter -VMName $VMName -StaticMacAddress $MAC
        #Add hyphens to the MAC address for later
        $XMLMAC = ($MAC -replace '..(?!$)','$&-').ToUpper()

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
        if($VMName -eq "CL01") {$Params['Path'] = "E:\ISO\Windows.iso"}
        if($VMName -eq "pfSense") {$Params['Path'] = "E:\ISO\pfSense.iso"}
        Add-VMDvdDrive @Params

        #Copy autounattend.xml to VM Folder
        Copy-Item -Path "E:\autounattend\" -Destination E:\$VMName -Recurse

        #Copy VM Automation script into autounattend so it can run on first logon
        Copy-Item -Path E:\$VMName.ps1 -Destination E:\$VMName\autounattend\$VMName.ps1 

        #Customize autounattend.xml for each VM
        (Get-Content "E:\$VMName\autounattend\autounattend.xml").replace("1ComputerName", $VMName) | Set-Content "E:\$VMName\autounattend\autounattend.xml"
        $Script = "E:\" + $Script
        (Get-Content "E:\$VMName\autounattend\autounattend.xml").replace("1Script", $Script) | Set-Content "E:\$VMName\autounattend\autounattend.xml"

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
        $Order1 = Get-VMDvdDrive -VMName $VMName | Where-Object Path  -NotMatch "unattend"
        $Order2 = Get-VMHardDiskDrive -VMName $VMName | Where-Object Path -Match "OS"
        $Order3 = Get-VMHardDiskDrive -VMName $VMName | Where-Object Path -Match "Data"
        $Order4 = Get-VMDvdDrive -VMName $VMName | Where-Object Path  -Match "unattend"
        $Order5 = Get-VMNetworkAdapter -VMName $VMName
        Set-VMFirmware -VMName $VMName -BootOrder $Order1, $Order2, $Order3, $Order4, $Order5

        Start-VM -Name $VMName
    }

}
Create-CustomVM -VMName $VMConfigs.Name[0] -IP $VMConfigs.IP[0] -MAC $VMConfigs.MAC[0] -Script $VMConfigs.Script[0]


#Wait for Active Directory Web Services to come online
while ((Test-NetConnection -ComputerName 192.168.10.10 -Port 9389).TcpTestSucceeded -ne "True") {
Start-Sleep -Seconds 10
}
Write-Host "ADWS is primed"
Create-CustomVM -VMName $VMConfigs.Name[1] -IP $VMConfigs.IP[1] -MAC $VMConfigs.MAC[1] -Script $VMConfigs.Script[1]
Create-CustomVM -VMName $VMConfigs.Name[2] -IP $VMConfigs.IP[2] -MAC $VMConfigs.MAC[2] -Script $VMConfigs.Script[2]

#DC01 postinstall script
$usr = "ad\Administrator"
$pwd = ConvertTo-SecureString "1Password" -AsPlainText -Force
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $usr, $pwd
Invoke-Command -Credential $cred -VMName DC01 -FilePath E:\DC01-postinstall.ps1

#Check if VM is ready for remote commands
while ((Get-VM -VMName "DHCP").Heartbeat -ne "okApplicationsUnknown") {
Start-Sleep -Seconds 10
}

#Needs time to run first time login script 
Start-Sleep -Seconds 90

#Check if VM is ready for remote commands
while ((Get-VM -VMName "DHCP").Heartbeat -ne "okApplicationsUnknown") {
Start-Sleep -Seconds 10
}

#DHCP postinstall script
Invoke-Command -Credential $cred -VMName DHCP -FilePath E:\DHCP-postinstall.ps1

#Check if VM is ready for remote commands
while ((Get-VM -VMName "FS01").Heartbeat -ne "okApplicationsUnknown") {
Start-Sleep -Seconds 10
}

#FS01 postinstall script
Invoke-Command -Credential $cred -VMName FS01 -FilePath E:\FS01-postinstall.ps1

#Group policy configuration
Invoke-Command -Credential $cred -VMName DHCP -FilePath E:\group-policy.ps1

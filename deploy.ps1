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

#Remove vSwitch if it exists
Write-Host "Removing old vSwitch" -ForegroundColor Green -BackgroundColor Black
Get-VMSwitch | Where-Object Name -eq "PrivateLabSwitch" | Remove-VMSwitch -Force | Out-Null

#Create vSwitch
Write-Host "Adding new vSwitch" -ForegroundColor Green -BackgroundColor Black
New-VMSwitch -Name "PrivateLabSwitch" -SwitchType "Private" | Out-Null

$WinServerISO = "E:\ISO\WINSERVER-22.iso"
$WinClientISO = "E:\ISO\Windows.iso"
$WinServerAutoISO = "E:\ISO\WINSERVER-22-auto.iso"
$WinClientAutoISO = "E:\ISO\Windows-auto.iso"

#Mount WinServer ISO
Write-Host "Mount WinServer ISO" -ForegroundColor Green -BackgroundColor Black
Mount-DiskImage -ImagePath $WinServerISO | Out-Null

#Copy WinServer ISO
Write-Host "Copy ISO" -ForegroundColor Green -BackgroundColor Black
$Path = (Get-DiskImage -ImagePath $WinServerISO | Get-Volume).DriveLetter + ":\"
New-Item -Type Directory -Path "E:\WinServerISOBuild" | Out-Null
Copy-Item -Path $Path* -Destination "E:\WinServerISOBuild" -Recurse | Out-Null

#Create WinServer ISO
Write-Host "Create WinServer ISO" -ForegroundColor Green -BackgroundColor Black
New-ISOFile -source "E:\WinServerISOBuild" -destinationISO $WinServerAutoISO -bootfile "E:\WinServerISOBuild\efi\microsoft\boot\efisys_noprompt.bin" -title "WINSERVER-22-Auto" | Out-Null

#Cleanup
Write-Host "Dismount ISO" -ForegroundColor Green -BackgroundColor Black
Dismount-DiskImage -ImagePath $WinServerISO | Out-Null
#Remove-Item -Recurse -Path "E:\WinServerISOBuild"

#Mount WinClient ISO
Write-Host "Mount WinClient ISO" -ForegroundColor Green -BackgroundColor Black
Mount-DiskImage -ImagePath $WinClientISO | Out-Null

#Copy WinClient ISO
Write-Host "Copy WinClient ISO" -ForegroundColor Green -BackgroundColor Black
$Path = (Get-DiskImage -ImagePath $WinClientISO | Get-Volume).DriveLetter + ":\"
New-Item -Type Directory -Path "E:\WinClientISOBuild" | Out-Null
Copy-Item -Path $Path* -Destination "E:\WinClientISOBuild" -Recurse | Out-Null

#Create WinClient ISO
Write-Host "Create WinClient ISO" -ForegroundColor Green -BackgroundColor Black
New-ISOFile -source "E:\WinClientISOBuild" -destinationISO $WinClientAutoISO -bootfile "E:\WinClientISOBuild\efi\microsoft\boot\efisys_noprompt.bin" -title "WINClient-22-Auto" | Out-Null

#Cleanup
Write-Host "Dismount ISO" -ForegroundColor Green -BackgroundColor Black
Dismount-DiskImage -ImagePath $WinClientISO | Out-Null
#Remove-Item -Recurse -Path "E:\WinClientISOBuild"

#Create folder for autounattend ISO
Write-Host "Create folder for autounattend ISO" -ForegroundColor Green -BackgroundColor Black
New-Item -Type Directory -Path "E:\autounattend" | Out-Null

#Create base  server-autounattend.xml file
Write-Host "Create base autounattend.xml file" -ForegroundColor Green -BackgroundColor Black
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
$data | out-file "E:\autounattend\server-autounattend.xml" -Encoding "utf8" | Out-Null


#Create base  server-autounattend.xml file
Write-Host "Create base autounattend.xml file" -ForegroundColor Green -BackgroundColor Black
$data = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
  <settings pass="offlineServicing" />
  <settings pass="windowsPE">
    <component name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <SetupUILanguage>
        <UILanguage>en-US</UILanguage>
      </SetupUILanguage>
      <InputLocale>0409:00000409</InputLocale>
      <SystemLocale>en-US</SystemLocale>
      <UILanguage>en-US</UILanguage>
      <UserLocale>en-US</UserLocale>
    </component>
    <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <ImageInstall>
        <OSImage>
          <InstallTo>
            <DiskID>0</DiskID>
            <PartitionID>3</PartitionID>
          </InstallTo>
        </OSImage>
      </ImageInstall>
      <UserData>
        <ProductKey>
          <Key>VK7JG-NPHTM-C97JM-9MPGT-3V66T</Key>
        </ProductKey>
        <AcceptEula>true</AcceptEula>
      </UserData>
      <RunSynchronous>
        <RunSynchronousCommand>
          <Order>1</Order>
          <Path>cmd.exe /c echo SELECT DISK 0 &gt;&gt; X:\diskpart.txt</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand>
          <Order>2</Order>
          <Path>cmd.exe /c echo CLEAN &gt;&gt; X:\diskpart.txt</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand>
          <Order>3</Order>
          <Path>cmd.exe /c echo CONVERT GPT &gt;&gt; X:\diskpart.txt</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand>
          <Order>4</Order>
          <Path>cmd.exe /c echo CREATE PARTITION EFI SIZE=100 &gt;&gt; X:\diskpart.txt</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand>
          <Order>5</Order>
          <Path>cmd.exe /c echo FORMAT QUICK FS=FAT32 LABEL="System" &gt;&gt; X:\diskpart.txt</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand>
          <Order>6</Order>
          <Path>cmd.exe /c echo CREATE PARTITION MSR SIZE=16 &gt;&gt; X:\diskpart.txt</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand>
          <Order>7</Order>
          <Path>cmd.exe /c echo CREATE PARTITION PRIMARY &gt;&gt; X:\diskpart.txt</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand>
          <Order>8</Order>
          <Path>cmd.exe /c echo FORMAT QUICK FS=NTFS LABEL="Windows" &gt;&gt; X:\diskpart.txt</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand>
          <Order>9</Order>
          <Path>cmd.exe /c diskpart /s X:\diskpart.txt &gt;&gt; X:\diskpart.log</Path>
        </RunSynchronousCommand>
      </RunSynchronous>
    </component>
  </settings>
  <settings pass="generalize" />
  <settings pass="specialize" />
  <settings pass="auditSystem" />
  <settings pass="auditUser" />
  <settings pass="oobeSystem">
    <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <InputLocale>0409:00000409</InputLocale>
      <SystemLocale>en-US</SystemLocale>
      <UILanguage>en-US</UILanguage>
      <UserLocale>en-US</UserLocale>
    </component>
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <UserAccounts>
        <AdministratorPassword>
          <Value>1Password</Value>
          <PlainText>true</PlainText>
        </AdministratorPassword>
      </UserAccounts>
      <AutoLogon>
        <Username>Administrator</Username>
        <Enabled>true</Enabled>
        <LogonCount>1</LogonCount>
        <Password>
          <Value>1Password</Value>
          <PlainText>true</PlainText>
        </Password>
      </AutoLogon>
      <OOBE>
        <ProtectYourPC>3</ProtectYourPC>
        <HideEULAPage>true</HideEULAPage>
        <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
      </OOBE>
    </component>
  </settings>
</unattend>
"@
#Write XML
$data | out-file "E:\autounattend\client-autounattend.xml" -Encoding "utf8" | Out-Null


## Deploy VMs
$VMConfigs = @(
    [PSCustomObject]@{Name = "DC01"; Type = "Server"}
    [PSCustomObject]@{Name = "DHCP"; Type = "Server"}
    [PSCustomObject]@{Name = "FS01"; Type = "Server"}
    [PSCustomObject]@{Name = "WSUS"; Type = "Server"}
    [PSCustomObject]@{Name = "CL01"; Type = "Client"}
    [PSCustomObject]@{Name = "DC02"; Type = "Server"}
    [PSCustomObject]@{Name = "WEB01"; Type = "Server"}
    [PSCustomObject]@{Name = "GW01"; Type = "Server"}
)

function New-CustomVM {
	[CmdletBinding()]
	param(
		[Parameter()]
		[String]$VMName,
        [Parameter()]
		[String]$Type
	)
	
    process {
        #Create New VM
        Write-Host "Running New-VM for $VMName" -ForegroundColor Magenta -BackgroundColor Black
        $Params = @{
            Name = $VMName
            MemoryStartupBytes = 2GB
            Path = "E:\$VMName"
            Generation = 2
        }
        New-VM @Params | Out-Null

        #Edit VM
        Write-Host "Running Set-VM for $VMName" -ForegroundColor Magenta -BackgroundColor Black
        $Params = @{
            Name = $VMName
            ProcessorCount = 4
            DynamicMemory = $true
            MemoryMinimumBytes = 1GB
            MemoryMaximumBytes = 8GB
        }
        Set-VM @Params | Out-Null
	
        #Add Network Adapter
        Write-Host "Add Network Adapter for $VMName" -ForegroundColor Magenta -BackgroundColor Black	
	$Params = @{
            VMName = $VMName
            SwitchName = "ExternalLabSwitch"
            Name = "External"
        }
	if($VMName -eq "GW01") {Add-VMNetworkAdapter @Params | Out-Null}
	
	$Params = @{
            VMName = $VMName
            SwitchName = "PrivateLabSwitch"
            Name = "Internal"
        }
	Add-VMNetworkAdapter @Params | Out-Null

        #Specify CPU settings
        Write-Host "Running Set-VMProcessor for $VMName" -ForegroundColor Magenta -BackgroundColor Black
        $Params = @{
            VMName = $VMName
            Count = 8
            Maximum = 100
            RelativeWeight = 100
        }
        Set-VMProcessor @Params | Out-Null
	
	#Configure vTPM
	Write-Host "Configure vTPM for $VMName" -ForegroundColor Magenta -BackgroundColor Black
	Set-VMKeyProtector -VMName $VMName -NewLocalKeyProtector | Out-Null
	Enable-VMTPM -VMName $VMName | Out-Null
	
        #Add Installer ISO
        Write-Host "Setting Install ISO for $VMName" -ForegroundColor Magenta -BackgroundColor Black
        $Params = @{
            VMName = $VMName
            Path = "E:\ISO\WINSERVER-22-Auto.iso"
        }
        if($VMName -eq "CL01") {$Params['Path'] = "E:\ISO\Windows-auto.iso"}
        if($VMName -eq "pfSense") {$Params['Path'] = "E:\ISO\pfSense.iso"}
        Add-VMDvdDrive @Params | Out-Null

        #Copy autounattend.xml to VM Folder
        New-Item -ItemType Directory E:\$VMName\autounattend\
        Write-Host "Copying autounattend.xml for $VMName" -ForegroundColor Magenta -BackgroundColor Black
        if ($Type -eq "Client") {
        Copy-Item -Path "E:\autounattend\client-autounattend.xml" -Destination E:\$VMName\autounattend\autounattend.xml | Out-Null
        }
        if ($Type -eq "Server") {
        Copy-Item -Path "E:\autounattend\server-autounattend.xml" -Destination E:\$VMName\autounattend\autounattend.xml | Out-Null
        }

        #Customize autounattend.xml for each VM
        Write-Host "Customizing autounattend.xml for $VMName" -ForegroundColor Magenta -BackgroundColor Black
        (Get-Content "E:\$VMName\autounattend\autounattend.xml").replace("1ComputerName", $VMName) | Set-Content "E:\$VMName\autounattend\autounattend.xml" | Out-Null

        #Create the ISO
        Write-Host "Creating autounattend ISO for $VMName" -ForegroundColor Magenta -BackgroundColor Black
        New-ISOFile -source "E:\$VMName\autounattend\" -destinationIso "E:\$VMName\autounattend.iso" -title autounattend | Out-Null

        #Cleanup
        Remove-Item -Recurse -Path "E:\$VMName\autounattend\" | Out-Null

        #Add autounattend ISO
        Write-Host "Attaching autounattend ISO to $VMName" -ForegroundColor Magenta -BackgroundColor Black
        $Params = @{
            VMName = $VMName
            Path = "E:\$VMName\autounattend.iso"
        }
        Add-VMDvdDrive @Params | Out-Null

        #Create OS Drive
        Write-Host "Create OS disk for $VMName" -ForegroundColor Magenta -BackgroundColor Black
        $Params = @{
            Path = "E:\$VMName\Virtual Hard Disks\$VMName-OS.vhdx"
            SizeBytes = 100GB
            Dynamic = $true
        }
        New-VHD @Params | Out-Null

        #Create Data Drive
        Write-Host "Create data disk for $VMName" -ForegroundColor Magenta -BackgroundColor Black
        $Params = @{
            Path = "E:\$VMName\Virtual Hard Disks\$VMName-Data.vhdx"
            SizeBytes = 500GB
            Dynamic = $true
        }
        New-VHD @Params | Out-Null

        #Add OS Drive to VM
        Write-Host "Attach OS disk for $VMName" -ForegroundColor Magenta -BackgroundColor Black
        $Params = @{
            VMName = $VMName
            Path = "E:\$VMName\Virtual Hard Disks\$VMName-OS.vhdx"
        }
        Add-VMHardDiskDrive @Params | Out-Null

        #Add Data Drive to VM
        Write-Host "Attach data disk for $VMName" -ForegroundColor Magenta -BackgroundColor Black
        $Params = @{
            VMName = $VMName
            Path = "E:\$VMName\Virtual Hard Disks\$VMName-Data.vhdx"
        }
        Add-VMHardDiskDrive @Params | Out-Null

        #Set boot priority
        Write-Host "Set boot priority for $VMName" -ForegroundColor Magenta -BackgroundColor Black
        $Order1 = Get-VMDvdDrive -VMName $VMName | Where-Object Path  -NotMatch "unattend"
        $Order2 = Get-VMHardDiskDrive -VMName $VMName | Where-Object Path -Match "OS"
        $Order3 = Get-VMHardDiskDrive -VMName $VMName | Where-Object Path -Match "Data"
        $Order4 = Get-VMDvdDrive -VMName $VMName | Where-Object Path  -Match "unattend"
        Set-VMFirmware -VMName $VMName -BootOrder $Order1, $Order2, $Order3, $Order4 | Out-Null
        
        Write-Host "Starting $VMName" -ForegroundColor Magenta -BackgroundColor Black
        Start-VM -Name $VMName | Out-Null
    }

}
Write-Host "Deploy DC01" -ForegroundColor Green -BackgroundColor Black
New-CustomVM -VMName $VMConfigs.Name[0] -Type $VMConfigs.Type[0] | Out-Null
Write-Host "Deploy DHCP" -ForegroundColor Green -BackgroundColor Black
New-CustomVM -VMName $VMConfigs.Name[1] -Type $VMConfigs.Type[1] | Out-Null
Write-Host "Deploy FS01" -ForegroundColor Green -BackgroundColor Black
New-CustomVM -VMName $VMConfigs.Name[2] -Type $VMConfigs.Type[2] | Out-Null
Write-Host "Deploy CL01" -ForegroundColor Green -BackgroundColor Black
New-CustomVM -VMName $VMConfigs.Name[4] -Type $VMConfigs.Type[4] | Out-Null
Write-Host "Deploy DC02" -ForegroundColor Green -BackgroundColor Black
New-CustomVM -VMName $VMConfigs.Name[5] -Type $VMConfigs.Type[5] | Out-Null
Write-Host "Deploy WEB01" -ForegroundColor Green -BackgroundColor Black
New-CustomVM -VMName $VMConfigs.Name[6] -Type $VMConfigs.Type[6] | Out-Null
Write-Host "Deploy GW01" -ForegroundColor Green -BackgroundColor Black
New-CustomVM -VMName $VMConfigs.Name[7] -Type $VMConfigs.Type[7] | Out-Null



$localusr = "Administrator"
$domainusr = "ad\Administrator"
$password = ConvertTo-SecureString "1Password" -AsPlainText -Force
$localcred = new-object -typename System.Management.Automation.PSCredential -argumentlist $localusr, $password
$domaincred = new-object -typename System.Management.Automation.PSCredential -argumentlist $domainusr, $password

#Wait for DC01 to respond to PowerShell Direct
Write-Host "Wait for DC01 to respond to PowerShell Direct" -ForegroundColor Green -BackgroundColor Black
while ((Invoke-Command -VMName DC01 -Credential $localcred {"Test"} -ea SilentlyContinue) -ne "Test") {
    Write-Host "Still waiting..." -ForegroundColor Green -BackgroundColor Black
    Start-Sleep -Seconds 5
}

#Configure Networking and install AD DS on DC01
Write-Host "Configure Networking and install AD DS on DC01" -ForegroundColor Green -BackgroundColor Black
Invoke-Command -VMName DC01 -Credential $localcred -ScriptBlock {
    #Disable IPV6
    Get-NetAdapterBinding | Where-Object ComponentID -eq 'ms_tcpip6' | Disable-NetAdapterBinding | Out-Null

    #Set IP Address
    Write-Host "Set IP Address" -ForegroundColor Blue -BackgroundColor Black
    $Params = @{
        IPAddress = "192.168.10.10"
        DefaultGateway = "192.168.10.1"
        PrefixLength = "24"
        InterfaceAlias = "Internal"
    }
    New-NetIPAddress @Params | Out-Null

    Write-Host "Set DNS" -ForegroundColor Blue -BackgroundColor Black
    #Configure DNS Settings
    $Params = @{
        ServerAddresses = "192.168.10.10"
        InterfaceAlias = "Internal"
    }
    Set-DNSClientServerAddress @Params | Out-Null
    
    #Install BitLocker
    Write-Host "Install BitLocker" -ForegroundColor Blue -BackgroundColor Black
    Install-WindowsFeature BitLocker -IncludeAllSubFeature -IncludeManagementTools | Out-Null

    #Install AD DS server role
    Write-Host "Install AD DS Server Role" -ForegroundColor Blue -BackgroundColor Black
    Install-WindowsFeature -name AD-Domain-Services -IncludeManagementTools | Out-Null

    #Configure server as a domain controller
    Write-Host "Configure server as a domain controller" -ForegroundColor Blue -BackgroundColor Black
    Install-ADDSForest -DomainName ad.contoso.com -DomainNetBIOSName AD -InstallDNS -Force -SafeModeAdministratorPassword (ConvertTo-SecureString "1Password" -AsPlainText -Force) -WarningAction SilentlyContinue | Out-Null
}

Start-Sleep -Seconds 10

#Wait for DC01 to respond to PowerShell Direct
Write-Host "Wait for DC01 to respond to PowerShell Direct" -ForegroundColor Green -BackgroundColor Black
while ((Invoke-Command -VMName DC01 -Credential $domaincred {"Test"} -ea SilentlyContinue) -ne "Test") {
    Write-Host "Still waiting..." -ForegroundColor Green -BackgroundColor Black
    Start-Sleep -Seconds 5
}

Invoke-Command -VMName DC01 -Credential $domaincred -ScriptBlock {
    while ((Get-Process | Where-Object ProcessName -eq "LogonUI") -ne $null) {
        Start-Sleep 5
        Write-Host "LogonUI still processing..." -ForegroundColor Green -BackgroundColor Black
    }
Write-host "LogonUI is down! Server is good to go!" -ForegroundColor Green -BackgroundColor Black
}

#DC01 postinstall script
Write-Host "DC01 postinstall script" -ForegroundColor Green -BackgroundColor Black
Invoke-Command -Credential $domaincred -VMName DC01 -ScriptBlock {
    Write-Host "Set DNS Forwarder" -ForegroundColor Blue -BackgroundColor Black
    Set-DnsServerForwarder -IPAddress "1.1.1.1" -PassThru | Out-Null
    #Create OU's
    Write-Host "Create OU's" -ForegroundColor Blue -BackgroundColor Black
    #Base OU
    New-ADOrganizationalUnit -Name "Contoso" -Path "DC=ad,DC=contoso,DC=com" | Out-Null
    #Devices
    New-ADOrganizationalUnit -Name "Devices" -Path "OU=Contoso,DC=ad,DC=contoso,DC=com" | Out-Null
    New-ADOrganizationalUnit -Name "Servers" -Path "OU=Devices,OU=Contoso,DC=ad,DC=contoso,DC=com" | Out-Null
    New-ADOrganizationalUnit -Name "Workstations" -Path "OU=Devices,OU=Contoso,DC=ad,DC=contoso,DC=com" | Out-Null
    #Users
    New-ADOrganizationalUnit -Name "Users" -Path "OU=Contoso,DC=ad,DC=contoso,DC=com" | Out-Null
    New-ADOrganizationalUnit -Name "Admins" -Path "OU=Users,OU=Contoso,DC=ad,DC=contoso,DC=com" | Out-Null
    New-ADOrganizationalUnit -Name "Employees" -Path "OU=Users,OU=Contoso,DC=ad,DC=contoso,DC=com" | Out-Null
    #Groups
    New-ADOrganizationalUnit -Name "Groups" -Path "OU=Contoso,DC=ad,DC=contoso,DC=com" | Out-Null
    New-ADOrganizationalUnit -Name "SecurityGroups" -Path "OU=Groups,OU=Contoso,DC=ad,DC=contoso,DC=com" | Out-Null
    New-ADOrganizationalUnit -Name "DistributionLists" -Path "OU=Groups,OU=Contoso,DC=ad,DC=contoso,DC=com" | Out-Null
    #New admin user
    Write-Host "New admin user" -ForegroundColor Blue -BackgroundColor Black
    $Params = @{
        Name = "Admin-John.Smith"
        AccountPassword = (ConvertTo-SecureString "1Password" -AsPlainText -Force)
        Enabled = $true
        ChangePasswordAtLogon = $true
        DisplayName = "John Smith - Admin"
        Path = "OU=Admins,OU=Users,OU=Contoso,DC=ad,DC=contoso,DC=com"
    }
    New-ADUser @Params | Out-Null
    #Add admin to Domain Admins group
    Add-ADGroupMember -Identity "Domain Admins" -Members "Admin-John.Smith" | Out-Null

    #New domain user
    Write-Host "New domain user" -ForegroundColor Blue -BackgroundColor Black
    $Params = @{
        Name = "John.Smith"
        AccountPassword = (ConvertTo-SecureString "1Password" -AsPlainText -Force)
        Enabled = $true
        ChangePasswordAtLogon = $true
        DisplayName = "John Smith"
        Company = "Contoso"
        Department = "Information Technology"
        Path = "OU=Employees,OU=Users,OU=Contoso,DC=ad,DC=contoso,DC=com"
    }
    New-ADUser @Params | Out-Null
    #Will have issues logging in through Hyper-V Enhanced Session Mode if not in this group
    Add-ADGroupMember -Identity "Remote Desktop Users" -Members "John.Smith" | Out-Null

    #Add Company SGs and add members to it
    Write-Host "Add Company SGs and add members to it" -ForegroundColor Blue -BackgroundColor Black
    New-ADGroup -Name "All-Staff" -SamAccountName "All-Staff" -GroupCategory Security -GroupScope Global -DisplayName "All-Staff" -Path "OU=SecurityGroups,OU=Groups,OU=Contoso,DC=ad,DC=contoso,DC=com" -Description "Members of this group are employees of Contoso" | Out-Null
    Add-ADGroupMember -Identity "All-Staff" -Members "John.Smith" | Out-Null
}

#Wait for GW01 to respond to PowerShell Direct
Write-Host "Wait for GW01 to respond to PowerShell Direct" -ForegroundColor Green -BackgroundColor Black
while ((Invoke-Command -VMName GW01 -Credential $localcred {"Test"} -ea SilentlyContinue) -ne "Test") {
    Write-Host "Still waiting..." -ForegroundColor Green -BackgroundColor Black
    Start-Sleep -Seconds 5
}

#GW01 configure networking and domain join
Write-Host "GW01 Networking and domain join" -ForegroundColor Green -BackgroundColor Black
Invoke-Command -Credential $localcred -VMName GW01 -ScriptBlock {
    #Disable IPV6
    Write-Host "Disable IPV6" -ForegroundColor Blue -BackgroundColor Black
    Get-NetAdapterBinding | Where-Object ComponentID -eq 'ms_tcpip6' | Disable-NetAdapterBinding | Out-Null

    #Set IP Address
    Write-Host "Set IP Address" -ForegroundColor Blue -BackgroundColor Black
    $Params = @{
        IPAddress = "192.168.10.1"
        DefaultGateway = "192.168.10.1"
        PrefixLength = "24"
        InterfaceAlias = "Internal"
    }
    New-NetIPAddress @Params | Out-Null

    #Configure DNS Settings
    Write-Host "Configure DNS" -ForegroundColor Blue -BackgroundColor Black
    $Params = @{
        ServerAddresses = "192.168.10.10"
        InterfaceAlias = "Internal"
    }
    Set-DNSClientServerAddress @Params | Out-Null

    #Domain join
    Write-Host "Domain join and restart" -ForegroundColor Blue -BackgroundColor Black
    $usr = "ad\Administrator"
    $password = ConvertTo-SecureString "1Password" -AsPlainText -Force
    $cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $usr, $password
    $Params = @{
	    DomainName = "ad.contoso.com"
	    OUPath = "OU=Servers,OU=Devices,OU=Contoso,DC=ad,DC=contoso,DC=com"
	    Credential = $cred
	    Force = $true
	    Restart = $true
    }
    Add-Computer @Params | Out-Null
}

#Wait for DHCP to respond to PowerShell Direct
Write-Host "Wait for DHCP to respond to PowerShell Direct" -ForegroundColor Green -BackgroundColor Black
while ((Invoke-Command -VMName DHCP -Credential $localcred {"Test"} -ea SilentlyContinue) -ne "Test") {
    Write-Host "Still waiting..." -ForegroundColor Green -BackgroundColor Black
    Start-Sleep -Seconds 5
}

#DHCP configure networking and domain join
Write-Host "DHCP Networking and domain join" -ForegroundColor Green -BackgroundColor Black
Invoke-Command -Credential $localcred -VMName DHCP -ScriptBlock {
    #Disable IPV6
    Write-Host "Disable IPV6" -ForegroundColor Blue -BackgroundColor Black
    Get-NetAdapterBinding | Where-Object ComponentID -eq 'ms_tcpip6' | Disable-NetAdapterBinding | Out-Null

    #Set IP Address
    Write-Host "Set IP Address" -ForegroundColor Blue -BackgroundColor Black
    $Params = @{
        IPAddress = "192.168.10.13"
        DefaultGateway = "192.168.10.1"
        PrefixLength = "24"
        InterfaceAlias = "Internal"
    }
    New-NetIPAddress @Params | Out-Null

    #Configure DNS Settings
    Write-Host "Configure DNS" -ForegroundColor Blue -BackgroundColor Black
    $Params = @{
        ServerAddresses = "192.168.10.10"
        InterfaceAlias = "Internal"
    }
    Set-DNSClientServerAddress @Params | Out-Null

    #Domain join
    Write-Host "Domain join and restart" -ForegroundColor Blue -BackgroundColor Black
    $usr = "ad\Administrator"
    $password = ConvertTo-SecureString "1Password" -AsPlainText -Force
    $cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $usr, $password
    $Params = @{
	    DomainName = "ad.contoso.com"
	    OUPath = "OU=Servers,OU=Devices,OU=Contoso,DC=ad,DC=contoso,DC=com"
	    Credential = $cred
	    Force = $true
	    Restart = $true
    }
    Add-Computer @Params | Out-Null
}

#Wait for FS01 to respond to PowerShell Direct
Write-Host "Wait for FS01 to respond to PowerShell Direct" -ForegroundColor Green -BackgroundColor Black
while ((Invoke-Command -VMName FS01 -Credential $localcred {"Test"} -ea SilentlyContinue) -ne "Test") {
    Write-Host "Still waiting..." -ForegroundColor Green -BackgroundColor Black
    Start-Sleep -Seconds 5
}

#FS01 Networking and domain join
Write-Host "FS01 Networking and domain join" -ForegroundColor Green -BackgroundColor Black
Invoke-Command -Credential $localcred -VMName FS01 -ScriptBlock {
    #Disable IPV6
    Write-Host "Disable IPV6" -ForegroundColor Blue -BackgroundColor Black
    Get-NetAdapterBinding | Where-Object ComponentID -eq 'ms_tcpip6' | Disable-NetAdapterBinding | Out-Null

    #Set IP Address
    Write-Host "Set IP Address" -ForegroundColor Blue -BackgroundColor Black
    $Params = @{
        IPAddress = "192.168.10.14"
        DefaultGateway = "192.168.10.1"
        PrefixLength = "24"
        InterfaceAlias = "Internal"
    }
    New-NetIPAddress @Params | Out-Null

    #Configure DNS Settings
    Write-Host "Configure DNS" -ForegroundColor Blue -BackgroundColor Black
    $Params = @{
        ServerAddresses = "192.168.10.10"
        InterfaceAlias = "Internal"
    }
    Set-DNSClientServerAddress @Params | Out-Null

    #Domain Join
    Write-Host "Domain Join" -ForegroundColor Blue -BackgroundColor Black
    $usr = "ad\Administrator"
    $password = ConvertTo-SecureString "1Password" -AsPlainText -Force
    $cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $usr, $password
    $Params = @{
	    DomainName = "ad.contoso.com"
	    OUPath = "OU=Servers,OU=Devices,OU=Contoso,DC=ad,DC=contoso,DC=com"
	    Credential = $cred
	    Force = $true
	    Restart = $true
    }
    Add-Computer @Params | Out-Null
}

#WEB01 configure networking and domain join
Write-Host "WEB01 postinstall script" -ForegroundColor Green -BackgroundColor Black
Invoke-Command -Credential $localcred -VMName WEB01 -ScriptBlock {
    #Disable IPV6
    Write-Host "Disable IPV6" -ForegroundColor Blue -BackgroundColor Black
    Get-NetAdapterBinding | Where-Object ComponentID -eq 'ms_tcpip6' | Disable-NetAdapterBinding | Out-Null

    #Set IP Address
    Write-Host "Set IP Address" -ForegroundColor Blue -BackgroundColor Black
    $Params = @{
        IPAddress = "192.168.10.15"
        DefaultGateway = "192.168.10.1"
        PrefixLength = "24"
        InterfaceAlias = "Internal"
    }
    New-NetIPAddress @Params | Out-Null

    #Configure DNS Settings
    Write-Host "Configure DNS" -ForegroundColor Blue -BackgroundColor Black
    $Params = @{
        ServerAddresses = "192.168.10.10"
        InterfaceAlias = "Internal"
    }
    Set-DNSClientServerAddress @Params | Out-Null

    #Domain join
    Write-Host "Domain join and restart" -ForegroundColor Blue -BackgroundColor Black
    $usr = "ad\Administrator"
    $password = ConvertTo-SecureString "1Password" -AsPlainText -Force
    $cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $usr, $password
    $Params = @{
	    DomainName = "ad.contoso.com"
	    OUPath = "OU=Servers,OU=Devices,OU=Contoso,DC=ad,DC=contoso,DC=com"
	    Credential = $cred
	    Force = $true
	    Restart = $true
    }
    Add-Computer @Params | Out-Null
}

#Wait for GW01 to respond to PowerShell Direct
Write-Host "Wait for GW01 to respond to PowerShell Direct" -ForegroundColor Green -BackgroundColor Black
while ((Invoke-Command -VMName GW01 -Credential $domaincred {"Test"} -ea SilentlyContinue) -ne "Test") {
    Write-Host "Still waiting..." -ForegroundColor Green -BackgroundColor Black
    Start-Sleep -Seconds 5
}

#GW01 post-install
Write-Host "GW01 post-install" -ForegroundColor Green -BackgroundColor Black
Invoke-Command -Credential $domaincred -VMName GW01 -ScriptBlock {
	Install-WindowsFeature Routing -IncludeManagementTools
	
	Install-RemoteAccess -VpnType RoutingOnly -PassThru

	$ExternalInterface="External"
	$InternalInterface="Internal"

	cmd.exe /c "netsh routing ip nat install"
	cmd.exe /c "netsh routing ip nat add interface $ExternalInterface"
	cmd.exe /c "netsh routing ip nat set interface $ExternalInterface mode=full"
	cmd.exe /c "netsh routing ip nat add interface $InternalInterface"
	
	Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\RemoteAccess\Parameters\IP' -Name InitialAddressPoolSize -Type DWORD -Value 0

}

#Wait for DHCP to respond to PowerShell Direct
Write-Host "Wait for DHCP to respond to PowerShell Direct" -ForegroundColor Green -BackgroundColor Black
while ((Invoke-Command -VMName DHCP -Credential $domaincred {"Test"} -ea SilentlyContinue) -ne "Test") {
    Write-Host "Still waiting..." -ForegroundColor Green -BackgroundColor Black
    Start-Sleep -Seconds 5
}

#DHCP postinstall script
Write-Host "DHCP postinstall script" -ForegroundColor Green -BackgroundColor Black
Invoke-Command -Credential $domaincred -VMName DHCP -ScriptBlock {
    #Install DCHP server role
    Write-Host "Install DCHP server role" -ForegroundColor Blue -BackgroundColor Black
    Install-WindowsFeature DHCP -IncludeManagementTools | Out-Null

    #Add required DHCP security groups on server and restart service
    Write-Host "Add required DHCP security groups on server and restart service" -ForegroundColor Blue -BackgroundColor Black
    netsh dhcp add securitygroups | Out-Null
    Restart-Service dhcpserver | Out-Null

    #Authorize DHCP Server in AD
    Write-Host "Authorize DHCP Server in AD" -ForegroundColor Blue -BackgroundColor Black
    Add-DhcpServerInDC -DnsName dhcp.ad.contoso.com | Out-Null

    #Notify Server Manager that DCHP installation is complete, since it doesn't do this automatically
    Write-Host "Notify Server Manager that DCHP installation is complete, since it doesn't do this automatically" -ForegroundColor Blue -BackgroundColor Black
    $Params = @{
        Path = "registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\ServerManager\Roles\12"
        Name = "ConfigurationState"
        Value = "2"
    }
    Set-ItemProperty @Params | Out-Null

    #Configure DHCP Scope
    Write-Host "Configure DHCP Scope" -ForegroundColor Blue -BackgroundColor Black
    Add-DhcpServerv4Scope -name "Corpnet" -StartRange 192.168.10.50 -EndRange 192.168.10.254 -SubnetMask 255.255.255.0 -State Active | Out-Null

    #Exclude address range
    Write-Host "Exclude address range" -ForegroundColor Blue -BackgroundColor Black
    Add-DhcpServerv4ExclusionRange -ScopeID 192.168.10.0 -StartRange 192.168.10.1 -EndRange 192.168.10.49 | Out-Null

    #Specify default gateway 
    Write-Host "Specify default gateway " -ForegroundColor Blue -BackgroundColor Black
    Set-DhcpServerv4OptionValue -OptionID 3 -Value 192.168.10.1 -ScopeID 192.168.10.0 -ComputerName dhcp.ad.contoso.com | Out-Null

    #Specify default DNS server
    Write-Host "Specify default DNS server" -ForegroundColor Blue -BackgroundColor Black
    Set-DhcpServerv4OptionValue -DnsDomain ad.contoso.com -DnsServer 192.168.10.10 | Out-Null
}

#Wait for FS01 to respond to PowerShell Direct
Write-Host "Wait for FS01 to respond to PowerShell Direct" -ForegroundColor Green -BackgroundColor Black
while ((Invoke-Command -VMName FS01 -Credential $domaincred {"Test"} -ea SilentlyContinue) -ne "Test") {
    Write-Host "Still waiting..." -ForegroundColor Green -BackgroundColor Black
    Start-Sleep -Seconds 5
}

#FS01 post-install
Write-Host "FS01 post-install" -ForegroundColor Green -BackgroundColor Black
Invoke-Command -Credential $domaincred -VMName FS01 -ScriptBlock {
    #Bring data disk online
    Write-Host "Bring data disk online" -ForegroundColor Blue -BackgroundColor Black
    Initialize-Disk -Number 1 | Out-Null
    #Partition and format
    Write-Host "Partition and format" -ForegroundColor Blue -BackgroundColor Black
    New-Partition -DiskNumber 1 -UseMaximumSize | Format-Volume -FileSystem "NTFS" -NewFileSystemLabel "Data" | Out-Null
    #Set drive letter 
    Write-Host "Set drive letter" -ForegroundColor Blue -BackgroundColor Black
    Set-Partition -DiskNumber 1 -PartitionNumber 2 -NewDriveLetter F | Out-Null


    Write-Host "Install FS Feature" -ForegroundColor Blue -BackgroundColor Black
    Install-WindowsFeature FS-FileServer  | Out-Null

    Write-Host "Create NetworkShare folder" -ForegroundColor Blue -BackgroundColor Black
    New-Item "F:\Data\NetworkShare" -Type Directory | Out-Null

    Write-Host "Create new SMB share" -ForegroundColor Blue -BackgroundColor Black
    $Params = @{
        Name = "NetworkShare"
        Path = "F:\Data\NetworkShare"
        FullAccess = "Domain Admins"
        ReadAccess = "Domain Users"
        FolderEnumerationMode = "Unrestricted"
    }
    New-SmbShare @Params | Out-Null

    Write-Host "Install and configure DFS Namespace" -ForegroundColor Blue -BackgroundColor Black
    Install-WindowsFeature FS-DFS-Namespace -IncludeManagementTools | Out-Null
    New-DfsnRoot -TargetPath "\\fs01.ad.contoso.com\NetworkShare" -Type DomainV2 -Path "\\ad.contoso.com\NetworkShare" | Out-Null
}

#Wait for WEB01 to respond to PowerShell Direct
Write-Host "Wait for WEB01 to respond to PowerShell Direct" -ForegroundColor Green -BackgroundColor Black
while ((Invoke-Command -VMName WEB01 -Credential $domaincred {"Test"} -ea SilentlyContinue) -ne "Test") {
    Write-Host "Still waiting..." -ForegroundColor Green -BackgroundColor Black
    Start-Sleep -Seconds 5
}

#WEB01 post-install
Write-Host "WEB01 post-install" -ForegroundColor Green -BackgroundColor Black
Invoke-Command -Credential $domaincred -VMName WEB01 -ScriptBlock {
    #Install IIS role
    Write-Host "Install IIS role" -ForegroundColor Blue -BackgroundColor Black
    Install-WindowsFeature -name "Web-Server" -IncludeAllSubFeature ‑IncludeManagementTools
}

#Wait for DC01 to respond to PowerShell Direct
Write-Host "Wait for DC01 to respond to PowerShell Direct" -ForegroundColor Green -BackgroundColor Black
while ((Invoke-Command -VMName DC01 -Credential $domaincred {"Test"} -ea SilentlyContinue) -ne "Test") {
    Write-Host "Still waiting..." -ForegroundColor Green -BackgroundColor Black
    Start-Sleep -Seconds 5
}

#Group policy configuration
Write-Host "Group policy configuration" -ForegroundColor Green -BackgroundColor Black
Invoke-Command -Credential $domaincred -VMName DC01 -ScriptBlock {
    Write-Host "Creating drive mapping GPO" -ForegroundColor Blue -BackgroundColor Black
    #Create GPO
    $gpoOuObj=new-gpo -name "All Staff Mapped Drive"

    #Link GPO to domain
    new-gplink -Guid $gpoOuObj.Id.Guid -target "DC=ad,DC=contoso,DC=com" | Out-Null

    #Get GUID and make it upper case
    $guid = $gpoOuObj.Id.Guid.ToUpper()

    #Create a folder that the GP MMC snap-in normally would
    $path="\\ad.contoso.com\SYSVOL\ad.contoso.com\Policies\{$guid}\User\Preferences\Drives"
    New-Item -Path $path -type Directory | Out-Null 

    #Variables that would normally be set in the Drive Mapping dialog box
    $Letter = "M"
    $Label = "NetworkShare"
    $SharePath = "\\ad.contoso.com\NetworkShare"
    $ILT = "AD\All-Staff"
    $SID = (Get-ADGroup "All-Staff").SID.Value

    #Date needs to be inserted into the XML
    $Date = Get-Date -Format "yyyy-MM-dd hh:mm:ss"

    #A Guid needs to be inserted into the XML - This can be completely random 
    $RandomGuid = (New-Guid).Guid.ToUpper()

    #The XML
$data = @"
<?xml version="1.0" encoding="utf-8"?>
<Drives clsid="{8FDDCC1A-0C3C-43cd-A6B4-71A6DF20DA8C}">
	<Drive clsid="{935D1B74-9CB8-4e3c-9914-7DD559B7A417}" bypassErrors="1" uid="{$RandomGuid}" changed="$Date" image="2" status="${Letter}:" name="${Letter}:">
		<Properties letter="$Letter" useLetter="1" persistent="1" label="$Label" path="$SharePath" userName="" allDrives="SHOW" thisDrive="SHOW" action="U"/>
		<Filters>
        <FilterGroup bool="AND" not="0" name="$ILT" sid="$SID" userContext="1" primaryGroup="0" localGroup="0"/>
    </Filters>
	</Drive>
</Drives>
"@
    #Write XML
    $data | out-file $path\drives.xml -Encoding "utf8" | Out-Null

    #Edit AD Attribute "gPCUserExtensionNames" since the GP MMC snap-in normally would 
    $ExtensionNames = "[{00000000-0000-0000-0000-000000000000}{2EA1A81B-48E5-45E9-8BB7-A6E3AC170006}][{5794DAFD-BE60-433F-88A2-1A31939AC01F}{2EA1A81B-48E5-45E9-8BB7-A6E3AC170006}]"
    Set-ADObject -Identity "CN={$guid},CN=Policies,CN=System,DC=ad,DC=contoso,DC=com" -Add @{gPCUserExtensionNames=$ExtensionNames} | Out-Null

    #A versionNumber of 0 means that clients won't get the policy since it hasn't changed
    #Edit something random (and easy) so it increments the versionNumber properly
    #This one removes the computer icon from the desktop.
    $Params = @{
        Name = "All Staff Mapped Drive"
        Key = "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\NonEnum"
        Type = "DWORD"
        ValueName = "{645FF040-5081-101B-9F08-00AA002F954E}"
        Value = 1
    }
    set-GPRegistryValue @Params | Out-Null
}

#Wait for DC02 to respond to PowerShell Direct
Write-Host "Wait for DC02 to respond to PowerShell Direct" -ForegroundColor Green -BackgroundColor Black
while ((Invoke-Command -VMName DC02 -Credential $localcred {"Test"} -ea SilentlyContinue) -ne "Test") {
    Write-Host "Still waiting..." -ForegroundColor Green -BackgroundColor Black
    Start-Sleep -Seconds 5
}

#DC02 Networking and domain join
Write-Host "DC02 Networking and domain join" -ForegroundColor Green -BackgroundColor Black
Invoke-Command -Credential $localcred -VMName DC02 -ScriptBlock {
    #Disable IPV6
    Write-Host "Disable IPV6" -ForegroundColor Blue -BackgroundColor Black
    Get-NetAdapterBinding | Where-Object ComponentID -eq 'ms_tcpip6' | Disable-NetAdapterBinding | Out-Null
    
    #Set IP Address
    Write-Host "Set IP Address" -ForegroundColor Blue -BackgroundColor Black
    $Params = @{
        IPAddress = "192.168.10.11"
        DefaultGateway = "192.168.10.1"
        PrefixLength = "24"
        InterfaceAlias = "Internal"
    }
    New-NetIPAddress @Params | Out-Null

    #Configure DNS Settings
    Write-Host "Configure DNS" -ForegroundColor Blue -BackgroundColor Black
    $Params = @{
        ServerAddresses = "192.168.10.10"
        InterfaceAlias = "Internal"
    }
    Set-DNSClientServerAddress @Params | Out-Null

    #Install AD DS server role
    Write-Host "Install AD DS Server Role" -ForegroundColor Blue -BackgroundColor Black
    Install-WindowsFeature -name AD-Domain-Services -IncludeManagementTools | Out-Null

    #Promote to DC
    Write-Host "Promote to DC" -ForegroundColor Blue -BackgroundColor Black
    $dc02usr = "ad\Administrator"
    $dc02password = ConvertTo-SecureString "1Password" -AsPlainText -Force
    $dc02cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $dc02usr, $dc02password
    Install-ADDSDomainController -DomainName "ad.contoso.com" -InstallDns:$true -Credential $dc02cred -Force -SafeModeAdministratorPassword (ConvertTo-SecureString "1Password" -AsPlainText -Force) -WarningAction SilentlyContinue | Out-Null
}

#Wait for CL01 to respond to PowerShell Direct
Write-Host "Wait for CL01 to respond to PowerShell Direct" -ForegroundColor Green -BackgroundColor Black
while ((Invoke-Command -VMName CL01 -Credential $localcred {"Test"} -ea SilentlyContinue) -ne "Test") {
    Write-Host "Still waiting..." -ForegroundColor Green -BackgroundColor Black
    Start-Sleep -Seconds 5
}

#CL01 Networking and domain join
Write-Host "CL01 Networking and domain join" -ForegroundColor Green -BackgroundColor Black
Invoke-Command -Credential $localcred -VMName CL01 -ScriptBlock {
    #Disable IPV6
    Write-Host "Disable IPV6" -ForegroundColor Blue -BackgroundColor Black
    Get-NetAdapterBinding | Where-Object ComponentID -eq 'ms_tcpip6' | Disable-NetAdapterBinding | Out-Null
    
    Write-Host "Get a new DHCP lease" -ForegroundColor Blue -BackgroundColor Black
    ipconfig /release | Out-Null
    ipconfig /renew | Out-Null
    
    #Install RSAT
    Write-Host "Install RSAT" -ForegroundColor Blue -BackgroundColor Black
    Get-WindowsCapability -Name RSAT* -Online | Add-WindowsCapability -Online

    #Domain join and restart
    Write-Host "Domain join and restart" -ForegroundColor Blue -BackgroundColor Black
    $usr = "ad\Administrator"
    $password = ConvertTo-SecureString "1Password" -AsPlainText -Force
    $cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $usr, $password
    $Params = @{
	    DomainName = "ad.contoso.com"
	    OUPath = "OU=Workstations,OU=Devices,OU=Contoso,DC=ad,DC=contoso,DC=com"
	    Credential = $cred
	    Force = $true
	    Restart = $true
    }
    Add-Computer @Params | Out-Null
}

#Clone DC01 to DC03
Write-Host "Ensure both domain controllers are up before bringing DC01 down to clone" -ForegroundColor Green -BackgroundColor Black
#Wait for DC01 to respond to PowerShell Direct
Write-Host "Wait for DC01 to respond to PowerShell Direct" -ForegroundColor Green -BackgroundColor Black
while ((Invoke-Command -VMName DC01 -Credential $domaincred {"Test"} -ea SilentlyContinue) -ne "Test") {
    Write-Host "Still waiting..." -ForegroundColor Green -BackgroundColor Black
    Start-Sleep -Seconds 5
}

Invoke-Command -VMName DC01 -Credential $domaincred -ScriptBlock {
    while ((Get-Process | Where-Object ProcessName -eq "LogonUI") -ne $null) {
        Start-Sleep 5
        Write-Host "LogonUI still processing..." -ForegroundColor Green -BackgroundColor Black
    }
Write-host "LogonUI is down! Server is good to go!" -ForegroundColor Green -BackgroundColor Black
}

#Wait for DC02 to respond to PowerShell Direct
Write-Host "Wait for DC02 to respond to PowerShell Direct" -ForegroundColor Green -BackgroundColor Black
while ((Invoke-Command -VMName DC02 -Credential $domaincred {"Test"} -ea SilentlyContinue) -ne "Test") {
    Write-Host "Still waiting..." -ForegroundColor Green -BackgroundColor Black
    Start-Sleep -Seconds 5
}

Invoke-Command -VMName DC02 -Credential $domaincred -ScriptBlock {
    while ((Get-Process | Where-Object ProcessName -eq "LogonUI") -ne $null) {
        Start-Sleep 5
        Write-Host "LogonUI still processing..." -ForegroundColor Green -BackgroundColor Black
    }
Write-host "LogonUI is down! Server is good to go!" -ForegroundColor Green -BackgroundColor Black
}

Write-Host "DC01 cloning to DC03" -ForegroundColor Green -BackgroundColor Black
Invoke-Command -Credential $domaincred -VMName DC01 -ScriptBlock {
    #Add to Cloneable Domain Controllers
    Write-Host "Add to Cloneable Domain Controllers" -ForegroundColor Blue -BackgroundColor Black
    Add-ADGroupMember -Identity "Cloneable Domain Controllers" -Members "CN=DC01,OU=Domain Controllers,DC=ad,DC=contoso,DC=com" | Out-Null
    Start-Sleep 5

    #Force a domain sync
    Write-Host "Force a domain sync" -ForegroundColor Blue -BackgroundColor Black
    repadmin /syncall /AdeP | out-null

    #Wait for DC01 to show up in the Cloneable Domain Controllers group on DC01
    Write-Host "Wait for DC01 to show up in the Cloneable Domain Controllers group on DC01" -ForegroundColor Green -BackgroundColor Black
    while ((Get-ADGroupMember -Server "DC01" -Identity "Cloneable Domain Controllers").name -NotMatch "DC01") {
        Write-Host "Still waiting..." -ForegroundColor Blue -BackgroundColor Black
        Start-Sleep -Seconds 5
    } 
    Write-Host "DC01 found in Cloneable Domain Controllers on DC01, moving on" -ForegroundColor Blue -BackgroundColor Black
    Start-Sleep 5

    #Wait for DC01 to show up in the Cloneable Domain Controllers group on DC02
    Write-Host "Wait for DC01 to show up in the Cloneable Domain Controllers group on DC02" -ForegroundColor Green -BackgroundColor Black
    while ((Get-ADGroupMember -Server "DC02" -Identity "Cloneable Domain Controllers").name -NotMatch "DC01") {
        Write-Host "Still waiting..." -ForegroundColor Blue -BackgroundColor Black
        Start-Sleep -Seconds 5
    } 
    Write-Host "DC01 found in Cloneable Domain Controllers on DC02, moving on" -ForegroundColor Blue -BackgroundColor Black
    Start-Sleep 5

    #List of applications that won't be cloned
    Write-Host "List of applications that won't be cloned" -ForegroundColor Blue -BackgroundColor Black
    Start-Sleep -Seconds 2
    Get-ADDCCloningExcludedApplicationList -GenerateXML | Out-Null
    Start-Sleep 5

    #Create clone config file
    Write-Host "Create clone config file" -ForegroundColor Blue -BackgroundColor Black
    $Params = @{
    CloneComputerName   =   "DC03"
    Static              =   $true
    IPv4Address         =   "192.168.10.12"
    IPv4SubnetMask      =   "255.255.255.0"
    IPv4DefaultGateway  =   "192.168.10.1"
    IPv4DNSResolver     =   "192.168.10.10"
    }
    New-ADDCCloneConfigFile @Params | Out-Null

    #Check the config file was created
    while ((Test-Path -Path C:\Windows\NTDS\DCCloneConfig.xml) -eq $false) {
        Write-Host "Config file not created, trying again..." -ForegroundColor Blue -BackgroundColor Black
        New-ADDCCloneConfigFile @Params | Out-Null
        Start-Sleep 5
    }

    #Shutdown DC01
    Write-Host "Shutdown DC01" -ForegroundColor Blue -BackgroundColor Black
    Stop-Computer -Force | Out-Null
}

#Check DC01 is shutdown
while ((Get-VM "DC01").State -ne "Off") {
    Write-Host "Waiting for DC01 to shutdown..." -ForegroundColor Green -BackgroundColor Black
    Start-Sleep -Seconds 2
}
Write-Host "DC01 is down, moving on" -ForegroundColor Green -BackgroundColor Black

#Export VM
Write-Host "Export VM" -ForegroundColor Green -BackgroundColor Black
Export-VM -Name "DC01" -Path E:\Export | Out-Null

#Start DC01
Write-Host "Start DC01" -ForegroundColor Green -BackgroundColor Black
Start-VM -Name "DC01" | Out-Null

#New directory for DC03
Write-Host "New directory for DC03" -ForegroundColor Green -BackgroundColor Black
$guid = (Get-VM "DC01").vmid.guid.ToUpper()
New-Item -Type Directory -Path "E:\DC03" | Out-Null

#Import DC01
Write-Host "Import DC01" -ForegroundColor Green -BackgroundColor Black
$Params = @{
    Path                =   "E:\Export\DC01\Virtual Machines\$guid.vmcx"
    VirtualMachinePath  =   "E:\DC03"
    VhdDestinationPath  =   "E:\DC03\Virtual Hard Disks"
    SnapshotFilePath    =   "E:\DC03"
    SmartPagingFilePath =   "E:\DC03"
    Copy                =   $true
    GenerateNewId       =   $true
}
Import-VM @Params | Out-Null

#Rename DC01 to DC03
Write-Host "Rename DC01 to DC03" -ForegroundColor Green -BackgroundColor Black
Get-VM DC01 | Where-Object State -eq "Off" | Rename-VM -NewName DC03 | Out-Null

Write-Host "Ensure both domain controllers are up before bringing DC03 up" -ForegroundColor Green -BackgroundColor Black
#Wait for DC01 to respond to PowerShell Direct
Write-Host "Wait for DC01 to respond to PowerShell Direct" -ForegroundColor Green -BackgroundColor Black
while ((Invoke-Command -VMName DC01 -Credential $domaincred {"Test"} -ea SilentlyContinue) -ne "Test") {
    Write-Host "Still waiting..." -ForegroundColor Green -BackgroundColor Black
    Start-Sleep -Seconds 5
}

Invoke-Command -VMName DC01 -Credential $domaincred -ScriptBlock {
    while ((Get-Process | Where-Object ProcessName -eq "LogonUI") -ne $null) {
        Start-Sleep 5
        Write-Host "LogonUI still processing..." -ForegroundColor Green -BackgroundColor Black
    }
Write-host "LogonUI is down! Server is good to go!" -ForegroundColor Green -BackgroundColor Black
}

#Wait for DC02 to respond to PowerShell Direct
Write-Host "Wait for DC02 to respond to PowerShell Direct" -ForegroundColor Green -BackgroundColor Black
while ((Invoke-Command -VMName DC02 -Credential $domaincred {"Test"} -ea SilentlyContinue) -ne "Test") {
    Write-Host "Still waiting..." -ForegroundColor Green -BackgroundColor Black
    Start-Sleep -Seconds 5
}

#Start DC03
Write-Host "Start DC03" -ForegroundColor Green -BackgroundColor Black
Start-VM -Name "DC03" | Out-Null

#Cleanup export folder
Write-Host "Cleanup export folder" -ForegroundColor Green -BackgroundColor Black
Remove-Item -Recurse E:\Export\ | Out-Null

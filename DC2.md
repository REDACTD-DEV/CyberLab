## Prepare DC1 to be cloned
```posh
#Add to Cloneable Domain Controllers
Add-ADGroupMember -Identity "Cloneable Domain Controllers" -Members "CN=DC1,OU=Domain Contrllers,DC=ad,DC=contoso,DC=com"

#List of applications that won't be cloned
Get-ADDCCloningExcludedApplicationList -GenerateXML

#Create clone config file
$Params = @{
    CloneComputerName   =   "DC2"
    Static              =   $true
    IPv4Address         =   "192.168.10.14"
    IPv4SubnetMask      =   "255.255.255.0"
    IPv4DefaultGateway  =   "192.168.10.1"
    IPv4DNSResolver     =   "192.168.10.10"
}
New-ADDCCloneConfigFile @Params

#Shutdown DC1
Stop-Computer
```

## Export VM
```posh
Export-VM -Name "DC1" -Path E:\Export
Rename-Item -Path "E:\Export\DC1" -NewName "DC2"
Move-Item -Path "E:\Export\DC2" -Destination "E:\"
Remove-Item -Path "E:\Export"
```

## Import VM
```posh
Start-VM -Name "DC1"
$guid = (Get-VM "DC1").vmid.guid.ToUpper()
$Params = @{
    Path                =   "E:\DC2\$guid.vmcx"
    VirtualMachinePath  =   "E:\DC2"
    VhdDestinationPath  =   "E:\DC2"
    SnapshotFilePath    =   "E:\DC2"
    SmartPagingFilePath =   "E:\DC2"
    Copy                =   $true
    GenerateNewId       =   $true
}
Import-VM @Params
Get-VM DC1 | Where State -eq "Off" | Rename-VM -NewName DC2
Start-VM -Name "DC2"
```

## Inital configuration
```posh
#Rename the server
Rename-Computer -NewName DC1

#Restart the server
Restart-Computer -Force

#Set IP Address (Change InterfaceIndex param if there's more than one NIC)
$Params = @{
  IPAddress = "192.168.10.10"
  DefaultGateway = "192.168.10.1"
  PrefixLength = "24"
  InterfaceIndex = (Get-NetAdapter).InterfaceIndex
}
New-NetIPAddress @Params

#Configure DNS Settings
$Params = @{
  ServerAddresses = "192.168.10.10"
  InterfaceIndex = (Get-NetAdapter).InterfaceIndex
}
Set-DNSClientServerAddress @Params
```

## Install AD DS
```posh
#Install AD DS server role
Install-WindowsFeature -name AD-Domain-Services -IncludeManagementTools

#Configure server as a domain controller
Install-ADDSForest -DomainName ad.contoso.com -DomainNetBIOSName AD -InstallDNS
```

## DNS server configuration
```posh
Set-DnsServerForwarder -IPAddress "1.1.1.1" -PassThru
```

## Basic AD Configuration
```posh
#Create OU's
#Base OU
New-ADOrganizationalUnit “Contoso” –path “DC=ad,DC=contoso,DC=com”
#Devices
New-ADOrganizationalUnit “Devices” –path “OU=Contoso,DC=ad,DC=contoso,DC=com”
New-ADOrganizationalUnit “Servers” –path “OU=Devices,OU=Contoso,DC=ad,DC=contoso,DC=com”
New-ADOrganizationalUnit “Workstations” –path “OU=Devices,OU=Contoso,DC=ad,DC=contoso,DC=com”
#Users
New-ADOrganizationalUnit “Users” –path “OU=Contoso,DC=ad,DC=contoso,DC=com”
New-ADOrganizationalUnit “Admins” –path “OU=Users,OU=Contoso,DC=ad,DC=contoso,DC=com”
New-ADOrganizationalUnit “Employees” –path “OU=Users,OU=Contoso,DC=ad,DC=contoso,DC=com”
#Groups
New-ADOrganizationalUnit “Groups” –path “OU=Contoso,DC=ad,DC=contoso,DC=com”
New-ADOrganizationalUnit “SecurityGroups” –path “OU=Groups,OU=Contoso,DC=ad,DC=contoso,DC=com”
New-ADOrganizationalUnit “DistributionLists” –path “OU=Groups,OU=Contoso,DC=ad,DC=contoso,DC=com”
```

## Create users
```posh
#New admin user
$Params = @{
    Name = "Admin-John.Smith"
    AccountPassword = (Read-Host -AsSecureString "Enter Password")
    Enabled = $true
    ChangePasswordAtLogon = $true
    DisplayName = "John Smith - Admin"
    Path = “OU=Admins,OU=Users,OU=Contoso,DC=ad,DC=contoso,DC=com”
}
New-ADUser @Params
#Add admin to Domain Admins group
Add-ADGroupMember -Identity "Domain Admins" -Members "Admin-John.Smith"

#New domain user
$Params = @{
    Name = "John.Smith"
    AccountPassword = (Read-Host -AsSecureString "Enter Password")
    Enabled = $true
    ChangePasswordAtLogon = $true
    DisplayName = "John Smith"
    Company = "Contoso"
    Department = "Information Technology"
    Path = “OU=Employees,OU=Users,OU=Contoso,DC=ad,DC=contoso,DC=com”
}
New-ADUser @Params
#Will have issues logging in through Hyper-V Enhanced Session Mode if not in this group
Add-ADGroupMember -Identity "Remote Desktop Users" -Members "John.Smith"

#Add Company SGs and add members to it
New-ADGroup -Name "All-Staff" -SamAccountName "All-Staff" -GroupCategory Security -GroupScope Global -DisplayName "All-Staff" -Path "OU=SecurityGroups,OU=Groups,OU=Contoso,DC=ad,DC=contoso,DC=com" -Description "Members of this group are employees of Contoso"
Add-ADGroupMember -Identity "All-Staff" -Members "John.Smith"
```




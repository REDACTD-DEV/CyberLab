Set-DnsServerForwarder -IPAddress "1.1.1.1" -PassThru
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
#New admin user
$Params = @{
    Name = "Admin-John.Smith"
    AccountPassword = (ConvertTo-SecureString "1Password" -AsPlainText -Force)
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
    AccountPassword = (ConvertTo-SecureString "1Password" -AsPlainText -Force)
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
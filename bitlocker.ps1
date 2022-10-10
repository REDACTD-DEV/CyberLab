    #BitLocker Group Policy Configuration
    Write-Host "Creating BitLocker GPO" -ForegroundColor Blue -BackgroundColor Black
    $gpoOuObj=new-gpo -name "BitLocker"
    new-gplink -Guid $gpoOuObj.Id.Guid -target "OU=Workstations,OU=Devices,OU=Contoso,DC=ad,DC=contoso,DC=com"
    set-GPRegistryValue -Name BitLocker -Key "HKLM\Software\Policies\Microsoft\FVE" -Type "DWORD" -ValueName "ActiveDirectoryBackup" -Value 1
    set-GPRegistryValue -Name BitLocker -Key "HKLM\Software\Policies\Microsoft\FVE" -Type "DWORD" -ValueName "ActiveDirectoryInfoToStore" -Value 1
    set-GPRegistryValue -Name BitLocker -Key "HKLM\Software\Policies\Microsoft\FVE" -Type "DWORD" -ValueName "OSActiveDirectoryBackup" -Value 1
    set-GPRegistryValue -Name BitLocker -Key "HKLM\Software\Policies\Microsoft\FVE" -Type "DWORD" -ValueName "OSActiveDirectoryInfoToStore" -Value 1
    set-GPRegistryValue -Name BitLocker -Key "HKLM\Software\Policies\Microsoft\FVE" -Type "DWORD" -ValueName "OSEncryptionType" -Value 2
    set-GPRegistryValue -Name BitLocker -Key "HKLM\Software\Policies\Microsoft\FVE" -Type "DWORD" -ValueName "OSHideRecoveryPage" -Value 0
    set-GPRegistryValue -Name BitLocker -Key "HKLM\Software\Policies\Microsoft\FVE" -Type "DWORD" -ValueName "OSManageDRA" -Value 1
    set-GPRegistryValue -Name BitLocker -Key "HKLM\Software\Policies\Microsoft\FVE" -Type "DWORD" -ValueName "OSRecovery" -Value 1
    set-GPRegistryValue -Name BitLocker -Key "HKLM\Software\Policies\Microsoft\FVE" -Type "DWORD" -ValueName "OSRecoveryKey" -Value 2
    set-GPRegistryValue -Name BitLocker -Key "HKLM\Software\Policies\Microsoft\FVE" -Type "DWORD" -ValueName "OSRecoveryPassword" -Value 2
    set-GPRegistryValue -Name BitLocker -Key "HKLM\Software\Policies\Microsoft\FVE" -Type "DWORD" -ValueName "OSRequireActiveDirectoryBackup" -Value 1
    set-GPRegistryValue -Name BitLocker -Key "HKLM\Software\Policies\Microsoft\FVE" -Type "DWORD" -ValueName "RequireActiveDirectoryBackup" -Value 1
    
    
    #On Client
    gpupdate /force
    Enable-BitLocker -MountPoint "C:" -RecoveryPasswordProtector -UsedSpaceOnly
    Restart-Computer -Force

#
# Tester.ps1
#

#$strScriptName = ($MyInvocation.MyCommand.Name).Substring(0,($MyInvocation.MyCommand.Name).Length-4)
#$strEventLogSource = "Custom Script Logger"

#Write-Host $strScriptName

#$colAvailableEventSources = (Get-ChildItem HKLM:\SYSTEM\CurrentControlSet\Services\EventLog\Application).PSChildName
#If ($colAvailableEventSources -notcontains $strEventLogSource) {
#	New-EventLog -LogName Application -Source $strEventLogSource
#}

#Write-EventLog -LogName Application -Source $strEventLogSource -EventId "9999" -EntryType Information -Message ($strScriptName + ": Test message") -Category 0

####################### Add specified Filesystem/registry permission ############################
function Add-ACLPermission ($strPath, $strUserName, $strPermissions, $strInheritance) {
    Try {
		$objCurrentAcl = (Get-Item $strPath).GetAccessControl('Access')
		If ($objCurrentAcl -eq $NULL) {
            LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("The object `"" + $strPath + "`" does not exist or the user does not have permission to read it.")
			Return -3
		}
		If (($objCurrentAcl.GetType()).Name -eq "RegistrySecurity") {
			$objRuleToAdd = New-Object System.Security.AccessControl.RegistryAccessRule ($strUserName,$strPermissions,$strInheritance,"None","Allow")
		} ElseIf (($objCurrentAcl.GetType()).Name -eq "DirectorySecurity") {
			$objRuleToAdd = New-Object System.Security.AccessControl.FileSystemAccessRule ($strUserName,$strPermissions,$strInheritance,"None","Allow")
		} Else {
			LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("The object type is unknown!")
			Return -4
		}
		$objCurrentAcl.AddAccessRule($objRuleToAdd)
		Set-Acl -Path $strPath -AclObject $objCurrentAcl -ErrorAction Stop
	} Catch {
        $Comment = $_.Exception
        If ($Comment -like "*access is not allowed*") {
            LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("The current user has no permission to access the specified object")
			Return -2
        } Else {
			LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("The addition of the permission has failed with the following exception:`r`n" + $Comment)
			Return -1
		}
    }
}
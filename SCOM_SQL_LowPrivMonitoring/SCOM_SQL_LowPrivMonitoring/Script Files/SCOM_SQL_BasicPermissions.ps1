#
# Script.ps1
#
###################### INIT #############################################################
[CmdletBinding()]
Param(
	[Parameter(Mandatory=$True)]
	[ValidateScript({Test-Path $_ -PathType ‘Leaf’})]
	[Alias("ConfigFile")]
	[string]$strConfigFilePath
)

$strScriptPath = $NULL
$strScriptName = $NULL
$strLogFile = $NULL

function Get-ScriptDirectory
{
	$Invocation = $NULL
	$Invocation = (Get-Variable MyInvocation -Scope 1).Value
	If ($Invocation -eq $NULL) {
		If ($strLogFile -eq $NULL) {
			$strCommand = $ErrorReturn.InvocationInfo.Line
			$strException = $ErrorReturn.Exception
			Write-Host "Error occured during command: $strCommand `r`nThe exception of the error is: $strException"
			Exit -1
		}
		Else {
			$strCommand = $ErrorReturn.InvocationInfo.Line
			$strException = $ErrorReturn.Exception
			LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData "Error occured during command: $strCommand"
			LogToFile -intLogType $constDATA -strFile $strLogFile -strLogData "The exception of the error is: $strException"
			$ReturnValue = $false
			return
		}
		
	}
	Split-Path $Invocation.MyCommand.Path
}

.((Get-ScriptDirectory) + "\Logging.ps1")

If (-not($strScriptPath = Get-ScriptDirectory)) {
	Write-Host "The script cannot determinde its working directory. Without this parameter the script cannot run. Please check and run the script again!"
	Exit -2
}
$strScriptName = ($MyInvocation.MyCommand.Name).Substring(0,($MyInvocation.MyCommand.Name).Length-4)
$strLogFile = ($strScriptPath + "\" + $strScriptName + ".log")
$blnCheckError = $false

####################### Function to finish the script #################
function End-Script($blnWithError) {
	Write-Host -ForegroundColor Yellow "The script is finishing."
	If ($blnWithError -eq $True) {
		LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData "The script $strScriptName finished with errors. Please check the log for related entries. Fix the errors and run the script again."
		Write-Host "Press any key to continue..."
		$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
		Exit (-10)
	} Else {
		LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData "The script $strScriptName finished successfully"
		Write-Host "Press any key to continue..."
		$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
		Exit (0)
	}
}

####################### Function to get admin credential ###########################
function Get-RunAsCredential()
{
	$Error.Clear()
	$objError = $null
	$objCredential = Get-Credential -Message "RunAs user with Administrative rights"
	$objError = $Error[0]
	If ($objError -ne $null) {
		LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("An error occured when the script tried to store the credential")
		LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("Exception: " + $objError.Exception)
		Return -1
	}
	LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData "The inserted credential is successfully stored."
	LogToFile -intLogType $constDATA -strFile $strLogFile -strLogData ("Username: " + $objCredential.UserName + "`r`nPassword string: " + ($objCredential.Password | ConvertFrom-SecureString))
	Return $objCredential
}

####################### Function to add user to group ##############################
function Add-ADObjectToGroup($strDomain, $strObjectName, $strLocalGroupName, $Computer) {
	Try {
		$objGroup = [ADSI]"WinNT://$Computer/$strLocalGroupName"
		$objGroup.Add("WinNT://$strDomain/$strObjectName")
		LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData ("Object named " + $strDomain + "\" + $strObjectName + " has been added to the group called `"" + $strLocalGroupName + "`" on computer: " + $Computer)
	} Catch {
		$Comment = $_.Exception
		If ($Comment -like "*The specified account name is already a member of the group*") {
			LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData ("The object is already a member of the specified group")
		} ElseIf ($Comment -like "*A member could not be added to or removed from the local group because the member does not exist*") {
			LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("The object $strDomain/$strObjectName does not exist")
			Return -2
		} ElseIf ($Comment -like "*Access is denied*") {
			LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("The object $strDomain/$strObjectName cannot be added to the specified group, because the user runs this script has no rights to access the Active Directory")
			Return -3			
		} Else {
			LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("The addition of the object has failed with the following exception:`r`n" + $Comment)
			Return -1
		}
	}
	Return 0
}

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
####################### Functions to modify WMI Namespace Security ###################

Function Get-AccessMaskFromPermission($strPermissionList) {
	$WBEM_ENABLE = 1
	$WBEM_METHOD_EXECUTE = 2
	$WBEM_FULL_WRITE_REP = 4
	$WBEM_PARTIAL_WRITE_REP = 8
	$WBEM_WRITE_PROVIDER = 0x10
	$WBEM_REMOTE_ACCESS = 0x20
	$WBEM_RIGHT_SUBSCRIBE = 0x40
	$WBEM_RIGHT_PUBLISH = 0x80
	$READ_CONTROL = 0x20000
	$WRITE_DAC = 0x40000
      
	$WBEM_RIGHTS_FLAGS = $WBEM_ENABLE,$WBEM_METHOD_EXECUTE,$WBEM_FULL_WRITE_REP,$WBEM_PARTIAL_WRITE_REP,$WBEM_WRITE_PROVIDER,$WBEM_REMOTE_ACCESS,$READ_CONTROL,$WRITE_DAC
	$WBEM_RIGHTS_STRINGS = "Enable","MethodExecute","FullWrite","PartialWrite","ProviderWrite","RemoteAccess","ReadSecurity","WriteSecurity"

	$permissionTable = @{}

	for ($i = 0; $i -lt $WBEM_RIGHTS_FLAGS.Length; $i++) {
		$permissionTable.Add($WBEM_RIGHTS_STRINGS[$i].ToLower(), $WBEM_RIGHTS_FLAGS[$i])
	}
	$accessMask = 0
	foreach ($strPermission in $strPermissionList) {
		if (-not $permissionTable.ContainsKey($strPermission.ToLower())) {
			LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("Unknown permission: $strPermission`nValid permissions: $($permissionTable.Keys)")
			Return -1
		}
		$accessMask += $permissionTable[$strPermission.ToLower()]
	}   
	return $accessMask
}

Function Set-WmiNamespaceSecurity {
 
Param (
    [parameter(Mandatory=$true,Position=0)]
    [string]$strNameSpace,
    [parameter(Mandatory=$true,Position=1)]
    [string] $strOperation,
    [parameter(Mandatory=$true,Position=2)]
    [string] $strAccount,
    [parameter(Position=3)]
    [string[]] $strPermissionList = $null,
    [bool] $allowInherit = $false,
    [bool] $deny = $false,
    [string] $strComputer = ".",
    [System.Management.Automation.PSCredential] $credCredential = $null)
   
	$ErrorActionPreference = "Stop"

	if ($PSBoundParameters.ContainsKey("Credential")) {
		$remoteparams = @{ComputerName=$strComputer;Credential=$credCredential}
	} else {
		$remoteparams = @{ComputerName=$strComputer}
	}
	
	$invokeparams = @{Namespace=$strNameSpace;Path="__systemsecurity=@"} + $remoteParams
	
	$output = Invoke-WmiMethod @invokeparams -Name GetSecurityDescriptor
	if ($output.ReturnValue -ne 0) {
		LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("GetSecurityDescriptor failed: $($output.ReturnValue)")
		Return -1
	}
	
	$acl = $output.Descriptor
	$OBJECT_INHERIT_ACE_FLAG = 0x1
	$CONTAINER_INHERIT_ACE_FLAG = 0x2
	
	$computerName = (Get-WmiObject @remoteparams Win32_ComputerSystem).Name
	
	if ($strAccount.Contains('\')) {
		$domainaccount = $strAccount.Split('\')
		$domain = $domainaccount[0]
		if (($domain -eq ".") -or ($domain -eq "BUILTIN")) {
			$domain = $computerName
		}
		$accountname = $domainaccount[1]
	} elseif ($strAccount.Contains('@')) {
		$domainaccount = $strAccount.Split('@')
		$domain = $domainaccount[1].Split('.')[0]
		$accountname = $domainaccount[0]
	} else {
		$domain = $computerName
		$accountname = $strAccount
	}
	
	$getparams = @{Class="Win32_Account";Filter="Domain='$domain' and Name='$accountname'"}
	
	$win32account = Get-WmiObject @getparams
	
	if ($win32account -eq $null) {
		LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("Account was not found: $strAccount")
		Return -2
	}
	
	switch ($strOperation) {
		"add" {
			if ($strPermissionList -eq $null) {
				LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("No permission was specified for `"ADD`" function")
				return -3
			}
			$accessMask = Get-AccessMaskFromPermission($strPermissionList)
			If ($accessMask -eq -1) {
				return -4
			}
			
			$ace = (New-Object System.Management.ManagementClass("win32_Ace")).CreateInstance()
			$ace.AccessMask = $accessMask
			if ($allowInherit) {
				$ace.AceFlags = $OBJECT_INHERIT_ACE_FLAG + $CONTAINER_INHERIT_ACE_FLAG
			} else {
				$ace.AceFlags = 0
			}
			
			$trustee = (New-Object System.Management.ManagementClass("win32_Trustee")).CreateInstance()
			$trustee.SidString = $win32account.Sid
			$ace.Trustee = $trustee
			
			$ACCESS_ALLOWED_ACE_TYPE = 0x0
			$ACCESS_DENIED_ACE_TYPE = 0x1
			
			if ($deny) {
				$ace.AceType = $ACCESS_DENIED_ACE_TYPE
			} else {
				$ace.AceType = $ACCESS_ALLOWED_ACE_TYPE
			}
			
			$acl.DACL += $ace.psobject.immediateBaseObject
		
		}
		"delete" {
			if ($strPermissionList -ne $null) {
				LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("Permissions cannot be specified for a `"DELETE`" operation")
				return -3
			}
			[System.Management.ManagementBaseObject[]]$newDACL = @()
			foreach ($ace in $acl.DACL) {
				if ($ace.Trustee.SidString -ne $win32account.Sid) {
					$newDACL += $ace.psobject.immediateBaseObject
				}
			}
			
			$acl.DACL = $newDACL.psobject.immediateBaseObject
		}
		
		default {
			LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("Unknown operation: $strOperation`nAllowed operations: add delete")
			return -5
		}
	}
	
	$setparams = @{Name="SetSecurityDescriptor";ArgumentList=$acl.psobject.immediateBaseObject} + $invokeParams
	
	$output = Invoke-WmiMethod @setparams
	if ($output.ReturnValue -ne 0) {
		LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("SetSecurityDescriptor failed: $($output.ReturnValue)")
		return -6
	}
}

####################### Starting the script ##########################################

LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData ("The script `"" + $strScriptName + "`" has been started...")
Write-Host -ForegroundColor Yellow "##################################################################"
Write-Host -ForegroundColor Yellow ("          Starting script " + $strScriptName)
Write-Host -ForegroundColor Yellow "##################################################################"


###################### Loading XML from the specified directory #####################

Write-Host -ForegroundColor Magenta "`r`nLoading configuration from XML file"
Write-Host -ForegroundColor Yellow -NoNewline "Service Accounts..."
[xml]$xmlConfiguration = Get-Content $strConfigFilePath
$colAccounts = @()

foreach ($objAccount in $xmlConfiguration.configuration.Principals.UserAccounts.UserAccount) {
	LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData ("Adding service user to collection - Type: " + $objAccount.Type + "UserName: " + $xmlConfiguration.configuration.Principals.UserAccounts.Domain + "\" + $objAccount.UserName)
	If (($objAccount.Type -eq "") -or ($objAccount.UserName -eq "") -or ($xmlConfiguration.configuration.Principals.UserAccounts.Domain -eq "")) {
		LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("The Service Account information is incorrect. Please check it and run the script again...")
		Write-Host -ForegroundColor Red "FAIL!"
		End-Script -blnWithError $True
	}
	$objData = New-Object –TypeName PSObject
	$objData | Add-Member –MemberType NoteProperty –Name Type –Value $objAccount.Type
	$objData | Add-Member –MemberType NoteProperty –Name UserName –Value $objAccount.UserName
	$objData | Add-Member –MemberType NoteProperty –Name Domain –Value $xmlConfiguration.configuration.Principals.UserAccounts.Domain
	$colAccounts += $objData
}
Write-Host -ForegroundColor Green "DONE!"

Write-Host -ForegroundColor Yellow -NoNewline "Security Group..."
$objGroup = New-Object –TypeName PSObject
$objGroup | Add-Member –MemberType NoteProperty –Name GroupName –Value $xmlConfiguration.configuration.Principals.Group.GroupName
$objGroup | Add-Member –MemberType NoteProperty –Name Domain –Value $xmlConfiguration.configuration.Principals.Group.Domain
$objGroup | Add-Member –MemberType NoteProperty –Name Used –Value $xmlConfiguration.configuration.Principals.Group.Used
LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData ("Loading security group to variable - Used: " + $objGroup.Used + "Principal: " + $objGroup.Domain + "\" + $objGroup.GroupName)
If (($objGroup.Used -eq "True") -and (($objGroup.GroupName -eq "") -or ($objGroup.Domain -eq ""))) {
	LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("The security group information is incorrect. Please check it and run the script again...")
	Write-Host -ForegroundColor Red "FAIL!"
	End-Script -blnWithError $True
}
Write-Host -ForegroundColor Green "DONE!"

Write-Host -ForegroundColor Yellow -NoNewline "SQL Instances..."
$objInstances = New-Object –TypeName PSObject
$objInstances | Add-Member –MemberType NoteProperty –Name InstanceNames –Value $xmlConfiguration.configuration.Instances.InstanceName
$objInstances | Add-Member –MemberType NoteProperty –Name InstanceVersion –Value $xmlConfiguration.configuration.Instances.Version
$objInstances | Add-Member –MemberType NoteProperty –Name ServerName –Value $xmlConfiguration.configuration.Instances.ServerName
LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData ("Loading instance information to variable - ServerName: " + $objInstances.ServerName + "Version: " + $objInstances.Version + "Instances: " + $objInstances.InstanceNames)
If (($objInstances.ServerName -eq "") -or ($objInstances.Version -eq "") -or ($objInstances.InstanceNames -eq "")) {
	LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("The instances information is incorrect. Please check it and run the script again...")
	Write-Host -ForegroundColor Red "FAIL!"
	End-Script -blnWithError $True
}

Write-Host -ForegroundColor Green "DONE!"

if ($objInstances.ServerName -eq "local"){
	$strServerName = $env:COMPUTERNAME
	LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData ("The script is running locally on " + $strServerName + "...")
} Else {
	$strServerName = $objInstances.ServerName
	LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData ("The script is running remotely on " + $strServerName + "...")
}

######################## Adding users to local groups ##################

Write-Host -ForegroundColor Magenta "`r`nAdding accounts to the specified local groups"

###### - Default Action Account to "Performance Monitor Users", "Event Log Readers" and "Users"
$colLocalGroups = @("Performance Monitor Users","Event Log Readers","Users")
Write-Host -ForegroundColor Magenta "`r`nDefault Action Account"
foreach ($objADObject in $colAccounts | ? {$_.Type -eq "DefaultAction"}) {
	foreach ($objLocalGroup in $colLocalGroups) {
		Write-Host -ForegroundColor Yellow -NoNewline ("Adding " + $objADObject.Domain + "\" + $objADObject.UserName + " (Default Action Account) to group `"" + $objLocalGroup + "`" on server `"" + $strServerName + "`"...")
		LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData ("Adding " + $objADObject.Domain + "\" + $objADObject.UserName + " (Default Action Account) to group `"" + $objLocalGroup + "`" on server `"" + $strServerName + "`"...")
		$return = Add-ADObjectToGroup -strDomain $objADObject.Domain -strObjectName $objADObject.UserName -strLocalGroupName $objLocalGroup -Computer $strServerName
		If ($return -eq -1) {
			Write-Host -ForegroundColor Red "FAIL!"
		} ElseIf ($return -eq -2) {
			Write-Host -ForegroundColor Red "FAIL!"
			End-Script -blnWithError $True
		} ElseIf ($return -eq -3) {
			Write-Host -ForegroundColor Red "FAIL!"
			End-Script -blnWithError $True
		} Else {
			Write-Host -ForegroundColor Green "DONE!"
		}
	}
}

###### - Monitoring Account to "Performance Monitor Users" and "Event Log Readers"
If ($objGroup.Used -eq "True") {
	$colLocalGroups = @("Performance Monitor Users","Event Log Readers")
} Else {
	$colLocalGroups = @("Performance Monitor Users","Event Log Readers","Users")
}
Write-Host -ForegroundColor Magenta "`r`nMonitoring Account"
foreach ($objADObject in $colAccounts | ? {$_.Type -eq "Monitoring"}) {
	foreach ($objLocalGroup in $colLocalGroups) {
		Write-Host -ForegroundColor Yellow -NoNewline ("Adding " + $objADObject.Domain + "\" + $objADObject.UserName + " (Monitoring Account) to group `"" + $objLocalGroup + "`" on server `"" + $strServerName + "`"...")
		LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData ("Adding " + $objADObject.Domain + "\" + $objADObject.UserName + " (Monitoring Account) to group `"" + $objLocalGroup + "`" on server `"" + $strServerName + "`"...")
		$return = Add-ADObjectToGroup -strDomain $objADObject.Domain -strObjectName $objADObject.UserName -strLocalGroupName $objLocalGroup -Computer $strServerName
		If ($return -eq -1) {
			Write-Host -ForegroundColor Red "FAIL!"
		} ElseIf ($return -eq -2) {
			Write-Host -ForegroundColor Red "FAIL!"
			End-Script -blnWithError $True
		} ElseIf ($return -eq -3) {
			Write-Host -ForegroundColor Red "FAIL!"
			End-Script -blnWithError $True
		} Else {
			Write-Host -ForegroundColor Green "DONE!"
		}
	}
}

###### - LowPriv group to "Users" 

If ($objGroup.Used -eq "True") {
	Write-Host -ForegroundColor Magenta "`r`nLowPriv group"
	$colLocalGroups = @("Users")
	foreach ($objLocalGroup in $colLocalGroups) {
		Write-Host -ForegroundColor Yellow -NoNewline ("Adding " + $objGroup.Domain + "\" + $objGroup.GroupName + " to group `"" + $objLocalGroup + "`" on server `"" + $strServerName + "`"...")
		LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData ("Adding " + $objGroup.Domain + "\" + $objGroup.GroupName + " to group `"" + $objLocalGroup + "`" on server `"" + $strServerName + "`"...")
		$return = Add-ADObjectToGroup -strDomain $objGroup.Domain -strObjectName $objGroup.GroupName -strLocalGroupName $objLocalGroup -Computer $strServerName
		If ($return -eq -1) {
			Write-Host -ForegroundColor Red "FAIL!"
		} ElseIf ($return -eq -2) {
			Write-Host -ForegroundColor Red "FAIL!"
			End-Script -blnWithError $True
		} ElseIf ($return -eq -3) {
			Write-Host -ForegroundColor Red "FAIL!"
			End-Script -blnWithError $True
		} Else {
			Write-Host -ForegroundColor Green "DONE!"
		}
	}
} Else {
	Write-Host -ForegroundColor Magenta "`r`nNo LowPriv group is used"
	$colLocalGroups = @("Users")
	foreach ($objADObject in $colAccounts | ? {$_.Type -eq "Discovery" -or $_.Type -eq "Monitoring"}) {
		foreach ($objLocalGroup in $colLocalGroups) {
			Write-Host -ForegroundColor Yellow -NoNewline ("Adding " + $objADObject.Domain + "\" + $objADObject.UserName + " (Discovery Account) to group `"" + $objLocalGroup + "`" on server `"" + $strServerName + "`"...")
			LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData ("Adding " + $objADObject.Domain + "\" + $objADObject.UserName + " (Discovery Account) to group `"" + $objLocalGroup + "`" on server `"" + $strServerName + "`"...")
			$return = Add-ADObjectToGroup -strDomain $objADObject.Domain -strObjectName $objADObject.UserName -strLocalGroupName $objLocalGroup -Computer $strServerName
			If ($return -eq -1) {
				Write-Host -ForegroundColor Red "FAIL!"
			} ElseIf ($return -eq -2) {
				Write-Host -ForegroundColor Red "FAIL!"
				End-Script -blnWithError $True
			} ElseIf ($return -eq -3) {
				Write-Host -ForegroundColor Red "FAIL!"
				End-Script -blnWithError $True
			} Else {
				Write-Host -ForegroundColor Green "DONE!"
			}
		}
	}
}

######################## Set Registry permissions ######################

Write-Host -ForegroundColor Magenta "`r`nSetting up registry permissions"
Write-Host -ForegroundColor Green "`r`nCollecting information of SQL Instances installed on the server"
If ($objInstances.InstanceNames[0] -eq "All") {
	If ($objInstances.InstanceVersion -eq "2012") {
		$colInstances = Get-WmiObject -Namespace ROOT\Microsoft\SqlServer\ComputerManagement11 -Class SqlServiceAdvancedProperty | ? {($_.PropertyName -eq "INSTANCEID") -and ($_.PropertyIndex -eq 12)}
		$colRegKeys = @("HKLM:\Software\Microsoft\Microsoft SQL Server")
		foreach ($objInstance in $colInstances) {
			$colRegKeys += ("HKLM:\Software\Microsoft\Microsoft SQL Server\" + $objInstance.PropertyStrValue + "\MSSQLServer\Parameters")
		}
	} ElseIf ($objInstances.InstanceVersion -eq "2014") {
		$colInstances = Get-WmiObject -Namespace ROOT\Microsoft\SqlServer\ComputerManagement12 -Class SqlServiceAdvancedProperty | ? {($_.PropertyName -eq "INSTANCEID") -and ($_.PropertyIndex -eq 12)}
		$colRegKeys = @("HKLM:\Software\Microsoft\Microsoft SQL Server")
		foreach ($objInstance in $colInstances) {
			$colRegKeys += ("HKLM:\Software\Microsoft\Microsoft SQL Server\" + $objInstance.PropertyStrValue + "\MSSQLServer\Parameters")
		}
	}
} Else {
	If ($objInstances.InstanceVersion -eq "2012") {
		$colInstances = Get-WmiObject -Namespace ROOT\Microsoft\SqlServer\ComputerManagement11 -Class SqlServiceAdvancedProperty | ? {($_.PropertyName -eq "INSTANCEID") -and ($_.PropertyIndex -eq 12)}
		$colRegKeys = @("HKLM:\Software\Microsoft\Microsoft SQL Server")
		foreach ($objInstance in $objInstances.InstanceNames) {
			If ($objInstance -eq "MSSQLSERVER") {
				$strServiceName = $objInstance
			} Else {
				$strServiceName = ("MSSQL$" + $objInstance)
			}
			$strInstanceRegID = ""
			$strInstanceRegID = $colInstances | ? {$_.ServiceName -eq $strServiceName} | Select PropertyStrValue
			If (($strInstanceRegID.PropertyStrValue -eq $NULL) -or ($strInstanceRegID.PropertyStrValue -eq "")) {
				Write-Host "No such instance as `"$objInstance`" installed on this server"
				LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("No such instance as `"$objInstance`" installed on this server")
				End-Script -blnWithError $True
			} ElseIf ($strInstanceRegID.count -gt 1) {
				Write-Host "The search for the instance `"$objInstance`" resulted multiple entries. It will not be added to the collection."
				LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("The search for the instance `"" + $objInstance + "`" resulted multiple entries. It will not be added to the collection.")
				End-Script -blnWithError $True
			}
			$colRegKeys += ("HKLM:\Software\Microsoft\Microsoft SQL Server\" + $strInstanceRegID.PropertyStrValue + "\MSSQLServer\Parameters")
		}
	} ElseIf ($objInstances.InstanceVersion -eq "2014") {
		$colRegKeys = @("HKLM:\Software\Microsoft\Microsoft SQL Server")
		$colInstances = Get-WmiObject -Namespace ROOT\Microsoft\SqlServer\ComputerManagement12 -Class SqlServiceAdvancedProperty | ? {($_.PropertyName -eq "INSTANCEID") -and ($_.PropertyIndex -eq 12)}
		$colRegKeys = @("HKLM:\Software\Microsoft\Microsoft SQL Server")
		foreach ($objInstance in $objInstances.InstanceNames) {
			If ($objInstance -eq "MSSSQLSERVER") {
				$strServiceName = $objInstance
			} Else {
				$strServiceName = ("MSSQL$" + $objInstance)
			}
			$strInstanceRegID = ""
			$strInstanceRegID = $colInstances | ? {$_.ServiceName -eq $strServiceName} | Select PropertyStrValue
			If (($strInstanceRegID.PropertyStrValue -eq $NULL) -or ($strInstanceRegID.PropertyStrValue -eq "")) {
				Write-Host "No such instance as `"$objInstance`" installed on this server"
				LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("No such instance as `"$strInstanceRegID`" installed on this server")
				End-Script -blnWithError $True
			} ElseIf ($strInstanceRegID.count -gt 1) {
				Write-Host "The search for the instance `"$objInstance`" resulted multiple entries. It will not be added to the collection."
				LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("The search for the instance `"" + $objInstance + "`" resulted multiple entries. It will not be added to the collection.")
				End-Script -blnWithError $True
			}
			$colRegKeys += ("HKLM:\Software\Microsoft\Microsoft SQL Server\" + $strInstanceRegID.PropertyStrValue + "\MSSQLServer\Parameters")
		}
	}
}

$strRegPermissions = "QueryValues,EnumerateSubKeys,Notify,ReadPermissions"
$strRegInheritance = "ObjectInherit,ContainerInherit"

Write-Host "`r`n"
foreach ($objAccount in $colAccounts | ? {$_.Type -eq "Discovery" -or $_.Type -eq "Monitoring" -or $_.Type -eq "DefaultAction"}) {
	Foreach ($objRegKey in $colRegKeys) {
		Write-Host -ForegroundColor Yellow -NoNewline ("Granting `"" + $strRegPermissions + "`" permissions to object `"" + $objAccount.Domain + "\" + $objAccount.UserName + "`" on RegKey `"" + $objRegKey + "`"...")
		LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData ("Granting " + $strRegPermissions + " permissions to object " + $objAccount.Domain + "\" + $objAccount.UserName + "`" on RegKey `"" + $objRegKey + "`"...")
		$return = Add-ACLPermission -strPath $objRegKey -strUserName ($objAccount.Domain + "\" + $objAccount.UserName) -strPermissions $strRegPermissions -strInheritance $strRegInheritance
		If ($return -eq -1) {
			Write-Host -ForegroundColor Red "FAIL!"
		} ElseIf ($return -eq -2) {
			Write-Host -ForegroundColor Red "FAIL!"
			End-Script -blnWithError $True
		} ElseIf ($return -eq -3) {
			Write-Host -ForegroundColor Red "FAIL!"
			End-Script -blnWithError $True
		} ElseIf ($return -eq -4) {
			Write-Host -ForegroundColor Red "FAIL!"
			End-Script -blnWithError $True			
		} Else {
			Write-Host -ForegroundColor Green "DONE!"
		}
	}
}

######################## Set permission to Windows Temp folder #########

Write-Host -ForegroundColor Magenta "`r`nSetting up permission to Windows Temp folder"

$strFolder = "C:\Windows\Temp"
$strFolderPermission = "Modify"

foreach ($objAccount in $colAccounts | ? {$_.Type -eq "Monitoring"}) {
	Write-Host -ForegroundColor Yellow -NoNewline ("Granting `"" + $strFolderPermission + "`" permissions to object `"" + $objAccount.Domain + "\" + $objAccount.UserName + "`" on folder `"" + $strFolder + "`"...")
	LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData ("Granting `"" + $strFolderPermission + "`" permissions to object `"" + $objAccount.Domain + "\" + $objAccount.UserName + "`" on folder `"" + $strFolder + "`"...")
	$return = Add-ACLPermission -strPath $strFolder -strUserName ($objAccount.Domain + "\" + $objAccount.UserName) -strPermissions $strFolderPermission -strInheritance $strRegInheritance
	If ($return -eq -1) {
		Write-Host -ForegroundColor Red "FAIL!"
	} ElseIf ($return -eq -2) {
		Write-Host -ForegroundColor Red "FAIL!"
		End-Script -blnWithError $True
	} ElseIf ($return -eq -3) {
		Write-Host -ForegroundColor Red "FAIL!"
		End-Script -blnWithError $True
		} ElseIf ($return -eq -4) {
			Write-Host -ForegroundColor Red "FAIL!"
			End-Script -blnWithError $True			
	} Else {
		Write-Host -ForegroundColor Green "DONE!"
	}
}

######################## Set WMI namespace permissions #################

Write-Host -ForegroundColor Magenta "`r`nSetting Up WMI namespace permissions"

If ($objInstances.InstanceVersion -eq "2012") {
	$colWMINameSpaces = @("root","root\cimv2","root\default","Root\Microsoft\SqlServer\ComputerManagement11")
} ElseIf ($objInstances.InstanceVersion -eq "2014") {
	$colWMINameSpaces = @("root","root\cimv2","root\default","Root\Microsoft\SqlServer\ComputerManagement12")
}
$colPermissionList = @("MethodExecute","Enable","RemoteAccess","ReadSecurity")

foreach ($objWMINameSpace in $colWMINameSpaces) {
	foreach ($objAccount in $colAccounts | ? {$_.Type -eq "Discovery" -or $_.Type -eq "Monitoring" -or $_.Type -eq "DefaultAction"}) {
		Write-Host -ForegroundColor Yellow -NoNewline ("Granting `"" + $colPermissionList + "`" permissions to object `"" + $objAccount.Domain + "\" + $objAccount.UserName + "`" on WMI Namespace `"" + $objWMINameSpace + "`"...")
		LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData ("Granting `"" + $colPermissionList + "`" permissions to object `"" + $objAccount.Domain + "\" + $objAccount.UserName + "`" on WMI Namespace `"" + $objWMINameSpace + "`"...")
		$return = Set-WmiNamespaceSecurity -strNameSpace $objWMINameSpace -strOperation "add" -strAccount ($objAccount.Domain + "\" + $objAccount.UserName) -strPermissionList $colPermissionList
		If ($return -eq -1) {
			Write-Host -ForegroundColor Red "FAIL!"
		} ElseIf ($return -eq -2) {
			Write-Host -ForegroundColor Red "FAIL!"
			End-Script -blnWithError $True
		} ElseIf ($return -eq -3) {
			Write-Host -ForegroundColor Red "FAIL!"
			End-Script -blnWithError $True
		} ElseIf ($return -eq -4) {
			Write-Host -ForegroundColor Red "FAIL!"
			End-Script -blnWithError $True			
		} ElseIf ($return -eq -5) {
			Write-Host -ForegroundColor Red "FAIL!"
			End-Script -blnWithError $True			
		} ElseIf ($return -eq -6) {
			Write-Host -ForegroundColor Red "FAIL!"
			End-Script -blnWithError $True			
		} Else {
			Write-Host -ForegroundColor Green "DONE!"
		}
	}
}

######################## Script finished ###############################

End-Script -blnWithError $False

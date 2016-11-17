#
# Script.ps1
#
###################### INIT #############################################################
[CmdletBinding()]
Param(
	[Parameter(Mandatory=$True)]
	[ValidateScript({Test-Path $_ -PathType ‘Leaf’})]
	[Alias("ServiceAccount")]
	[string]$strServiceAccount
)

$strEventLogSource = "Custom Script Logger"
$strScriptName = ($MyInvocation.MyCommand.Name).Substring(0,($MyInvocation.MyCommand.Name).Length-4)
$strDomain = ($strServiceAccount.Split("\"))[0]
$strAccountName = ($strServiceAccount.Split("\"))[1]

####################### Prepare script to write event log ###############################

$colAvailableEventSources = (Get-ChildItem HKLM:\SYSTEM\CurrentControlSet\Services\EventLog\Application).PSChildName
If ($colAvailableEventSources -notcontains $strEventLogSource) {
	New-EventLog -LogName Applcation -Source $strEventLogSource
}

####################### Function to finish the script #################
function End-Script($blnWithError) {
	If ($blnWithError -eq $True) {
		Exit (-10)
	} Else {
		Exit (0)
	}
}

####################### Function to add user to group ##############################
function Add-ADObjectToGroup($strDomain, $strObjectName, $strLocalGroupName) {
	Try {
		$objGroup = [ADSI]"WinNT://localhost/$strLocalGroupName"
		$objGroup.Add("WinNT://$strDomain/$strObjectName")
	} Catch {
		$Comment = $_.Exception
		If ($Comment -like "*The specified account name is already a member of the group*") {
			return 0
		} ElseIf ($Comment -like "*A member could not be added to or removed from the local group because the member does not exist*") {
			Return -2
		} ElseIf ($Comment -like "*Access is denied*") {
			Return -3			
		} Else {
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
			Return -3
		}
		If (($objCurrentAcl.GetType()).Name -eq "RegistrySecurity") {
			$objRuleToAdd = New-Object System.Security.AccessControl.RegistryAccessRule ($strUserName,$strPermissions,$strInheritance,"None","Allow")
		} ElseIf (($objCurrentAcl.GetType()).Name -eq "DirectorySecurity") {
			$objRuleToAdd = New-Object System.Security.AccessControl.FileSystemAccessRule ($strUserName,$strPermissions,$strInheritance,"None","Allow")
		} Else {
			Return -4
		}
		$objCurrentAcl.AddAccessRule($objRuleToAdd)
		Set-Acl -Path $strPath -AclObject $objCurrentAcl -ErrorAction Stop
	} Catch {
        $Comment = $_.Exception
        If ($Comment -like "*access is not allowed*") {
			Return -2
        } Else {
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

#???

######################## Adding users to local groups ##################

###### Action Account to "Performance Monitor Users", "Event Log Readers" and "Users" ##############
$colLocalGroups = @("Performance Monitor Users","Event Log Readers","Users")
foreach ($objLocalGroup in $colLocalGroups) {
	$return = Add-ADObjectToGroup -strDomain $strDomain -strObjectName $strAccountName -strLocalGroupName $objLocalGroup
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

######################## Set Registry permissions ######################

$colInstances = Get-WmiObject -Namespace ROOT\Microsoft\SqlServer\ComputerManagement11 -Class SqlServiceAdvancedProperty | ? {($_.PropertyName -eq "INSTANCEID") -and ($_.PropertyIndex -eq 12)}
If (!$colInstances) {
	$colInstances = Get-WmiObject -Namespace ROOT\Microsoft\SqlServer\ComputerManagement12 -Class SqlServiceAdvancedProperty | ? {($_.PropertyName -eq "INSTANCEID") -and ($_.PropertyIndex -eq 12)}
	If (!$colInstances) {
		$colInstances = Get-WmiObject -Namespace ROOT\Microsoft\SqlServer\ComputerManagement13 -Class SqlServiceAdvancedProperty | ? {($_.PropertyName -eq "INSTANCEID") -and ($_.PropertyIndex -eq 12)}
		If (!$colInstances) {
			End-Script -blnWithError $true
		} Else {
			$colRegKeys = @("HKLM:\Software\Microsoft\Microsoft SQL Server")
			foreach ($objInstance in $colInstances) {
				$colRegKeys += ("HKLM:\Software\Microsoft\Microsoft SQL Server\" + $objInstance.PropertyStrValue + "\MSSQLServer\Parameters")
			}
		}
	} Else {
		$colRegKeys = @("HKLM:\Software\Microsoft\Microsoft SQL Server")
		foreach ($objInstance in $colInstances) {
			$colRegKeys += ("HKLM:\Software\Microsoft\Microsoft SQL Server\" + $objInstance.PropertyStrValue + "\MSSQLServer\Parameters")
		}
	}
} Else {
	$colRegKeys = @("HKLM:\Software\Microsoft\Microsoft SQL Server")
	foreach ($objInstance in $colInstances) {
		$colRegKeys += ("HKLM:\Software\Microsoft\Microsoft SQL Server\" + $objInstance.PropertyStrValue + "\MSSQLServer\Parameters")
	}
}

$strRegPermissions = "QueryValues,EnumerateSubKeys,Notify,ReadPermissions"
$strRegInheritance = "ObjectInherit,ContainerInherit"

Foreach ($objRegKey in $colRegKeys) {
	$return = Add-ACLPermission -strPath $objRegKey -strUserName ($strDomain + "\" + $strAccountName) -strPermissions $strRegPermissions -strInheritance $strRegInheritance
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

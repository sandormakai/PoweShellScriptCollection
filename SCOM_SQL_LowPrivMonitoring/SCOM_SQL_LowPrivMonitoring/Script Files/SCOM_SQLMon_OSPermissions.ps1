#
# Script.ps1
#
###################### INIT #############################################################

$strEventLogName = "Operations Manager"
$strEventLogSource = "Health Service Script"
$intErrorEventId = 5002
$intWarningEventId = 5001
$intInformationEventid = 5000
$strScriptName = ($MyInvocation.MyCommand.Name).Substring(0,($MyInvocation.MyCommand.Name).Length-4)
$strServiceAccount = "COBHAM\SVC-OMSQLAA-001"
$strDomain = ($strServiceAccount.Split("\"))[0]
$strAccountName = ($strServiceAccount.Split("\"))[1]
$colLocalGroups = @("Performance Monitor Users","Event Log Readers","Users")
$colPermissionList = @("MethodExecute","Enable","RemoteAccess","ReadSecurity")
$strAddingRegistryPermission = "N/A"
$strAddingUserToGroups = "N/A"
$strAddingFolderPermission = "N/A"
$strAddingWMIPermission = "N/A"

####################### Function to finish the script #################

function End-Script($blnWithError) {
    $Comment = ("Results:`r`nAdding user to groups: " + $strAddingUserToGroups + "`r`nAdding registry permission: " + $strAddingRegistryPermission + "`r`nAdding folder permission: " + $strAddingFolderPermission + "`r`nAdding WMI permissions: " + $strAddingWMIPermission)
	If ($blnWithError -eq $True) {
        Write-EventLog -LogName $strEventLogName -Source $strEventLogSource -EntryType Warning -Category 0 -EventId $intWarningEventId -Message ($strScriptName + ": The script ended with errors! `r`nCheck log for related error messages...`r`n" + $Comment)
		Exit (-10)
	} Else {
        Write-EventLog -LogName $strEventLogName -Source $strEventLogSource -EntryType Information -Category 0 -EventId $intInformationEventId -Message ($strScriptName + ": The script has finished successfully`r`n" + $Comment)
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
            Write-EventLog -LogName $strEventLogName -Source $strEventLogSource -EntryType Warning -Category 0 -EventId $intWarningEventId -Message ($strScriptName + "Adding user to group called `"" + $strLocalGroupName + "`"`r`nException: " + $Comment)
			return 0
		} Else {
            Write-EventLog -LogName $strEventLogName -Source $strEventLogSource -EntryType Error -Category 0 -EventId $intErrorEventId -Message ($strScriptName + "Adding user to group called `"" + $strLocalGroupName + "`"`r`nException: " + $Comment)
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
            $Comment = "The object `"" + $strPath + "`" does not exist or the user does not have permission to read it."
            Write-EventLog -LogName $strEventLogName -Source $strEventLogSource -EntryType Error -Category 0 -EventId $intErrorEventId -Message ($strScriptName + "Add specified Filesystem/registry permission...`r`nException: " + $Comment)
			Return -1
		}
		If (($objCurrentAcl.GetType()).Name -eq "RegistrySecurity") {
			$objRuleToAdd = New-Object System.Security.AccessControl.RegistryAccessRule ($strUserName,$strPermissions,$strInheritance,"None","Allow")
		} ElseIf (($objCurrentAcl.GetType()).Name -eq "DirectorySecurity") {
			$objRuleToAdd = New-Object System.Security.AccessControl.FileSystemAccessRule ($strUserName,$strPermissions,$strInheritance,"None","Allow")
		} Else {
            $Comment = "Unknown path type for `"" + $strPath + "`""
            Write-EventLog -LogName $strEventLogName -Source $strEventLogSource -EntryType Error -Category 0 -EventId $intErrorEventId -Message ($strScriptName + "Add specified Filesystem/registry permission...`r`nException: " + $Comment)
			Return -1
		}
		$objCurrentAcl.AddAccessRule($objRuleToAdd)
		Set-Acl -Path $strPath -AclObject $objCurrentAcl -ErrorAction Stop
	} Catch {
        $Comment = $_.Exception
        Write-EventLog -LogName $strEventLogName -Source $strEventLogSource -EntryType Error -Category 0 -EventId $intErrorEventId -Message ($strScriptName + "Add specified Filesystem/registry permission...`r`nException: " + $Comment)
        Return -1
    }
    Return 0
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
            $Comment = "Unknown permission: $strPermission`nValid permissions: $($permissionTable.Keys)"
            Write-EventLog -LogName $strEventLogName -Source $strEventLogSource -EntryType Error -Category 0 -EventId $intErrorEventId -Message ($strScriptName + "Modify WMI Namespace Security...`r`nException: " + $Comment)
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
        $Comment = "GetSecurityDescriptor failed: $($output.ReturnValue)"
        Write-EventLog -LogName $strEventLogName -Source $strEventLogSource -EntryType Error -Category 0 -EventId $intErrorEventId -Message ($strScriptName + "Modify WMI Namespace Security...`r`nException: " + $Comment)
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
        $Comment = "Account was not found: $strAccount"
		Write-EventLog -LogName $strEventLogName -Source $strEventLogSource -EntryType Error -Category 0 -EventId $intErrorEventId -Message ($strScriptName + "Modify WMI Namespace Security...`r`nException: " + $Comment)
		Return -1
	}
	
	switch ($strOperation) {
		"add" {
			if ($strPermissionList -eq $null) {
                $Comment = "No permission was specified for `"ADD`" function"
                Write-EventLog -LogName $strEventLogName -Source $strEventLogSource -EntryType Error -Category 0 -EventId $intErrorEventId -Message ($strScriptName + "Modify WMI Namespace Security...`r`nException: " + $Comment)
				return -1
			}
			$accessMask = Get-AccessMaskFromPermission($strPermissionList)
			If ($accessMask -eq -1) {
				return -1
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
                $Comment = "Permissions cannot be specified for a `"DELETE`" operation"
				Write-EventLog -LogName $strEventLogName -Source $strEventLogSource -EntryType Error -Category 0 -EventId $intErrorEventId -Message ($strScriptName + "Modify WMI Namespace Security...`r`nException: " + $Comment)
				return -1
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
            $Comment = "Unknown operation: $strOperation`nAllowed operations: add delete"
            Write-EventLog -LogName $strEventLogName -Source $strEventLogSource -EntryType Error -Category 0 -EventId $intErrorEventId -Message ($strScriptName + "Modify WMI Namespace Security...`r`nException: " + $Comment)
			return -1
		}
	}
	
	$setparams = @{Name="SetSecurityDescriptor";ArgumentList=$acl.psobject.immediateBaseObject} + $invokeParams
	
	$output = Invoke-WmiMethod @setparams
	if ($output.ReturnValue -ne 0) {
        $Comment = "SetSecurityDescriptor failed: $($output.ReturnValue)"
        Write-EventLog -LogName $strEventLogName -Source $strEventLogSource -EntryType Error -Category 0 -EventId $intErrorEventId -Message ($strScriptName + "Modify WMI Namespace Security...`r`nException: " + $Comment)
		return -1
	}
}

####################### Starting the script ##########################################

Write-EventLog -LogName $strEventLogName -Source $strEventLogSource -EntryType Information -Category 0 -EventId $intInformationEventId -Message ($strScriptName + ": Started...")

######################## Check whether it is a cluster member ########################

$objCluster = Get-WmiObject -Namespace "Root\MSCluster" -Class "MSCluster_Cluster"
If (!$objCluster) {
    $blnIsCluster = $False
} Else {
    $blnIsCluster = $True
}

If ($blnIsCluster) {
    Import-Module FailoverClusters
}

######################## Set Registry permissions ######################

[string]$strInstanceVersion = ""

$colInstances = Get-WmiObject -Namespace ROOT\Microsoft\SqlServer\ComputerManagement11 -Class SqlServiceAdvancedProperty -ErrorAction SilentlyContinue | ? {($_.PropertyName -eq "INSTANCEID") -and ($_.PropertyIndex -eq 12)}
If (!$colInstances) {
	$colInstances = Get-WmiObject -Namespace ROOT\Microsoft\SqlServer\ComputerManagement12 -Class SqlServiceAdvancedProperty -ErrorAction SilentlyContinue | ? {($_.PropertyName -eq "INSTANCEID") -and ($_.PropertyIndex -eq 12)}
	If (!$colInstances) {
		$colInstances = Get-WmiObject -Namespace ROOT\Microsoft\SqlServer\ComputerManagement13 -Class SqlServiceAdvancedProperty -ErrorAction SilentlyContinue | ? {($_.PropertyName -eq "INSTANCEID") -and ($_.PropertyIndex -eq 12)}
		If (!$colInstances) {
            $Comment = "No SQL server installation could be found on this server"
            Write-EventLog -LogName $strEventLogName -Source $strEventLogSource -EntryType Error -Category 0 -EventId $intErrorEventId -Message ($strScriptName + "Set registry permission...`r`nException: " + $Comment)
			End-Script -blnWithError $true
		} Else {
			$strInstanceVersion = "2016"
			$colRegKeys = @("HKLM:\Software\Microsoft\Microsoft SQL Server")
			foreach ($objInstance in $colInstances) {
				$colRegKeys += ("HKLM:\Software\Microsoft\Microsoft SQL Server\" + $objInstance.PropertyStrValue + "\MSSQLServer\Parameters")
			}
		}
	} Else {
		$strInstanceVersion = "2014"
		$colRegKeys = @("HKLM:\Software\Microsoft\Microsoft SQL Server")
		foreach ($objInstance in $colInstances) {
			$colRegKeys += ("HKLM:\Software\Microsoft\Microsoft SQL Server\" + $objInstance.PropertyStrValue + "\MSSQLServer\Parameters")
		}
	}
} Else {
	$strInstanceVersion = "2012"
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
		$strAddingRegistryPermission = "ERROR"
	} Else {
		$strAddingRegistryPermission = "OK"
	}
}

######################## Adding users to local groups ##################

foreach ($objLocalGroup in $colLocalGroups) {
	$return = Add-ADObjectToGroup -strDomain $strDomain -strObjectName $strAccountName -strLocalGroupName $objLocalGroup
	If ($return -eq -1) {
		$strAddingUserToGroups = "ERROR"
	} Else {
		$strAddingUserToGroups = "OK"
	}
}

######################## Set permission to Windows Temp folder #########

$strFolder = "C:\Windows\Temp"
$strFolderPermission = "Modify"

$return = Add-ACLPermission -strPath $strFolder -strUserName ($strDomain + "\" + $strAccountName) -strPermissions $strFolderPermission -strInheritance $strRegInheritance
If ($return -eq -1) {
	$strAddingFolderPermission = "ERROR"
} Else {
	$strAddingFolderPermission = "OK"
}

######################## Set Cluster permission ########################

If ($blnIsCluster){
    Grant-ClusterAccess -User $strServiceAccount -Full
}


######################## Set WMI namespace permissions #################

If ($strInstanceVersion -eq "2012") {
	$colWMINameSpaces = @("root","root\cimv2","root\default","root\Microsoft\SqlServer\ComputerManagement11")
} ElseIf ($strInstanceVersion -eq "2014") {
	$colWMINameSpaces = @("root","root\cimv2","root\default","root\Microsoft\SqlServer\ComputerManagement12")
} ElseIf ($strInstanceVersion -eq "2016") {
	$colWMINameSpaces = @("root","root\cimv2","root\default","root\Microsoft\SqlServer\ComputerManagement13")
}

If ($blnIsCluster) {
    $colWMINameSpaces += "root\MSCluster"
}

foreach ($objWMINameSpace in $colWMINameSpaces) {
	$return = Set-WmiNamespaceSecurity -strNameSpace $objWMINameSpace -strOperation "add" -strAccount ($strDomain + "\" + $strAccountName) -strPermissionList $colPermissionList
	If ($return -eq -1) {
    	$strAddingWMIPermission = "ERROR"
    } Else {
	    $strAddingWMIPermission = "OK"
	}
}

############## Check whether the script finished successfully or not ################

If (($strAddingRegistryPermission -eq "ERROR") -or ($strAddingWMIPermission -eq "ERROR") -or ($strAddingFolderPermission -eq "ERROR") -or ($strAddingUserToGroups -eq "ERROR")) {
    End-Script -blnWithError $True
}

######################## Script finished successfully ###############################

End-Script -blnWithError $False

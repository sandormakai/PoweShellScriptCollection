#
# Script.ps1
#
###################### INIT #############################################################
[CmdletBinding()]
Param(
	[Parameter(Mandatory=$True,ParameterSetName=’Single’)]
	[ValidateNotNullOrEmpty()]
	[Alias("Single")]
	[switch]$blnSingle,
	[Parameter(Mandatory=$True,ParameterSetName=’Multiple’)]
	[ValidateNotNullOrEmpty()]
	[Alias("Multiple")]
	[switch]$blnMultiple,
	[Parameter(Mandatory=$True,ParameterSetName=’Single’)]
	[ValidateNotNullOrEmpty()]
	[Alias("ServerName")]
	[string]$strServerName,
	[Parameter(Mandatory=$True,ParameterSetName=’Multiple’)]
	[ValidateScript({Test-Path $_ -PathType ‘Leaf’})]
	[Alias("ServerList")]
	[string]$strServerList,
	[Parameter(Mandatory=$False)]
	[ValidateNotNullOrEmpty()]
	[Alias("InstallAccount")]
	[string]$strInstallAccount = $NULL,
	[Parameter(Mandatory=$False)]
	[ValidateNotNullOrEmpty()]
	[Alias("AgentActionAccount")]
	[string]$strAgentActionAccount = $NULL,
	[Parameter(Mandatory=$False)]
	[ValidateNotNullOrEmpty()]
	[Alias("DNSServers")]
	[string]$colDNSServers = $NULL,
	[Parameter(Mandatory=$True)]
	[ValidateNotNullOrEmpty()]
	[Alias("PrimaryMgtSrv")]
	[string]$strPrimaryMgtSrv,
	[Parameter(Mandatory=$False)]
	[ValidateNotNullOrEmpty()]
	[Alias("ScriptVerbose")]
	[switch]$blnScriptVerbose

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
#		Write-Host "Press any key to continue..."
#		$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
		Exit (-10)
	} Else {
		LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData "The script $strScriptName finished successfully"
#		Write-Host "Press any key to continue..."
#		$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
		Exit (0)
	}
}

####################### Function to get admin credential ###########################
function Get-RunAsCredential($strUserName)
{
	$Error.Clear()
	$objError = $null
	Try {
		If ($strUserName -eq "") {
			$objCredential = Get-Credential -Message "RunAs user with Administrative rights"
		} Else {
			$objCredential = Get-Credential -UserName $strUserName -Message "RunAs user with Administrative rights"
		}
	} Catch {
		$objError = $Error[0]
		LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("An error occured when the script tried to store the credential")
		LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("Exception: " + $objError.Exception)
		Return -1
	}
	LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData "The inserted credential is successfully stored."
	LogToFile -intLogType $constDATA -strFile $strLogFile -strLogData ("Username: " + $objCredential.UserName + "`r`nPassword string: " + ($objCredential.Password | ConvertFrom-SecureString))
	Return $objCredential
}

################### Funciton to build serverlist from file #########################################
function New-ServerList($strFilePath,$colResolutionServers)
{
	$colServers = Get-Content -Path $strFilePath
	If (!$colServers) {
		LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("An error occured when the script tried to load the list of server from file: `"" + $strServerList + "`"")
		Return (-1)
	}
	Foreach ($objServer in $colServers) {
        If ($objServer -eq "") {
            Continue
        }
		If ($colResolutionServers) {
			Try {
				$something = Resolve-DnsName -DnsOnly -Name $objServer -Server $colResolutionServers -ErrorAction Stop
			} Catch {
				LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("The DNS resolution for server `"" + $objServer + "`" did not produce a result. This server will not be included in the installation list")
                Continue
			}
		} Else {
			Try {
				$something = Resolve-DnsName -DnsOnly -Name $objServer -ErrorAction Stop
			} Catch {
				LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("The DNS resolution for server `"" + $objServer + "`" did not produce a result. This server will not be included in the installation list")
                Continue
			}
		}
		[String[]]$colReturnList += $objServer
	}
	Return $colReturnList
}

###################### Initialization ###############################################
LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData ("The script `"" + $strScriptName + "`" has been started...")
LogToFile -intLogType $constDATA -strFile $strLogFile -strLogData ("Starting Parameters:
	Single Server Installation: " + $blnSingle + "
	Multi Server Installation: " + $blnMultiple + "
	ServerName (for Single installation): " + $strServerName + "
	Path for serverlist file (for Multiple installation): " + $strServerList + "
	Agent Install Account: " + $strInstallAccount + "
	Agent Action Account: " + $strAgentActionAccount + "
	List of DNS Servers: " + $colDNSServers + "
	Primary Management Server: " + $strPrimaryMgtSrv)

If ($blnScriptVerbose) {
	Write-Host -ForegroundColor Yellow "##################################################################"
	Write-Host -ForegroundColor Yellow ("          Starting script " + $strScriptName)
	Write-Host -ForegroundColor Yellow "##################################################################"
	Write-Host -ForegroundColor Yellow "Starting Parameters:"
	Write-Host -ForegroundColor Yellow -NoNewline "Single Server Installation: "
	Write-Host -ForegroundColor Magenta $blnSingle
	Write-Host -ForegroundColor Yellow -NoNewline "Multi Server Installation: "
	Write-Host -ForegroundColor Magenta $blnMultiple
	Write-Host -ForegroundColor Yellow -NoNewline "ServerName (for Single installation): "
	Write-Host -ForegroundColor Magenta $strServerName
	Write-Host -ForegroundColor Yellow -NoNewline "Path for serverlist file (for Multiple installation): "
	Write-Host -ForegroundColor Magenta $strServerList
	Write-Host -ForegroundColor Yellow -NoNewline "Agent Install Account: "
	Write-Host -ForegroundColor Magenta $strInstallAccount
	Write-Host -ForegroundColor Yellow -NoNewline "Agent Action Account: "
	Write-Host -ForegroundColor Magenta $strAgentActionAccount
	Write-Host -ForegroundColor Yellow -NoNewline "List of DNS Servers: "
	Write-Host -ForegroundColor Magenta $colDNSServers
	Write-Host -ForegroundColor Yellow -NoNewline "Primary Management Server: "
	Write-Host -ForegroundColor Magenta $strPrimaryMgtSrv
}

################### Check whether the script was started in SCOM shell or not ######################
If ($blnScriptVerbose) {
	Write-Host -ForegroundColor Yellow -NoNewline "`r`nInitializing Operations Manager Shell..."
}
If(-not (Get-Module | ? {$_.Name -eq "OperationsManager"})) {
	if(Get-Module -ListAvailable | ? {$_.Name -eq "OperationsManager"}) {
		Import-Module OperationsManager
		Write-Host -ForegroundColor Green "DONE!"
	} Else {
		LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData "The PS Module named OperationsManager is not available on this machine. Please run the script again on a server where this module is available."
		If ($blnScriptVerbose) {
			Write-Host -ForegroundColor Red "FAIL!"
		}
		End-Script -blnWithError $True
	}
} Else {
	If ($blnScriptVerbose) {
		Write-Host -ForegroundColor Green "DONE!"
	}
}

#################### Get SCOM Management Server #####################
If ($blnScriptVerbose) {
	Write-Host -ForegroundColor Yellow -NoNewline "Load Management Server Object into variable..."
}
Try {
	$objPrimaryMgtSrv = Get-SCOMManagementServer | ? { $_.Name -eq $strPrimaryMgtSrv }
	If ($blnScriptVerbose) {
		Write-Host -ForegroundColor Green "DONE!"
	}
} Catch {
	LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData "The Name of the Management Server is incorrect. Please fix and run the script again!"
	If ($blnScriptVerbose) {
		Write-Host -ForegroundColor Red "FAIL!"
	}
	End-Script -blnWithError $True
}

##################### Get Install and Action Accounts ################
If ($blnScriptVerbose) {
	Write-Host -ForegroundColor Yellow -NoNewline "Load Agent Installation Account into variable..."
}
If ($strInstallAccount) {
	$credInstallAccount = Get-RunAsCredential -strUserName $strInstallAccount
	If ($credInstallAccount -eq -1) {
		LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("An error occured when the script tried to store credential information for user `"" + $strInstallAccount + "`"")
		If ($blnScriptVerbose) {
			Write-Host -ForegroundColor Red "FAIL!"
		}
		End-Script -blnWithError $True
	}
} Else {
	$credInstallAccount = $NULL
}
If ($blnScriptVerbose) {
	Write-Host -ForegroundColor Green "DONE!"
}

If ($blnScriptVerbose) {
	Write-Host -ForegroundColor Yellow -NoNewline "Load Agent Action Account into variable..."
}
If ($strAgentActionAccount) {
	$credAgentActionAccount = Get-RunAsCredential -strUserName $strAgentActionAccount
	If ($credAgentActionAccount -eq -1) {
		LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("An error occured when the script tried to store credential information for user `"" + $strAgentActionAccount + "`"")
		If ($blnScriptVerbose) {
			Write-Host -ForegroundColor Red "FAIL!"
		}
		End-Script -blnWithError $True
	}
} Else {
	$credAgentActionAccount = $NULL
}
If ($blnScriptVerbose) {
	Write-Host -ForegroundColor Green "DONE!"
}

######################## Build serverlist ##############################
If ($blnSingle) {
	If ($blnScriptVerbose) {
		Write-Host -ForegroundColor Yellow -NoNewline "Single Agent installation. Filling up variable..."
	}
	$objServers = $strServerName
} ElseIf ($blnMultiple) {
	If ($blnScriptVerbose) {
		Write-Host -ForegroundColor Yellow -NoNewline "Multiple Agent installation. Building up serverlist..."
	}
	If (!$colDNSServers) {
		$objServers = New-ServerList -strFilePath  $strServerList -colResolutionServers $colDNSServers
	} Else {
		$objServers = New-ServerList -strFilePath  $strServerList
	}
} Else {
	LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("An error occured when the script tried to check whether the running mode is Single or Multiple")
	If ($blnScriptVerbose) {
		Write-Host -ForegroundColor Red "FAIL!"
	}
	End-Script -blnWithError $True
}
If ($blnScriptVerbose) {
	Write-Host -ForegroundColor Green "DONE!"
}

######################## Push SCOM Agents ##############################
If ($blnScriptVerbose) {
	Write-Host -ForegroundColor Yellow -NoNewline "Pushing out agents..."
}
If ((!$credInstallAccount) -and (!$credAgentActionAccount)) {
	$objResult = Install-SCOMAgent -DNSHostName $objServers -PrimaryManagementServer $objPrimaryMgtSrv
} ElseIf (($credInstallAccount) -and (!$credAgentActionAccount)) {
	$objResult = Install-SCOMAgent -DNSHostName $objServers -PrimaryManagementServer $objPrimaryMgtSrv -ActionAccount $credInstallAccount
} ElseIf (($credInstallAccount) -and ($credAgentActionAccount)) {
	$objResult = Install-SCOMAgent -DNSHostName $objServers -PrimaryManagementServer $objPrimaryMgtSrv -ActionAccount $credInstallAccount -AgentActionAccount $credAgentActionAccount	
} ElseIf ((!$credInstallAccount) -and ($credAgentActionAccount)) {
	$objResult = Install-SCOMAgent -DNSHostName $objServers -PrimaryManagementServer $objPrimaryMgtSrv -AgentActionAccount $credAgentActionAccount
} Else {
	LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData "Not enough information to push the agents"
	If ($blnScriptVerbose) {
		Write-Host -ForegroundColor Red "FAIL!"
	}
	End-Script -blnWithError $True
}
If ($blnScriptVerbose) {
	Write-Host -ForegroundColor Green "DONE!"
}

######################## Script finished ###############################
Write-Host -ForegroundColor Yellow "`r`n##################################################################"
Write-Host -ForegroundColor Yellow ("          Finishing script " + $strScriptName)
Write-Host -ForegroundColor Yellow "##################################################################"
End-Script -blnWithError $False
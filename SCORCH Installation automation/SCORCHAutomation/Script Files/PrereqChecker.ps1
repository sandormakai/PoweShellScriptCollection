

###################### INIT #############################################################
Param(
	[Parameter(Mandatory=$True,ParameterSetName=’Install’)]
	[ValidateNotNullOrEmpty()]
	[switch]$Install,
	[Parameter(Mandatory=$True,ParameterSetName=’Check’)]
	[ValidateNotNullOrEmpty()]
	[switch]$Check,
	[Parameter(Mandatory=$True,ParameterSetName=’Install’)]
	[Parameter(ParameterSetName=’Check’)]
	[ValidateScript({Test-Path $_ -PathType 'Container'})]
	[Alias("ConfigPath")]
	[string]$strXMLFilesPath
 )

$ErrorActionPreference = 'silentlycontinue'
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
.((Get-ScriptDirectory) + "\Functions.ps1")

If (-not($strScriptPath = Get-ScriptDirectory)) {
	Write-Host "The script cannot determinde its working directory. Without this parameter the script cannot run. Please check and run the script again!"
	Exit -2
}
$strScriptName = ($MyInvocation.MyCommand.Name).Substring(0,($MyInvocation.MyCommand.Name).Length-4)
$strLogFile = ($strScriptPath + "\" + $strScriptName + ".log")
$strResultLogFile = ($strScriptPath + "\" + $strScriptName + "_Result.log")

####################### Starting the script ##########################################

LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData "Logging started for $strScriptName with the following parameters:`r`nInstall: $Install`r`nCheck: $Check`r`nConfiguration Files: $strXmlFilesPath"
Write-Host -ForegroundColor Yellow "##################################################################"
Write-Host -ForegroundColor Yellow ("          Starting script " + $strScriptName)
Write-Host -ForegroundColor Yellow "##################################################################"

####################### Checking the configuration files #############################

Write-Host -ForegroundColor Yellow -NoNewline "`r`nChecking for configuration files..."
$colXMLFiles = Get-ChildItem -Path "$strXmlFilesPath*" -Include *.xml

If ($colXMLFiles.Count -lt 2) {
	LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData "At least one of the mandatory configuration files is missing! Please correct the error and run the script again."
	LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData "The script $strScriptName finished with error. Please check log file"
	Write-Host -ForegroundColor Red "FAIL"
	Write-Host "Press any key to continue..."
	$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
	Exit (-3)
}
Write-Host -ForegroundColor Green "PASS"

[xml]$xmlTemp = $null
[xml]$xmlInfra = $null
[xml]$xmlPrereq = $null
[bool]$blnCheckError = $false
[bool]$blnSingleServerInstall = $false
[bool]$blnMultiServerInstall = $false

###################### Loading XMLs from the specified directory #####################

Write-Host -ForegroundColor Yellow "`r`nLoading configuration from XML files"
foreach ($objXMLFile in $colXMLFiles) {
	$xmlTemp = Get-Content $objXMLFile.FullName
	If ($xmlTemp.configuration.Type -eq "Infrastructure") {
		Write-Host -ForegroundColor Yellow ("Loading `"Infrastructure`" configuration data from " + $objXMLFile.FullName)
		LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData ("Loading " + $objXMLFile.BaseName + $objXMLFile.Extension + " file into variable")
		$xmlInfra = $xmlTemp
	} ElseIf ($xmlTemp.configuration.Type -eq "Prerequisite") {
		Write-Host -ForegroundColor Yellow ("Loading `"Prerequisite`" configuration data from " + $objXMLFile.FullName)
		LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData ("Loading " + $objXMLFile.BaseName + $objXMLFile.Extension + " file into variable")
		$xmlPrereq = $xmlTemp
	}
	$xmlTemp = $null
}

###################### Check if all the required configuration data is available ####################
Write-Host -ForegroundColor Yellow -NoNewline ("`r`nChecking if all the configuration data is available...")
If ($xmlPrereq -eq $NULL) {
	LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData "The configuration file contains information about the Prerequisites is missing."
	LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData "The script $strScriptName finished with error. Please check log file"
	Write-Host -ForegroundColor Red "FAIL"
	Write-Host "Press any key to continue..."
	$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
	Exit (-4)
} ElseIf ($xmlInfra -eq $NULL) {
	LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData "The configuration file contains information about the Infrastructure is missing."
	LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData "The script $strScriptName finished with error. Please check log file"
	Write-Host -ForegroundColor Red "FAIL"
	Write-Host "Press any key to continue..."
	$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
	Exit (-4)
}
Write-Host -ForegroundColor Green "PASS"

LogToFile -intLogType $constINFO -strFile $strResultLogFile -strLogData "Prerequisiste check result:"

Write-Host -ForegroundColor Yellow -NoNewLine "Checking if it is a single or multi server deployment..."
LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData "Checking if it is single or multi server deployment..."
If ($xmlInfra.configuration.SingleServerInstall.Used -eq "True") {
	$blnSingleServerInstall = $True
	Write-Host -ForegroundColor Green "SINGLE"
	LogToFile -intLogType $constDATA -strFile $strResultLogFile -strLogData "Single server deployment"
	$colSingleHardwareRequirements = Get-ServerHardwareCollection -Single -xmlServers $xmlInfra -xmlSettings $xmlPrereq
	LogToFile -intLogType $constDATA -strFile $strResultLogFile -strLogData $colSingleHardwareRequirements
	$colSingleSupportedOS = Get-RoleSupportedOSCollection -Single -xmlServers $xmlInfra -xmlSettings $xmlPrereq
	LogToFile -intLogType $constDATA -strFile $strResultLogFile -strLogData $colSingleSupportedOS
} Elseif ($xmlInfra.configuration.MultiServerInstall.Used -eq "True") {
	$blnMultiServerInstall = $true
	Write-Host -ForegroundColor Green "MULTI"
	LogToFile -intLogType $constDATA -strFile $strResultLogFile -strLogData "Multi server deployment"
	$colTemp = Get-ServerHardwareCollection -Multi -xmlServers $xmlInfra -xmlSettings $xmlPrereq
	LogToFile -intLogType $constDATA -strFile $strResultLogFile -strLogData $colTemp
} Else {
	LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData "Both Single and Multi server deployment marked as `"FALSE`". At lease one needs to be set to `"TRUE`"..."
	Write-Host -ForegroundColor Red "ERROR"
	LogToFile -intLogType $constDATA -strFile $strResultLogFile -strLogData "Incorrect configuration in XML"
	Write-Host "Press any key to continue..."
	$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
	Exit (-6)
}

[System.Management.Automation.Credential()]$credRunAsUser = [System.Management.Automation.PSCredential]::Empty
LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData "Storing credential for RunAsAdmin account..."
$credRunAsUser = Get-RunAsCredential
If ($credRunAsUser -eq -1) {
	LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("Credential not stored. See log for related errors. Fix the issue and run the script again.")
	LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("The script " + $strScriptName + "finished unsuccessfully")
	Exit (-5)
}


#$strComputerName = "DEMO-OM01"

#$objPSSession = New-RemotePSConnection -strComputerName $strComputerName -credCredential $credRunAsUser
#If ($objPSSession -eq -1) {
#	LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData ("Cannot perform the operation for computer " + $strComputerName + ". Please fix the error and run the script again.")
#	$blnCheckError = $True
#}
#LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData ("ID: " + $objPSSession.Id)

#Remove-PSSession $objPSSession

######################## Script finished ###############################
If ($blnCheckError -eq $True) {
	LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData "The script $strScriptName finished with errors. Please check the log for related entries. Fix the errors and run the script again."
	Write-Host "Press any key to continue..."
	$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
	Exit (-10)
} Else {
	LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData "The script $strScriptName finished successfully"
	Write-Host "Press any key to continue..."
	$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
	Exit (0)
}


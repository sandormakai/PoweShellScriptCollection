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

####################### Function to load account information for XML #################
function Get-AccountFromXML([xml]$xmlData) {
	$colData = @()
	foreach ($objAccount in $xmlData.configuration.Principals.UserAccounts.UserAccount) {
		If ($objAccount.Used -ne "False") {
			$objData = New-Object –TypeName PSObject
			$objData | Add-Member –MemberType NoteProperty –Name Type –Value $objAccount.Type
			$objData | Add-Member –MemberType NoteProperty –Name UserName –Value $objAccount.UserName
			$objData | Add-Member –MemberType NoteProperty –Name Domain –Value $xmlData.configuration.Principals.UserAccounts.Domain
			$colData += $objData
		}
	}
	return $colData
}

####################### Starting the script ##########################################

LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData ("The script `"" + $strScriptName + "`" has been started...")
Write-Host -ForegroundColor Yellow "##################################################################"
Write-Host -ForegroundColor Yellow ("          Starting script " + $strScriptName)
Write-Host -ForegroundColor Yellow "##################################################################"


###################### Loading XML from the specified directory #####################

Write-Host -ForegroundColor Yellow "`r`nLoading configuration from XML file"
Write-Host -ForegroundColor Yellow -NoNewline "Service Accounts..."
[xml]$xmlConfiguration = Get-Content $strConfigFilePath
$colAccounts = @()
$colAccounts = Get-AccountFromXML -xmlData $xmlConfiguration
$strLogSting = "The following accounts, groups and SQL Instances have been loaded:`r`n"
foreach ($objAccount in $colAccounts) {
	$strLogSting += ("	AccountType: " + $objAccount.Type + "	UserName: " + $objAccount.UserName + "	Domain: " + $objAccount.Domain + "`r`n")
}
Write-Host -ForegroundColor Green "DONE!"

Write-Host -ForegroundColor Yellow -NoNewline "Security Group..."
$objGroup = New-Object –TypeName PSObject
$objGroup | Add-Member –MemberType NoteProperty –Name GroupName –Value $xmlConfiguration.configuration.Principals.Group.GroupName
$objGroup | Add-Member –MemberType NoteProperty –Name Domain –Value $xmlConfiguration.configuration.Principals.Group.Domain

$strLogSting += ("	GroupName: " + $objGroup.GroupName + "	Domain: " + $objGroup.Domain + "`r`n")
Write-Host -ForegroundColor Green "DONE!"

Write-Host -ForegroundColor Yellow -NoNewline "SQL Instances..."
$objInstances = New-Object –TypeName PSObject
$objInstances | Add-Member –MemberType NoteProperty –Name InstanceNames –Value $xmlConfiguration.configuration.Instances.InstanceName
$objInstances | Add-Member –MemberType NoteProperty –Name InstanceVersion –Value $xmlConfiguration.configuration.Instances.Version
$objInstances | Add-Member –MemberType NoteProperty –Name Domain –Value $xmlConfiguration.configuration.Instances.Domain
Write-Host -ForegroundColor Green "DONE!"
$strLogSting += "	Instances: "
foreach ($strInstance in $objInstances.InstanceNames) {
	$strLogSting += ($strInstance + ";")
}

$strLogSting += ("	SQL Version: " + $objInstances.InstanceVersion + "	Domain: " + $objInstances.Domain + "`r`n")
LogToFile -intLogType $constDATA -strFile $strLogFile -strLogData $strLogSting


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

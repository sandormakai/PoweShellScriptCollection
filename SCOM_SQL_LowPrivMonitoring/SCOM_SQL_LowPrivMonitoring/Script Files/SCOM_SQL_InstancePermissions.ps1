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

####################### Starting the script ##########################################

LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData ("The script `"" + $strScriptName + "`" has been started...")
Write-Host -ForegroundColor Yellow "##################################################################"
Write-Host -ForegroundColor Yellow ("          Starting script " + $strScriptName)
Write-Host -ForegroundColor Yellow "##################################################################"




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

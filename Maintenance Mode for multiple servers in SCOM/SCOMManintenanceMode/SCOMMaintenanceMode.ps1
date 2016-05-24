#
# Script.ps1
#
###################### INIT #############################################################
[CmdletBinding()]
Param(
	[Parameter(Mandatory=$True)]
	[Alias("ManagementServer","MgtServer","MS")]
	[ValidateNotNullOrEmpty()]
	[string]$strServerName,
	
	[Parameter(Mandatory=$True)]
	[ValidateScript({Test-Path $_ -PathType ‘Leaf’})]
	[Alias("FilePath","FP")]
	[string]$strFilePath
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

################### Check whether the script was started in SCOM shell or not ######################
if(-not (Get-Module | ? {$_.Name -eq “OperationsManager”})) {
	if(Get-Module -ListAvailable | ? {$_.Name -eq “OperationsManager”}) {
		Import-Module OperationsManager
	}
	Else {
		LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData "The PS Module named OperationsManager is not available on this machine. Please run the script again on a server where this module is available."
		Exit(-1)
	}
}

################### Connect to Management Server ###################################################
If 
New-SCOMManagementGroupConnection -ComputerName $strServerName
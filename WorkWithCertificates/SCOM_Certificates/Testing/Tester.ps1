#
# Tester.ps1
#
$strScriptPath = $NULL
$strScriptName = $NULL

function Get-ScriptDirectory
{
	$Invocation = $NULL
	$Invocation = (Get-Variable MyInvocation -Scope 1).Value
	If ($Invocation -eq $NULL) {
		$strCommand = $ErrorReturn.InvocationInfo.Line
		$strException = $ErrorReturn.Exception
		Write-Host ("Error occured during command: {0} `r`nThe exception of the error is: {1}", $strCommand, $strException)
		Exit -1
	}
	Split-Path $Invocation.MyCommand.Path
}

If (-not($strScriptPath = Get-ScriptDirectory)) {
	Write-Host "The script cannot determinde its working directory. Without this parameter the script cannot run. Please check and run the script again!"
	Exit -2
}

.((Get-ScriptDirectory) + "\..\_Basic\Logging.ps1")

$strScriptName = ($MyInvocation.MyCommand.Name).Substring(0,($MyInvocation.MyCommand.Name).Length-4)
$blnCheckError = $false

######################### Initialization ##################################################################################################################

function Generate-InfFile ([string]$strComputerName,[string]$strTemplateName) {
	$strFileName = ($strScriptPath + "\" + $strComputerName + ".inf")
	If (Get-ChildItem -Path $strFileName -ErrorAction SilentlyContinue) {
		Remove-Item -Path $strFileName
	}
	Add-Content -Path $strFileName -Value "[NewRequest]"
	Add-Content -Path $strFileName -Value ("Subject=`"CN={0}`"" -f $strComputerName)
	Add-Content -Path $strFileName -Value "KeyLength=2048"
	Add-Content -Path $strFileName -Value "KeySpec=1"
	Add-Content -Path $strFileName -Value "KeyUsage=0xf0"
	Add-Content -Path $strFileName -Value "MachineKeySet=TRUE"
	Add-Content -Path $strFileName -Value "[RequestAttributes]"
	Add-Content -Path $strFileName -Value ("CertificateTemplate=`"{0}`"" -f $strTemplateName)
}

Generate-InfFile -strComputerName TestMachine.something.local -strTemplateName "This is a template"
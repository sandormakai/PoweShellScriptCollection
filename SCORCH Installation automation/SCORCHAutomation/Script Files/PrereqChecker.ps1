

###################### INIT #############################################################
Param(
	[Parameter(Mandatory=$True,ParameterSetName=’Install1Server’)]
	[Parameter(ParameterSetName=’InstallMultiServer’)]
	[ValidateNotNullOrEmpty()]
	[switch]$Install,
	[Parameter(Mandatory=$True,ParameterSetName=’Check1Server’)]
	[Parameter(ParameterSetName=’CheckMultiServer’)]
	[ValidateNotNullOrEmpty()]
	[switch]$Check,
	[Parameter(Mandatory=$False,ParameterSetName=’Install1Server’)]
	[Parameter(ParameterSetName=’Check1Server’)]
	[ValidateNotNullOrEmpty()]
	[string]$ComputerName,
	[Parameter(Mandatory=$False,ParameterSetName=’InstallMultiServer’)]
	[Parameter(ParameterSetName=’CheckMultiServer’)]
	[ValidateScript({Test-Path $_ -PathType 'Leaf'})]
	[string]$ComputerList,
	[Parameter(Mandatory=$False,ParameterSetName=’Install1Server’)]
	[Parameter(ParameterSetName=’Check1Server’)]
	[ValidateSet("ManagementServer","RunBookServer","OrchestratorWebServices","RunbookDesigner","OrchestrationConsole")]
	[string]$ServerRole,
	[Parameter(Mandatory=$false)]
	[ValidateScript({Test-Path $_ -PathType 'Container'})]
	[string]$SourcePath = $NULL
 )

$strScriptPath = $NULL
$strScriptName = $NULL
$strLogFile = $NULL
$objPSVolume = $NULL

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

function Test-RegistryKey([string]$strComputerName,[string]$strRegKey, [string]$strRegValue)
{
	If ($strComputerName -eq $null -or $strComputerName -eq "")
	{
	    $strComputerName = "localhost"
	}
	$objRemoteReg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey("LocalMachine", $strComputerName)
	If ($objRemoteReg -eq $null)
	{
		[int]$ReturnValue = -1
		return $ReturnValue
	}
	$objRemoteKey = $objRemoteReg.OpenSubKey($strRegKey)
	If ($objRemoteKey -eq $null)
	{
		[int]$ReturnValue = 1
		return $ReturnValue
	}
	$colRegValues = $objRemoteKey.GetValueNames()
	Foreach ($objRegValue in $colRegValues)
	{
		If ([string]$objRegValue -eq $strRegValue)
		{
			[int]$ReturnValue = 0
			Return $ReturnValue
		}
		Else { [int]$ReturnValue = 2 }
	}
	return $ReturnValue
}

function Check-NETFramework35([string]$strComputerName)
{
	$NetFramework35RegPath = "Software\Microsoft\NET Framework Setup\NDP\v3.5"
	$NetFramework35RegKey = "Install"
	If ($strComputerName -eq $NULL -or $strComputerName -eq "")
	{
		$Result = Test-RegistryKey -strRegKey $NetFramework35RegPath -strRegValue $NetFramework35RegKey
	}
	Else
	{
		$Result = Test-RegistryKey -strComputerName $strComputerName -strRegKey $NetFramework35RegPath -strRegValue $NetFramework35RegKey
	}
	Return $Result
}

function Get-AdminCredential()
{

}

function Mount-ImageFile([string]$strFileName)
{
	Write-Host "something"
}

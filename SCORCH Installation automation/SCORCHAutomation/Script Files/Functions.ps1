#
# Script.ps1
#

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

function New-RemotePSConnection ([string]$strComputerName, [System.Management.Automation.Credential()]$credCredential) {
	LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData ("Opening remote PSSession to " + $strComputerName + "...")
	$Error.Clear()
	$objError = $null
	$objSession = New-PSSession -ComputerName $strComputerName -Credential $credCredential
	$objError = $Error[0]
	If ($objError -ne $null) {
		LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("An error occured when the script tried to open PSSession to computer " + $strComputerName)
		LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("Exception: " + $objError.Exception)
		Return -1
	}
	LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData ("PSSession is open to computer " + $objSession.ComputerName + "with ID: " + $objSession.Id)
	Return $objSession
}

function Get-RegistryValue () {

}

function Test-RegistryKey([string]$strComputerName, [string]$strRegKey, [string]$strRegValue)
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

function Mount-ImageFile([string]$strFileName)
{
	Write-Host "something"
}

#
# Script.ps1
#
###################### INIT #############################################################
[CmdletBinding()]
Param(
	[Parameter(Mandatory=$True)]
	[ValidateNotNullOrEmpty()]
	[Alias("StorageName")]
	[string]$strStorageAccountName,
	[Parameter(Mandatory=$True)]
	[ValidateNotNullOrEmpty()]
	[Alias("StorageKey")]
	[string]$strStorageAccountKey,
	[Parameter(Mandatory=$True)]
	[ValidateNotNullOrEmpty()]
	[Alias("Container")]
	[string]$strContainer,
	[Parameter(Mandatory=$True)]
	[ValidateSet("H","h","D","d","M","m","Y","y")]
	[Alias("CleanupTimeUnit")]
	[char]$chrCleanupTimeUnit,
	[Parameter(Mandatory=$True)]
	[ValidateNotNullOrEmpty()]
	[Alias("CleanupTimeFrame")]
	[int]$intCleanupTimeFrame,
	[Parameter(Mandatory=$False)]
	[ValidateNotNullOrEmpty()]
	[Alias("ScriptVerbose")]
	[switch]$blnVerbose
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
		LogToFile -intLogType $constERROR -strFile $strLogFile `
			-strLogData "The script $strScriptName finished with errors. Please check the log for related entries. Fix the errors and run the script again."
		Write-Host "Press any key to continue..."
		$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
		Exit (-10)
	} Else {
		LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData "The script $strScriptName finished successfully"
		Write-Host "Press any key to continue..."
		$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
		Exit (0)
	}
}

##################### Starting main script ############################
LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData ("Starting script `"" + $strScriptName + "`"...`r`n" + `
	"Calling Parameters:" + `
	"Storage Account Name: " + $strStorageAccountName + "`r`n" +`
	"Storage Account Key: " + $strStorageAccountKey + "`r`n" +`
	"Storage Container: " + $strContainer + "`r`n" +`
	"Cleanup Time Unit: " + $chrCleanupTimeUnit + "`r`n" +`
	"Cleanup Timeframe: " +  $intCleanupTimeFrame )

If ($blnVerbose) {
	Write-Host -ForegroundColor Yellow ("Starting script `"" + $strScriptName + "`"...`r`n" + `
		"Calling Parameters:")
	Write-Host -ForegroundColor Yellow -NoNewline ("Storage Account Name: ")
	Write-Host -ForegroundColor Green $strStorageAccountName
	Write-Host -ForegroundColor Yellow -NoNewline ("Storage Account Key: ")
	Write-Host -ForegroundColor Green $strStorageAccountKey
	Write-Host -ForegroundColor Yellow -NoNewline ("Storage Container: ")
	Write-Host -ForegroundColor Green $strContainer
	Write-Host -ForegroundColor Yellow -NoNewline ("Cleanup Time Unit: ")
	Write-Host -ForegroundColor Green $chrCleanupTimeUnit
	Write-Host -ForegroundColor Yellow -NoNewline ("Cleanup Timeframe: ")
	Write-Host -ForegroundColor Green $intCleanupTimeFrame
}

######################## Determine Time variable ########################
switch($chrCleanupTimeUnit){
	"H" {$dtCleanupTime = [DateTime]::UtcNow.AddHours($intCleanupTimeFrame)}
	"h" {$dtCleanupTime = [DateTime]::UtcNow.AddHours($intCleanupTimeFrame)}
	"D" {$dtCleanupTime = [DateTime]::UtcNow.AddDays($intCleanupTimeFrame)}
	"d" {$dtCleanupTime = [DateTime]::UtcNow.AddDays($intCleanupTimeFrame)}
	"M" {$dtCleanupTime = [DateTime]::UtcNow.AddMonths($intCleanupTimeFrame)}
	"m" {$dtCleanupTime = [DateTime]::UtcNow.AddMonths($intCleanupTimeFrame)}
	"Y" {$dtCleanupTime = [DateTime]::UtcNow.AddYears($intCleanupTimeFrame)}
	"y" {$dtCleanupTime = [DateTime]::UtcNow.AddYears($intCleanupTimeFrame)}
}

LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData ("CleaunUp Time: " + $dtCleanupTime)
If ($blnVerbose) {
	Write-Host -ForegroundColor Yellow -NoNewline "`r`nDetermined CleaunUp Time: "
	Write-Host -ForegroundColor Green $dtCleanupTime
}

######################## Connecting ot Storage ###########################
LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData ("Connecting to Azure Storage...")
If ($blnVerbose) {
	Write-Host -ForegroundColor Yellow -NoNewline ("Connecting to Azure Storage...")
}

$Error.Clear()
$objError = $NULL
Try {
	$objAzStorage = New-AzureStorageContext -StorageAccountName $strStorageAccountName -StorageAccountKey $strStorageAccountKey
} Catch [System.Management.Automation.CommandNotFoundException] {
	LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("The Azure PowerShell Module is not installed on this computer.`
	 Please install the module and run the script again")
	If ($blnVerbose) {
		Write-Host -ForegroundColor Red ("Failed!")
	}
	End-Script -blnWithError $True
} Catch {
	$objError = $Error[0]
	LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("An error occured when the script tried to load the Azure storage context")
	LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("Exception: " + $objError.Exception)
	If ($blnVerbose) {
		Write-Host -ForegroundColor Red ("Failed!")
	}
	End-Script -blnWithError $True
}

LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData ("Connection done")
If ($blnVerbose) {
	Write-Host -ForegroundColor Green ("Done!")
}

####################### Removing old files from Storage ##############################
LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData ("Removing old files...")
If ($blnVerbose) {
	Write-Host -ForegroundColor Yellow -NoNewline ("Removing old files...")
}

$Error.Clear()
$objError = $NULL
Try {
	Get-AzureStorageBlob -Container $strContainer -Context $objAzStorage | `
		Where-Object { $_.LastModified.UtcDateTime -lt $dtCleanupTime -and $_.BlobType -eq "PageBlob" -and $_.Name -like "*.bak"} |`
		Remove-AzureStorageBlob
} Catch {
	$objError = $Error[0]
	LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("An error occured when the script tried delete the old backup files")
	LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("Exception: " + $objError.Exception)
	End-Script -blnWithError $True
}

LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData ("Files Deleted!")
If ($blnVerbose) {
	Write-Host -ForegroundColor Green ("Done!")
}

End-Script -blnWithError $False
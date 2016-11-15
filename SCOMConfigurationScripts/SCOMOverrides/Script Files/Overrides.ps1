#
# Overrides.ps1
#
[CmdletBinding()]
Param(
	[Parameter(Mandatory=$True)]
	[ValidateNotNullOrEmpty()]
	[Alias("ManagementServer")]
	[string]$strManagementServer,
	[Parameter(Mandatory=$True)]
	[ValidateScript({Test-Path $_ -PathType ‘Container’})]
	[Alias("ManagementPackStore")]
	[string]$strManagementPackStore,
	[Parameter(Mandatory=$True)]
	[ValidateScript({Test-Path $_ -PathType ‘Leaf’})]
	[Alias("ItemListFile")]
	[string]$strItemListFile,
	[Parameter(Mandatory=$False)]
	[ValidateNotNullOrEmpty()]
	[Alias("ScriptVerbose")]
	[switch]$blnScritpVerbose
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

#################### Funtion to create ManagementPack file ##########################

<#[xml]$xmlTempFile = "<ManagementPack ContentReadable=`"true`" xmlns:xsd=`"http://www.w3.org/2001/XMLSchema`">
  <Manifest>
    <Identity>
      <ID></ID>
      <Version></Version>
    </Identity>
    <Name></Name>
    <References>
    </References>
  </Manifest>
</ManagementPack>"
#>

###################### Initialization ###############################################
LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData ("The script `"" + $strScriptName + "`" has been started...")
LogToFile -intLogType $constDATA -strFile $strLogFile -strLogData ("Starting Parameters:
	ScritpVerbose: " + $blnScritpVerbose + "
	ManagementServer: " + $strManagementServer + "
	ManagementPackStore: " + $strManagementPackStore + "
	ItemListFile: " + $strItemListFile)

Write-Host -ForegroundColor Yellow "##################################################################"
Write-Host -ForegroundColor Yellow ("          Starting script " + $strScriptName)
Write-Host -ForegroundColor Yellow "##################################################################"
If ($blnScritpVerbose) {
	Write-Host -ForegroundColor Yellow ("Starting Parameters:
	ScritpVerbose: " + $blnScritpVerbose + "
	ManagementServer: " + $strManagementServer + "
	ManagementPackStore: " + $strManagementPackStore + "
	ItemListFile: " + $strItemListFile)

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

$colItemsToOverride = Import-Csv -Path $strItemListFile -Delimiter ";"

$objMonitor = Get-SCOMMonitor -Name ($colItemsToOverride[0].Name)
If (!$objMonitor) {
	$objRule = Get-SCOMRule -Name ($colItemsToOverride[0].Name)                  ### Check whether the item is Rule
	If (!$objRule) {
		LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("Wrong item with name `"" + ($colItemsToOverride[0].Name) + "`"")  ### Write an error to the variable if the item is neither a rule nor a monitor
	} Else {
		$ManagementPackName = ($objRule.ManagementPackName + ".Override")
		$ManagementPackDisplayName = (((Get-SCOMManagementPack -Name ($objRule.ManagementPackName)).DisplayName) + " [Override]")
	}
} Else {
	$ManagementPackName = (($objMonitor.Identifier.Domain[0]) + ".Override")
	$ManagementPackDisplayName = (((Get-SCOMManagementPack -Name ($objMonitor.Identifier.Domain[0])).DisplayName) + " [Override]")
}

Write-Host "Connecting to SCOM Management Group"
$MG = New-Object Microsoft.EnterpriseManagement.ManagementGroup($strManagementServer)

Write-Host "Creating new Microsoft.EnterpriseManagement.Configuration.IO.ManagementPackFileStore object"
$MPStore = New-Object Microsoft.EnterpriseManagement.Configuration.IO.ManagementPackFileStore

Write-Host "Creating new Microsoft.EnterpriseManagement.Configuration.ManagementPack object"
$MP = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPack($ManagementPackName, $ManagementPackName, (New-Object Version(1, 0, 0)), $MPStore)

Write-Host "Importing Management Pack"
$MG.ImportManagementPack($MP)

Write-Host "Getting Management Pack"
$MP = Get-SCOMManagementPack -Name $ManagementPackName

Write-Host "Setting Display Name"
$MP.DisplayName = $ManagementPackDisplayName

Write-Host "Setting Description"
$MP.Description = "Override Management Pack for `"" + $ManagementPackDisplayName + "`""

Write-Host "Saving Changes"
$MP.AcceptChanges()

Foreach ($objItem in $colItemsToOverride) {
	$objMonitor = Get-SCOMMonitor -Name ($objItem.Name)
	If (!$objMonitor) {
		$objRule = Get-SCOMRule -Name ($objItem.Name)                  ### Check whether the item is Rule
		If (!$objRule) {
			LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("Wrong item with name `"" + ($objItem.Name) + "`"")  ### Write an error to the variable if the item is neither a rule nor a monitor
		} Else {
			LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData ("Creating override for rule called `"" + ($objRule.DisplayName) + "`"")
			Write-Host "Creating override for rule called `"" + ($objRule.DisplayName) + "`""
			$objTarget= Get-SCOMClass -Id $objRule.Target.Id
			$strOverrideName = ($objRule.name + ".Override")
			$strOverrideDisplayName = ("Disable rule called `"" + ($objRule.DisplayName) + "`"")
			$objOverride = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackRulePropertyOverride($MP,$strOverrideName)
			$objOverride.Rule = $objRule
			$objOverride.Property = "Enabled"
			$objOverride.Value = "false"
			$objOverride.Context = $objTarget
			$objOverride.DisplayName = $strOverrideDisplayName
		}
	} Else {
		LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData ("Creating override for monitor called `"" + ($objMonitor.DisplayName) + "`"")
		Write-Host "Creating override for monitor called `"" + ($objMonitor.DisplayName) + "`""
		$objTarget= Get-SCOMClass -Id $objMonitor.Target.Id
		$strOverrideName = ($objMonitor.Name + ".Override")
		$strOverrideDisplayName = ("Disable monitor called `"" + ($objMonitor.DisplayName) + "`"")
		$objOverride = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackMonitorPropertyOverride($MP,$strOverrideName)
		$objOverride.Monitor = $objMonitor
		$objOverride.Property = "Enabled"
		$objOverride.Value = "false"
		$objOverride.Context = $objTarget
		$objOverride.DisplayName = $strOverrideDisplayName
	}
}

$MP.Verify()
$MP.AcceptChanges()

End-Script -blnWithError $false

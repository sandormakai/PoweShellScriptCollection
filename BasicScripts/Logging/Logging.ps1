#
# Logging.ps1
#

IF ((Test-Path variable:constEventERROR) -eq 0) {
	Set-Variable -name constEventERROR -value 9999 -option Constant
}
IF ((Test-Path variable:constEventWARNING) -eq 0) {
	Set-Variable -name constEventWARNING -value 9998 -option Constant
}
IF ((Test-Path variable:constEventINF) -eq 0) {
	Set-Variable -name constEventINF -value 9997 -option Constant
}
IF ((Test-Path variable:constDEBUG) -eq 0) {
	Set-Variable -name constDEBUG -value 10 -option Constant
}
IF ((Test-Path variable:constNORMAL) -eq 0) {
	Set-Variable -name constNORMAL -value 0 -option Constant
}

function IsLogExist ($strLogName, $strSource) {
	Try {
		$objLog = Get-EventLog -LogName $strLogName -ErrorAction Stop
	} Catch {
		New-EventLog -LogName $strLogName -Source $strSource
		Write-EventLog -LogName $strLogName -Source $strSource -EntryType Information -EventId constEventINF -Category 0 -Message "The necessary log has been created..."
	}
}

function Write-ERROREvent ($strLogName, $strSource, $strMessage, $intCurrentDebugLevel, $intDebugLevelMessage) {
	If ($intDebugLevelMessage -le $intCurrentDebugLevel) {
		Write-EventLog -LogName $strLogName -Source $strSource -EntryType Error -EventId constEventERROR -Category 0 -Message $strMessage
	} 
}

function Write-WARNINGEvent ($strLogName, $strSource, $strMessage, $intCurrentDebugLevel, $intDebugLevelMessage) {
	If ($intDebugLevelMessage -le $intCurrentDebugLevel) {
		Write-EventLog -LogName $strLogName -Source $strSource -EntryType Warning -EventId constEventWARNING -Category 0 -Message $strMessage
	}
}

function Write-INFEvent ($strLogName, $strSource, $strMessage, $intCurrentDebugLevel, $intDebugLevelMessage) {
	If ($intDebugLevelMessage -le $intCurrentDebugLevel) {
		Write-EventLog -LogName $strLogName -Source $strSource -EntryType Information -EventId constEventINF -Category 0 -Message $strMessage
	}
}
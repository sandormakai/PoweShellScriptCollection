#Logger functions
IF ((Test-Path variable:constERROR) -eq 0) {
	Set-Variable -name constERROR -value 1 -option Constant
	}
IF ((Test-Path variable:constINFO) -eq 0) {
	Set-Variable -name constINFO -value 2 -option Constant
}
IF ((Test-Path variable:constDATA) -eq 0) {
	Set-Variable -name constDATA -value 3 -option Constant
}

function IsFileExist ($strFile)
{
	Return Test-Path -PathType Leaf -Path $strFile
}

function LogToFile ($intLogType, $strFile, $strLogData)
{
	switch ($intLogType)
	{
		1 {
			$strDataToFile = "{0:MM}-{0:dd}-{0:yyyy} - {0:hh}:{0:mm}:{0:ss}" -f (Get-Date)
			$strDataToFile = $strDataToFile + " --- ERROR --- " + $strLogData
			Add-Content -Path $strFile -Value $strDataToFile
		}
		2 {
			$strDataToFile = "{0:MM}-{0:dd}-{0:yyyy} - {0:hh}:{0:mm}:{0:ss}" -f (Get-Date)
			$strDataToFile = $strDataToFile + " --- INFO --- " + $strLogData
			Add-Content -Path $strFile -Value $strDataToFile
		}
		3 {
			Add-Content -Path $strFile -Value $strLogData
		}
		default {
			Return 10
		}
	}
}
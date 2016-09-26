#
# Tester.ps1
#

if(-not (Get-Module | ? {$_.Name -eq "OperationsManager"})) {
	if(Get-Module -ListAvailable | ? {$_.Name -eq "OperationsManager"}) {
		Import-Module OperationsManager
	}
	Else {
		Write-Host "The PS Module named OperationsManager is not available on this machine. Please run the script again on a server where this module is available."
		Exit -1
	}
}

#
# Tester.ps1
#

#$colServers2 = @()
#[xml]$testXML = Get-Content '..\Config Files\configuration.xml'

#$colServers2 = Get-AccountFromXML -xmlData $testXML

#$colServers2

$colLocalGroups = @("Users")
foreach ($objLocalGroup in $colLocalGroups) {
	Write-Host $objLocalGroup
}
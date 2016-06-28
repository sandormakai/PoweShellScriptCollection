#
# Tester.ps1
#

function Get-AccountFromXML([xml]$xmlData) {
	$colData = @()
	foreach ($objAccount in $xmlData.configuration.Principals.UserAccounts.UserAccount) {
		If ($objAccount.Used -ne "False") {
			$objData = New-Object –TypeName PSObject
			$objData | Add-Member –MemberType NoteProperty –Name Type –Value $objAccount.Type
			$objData | Add-Member –MemberType NoteProperty –Name UserName –Value $objAccount.UserName
			$objData | Add-Member –MemberType NoteProperty –Name Domain –Value $xmlData.configuration.Principals.UserAccounts.Domain
			$colData += $objData
		}
	}
	return $colData
}


$colServers2 = @()
[xml]$testXML = Get-Content '..\Config Files\configuration.xml'

$colServers2 = Get-AccountFromXML -xmlData $testXML

$colServers2
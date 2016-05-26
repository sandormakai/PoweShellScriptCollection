#
# Tester.ps1
#
$strXmlFilesPath = "C:\Users\sandor.makai\OneDrive - Inframon 1\Source\Repos\PoweShellScriptCollection\SCORCH Installation automation\SCORCHAutomation\Config Files"
$colXMLFiles = Get-ChildItem -Path $strXmlFilesPath
[xml]$xmlTemp = $null
[xml]$xmlInfra = $null
[xml]$xmlPrereq = $null
foreach ($objXMLFile in $colXMLFiles) {
	$xmlTemp = Get-Content $objXMLFile.FullName
	If ($xmlTemp.configuration.Type -eq "Infrastructure") {
		$xmlInfra = $xmlTemp
	} ElseIf ($xmlTemp.configuration.Type -eq "Prerequisite") {
		$xmlPrereq = $xmlTemp
	}
	$xmlTemp = $null
}

Write-Host "xmlInfra: " $xmlInfra.configuration.Type
Write-Host "xmlPrereq: " $xmlPrereq.configuration.Type

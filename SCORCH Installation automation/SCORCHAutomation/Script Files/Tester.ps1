#
# Tester.ps1
#
$colServers = @()
[xml]$testXML = Get-Content D:\Temp\InfrastructureServers.xml
[xml]$testXML2 = Get-Content D:\Temp\PrerequisiteSettings.xml
foreach ($server in $testXML2.configuration.Software.SingleServerInstall.Servers.Server.OperatingSystem.Version) {
	Write-Host ("ServerName: " + $server.Name)
	$objServer = New-Object –TypeName PSObject
	$objServer | Add-Member –MemberType NoteProperty –Name Name –Value $testXML.configuration.SingleServerInstall.Servers.Server.Name
	$objServer | Add-Member –MemberType NoteProperty –Name IPAddress –Value $testXML.configuration.SingleServerInstall.Servers.Server.IPAddress
	$objServer | Add-Member –MemberType NoteProperty –Name ServerRole –Value $testXML.configuration.SingleServerInstall.Servers.Server.Type
	$objServer | Add-Member –MemberType NoteProperty –Name OSName –Value $server.Name
	$objServer | Add-Member –MemberType NoteProperty –Name VersionNumber –Value $server.VersionNumber
	$objServer | Add-Member –MemberType NoteProperty –Name Editions –Value $server.Edition
	$colServers += $objServer
}

$colServers

#foreach ($server in $testXML2.configuration.hardware.MultiServerInstall.Servers.Server) {
#	foreach ($object in $colServers) {
#		If ($server.Type -eq $object.ServerRole) {
#			$object.CPUSpeed = $server.CPUSpeed
#			$object.CPUCores = $server.CPUCores
#			$object.MinRAMMB = $server.MinRAMMB
#			$object.RecRAMMB = $server.RecRAMMB
#			$object.MinSpaceMB = $server.MinSpaceMB
#			$object.RecSpaceMB = $server.RecSpaceMB
#			$object.InstallationDrive = $server.InstallationDrive
#		}
#	}
#}

#$colServers


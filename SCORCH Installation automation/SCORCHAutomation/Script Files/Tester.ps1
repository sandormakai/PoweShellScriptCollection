#
# Tester.ps1
#




#$colServers2 = @()
[xml]$testXML = Get-Content D:\Temp\InfrastructureServers.xml
[xml]$testXML2 = Get-Content D:\Temp\PrerequisiteSettings.xml

$colServers2 = Get-RoleSupportedDatabaseCollection -Multi -xmlServers $testXML -xmlSettings $testXML2

#foreach ($server in $testXML2.configuration.Software.SingleServerInstall.Servers.Server.AdditionalSoftwares.AdditionalSoftware) {
#	Write-Host ("Registry: " + $server.Registry.Used)
#	Write-Host ("WMI: " + $server.WMI.Used)
#	$objServer = New-Object –TypeName PSObject
#	$objServer | Add-Member –MemberType NoteProperty –Name Name –Value $testXML.configuration.SingleServerInstall.Servers.Server.Name
#	$objServer | Add-Member –MemberType NoteProperty –Name IPAddress –Value $testXML.configuration.SingleServerInstall.Servers.Server.IPAddress
#	$objServer | Add-Member –MemberType NoteProperty –Name ServerRole –Value $testXML.configuration.SingleServerInstall.Servers.Server.Type
#	If ($server.Registry.Used -eq "True" -and $server.WMI.Used -eq "False") {
#		$objServer | Add-Member –MemberType NoteProperty –Name LookupSource –Value "Registry"
#		$objServer | Add-Member –MemberType NoteProperty –Name Root –Value $server.Registry.Root
#		$objServer | Add-Member –MemberType NoteProperty –Name ClassPath –Value $server.Registry.Path
#		$objServer | Add-Member –MemberType NoteProperty –Name PropertyKey –Value $server.Registry.Key
#		$objServer | Add-Member –MemberType NoteProperty –Name Value –Value $server.Registry.Value
#		$colServers2 += $objServer
#		Write-Host $colServers2.count
#	} ElseIf ($server.Registry.Used -eq "False" -and $server.WMI.Used -eq "True") {
#		$objServer | Add-Member –MemberType NoteProperty –Name LookupSource –Value "WMI"
#		$objServer | Add-Member –MemberType NoteProperty –Name Root –Value $server.WMI.Root
#		$objServer | Add-Member –MemberType NoteProperty –Name ClassPath –Value $server.WMI.Class
#		$objServer | Add-Member –MemberType NoteProperty –Name PropertyKey –Value $server.WMI.Property
#		$objServer | Add-Member –MemberType NoteProperty –Name Value –Value $server.WMI.Value
#		$colServers2 += $objServer
#		Write-Host $colServers2.count
#	} Else {
#		Write-Host "No good"
#	}
#}

$colServers2
$colServers2.count
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


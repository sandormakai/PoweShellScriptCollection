#
# Tester.ps1
#

function New-ServerList($strFilePath,$colResolutionServers)
{
	$colServers = Get-Content -Path $strServerList
	If (!$colServers) {
		LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("An error occured when the script tried to load the list of server from file: `"" + $strServerList + "`"")
		Return (-1)
	}
	Foreach ($objServer in $colServers) {
		If ($colResolutionServers) {
			Try {
				Resolve-DnsName -DnsOnly -Name $objServer -Server $colResolutionServers
			} Catch {
				LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("The DNS resolution for server `"" + $objServer + "`" did not produce a result. This server will not be included in the installation list")
			}
		} Else {
			Try {
				Resolve-DnsName -DnsOnly -Name $objServer
			} Catch {
				LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("The DNS resolution for server `"" + $objServer + "`" did not produce a result. This server will not be included in the installation list")
			}
		}
		$colReturnList += $objServer
	}
	Return $colReturnList
}

$test = New-ServerList -strFilePath D:\Temp\ServerList.txt -colResolutionServers
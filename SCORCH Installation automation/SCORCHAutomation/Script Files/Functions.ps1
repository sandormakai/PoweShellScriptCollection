#
# Script.ps1
#

function Get-RunAsCredential()
{
	$Error.Clear()
	$objError = $null
	$objCredential = Get-Credential -Message "RunAs user with Administrative rights"
	$objError = $Error[0]
	If ($objError -ne $null) {
		LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("An error occured when the script tried to store the credential")
		LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("Exception: " + $objError.Exception)
		Return -1
	}
	LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData "The inserted credential is successfully stored."
	LogToFile -intLogType $constDATA -strFile $strLogFile -strLogData ("Username: " + $objCredential.UserName + "`r`nPassword string: " + ($objCredential.Password | ConvertFrom-SecureString))
	Return $objCredential
}

function New-RemotePSConnection ([string]$strComputerName, [System.Management.Automation.Credential()]$credCredential) {
	LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData ("Opening remote PSSession to " + $strComputerName + "...")
	$Error.Clear()
	$objError = $null
	$objSession = New-PSSession -ComputerName $strComputerName -Credential $credCredential
	$objError = $Error[0]
	If ($objError -ne $null) {
		LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("An error occured when the script tried to open PSSession to computer " + $strComputerName)
		LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("Exception: " + $objError.Exception)
		Return -1
	}
	LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData ("PSSession is open to computer " + $objSession.ComputerName + "with ID: " + $objSession.Id)
	Return $objSession
}

function Get-ServerHardwareCollection() {
	Param(
		[Parameter(Mandatory=$True,ParameterSetName=’Single’)]
		[ValidateNotNullOrEmpty()]
		[switch]$Single,
		[Parameter(Mandatory=$True,ParameterSetName=’Multi’)]
		[ValidateNotNullOrEmpty()]
		[switch]$Multi,
		[Parameter(Mandatory=$True)]
		[xml]$xmlServers,
		[Parameter(Mandatory=$True)]
		[xml]$xmlSettings
	)

	If ($Single -eq $True) {
		LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData ("Get-ServerHardwareCollection called with parameter Single = " + $Single)
		$colServers = @()
		$objServer = New-Object –TypeName PSObject
		$objServer | Add-Member –MemberType NoteProperty –Name Name –Value $xmlServers.configuration.SingleServerInstall.Servers.Server.Name
		$objServer | Add-Member –MemberType NoteProperty –Name IPAddress –Value $xmlServers.configuration.SingleServerInstall.Servers.Server.IPAddress
		$objServer | Add-Member –MemberType NoteProperty –Name ServerRole –Value $xmlServers.configuration.SingleServerInstall.Servers.Server.Type
		$objServer | Add-Member –MemberType NoteProperty –Name CPUSpeed –Value $xmlSettings.configuration.Hardware.SingleServerInstall.Servers.Server.CPUSpeed
		$objServer | Add-Member –MemberType NoteProperty –Name CPUCores –Value $xmlSettings.configuration.Hardware.SingleServerInstall.Servers.Server.CPUCores
		$objServer | Add-Member –MemberType NoteProperty –Name MinRAMMB –Value $xmlSettings.configuration.Hardware.SingleServerInstall.Servers.Server.MinRAMMB
		$objServer | Add-Member –MemberType NoteProperty –Name RecRAMMB –Value $xmlSettings.configuration.Hardware.SingleServerInstall.Servers.Server.RecRAMMB
		$objServer | Add-Member –MemberType NoteProperty –Name MinSpaceMB –Value $xmlSettings.configuration.Hardware.SingleServerInstall.Servers.Server.MinSpaceMB
		$objServer | Add-Member –MemberType NoteProperty –Name RecSpaceMB –Value $xmlSettings.configuration.Hardware.SingleServerInstall.Servers.Server.RecSpaceMB
		$objServer | Add-Member –MemberType NoteProperty –Name InstallationDrive –Value $xmlSettings.configuration.Hardware.SingleServerInstall.Servers.Server.InstallationDrive
		$colServers += $objServer
	} ElseIf ($Multi -eq $True) {
		LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData ("Get-ServerHardwareCollection called with parameter Multi = " + $Multi)
		$colServers = @()
		foreach ($objItem in $xmlServers.configuration.MultiServerInstall.Servers.Server) {
			$objServer = New-Object –TypeName PSObject
			$objServer | Add-Member –MemberType NoteProperty –Name Name –Value $objItem.Name
			$objServer | Add-Member –MemberType NoteProperty –Name IPAddress –Value $objItem.IPAddress
			$objServer | Add-Member –MemberType NoteProperty –Name ServerRole –Value $objItem.Type
			$objServer | Add-Member –MemberType NoteProperty –Name CPUSpeed –Value ""
			$objServer | Add-Member –MemberType NoteProperty –Name CPUCores –Value ""
			$objServer | Add-Member –MemberType NoteProperty –Name MinRAMMB –Value ""
			$objServer | Add-Member –MemberType NoteProperty –Name RecRAMMB –Value ""
			$objServer | Add-Member –MemberType NoteProperty –Name MinSpaceMB –Value ""
			$objServer | Add-Member –MemberType NoteProperty –Name RecSpaceMB –Value ""
			$objServer | Add-Member –MemberType NoteProperty –Name InstallationDrive –Value ""
			$colServers += $objServer
		}
		foreach ($objHardware in $xmlSettings.configuration.hardware.MultiServerInstall.Servers.Server) {
			foreach ($objItem in $colServers) {
				If ($objHardware.Type -eq $objItem.ServerRole) {
					$objItem.CPUSpeed = $objHardware.CPUSpeed
					$objItem.CPUCores = $objHardware.CPUCores
					$objItem.MinRAMMB = $objHardware.MinRAMMB
					$objItem.RecRAMMB = $objHardware.RecRAMMB
					$objItem.MinSpaceMB = $objHardware.MinSpaceMB
					$objItem.RecSpaceMB = $objHardware.RecSpaceMB
					$objItem.InstallationDrive = $objHardware.InstallationDrive
				}
			}
		}
	} Else {
		LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData ("Something went wrong with calling Get-ServerHardwareCollection")
		Return -1
	}
	return $colServers
}

function Get-RoleSupportedOSCollection() {
	Param(
		[Parameter(Mandatory=$True,ParameterSetName=’Single’)]
		[ValidateNotNullOrEmpty()]
		[switch]$Single,
		[Parameter(Mandatory=$True,ParameterSetName=’Multi’)]
		[ValidateNotNullOrEmpty()]
		[switch]$Multi,
		[Parameter(Mandatory=$True)]
		[xml]$xmlServers,
		[Parameter(Mandatory=$True)]
		[xml]$xmlSettings
	)
	If ($Single -eq $True) {
		LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData ("Get-RoleSupportedOSCollection called with parameter Single = " + $Single)
		$colServers = @()
		foreach ($objItem in $xmlSettings.configuration.Software.SingleServerInstall.Servers.Server.OperatingSystem.Version) {
			$objServer = New-Object –TypeName PSObject
			$objServer | Add-Member –MemberType NoteProperty –Name Name –Value $xmlServers.configuration.SingleServerInstall.Servers.Server.Name
			$objServer | Add-Member –MemberType NoteProperty –Name IPAddress –Value $xmlServers.configuration.SingleServerInstall.Servers.Server.IPAddress
			$objServer | Add-Member –MemberType NoteProperty –Name ServerRole –Value $xmlServers.configuration.SingleServerInstall.Servers.Server.Type
			$objServer | Add-Member –MemberType NoteProperty –Name OSName –Value $objItem.Name
			$objServer | Add-Member –MemberType NoteProperty –Name VersionNumber –Value $objItem.VersionNumber
			$objServer | Add-Member –MemberType NoteProperty –Name Editions –Value $objItem.Edition
			$colServers += $objServer
		}
	} ElseIf ($Multi -eq $True) {
		LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData ("Get-RoleSupportedOSCollection called with parameter Multi = " + $Multi)
		$colServers = @()
		foreach ($objServerInfo in $xmlServers.configuration.MultiServerInstall.Servers.Server) {
			foreach ($objItem in $xmlSettings.configuration.Software.MultiServerInstall.Servers.Server) {
				If ($objServerInfo.Type -eq $objItem.Type) {
					foreach ($objOS in (($xmlSettings.configuration.Software.MultiServerInstall.Servers.Server | ? {$_.Type -eq $objItem.Type}).OperatingSystem.Version)) {
						$objServer = New-Object –TypeName PSObject
						$objServer | Add-Member –MemberType NoteProperty –Name Name –Value $objServerInfo.Name
						$objServer | Add-Member –MemberType NoteProperty –Name IPAddress –Value $objServerInfo.IPAddress
						$objServer | Add-Member –MemberType NoteProperty –Name ServerRole –Value $objServerInfo.Type
						$objServer | Add-Member –MemberType NoteProperty –Name OSName –Value $objOS.Name
						$objServer | Add-Member –MemberType NoteProperty –Name VersionNumber –Value $objOS.VersionNumber
						$objServer | Add-Member –MemberType NoteProperty –Name Editions –Value $objOS.Edition
						$colServers += $objServer
					}
				}
			}
		}
	} Else {
		LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData ("Something went wrong with calling Get-RoleSupportedOSCollection")
		Return -1
	}
	return $colServers
}



function Get-RoleSupportedDatabaseCollection() {
	Param(
		[Parameter(Mandatory=$True,ParameterSetName=’Single’)]
		[ValidateNotNullOrEmpty()]
		[switch]$Single,
		[Parameter(Mandatory=$True,ParameterSetName=’Multi’)]
		[ValidateNotNullOrEmpty()]
		[switch]$Multi,
		[Parameter(Mandatory=$True)]
		[xml]$xmlServers,
		[Parameter(Mandatory=$True)]
		[xml]$xmlSettings
	)
	If ($Single -eq $True) {
		LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData ("Get-RoleSupportedOSCollection called with parameter Single = " + $Single)
		$colServers = @()
		foreach ($objDatabaseType in $xmlSettings.configuration.Software.SingleServerInstall.Servers.Server.Databases.Database) {
			foreach ($objItem in $objDatabaseType.Versions.Version) {
				$objServer = New-Object –TypeName PSObject
				$objServer | Add-Member –MemberType NoteProperty –Name Name –Value $xmlServers.configuration.SingleServerInstall.Servers.Server.Name
				$objServer | Add-Member –MemberType NoteProperty –Name IPAddress –Value $xmlServers.configuration.SingleServerInstall.Servers.Server.IPAddress
				$objServer | Add-Member –MemberType NoteProperty –Name ServerRole –Value $xmlServers.configuration.SingleServerInstall.Servers.Server.Type
				$objServer | Add-Member –MemberType NoteProperty –Name VersionName –Value $objItem.Name
				$objServer | Add-Member –MemberType NoteProperty –Name VersionNumber –Value $objItem.VersionNumber
				$objServer | Add-Member –MemberType NoteProperty –Name Editions –Value $objItem.Edition
				$objServer | Add-Member –MemberType NoteProperty –Name Collation –Value $objDatabaseType.Collation
				$colServers += $objServer
			}
		}
	} ElseIf ($Multi -eq $True) {
		LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData ("Get-RoleSupportedOSCollection called with parameter Multi = " + $Multi)
		$colServers = @()
		foreach ($objServerInfo in $xmlServers.configuration.MultiServerInstall.Servers.Server) {
			foreach ($objItem in $xmlSettings.configuration.Software.MultiServerInstall.Servers.Server) {
				If ($objServerInfo.Type -eq $objItem.Type) {
					foreach ($objDatabaseType in (($xmlSettings.configuration.Software.MultiServerInstall.Servers.Server | ? {$_.Type -eq $objItem.Type}).Databases.Database)) {
						foreach ($objDatabase in $objDatabaseType.Versions.Version) {
							$objServer = New-Object –TypeName PSObject
							$objServer | Add-Member –MemberType NoteProperty –Name Name –Value $objServerInfo.Name
							$objServer | Add-Member –MemberType NoteProperty –Name IPAddress –Value $objServerInfo.IPAddress
							$objServer | Add-Member –MemberType NoteProperty –Name ServerRole –Value $objServerInfo.Type
							$objServer | Add-Member –MemberType NoteProperty –Name VersionName –Value $objDatabase.Name
							$objServer | Add-Member –MemberType NoteProperty –Name VersionNumber –Value $objDatabase.VersionNumber
							$objServer | Add-Member –MemberType NoteProperty –Name Editions –Value $objDatabase.Edition
							$objServer | Add-Member –MemberType NoteProperty –Name Collation –Value $objDatabaseType.Collation
							$colServers += $objServer
						}
					}
				}
			}
		}
	} Else {
		LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData ("Something went wrong with calling Get-RoleSupportedOSCollection")
		Return -1
	}
	return $colServers
}


function Get-DomainRoleCollection () {
	Param(
		[Parameter(Mandatory=$True,ParameterSetName=’Single’)]
		[ValidateNotNullOrEmpty()]
		[switch]$Single,
		[Parameter(Mandatory=$True,ParameterSetName=’Multi’)]
		[ValidateNotNullOrEmpty()]
		[switch]$Multi,
		[Parameter(Mandatory=$True)]
		[xml]$xmlServers,
		[Parameter(Mandatory=$True)]
		[xml]$xmlSettings
	)
	If ($Single -eq $True) {
		LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData ("Get-DomainRoleCollection called with parameter Single = " + $Single)
		$colServers = @()
		foreach ($objItem in $xmlSettings.configuration.Software.SingleServerInstall.Servers.Server.DomainJoined) {
			$objServer = New-Object –TypeName PSObject
			$objServer | Add-Member –MemberType NoteProperty –Name Name –Value $xmlServers.configuration.SingleServerInstall.Servers.Server.Name
			$objServer | Add-Member –MemberType NoteProperty –Name IPAddress –Value $xmlServers.configuration.SingleServerInstall.Servers.Server.IPAddress
			$objServer | Add-Member –MemberType NoteProperty –Name ServerRole –Value $xmlServers.configuration.SingleServerInstall.Servers.Server.Type
			$objServer | Add-Member –MemberType NoteProperty –Name WMIRoot –Value $objItem.WMIRoot
			$objServer | Add-Member –MemberType NoteProperty –Name WMIClass –Value $objItem.WMIClass
			$objServer | Add-Member –MemberType NoteProperty –Name WMIProperty –Value $objItem.WMIProperty
			$objServer | Add-Member –MemberType NoteProperty –Name WMIPropertyValue –Value $objItem.Value
			$colServers += $objServer
		}
	} ElseIf ($Multi -eq $True) {
		LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData ("Get-DomainRoleCollection called with parameter Multi = " + $Multi)
		$colServers = @()
		foreach ($objServerInfo in $xmlServers.configuration.MultiServerInstall.Servers.Server) {
			foreach ($objItem in $xmlSettings.configuration.Software.MultiServerInstall.Servers.Server) {
				If ($objServerInfo.Type -eq $objItem.Type) {
					foreach ($objDomainRole in (($xmlSettings.configuration.Software.MultiServerInstall.Servers.Server | ? {$_.Type -eq $objItem.Type}).DomainJoined)) {
						$objServer = New-Object –TypeName PSObject
						$objServer | Add-Member –MemberType NoteProperty –Name Name –Value $objServerInfo.Name
						$objServer | Add-Member –MemberType NoteProperty –Name IPAddress –Value $objServerInfo.IPAddress
						$objServer | Add-Member –MemberType NoteProperty –Name ServerRole –Value $objServerInfo.Type
						$objServer | Add-Member –MemberType NoteProperty –Name WMIRoot –Value $objDomainRole.WMIRoot
						$objServer | Add-Member –MemberType NoteProperty –Name WMIClass –Value $objDomainRole.WMIClass
						$objServer | Add-Member –MemberType NoteProperty –Name WMIProperty –Value $objDomainRole.WMIProperty
						$objServer | Add-Member –MemberType NoteProperty –Name WMIPropertyValue –Value $objDomainRole.Value
						$colServers += $objServer
					}
				}
			}
		}
	} Else {
		LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData ("Something went wrong with calling Get-DomainRoleCollection")
		return -1
	}
	return $colServers

}

function Get-AdditionalSoftwareCollection () {
	Param(
		[Parameter(Mandatory=$True,ParameterSetName=’Single’)]
		[ValidateNotNullOrEmpty()]
		[switch]$Single,
		[Parameter(Mandatory=$True,ParameterSetName=’Multi’)]
		[ValidateNotNullOrEmpty()]
		[switch]$Multi,
		[Parameter(Mandatory=$True)]
		[xml]$xmlServers,
		[Parameter(Mandatory=$True)]
		[xml]$xmlSettings
	)
	If ($Single -eq $True) {
		LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData ("Get-AdditionalSoftwareCollection called with parameter Single = " + $Single)
		$colServers = @()
		foreach ($software in $xmlSettings.configuration.Software.SingleServerInstall.Servers.Server.AdditionalSoftwares.AdditionalSoftware) {
			$objServer = New-Object –TypeName PSObject
			$objServer | Add-Member –MemberType NoteProperty –Name Name –Value $xmlServers.configuration.SingleServerInstall.Servers.Server.Name
			$objServer | Add-Member –MemberType NoteProperty –Name IPAddress –Value $xmlServers.configuration.SingleServerInstall.Servers.Server.IPAddress
			$objServer | Add-Member –MemberType NoteProperty –Name ServerRole –Value $xmlServers.configuration.SingleServerInstall.Servers.Server.Type
			If ($software.Registry.Used -eq "True" -and $software.WMI.Used -eq "False") {
				$objServer | Add-Member –MemberType NoteProperty –Name LookupSource –Value "Registry"
				$objServer | Add-Member –MemberType NoteProperty –Name Root –Value $software.Registry.Root
				$objServer | Add-Member –MemberType NoteProperty –Name ClassPath –Value $software.Registry.Path
				$objServer | Add-Member –MemberType NoteProperty –Name PropertyKey –Value $software.Registry.Key
				$objServer | Add-Member –MemberType NoteProperty –Name Value –Value $software.Registry.Value
				$colServers += $objServer
			} ElseIf ($software.Registry.Used -eq "False" -and $software.WMI.Used -eq "True") {
				$objServer | Add-Member –MemberType NoteProperty –Name LookupSource –Value "WMI"
				$objServer | Add-Member –MemberType NoteProperty –Name Root –Value $software.WMI.Root
				$objServer | Add-Member –MemberType NoteProperty –Name ClassPath –Value $software.WMI.Class
				$objServer | Add-Member –MemberType NoteProperty –Name PropertyKey –Value $software.WMI.Property
				$objServer | Add-Member –MemberType NoteProperty –Name Value –Value $software.WMI.Value
				$colServers += $objServer
			} Else {
				Write-Host ("Wrong entry for " + ($software.Name) + " in case of server named " + ($objServer.Name))
				LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("Both LookupSource is marked true or false for software " + ($software.Name) + "in case of server named " + ($objServer.Name) + ". Please make sure only one of them is marked as true...")
			}
		}
	} ElseIf ($Multi -eq $True) {
		LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData ("Get-AdditionalSoftwareCollection called with parameter Multi = " + $Multi)
		$colServers = @()
		foreach ($objServerInfo in $xmlServers.configuration.MultiServerInstall.Servers.Server) {
			foreach ($objItem in $xmlSettings.configuration.Software.MultiServerInstall.Servers.Server) {
				If ($objServerInfo.Type -eq $objItem.Type) {
					foreach ($software in (($xmlSettings.configuration.Software.MultiServerInstall.Servers.Server | ? {$_.Type -eq $objItem.Type}).AdditionalSoftwares.AdditionalSoftware)) {
						$objServer = New-Object –TypeName PSObject
						$objServer | Add-Member –MemberType NoteProperty –Name Name –Value $objServerInfo.Name
						$objServer | Add-Member –MemberType NoteProperty –Name IPAddress –Value $objServerInfo.IPAddress
						$objServer | Add-Member –MemberType NoteProperty –Name ServerRole –Value $objServerInfo.Type
						If ($software.Registry.Used -eq "True" -and $software.WMI.Used -eq "False") {
							$objServer | Add-Member –MemberType NoteProperty –Name LookupSource –Value "Registry"
							$objServer | Add-Member –MemberType NoteProperty –Name Root –Value $software.Registry.Root
							$objServer | Add-Member –MemberType NoteProperty –Name ClassPath –Value $software.Registry.Path
							$objServer | Add-Member –MemberType NoteProperty –Name PropertyKey –Value $software.Registry.Key
							$objServer | Add-Member –MemberType NoteProperty –Name Value –Value $software.Registry.Value
							$colServers += $objServer
						} ElseIf ($software.Registry.Used -eq "False" -and $software.WMI.Used -eq "True") {
							$objServer | Add-Member –MemberType NoteProperty –Name LookupSource –Value "WMI"
							$objServer | Add-Member –MemberType NoteProperty –Name Root –Value $software.WMI.Root
							$objServer | Add-Member –MemberType NoteProperty –Name ClassPath –Value $software.WMI.Class
							$objServer | Add-Member –MemberType NoteProperty –Name PropertyKey –Value $software.WMI.Property
							$objServer | Add-Member –MemberType NoteProperty –Name Value –Value $software.WMI.Value
							$colServers += $objServer
						} Else {
							LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("Both LookupSource is marked true or false for software " + ($software.Name) + "in case of server named " + ($objServer.Name) + ". Please make sure only one of them is marked as true...")
						}
					}
				}
			}
		}
	} Else {
		LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData ("Something went wrong with calling Get-AdditionalSoftwareCollection")
		return -1
	}
	return $colServers
}

function Validate-IpToHostName () {
	Param(
	[Parameter(Mandatory=$True,ParameterSetName=’Single’)]
	[ValidateNotNullOrEmpty()]
	[switch]$Single,
	[Parameter(Mandatory=$True,ParameterSetName=’Multi’)]
	[ValidateNotNullOrEmpty()]
	[switch]$Multi,
	[Parameter(Mandatory=$True)]
	[ValidateNotNullOrEmpty()]
	[xml]$xmlServers
	)
	If ($Single -eq $True) {
		LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData ("ValidateIpToHostName called with parameter Single = " + $Single)
		$strHostName = $xmlServers.configuration.SingleServerInstall.Servers.Server.Name
		Try {
			[ipaddress]$iaIPAddress = $xmlServers.configuration.SingleServerInstall.Servers.Server.IPAddress
		} Catch {
			LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("ServerName: " + $strHostName + " - ErrorMessage: " + $_.Exception.Message)
			Return -1
		}
	} ElseIf ($Multi -eq $True) {
		LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData ("ValidateIpToHostName called with parameter Multi = " + $Multi)
		Try {
			foreach ($objServer in $xmlServers.configuration.MultiServerInstall.Servers.Server) {
				$strHostName = $objServer.Name
				[ipaddress]$iaIPAddress = $objServer.IPAddress
				$blnConnection = Validate-Connection -strServerName $strHostName -iaServerIP $iaIPAddress
				If ($blnConnection -ne 0) {
					LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("Connection to the server named " +  + " with IP address: " +  + " failed. Check the connection and try again.")
					Return -1
				}
			}
		} Catch {
			LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("ServerName: " + $strHostName + " - ErrorMessage: " + $_.Exception.Message)
			Return -1
		}
	} Else {
		LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData ("Something went wrong with calling ValidateIpToHostName")
		return -1
	}
	return 0
}

function Get-RegistryValue () {

}

function Test-RegistryKey([string]$strComputerName, [string]$strRegKey, [string]$strRegValue)
{
	If ($strComputerName -eq $null -or $strComputerName -eq "")
	{
	    $strComputerName = "localhost"
	}
	$objRemoteReg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey("LocalMachine", $strComputerName)
	If ($objRemoteReg -eq $null)
	{
		[int]$ReturnValue = -1
		return $ReturnValue
	}
	$objRemoteKey = $objRemoteReg.OpenSubKey($strRegKey)
	If ($objRemoteKey -eq $null)
	{
		[int]$ReturnValue = 1
		return $ReturnValue
	}
	$colRegValues = $objRemoteKey.GetValueNames()
	Foreach ($objRegValue in $colRegValues)
	{
		If ([string]$objRegValue -eq $strRegValue)
		{
			[int]$ReturnValue = 0
			Return $ReturnValue
		}
		Else { [int]$ReturnValue = 2 }
	}
	return $ReturnValue
}

function Check-NETFramework35([string]$strComputerName)
{
	$NetFramework35RegPath = "Software\Microsoft\NET Framework Setup\NDP\v3.5"
	$NetFramework35RegKey = "Install"
	If ($strComputerName -eq $NULL -or $strComputerName -eq "")
	{
		$Result = Test-RegistryKey -strRegKey $NetFramework35RegPath -strRegValue $NetFramework35RegKey
	}
	Else
	{
		$Result = Test-RegistryKey -strComputerName $strComputerName -strRegKey $NetFramework35RegPath -strRegValue $NetFramework35RegKey
	}
	Return $Result
}

function Mount-ImageFile([string]$strFileName)
{
	Write-Host "something"
}

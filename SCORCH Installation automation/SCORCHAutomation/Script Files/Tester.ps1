#
# Tester.ps1
#
$ErrorActionPreference = 'silentlycontinue'
."C:\Users\sandor.makai\OneDrive - Inframon 1\Source\Repos\PoweShellScriptCollection\SCORCH Installation automation\SCORCHAutomation\Script Files\Functions.ps1"

function Validate-Connection ([string]$strServerName, [ipaddress]$iaServerIP, [System.Management.Automation.Credential()]$credCredential) {
	$idConnection = New-RemotePSConnection -strComputerName $strServerName -credCredential $credRunasAccount
	If ($idConnection -eq -1) {
		LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("An error occured when the script tried to validate the connection properties. Please check the log for related errors")
		return -1
	}
	return 0
}


#$colServers2 = @()
#[xml]$testXML = Get-Content D:\Temp\InfrastructureServers.xml
#[xml]$testXML2 = Get-Content D:\Temp\PrerequisiteSettings.xml

#$colServers2 = ValidateIpToHostName -Single -xmlServers $testXML -xmlSettings $testXML2
#$colServers2 = Validate-IpToHostName -Multi -xmlServers $testXML

$credRunasAccount = Get-RunAsCredential

$strHostName = "Buzievagy"
[ipaddress]$iaIPAddress = "10.5.1.4"
$colServers2 = Validate-Connection -strServerName $strHostName -iaServerIP $iaIPAddress

$colServers2
$colServers2.count

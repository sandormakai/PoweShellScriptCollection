#
# GetSCOMCertificate.ps1
#
[CmdletBinding()]
Param(
	[Parameter(Mandatory=$True,ParameterSetName=’Single’)]
	[ValidateNotNullOrEmpty()]
	[Alias("Single")]
	[switch]$blnSingle,
	[Parameter(Mandatory=$True,ParameterSetName=’Multiple’)]
	[ValidateNotNullOrEmpty()]
	[Alias("Multiple")]
	[switch]$blnMultiple,
	[Parameter(Mandatory=$True,ParameterSetName=’Single’)]
	[ValidateNotNullOrEmpty()]
	[Alias("ServerName")]
	[string]$strServerName,
	[Parameter(Mandatory=$True,ParameterSetName=’Multiple’)]
	[ValidateScript({Test-Path $_ -PathType ‘Leaf’})]
	[Alias("ServerList")]
	[string]$strServerList,
	[Parameter(Mandatory=$True)]
	[ValidateNotNullOrEmpty()]
	[Alias("Template")]
	[string]$strTemplateName,
	[Parameter(Mandatory=$False)]
	[ValidateList("NORMAL","DEBUG")]
	[Alias("ScriptVerbose")]
	[string]$strScriptVerbose

)

$strScriptPath = $NULL
$strScriptName = $NULL
$strLogName = "Custom Scripts"
$strCertificateStore = "Cert:\LocalMachine\My"

function Get-ScriptDirectory
{
	$Invocation = $NULL
	$Invocation = (Get-Variable MyInvocation -Scope 1).Value
	If ($Invocation -eq $NULL) {
		$strCommand = $ErrorReturn.InvocationInfo.Line
		$strException = $ErrorReturn.Exception
		Write-Host ("Error occured during command: {0} `r`nThe exception of the error is: {1}" -f $strCommand, $strException)
		Exit -1
	}
	Split-Path $Invocation.MyCommand.Path
}

If (-not($strScriptPath = Get-ScriptDirectory)) {
	Write-Host "The script cannot determinde its working directory. Without this parameter the script cannot run. Please check and run the script again!"
	Exit -2
}

.((Get-ScriptDirectory) + "..\_Basic\Logging.ps1")

If (!(Test-Path -Path ("{0}\Certificates" -f $strScriptPath))) {
	New-Item -Path $strScriptPath -Name "Certificates" -ItemType Directory
	$strCertFolder = ("{0}\Certificates" -f $strScriptPath)
}

$strScriptName = ($MyInvocation.MyCommand.Name).Substring(0,($MyInvocation.MyCommand.Name).Length-4)
$blnCheckError = $false
$strCertPassword = Read-Host "Enter Password used for certificates..." -AsSecureString

######################### Initialization ##################################################################################################################

function Generate-InfFile ([string]$strComputerName,[string]$strTemplateName) {
	$strFileName = ($strScriptPath + "\" + $strComputerName + ".inf")
	If (Get-ChildItem -Path $strFileName -ErrorAction SilentlyContinue) {
		Remove-Item -Path $strFileName
	}
	Add-Content -Path $strFileName -Value "[NewRequest]"
	Add-Content -Path $strFileName -Value ("Subject=`"CN={0}`"" -f $strComputerName)
	Add-Content -Path $strFileName -Value "KeyLength=2048"
	Add-Content -Path $strFileName -Value "KeySpec=1"
	Add-Content -Path $strFileName -Value "KeyUsage=0xf0"
	Add-Content -Path $strFileName -Value "MachineKeySet=TRUE"
	Add-Content -Path $strFileName -Value "[RequestAttributes]"
	Add-Content -Path $strFileName -Value ("CertificateTemplate=`"{0}`"" -f $strTemplateName)
}

function Request-Cert ($strReqFile) {

}

function Generate-PFXCert ($strComputerName) {
	$objCert = Get-ChildItem -Path $strCertificateStore | 
	% {
	$_ | Select `
		Friendlyname,
		Thumbprint,
		@{N="Template";E={($_.Extensions | ?{$_.oid.Friendlyname -match "Certificate Template Information"}).Format(0) -replace "(.+)?=(.+)\((.+)?", '$2'}},
		@{N="Subject";E={($_.SubjectName.name -replace ".*=")}}
	} | ? {($_.Subject -eq $strComputerName) -and ($_.Template -eq $strTemplateName)}
	If (!$objCert) {
		Write-WARNINGEvent -strLogName $strLogName -strSource $strScriptName -strMessage ("No certificate could be found!`r`nSubjectName: {0}`r`nTemplate: {1}" -f $strComputerName, $strTemplateName) -intCurrentDebugLevel $strScriptVerbose -intDebugLevelMessage "DEBUG"
	} Else {
		Get-ChildItem -Path ("Cert:\LocalMachine\My\{0}" -f $objCert.Thumbprint) | Export-PfxCertificate -FilePath $strCertFolder -Password $strCertPassword
	}
}


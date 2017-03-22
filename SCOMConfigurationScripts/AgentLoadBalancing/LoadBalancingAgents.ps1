[CmdletBinding()]
Param(
	[Parameter(Mandatory=$True)]
	[ValidateNotNullOrEmpty()]
	[Alias("ResourcePool")]
	[string]$strResourcePool,
	[Parameter(Mandatory=$True)]
	[ValidateNotNullOrEmpty()]
	[Alias("Filter")]
	[string]$strNamePattern
)

$objApi = New-Object -ComObject "MOM.ScriptAPI"
#$objApi.LogScriptEvent("Test.ps1",9999,0,"this is a test event")
$colManagementServers = @()
$strError = ""
$strScriptName = ($MyInvocation.MyCommand.Name).Substring(0,($MyInvocation.MyCommand.Name).Length-4)


####################### Function to finish the script #################
function End-Script($blnWithError) {
	If ($blnWithError -eq $True) {
        $strLogEntry = ("The script finished with error!`r`nErrormessage: " + $strError + ".")
        $objApi.LogScriptEvent($strScriptName,9999,1,$strLogEntry)
		Exit (-10)
	} Else {
        $strLogEntry = ("The script finished successfully")
        $objApi.LogScriptEvent($strScriptName,9998,1,$strLogEntry)
		Exit (0)
	}
}

####################### Get the Resource Pool object using its DisplayName #######################
$objResourcePool = Get-SCOMResourcePool -DisplayName $strResourcePool
If (!$objResourcePool) {
    $strError = ("No Resource Pool Available with name `"" + $strResourcePool + "`"")
    End-Script -blnWithError $True
} ElseIf ($objResourcePool.Members.Count -lt 2) {
    $strError = ("The Resource Pool requires to have at least 2 members`r`nResource Pool: " + ($objResourcePool.DisplayName) + "`r`nNumber of Members: " + ($objResourcePool.Members.Count))
    End-Script -blnWithError $True
}

###################### Load all Management Servers in the variable from the pool #################
foreach ($objMember in $objResourcePool.Members) {
    $colManagementServers += Get-SCOMManagementServer -Name $objMember.DisplayName
}

##################### Loading all Agents from the Management Group ###############################
$colAgents = Get-SCOMAgent | ? {$_.DisplayName -like $strLocationID}
If (!$colAgents) {
    $strError = ("No agents were found with the location ID `"" + $strLocationID + "`"")
    End-Script -blnWithError $True
}

##################### Set Primary and Failover Management Servers for agents one-by-one ##########
Foreach ($objAgent in $colAgents) {
    $objPrimaryMgtSrv, $objremainingMgtSrvs = $colManagementServers
    $objFailoverMgtSrv = $colManagementServers[1]
    $colManagementServers = @()
    Set-SCOMParentManagementServer -Agent $objAgent -FailoverServer $null
    Set-SCOMParentManagementServer -Agent $objAgent -PrimaryServer $objPrimaryMgtSrv
    Set-SCOMParentManagementServer -Agent $objAgent -FailoverServer $objFailoverMgtSrv
    $colManagementServers += $colManagementServers
    $colManagementServers += $colManagementServers
}
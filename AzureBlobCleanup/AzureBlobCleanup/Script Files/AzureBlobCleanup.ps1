<#  
.SYNOPSIS  
    Clean-Up files from Azure storage account past retention time  
.DESCRIPTION  
    The script is designed to take care of the files past retention time on the dedicated Azure storage Account
	It is originally designed for SQL Backup files, but because the extensions and filenames can be changed in the 
	parameters, it can be used for other type of files as well. It can handle backups for Full Recovery Model
.NOTES  
    Author     : Sandor Makai - sandor.makai@inframon.com
    Requires   : It was tested using PS version 5
.EXAMPLE  
	.\AzureBlobCleanup.ps1 -Simple -StorageName NameOfStorage -StorageKey KeyOfStorage -ContainerFull ContainerForFull -ExtensionFull ".bak" -CleanupTimeUnitFull D -CleanupTimeFrameFull -35 -FileNameFilter "*file*" -ScriptVerbose

	Clean-up files older than 35 days (Simple Recovery Model)
.EXAMPLE  
	.\AzureBlobCleanup.ps1 -Full -StorageName NameOfStorage -StorageKey KeyOfStorage -ContainerFull ContainerForFull -ExtensionFull ".bak" -ContainerDiff ContainerForDiff -ExtensionDiff ".dif" -ContainerDiff ContainerForTrn -ExtensionDiff ".trn" -CleanupTimeUnitFull D -CleanupTimeFrameFull -35 -FileNameFilter "*file*" -KeepDiffForFull 1 -ScriptVerbose

    Clean-Up full backup files older than 35 days,	differential and transaction log
	backup files older than the last full backup (Full Recovery Model)

.PARAMETER blnFull
	[Alias: Full]
	Parameter is used to tell the script the Recovery Model. It changes the script behaviour
	to look for differential and transaction log backups. The following parameters only 
	available when blnFull is selected:
		- strContainerForDiff
		- strExtensionForDiff
		- strContainerForTrn
		- strExtensionForTrn
		- intKeepDiffForFull
	One of the parameters blnFull or blnSimple is mandatory

.PARAMETER blnSimple
	[Alias: Simple]
	Parameter is used to tell the script the Recovery Model. It changes the script behaviour
	to look only for full backup file. The parameters listed in the section blnFull are not
	available when Simple recovery model is selected.
	One of the parameters blnFull or blnSimple is mandatory

.PARAMETER strStorageAccountName
	[Alias: StorageName]
	Mandatory parameter. It is for the Name of the Storage Account in Azure

.PARAMETER strStorageAccountKey
	[Alias: StorageKey]
	Mandatory parameter. It is for the Secret Key of the Storage Account in Azure

.PARAMETER strContainerForFull
	[Alias: ContainerFull]
	Mandatory parameter. It identifies the container used to store the full backup files.

.PARAMETER strExtensionForFull
	[Alias: ExtensionFull]
	This parameter identifies the extension of the files used for the full backups.
	Optional parameter, its default value is ".bak"

.PARAMETER strContainerForDiff
	[Alias: ContainerDiff]
	Optional parameter. It identifies the container used to store the differential backup
	files. It is available only with blnFull. Default value is the same as strContainerForFull

.PARAMETER strExtensionForDiff
	[Alias: ExtensionDiff]
	This parameter identifies the extension of the files used for the differential backups.
	Optional parameter, its default value is ".dif"

.PARAMETER strContainerForTrn
	[Alias: ContainerTrn]
	Optional parameter. It identifies the container used to store the Transaction Log backup
	files. 	It is available only with blnFull. Default value is the same as strContainerForFull

.PARAMETER strExtensionForTrn
	[Alias: ExtensionTrn]
	This parameter identifies the extension of the files used for the Transaction log backups.
	Optional parameter, its default value is ".trn"

.PARAMETER strFilterForFileName
	[Alias: FileNameFilter]
	This parameter is for telling the script about the pattern of the files we would like to
	work with. Together with the extension it creates the full search pattern.
	Mandatory parameter.

.PARAMETER chrCleanupTimeUnitFull
	[Alias: CleanupTimeUnitFull]
	Parameter to identifies the retention time unit. It can holds the following characters:
		 - Y or y - It means the time unit is YEAR
		 - M or m - It means the time unit is MONTH
		 - D or d - It means the time unit is DAY
		 - H or h - It means the time unit is HOUR
	Together with intCleanupTimeFrameFull it creates the retention time period
	Mandatory parameter

.PARAMETER intCleanupTimeFrameFull
	[Alias: CleanupTimeFrameFull]
	Parameters to identifies how many units the script needs to calculate into the past
	to identifies the deletion point. Together with chrCleanupTimeUnitFull it creates
	the retention time period.
	Mandatory parameter.

.PARAMETER intKeepDiffForFull
	[Alias: KeepDiffForFull]
	This parameter tell the script how many full backups in the past needs to have their
	differential and transaction log backup files kept.
	Optional parameter, its default value is 1. This means only the last full backup will
	have its differential and transaction log backup files kept.

.PARAMETER blnVerbose
	[Alias: ScriptVerbose]
	If this parameter selected the script will use the console to inform the user which
	action is currently running. It is used only for informational purposes.
	Optional parameter, its default value is False.
#>

###################### INIT #############################################################
[CmdletBinding()]
Param(
	[Parameter(Mandatory=$True,ParameterSetName=’Full’)]
	[ValidateNotNullOrEmpty()]
	[Alias("Full")]
	[switch]$blnFull = $False,
	[Parameter(Mandatory=$True,ParameterSetName=’Simple’)]
	[ValidateNotNullOrEmpty()]
	[Alias("Simple")]
	[switch]$blnSimple = $False,
	[Parameter(Mandatory=$True)]
	[ValidateNotNullOrEmpty()]
	[Alias("StorageName")]
	[string]$strStorageAccountName,
	[Parameter(Mandatory=$True)]
	[ValidateNotNullOrEmpty()]
	[Alias("StorageKey")]
	[string]$strStorageAccountKey,
	[Parameter(Mandatory=$True)]
	[ValidateNotNullOrEmpty()]
	[Alias("ContainerFull")]
	[string]$strContainerForFull,
	[Parameter(Mandatory=$False)]
	[ValidateNotNullOrEmpty()]
	[Alias("ExtensionFull")]
	[string]$strExtensionForFull = ".bak",
	[Parameter(Mandatory=$False,ParameterSetName=’Full’)]
	[ValidateNotNullOrEmpty()]
	[Alias("ContainerDiff")]
	[string]$strContainerForDiff = $strContainerForFull,
	[Parameter(Mandatory=$False,ParameterSetName=’Full’)]
	[ValidateNotNullOrEmpty()]
	[Alias("ExtensionDiff")]
	[string]$strExtensionForDiff = ".dif",
	[Parameter(Mandatory=$False,ParameterSetName=’Full’)]
	[ValidateNotNullOrEmpty()]
	[Alias("ContainerTrn")]
	[string]$strContainerForTrn = $strContainerForFull,
	[Parameter(Mandatory=$False,ParameterSetName=’Full’)]
	[ValidateNotNullOrEmpty()]
	[Alias("ExtensionTrn")]
	[string]$strExtensionForTrn = ".trn",
	[Parameter(Mandatory=$True)]
	[ValidateNotNullOrEmpty()]
	[Alias("FileNameFilter")]
	[string]$strFilterForFileName,
	[Parameter(Mandatory=$True)]
	[ValidateSet("H","h","D","d","M","m","Y","y")]
	[Alias("CleanupTimeUnitFull")]
	[char]$chrCleanupTimeUnitFull,
	[Parameter(Mandatory=$True)]
	[ValidateNotNullOrEmpty()]
	[Alias("CleanupTimeFrameFull")]
	[int]$intCleanupTimeFrameFull,
	[Parameter(Mandatory=$False,ParameterSetName=’Full’)]
	[ValidateNotNullOrEmpty()]
	[Alias("KeepDiffForFull")]
	[string]$intKeepDiffForFull = 1,
	[Parameter(Mandatory=$False)]
	[ValidateNotNullOrEmpty()]
	[Alias("ScriptVerbose")]
	[switch]$blnVerbose = $False
)

$strScriptName = $NULL

$strScriptName = ($MyInvocation.MyCommand.Name).Substring(0,($MyInvocation.MyCommand.Name).Length-4)

####################### Function to finish the script #################
function End-Script($blnWithError) {
	Write-Host -ForegroundColor Yellow "The script is finishing."
	If ($blnWithError -eq $True) {
		Write-EventLog –LogName Application –Source $strScriptName –EntryType Warning `
		    –EventID 7001 –Message	("The script {0} finished with errors. Please check the" -f $strScriptName + `
			"log for related entries. Fix the errors and run the script again.") -Category 0
		If ($blnVerbose) {
			Write-Host "Press any key to continue..."
			$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
		}
		Exit (-10)
	} Else {
		Write-EventLog –LogName Application –Source $strScriptName –EntryType Information `
		    –EventID 7000 –Message ("The script {0} finished successfully" -f $strScriptName) -Category 0
		If ($blnVerbose) {
			Write-Host "Press any key to continue..."
			$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
		}
		Exit (0)
	}
}

##################### Starting main script ############################
Try {
    $a = Write-EventLog –LogName Application –Source $strScriptName –EntryType Information `
		–EventID 7000 –Message ("Starting script {0}... `
	Calling Parameters: `
	Full Recovery Model: {1} `
	Simple Recovery Model: {2} `
	Storage Account Name: {3} `
	Storage Account Key: {4} `
	Storage Container (Full): {5} `
	File Extension (Full): {6} `
	Storage Container (Diff): {7} `
	File Extension (Diff): {8} `
	Storage Container (Trn): {9} `
	File Extension (Trn): {10} `
	Filter for Filename: {11} `
	Cleanup Time Unit (Full): {12} `
	Cleanup Timeframe (Full): {13} `
	Keep Diff Backup for x Full: {14}" -f $strScriptName, $blnFull, $blnSimple, `
	$strStorageAccountName, ($strStorageAccountKey.Substring(0,10)), $strContainerForFull, $strExtensionForFull, `
	$strContainerForDiff, $strExtensionForDiff, $strContainerForTrn, $strExtensionForTrn, `
	$strFilterForFileName, $chrCleanupTimeUnitFull, $intCleanupTimeFrameFull, `
	$intKeepDiffForFull) -Category 0 -ErrorAction Stop
} Catch [System.Security.SecurityException] {
    New-EventLog –LogName Application –Source $strScriptName
    $a = Write-EventLog –LogName Application –Source $strScriptName –EntryType Information `
		–EventID 7000 –Message ("Starting script {0}...`
	Calling Parameters: `
	Full Recovery Model: {1} `
	Simple Recovery Model: {2} `
	Storage Account Name: {3} `
	Storage Account Key: {4} `
	Storage Container (Full): {5} `
	File Extension (Full): {6} `
	Storage Container (Diff): {7} `
	File Extension (Diff): {8} `
	Storage Container (Trn): {9} `
	File Extension (Trn): {10} `
	Filter for Filename: {11} `
	Cleanup Time Unit (Full): {12} `
	Cleanup Timeframe (Full): {13} `
	Keep Diff Backup for x Full: {14}" -f $strScriptName, $blnFull, $blnSimple, `
	$strStorageAccountName, ($strStorageAccountKey.Substring(0,10)), $strContainerForFull, $strExtensionForFull, `
	$strContainerForDiff, $strExtensionForDiff, $strContainerForTrn, $strExtensionForTrn, `
	$strFilterForFileName, $chrCleanupTimeUnitFull, $intCleanupTimeFrameFull, `
	$intKeepDiffForFull) -Category 0 -ErrorAction Stop
} Catch [InvalidOperationException] {
    New-EventLog –LogName Application –Source $strScriptName
    $a = Write-EventLog –LogName Application –Source $strScriptName –EntryType Information `
		–EventID 7000 –Message ("Starting script {0}...`
	Calling Parameters: `
	Full Recovery Model: {1} `
	Simple Recovery Model: {2} `
	Storage Account Name: {3} `
	Storage Account Key: {4} `
	Storage Container (Full): {5} `
	File Extension (Full): {6} `
	Storage Container (Diff): {7} `
	File Extension (Diff): {8} `
	Storage Container (Trn): {9} `
	File Extension (Trn): {10} `
	Filter for Filename: {11} `
	Cleanup Time Unit (Full): {12} `
	Cleanup Timeframe (Full): {13} `
	Keep Diff Backup for x Full: {14}" -f $strScriptName, $blnFull, $blnSimple, `
	$strStorageAccountName, ($strStorageAccountKey.Substring(0,10)), $strContainerForFull, $strExtensionForFull, `
	$strContainerForDiff, $strExtensionForDiff, $strContainerForTrn, $strExtensionForTrn, `
	$strFilterForFileName, $chrCleanupTimeUnitFull, $intCleanupTimeFrameFull, `
	$intKeepDiffForFull) -Category 0 -ErrorAction Stop
}

If ($blnVerbose) {
	Write-Host -ForegroundColor Yellow ("Starting script `"" + $strScriptName + "`"...`r`n" + `
		"Calling Parameters:")
	Write-Host -ForegroundColor Yellow -NoNewline ("Full Recovery Model: ")
	Write-Host -ForegroundColor Green $blnFull
	Write-Host -ForegroundColor Yellow -NoNewline ("Simple Recovery Model: ")
	Write-Host -ForegroundColor Green $blnSimple
	Write-Host -ForegroundColor Yellow -NoNewline ("Storage Account Name: ")
	Write-Host -ForegroundColor Green $strStorageAccountName
	Write-Host -ForegroundColor Yellow -NoNewline ("Storage Account Key: ")
	Write-Host -ForegroundColor Green $strStorageAccountKey
	Write-Host -ForegroundColor Yellow -NoNewline ("Storage Container (Full): ")
	Write-Host -ForegroundColor Green $strContainerForFull
	Write-Host -ForegroundColor Yellow -NoNewline ("File Extension (Full): ")
	Write-Host -ForegroundColor Green $strExtensionForFull
	Write-Host -ForegroundColor Yellow -NoNewline ("Storage Container (Diff): ")
	Write-Host -ForegroundColor Green $strContainerForDiff
	Write-Host -ForegroundColor Yellow -NoNewline ("File Extension (Diff): ")
	Write-Host -ForegroundColor Green $strExtensionForDiff
	Write-Host -ForegroundColor Yellow -NoNewline ("Storage Container (Trn): ")
	Write-Host -ForegroundColor Green $strContainerForTrn
	Write-Host -ForegroundColor Yellow -NoNewline ("File Extension (Trn): ")
	Write-Host -ForegroundColor Green $strExtensionForTrn
	Write-Host -ForegroundColor Yellow -NoNewline ("Filter for Filename: ")
	Write-Host -ForegroundColor Green $strFilterForFileName
	Write-Host -ForegroundColor Yellow -NoNewline ("Cleanup Time Unit (Full): ")
	Write-Host -ForegroundColor Green $chrCleanupTimeUnitFull
	Write-Host -ForegroundColor Yellow -NoNewline ("Cleanup Timeframe (Full): ")
	Write-Host -ForegroundColor Green $intCleanupTimeFrameFull
	Write-Host -ForegroundColor Yellow -NoNewline ("Keep Diff Backup for x Full: ")
	Write-Host -ForegroundColor Green $intKeepDiffForFull
}

######################## Determine Time variable ########################
switch($chrCleanupTimeUnitFull){
	"H" {$dtCleanupTime = [DateTime]::UtcNow.AddHours($intCleanupTimeFrameFull)}
	"h" {$dtCleanupTime = [DateTime]::UtcNow.AddHours($intCleanupTimeFrameFull)}
	"D" {$dtCleanupTime = [DateTime]::UtcNow.AddDays($intCleanupTimeFrameFull)}
	"d" {$dtCleanupTime = [DateTime]::UtcNow.AddDays($intCleanupTimeFrameFull)}
	"M" {$dtCleanupTime = [DateTime]::UtcNow.AddMonths($intCleanupTimeFrameFull)}
	"m" {$dtCleanupTime = [DateTime]::UtcNow.AddMonths($intCleanupTimeFrameFull)}
	"Y" {$dtCleanupTime = [DateTime]::UtcNow.AddYears($intCleanupTimeFrameFull)}
	"y" {$dtCleanupTime = [DateTime]::UtcNow.AddYears($intCleanupTimeFrameFull)}
}

Write-EventLog –LogName Application –Source $strScriptName –EntryType Information `
		–EventID 7000 –Message ("CleaunUp Time: {0}" -f $dtCleanupTime) -Category 0
If ($blnVerbose) {
	Write-Host -ForegroundColor Yellow -NoNewline "`r`nDetermined CleaunUp Time: "
	Write-Host -ForegroundColor Green $dtCleanupTime
}

######################## Connecting ot Storage ###########################
If ($blnVerbose) {
	Write-Host -ForegroundColor Yellow -NoNewline ("Connecting to Azure Storage...")
}

$Error.Clear()
$objError = $NULL
Try {
	$objAzStorage = New-AzureStorageContext -StorageAccountName $strStorageAccountName -StorageAccountKey $strStorageAccountKey
} Catch [System.Management.Automation.CommandNotFoundException] {
	Write-EventLog –LogName Application –Source $strScriptName –EntryType Error `
		–EventID 7005 –Message ("The Azure PowerShell Module is not installed on this computer." + `
			" Please install the module before executing the script") -Category 0
	If ($blnVerbose) {
		Write-Host -ForegroundColor Red ("Failed!")
	}
	End-Script -blnWithError $True
} Catch {
	$objError = $Error[0]
	Write-EventLog –LogName Application –Source $strScriptName –EntryType Error `
		–EventID 7005 –Message ("An error occured when the script tried to load the Azure storage context" + `
			" Exception: {0}" -f ($objError.Exception)) -Category 0
	If ($blnVerbose) {
		Write-Host -ForegroundColor Red ("Failed!")
	}
	End-Script -blnWithError $True
}

Write-EventLog –LogName Application –Source $strScriptName –EntryType Information `
	–EventID 7000 –Message ("Connection to Azure storage {0} is successfull" -f `
	($objAzStorage.StorageAccountName)) -Category 0
If ($blnVerbose) {
	Write-Host -ForegroundColor Green ("Done!")
}

####################### Removing old full backup files from Storage ##############################
If ($blnVerbose) {
	Write-Host -ForegroundColor Yellow -NoNewline ("Removing old full backup files...")
}

$Error.Clear()
$objError = $NULL

Try {
	Get-AzureStorageBlob -Container $strContainerForFull -Context $objAzStorage | `
		Where-Object { $_.Name -like ($strFilterForFileName + $strExtensionForFull) -and $_.BlobType `
		-eq "PageBlob" -and $_.LastModified.UtcDateTime -lt $dtCleanupTime} | Remove-AzureStorageBlob
} Catch {
	$objError = $Error[0]
	Write-EventLog –LogName Application –Source $strScriptName –EntryType Error `
		–EventID 7005 –Message ("An error occured when the script tried delete the" + `
		 " old full backup files. Exception: {0}" -f ($objError.Exception)) -Category 0
	If ($blnVerbose) {
		Write-Host -ForegroundColor Red ("Failed!")
	}
	End-Script -blnWithError $True
}

Write-EventLog –LogName Application –Source $strScriptName –EntryType Information `
	–EventID 7000 –Message ("Old full backup files are deleted!") -Category 0
If ($blnVerbose) {
	Write-Host -ForegroundColor Green ("Done!")
}

If ($blnSimple -eq $True) {
	End-Script -blnWithError $False
}

########## Removing old differential and transaction log backup files from Storage ##############################
If ($blnVerbose) {
	Write-Host -ForegroundColor Yellow -NoNewline ("Removing old differential and" + `
	" transaction log backup files...")
}

$Error.Clear()
$objError = $NULL

Try {
    $dtCleanupTime = (((Get-AzureStorageBlob -Container $strContainerForFull -Context $objAzStorage | `
		Where-Object { $_.Name -like ($strFilterForFileName + $strExtensionForFull) -and $_.BlobType `
		-eq "PageBlob" } | Sort-Object LastModified -Descending)[$intKeepDiffForFull-1]).LastModified).DateTime

} Catch {
	$objError = $Error[0]
	Write-EventLog –LogName Application –Source $strScriptName –EntryType Error `
		–EventID 7005 –Message ("An error occured when the script tried to identify" + `
		    " the cleanup timeframe for old differential and transaction log backup files." + `
            " Exception: {0}" -f ($objError.Exception)) -Category 0
	If ($blnVerbose) {
		Write-Host -ForegroundColor Red ("Failed!")
	}
	End-Script -blnWithError $True
}

$Error.Clear()
$objError = $NULL

Try {
	Get-AzureStorageBlob -Container $strContainerForDiff -Context $objAzStorage | `
		Where-Object { $_.Name -like ($strFilterForFileName + $strExtensionForDiff) -and $_.BlobType `
		-eq "PageBlob" -and $_.LastModified.UtcDateTime -lt $dtCleanupTime} | Remove-AzureStorageBlob
	Get-AzureStorageBlob -Container $strContainerForTrn -Context $objAzStorage | `
		Where-Object { $_.Name -like ($strFilterForFileName + $strExtensionForTrn) -and $_.BlobType `
		-eq "PageBlob" -and $_.LastModified.UtcDateTime -lt $dtCleanupTime} | Remove-AzureStorageBlob
} Catch {
	$objError = $Error[0]
	Write-EventLog –LogName Application –Source $strScriptName –EntryType Error `
		–EventID 7005 –Message ("An error occured when the script tried delete the" + `
		 " old differential and transaction log backup files. Exception: {0}" -f ($objError.Exception)) -Category 0
	If ($blnVerbose) {
		Write-Host -ForegroundColor Red ("Failed!")
	}
	End-Script -blnWithError $True
}

Write-EventLog –LogName Application –Source $strScriptName –EntryType Information `
	–EventID 7000 –Message ("Old differential and transaction log backup files are deleted!") -Category 0

If ($blnVerbose) {
	Write-Host -ForegroundColor Green ("Done!")
}

End-Script -blnWithError $False
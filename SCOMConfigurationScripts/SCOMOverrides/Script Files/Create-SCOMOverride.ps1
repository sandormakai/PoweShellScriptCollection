<# 
.SYNOPSIS 
    A summary of what this script does 
    In this case, this script documents the auto-help text in PSH CTP 3 
    Appears in all basic, -detailed, -full, -examples 
.DESCRIPTION 
    A more in depth description of the script 
    Should give script developer more things to talk about 
    Hopefully this can help the community too 
    Becomes: "DETAILED DESCRIPTION" 
    Appears in basic, -full and -detailed 
.NOTES 
    Additional Notes, eg 
    File Name  : Get-AutoHelp.ps1 
    Author     : Thomas Lee - tfl@psp.co.uk 
    Appears in -full  
.LINK 
    A hyper link, eg 
    http://www.pshscripts.blogspot.com 
    Becomes: "RELATED LINKS"  
    Appears in basic and -Full 
.EXAMPLE 
    The first example - just text documentation 
    You should provide a way of calling the script, plus expected output 
    Appears in -detailed and -full 
.EXAMPLE 
    The second example - more text documentation 
    This would be an example calling the script differently. You can have lots 
    and lots, and lots of examples if this is useful. 
    Appears in -detailed and -full 
.INPUTTYPE 
   Documentary text, eg: 
   Input type  [Universal.SolarSystem.Planetary.CommonSense] 
   Appears in -full 
.RETURNVALUE 
   Documentary Text, eg: 
   Output type  [Universal.SolarSystem.Planetary.Wisdom] 
   Appears in -full 
.COMPONENT 
   Not sure how to specify or use 
   Does not appear in basic, -full, or -detailed 
   Should appear in -component 
.ROLE  
   Not sure How to specify or use 
   Does not appear in basic, -full, or -detailed 
   Should appear with -role 
.FUNCTIONALITY 
   Not sure How to specify or use 
   Does not appear in basic, -full, or -detailed 
   Should appear with -functionality 
.PARAMETER foo 
   The .Parameter area in the script is used to derive the contents of the PARAMETERS in Get-Help output which  
   documents the parameters in the param block. The section takes a value (in this case foo, 
   the name of the first actual parameter), and only appears if there is parameter of that name in the 
   params block. Having a section for a parameter that does not exist generate no extra output of this section 
   Appears in -det, -full (with more info than in -det) and -Parameter (need to specify the parameter name) 
.PARAMETER bar 
   Example of a parameter definition for a parameter that does not exist. 
   Does not appear at all. 
#> 

[CmdletBinding()]
Param(
	[Parameter(Mandatory=$True,ParameterSetName="ToMG")]
	[ValidateNotNullOrEmpty()]
	[Alias("ImportToMG")]
	[switch]$Global:blnImportToMG,
	[Parameter(Mandatory=$True,ParameterSetName="ToFile")]
	[ValidateNotNullOrEmpty()]
	[Alias("OnlyToFile")]
	[switch]$Global:blnOnlyToFile,
	[Parameter(Mandatory=$True,ParameterSetName="ToMG")]
	[ValidateNotNullOrEmpty()]
	[Alias("ManagementServer")]
	[string]$Global:strManagementServer,
	[Parameter(Mandatory=$True)]
	[ValidateScript({Test-Path $_ -PathType ‘Container’})]
	[Alias("ManagementPackStore")]
	[string]$Global:strManagementPackStore,
	[Parameter(Mandatory=$True)]
	[ValidateScript({Test-Path $_ -PathType ‘Leaf’})]
	[Alias("ItemListFile")]
	[string]$strItemListFile,
	[Parameter(Mandatory=$False)]
	[ValidateNotNullOrEmpty()]
	[Alias("ScriptVerbose")]
	[switch]$blnScritpVerbose
)

$strScriptPath = $NULL
$strScriptName = $NULL
$strLogFile = $NULL

function Get-ScriptDirectory
{
	$Invocation = $NULL
	$Invocation = (Get-Variable MyInvocation -Scope 1).Value
	If ($Invocation -eq $NULL) {
		If ($strLogFile -eq $NULL) {
			$strCommand = $ErrorReturn.InvocationInfo.Line
			$strException = $ErrorReturn.Exception
			Write-Host "Error occured during command: $strCommand `r`nThe exception of the error is: $strException"
			Exit -1
		}
		Else {
			$strCommand = $ErrorReturn.InvocationInfo.Line
			$strException = $ErrorReturn.Exception
			LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData "Error occured during command: $strCommand"
			LogToFile -intLogType $constDATA -strFile $strLogFile -strLogData "The exception of the error is: $strException"
			$ReturnValue = $false
			return
		}
		
	}
	Split-Path $Invocation.MyCommand.Path
}

.((Get-ScriptDirectory) + "\Logging.ps1")

If (-not($strScriptPath = Get-ScriptDirectory)) {
	Write-Host "The script cannot determinde its working directory. Without this parameter the script cannot run. Please check and run the script again!"
	Exit -2
}
$strScriptName = ($MyInvocation.MyCommand.Name).Substring(0,($MyInvocation.MyCommand.Name).Length-4)
$strLogFile = ($strScriptPath + "\" + $strScriptName + ".log")
$blnCheckError = $false

####################### Function to finish the script #################
function End-Script($blnWithError) {
	Write-Host -ForegroundColor Yellow "The script is finishing."
	If ($blnWithError -eq $True) {
		LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData "The script $strScriptName finished with errors. Please check the log for related entries. Fix the errors and run the script again."
		Write-Host "Press any key to continue..."
		$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
		Exit (-10)
	} Else {
		LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData "The script $strScriptName finished successfully"
		Write-Host "Press any key to continue..."
		$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
		Exit (0)
	}
}

####################### Function to get admin credential ###########################
function Get-RunAsCredential($strUserName)
{
	$Error.Clear()
	$objError = $null
	Try {
		If ($strUserName -eq "") {
			$objCredential = Get-Credential -Message "RunAs user with Administrative rights"
		} Else {
			$objCredential = Get-Credential -UserName $strUserName -Message "RunAs user with Administrative rights"
		}
	} Catch {
		$objError = $Error[0]
		LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("An error occured when the script tried to store the credential")
		LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData ("Exception: " + $objError.Exception)
		Return -1
	}
	LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData "The inserted credential is successfully stored."
	LogToFile -intLogType $constDATA -strFile $strLogFile -strLogData ("Username: " + $objCredential.UserName + "`r`nPassword string: " + ($objCredential.Password | ConvertFrom-SecureString))
	Return $objCredential
}

################### Get the highest version number ############################################
function Get-Highest ($arrList){
	$intCount = 0
	$strReference = ""
	While ($arrList.Count -gt 1) {
		$arrCurrentList = $arrList.Clone()
		For ($i=0; $i -lt $arrCurrentList.Count; $i++) {
			$arrCurrentList[$i] = [int[]] $arrCurrentList[$i].split(".")
			[int[]]$arrCompList += $arrCurrentList[$i][$intCount]
		}
		$intHigh = ($arrCompList | Measure-Object -Max).Maximum
		If (($arrCurrentList[0].Count) -eq ($intCount+1)) {
			$strReference += ([string]$intHigh)
		} Else {
			$strReference += ([string]$intHigh + ".")
		}
		$arrList = $arrList | ? {$_.StartsWith($strReference)}
		$arrCompList = ""
		$intCount++
	}
	Return $arrList
}

################### Funciton to check the existence of Override MP #################################
function Check-OverridePack ($strManagementPackName) {
	If ($Global:blnImportToMG) {
		$objManagementPackInMG = Get-SCOMManagementPack -Name $strManagementPackName
		If ($objManagementPackInMG -eq $null) {
			$strLatestVersionFromMG = "NOTEXIST"
		} Else {
			$strLatestVersionFromMG = ($objManagementPackInMG.Version).ToString()
		}
		Try {
			$colVersions = (Get-ChildItem -ErrorAction Stop -Path ($Global:strMPStore + "\" + $strManagementPackName) | Where-Object {$_.PSIsContainer} | Foreach-Object {$_.Name})
			If ($colVersions -eq $null) {
				### No version folder available
				$strLatestVersionFromStore = "NOTEXIST"
			} Else {
				$strLatestVersionFromStore = Get-Highest $colVersions
			}
		} Catch {
			### No folder exist
			$strLatestVersionFromStore = "NOTEXIST"
		}
		If (($strLatestVersionFromMG -eq "NOTEXIST") -and ($strLatestVersionFromStore -eq "NOTEXIST")) {
			$strLatestVersion = "NOTEXIST"
		} ElseIf (($strLatestVersionFromMG -eq "NOTEXIST") -and ($strLatestVersionFromStore -ne "NOTEXIST")) {
			$strLatestVersion = ($strLatestVersionFromStore + ":FILE")
		} ElseIf (($strLatestVersionFromMG -ne "NOTEXIST") -and ($strLatestVersionFromStore -eq "NOTEXIST")) {
			$strLatestVersion = ($strLatestVersionFromMG + ":MG")
		} Else {
			[System.Object[]]$arrTempList = $strLatestVersionFromMG
			$arrTempList += $strLatestVersionFromStore
			$strLatestVersion = Get-Highest $arrTempList
			If ($strLatestVersion -eq $strLatestVersionFromMG) {
				$strLatestVersion = ($strLatestVersion + ":MG")
			} ElseIf ($strLatestVersion -eq $strLatestVersionFromStore) {
				$strLatestVersion = ($strLatestVersion + ":FILE")
			} Else {
				$strLatestVersion = ($strLatestVersion + ":UNKNOWN")
			}
		}
	} ElseIf ($Global:blnOnlyToFile) {
		Try {
			$colVersions = (Get-ChildItem -ErrorAction Stop -Path ($Global:strMPStore + "\" + $strManagementPackName) | Where-Object {$_.PSIsContainer} | Foreach-Object {$_.Name})
			If ($colVersions -eq $null) {
				### No version folder available
				$strLatestVersion = "NOTEXIST"
			} Else {
				$strLatestVersion = Get-Highest $colVersions
				$strLatestVersion = ($strLatestVersion + ":FILE")
			}
		} Catch {
			### No folder exist
			$strLatestVersion = "NOTEXIST"
		}
	}
	Return $strLatestVersion
}

################### Function to get the original target and Management Pack for items ##############
function Check-ContextAndOverridePack ([ref]$colItems) {
	foreach ($objItem in $colItems.Value) {
		If ((($objItem.Context) -ne "") -and (($objItem.OverridePack) -ne "")) { ### Both Context and Override Pack is filled
			$arrContextItems = ($objItem.Context).Split(":")
			switch($arrContextItems[1]) { 
				"" {                                                         ### If Context identified as a SCOM Class
					$objClass = Get-SCOMClass -Name $arrContextItems[0]
					If (!$objClass) {
						$objItem.Context = "ERROR1:Not exist!"
					} ElseIf ($objClass.Count -gt 1) { 
						$objItem.Context = "ERROR2:There are more than 1 Class available"
					} Else {
						If ((Get-SCOMManagementPack -Name ($objClass.Identifier.Domain[0])).Sealed) { ### Check whether the Management pack of the class is sealed or not
							$objItem.Context = (($objItem.Context) + ":Class:SEALED")
						} Else {
							$objItem.Context = (($objItem.Context) + ":Class:UNSEALED")
						}
					}
				}
				"Group" {                                                    ### If Context identified as a SCOM Group
					$objGroup = Get-SCOMGroup -DisplayName $arrContextItems[0]
					If (!$objGroup) {
						$objItem.Context = "ERROR1:Not exist!"
					} ElseIf ($objGroup.Count -gt 1) {
						$objItem.Context = "ERROR2:There are more than 1 Group available"
					} Else {
						If ((Get-SCOMManagementPack -Name ($objGroup.GetMostDerivedMonitoringClasses().ManagementPackName)).Sealed) { ### Check whether the Management pack of the group is sealed or not
							$objItem.Context = (($objItem.Context) + ":SEALED")
						} Else {
							$objItem.Context = (($objItem.Context) + ":UNSEALED")
						}
					}
				}
				default {                                                    ### If Context cannot be identified
					$objItem.Context = "ERROR3:Context entry is unknown"
				}
			}
			$objTemp = Check-OverridePack -strManagementPackName ($objItem.OverridePack)  ###Check whether the Override ManagementPack exist or not
			If ($objTemp -eq "NOTEXIST") {
				$objItem.OverridePack = (($objItem.OverridePack) + ":1.0.0.0:NOTEXIST")
			} Else {
				$objItem.OverridePack = (($objItem.OverridePack) + ":" + $objTemp)
			}
			$objMonitor = Get-SCOMMonitor -Name $objItem.Name                ### Check whether the item is a Monitor or not
			If (!$objMonitor) {
				$objRule = Get-SCOMRule -Name $objItem.Name                  ### Check whether the item is a Monitor or not
				If (!$objRule) {
					$objItem.Name = "ERROR5:No Monitor or rule is available with the given Name"
				} Else {
					If ($objRule.Sealed){                                    ### Check whether the item in a SEALED or UNSEALED Management Pack
						$objItem.Name = (($objItem.Name) + ":SEALED")
					} Else {
						$objItem.Name = (($objItem.Name) + ":UNSEALED")
					}
				}
			} Else {
				If ((Get-SCOMManagementPack -Name ($objMonitor.Identifier.Domain[0])).Sealed) {  ### Check whether the item in a SEALED or UNSEALED Management Pack
					$objItem.Name = (($objItem.Name) + ":SEALED")
				} Else {
					$objItem.Name = (($objItem.Name) + ":UNSEALED")
				}
			}
		} Else {
			If ((($objItem.Context) -eq "") -and (($objItem.OverridePack) -eq "")) { ### Both Context and Override Pack is empty
				$objMonitor = Get-SCOMMonitor -Name ($objItem.Name)                    ### Check whether the item is Monitor
					If (!$objMonitor) {
						$objRule = Get-SCOMRule -Name ($objItem.Name)                  ### Check whether the item is Rule
						If (!$objRule) {
							$objItem.Name = "ERROR5:No Monitor or rule is available with the given Name"  ### Write an error to the variable if the item is neither a rule nor a monitor
						} Else {
							$objClass = Get-SCOMClass -Name ($objRule.Target.Identifier.Path)               ### Check whether the item's target is a class
							If ($objClass) {
								If ((Get-SCOMManagementPack -Name ($objClass.Identifier.Domain[0])).Sealed) {   ### Check whether the item's class is in a sealed management pack
									$objItem.Context = (($objRule.Target.Identifier.Path) + ":SEALED")
								} Else {
									$objItem.Context = (($objRule.Target.Identifier.Path) + ":UNSEALED")
								}	
							} Else {                                                                           ### If the item's target is not class, than it must be a group
								$objGroup = Get-SCOMGroup | ? {$_.FullName -eq ($objRule.Target.Identifier.Path)}
								If ((Get-SCOMManagementPack -Name ($objGroup.GetMostDerivedMonitoringClasses().ManagementPackName)).Sealed) {
									$objItem.Context = (($objGroup.DisplayName) + ":SEALED")
								} Else {
									$objItem.Context = (($objGroup.DisplayName) + ":UNSEALED")
								}
							}
							If ($objRule.Sealed) {                                   ### Check whether the Rule is in a sealed Management Pack or not
								$objItem.Name = (($objItem.Name) + ":SEALED")
							} Else {
								$objItem.Name = (($objItem.Name) + ":UNSEALED")
							}
							$objTemp = Check-OverridePack -strManagementPackName (($objRule.ManagementPackName) + ".Override")   ### Identifies the OverridePack
							If ($objTemp -eq "NOTEXIST") {
								$objItem.OverridePack = (($objRule.ManagementPackName) + ".Override:1.0.0.0:NOTEXIST")
							} Else {
								$objItem.OverridePack = (($objRule.ManagementPackName) + ".Override:" + $objTemp)
							}
						}
					} Else {                  ### If the item is a monitor
						$objClass = Get-SCOMClass -Name ($objMonitor.Target.Identifier.Path)               ### Check whether the item's target is a class
						If ($objClass) {
							If ((Get-SCOMManagementPack -Name ($objClass.Identifier.Domain[0])).Sealed) {   ### Check whether the item's class is in a sealed management pack
								$objItem.Context = (($objMonitor.Target.Identifier.Path) + ":SEALED")
							} Else {
								$objItem.Context = (($objMonitor.Target.Identifier.Path) + ":UNSEALED")
							}	
						} Else {                                                                           ### If the item's target is not class, than it must be a group
							$objGroup = Get-SCOMGroup | ? {$_.FullName -eq ($objRule.Target.Identifier.Path)}
							If ((Get-SCOMManagementPack -Name ($objGroup.GetMostDerivedMonitoringClasses().ManagementPackName)).Sealed) {
								$objItem.Context = (($objGroup.DisplayName) + ":SEALED")
							} Else {
								$objItem.Context = (($objGroup.DisplayName) + ":UNSEALED")
							}
						}
						If ((Get-SCOMManagementPack -Name ($objMonitor.Identifier.Domain[0])).Sealed) {  ### Check whether the item in a SEALED or UNSEALED Management Pack
							$objItem.Name = (($objItem.Name) + ":SEALED")
						} Else {
							$objItem.Name = (($objItem.Name) + ":UNSEALED")
						}
						$objTemp = Check-OverridePack -strManagementPackName (($objMonitor.Identifier.Domain[0]) + ".Override")   ### Identifies the OverridePack
						If ($objTemp -eq "NOTEXIST") {
							$objItem.OverridePack = (($objMonitor.Identifier.Domain[0]) + ".Override:1.0.0.0:NOTEXIST")
						} Else {
							$objItem.OverridePack = (($objMonitor.Identifier.Domain[0]) + ".Override:" + $objTemp)
						}
					}
			} ElseIf ((($objItem.Context) -ne "") -and (($objItem.OverridePack) -eq "")) { ### Only Context is filled
				$arrContextItems = ($objItem.Context).Split(":")
				switch($arrContextItems[1]) { 
					"" {                                                         ### If Context identified as a SCOM Class
						$objClass = Get-SCOMClass -Name $arrContextItems[0]
						If (!$objClass) {
							$objItem.Context = "ERROR1:Not exist!"
						} ElseIf ($objClass.Count -gt 1) { 
							$objItem.Context = "ERROR2:There are more than 1 Class available"
						} Else {
							If ((Get-SCOMManagementPack -Name ($objClass.Identifier.Domain[0])).Sealed) { ### Check whether the Management pack of the class is sealed or not
								$objItem.Context = (($objItem.Context) + ":Class:SEALED")
							} Else {
								$objItem.Context = (($objItem.Context) + ":Class:UNSEALED")
							}
						}
					}
					"Group" {                                                    ### If Context identified as a SCOM Group
						$objGroup = Get-SCOMGroup -DisplayName $arrContextItems[0]
						If (!$objGroup) {
							$objItem.Context = "ERROR1:Not exist!"
						} ElseIf ($objGroup.Count -gt 1) {
							$objItem.Context = "ERROR2:There are more than 1 Group available"
						} Else {
							If ((Get-SCOMManagementPack -Name ($objGroup.GetMostDerivedMonitoringClasses().ManagementPackName)).Sealed) { ### Check whether the Management pack of the group is sealed or not
								$objItem.Context = (($objItem.Context) + ":SEALED")
							} Else {
								$objItem.Context = (($objItem.Context) + ":UNSEALED")
							}
						}
					}
					default {                                                    ### If Context cannot be identified
						$objItem.Context = "ERROR3:Context entry is unknown"
					}
				}
				$objMonitor = Get-SCOMMonitor -Name $objItem.Name                ### Check whether the item is a Monitor or not
				If (!$objMonitor) {
					$objRule = Get-SCOMRule -Name $objItem.Name                  ### Check whether the item is a Monitor or not
					If (!$objRule) {
						$objItem.Name = "ERROR5:No Monitor or rule is available with the given Name"
					} Else {
						If ($objRule.Sealed){                                    ### Check whether the item in a SEALED or UNSEALED Management Pack
							$objItem.Name = (($objItem.Name) + ":SEALED")
						} Else {
							$objItem.Name = (($objItem.Name) + ":UNSEALED")
						}
						$objTemp = Check-OverridePack -strManagementPackName (($objRule.ManagementPackName) + ".Override")   ### Identifies the OverridePack
						If ($objTemp -eq "NOTEXIST") {
							$objItem.OverridePack = (($objRule.ManagementPackName) + ".Override:1.0.0.0:NOTEXIST")
						} Else {
							$objItem.OverridePack = (($objRule.ManagementPackName) + ".Override:" + $objTemp)
						}
					}
				} Else {
					If ((Get-SCOMManagementPack -Name ($objMonitor.Identifier.Domain[0])).Sealed) {  ### Check whether the item in a SEALED or UNSEALED Management Pack
						$objItem.Name = (($objItem.Name) + ":SEALED")
					} Else {
						$objItem.Name = (($objItem.Name) + ":UNSEALED")
					}
					$objTemp = Check-OverridePack -strManagementPackName (($objMonitor.Identifier.Domain[0]) + ".Override")   ### Identifies the OverridePack
					If ($objTemp -eq "NOTEXIST") {
						$objItem.OverridePack = (($objMonitor.Identifier.Domain[0]) + ".Override:1.0.0.0:NOTEXIST")
					} Else {
						$objItem.OverridePack = (($objMonitor.Identifier.Domain[0]) + ".Override:" + $objTemp)
					}
				}
			} ElseIf (($objItem.Context -eq "") -and ($objItem.OverridePack -ne "")) { ### Only OverridePack is filled
				$objMonitor = Get-SCOMMonitor -Name ($objItem.Name)                    ### Check whether the item is Monitor
					If (!$objMonitor) {
						$objRule = Get-SCOMRule -Name ($objItem.Name)                  ### Check whether the item is Rule
						If (!$objRule) {
							$objItem.Name = "ERROR5:No Monitor or rule is available with the given Name"  ### Write an error to the variable if the item is neither a rule nor a monitor
						} Else {
							$objClass = Get-SCOMClass -Name ($objRule.Target.Identifier.Path)               ### Check whether the item's target is a class
							If ($objClass) {
								If ((Get-SCOMManagementPack -Name ($objClass.Identifier.Domain[0])).Sealed) {   ### Check whether the item's class is in a sealed management pack
									$objItem.Context = (($objRule.Target.Identifier.Path) + ":SEALED")
								} Else {
									$objItem.Context = (($objRule.Target.Identifier.Path) + ":UNSEALED")
								}	
							} Else {                                                                           ### If the item's target is not class, than it must be a group
								$objGroup = Get-SCOMGroup | ? {$_.FullName -eq ($objRule.Target.Identifier.Path)}
								If ((Get-SCOMManagementPack -Name ($objGroup.GetMostDerivedMonitoringClasses().ManagementPackName)).Sealed) {
									$objItem.Context = (($objGroup.DisplayName) + ":SEALED")
								} Else {
									$objItem.Context = (($objGroup.DisplayName) + ":UNSEALED")
								}
							}
							If ($objRule.Sealed) {                                   ### Check whether the Rule is in a sealed Management Pack or not
								$objItem.Name = (($objItem.Name) + ":SEALED")
							} Else {
								$objItem.Name = (($objItem.Name) + ":UNSEALED")
							}
							$objTemp = Check-OverridePack -strManagementPackName ($objItem.OverridePack)   ### Identifies the OverridePack
							If ($objTemp -eq "NOTEXIST") {
								$objItem.OverridePack = (($objItem.OverridePack) + ":1.0.0.0:NOTEXIST")
							} Else {
								$objItem.OverridePack = (($objItem.OverridePack) + ":" + $objTemp)
							}
						}
					} Else {                  ### If the item is a monitor
						$objClass = Get-SCOMClass -Name ($objMonitor.Target.Identifier.Path)               ### Check whether the item's target is a class
						If ($objClass) {
							If ((Get-SCOMManagementPack -Name ($objClass.Identifier.Domain[0])).Sealed) {   ### Check whether the item's class is in a sealed management pack
								$objItem.Context = (($objMonitor.Target.Identifier.Path) + ":SEALED")
							} Else {
								$objItem.Context = (($objMonitor.Target.Identifier.Path) + ":UNSEALED")
							}	
						} Else {                                                                           ### If the item's target is not class, than it must be a group
							$objGroup = Get-SCOMGroup | ? {$_.FullName -eq ($objRule.Target.Identifier.Path)}
							If ((Get-SCOMManagementPack -Name ($objGroup.GetMostDerivedMonitoringClasses().ManagementPackName)).Sealed) {
								$objItem.Context = (($objGroup.DisplayName) + ":SEALED")
							} Else {
								$objItem.Context = (($objGroup.DisplayName) + ":UNSEALED")
							}
						}
						If ((Get-SCOMManagementPack -Name ($objMonitor.Identifier.Domain[0])).Sealed) {  ### Check whether the item in a SEALED or UNSEALED Management Pack
							$objItem.Name = (($objItem.Name) + ":SEALED")
						} Else {
							$objItem.Name = (($objItem.Name) + ":UNSEALED")
						}
						$objTemp = Check-OverridePack -strManagementPackName ($objItem.OverridePack)   ### Identifies the OverridePack
						If ($objTemp -eq "NOTEXIST") {
							$objItem.OverridePack = (($objItem.OverridePack) + ":1.0.0.0:NOTEXIST")
						} Else {
							$objItem.OverridePack = (($objItem.OverridePack) + ":" + $objTemp)
						}
					}
			} Else {                                                                   ### Unknown configuration
				$objItem.Name = "ERROR4:Unknown configuration for this item in the CSV file"
			}
		}
	}
}

################### Function to create Management Pack using XML template file #####################
function Create-ManagementPack ($strMPName, $strMPVersion) {

}

################### Function to create list of affected management packs ###########################
function Create-ManagementPackList ($colItems) {
	[string[]]$arrManagementPacks = $NULL
	Foreach ($objItem in $colItems) {
		If (!($arrManagementPacks -contains $objItem.OverridePack)) {
			$arrManagementPacks += $objItem.OverridePack
		}
	}
	Foreach ($objItem in $arrManagementPacks) {
		$arrItem = $objItem.Split(":")
		If ($arrItem[2] -eq "NOTEXIST") {
			Create-ManagementPack -strMPName ($arrItem[0]) -strMPVersion ($arrItem[1])
		}
	}
}

###################### Initialization ###############################################
LogToFile -intLogType $constINFO -strFile $strLogFile -strLogData ("The script `"" + $strScriptName + "`" has been started...")
LogToFile -intLogType $constDATA -strFile $strLogFile -strLogData ("Starting Parameters:
	ImportToMG: " + $blnImportToMG + "
	OnlyToFile: " + $blnOnlyToFile + "
	ScritpVerbose: " + $blnScritpVerbose + "
	ManagementServer: " + $strManagementServer + "
	ManagementPackStore: " + $strManagementPackStore + "
	ItemListFile: " + $strItemListFile)

Write-Host -ForegroundColor Yellow "##################################################################"
Write-Host -ForegroundColor Yellow ("          Starting script " + $strScriptName)
Write-Host -ForegroundColor Yellow "##################################################################"
If ($blnScritpVerbose) {
	Write-Host -ForegroundColor Yellow ("Starting Parameters:
	ImportToMG: " + $blnImportToMG + "
	OnlyToFile: " + $blnOnlyToFile + "
	ScritpVerbose: " + $blnScritpVerbose + "
	ManagementServer: " + $strManagementServer + "
	ManagementPackStore: " + $strManagementPackStore + "
	ItemListFile: " + $strItemListFile)

}

################### Check whether the script was started in SCOM shell or not ######################
If ($blnScriptVerbose) {
	Write-Host -ForegroundColor Yellow -NoNewline "`r`nInitializing Operations Manager Shell..."
}
If(-not (Get-Module | ? {$_.Name -eq "OperationsManager"})) {
	if(Get-Module -ListAvailable | ? {$_.Name -eq "OperationsManager"}) {
		Import-Module OperationsManager
		Write-Host -ForegroundColor Green "DONE!"
	} Else {
		LogToFile -intLogType $constERROR -strFile $strLogFile -strLogData "The PS Module named OperationsManager is not available on this machine. Please run the script again on a server where this module is available."
		If ($blnScriptVerbose) {
			Write-Host -ForegroundColor Red "FAIL!"
		}
		End-Script -blnWithError $True
	}
} Else {
	If ($blnScriptVerbose) {
		Write-Host -ForegroundColor Green "DONE!"
	}
}


$colItemsToOverride = Import-Csv -Path $strItemListFile -Delimiter ";"

Check-ContextAndOverridePack ([ref]$colItemsToOverride)

###################### Script Ends without error ####################################
End-Script -blnWithError $false
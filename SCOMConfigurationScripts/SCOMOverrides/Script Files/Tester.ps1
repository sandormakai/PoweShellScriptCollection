#
# Tester.ps1
#

################### Function to check combination of Name-Context-OverridePack #####################
function Check-OverridePack ($colItems, [ref]$RetrunList) {
	foreach ($objItem in $colItems) {
		[sting[]]$arrOverridePack = ($objItem.OverridePack).Split(":")
		If ($arrOverridePack[2] -eq "SEALED") {
			### Log error
		} ElseIf ($arrOverridePack[2] -eq "UNSEALED") {
			[string[]]$arrName = ($objItem.Name).Split(":")
			[string[]]$arrContext = ($objItem.Context).Split(":")
			If ($arrName[0] -like "ERROR*") {
				### Log Error
			} ElseIf ($arrContext[0] -like "ERROR*") {
				### Log error
			} Else {
				$blnNoError = $true
			}
		} Else {
			#### Log Error
		}
		If ($blnNoError) {
			If ($arrName[1] -eq "SEALED")  {
				If ($arrContext[2] -eq "SEALED") {
					### Copy record to ref list
				} ElseIf ($arrContext[2] -eq "UNSEALED") {
					switch($arrContext[1]) {
						"Class" { $strContextMPName = ((Get-SCOMClass -Name $arrContext[0]).ManagementPackName) }
						"Group" { $strContextMPName = (((Get-SCOMGroup -DisplayName $arrContext[0]).GetMostDerivedMonitoringClasses()).ManagementPackName) }
					} default { <### Log Error and break #> }
					If ($strContextMPName -eq $arrOverridePack[0]) {
						### Copy record to ref list
					} Else {
						### Log Error
					}
				}
			} ElseIf ($arrName[1] -eq "UNSEALED") {
				If ($arrContext[1] -eq "SEALED") {
					$objMonitor = Get-SCOMMonitor -Name $arrName[0]
					If (!$objMonitor) {
						$objRule = Get-SCOMRule -Name $arrName[0]
						If (!$objRule) {
							### Log error
						} Else {
							$strNameMPName = ($objRule.ManagementPackName)
						}
					} Else {
						$strNameMPName = ($Monitor.Target.Identifier.Domain[0])
					}
					If ($strNameMPName -eq $arrOverridePack[0]) {
						### Copy record to ref list
					} Else {
						### Log Error
					}
				} ElseIf ($arrContext[1] -eq "UNSEALED") {
					$objMonitor = Get-SCOMMonitor -Name $arrName[0]
					If (!$objMonitor) {
						$objRule = Get-SCOMRule -Name $arrName[0]
						If (!$objRule) {
							### Log error
						} Else {
							$strNameMPName = ($objRule.ManagementPackName)
						}
					} Else {
						$strNameMPName = ($Monitor.Target.Identifier.Domain[0])
					}
					switch($arrContext[1]) {
						"Class" { $strContextMPName = ((Get-SCOMClass -Name $arrContext[0]).ManagementPackName) }
						"Group" { $strContextMPName = (((Get-SCOMGroup -DisplayName $arrContext[0]).GetMostDerivedMonitoringClasses()).ManagementPackName) }
					} default { <### Log Error and break #> }
					If ()
				}
			}
		} Else {

		}
	}
}


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
				If ((Get-SCOMManagementPack -Name ($objMonitor.ParentMonitorID.Identifier.Domain[0])).Sealed) {  ### Check whether the item in a SEALED or UNSEALED Management Pack
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
						If ((Get-SCOMManagementPack -Name ($objMonitor.ParentMonitorID.Identifier.Domain[0])).Sealed) {  ### Check whether the item in a SEALED or UNSEALED Management Pack
							$objItem.Name = (($objItem.Name) + ":SEALED")
						} Else {
							$objItem.Name = (($objItem.Name) + ":UNSEALED")
						}
						$objTemp = Check-OverridePack -strManagementPackName (($objMonitor.ParentMonitorID.Identifier.Domain[0]) + ".Override")   ### Identifies the OverridePack
						If ($objTemp -eq "NOTEXIST") {
							$objItem.OverridePack = (($objRule.ManagementPackName) + ".Override:1.0.0.0:NOTEXIST")
						} Else {
							$objItem.OverridePack = (($objRule.ManagementPackName) + ".Override:" + $objTemp)
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
					If ((Get-SCOMManagementPack -Name ($objMonitor.ParentMonitorID.Identifier.Domain[0])).Sealed) {  ### Check whether the item in a SEALED or UNSEALED Management Pack
						$objItem.Name = (($objItem.Name) + ":SEALED")
					} Else {
						$objItem.Name = (($objItem.Name) + ":UNSEALED")
					}
					$objTemp = Check-OverridePack -strManagementPackName (($objMonitor.ParentMonitorID.Identifier.Domain[0]) + ".Override")   ### Identifies the OverridePack
					If ($objTemp -eq "NOTEXIST") {
						$objItem.OverridePack = (($objMonitor.ParentMonitorID.Identifier.Domain[0]) + ".Override:1.0.0.0:NOTEXIST")
					} Else {
						$objItem.OverridePack = (($objMonitor.ParentMonitorID.Identifier.Domain[0]) + ".Override:" + $objTemp)
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
						If ((Get-SCOMManagementPack -Name ($objMonitor.ParentMonitorID.Identifier.Domain[0])).Sealed) {  ### Check whether the item in a SEALED or UNSEALED Management Pack
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

$arrList = Import-Csv -Path D:\Temp\ManagementPacks\MonitorsToOverride.csv -Delimiter ";"


foreach ($item in $arrList) {
	Write-Host ("ItemName: " + $item.Name + "Context" + $item.Context + "Property" + $item.Property + "Value" + $item.Value + "OverridePack" + $item.OverridePack + "OverrideComment" + $item.OverrideComment + "")
}

Check-ContextAndOverridePack ([ref]$arrList)

foreach ($item in $arrList) {
	Write-Host ("ItemName: " + $item.Name + "Context" + $item.Context + "Property" + $item.Property + "Value" + $item.Value + "OverridePack" + $item.OverridePack + "OverrideComment" + $item.OverrideComment + "")
}

#
# Tester.ps1
#
$colObjects = "Buzi","vagy"
Write-Host $colObjects.GetType()

Foreach ($cucc in $colObjects) {
	Write-Host $cucc
}
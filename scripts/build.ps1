$ErrorActionPreference = "Stop"

function Get-AftmanToolPath {
	param (
		[string] $Owner,
		[string] $Tool,
		[string] $Version,
		[string] $Executable
	)

	$toolPath = Join-Path $env:USERPROFILE ".aftman\tool-storage\$Owner\$Tool\$Version\$Executable"
	if (Test-Path $toolPath) {
		return $toolPath
	}

	return $Executable
}

$rojo = Get-AftmanToolPath "rojo-rbx" "rojo" "7.7.0-rc.1" "rojo.exe"

New-Item -ItemType Directory -Force build | Out-Null
& $rojo build default.project.json --output build/RobloxItemCatalogV2.rbxlx

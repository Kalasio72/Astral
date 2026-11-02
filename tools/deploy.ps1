param([switch]$Restart)
# Déploie le contenu de server_files/ sur le serveur (chemins relatifs à garrysmod/), en UTF-8 sans BOM et fins de ligne LF.
# Usage : powershell -File tools\deploy.ps1 [-Restart]
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\panel_config.ps1"
$h = @{ Authorization = "Bearer $env:GMOD_PANEL_KEY"; Accept = 'application/json' }
$root = (Resolve-Path (Join-Path (Split-Path $PSScriptRoot -Parent) 'server_files')).Path
$utf8 = New-Object Text.UTF8Encoding $false
$files = Get-ChildItem $root -Recurse -File
foreach ($f in $files) {
	$rel = $f.FullName.Substring($root.Length + 1).Replace('\', '/')
	$text = [IO.File]::ReadAllText($f.FullName, [Text.Encoding]::UTF8).Replace("`r`n", "`n")
	Invoke-RestMethod "$PanelServerApi/files/write?file=$([uri]::EscapeDataString("/garrysmod/$rel"))" -Method Post -Headers ($h + @{ 'Content-Type' = 'text/plain; charset=utf-8' }) -Body $utf8.GetBytes($text) | Out-Null
	"envoyé : $rel"
}
"$($files.Count) fichier(s) déployé(s)."
if ($Restart) {
	$log = Join-Path $env:TEMP "astral_deploy_restart.log"
	& "$PSScriptRoot\panel_console.ps1" -Seconds 150 -Signal restart -Out $log | Out-Null
	Get-Content $log -Encoding UTF8 | Where-Object { $_ -match 'STATUS|ERROR|rror|Astral|MySQL' }
}

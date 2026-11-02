param([Parameter(Mandatory)][string[]]$Files)
# Répare sur le serveur les accents UTF-8 relus en cp1252 (ex. « Ã© » au lieu de « é »).
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\panel_config.ps1"
$h = @{ Authorization = "Bearer $env:GMOD_PANEL_KEY"; Accept = 'application/json' }
$cp = [Text.Encoding]::GetEncoding(1252)
$utf8 = [Text.Encoding]::UTF8
# Construit la table des séquences fautives à partir des lettres accentuées françaises
$letters = 'àâäçéèêëîïôöùûüÿœæÀÂÄÇÉÈÊËÎÏÔÖÙÛÜŸŒÆ«»'
$map = @{}
foreach ($c in $letters.ToCharArray()) { $map[$cp.GetString($utf8.GetBytes([string]$c))] = [string]$c }
foreach ($p in $Files) {
	$r = Invoke-WebRequest "$PanelServerApi/files/contents?file=$([uri]::EscapeDataString($p))" -Headers $h -UseBasicParsing
	$src = $utf8.GetString($r.RawContentStream.ToArray())
	$fixed = $src
	foreach ($k in $map.Keys) { $fixed = $fixed.Replace($k, $map[$k]) }
	if ($fixed -ne $src) {
		Invoke-RestMethod "$PanelServerApi/files/write?file=$([uri]::EscapeDataString($p))" -Method Post -Headers ($h + @{ 'Content-Type' = 'text/plain; charset=utf-8' }) -Body $utf8.GetBytes($fixed) | Out-Null
		"corrigé : $p"
	} else { "inchangé : $p" }
}

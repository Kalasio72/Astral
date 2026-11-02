param([Parameter(Mandatory)][string]$PatchFile)
# Applique des remplacements exacts sur des fichiers du serveur.
# $PatchFile : fichier .psd1 contenant @{ Patches = @( @{ File = '/garrysmod/...'; Old = '...'; New = '...' }, ... ) }
# Chaque Old doit apparaître exactement une fois, sinon le fichier n'est pas modifié.
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\panel_config.ps1"
$h = @{ Authorization = "Bearer $env:GMOD_PANEL_KEY"; Accept = 'application/json' }
# PowerShell 5.1 lit les fichiers sans BOM en ANSI : on passe par une copie UTF-8 avec BOM
$tmp = Join-Path $env:TEMP ("astral_patch_" + [guid]::NewGuid() + ".psd1")
[IO.File]::WriteAllText($tmp, [IO.File]::ReadAllText((Resolve-Path $PatchFile), [Text.Encoding]::UTF8), (New-Object Text.UTF8Encoding $true))
$data = Import-PowerShellDataFile $tmp
Remove-Item $tmp
$byFile = $data.Patches | Group-Object { $_.File }
foreach ($grp in $byFile) {
	$path = $grp.Name
	$r = Invoke-WebRequest "$PanelServerApi/files/contents?file=$([uri]::EscapeDataString($path))" -Headers $h -UseBasicParsing
	$src = [Text.Encoding]::UTF8.GetString($r.RawContentStream.ToArray()).Replace("`r`n", "`n")
	$ok = $true
	foreach ($p in $grp.Group) {
		$old = $p.Old.Replace("`r`n", "`n"); $new = $p.New.Replace("`r`n", "`n")
		$count = ([regex]::Matches($src, [regex]::Escape($old))).Count
		if ($count -ne 1) {
			if ($src.Contains($new)) { "DÉJÀ APPLIQUÉ  $path : $($p.Id)"; continue }
			"ÉCHEC ($count occurrences)  $path : $($p.Id)"; $ok = $false; break
		}
		$src = $src.Replace($old, $new); "OK  $path : $($p.Id)"
	}
	if ($ok) {
		Invoke-RestMethod "$PanelServerApi/files/write?file=$([uri]::EscapeDataString($path))" -Method Post -Headers ($h + @{ 'Content-Type' = 'text/plain; charset=utf-8' }) -Body ([Text.Encoding]::UTF8.GetBytes($src)) | Out-Null
	} else { "Fichier NON modifié : $path" }
}

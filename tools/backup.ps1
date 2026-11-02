param([string]$Dest = (Join-Path (Split-Path $PSScriptRoot -Parent) 'backups'))
# Sauvegarde Astral BaseWars : export JSON des tables MySQL puis archive des fichiers du serveur, téléchargée en local.
# Usage : powershell -File tools\backup.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\panel_config.ps1"
$h = @{ Authorization = "Bearer $env:GMOD_PANEL_KEY"; Accept = 'application/json' }
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
New-Item -ItemType Directory -Force $Dest | Out-Null

# 1. Script d'export présent sur le serveur (réécrit à chaque fois pour rester identique à la version locale)
$local = Join-Path (Split-Path $PSScriptRoot -Parent) 'server_files\lua\astral_tools\backup_db.lua'
$body = [Text.Encoding]::UTF8.GetBytes((Get-Content $local -Raw -Encoding UTF8).Replace("`r`n", "`n"))
Invoke-RestMethod "$PanelServerApi/files/write?file=$([uri]::EscapeDataString('/garrysmod/lua/astral_tools/backup_db.lua'))" -Method Post -Headers ($h + @{ 'Content-Type' = 'text/plain; charset=utf-8' }) -Body $body | Out-Null

# 2. Export de la base (écrit dans garrysmod/data/astral_backups/)
$log = Join-Path $env:TEMP "astral_backup_$stamp.log"
& "$PSScriptRoot\panel_console.ps1" -Seconds 10 -Command 'lua_openscript astral_tools/backup_db.lua' -Out $log | Out-Null
$result = Get-Content $log | Select-String '\[Astral Backup\]' | ForEach-Object Line
if (-not ($result -match '\[Astral Backup\] OK')) { throw "Export SQL non confirmé (serveur éteint ?) : $result" }
$result

# 3. Archive des fichiers du serveur (gamemode, addons, cfg, data, PData)
$c = Invoke-RestMethod "$PanelServerApi/files/compress" -Method Post -Headers $h -ContentType 'application/json' -Body (@{ root = '/garrysmod'; files = @('gamemodes/basewars', 'addons', 'cfg', 'data', 'sv.db') } | ConvertTo-Json) -TimeoutSec 300
$name = $c.attributes.name
$url = (Invoke-RestMethod "$PanelServerApi/files/download?file=$([uri]::EscapeDataString("/garrysmod/$name"))" -Headers $h).attributes.url
$out = Join-Path $Dest "astral_backup_$stamp.tar.gz"
Invoke-WebRequest $url -OutFile $out -UseBasicParsing -TimeoutSec 600
Invoke-RestMethod "$PanelServerApi/files/delete" -Method Post -Headers $h -ContentType 'application/json' -Body (@{ root = '/garrysmod'; files = @($name) } | ConvertTo-Json) | Out-Null
"Sauvegarde : $out ({0:N0} Ko)" -f ((Get-Item $out).Length / 1KB)

param([int]$Seconds = 120, [string]$Signal = '', [string]$Command = '', [string]$Out = "$PSScriptRoot\console.log")
# Capture la console du serveur (websocket Pterodactyl) ; option : signal d'alimentation (start/stop/restart) ou commande console.
# Clé lue dans $env:GMOD_PANEL_KEY, jamais écrite sur disque.
. "$PSScriptRoot\panel_config.ps1"
$h = @{ Authorization = "Bearer $env:GMOD_PANEL_KEY"; Accept = 'application/json' }
$ws = (Invoke-RestMethod "$PanelServerApi/websocket" -Headers $h).data
$sock = New-Object System.Net.WebSockets.ClientWebSocket
$sock.Options.SetRequestHeader('Origin', $PanelUrl)
$sock.ConnectAsync([Uri]$ws.socket, [Threading.CancellationToken]::None).Wait()
function Send($obj) { $b = [Text.Encoding]::UTF8.GetBytes(($obj | ConvertTo-Json -Compress)); $sock.SendAsync([ArraySegment[byte]]$b, 'Text', $true, [Threading.CancellationToken]::None).Wait() }
Send @{ event = 'auth'; args = @($ws.token) }
$buf = New-Object byte[] 65536; $lines = New-Object System.Collections.Generic.List[string]
$deadline = (Get-Date).AddSeconds($Seconds); $sent = $false
while ((Get-Date) -lt $deadline -and $sock.State -eq 'Open') {
  $sb = New-Object Text.StringBuilder
  do { $t = $sock.ReceiveAsync([ArraySegment[byte]]$buf, [Threading.CancellationToken]::None)
       if (-not $t.Wait([int][Math]::Max(1, ($deadline - (Get-Date)).TotalMilliseconds))) { break }
       $r = $t.Result; [void]$sb.Append([Text.Encoding]::UTF8.GetString($buf, 0, $r.Count)) } while (-not $r.EndOfMessage)
  if ($sb.Length -eq 0) { break }
  $m = $sb.ToString() | ConvertFrom-Json
  switch ($m.event) {
    'auth success' { if (-not $sent) { $sent = $true
        if ($Signal) { Send @{ event = 'set state'; args = @($Signal) } }
        if ($Command) { Send @{ event = 'send command'; args = @($Command) } } } }
    'console output' { $lines.Add(($m.args[0] -replace '\x1b\[[0-9;]*m', '')) }
    'status' { $lines.Add("### STATUS: $($m.args[0])") }
    'token expiring' { $ws = (Invoke-RestMethod "$PanelServerApi/websocket" -Headers $h).data; Send @{ event = 'auth'; args = @($ws.token) } }
  }
}
$lines | Set-Content -Encoding utf8 $Out
"{0} lignes capturées -> {1}" -f $lines.Count, $Out

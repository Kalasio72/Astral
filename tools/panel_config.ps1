# Paramètres communs des outils Astral (aucun secret ici : la clé API est dans $env:GMOD_PANEL_KEY)
$PanelUrl = 'https://panel.yorkhost.fr'
$PanelServerId = '434e787a'
$PanelServerApi = "$PanelUrl/api/client/servers/$PanelServerId"
if (-not $env:GMOD_PANEL_KEY) { throw "Variable d'environnement GMOD_PANEL_KEY absente." }

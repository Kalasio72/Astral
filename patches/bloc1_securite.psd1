@{
Patches = @(
@{ Id = 'S2 mot de passe faction masqué dans les logs'; File = '/garrysmod/gamemodes/basewars/gamemode/modules/factions/server/sv_factions.lua'
Old = '". Password: ", (password ~= "" and password or "<NONE>"), ".")'
New = '". Password: ", (password and password ~= "") and "<DÉFINI>" or "<NONE>", ".") -- Astral S2 : ne jamais journaliser le mot de passe' }

@{ Id = 'S3 vérifier le mot de passe avant de quitter sa faction'; File = '/garrysmod/gamemodes/basewars/gamemode/modules/factions/server/sv_factions.lua'
Old = '	local Lead = ply:InFaction(nil, true)
	if ply:InFaction() then
		ply:LeaveFaction(Lead)
	end
	if Faction.password and Faction.password ~= password and not force then
		ply:Notify(BaseWars.LANG.FactionWrongPass, BASEWARS_NOTIFICATION_ERROR)
		return
	end'
New = '	-- Astral S3 : le mot de passe est vérifié AVANT de quitter (sinon un chef dissout sa faction sur une erreur)
	if Faction.password and Faction.password ~= password and not force then
		ply:Notify(BaseWars.LANG.FactionWrongPass, BASEWARS_NOTIFICATION_ERROR)
		return
	end
	local Lead = ply:InFaction(nil, true)
	if ply:InFaction() then
		ply:LeaveFaction(Lead)
	end' }

@{ Id = 'S4 limite de fréquence des messages de faction'; File = '/garrysmod/gamemodes/basewars/gamemode/modules/factions/server/sv_factions.lua'
Old = 'function MODULE:HandleNetMessage(len, ply)
	local Mode = net.ReadUInt(2)'
New = 'function MODULE:HandleNetMessage(len, ply)
	-- Astral S4 : 1 action de faction toutes les 2 secondes par joueur
	local now = CurTime()
	if (ply.AstralNextFactionNet or 0) > now then return end
	ply.AstralNextFactionNet = now + 2
	local Mode = net.ReadUInt(2)' }

@{ Id = 'S5 limite de fréquence textscreens'; File = '/garrysmod/gamemodes/basewars/entities/weapons/gmod_tool/stools/textscreens.lua'
Old = '	net.Receive("textscreens_upload", function(_,ply)
		local l = net.ReadUInt(32)'
New = '	net.Receive("textscreens_upload", function(_,ply)
		-- Astral S5 : 1 enregistrement SQL toutes les 3 secondes par joueur
		local now = CurTime()
		if (ply.AstralNextTextscreenSave or 0) > now then return end
		ply.AstralNextTextscreenSave = now + 3
		local l = net.ReadUInt(32)' }

@{ Id = 'S6 SendLua (banni) remplacé par Notify'; File = '/garrysmod/gamemodes/basewars/gamemode/server/commands.lua'
Old = 'ply:SendLua(string.format([[local s = "%s" notification.AddLegacy(s, 1, 4)]], "Banned players use no commands!"))'
New = 'ply:Notify("Les joueurs bannis ne peuvent pas utiliser de commandes.", BASEWARS_NOTIFICATION_ERROR) -- Astral S6' }

@{ Id = 'S6 SendLua (raison) remplacé par Notify'; File = '/garrysmod/gamemodes/basewars/gamemode/server/commands.lua'
Old = 'ply:SendLua(string.format([[local s = "%s" notification.AddLegacy(s, 1, 4)]], reason))'
New = 'ply:Notify(tostring(reason), BASEWARS_NOTIFICATION_ERROR) -- Astral S6 : plus de code Lua construit à partir de texte' }

@{ Id = 'S6 bwa.Error remplacé par Notify'; File = '/garrysmod/gamemodes/basewars/gamemode/shared/admin.lua'
Old = '		ply:SendLua(string.format(
			"local s = ''%s'' notification.AddLegacy(s, NOTIFY_ERROR, 5) MsgN(s)",
			"bwa: " .. msg
		))'
New = '		ply:Notify("bwa: " .. tostring(msg), BASEWARS_NOTIFICATION_ERROR) -- Astral S6' }

@{ Id = 'S7 drug lab : cuisson unique, distance, drogue valide'; File = '/garrysmod/gamemodes/basewars/entities/entities/bw_druglab.lua'
Old = '    if not Ent.Status == "Press e to start cooking!" then return end
    Ent:StartCooking(net.ReadString())'
New = '    -- Astral S7 : pas de relance pendant une cuisson, joueur à proximité, drogue existante
    if Ent.Cooking then return end
    if cl:GetPos():DistToSqr(Ent:GetPos()) > 256 * 256 then return end
    local drug = net.ReadString()
    if drug == "CookTime" or not BaseWars.Config.Drugs[drug] or not (BaseWars.Drugs and BaseWars.Drugs.EffectTable and BaseWars.Drugs.EffectTable[drug]) then return end
    Ent:StartCooking(drug)' }

@{ Id = 'S8 protection des entités des coéquipiers'; File = '/garrysmod/gamemodes/basewars/gamemode/init.lua'
Old = '(not Attacker == Owner and Attacker.InFaction'
New = '(Attacker ~= Owner and Attacker.InFaction' }

@{ Id = 'S9 limite de fréquence des achats'; File = '/garrysmod/gamemodes/basewars/gamemode/shared/spawnmenu.lua'
Old = '	concommand.Add("basewars_spawn",function(ply,_,args)
		if not IsValid(ply) then return end'
New = '	concommand.Add("basewars_spawn",function(ply,_,args)
		if not IsValid(ply) then return end
		-- Astral S9 : 4 achats par seconde maximum
		local now = CurTime()
		if (ply.AstralNextBuy or 0) > now then return end
		ply.AstralNextBuy = now + 0.25' }

@{ Id = 'S11 compteur de limite nil (retrait)'; File = '/garrysmod/gamemodes/basewars/gamemode/shared/spawnmenu.lua'
Old = 'ply:GetTable()["limit_" .. ent] = ply:GetTable()["limit_" .. ent] - 1'
New = 'ply:GetTable()["limit_" .. ent] = math.max((ply:GetTable()["limit_" .. ent] or 1) - 1, 0) -- Astral S11' }

@{ Id = 'S11 compteur de limite nil (ajout)'; File = '/garrysmod/gamemodes/basewars/gamemode/shared/spawnmenu.lua'
Old = 'ply:GetTable()["limit_" .. ent] = ply:GetTable()["limit_" .. ent] + 1'
New = 'ply:GetTable()["limit_" .. ent] = (ply:GetTable()["limit_" .. ent] or 0) + 1 -- Astral S11' }
)
}

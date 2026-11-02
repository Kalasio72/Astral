-- Astral BaseWars — test de la persistance des factions avec un bot (aucun vrai joueur n'est touché).
-- Console serveur : lua_openscript astral_tools/test_factions.lua
-- Étapes : création avec mot de passe → hachage + écriture en base → contrôle du mot de passe → déconnexion du chef
-- (la faction doit rester) → reconnexion d'un bot (restauration si même SteamID64) → dissolution (marquée en base).
-- Laisse en base une faction « Astral Test Faction » marquée dissoute et quelques lignes de journal.
local NAME = "Astral Test Faction"
local FT = BaseWars.Factions.FactionTable
local AF = Astral.Factions
local db = Astral.DB.Conn()
local function out(ok, msg) print(string.format("[Astral Test] %s %s", ok and "OK   " or "ECHEC", msg)) end
if not AF or not db then return print("[Astral Test] ECHEC : module ou base absent") end
if FT[NAME] or AF.Active[NAME] then return print("[Astral Test] ECHEC : la faction de test existe déjà (relancer après redémarrage)") end

local bot = player.CreateNextBot("AstralTestFac")
local sid = bot:SteamID64()
print("[Astral Test] Bot créé, SteamID64 " .. tostring(sid))

timer.Simple(5, function()
	if not IsValid(bot) then return out(false, "bot disparu") end
	BaseWars.Factions:Create(bot, NAME, "secret12", Color(120, 200, 255))
	local fac = FT[NAME]
	out(fac ~= nil and bot:GetFaction() == NAME, "création et adhésion du chef")
	out(fac and fac.password == nil and isstring(fac.AstralHash), "mot de passe retiré de la mémoire, haché")
	local okBad = hook.Run("CanJoinFaction", bot, NAME, "mauvais")
	local okGood = hook.Run("CanJoinFaction", bot, NAME, "secret12")
	out(okBad == false and okGood == nil, "mauvais mot de passe refusé, bon accepté")
	local blocked = hook.Run("CanCreateFaction", bot, "  astral TEST faction ")
	out(blocked == nil, "nom pris détecté par SpaceVX tant que la faction est en mémoire (hook Astral neutre)")
end)

timer.Simple(8, function()
	db:FetchOne("SELECT f.leader, f.pass_hash, f.disbanded_at, m.sid64 FROM astral_factions f LEFT JOIN astral_faction_members m ON m.faction = f.name WHERE f.name = {1}", { params = { NAME }, callback = function(err, row)
		out(not err and row ~= nil and isstring(row.pass_hash) and #row.pass_hash == 64 and tostring(row.sid64) == tostring(sid), "ligne en base (hachage 64 caractères, membre = bot) " .. tostring(err or ""))
		if IsValid(bot) then bot:Kick("Test Astral : déconnexion du chef") end
	end })
end)

timer.Simple(11, function()
	out(FT[NAME] ~= nil and AF.Active[NAME] ~= nil, "faction conservée après la déconnexion du chef")
	local bot2 = player.CreateNextBot("AstralTestFac2")
	print("[Astral Test] Nouveau bot, SteamID64 " .. tostring(bot2:SteamID64()) .. (bot2:SteamID64() == sid and " (identique : test de restauration)" or " (différent : restauration non testable avec un bot)"))
	timer.Simple(6, function()
		if not IsValid(bot2) then return out(false, "bot 2 disparu") end
		if bot2:SteamID64() == sid then
			out(bot2:GetFaction() == NAME and bot2:GetNW2Bool("BaseWars.Factions.Leader"), "reconnexion : faction et rôle de chef restaurés")
		else
			BaseWars.Factions:Set(bot2, NAME, "secret12", false)
			out(bot2:GetFaction() == NAME, "adhésion avec le bon mot de passe")
			bot2:SetNW2Bool("BaseWars.Factions.Leader", true)
			FT[NAME].leader = bot2:SteamID()
		end
		BaseWars.Factions:Leave(bot2, true, true)
		out(FT[NAME] == nil and AF.Active[NAME] == nil, "dissolution")
		timer.Simple(2, function()
			db:FetchOne("SELECT disbanded_at FROM astral_factions WHERE name = {1}", { params = { NAME }, callback = function(err, row)
				out(row and tonumber(row.disbanded_at) and tonumber(row.disbanded_at) > 0, "dissolution enregistrée en base (ligne conservée)")
				if IsValid(bot2) then bot2:Kick("Fin du test Astral") end
				print("[Astral Test] Terminé")
			end })
		end)
	end)
end)

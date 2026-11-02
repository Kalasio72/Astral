-- Astral BaseWars — diagnostic : commande console « astral_diag ».
-- Utilisable depuis la console du serveur ou par un joueur ayant le privilège Astral.Diagnostics.
-- Lecture seule : n'agit sur rien, affiche l'état du socle et les éventuels points de surcharge.

local function report()
	local out = {}
	local function add(s) out[#out + 1] = s end

	add("=== Astral BaseWars " .. Astral.Version .. " — diagnostic ===")
	add(string.format("Serveur : %s | map %s | %d/%d joueurs | tickrate %d | uptime %s",
		GetHostName(), game.GetMap(), player.GetCount(), game.MaxPlayers(),
		math.Round(1 / engine.TickInterval()), string.NiceTime(math.floor(SysTime()))))

	local problems = Astral.ConfigProblems or {}
	add("Configuration : " .. (#problems == 0 and "OK" or (#problems .. " valeur(s) corrigée(s)")))
	for _, p in ipairs(problems) do add("  - " .. p) end

	local DB = Astral.DB
	add(string.format("Base : %s | schéma v%s (code v%d)%s",
		DB.Ready and "prête" or "NON PRÊTE", tostring(DB.SchemaVersion), #DB.Migrations,
		DB.LastError and (" | dernière erreur : " .. DB.LastError) or ""))

	local LS = Astral.Logs.Stats
	add(string.format("Journaux : %d en file | %d écrits | %d perdus | %d en échec | dernier envoi %s",
		#Astral.Logs.Queue, LS.written, LS.dropped, LS.failed,
		LS.lastFlush > 0 and (os.time() - LS.lastFlush .. " s") or "jamais"))

	local NS = Astral.Net.Stats
	local rejected = 0
	for _, n in pairs(NS.rejected) do rejected = rejected + n end
	add(string.format("Réseau : %d messages acceptés | %d rejetés | %d erreurs de handler", NS.accepted, rejected, NS.errors))
	for key, n in SortedPairsByValue(NS.rejected, true) do add("  - " .. key .. " : " .. n) end

	-- Entités : total, entités BaseWars et classes les plus nombreuses
	local counts, total, bw = {}, 0, 0
	for _, e in ents.Iterator() do
		total = total + 1
		local c = e:GetClass()
		if c:sub(1, 3) == "bw_" then bw = bw + 1 end
		counts[c] = (counts[c] or 0) + 1
	end
	add(string.format("Entités : %d au total | %d BaseWars", total, bw))
	local shown = 0
	for class, n in SortedPairsByValue(counts, true) do
		shown = shown + 1
		if shown > Astral.Cfg("Diagnostics.TopEntityClasses", 10) then break end
		add(string.format("  %5d  %s", n, class))
	end

	-- Entités BaseWars par joueur
	local perOwner = {}
	for _, e in ipairs(ents.FindByClass("bw_*")) do
		local o = BaseWars.CPPI.GetOwner(e)
		local k = IsValid(o) and o:Nick() or "(sans propriétaire)"
		perOwner[k] = (perOwner[k] or 0) + 1
	end
	for name, n in SortedPairsByValue(perOwner, true) do add(string.format("  %5d  bw_* de %s", n, name)) end

	add(string.format("Mémoire Lua : %.1f Mo", collectgarbage("count") / 1024))
	return out
end

Astral.Diagnostics = { Report = report }

concommand.Add("astral_diag", function(ply)
	Astral.HasAccess(ply, "Diagnostics", function(allowed)
		if not allowed then
			if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, "[Astral] Accès refusé à astral_diag.") end
			return
		end
		for _, line in ipairs(report()) do
			if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, line) else print(line) end
		end
		if IsValid(ply) then Astral.Logs.Write("diag", ply, {}) end
	end)
end)

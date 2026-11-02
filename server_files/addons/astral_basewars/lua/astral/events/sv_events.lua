-- Astral Events — moteur serveur : lancement (automatique ou admin), fin, annonce, effets, journalisation.
-- Automatique : si aucun événement depuis Events.AutoInterval secondes et au moins Events.MinPlayers joueurs connectés.
-- Les effets sont appliqués là où ils comptent (foreuse, raffinerie, fabricateur, vente, paye, tirage de minerai,
-- imprimantes, fermes, receleur). Ambiance visuelle et sonore : astral/ui/cl_events.lua.

local E = Astral.Events
E.LastEnded = E.LastEnded or CurTime()
util.AddNetworkString("Astral.EventFX")

local function announce(text)
	net.Start("Astral.Announce") net.WriteString(text) net.Broadcast()
end

local function fx(id, starting)
	net.Start("Astral.EventFX") net.WriteString(id) net.WriteBool(starting) net.Broadcast()
end

-- Spectacle de feux d'artifice au-dessus des joueurs (événement « Nuit des feux d'artifice », menu admin)
function E.FireworksShow(count)
	if not (Astral.Farms and Astral.Farms.Firework) then return end
	local players = player.GetHumans()
	for i = 1, (count or 1) do
		local ply = players[math.random(#players)]
		if IsValid(ply) then
			timer.Simple(i * 0.6, function()
				if not IsValid(ply) then return end
				local start = ply:GetPos() + Vector(math.random(-500, 500), math.random(-500, 500), 0)
				local tr = util.TraceLine({ start = start + Vector(0, 0, 40), endpos = start + Vector(0, 0, 1500), mask = MASK_SOLID_BRUSHONLY })
				if tr.HitPos.z - start.z < 400 then return end
				Astral.Farms.Firework(start, Vector(start.x, start.y, math.min(tr.HitPos.z - 60, start.z + math.random(700, 1000))))
			end)
		end
	end
end

function E.Start(id, by, duration)
	local ev = E.List[id]
	if not ev then return false, "Événement inconnu." end
	if E.Current() then return false, "Un événement est déjà en cours." end
	duration = math.Clamp(tonumber(duration) or Astral.Cfg("Events.Duration", 600), 60, 7200)
	SetGlobal2String("AstralEvent", id)
	SetGlobal2Float("AstralEventEnds", CurTime() + duration)
	announce(string.format("Événement : %s — %s (%d min)", ev.name, ev.desc, math.floor(duration / 60)))
	fx(id, true)
	E.FireworksShow(id == "fireworks_night" and 8 or 3)
	if id == "fireworks_night" then timer.Create("Astral.Events.Fireworks", 15, 0, function() E.FireworksShow(3) end) end
	Astral.Logs.Write("event_start", IsValid(by) and by or nil, { event = id, duration = duration })
	timer.Create("Astral.Events.End", duration, 1, function() E.Stop() end)
	hook.Run("Astral.EventChanged", id, true)
	return true
end

function E.Stop(by)
	local id, ev = E.Current()
	if not id then return false, "Aucun événement en cours." end
	SetGlobal2String("AstralEvent", "")
	SetGlobal2Float("AstralEventEnds", 0)
	timer.Remove("Astral.Events.End")
	timer.Remove("Astral.Events.Fireworks")
	E.LastEnded = CurTime()
	announce("Fin de l'événement : " .. ev.name)
	fx(id, false)
	Astral.Logs.Write("event_end", IsValid(by) and by or nil, { event = id })
	hook.Run("Astral.EventChanged", id, false)
	return true
end

timer.Create("Astral.Events.Auto", 60, 0, function()
	if E.Current() then return end
	if player.GetCount() < Astral.Cfg("Events.MinPlayers", 2) then return end
	if CurTime() - E.LastEnded < Astral.Cfg("Events.AutoInterval", 2700) then return end
	E.Start(E.Order[math.random(#E.Order)])
end)

-- Paye : hook officiel SpaceVX (sv_payday.lua), la valeur renvoyée remplace le montant
hook.Add("BW_PayDay", "Astral.Events", function(ply, final)
	local m = E.Mult("payday")
	if m ~= 1 then return math.floor(final * m) end
end)

concommand.Add("astral_event", function(ply, _, args)
	Astral.HasAccess(ply, "Admin", function(allowed)
		if not allowed then return end
		local ok, err
		if args[1] == "stop" then ok, err = E.Stop(ply) else ok, err = E.Start(args[1] or "", ply, args[2]) end
		local msg = ok and "OK" or err
		if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, "[Astral] " .. msg) else print("[Astral] " .. msg) end
	end)
end)

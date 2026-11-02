-- Astral BaseWars — point d'entrée unique des messages réseau client → serveur.
-- Tout module Astral reçoit ses messages via Astral.Net.Receive, qui applique AVANT le handler :
--   taille maximale, limite de fréquence par joueur (seau à jetons), joueur valide (et vivant si demandé),
--   isolation des erreurs (pcall) et journalisation des rejets.
--
-- Astral.Net.Receive("Astral.Exemple", { rate = 2, burst = 4, maxBytes = 256, alive = true }, function(ply, len) ... end)
--   rate     : messages autorisés par seconde en régime continu
--   burst    : rafale maximale (taille du seau)
--   maxBytes : taille maximale du message en octets
--   alive    : refuser si le joueur est mort

Astral.Net = Astral.Net or {}
local N = Astral.Net
N.Handlers = N.Handlers or {}
N.Stats = N.Stats or { accepted = 0, rejected = {}, errors = 0 }

local function reject(ply, name, reason)
	local key = name .. " / " .. reason
	N.Stats.rejected[key] = (N.Stats.rejected[key] or 0) + 1
	local now = CurTime()
	ply.AstralNetRejectLog = ply.AstralNetRejectLog or {}
	if (ply.AstralNetRejectLog[key] or 0) > now then return end
	ply.AstralNetRejectLog[key] = now + Astral.Cfg("Net.RejectLogInterval", 10)
	if Astral.Logs then Astral.Logs.Write("net_reject", ply, { message = name, reason = reason }) end
end

local function takeToken(ply, name, opts)
	ply.AstralNetBuckets = ply.AstralNetBuckets or {}
	local b = ply.AstralNetBuckets[name]
	local now = CurTime()
	if not b then
		b = { tokens = opts.burst, last = now }
		ply.AstralNetBuckets[name] = b
	end
	b.tokens = math.min(opts.burst, b.tokens + (now - b.last) * opts.rate)
	b.last = now
	if b.tokens < 1 then return false end
	b.tokens = b.tokens - 1
	return true
end

function N.Receive(name, opts, handler)
	assert(isstring(name) and name:sub(1, 7) == "Astral.", "Astral.Net.Receive : le nom doit commencer par Astral.")
	assert(istable(opts) and isnumber(opts.rate) and opts.rate > 0, "Astral.Net.Receive : opts.rate obligatoire")
	opts.burst = opts.burst or math.max(1, math.ceil(opts.rate))
	opts.maxBytes = opts.maxBytes or 1024
	util.AddNetworkString(name)
	N.Handlers[name] = { opts = opts, handler = handler }
	net.Receive(name, function(len, ply)
		if not IsValid(ply) then return end
		local bytes = math.ceil(len / 8)
		if bytes > opts.maxBytes then return reject(ply, name, "taille " .. bytes .. " > " .. opts.maxBytes) end
		if not takeToken(ply, name, opts) then return reject(ply, name, "fréquence") end
		if opts.alive and not ply:Alive() then return reject(ply, name, "joueur mort") end
		N.Stats.accepted = N.Stats.accepted + 1
		local ok, err = pcall(handler, ply, len)
		if not ok then
			N.Stats.errors = N.Stats.errors + 1
			ErrorNoHalt("[Astral:net] erreur dans " .. name .. " : " .. tostring(err) .. "\n")
			if Astral.Logs then Astral.Logs.Write("net_error", ply, { message = name, error = tostring(err):sub(1, 300) }) end
		end
	end)
end

hook.Add("PlayerDisconnected", "Astral.Net.Cleanup", function(ply)
	ply.AstralNetBuckets = nil
	ply.AstralNetRejectLog = nil
end)

-- Message de santé : le client envoie Astral.Ping, le serveur répond Astral.Pong avec la version du socle.
-- Sert aussi à tester la limite de fréquence (1 par seconde, rafale de 2).
util.AddNetworkString("Astral.Pong")
N.Receive("Astral.Ping", { rate = 1, burst = 2, maxBytes = 8 }, function(ply)
	net.Start("Astral.Pong")
		net.WriteString(Astral.Version)
		net.WriteUInt(N.Stats.accepted % 2 ^ 31, 32)
	net.Send(ply)
end)

-- Astral Fermes (serveur) : sac du joueur, récolte, purge, revente au receleur, feux d'artifice, sac lâché à la mort.
-- Tout est revérifié ici : propriétaire, distance, contenu réel du sac (jamais celui annoncé par le client).

local F = Astral.Farms
local MAX_DIST = 200 ^ 2

util.AddNetworkString("Astral.Farm.Open")
util.AddNetworkString("Astral.Firework")

local function encode(bag)
	local parts = {}
	for _, id in ipairs(F.ProductOrder) do if (bag[id] or 0) > 0 then parts[#parts + 1] = id .. "=" .. bag[id] end end
	return table.concat(parts, ";")
end

function F.SyncBag(ply) ply:SetNW2String("AstralBag", encode(ply.AstralBag or {})) end

-- Transfère le contenu de « from » dans le sac du joueur, dans la limite F.BagMax. Retourne le nombre d'unités prises.
function F.GiveBag(ply, from)
	ply.AstralBag = ply.AstralBag or {}
	local space, taken = F.BagMax - F.BagCount(ply.AstralBag), 0
	for _, id in ipairs(F.ProductOrder) do
		local q = math.min(from[id] or 0, space - taken)
		if q > 0 then
			ply.AstralBag[id] = (ply.AstralBag[id] or 0) + q
			from[id] = from[id] - q
			if from[id] <= 0 then from[id] = nil end
			taken = taken + q
		end
	end
	if taken > 0 then F.SyncBag(ply) end
	return taken
end

local function owns(ply, ent) return BaseWars.CPPI.GetOwner(ent) == ply end
local function near(ply, ent) return ply:GetPos():DistToSqr(ent:GetPos()) <= MAX_DIST end

-- Récolte : les lots terminés passent dans le sac (lot entier uniquement)
function F.Collect(ply, ent)
	if not (IsValid(ent) and ent.IsAstralFarm and ent.Farm and owns(ply, ent)) then return 0 end
	local def, stock = ent.Farm, ent:GetNW2Int("AstralFarmStock", 0)
	if stock <= 0 then ply:Notify("Rien à récolter pour l'instant.", BASEWARS_NOTIFICATION_ERROR) return 0 end
	local space = F.BagMax - F.BagCount(ply.AstralBag or {})
	local lots = math.min(stock, math.floor(space / def.yield))
	if lots <= 0 then ply:Notify("Ton sac est plein : va voir le receleur.", BASEWARS_NOTIFICATION_ERROR) return 0 end
	F.GiveBag(ply, { [def.product] = lots * def.yield })
	ent:SetNW2Int("AstralFarmStock", stock - lots)
	ply:EmitSound("items/ammo_pickup.wav")
	ply:Notify(string.format("+%d %s dans ton sac", lots * def.yield, F.Products[def.product].name), BASEWARS_NOTIFICATION_MONEY)
	return lots * def.yield
end

Astral.Net.Receive("Astral.Farm.Collect", { rate = 3, burst = 6, maxBytes = 8, alive = true }, function(ply)
	local ent = net.ReadEntity()
	if IsValid(ent) and near(ply, ent) then F.Collect(ply, ent) end
end)

Astral.Net.Receive("Astral.Farm.Vent", { rate = 2, burst = 4, maxBytes = 8, alive = true }, function(ply)
	local ent = net.ReadEntity()
	if not (IsValid(ent) and ent.IsAstralFarm and ent.Farm and ent.Farm.heat and owns(ply, ent) and near(ply, ent)) then return end
	ent:Vent()
end)

-- Revente au receleur
function F.Sell(ply, npc)
	if not (IsValid(npc) and npc.IsAstralNPC and npc:GetRole() == "dealer" and near(ply, npc)) then return 0 end
	local bag = ply.AstralBag or {}
	local value = math.floor(F.BagValue(bag) * (Astral.Events and Astral.Events.Mult("farm_sell") or 1))
	local count = F.BagCount(bag)
	if count <= 0 then ply:Notify("Ton sac est vide.", BASEWARS_NOTIFICATION_ERROR) return 0 end
	ply.AstralBag = {}
	F.SyncBag(ply)
	ply:GiveMoney(value)
	ply:EmitSound("mvm/mvm_money_pickup.wav")
	ply:Notify(string.format("Silas t'a payé %s pour %d unité(s).", Astral.Printers.Money(value), count), BASEWARS_NOTIFICATION_MONEY)
	Astral.Logs.Write("farm_sell", ply, { units = count, value = value })
	hook.Run("Astral.FarmSold", ply, value, count)
	return value
end

Astral.Net.Receive("Astral.Farm.Sell", { rate = 1, burst = 3, maxBytes = 8, alive = true }, function(ply)
	F.Sell(ply, net.ReadEntity())
end)

-- Feux d'artifice : effet diffusé à tous (aussi utilisé par les événements)
-- start : point de départ de la fusée ; burst : point d'explosion
function F.Firework(start, burst, hue)
	net.Start("Astral.Firework")
		net.WriteVector(start)
		net.WriteVector(burst)
		net.WriteUInt(hue or math.random(0, 359), 9)
	net.Broadcast()
end

Astral.Net.Receive("Astral.Farm.Launch", { rate = 1, burst = 2, maxBytes = 4, alive = true }, function(ply)
	local bag = ply.AstralBag or {}
	if (bag.firework or 0) <= 0 then return ply:Notify("Tu n'as pas de feu d'artifice.", BASEWARS_NOTIFICATION_ERROR) end
	if (ply.AstralNextFirework or 0) > CurTime() then return end
	ply.AstralNextFirework = CurTime() + 4
	local tr = util.TraceLine({ start = ply:EyePos(), endpos = ply:EyePos() + Vector(0, 0, 2000), filter = ply, mask = MASK_SOLID_BRUSHONLY })
	local top = tr.HitPos - Vector(0, 0, 40)
	if top.z - ply:GetPos().z < 200 then return ply:Notify("Il faut tirer en plein air.", BASEWARS_NOTIFICATION_ERROR) end
	bag.firework = bag.firework - 1
	if bag.firework <= 0 then bag.firework = nil end
	F.SyncBag(ply)
	local start = ply:GetPos() + ply:GetForward() * 40
	F.Firework(start, Vector(start.x, start.y, math.min(top.z, start.z + 900)))
	Astral.Logs.Write("firework", ply, {})
end)

-- Mort : le sac tombe au sol
hook.Add("PlayerDeath", "Astral.Farms.Drop", function(ply)
	local bag = ply.AstralBag
	if not bag or F.BagCount(bag) <= 0 then return end
	local e = ents.Create("astral_bag")
	if IsValid(e) then
		e:SetPos(ply:GetPos() + Vector(0, 0, 20))
		e:Spawn()
		e:SetContents(bag)
	end
	ply.AstralBag = {}
	F.SyncBag(ply)
end)

-- Astral Industries — transferts automatiques entre machines et vente au serveur.
--
-- Chaîne : Foreuse (AstralOut : minerais) → Raffinerie (AstralIn : minerais raffinables, AstralOut : produits)
--          → Conteneur (AstralStore : tout) → vente au serveur par le propriétaire.
-- Les échanges n'ont lieu qu'entre machines du MÊME propriétaire, à moins de Industry.TransferRadius,
-- toutes les Industry.TransferInterval secondes : une seule recherche spatiale par raffinerie/conteneur,
-- aucun calcul par image.

Astral.Industry = Astral.Industry or {}
local IND = Astral.Industry
local R, I = Astral.Resources, Astral.Inv

local function owner(ent) return BaseWars.CPPI.GetOwner(ent) end

-- Voisins du même propriétaire, filtrés par classe
local function neighbours(ent, classes)
	local own = owner(ent)
	if not IsValid(own) then return {} end
	local list = {}
	for _, v in ipairs(ents.FindInSphere(ent:GetPos(), Astral.Cfg("Industry.TransferRadius", 400))) do
		if v ~= ent and classes[v:GetClass()] and owner(v) == own then list[#list + 1] = v end
	end
	return list
end

-- Déplace au plus `room` unités de `from` vers `to`, uniquement les ressources acceptées par `accept(id)`
local function move(from, to, room, accept)
	local moved = 0
	for _, id in ipairs(R.order) do
		if room - moved <= 0 then break end
		local q = from[id]
		if q and q > 0 and accept(id) then
			local n = math.min(q, room - moved)
			I.Add(from, id, -n)
			I.Add(to, id, n)
			moved = moved + n
		end
	end
	return moved
end

local function refinable(id) local d = R.Get(id) return d and d.refinesTo ~= nil end
local function anything() return true end

local SOURCES_FOR_REFINERY = { astral_drill = true, astral_container = true }
local SOURCES_FOR_CONTAINER = { astral_drill = true, astral_refinery = true, astral_fabricator = true, astral_greenhouse = true }
local SOURCES_FOR_FABRICATOR = { astral_container = true, astral_refinery = true, astral_drill = true, astral_greenhouse = true }

-- Le fabricateur prend uniquement les ingrédients de sa recette, dans la limite de ce qu'il accepte (ENT:Wants)
local function feedFabricator(fab)
	if not fab.AstralIn or not fab.Recipe then return end
	for _, src in ipairs(neighbours(fab, SOURCES_FOR_FABRICATOR)) do
		local inv = src:GetClass() == "astral_container" and src.AstralStore or src.AstralOut
		if inv then
			local moved = 0
			for id, q in pairs(inv) do
				local want = fab:Wants(id)
				if want > 0 and q > 0 then
					local n = math.min(want, q)
					I.Add(inv, id, -n) I.Add(fab.AstralIn, id, n)
					moved = moved + n
				end
			end
			if moved > 0 then src:AstralSync() fab:AstralSync() end
		end
	end
end

function IND.TransferTick()
	-- 1) Les raffineries prennent les minerais raffinables (foreuses puis conteneurs)
	for _, ref in ipairs(ents.FindByClass("astral_refinery")) do
		local room = Astral.Cfg("Industry.RefineryBuffer", 40) - I.Count(ref.AstralIn or {})
		if room > 0 and ref.AstralIn then
			for _, src in ipairs(neighbours(ref, SOURCES_FOR_REFINERY)) do
				local inv = src:GetClass() == "astral_container" and src.AstralStore or src.AstralOut
				if inv then
					local n = move(inv, ref.AstralIn, room, refinable)
					if n > 0 then room = room - n src:AstralSync() ref:AstralSync() end
				end
				if room <= 0 then break end
			end
		end
	end
	-- 2) Les fabricateurs prennent les ingrédients de leur recette
	for _, fab in ipairs(ents.FindByClass("astral_fabricator")) do feedFabricator(fab) end
	-- 3) Les conteneurs prennent toutes les sorties (foreuses, raffineries, fabricateurs)
	for _, box in ipairs(ents.FindByClass("astral_container")) do
		local room = Astral.Cfg("Industry.ContainerCapacity", 500) + Astral.Research.Add(owner(box), "capacity") - I.Count(box.AstralStore or {})
		if room > 0 and box.AstralStore then
			for _, src in ipairs(neighbours(box, SOURCES_FOR_CONTAINER)) do
				if src.AstralOut then
					local n = move(src.AstralOut, box.AstralStore, room, anything)
					if n > 0 then room = room - n src:AstralSync() box:AstralSync() end
				end
				if room <= 0 then break end
			end
		end
	end
end

timer.Create("Astral.Industry.Transfer", Astral.Cfg("Industry.TransferInterval", 5), 0, function()
	local ok, err = pcall(IND.TransferTick)
	if not ok then ErrorNoHalt("[Astral:industry] " .. tostring(err) .. "\n") end
end)

-- Choix de recette d'un fabricateur : propriétaire, distance et recette vérifiés ici
util.AddNetworkString("Astral.Fabricator.Open")
Astral.Net.Receive("Astral.Fabricator.SetRecipe", { rate = 2, burst = 3, maxBytes = 64, alive = true }, function(ply)
	local fab = net.ReadEntity()
	local id = net.ReadString()
	if not IsValid(fab) or fab:GetClass() ~= "astral_fabricator" then return end
	if owner(fab) ~= ply or ply:GetPos():DistToSqr(fab:GetPos()) > 250 * 250 then return end
	if not Astral.Recipes.Get(id) then return end
	fab:SetRecipe(id)
	ply:Notify("Recette du fabricateur : " .. Astral.Recipes.Get(id).name, BASEWARS_NOTIFICATION_GENRL)
end)

-- Choix de culture d'une serre : propriétaire, distance et culture vérifiés ici
util.AddNetworkString("Astral.Greenhouse.Open")
Astral.Net.Receive("Astral.Greenhouse.SetCrop", { rate = 2, burst = 3, maxBytes = 64, alive = true }, function(ply)
	local gh = net.ReadEntity()
	local id = net.ReadString()
	if not IsValid(gh) or gh:GetClass() ~= "astral_greenhouse" then return end
	if owner(gh) ~= ply or ply:GetPos():DistToSqr(gh:GetPos()) > 250 * 250 then return end
	local crop = Astral.Resources.Get(id)
	if not crop or crop.kind ~= "crop" then return end
	gh:SetCrop(id)
	ply:Notify("Serre : culture « " .. crop.name .. " » plantée.", BASEWARS_NOTIFICATION_GENRL)
end)

-- Vente du contenu d'un conteneur au serveur. Vérifications côté serveur : propriétaire, distance, contenu.
function IND.SellContainer(ply, box)
	if not IsValid(box) or box:GetClass() ~= "astral_container" or not box.AstralStore then return end
	if owner(box) ~= ply then
		return ply:Notify("Seul le propriétaire peut vendre le contenu de ce conteneur.", BASEWARS_NOTIFICATION_ERROR)
	end
	if ply:GetPos():DistToSqr(box:GetPos()) > 200 * 200 then return end
	if (box.AstralNextSell or 0) > CurTime() then return end
	box.AstralNextSell = CurTime() + 1
	local value = math.floor(I.Value(box.AstralStore) * Astral.Events.Mult("sell") * Astral.Research.Mult(ply, "sell"))
	local units = I.Count(box.AstralStore)
	if units == 0 then return ply:Notify("Le conteneur est vide.", BASEWARS_NOTIFICATION_GENRL) end
	local sold = table.Copy(box.AstralStore)
	box.AstralStore = {}           -- vidé AVANT le paiement : pas de double vente possible
	box:AstralSync()
	ply:GiveMoney(value)
	ply:EmitSound("mvm/mvm_money_pickup.wav")
	ply:Notify(string.format("Vendu %d ressources pour %s%s.", units, BaseWars.LANG.CURRENCY, BaseWars.NumberFormat(value)), BASEWARS_NOTIFICATION_MONEY)
	Astral.Logs.Write("industry_sell", ply, { units = units, value = value, content = I.Encode(sold) })
	hook.Run("Astral.IndustrySold", ply, units, value)
end

-- Astral — imprimantes : modèle unifié et améliorations (partagé serveur/client).
--
-- Modèle : toutes les imprimantes SpaceVX (bw_printer_*) utilisent le même boîtier (bloc PHX 36 × 24 × 12,
-- fourni avec Garry's Mod : rien à télécharger), teint à la couleur de leur tier et habillé côté client
-- (écran, ventilateur, voyants : astral/ui/cl_printerlook.lua).
--
-- Améliorations Astral, en plus du niveau SpaceVX (production ∝ niveau^1,3) :
--   speed     Vitesse   : -10 % de temps d'impression par rang (5 rangs)
--   overclock Overclock : +25 % de production par rang, mais +50 % de consommation d'énergie par rang (3 rangs)
--   capacity  Capacité  : +50 % de stockage par rang (5 rangs)
--   armor     Blindage  : +50 % de points de vie par rang (3 rangs)
-- Coût d'un rang = coût d'amélioration de l'imprimante (UpgradeCost SpaceVX, propre à chaque tier) × facteur × rang visé.
-- Rangs stockés sur l'entité (NWInt « Astral.Upg.<id> ») : comme le niveau SpaceVX, ils disparaissent avec la machine.

Astral.Printers = Astral.Printers or {}
local P = Astral.Printers

P.Model = "models/hunter/blocks/cube05x075x025.mdl"

P.Upgrades = {
	{ id = "speed", name = "Vitesse", desc = "Imprime plus souvent", max = 5, factor = 4, step = 0.10 },
	{ id = "overclock", name = "Overclock", desc = "Plus de production, plus d'énergie consommée", max = 3, factor = 8, step = 0.25, power = 0.5 },
	{ id = "capacity", name = "Capacité", desc = "Stocke plus d'argent", max = 5, factor = 2, step = 0.50 },
	{ id = "armor", name = "Blindage", desc = "Plus de points de vie", max = 3, factor = 3, step = 0.50 },
}
-- Actions de la Banque Astral (net « Astral.Bank.Action », uint3)
P.BankActions = { collect = 1, level = 2, upgrade = 3 }

P.ById = {}
for i, u in ipairs(P.Upgrades) do u.index = i P.ById[u.id] = u end

function P.IsPrinter(ent)
	return IsValid(ent) and ent.IsPrinter and ent.GetLevel ~= nil and ent:GetClass():sub(1, 11) == "bw_printer_"
end

function P.Rank(ent, id) return ent:GetNWInt("Astral.Upg." .. id, 0) end

-- Montant au format français (même rendu que UI.Money côté client), utilisable aussi dans les notifications serveur
local function group(n)
	local s = tostring(math.floor(math.abs(n))):reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", "")
	return (n < 0 and "-" or "") .. s
end
function P.Money(n)
	n = math.floor(tonumber(n) or 0)
	local a, s = math.abs(n)
	if a < 1e6 then s = group(n)
	else
		local v, unit = n / 1e6, "M"
		if a >= 1e9 then v, unit = n / 1e9, "Md" end
		s = (math.abs(v) >= 100 and group(math.floor(v)) or string.format("%.1f", v):gsub("%.0$", ""):gsub("%.", ",")) .. " " .. unit
	end
	return BaseWars.LANG.CURRENCY .. s
end

-- Coût du prochain rang (nil si maximum atteint)
function P.Cost(ent, id)
	local u = P.ById[id]
	local r = P.Rank(ent, id)
	if not u or r >= u.max then return nil end
	return math.max(ent:GetNWInt("UpgradeCost", 1000), 1) * u.factor * (r + 1)
end

-- Multiplicateurs effectifs
function P.IntervalMul(ent) return 1 - P.ById.speed.step * P.Rank(ent, "speed") end
-- Production : overclock et événement en cours (« Frénésie d'impression », « Ruée vers l'or »)
function P.AmountMul(ent)
	local ev = Astral.Events and Astral.Events.Mult and Astral.Events.Mult("print") or 1
	return (1 + P.ById.overclock.step * P.Rank(ent, "overclock")) * ev
end
function P.PowerMul(ent) return 1 + P.ById.overclock.power * P.Rank(ent, "overclock") end
function P.CapacityMul(ent) return 1 + P.ById.capacity.step * P.Rank(ent, "capacity") end
function P.ArmorMul(ent) return 1 + P.ById.armor.step * P.Rank(ent, "armor") end

-- Capacité affichée. Côté client, la NetworkVar String « Capacity » de SpaceVX peut rester à « 0 » (constaté en jeu le
-- 2026-11-02 sur une VIP 4 : 2 750 000 000 au serveur, 0 au client) : on retombe alors sur la valeur de la classe.
function P.Capacity(ent)
	local c = tonumber(ent:GetCapacity()) or 0
	if c <= 0 then c = math.floor((ent.Capacity or 0) * P.CapacityMul(ent)) end
	return c
end

-- Production par minute (même formule que ENT:ThinkFunc de SpaceVX, avec les améliorations Astral)
function P.PerMinute(ent, level)
	local stored = scripted_ents.GetStored(ent:GetClass())
	local t = stored and stored.t or ent
	local amount = (t.PrintAmount or ent.PrintAmount or 0) * P.AmountMul(ent)
	local interval = (t.PrintInterval or ent.PrintInterval or 1) * P.IntervalMul(ent)
	return math.Round(amount * ((level or ent:GetLevel()) ^ 1.3)) * 60 / math.max(interval, 0.05)
end

-- Remplacement du modèle de toutes les imprimantes (avant toute apparition) et des icônes de la boutique
local function swapModels()
	for class, e in pairs(scripted_ents.GetList()) do
		local t = e.t
		if t and isstring(class) and class:sub(1, 11) == "bw_printer_" then
			t.AstralOriginalModel = t.AstralOriginalModel or t.Model
			t.Model = P.Model
		end
	end
	for _, items in pairs(BaseWars.SpawnList and BaseWars.SpawnList.Entities or {}) do
		for _, item in pairs(items) do
			if istable(item) and isstring(item.ClassName) and item.ClassName:sub(1, 11) == "bw_printer_" then item.Model = P.Model end
		end
	end
end
-- Les entités peuvent être enregistrées après le chargement du socle : on repasse aux étapes suivantes du démarrage
swapModels()
hook.Add("Initialize", "Astral.Printers.Models", swapModels)
hook.Add("InitPostEntity", "Astral.Printers.Models", swapModels)

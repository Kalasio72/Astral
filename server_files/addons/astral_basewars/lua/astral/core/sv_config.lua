-- Astral BaseWars — validation de la configuration au démarrage.
-- Chaque module peut déclarer ses propres règles avec Astral.ConfigRule(...) puis appeler Astral.ValidateConfig().

Astral.ConfigRules = Astral.ConfigRules or {}
Astral.ConfigProblems = {}

-- type : "number" | "boolean" | "string" ; min/max facultatifs pour les nombres ; integer = true pour un entier
function Astral.ConfigRule(path, rule)
	Astral.ConfigRules[path] = rule
end

local setPath = Astral.SetCfg

local function check(value, rule)
	if type(value) ~= rule.type then return "type " .. type(value) .. " au lieu de " .. rule.type end
	if rule.type == "number" then
		if value ~= value or value == math.huge or value == -math.huge then return "nombre invalide" end
		if rule.integer and math.floor(value) ~= value then return "doit être un entier" end
		if rule.min and value < rule.min then return "inférieur au minimum " .. rule.min end
		if rule.max and value > rule.max then return "supérieur au maximum " .. rule.max end
	end
end

-- Vérifie une valeur contre une règle ; renvoie un message d'erreur ou nil (utilisé par l'équilibrage en jeu)
Astral.CheckConfigValue = check

function Astral.ValidateConfig()
	Astral.ConfigProblems = {}
	for path, rule in SortedPairs(Astral.ConfigRules) do
		local value = Astral.Cfg(path)
		local err = check(value, rule)
		if err then
			Astral.ConfigProblems[#Astral.ConfigProblems + 1] = path .. " : " .. err .. " → défaut " .. tostring(rule.default)
			setPath(path, rule.default)
		end
	end
	for _, p in ipairs(Astral.ConfigProblems) do Astral.Log("config", "CORRIGÉ " .. p) end
	return #Astral.ConfigProblems == 0
end

Astral.ConfigRule("Logs.FlushInterval", { type = "number", min = 2, max = 300, default = 10 })
Astral.ConfigRule("Logs.MaxQueue", { type = "number", integer = true, min = 100, max = 100000, default = 2000 })
Astral.ConfigRule("Logs.BatchSize", { type = "number", integer = true, min = 1, max = 500, default = 200 })
Astral.ConfigRule("Logs.RetentionDays", { type = "number", integer = true, min = 0, max = 3650, default = 30 })
Astral.ConfigRule("Net.RejectLogInterval", { type = "number", min = 1, max = 3600, default = 10 })
Astral.ConfigRule("Diagnostics.TopEntityClasses", { type = "number", integer = true, min = 1, max = 50, default = 10 })
Astral.ConfigRule("Events.AutoInterval", { type = "number", min = 300, max = 86400, default = 2700 })
Astral.ConfigRule("Events.Duration", { type = "number", min = 60, max = 7200, default = 600 })
Astral.ConfigRule("Events.MinPlayers", { type = "number", integer = true, min = 1, max = 128, default = 2 })
Astral.ConfigRule("Economy.AlertWindow", { type = "number", min = 30, max = 86400, default = 300 })
Astral.ConfigRule("Economy.AlertGain", { type = "number", min = 1000, default = 5000000 })
Astral.ConfigRule("Industry.TransferRadius", { type = "number", min = 64, max = 2000, default = 400 })
Astral.ConfigRule("Industry.TransferInterval", { type = "number", min = 1, max = 60, default = 5 })
Astral.ConfigRule("Industry.DrillSecondsPerOre", { type = "number", min = 0.5, max = 3600, default = 6 })
Astral.ConfigRule("Industry.DrillBuffer", { type = "number", integer = true, min = 1, max = 10000, default = 40 })
Astral.ConfigRule("Industry.RefinerySecondsPerIngot", { type = "number", min = 0.5, max = 3600, default = 8 })
Astral.ConfigRule("Industry.RefineryOrePerIngot", { type = "number", integer = true, min = 1, max = 100, default = 2 })
Astral.ConfigRule("Industry.RefineryBuffer", { type = "number", integer = true, min = 1, max = 10000, default = 40 })
Astral.ConfigRule("Industry.ContainerCapacity", { type = "number", integer = true, min = 1, max = 100000, default = 500 })
Astral.ConfigRule("Market.TaxPercent", { type = "number", min = 0, max = 50, default = 5 })
Astral.ConfigRule("Market.MaxOrders", { type = "number", integer = true, min = 1, max = 50, default = 5 })
Astral.ConfigRule("Market.MinPriceFactor", { type = "number", min = 0.01, max = 1, default = 0.25 })
Astral.ConfigRule("Market.MaxPriceFactor", { type = "number", min = 1, max = 100, default = 10 })
Astral.ConfigRule("Market.MaxQty", { type = "number", integer = true, min = 1, max = 65000, default = 500 })

Astral.ValidateConfig()

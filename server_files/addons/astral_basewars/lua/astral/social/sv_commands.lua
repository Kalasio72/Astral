-- Astral — commandes de chat pour tous les joueurs (préfixe ! ou /). Également accessibles depuis le menu Tab.
--   !roll [max]           lance un dé (100 par défaut)
--   !pile                 pile ou face
--   !me <action>          action en italique (« Kalasio se gratte la tête »)
--   !donner <nom> <somme> donne de l'argent à un joueur (journalisé, 5 s entre deux dons)
--   !saluer [nom]         salue (animation) un joueur ou tout le monde
--   !danse, !rire, !applaudir, !salut, !ok    animations
--   !sac                  contenu du sac de marchandise
--   !feu                  tire un feu d'artifice (s'il y en a dans le sac)
--   !commandes            liste des commandes

util.AddNetworkString("Astral.ChatLine")

local PURPLE, BLUE, WHITE, DIM, GREEN = Color(190, 150, 255), Color(110, 205, 255), Color(232, 236, 248), Color(160, 168, 196), Color(110, 225, 150)

-- Ligne de chat colorée, à tous (targets nil) ou à certains joueurs
local function line(targets, ...)
	net.Start("Astral.ChatLine") net.WriteTable({ ... })
	if targets then net.Send(targets) else net.Broadcast() end
end
Astral.ChatLine = line

local function findPlayer(name)
	if not name or name == "" then return nil end
	name = name:lower()
	for _, p in player.Iterator() do if p:Nick():lower():find(name, 1, true) then return p end end
end

local function cooldown(ply, key, seconds)
	ply.AstralCmdCD = ply.AstralCmdCD or {}
	if (ply.AstralCmdCD[key] or 0) > CurTime() then return false end
	ply.AstralCmdCD[key] = CurTime() + seconds
	return true
end

local ACTS = { danse = "dance", rire = "laugh", applaudir = "cheer", salut = "salute", ok = "agree", saluer = "wave" }

local CMDS = {}

CMDS.roll = function(ply, args)
	if not cooldown(ply, "roll", 3) then return end
	local max = math.Clamp(math.floor(tonumber(args[1]) or 100), 2, 1000000)
	line(nil, BLUE, "[Dé] ", WHITE, ply:Nick(), DIM, " lance un dé : ", GREEN, tostring(math.random(1, max)), DIM, " / " .. max)
end

CMDS.pile = function(ply)
	if not cooldown(ply, "pile", 3) then return end
	line(nil, BLUE, "[Pièce] ", WHITE, ply:Nick(), DIM, " lance une pièce : ", GREEN, math.random(2) == 1 and "pile" or "face")
end

CMDS.me = function(ply, args, raw)
	if not cooldown(ply, "me", 2) then return end
	local text = raw:Trim():sub(1, 160)
	if text == "" then return end
	line(nil, PURPLE, "* " .. ply:Nick() .. " " .. text)
end

CMDS.donner = function(ply, args)
	local target, amount = findPlayer(args[1]), math.floor(tonumber(args[2]) or 0)
	if not IsValid(target) or target == ply then return line(ply, DIM, "Usage : !donner <nom> <somme>") end
	if amount < 1 then return line(ply, DIM, "Somme invalide.") end
	if amount > ply:GetMoney() then return line(ply, DIM, "Tu n'as pas assez d'argent.") end
	if not cooldown(ply, "donner", 5) then return line(ply, DIM, "Attends quelques secondes entre deux dons.") end
	ply:TakeMoney(amount)
	target:GiveMoney(amount)
	Astral.Logs.Write("money_transfer", ply, { to = Astral.PlayerID(target), amount = amount, via = "!donner" })
	line(ply, GREEN, "Tu as donné " .. Astral.Printers.Money(amount) .. " à " .. target:Nick() .. ".")
	line(target, GREEN, ply:Nick() .. " t'a donné " .. Astral.Printers.Money(amount) .. " !")
	target:EmitSound("mvm/mvm_money_pickup.wav")
end

CMDS.saluer = function(ply, args)
	if not cooldown(ply, "act", 3) then return end
	ply:ConCommand("act wave")
	local target = findPlayer(args[1])
	if IsValid(target) and target ~= ply then
		line(nil, BLUE, "[Salut] ", WHITE, ply:Nick(), DIM, " salue ", WHITE, target:Nick())
	else
		line(nil, BLUE, "[Salut] ", WHITE, ply:Nick(), DIM, " salue tout le monde")
	end
end

for cmd, act in pairs(ACTS) do
	if not CMDS[cmd] then
		CMDS[cmd] = function(ply)
			if not cooldown(ply, "act", 3) then return end
			ply:ConCommand("act " .. act)
		end
	end
end

CMDS.sac = function(ply)
	local F = Astral.Farms
	local bag = ply.AstralBag or {}
	if F.BagCount(bag) == 0 then return line(ply, DIM, "Ton sac est vide.") end
	local parts = {}
	for _, id in ipairs(F.ProductOrder) do if bag[id] then parts[#parts + 1] = F.Products[id].name .. " × " .. bag[id] end end
	line(ply, BLUE, "Sac : ", WHITE, table.concat(parts, ", "), DIM, "  (" .. Astral.Printers.Money(F.BagValue(bag)) .. " chez le receleur)")
end

CMDS.feu = function(ply)
	-- Même traitement que le bouton du receleur (sv_farms.lua)
	local h = Astral.Net and Astral.Net.Handlers and Astral.Net.Handlers["Astral.Farm.Launch"]
	if h then h.handler(ply) end
end

CMDS.commandes = function(ply)
	line(ply, BLUE, "Commandes : ", WHITE, "!roll [max]  !pile  !me <action>  !donner <nom> <somme>  !saluer [nom]  !danse  !rire  !applaudir  !salut  !ok  !sac  !feu")
end
CMDS.aide = CMDS.commandes

hook.Add("PlayerSay", "Astral.Commands", function(ply, text)
	local prefix, cmd, rest = text:match("^([!/])(%a+)%s*(.*)$")
	if not prefix then return end
	local fn = CMDS[cmd:lower()]
	if not fn then return end
	local args = string.Explode(" ", rest)
	fn(ply, args, rest)
	Astral.Logs.Write("fun_command", ply, { cmd = cmd:lower() })
	return ""
end)

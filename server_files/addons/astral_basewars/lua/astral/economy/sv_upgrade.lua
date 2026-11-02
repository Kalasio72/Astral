-- Amélioration des machines depuis l'interface Astral (Maj + E sur sa machine, voir astral/ui/cl_upgrade.lua).
-- Réutilise ENT:Upgrade de SpaceVX : mêmes coûts (coût de base × niveau), même plafond, même gain que /upg et /maxupg.
-- Contrôles serveur : machine valide et améliorable, appartenant au joueur, à portée, joueur vivant, fréquence limitée.

local MAX_DIST = 200 ^ 2
local COUNTS = { [1] = true, [5] = true, [255] = true }   -- 255 = jusqu'au niveau maximum

local function upgradable(ent)
	return IsValid(ent) and isfunction(ent.Upgrade) and ent.GetLevel and ent.MaxLevel
end

Astral.Upgrade = Astral.Upgrade or {}

-- Retourne le nombre de niveaux gagnés (0 si refusé)
function Astral.Upgrade.Do(ply, ent, count)
	if not COUNTS[count] or not upgradable(ent) then return 0 end
	local owner = ent.CPPIGetOwner and ent:CPPIGetOwner()
	if owner ~= ply then ply:Notify("Cette machine ne t'appartient pas.", BASEWARS_NOTIFICATION_ERROR) return 0 end
	if ply:GetPos():DistToSqr(ent:GetPos()) > MAX_DIST then ply:Notify("Approche-toi de la machine.", BASEWARS_NOTIFICATION_ERROR) return 0 end

	local before, spentBefore = ent:GetLevel(), ply:GetMoney()
	for i = 1, math.min(count, ent.MaxLevel) do
		-- Premier essai : message d'erreur SpaceVX si refus (argent, niveau max) ; suivants : silencieux
		if ent:Upgrade(ply, i > 1) == false then break end
	end
	local gained = ent:GetLevel() - before
	if gained <= 0 then return 0 end
	local spent = spentBefore - ply:GetMoney()
	ply:Notify(string.format("Machine améliorée : niveau %d → %d (%s)", before, ent:GetLevel(), BaseWars.LANG.CURRENCY .. BaseWars.NumberFormat(spent)), BASEWARS_NOTIFICATION_MONEY)
	Astral.Logs.Write("upgrade", ply, { class = ent:GetClass(), from = before, to = ent:GetLevel(), cost = spent })
	return gained
end

Astral.Net.Receive("Astral.Upgrade", { rate = 2, burst = 4, maxBytes = 8, alive = true }, function(ply)
	Astral.Upgrade.Do(ply, net.ReadEntity(), net.ReadUInt(8))
end)

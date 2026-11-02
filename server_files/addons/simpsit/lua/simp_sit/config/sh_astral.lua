-- Ajout Astral (ne fait pas partie de SIMPSit d'origine) : règles anti-abus pour BaseWars.
-- On peut s'asseoir par terre et sur ses propres props, pas sur les props ou machines d'un autre joueur
-- (sinon un siège attaché au prop d'une base permet d'y entrer).
if not SERVER then return end

hook.Add("ShouldAllowSit", "Astral.SitRules", function(ply, pos, pitch, ent)
	if not IsValid(ent) or ent:IsWorld() then return end
	local owner = ent.CPPIGetOwner and ent:CPPIGetOwner()
	if IsValid(owner) and owner ~= ply then return false end
	if ent:GetClass():find("^bw_") and owner ~= ply then return false end
end)

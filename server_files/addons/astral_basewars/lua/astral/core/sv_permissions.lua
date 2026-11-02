-- Astral BaseWars — permissions administratives via CAMI (géré par ULX sur ce serveur).
-- Les privilèges apparaissent dans ULX (onglet Groupes) et peuvent y être accordés à d'autres rangs.

Astral.Privileges = {
	Admin = { Name = "Astral.Admin", MinAccess = "superadmin", Description = "Administration des systèmes Astral" },
	Diagnostics = { Name = "Astral.Diagnostics", MinAccess = "admin", Description = "Commande astral_diag" },
	Logs = { Name = "Astral.Logs", MinAccess = "admin", Description = "Consultation des journaux Astral" },
}

for _, priv in pairs(Astral.Privileges) do
	if CAMI and CAMI.RegisterPrivilege then CAMI.RegisterPrivilege(priv) end
end

-- Astral.HasAccess(ply, "Diagnostics", function(allowed) ... end)
-- La console du serveur (ply invalide) a toujours accès. Sans CAMI, on retombe sur le rang minimal déclaré.
function Astral.HasAccess(ply, key, callback)
	local priv = Astral.Privileges[key]
	if not priv then return callback(false) end
	if not IsValid(ply) then return callback(true) end
	if CAMI and CAMI.PlayerHasAccess then
		return CAMI.PlayerHasAccess(ply, priv.Name, function(allowed) callback(allowed == true) end)
	end
	if priv.MinAccess == "superadmin" then return callback(ply:IsSuperAdmin()) end
	callback(ply:IsAdmin())
end

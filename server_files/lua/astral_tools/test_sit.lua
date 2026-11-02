-- Diagnostic des sièges (SIMPSit) pour le premier joueur connecté. Lecture seule, sauf le test final « sit ».
-- Console serveur : lua_openscript astral_tools/test_sit.lua
for _, p in ipairs(player.GetHumans()) do print("[Astral Test] joueur", p:Nick(), p:SteamID64(), tostring(p:GetPos())) end
local ply = player.GetBySteamID64("76561198150326843") or player.GetHumans()[1]
if not IsValid(ply) then return print("[Astral Test] aucun joueur") end
local fn = concommand.GetTable()["sit"]
local i = fn and debug.getinfo(fn, "S")
print("[Astral Test] commande sit :", i and (i.short_src .. ":" .. i.linedefined) or "absente")
local tr = ply:GetEyeTrace()
local pitch = (tr.HitNormal:Angle() - Angle(270, 0, 0)).pitch
print("[Astral Test] visée", tostring(ply:EyeAngles()), "distance²", math.Round(ply:GetPos():DistToSqr(tr.HitPos)), "pitch", pitch, "entité", tostring(tr.Entity))
print("[Astral Test] position", tostring(ply:GetPos()), "au sol", ply:IsOnGround(), "noclip", ply:GetMoveType() == MOVETYPE_NOCLIP, "vise", tostring(tr.HitPos))
local ok, rot =SIMPSit.Core.CanSitHere(ply, tr.HitPos, pitch, tr.Entity)
print("[Astral Test] CanSitHere :", ok, rot)

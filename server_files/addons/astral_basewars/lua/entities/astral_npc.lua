-- PNJ Astral : remplace les PNJ « Help and Info » de SpaceVX (bw_npc, en tenue de médecin) par des PNJ à rôle :
--   guide   : aide, règles, raccourcis, commandes
--   quests  : quêtes journalières et hebdomadaires, classements
--   dealer  : receleur, rachète les produits des fermes Astral (astral/farms)
-- Placement : astral/world/sv_npcs.lua. Boîte de dialogue : astral/ui/cl_npcs.lua.
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "PNJ Astral"
ENT.Author = "Astral"
ENT.Spawnable = false
ENT.AutomaticFrameAdvance = true
ENT.IsAstralNPC = true

ENT.Roles = {
	guide  = { name = "Ava", role = "Guide d'Astral", model = "models/mossman.mdl", color = Color(110, 205, 255) },
	quests = { name = "Barney", role = "Quêtes et classements", model = "models/barney.mdl", color = Color(170, 130, 255) },
	dealer = { name = "Silas", role = "Receleur", model = "models/odessa.mdl", color = Color(255, 150, 80) },
}

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "Role")
end

function ENT:RoleInfo() return self.Roles[self:GetRole()] or self.Roles.guide end

if SERVER then
	util.AddNetworkString("Astral.NPC.Open")

	function ENT:Initialize()
		local info = self:RoleInfo()
		self:SetModel(info.model)
		self:SetSolid(SOLID_BBOX)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetCollisionBounds(Vector(-14, -14, 0), Vector(14, 14, 74))
		self:SetUseType(SIMPLE_USE)
		for _, s in ipairs({ "idle_subtle", "lineidle02", "idle_all_01", "idle01" }) do
			local seq = self:LookupSequence(s)
			if seq and seq > 0 then self.IdleSeq = seq break end
		end
		self.IdleSeq = self.IdleSeq or 0
		self:ResetSequence(self.IdleSeq)
	end

	function ENT:Use(ply)
		if not IsValid(ply) or not ply:IsPlayer() then return end
		if (ply.AstralNextNPC or 0) > CurTime() then return end
		ply.AstralNextNPC = CurTime() + 0.8
		net.Start("Astral.NPC.Open") net.WriteEntity(self) net.Send(ply)
		self:EmitSound("vo/npc/" .. (self:GetRole() == "guide" and "female01" or "male01") .. "/hi0" .. math.random(1, 2) .. ".wav", 60)
	end

	function ENT:Think()
		if self:GetSequence() ~= self.IdleSeq then self:ResetSequence(self.IdleSeq) end
		self:NextThink(CurTime() + 1)
		return true
	end

	-- Indestructible
	function ENT:OnTakeDamage() return 0 end
	return
end

---------------------------------------------------------------------------
-- Client : plaque holographique au-dessus de la tête et anneau lumineux au sol
---------------------------------------------------------------------------
surface.CreateFont("Astral.NPC.Name", { font = "Roboto", size = 64, weight = 900, extended = true })
surface.CreateFont("Astral.NPC.Role", { font = "Roboto", size = 34, weight = 700, extended = true })
surface.CreateFont("Astral.NPC.Hint", { font = "Roboto", size = 28, weight = 800, extended = true })

function ENT:Draw()
	self:DrawModel()
	local eye = EyePos()
	local d = eye:Distance(self:GetPos())
	if d > 700 then return end
	local a = math.Clamp((700 - d) / 150, 0, 1)
	local info = self:RoleInfo()
	local col = info.color
	local t = RealTime()

	-- Anneau au sol
	cam.Start3D2D(self:GetPos() + Vector(0, 0, 1), Angle(0, 0, 0), 0.1)
		for k = 0, 1 do
			local p = (t * 0.4 + k * 0.5) % 1
			local r = 160 + p * 120
			draw.RoundedBox(r, -r, -r, r * 2, r * 2, Color(col.r, col.g, col.b, 70 * (1 - p) * a))
		end
		draw.RoundedBox(170, -170, -170, 340, 340, Color(col.r, col.g, col.b, 40 * a))
	cam.End3D2D()

	-- Plaque face au joueur
	local pos = self:GetPos() + Vector(0, 0, 84 + math.sin(t * 1.5) * 1.2)
	local ang = Angle(0, (eye - pos):Angle().y + 90, 90)
	cam.Start3D2D(pos, ang, 0.05)
		surface.SetFont("Astral.NPC.Name")
		local nw = surface.GetTextSize(info.name)
		surface.SetFont("Astral.NPC.Role")
		local rw = surface.GetTextSize(info.role)
		local w = math.max(nw, rw) + 120
		draw.RoundedBox(24, -w / 2, -150, w, 160, Color(10, 13, 26, 220 * a))
		draw.RoundedBoxEx(24, -w / 2, -150, w, 10, Color(col.r, col.g, col.b, 255 * a), true, true, false, false)
		draw.SimpleText(info.name, "Astral.NPC.Name", 0, -132, Color(232, 236, 248, 255 * a), TEXT_ALIGN_CENTER)
		draw.SimpleText(info.role, "Astral.NPC.Role", 0, -62, Color(col.r, col.g, col.b, 255 * a), TEXT_ALIGN_CENTER)
		if d < 160 then
			local pulse = 0.6 + 0.4 * math.sin(t * 4)
			draw.RoundedBox(16, -110, 26, 220, 50, Color(col.r, col.g, col.b, 60 * pulse * a))
			draw.SimpleText("E  ·  Parler", "Astral.NPC.Hint", 0, 51, Color(255, 255, 255, 255 * a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	cam.End3D2D()
end

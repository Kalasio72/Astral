-- Sac de marchandise lâché à la mort d'un joueur (astral/farms/sv_farms.lua). E : le ramasser (dans la limite
-- du sac). Disparaît au bout de 10 minutes.
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Sac de marchandise"
ENT.Spawnable = false

if SERVER then
	function ENT:Initialize()
		self:SetModel("models/props_c17/BriefCase001a.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)
		self:PhysWake()
		self.Contents = self.Contents or {}
		timer.Simple(600, function() if IsValid(self) then self:Remove() end end)
	end

	function ENT:SetContents(bag)
		self.Contents = table.Copy(bag)
		self:SetNW2Int("AstralBagCount", Astral.Farms.BagCount(bag))
		self:SetNW2Int("AstralBagValue", Astral.Farms.BagValue(bag))
	end

	function ENT:Use(ply)
		if not IsValid(ply) or not ply:IsPlayer() then return end
		local taken = Astral.Farms.GiveBag(ply, self.Contents)
		if taken > 0 then
			ply:EmitSound("items/ammo_pickup.wav")
			ply:Notify(string.format("Tu as ramassé %d unité(s) de marchandise.", taken), BASEWARS_NOTIFICATION_MONEY)
		else
			ply:Notify("Ton sac est plein.", BASEWARS_NOTIFICATION_ERROR)
		end
		if Astral.Farms.BagCount(self.Contents) <= 0 then self:Remove() else self:SetContents(self.Contents) end
	end
	return
end

surface.CreateFont("Astral.Bag.Text", { font = "Roboto", size = 34, weight = 800, extended = true })

function ENT:Draw()
	self:DrawModel()
	local d = EyePos():Distance(self:GetPos())
	if d > 400 then return end
	local pos = self:GetPos() + Vector(0, 0, 22 + math.sin(RealTime() * 2) * 1.5)
	local ang = Angle(0, (EyePos() - pos):Angle().y + 90, 90)
	cam.Start3D2D(pos, ang, 0.05)
		local txt = "Sac : " .. self:GetNW2Int("AstralBagCount", 0) .. " u.  ·  " .. Astral.UI.Money(self:GetNW2Int("AstralBagValue", 0))
		surface.SetFont("Astral.Bag.Text")
		local w = surface.GetTextSize(txt) + 50
		draw.RoundedBox(16, -w / 2, -40, w, 60, Color(10, 13, 26, 220))
		draw.RoundedBoxEx(16, -w / 2, -40, w, 6, Color(255, 150, 80), true, true, false, false)
		draw.SimpleText(txt, "Astral.Bag.Text", 0, -8, Color(232, 236, 248), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	cam.End3D2D()
end

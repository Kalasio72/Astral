-- Astral Farming — Serre : fait pousser la culture choisie (E, propriétaire) tant qu'elle est alimentée (éclairage).
-- Croissance calculée à partir du temps écoulé à chaque réflexion (une par seconde), sans timer par plante.
-- Les récoltes partent automatiquement vers les conteneurs du propriétaire ; replantation automatique.
AddCSLuaFile()

ENT.Base = "bw_base_electronics"
ENT.Type = "anim"
ENT.PrintName = "Serre hydroponique"
ENT.Model = "models/props_c17/display_cooler01a.mdl"
ENT.PresetMaxHealth = 350
ENT.PowerRequired = 8
ENT.PowerCapacity = 2000
ENT.ThinkPeriods = 5
ENT.IsAstralMachine = true
ENT.OutputCap = 30

if SERVER then
	function ENT:Init()
		self.AstralOut = {}
		self.growth = 0
		self.lastThink = CurTime()
		self.Crop = nil
		self:SetNW2String("AstralCrop", "")
		self:AstralSync()
	end

	function ENT:AstralSync()
		self:SetNW2String("AstralInv", Astral.Inv.Encode(self.AstralOut))
	end

	function ENT:SetCrop(id)
		local crop = Astral.Resources.Get(id)
		if not crop or crop.kind ~= "crop" then return end
		self.Crop, self.growth = id, 0
		self:SetNW2String("AstralCrop", id)
	end

	function ENT:ThinkFuncBypass()
		local now = CurTime()
		self.dt = math.min(now - (self.lastThink or now), 5)
		self.lastThink = now
		if not self:IsPowered() then self:SetNW2String("AstralStatus", "Hors tension (lumière éteinte)") end
	end

	function ENT:ThinkFunc()
		local crop = self.Crop and Astral.Resources.Get(self.Crop)
		if not crop then self:SetNW2String("AstralStatus", "Choisis une culture (E)") return end
		if Astral.Inv.Count(self.AstralOut) >= self.OutputCap then self:SetNW2String("AstralStatus", "Récolte en attente (stock plein)") return end
		self.growth = self.growth + (self.dt or 0) / crop.grow
		if self.growth >= 1 then
			self.growth = 0
			Astral.Inv.Add(self.AstralOut, self.Crop, crop.yield)
			self:AstralSync()
			hook.Run("Astral.Produced", self, "harvest", crop.yield)
			self:EmitSound("physics/cardboard/cardboard_box_impact_soft2.wav", 60)
		end
		self:SetNW2String("AstralStatus", string.format("%s : croissance %d %%", crop.name, math.floor(self.growth * 100)))
	end

	function ENT:UseFuncBypass(activator)
		if not IsValid(activator) or not activator:IsPlayer() then return end
		if BaseWars.CPPI.GetOwner(self) ~= activator then
			return activator:Notify("Seul le propriétaire peut choisir la culture de cette serre.", BASEWARS_NOTIFICATION_ERROR)
		end
		if (self.NextMenu or 0) > CurTime() then return end
		self.NextMenu = CurTime() + 0.5
		net.Start("Astral.Greenhouse.Open") net.WriteEntity(self) net.Send(activator)
	end
else
	function ENT:Draw()
		self:DrawModel()
		if Astral.DrawMachinePanel then
			Astral.DrawMachinePanel(self, self.PrintName, self:GetNW2String("AstralStatus", ""), Astral.Inv.Decode(self:GetNW2String("AstralInv", "")))
		end
	end
end

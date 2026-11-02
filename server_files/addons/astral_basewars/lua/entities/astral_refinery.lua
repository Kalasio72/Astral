-- Astral Industries — Raffinerie : transforme Industry.RefineryOrePerIngot minerais en 1 produit de plus grande valeur.
-- Reçoit ses minerais automatiquement des foreuses et conteneurs du même propriétaire (voir sv_industry.lua).
AddCSLuaFile()

ENT.Base = "bw_base_electronics"
ENT.Type = "anim"
ENT.PrintName = "Raffinerie"
ENT.Model = "models/props_c17/FurnitureBoiler001a.mdl"
ENT.PresetMaxHealth = 500
ENT.PowerRequired = 15
ENT.PowerCapacity = 3000
ENT.ThinkPeriods = 5
ENT.IsAstralMachine = true

if SERVER then
	function ENT:Init()
		self.AstralIn = {}
		self.AstralOut = {}
		self.progress = 0
		self.lastThink = CurTime()
		self:AstralSync()
	end

	function ENT:AstralSync()
		local view = table.Copy(self.AstralIn)
		for id, q in pairs(self.AstralOut) do Astral.Inv.Add(view, id, q) end
		self:SetNW2String("AstralInv", Astral.Inv.Encode(view))
	end

	function ENT:ThinkFuncBypass()
		local now = CurTime()
		self.dt = math.min(now - (self.lastThink or now), 5)
		self.lastThink = now
		if not self:IsPowered() then self:SetNW2String("AstralStatus", "Hors tension") end
	end

	-- Minerai raffinable le plus abondant, s'il y en a assez pour un cycle
	function ENT:PickOre()
		local need = Astral.Cfg("Industry.RefineryOrePerIngot", 2)
		local best, bestQ
		for id, q in pairs(self.AstralIn) do
			local def = Astral.Resources.Get(id)
			if def and def.refinesTo and q >= need and (not bestQ or q > bestQ) then best, bestQ = id, q end
		end
		return best
	end

	function ENT:ThinkFunc()
		if Astral.Inv.Count(self.AstralOut) >= Astral.Cfg("Industry.RefineryBuffer", 40) then
			self:SetNW2String("AstralStatus", "Sortie pleine")
			return
		end
		local ore = self:PickOre()
		if not ore then
			self.progress = 0
			self:SetNW2String("AstralStatus", "En attente de minerai")
			return
		end
		self.progress = self.progress + (self.dt or 0) / Astral.Cfg("Industry.RefinerySecondsPerIngot", 8) * Astral.Events.Mult("refine") * Astral.Research.Mult(BaseWars.CPPI.GetOwner(self), "refine")
		if self.progress >= 1 then
			self.progress = 0
			Astral.Inv.Add(self.AstralIn, ore, -Astral.Cfg("Industry.RefineryOrePerIngot", 2))
			Astral.Inv.Add(self.AstralOut, Astral.Resources.Get(ore).refinesTo, 1)
			self:AstralSync()
			hook.Run("Astral.Produced", self, "refine", 1)
		end
		self:SetNW2String("AstralStatus", string.format("Raffinage %s… %d %%", Astral.Resources.Get(ore).name, math.floor(self.progress * 100)))
	end
else
	function ENT:Draw()
		self:DrawModel()
		if Astral.DrawMachinePanel then
			Astral.DrawMachinePanel(self, self.PrintName, self:GetNW2String("AstralStatus", ""), Astral.Inv.Decode(self:GetNW2String("AstralInv", "")))
		end
	end
end

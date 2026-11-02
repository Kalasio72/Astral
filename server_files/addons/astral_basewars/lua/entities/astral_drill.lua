-- Astral Industries — Foreuse : extrait des minerais aléatoires tant qu'elle est alimentée.
-- Hérite de bw_base_electronics : santé, consommation d'énergie, explosion et remboursement à la destruction.
AddCSLuaFile()

ENT.Base = "bw_base_electronics"
ENT.Type = "anim"
ENT.PrintName = "Foreuse"
ENT.Model = "models/props_c17/TrapPropeller_Engine.mdl"
ENT.PresetMaxHealth = 400
ENT.PowerRequired = 10
ENT.PowerCapacity = 2000
ENT.ThinkPeriods = 5 -- une réflexion par seconde
ENT.IsAstralMachine = true

if SERVER then
	function ENT:Init()
		self.AstralOut = {}
		self.progress = 0
		self.lastThink = CurTime()
		self:AstralSync()
	end

	function ENT:AstralSync()
		self:SetNW2String("AstralInv", Astral.Inv.Encode(self.AstralOut))
	end

	-- Appelée à chaque réflexion, alimentée ou non : mesure le temps écoulé
	function ENT:ThinkFuncBypass()
		local now = CurTime()
		self.dt = math.min(now - (self.lastThink or now), 5)
		self.lastThink = now
		if not self:IsPowered() then self:SetNW2String("AstralStatus", "Hors tension") end
	end

	-- Appelée seulement si la machine est alimentée et en bon état
	function ENT:ThinkFunc()
		local cap = Astral.Cfg("Industry.DrillBuffer", 40)
		if Astral.Inv.Count(self.AstralOut) >= cap then
			self:SetNW2String("AstralStatus", "Stock plein")
			return
		end
		self.progress = self.progress + (self.dt or 0) / Astral.Cfg("Industry.DrillSecondsPerOre", 6) * Astral.Events.Mult("drill") * Astral.Research.Mult(BaseWars.CPPI.GetOwner(self), "drill")
		local produced = false
		while self.progress >= 1 and Astral.Inv.Count(self.AstralOut) < cap do
			self.progress = self.progress - 1
			Astral.Inv.Add(self.AstralOut, Astral.Resources.RandomOre(Astral.Research.Mult(BaseWars.CPPI.GetOwner(self), "rare")), 1)
			produced = true
		end
		self:SetNW2String("AstralStatus", string.format("Extraction… %d %%", math.floor(self.progress * 100)))
		if produced then self:AstralSync() end
	end
else
	function ENT:Draw()
		self:DrawModel()
		if Astral.DrawMachinePanel then
			Astral.DrawMachinePanel(self, self.PrintName, self:GetNW2String("AstralStatus", ""), Astral.Inv.Decode(self:GetNW2String("AstralInv", "")))
		end
	end
end

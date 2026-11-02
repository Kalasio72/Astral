-- Astral Energy — Batterie : stocke l'énergie reçue des générateurs (système Power de SpaceVX) et la redistribue
-- aux machines électriques du même propriétaire qui en manquent, dans un rayon de 400 unités.
-- Utile pour lisser les pics de consommation et garder une base alimentée si un générateur est détruit.
AddCSLuaFile()

ENT.Base = "bw_base_electronics"
ENT.Type = "anim"
ENT.PrintName = "Batterie Astral"
ENT.Model = "models/props_lab/powerbox01a.mdl"
ENT.PresetMaxHealth = 300
ENT.PowerRequired = 0       -- ne consomme rien elle-même
ENT.PowerCapacity = 25000
ENT.ThinkPeriods = 5        -- une fois par seconde
ENT.IsAstralMachine = true
ENT.IsAstralBattery = true
ENT.DischargeRate = 200     -- énergie redistribuée par seconde au maximum
ENT.Radius = 400

if SERVER then
	function ENT:Init()
		self:SetNW2String("AstralInv", "")
	end

	function ENT:ThinkFunc()
		local stored = self:GetPower()
		local rate = self.DischargeRate * Astral.Research.Mult(BaseWars.CPPI.GetOwner(self), "discharge")
		local budget = math.min(stored, rate)
		local owner = BaseWars.CPPI.GetOwner(self)
		if budget > 0 and IsValid(owner) then
			for _, v in ipairs(ents.FindInSphere(self:GetPos(), self.Radius)) do
				if budget <= 0 then break end
				if v ~= self and v.IsElectronic and not v.IsAstralBattery and not v.IsGenerator
					and BaseWars.CPPI.GetOwner(v) == owner and v.GetMaxPower then
					local need = v:GetMaxPower() - v:GetPower()
					if need > 0 then
						local give = math.min(need, budget)
						v:ReceivePower(give)
						budget = budget - give
					end
				end
			end
			local used = math.min(stored, rate) - budget
			if used > 0 then self:SetPower(stored - used) end
		end
		local pct = math.floor(self:GetPower() / self:GetMaxPower() * 100)
		self:SetNW2String("AstralStatus", string.format("Charge %d %% — redistribution %d/s", pct, self.DischargeRate))
	end
else
	function ENT:Draw()
		self:DrawModel()
		if Astral.DrawMachinePanel then Astral.DrawMachinePanel(self, self.PrintName, self:GetNW2String("AstralStatus", ""), {}) end
	end
end

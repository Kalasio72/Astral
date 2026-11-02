-- Astral Fermes — base commune des machines de production (définitions : astral/farms/sh_farms.lua).
-- Production calculée à partir du temps écoulé (comme la serre), lots stockés dans la machine.
-- E (propriétaire) : menu ; Maj + E : tout mettre dans le sac (astral/ui/cl_farms.lua, astral/farms/sv_farms.lua).
AddCSLuaFile()

ENT.Base = "bw_base_electronics"
ENT.Type = "anim"
ENT.PrintName = "Ferme Astral"
ENT.Model = "models/hunter/blocks/cube05x1x05.mdl"
ENT.PowerRequired = 6
ENT.PowerCapacity = 2000
ENT.ThinkPeriods = 2
ENT.PresetMaxHealth = 300
ENT.IsAstralMachine = true
ENT.IsAstralFarm = true
ENT.IsValidRaidable = true

if SERVER then
	function ENT:Init()
		self.progress, self.heat, self.lastThink = 0, 20, CurTime()
		self:SetNW2Int("AstralFarmStock", 0)
		self:SetNW2Float("AstralFarmProg", 0)
		self:SetNW2Float("AstralFarmHeat", 20)
	end

	function ENT:ThinkFuncBypass()
		local now = CurTime()
		self.elapsed = math.min(now - (self.lastThink or now), 5)
		self.lastThink = now
	end

	function ENT:ThinkFunc()
		local def = self.Farm
		if not def then return end
		local stock = self:GetNW2Int("AstralFarmStock", 0)
		if stock >= def.stock then return end
		local mult = Astral.Events and Astral.Events.Mult("farm") or 1
		self.progress = self.progress + (self.elapsed or 0) * mult / def.seconds
		-- Labo de méthamphétamine : la cuve chauffe pendant la cuisson
		if def.heat then
			self.heat = self.heat + (self.elapsed or 0) * math.Rand(0.25, 0.55)
			self:SetNW2Float("AstralFarmHeat", self.heat)
			if self.heat >= 100 then return self:Explode() end
			if self.heat >= 80 and (self.nextAlarm or 0) < CurTime() then
				self.nextAlarm = CurTime() + 3
				self:EmitSound("ambient/alarms/klaxon1.wav", 70, 120)
			end
		end
		if self.progress >= 1 then
			self.progress = 0
			self:SetNW2Int("AstralFarmStock", stock + 1)
			self:EmitSound("buttons/button9.wav", 60, 110)
			hook.Run("Astral.Produced", self, "farm", def.yield)
		end
		self:SetNW2Float("AstralFarmProg", self.progress)
	end

	-- Purge (menu) : refroidit la cuve du labo de méthamphétamine
	function ENT:Vent()
		self.heat = 20
		self:SetNW2Float("AstralFarmHeat", 20)
		self:EmitSound("ambient/machines/steam_release_2.wav", 70)
		local ed = EffectData() ed:SetOrigin(self:GetPos() + self:GetUp() * 14) ed:SetScale(2)
		util.Effect("cball_explode", ed)
	end

	function ENT:Explode()
		if self.Exploded then return end
		self.Exploded = true
		local pos = self:GetPos()
		local ed = EffectData() ed:SetOrigin(pos) ed:SetMagnitude(2)
		util.Effect("Explosion", ed)
		util.BlastDamage(self, self, pos, 180, 60)
		local owner = BaseWars.CPPI.GetOwner(self)
		if IsValid(owner) then owner:Notify("Ton labo de méthamphétamine a explosé (surchauffe) !", BASEWARS_NOTIFICATION_ERROR) end
		Astral.Logs.Write("farm_explode", IsValid(owner) and owner or nil, { class = self:GetClass() })
		self:Remove()
	end

	function ENT:UseFuncBypass(activator)
		if not IsValid(activator) or not activator:IsPlayer() then return end
		if BaseWars.CPPI.GetOwner(self) ~= activator then return end
		if (self.NextMenu or 0) > CurTime() then return end
		self.NextMenu = CurTime() + 0.5
		net.Start("Astral.Farm.Open") net.WriteEntity(self) net.Send(activator)
	end
end

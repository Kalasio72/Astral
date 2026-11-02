-- Astral Industries — Fabricateur : assemble des composants à partir de lingots et de ressources (Astral.Recipes).
-- Le propriétaire choisit la recette avec E (menu). Les ingrédients arrivent automatiquement des conteneurs et
-- raffineries du même propriétaire ; le produit part vers les conteneurs (voir sv_industry.lua).
AddCSLuaFile()

ENT.Base = "bw_base_electronics"
ENT.Type = "anim"
ENT.PrintName = "Fabricateur"
ENT.Model = "models/props_lab/hev_machine.mdl"
ENT.PresetMaxHealth = 600
ENT.PowerRequired = 20
ENT.PowerCapacity = 4000
ENT.ThinkPeriods = 5
ENT.IsAstralMachine = true

if SERVER then
	function ENT:Init()
		self.AstralIn, self.AstralOut = {}, {}
		self.progress = 0
		self.lastThink = CurTime()
		self.Recipe = nil
		self:SetNW2String("AstralRecipe", "")
		self:AstralSync()
	end

	function ENT:AstralSync()
		local view = table.Copy(self.AstralIn)
		for id, q in pairs(self.AstralOut) do Astral.Inv.Add(view, id, q) end
		self:SetNW2String("AstralInv", Astral.Inv.Encode(view))
	end

	-- Changement de recette : les ingrédients déjà chargés qui ne servent plus sont rendus en sortie
	function ENT:SetRecipe(id)
		local recipe = Astral.Recipes.Get(id)
		if not recipe then return end
		for res, q in pairs(self.AstralIn) do
			if not recipe.inputs[res] then Astral.Inv.Add(self.AstralOut, res, q) self.AstralIn[res] = nil end
		end
		self.Recipe = id
		self.progress = 0
		self:SetNW2String("AstralRecipe", id)
		self:AstralSync()
	end

	-- Quantités encore acceptées en entrée (5 cycles d'avance au maximum)
	function ENT:Wants(res)
		local recipe = self.Recipe and Astral.Recipes.Get(self.Recipe)
		if not recipe or not recipe.inputs[res] then return 0 end
		return math.max(0, recipe.inputs[res] * 5 - (self.AstralIn[res] or 0))
	end

	function ENT:ThinkFuncBypass()
		local now = CurTime()
		self.dt = math.min(now - (self.lastThink or now), 5)
		self.lastThink = now
		if not self:IsPowered() then self:SetNW2String("AstralStatus", "Hors tension") end
	end

	function ENT:ThinkFunc()
		local recipe = self.Recipe and Astral.Recipes.Get(self.Recipe)
		if not recipe then self:SetNW2String("AstralStatus", "Choisis une recette (E)") return end
		if Astral.Inv.Count(self.AstralOut) >= 40 then self:SetNW2String("AstralStatus", "Sortie pleine") return end
		for res, q in pairs(recipe.inputs) do
			if (self.AstralIn[res] or 0) < q then
				self.progress = 0
				self:SetNW2String("AstralStatus", "En attente : " .. Astral.Resources.Get(res).name)
				return
			end
		end
		self.progress = self.progress + (self.dt or 0) / recipe.seconds * Astral.Events.Mult("fabricate") * Astral.Research.Mult(BaseWars.CPPI.GetOwner(self), "fabricate")
		if self.progress >= 1 then
			self.progress = 0
			for res, q in pairs(recipe.inputs) do Astral.Inv.Add(self.AstralIn, res, -q) end
			Astral.Inv.Add(self.AstralOut, recipe.output, recipe.qty)
			self:AstralSync()
			hook.Run("Astral.Produced", self, "fabricate", recipe.qty)
		end
		self:SetNW2String("AstralStatus", string.format("%s… %d %%", recipe.name, math.floor(self.progress * 100)))
	end

	-- E : le propriétaire ouvre le menu des recettes (même hors tension)
	function ENT:UseFuncBypass(activator)
		if not IsValid(activator) or not activator:IsPlayer() then return end
		if BaseWars.CPPI.GetOwner(self) ~= activator then
			return activator:Notify("Seul le propriétaire peut configurer ce fabricateur.", BASEWARS_NOTIFICATION_ERROR)
		end
		if (self.NextMenu or 0) > CurTime() then return end
		self.NextMenu = CurTime() + 0.5
		net.Start("Astral.Fabricator.Open") net.WriteEntity(self) net.Send(activator)
	end
else
	function ENT:Draw()
		self:DrawModel()
		if Astral.DrawMachinePanel then
			Astral.DrawMachinePanel(self, self.PrintName, self:GetNW2String("AstralStatus", ""), Astral.Inv.Decode(self:GetNW2String("AstralInv", "")))
		end
	end
end

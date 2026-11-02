-- Astral Industries — Conteneur industriel : stocke la production des machines voisines du même propriétaire.
-- Touche E (propriétaire uniquement) : vend tout le contenu au serveur. Sans énergie. Destructible en raid
-- (le contenu est alors perdu, la valeur d'achat est remboursée comme pour toute entité BaseWars).
AddCSLuaFile()

ENT.Base = "bw_base"
ENT.Type = "anim"
ENT.PrintName = "Conteneur industriel"
ENT.Model = "models/props_wasteland/controlroom_storagecloset001a.mdl"
ENT.PresetMaxHealth = 600
ENT.PowerCapacity = 0 -- bw_base initialise MaxPower avec cette valeur ; le conteneur n'utilise pas d'énergie
ENT.IsAstralMachine = true

if SERVER then
	function ENT:Init()
		self.AstralStore = {}
		self:AstralSync()
	end

	function ENT:AstralSync()
		local inv = self.AstralStore or {}
		self:SetNW2String("AstralInv", Astral.Inv.Encode(inv))
		self:SetNW2String("AstralStatus", string.format("%d / %d — valeur %s%s — E pour vendre",
			Astral.Inv.Count(inv), Astral.Cfg("Industry.ContainerCapacity", 500),
			BaseWars.LANG.CURRENCY, BaseWars.NumberFormat(Astral.Inv.Value(inv))))
	end

	function ENT:Use(activator)
		if IsValid(activator) and activator:IsPlayer() then Astral.Industry.SellContainer(activator, self) end
	end
else
	function ENT:Draw()
		self:DrawModel()
		if Astral.DrawMachinePanel then
			Astral.DrawMachinePanel(self, self.PrintName, self:GetNW2String("AstralStatus", ""), Astral.Inv.Decode(self:GetNW2String("AstralInv", "")))
		end
	end
end

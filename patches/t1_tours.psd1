@{
Patches = @(
@{ Id = 'T1 tours : variable réseau Radius manquante (plantage à l''apparition)'; File = '/garrysmod/gamemodes/basewars/entities/entities/bw_turret_healer.lua'
Old = '		self:NetworkVar("Int", 4, "Level")
		self:NetworkVar("String", 2, "UpgradeCost")'
New = '		self:NetworkVar("Int", 4, "Level")
		self:NetworkVar("Int", 5, "Radius") -- Astral T1 : utilisée par Init/ThinkFunc mais jamais déclarée
		self:NetworkVar("String", 2, "UpgradeCost")' }

@{ Id = 'T1 tours : coût d''amélioration vide avant achat'; File = '/garrysmod/gamemodes/basewars/entities/entities/bw_turret_healer.lua'
Old = '	return tonumber( self:GetUpgradeCost() * 40 * lvl )'
New = '	return (tonumber(self:GetUpgradeCost()) or 0) * 40 * lvl -- Astral T1 : chaîne vide avant achat' }

@{ Id = 'T1 tours : aucun tir sans cible (math.random(1, 0))'; File = '/garrysmod/gamemodes/basewars/entities/entities/bw_turret_healer.lua'
Old = '	self.nextShot = ct + self.FireDelay
	local amt = math.max(1, self:GetLevel())'
New = '	self.nextShot = ct + self.FireDelay
	if (self.n_entList or 0) < 1 then return end -- Astral T1 : sans cible, math.random(1, 0) levait une erreur
	local amt = math.max(1, self:GetLevel())' }

@{ Id = 'T1 tour de gel : GetPrestige inexistant (1)'; File = '/garrysmod/gamemodes/basewars/entities/entities/bw_turret_freezer.lua'
Old = '	if target:GetPrestige( "perk", "speedperk" ) >= 2 then'
New = '	if false then -- Astral T1 : pas de système de prestige sur ce serveur (GetPrestige inexistant)' }

@{ Id = 'T1 tour de gel : GetPrestige inexistant (2)'; File = '/garrysmod/gamemodes/basewars/entities/entities/bw_turret_freezer.lua'
Old = '		if target:GetPrestige( "perk", "speedperk" ) >= 1 then'
New = '		if false then -- Astral T1 : pas de système de prestige sur ce serveur' }
)
}

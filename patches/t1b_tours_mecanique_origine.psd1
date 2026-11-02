@{
Patches = @(
@{ Id = 'T1b tour à acide : retour au ciblage BaseWars d''origine'; File = '/garrysmod/gamemodes/basewars/entities/entities/bw_turret_acid.lua'
Old = '	if IsValid(owner) and owner:IsPlayer() and owner:IsEnemy(v) and owner:InRaid() and v:InRaid() then return true end -- Astral T1 : pas d''attaque hors raid'
New = '	if IsValid(owner) and owner:IsPlayer() and owner:IsEnemy(v) then return true end' }

@{ Id = 'T1b tour de gel : retour au ciblage BaseWars d''origine'; File = '/garrysmod/gamemodes/basewars/entities/entities/bw_turret_freezer.lua'
Old = '	if IsValid(owner) and owner:IsPlayer() and owner:IsEnemy(v) and owner:InRaid() and v:InRaid() then return true end -- Astral T1 : pas d''attaque hors raid'
New = '	if IsValid(owner) and owner:IsPlayer() and owner:IsEnemy(v) then return true end' }
)
}

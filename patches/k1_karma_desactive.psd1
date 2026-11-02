@{
Patches = @(
@{ Id = 'K1 karma désactivé : aucun délai de réapparition lié au karma (demande du propriétaire, 2026-11-02)'; File = '/garrysmod/gamemodes/basewars/gamemode/config.lua'
Old = '		KarmaSecondPer 	= 6,'
New = '		KarmaSecondPer 	= 1e9, -- Astral K1 : karma désactivé (était 6)' }

@{ Id = 'K1 karma désactivé : plus de perte de karma'; File = '/garrysmod/gamemodes/basewars/gamemode/config.lua'
Old = '		KarmaLoss 		= -2,'
New = '		KarmaLoss 		= 0, -- Astral K1 : karma désactivé (était -2)' }

@{ Id = 'K1 karma désactivé : plus de halo vert/rouge'; File = '/garrysmod/gamemodes/basewars/gamemode/config.lua'
Old = '		KarmaGlowLevel 	= 65,'
New = '		KarmaGlowLevel 	= 101, -- Astral K1 : karma désactivé (était 65)' }
)
}

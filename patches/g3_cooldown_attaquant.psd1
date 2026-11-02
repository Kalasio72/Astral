@{
Patches = @(
@{ Id = 'G3 config : délai attaquant'; File = '/garrysmod/gamemodes/basewars/gamemode/config.lua'
Old = '		CoolDownTime	= 60 * 30,'
New = '		CoolDownTime	= 60 * 30,
		-- AttackerCoolDown (Astral G3) : temps après la FIN d''un raid avant que l''attaquant puisse en relancer un
		AttackerCoolDown	= 60 * 5,' }

@{ Id = 'G3 vérification du délai attaquant au lancement'; File = '/garrysmod/gamemodes/basewars/gamemode/modules/raid/server/sv_raid.lua'
Old = '	if ply == target then
		ply:Notify(BaseWars.LANG.CantRaidSelf, BASEWARS_NOTIFICATION_RAID)
		return
	end'
New = '	if ply == target then
		ply:Notify(BaseWars.LANG.CantRaidSelf, BASEWARS_NOTIFICATION_RAID)
		return
	end
	-- Astral G3 : délai de l''attaquant (individuel, ou de sa faction)
	do
		local atkFaction = BaseWars.Factions.FactionTable[ply:GetFaction()]
		local untilT = (atkFaction and atkFaction.__AstralAttackCooldownUntil) or ply.__AstralAttackCooldownUntil or 0
		if untilT > CurTime() then
			ply:Notify("Tu dois attendre " .. string.NiceTime(math.ceil(untilT - CurTime())) .. " avant de lancer un nouveau raid.", BASEWARS_NOTIFICATION_RAID)
			return
		end
	end' }

@{ Id = 'G3 enregistrement du délai attaquant au lancement'; File = '/garrysmod/gamemodes/basewars/gamemode/modules/raid/server/sv_raid.lua'
Old = '	if Faction then Faction.__RaidCoolDown = 0 else ply.__RaidCoolDown = 0 end'
New = '	if Faction then Faction.__RaidCoolDown = 0 else ply.__RaidCoolDown = 0 end
	-- Astral G3 : l''attaquant devra attendre la fin du raid + AttackerCoolDown
	local atkUntil = CurTime() + BaseWars.Config.Raid.Time + (BaseWars.Config.Raid.AttackerCoolDown or 0)
	if Faction then Faction.__AstralAttackCooldownUntil = atkUntil else ply.__AstralAttackCooldownUntil = atkUntil end' }
)
}

-- Astral Quests — définitions (partagées : le client affiche les noms et descriptions).
-- Chaque quête suit un « compteur » alimenté par sv_quests.lua :
--   collect_money  argent récupéré sur ses imprimantes/coffres     buy_entity   machines achetées
--   play_minutes   minutes de jeu actives (hors AFK)                 refine       lingots raffinés par ses machines
--   fabricate      composants fabriqués par ses machines             sell_value   valeur vendue via les conteneurs
--   raid           raids lancés                                        harvest      unités récoltées dans ses serres
-- Chaque jour, Quests.DailyCount quêtes sont tirées dans Daily (même tirage pour tous) ; chaque semaine, WeeklyCount dans Weekly.

Astral.Quests = Astral.Quests or {}
local Q = Astral.Quests

Q.DailyCount = 3
Q.WeeklyCount = 2

Q.Daily = {
	{ id = "d_collect",  counter = "collect_money", goal = 10000, name = "Récolte du jour",      desc = "Récupère %s sur tes imprimantes.", money = 5000,  xp = 300 },
	{ id = "d_buy",      counter = "buy_entity",    goal = 3,     name = "Agrandir la base",     desc = "Achète %s machines.",               money = 3000,  xp = 200 },
	{ id = "d_play",     counter = "play_minutes",  goal = 30,    name = "Présence",             desc = "Joue %s minutes (hors AFK).",       money = 4000,  xp = 250 },
	{ id = "d_refine",   counter = "refine",        goal = 10,    name = "Fonderie",             desc = "Raffine %s lingots.",               money = 6000,  xp = 400 },
	{ id = "d_sell",     counter = "sell_value",    goal = 2000,  name = "Commerce industriel",  desc = "Vends pour %s de ressources.",      money = 5000,  xp = 350 },
	{ id = "d_harvest",  counter = "harvest",       goal = 20,    name = "Main verte",           desc = "Récolte %s unités dans tes serres.", money = 4000,  xp = 300 },
	{ id = "d_fabricate",counter = "fabricate",     goal = 3,     name = "Atelier",              desc = "Fabrique %s composants.",           money = 8000,  xp = 500 },
}

Q.Weekly = {
	{ id = "w_collect",  counter = "collect_money", goal = 150000, name = "Magnat",              desc = "Récupère %s sur tes imprimantes.", money = 60000, xp = 3000 },
	{ id = "w_play",     counter = "play_minutes",  goal = 300,    name = "Pilier du serveur",   desc = "Joue %s minutes (hors AFK).",       money = 40000, xp = 2500 },
	{ id = "w_fabricate",counter = "fabricate",     goal = 40,     name = "Chaîne de production",desc = "Fabrique %s composants.",           money = 90000, xp = 4000 },
	{ id = "w_raid",     counter = "raid",          goal = 2,      name = "Conquérant",          desc = "Lance %s raids.",                   money = 50000, xp = 3000 },
	{ id = "w_sell",     counter = "sell_value",    goal = 50000,  name = "Exportateur",         desc = "Vends pour %s de ressources.",      money = 70000, xp = 3500 },
}

Q.ById = {}
for _, list in ipairs({ Q.Daily, Q.Weekly }) do for _, q in ipairs(list) do Q.ById[q.id] = q end end

-- Les compteurs exprimés en argent s'affichent formatés
Q.MoneyCounters = { collect_money = true, sell_value = true }

function Q.FormatGoal(q)
	if Q.MoneyCounters[q.counter] then return BaseWars.LANG.CURRENCY .. BaseWars.NumberFormat(q.goal) end
	return tostring(q.goal)
end

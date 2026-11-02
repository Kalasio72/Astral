-- Astral — annonces automatiques de SpaceVX (BaseWars.AdvertTbl, affichées dans le chat) : remplacées par des
-- messages en français (les originales renvoyaient vers le groupe Steam, les forums et le Discord de l'auteur).
-- Couleurs : celles que SpaceVX définit pour ce tableau (NiceGreen, NiceBlue, Grey…), avec repli si absentes.

local G = Grey or Color(180, 180, 190)
local A = NiceBlue or Color(110, 205, 255)
local V = NiceGreen or Color(110, 225, 150)

BaseWars.AdvertTbl = {
	{ G, "Besoin d'aide ? Parle à ", A, "Ava", G, ", la guide, près du point d'apparition, ou ouvre ", V, "F3 → Aide", G, "." },
	{ G, "Revends la marchandise de tes fermes à ", A, "Silas", G, ", le receleur. Attention : si tu meurs, ton sac tombe !" },
	{ G, "Commandes fun : ", V, "!roll", G, ", ", V, "!pile", G, ", ", V, "!danse", G, ", ", V, "!donner", G, "… La liste : ", V, "!commandes" },
	{ G, "Une ", A, "Banque Astral", G, " (niveau 10) récolte et améliore toutes tes imprimantes d'un coup." },
}

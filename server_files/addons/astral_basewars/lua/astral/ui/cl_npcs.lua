-- Astral UI — boîte de dialogue des PNJ Astral (entities/astral_npc.lua) : portrait, réplique, choix.

local UI = Astral.UI
local C, S = UI.Colors, UI.Scale

local LINES = {
	guide = {
		"Bienvenue sur Astral ! Je peux t'expliquer tout ce qu'il faut savoir pour bien démarrer.",
		"Besoin d'un coup de main ? Choisis un sujet.",
	},
	quests = {
		"Des quêtes t'attendent, avec de belles récompenses à la clé.",
		"Tu veux voir où tu en es par rapport aux autres ?",
	},
	dealer = {
		"Pas de questions, pas de traces. Montre-moi ce que tu as.",
		"Je rachète tout ce qui sort de tes labos. Cash.",
	},
}

local SHORTCUTS = {
	{ "F3", "Menu principal : quêtes, recherche, marché, factions, raids, règles" },
	{ "F4", "Boutique : imprimantes, générateurs, fermes, armes" },
	{ "Tab", "Liste des joueurs et commandes rapides" },
	{ "E", "Gérer une machine (imprimante, banque, ferme…)" },
	{ "Maj + E", "Récolter directement" },
	{ "!astral", "Menu Astral (commandes et événements, selon ton rang)" },
	{ "/pm nom message", "Message privé" },
	{ "/sell, /dw", "Revendre la machine visée, lâcher son arme" },
}

local function shortcuts()
	local f = UI.Frame("Raccourcis et commandes", S(620), S(440))
	local list = vgui.Create("DPanel", f)
	list:Dock(FILL) list:DockMargin(S(6), S(34), S(6), S(6))
	function list:Paint(w, h)
		draw.RoundedBox(S(8), 0, 0, w, h, C.panel)
		for i, s in ipairs(SHORTCUTS) do
			local y = S(14) + (i - 1) * S(46)
			surface.SetFont("Astral.UI.Small")
			local kw = surface.GetTextSize(s[1]) + S(20)
			draw.RoundedBox(S(6), S(14), y, kw, S(30), C.line)
			draw.SimpleText(s[1], "Astral.UI.Small", S(14) + kw / 2, y + S(15), C.accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(s[2], "Astral.UI.Small", S(150), y + S(15), C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
	end
end

local function choices(role, npc)
	local menu = Astral.Menu
	if role == "guide" then
		return {
			{ "Guide du débutant", "Gagner de l'argent, construire, raider", function() menu.OpenPage("Aide") end },
			{ "Raccourcis et commandes", "Toutes les touches utiles", shortcuts },
			{ "Règles du serveur", "À lire avant de jouer", function() menu.OpenPage("Règles") end },
			{ "Boutique", "Imprimantes, générateurs, fermes", function() UI.OpenShop() end },
		}
	elseif role == "quests" then
		return {
			{ "Mes quêtes", "Journalières et hebdomadaires", function() menu.OpenPage("Quêtes") end },
			{ "Classements", "Les meilleurs joueurs du serveur", function() menu.OpenPage("Classements") end },
			{ "Recherche", "Technologies et bonus", function() menu.OpenPage("Recherche") end },
		}
	elseif role == "dealer" then
		local list = {}
		if Astral.Farms and Astral.Farms.OpenDealer then
			list[#list + 1] = { "Vendre ma marchandise", "Le contenu de ton sac, payé comptant", function() Astral.Farms.OpenDealer(npc) end }
		end
		list[#list + 1] = { "Les fermes", "Ce que je rachète et à quel prix", function() if Astral.Farms and Astral.Farms.OpenPrices then Astral.Farms.OpenPrices() end end }
		return list
	end
	return {}
end

local frame
net.Receive("Astral.NPC.Open", function()
	local npc = net.ReadEntity()
	if not IsValid(npc) or not npc.RoleInfo then return end
	if IsValid(frame) then frame:Close() end
	local info, role = npc:RoleInfo(), npc:GetRole()
	local col = info.color
	local opts = choices(role, npc)
	frame = UI.Frame("", S(640), S(170) + #opts * S(62) + S(70))
	local line = table.Random(LINES[role] or LINES.guide)
	local paint = frame.Paint
	function frame:Paint(w, h)
		paint(self, w, h)
		draw.RoundedBoxEx(S(10), 0, 0, w, S(4), col, true, true, false, false)
		draw.RoundedBox(S(40), S(20), S(24), S(80), S(80), ColorAlpha(col, 40))
		draw.SimpleText(info.name:sub(1, 1), "Astral.UI.Huge", S(60), S(64), col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText(info.name, "Astral.UI.Big", S(118), S(30), C.text)
		draw.SimpleText(info.role, "Astral.UI.Small", S(118), S(60), col)
	end
	local bubble = vgui.Create("DPanel", frame)
	bubble:SetPos(S(20), S(118)) bubble:SetSize(S(600), S(56))
	function bubble:Paint(w, h)
		draw.RoundedBox(S(8), 0, 0, w, h, C.panel)
		draw.RoundedBox(S(2), 0, S(8), S(3), h - S(16), col)
	end
	local l = UI.Label(bubble, "« " .. line .. " »", "Astral.UI.Text", C.text)
	l:SetPos(S(16), 0) l:SetSize(S(570), S(56)) l:SetWrap(true)
	for i, o in ipairs(opts) do
		local b = vgui.Create("DButton", frame)
		b:SetPos(S(20), S(188) + (i - 1) * S(62)) b:SetSize(S(600), S(54)) b:SetText("")
		function b:Paint(w, h)
			local hov = self:IsHovered()
			draw.RoundedBox(S(8), 0, 0, w, h, hov and C.line or C.panel)
			if hov then draw.RoundedBox(S(2), 0, S(10), S(3), h - S(20), col) end
			draw.SimpleText(o[1], "Astral.UI.Text", S(18), S(9), hov and C.text or C.text)
			draw.SimpleText(o[2], "Astral.UI.Small", S(18), S(31), C.dim)
			draw.SimpleText("›", "Astral.UI.Big", w - S(20), h / 2, hov and col or C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end
		b.DoClick = function() surface.PlaySound("ui/buttonclick.wav") frame:Close() o[3]() end
	end
	local bye = UI.Button(frame, "Au revoir", C.bad, function() frame:Close() end)
	bye:SetPos(S(20), S(188) + #opts * S(62) + S(6)) bye:SetSize(S(600), S(40))
end)

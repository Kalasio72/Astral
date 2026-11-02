-- Astral UI — écran d'accueil à la connexion (remplace le MOTD ULX par défaut, en anglais, coupé par le patch M1).
-- Affiché une fois par connexion. « astral_accueil » le rouvre.

local UI = Astral.UI
local C, S = UI.Colors, UI.Scale

local KEYS = {
	{ "F3", "Menu principal", "Quêtes, recherche, marché, factions, raids, règles" },
	{ "F4", "Boutique", "Imprimantes, générateurs, armes et objets" },
	{ "Tab", "Joueurs", "Liste des joueurs, profils et messages privés" },
	{ "E", "Gérer", "Vise ton imprimante ou ta banque : infos, améliorations" },
	{ "Maj + E", "Récolter", "Récupère l'argent sans ouvrir le menu" },
	{ "Échap", "Menu du serveur", "Règles, aide, paramètres et déconnexion" },
}

local frame
local function open()
	if IsValid(frame) then frame:Remove() end
	local w, h = math.min(ScrW() - S(80), S(760)), math.min(ScrH() - S(80), S(500))
	frame = vgui.Create("EditablePanel")
	frame:SetSize(w, h) frame:Center() frame:MakePopup()
	frame.openT = SysTime()
	function frame:Paint(pw, ph)
		self:SetAlpha(255 * math.Clamp((SysTime() - self.openT) / 0.25, 0, 1))
		draw.RoundedBox(S(12), 0, 0, pw, ph, Color(8, 11, 22, 252))
		draw.RoundedBoxEx(S(12), 0, 0, pw, S(4), C.accent, true, true, false, false)
		draw.SimpleText("BIENVENUE SUR", "Astral.UI.Small", pw / 2, S(30), C.dim, TEXT_ALIGN_CENTER)
		surface.SetFont("Astral.UI.Huge")
		local a, b = surface.GetTextSize("ASTRAL "), surface.GetTextSize("BASEWARS")
		local x = pw / 2 - (a + b) / 2
		draw.SimpleText("ASTRAL", "Astral.UI.Huge", x, S(50), C.accent)
		draw.SimpleText("BASEWARS", "Astral.UI.Huge", x + a, S(50), C.text)
		draw.SimpleText("Construis ta base, fais tourner tes machines, défends-la et lance des raids.", "Astral.UI.Text", pw / 2, S(98), C.text, TEXT_ALIGN_CENTER)
		-- Raccourcis : deux colonnes
		local cw, top = (pw - S(60)) / 2, S(140)
		for i, k in ipairs(KEYS) do
			local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
			local bx, by = S(24) + col * (cw + S(12)), top + row * S(78)
			draw.RoundedBox(S(8), bx, by, cw, S(68), C.panel)
			surface.SetFont("Astral.UI.Text")
			local kw = math.max(S(44), surface.GetTextSize(k[1]) + S(18))
			draw.RoundedBox(S(6), bx + S(12), by + S(17), kw, S(34), C.line)
			draw.SimpleText(k[1], "Astral.UI.Text", bx + S(12) + kw / 2, by + S(34), C.accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(k[2], "Astral.UI.Text", bx + kw + S(24), by + S(14), C.text)
			draw.SimpleText(UI.Truncate(k[3], "Astral.UI.Tiny", cw - kw - S(36)), "Astral.UI.Tiny", bx + kw + S(24), by + S(40), C.dim)
		end
		draw.SimpleText("En jouant, tu acceptes les règles du serveur.", "Astral.UI.Small", pw / 2, ph - S(92), C.warn, TEXT_ALIGN_CENTER)
	end

	local bar = vgui.Create("DPanel", frame)
	bar:Dock(BOTTOM) bar:DockMargin(S(24), 0, S(24), S(20)) bar:SetTall(S(44))
	function bar:Paint() end
	local rules = UI.Button(bar, "Lire les règles", C.warn, function()
		frame:Remove()
		if Astral.Menu and Astral.Menu.OpenPage then Astral.Menu.OpenPage("Règles") end
	end)
	rules:Dock(LEFT) rules:SetWide((frame:GetWide() - S(60)) / 2) rules:SetTall(S(44))
	local go = UI.Button(bar, "Commencer à jouer", C.good, function() frame:Remove() end)
	go:Dock(RIGHT) go:SetWide((frame:GetWide() - S(60)) / 2) go:SetTall(S(44))
end

hook.Add("InitPostEntity", "Astral.Welcome", function()
	timer.Simple(2, function() if GetConVar("astral_hud"):GetBool() then open() end end)
end)
concommand.Add("astral_accueil", open)

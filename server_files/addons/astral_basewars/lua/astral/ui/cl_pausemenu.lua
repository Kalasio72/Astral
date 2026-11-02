-- Astral UI — menu Échap.
-- Remplace le menu pause de Garry's Mod par un menu au style Astral. Le menu d'origine reste accessible par
-- « Paramètres du jeu ». Hook en priorité haute : il passe avant les autres menus Échap installés.
-- « astral_hud 0 » rend la main au menu précédent.

local UI = Astral.UI
local C, S = UI.Colors, UI.Scale

local menu
local bypass = false   -- laisse passer UNE ouverture du menu Garry's Mod (bouton « Paramètres du jeu »)

local function close()
	if IsValid(menu) then menu:Remove() end
end

local function bigButton(parent, label, sub, col, onClick)
	local b = vgui.Create("DButton", parent)
	b:Dock(TOP) b:DockMargin(0, 0, 0, S(8)) b:SetTall(S(54)) b:SetText("")
	function b:Paint(w, h)
		local hov = self:IsHovered()
		self.anim = Lerp(FrameTime() * 12, self.anim or 0, hov and 1 or 0)
		draw.RoundedBox(S(8), 0, 0, w, h, hov and C.panel or Color(16, 21, 40, 200))
		draw.RoundedBoxEx(S(8), 0, 0, S(3) + S(3) * self.anim, h, col or C.accent, true, false, true, false)
		draw.SimpleText(label, "Astral.UI.Big", S(20) + S(6) * self.anim, sub and h / 2 + S(1) or h / 2, C.text, TEXT_ALIGN_LEFT, sub and TEXT_ALIGN_BOTTOM or TEXT_ALIGN_CENTER)
		if sub then draw.SimpleText(sub, "Astral.UI.Small", S(20) + S(6) * self.anim, h / 2 + S(2), C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP) end
	end
	b.DoClick = function() surface.PlaySound("ui/buttonclick.wav") onClick() end
	return b
end

local function open()
	close()
	local me = LocalPlayer()
	menu = vgui.Create("DPanel")
	menu:SetSize(ScrW(), ScrH()) menu:MakePopup() menu:SetKeyboardInputEnabled(false)
	menu.start = SysTime()
	function menu:Paint(w, h)
		Derma_DrawBackgroundBlur(self, self.start)
		surface.SetDrawColor(5, 7, 15, 170) surface.DrawRect(0, 0, w, h)
		local x = S(90)
		draw.SimpleText("ASTRAL", "Astral.UI.Huge", x, S(110), C.accent)
		surface.SetFont("Astral.UI.Huge")
		draw.SimpleText("BASEWARS", "Astral.UI.Huge", x + surface.GetTextSize("ASTRAL "), S(110), C.text)
		draw.SimpleText(UI.Truncate(GetHostName(), "Astral.UI.Text", S(420)), "Astral.UI.Text", x + S(2), S(148), C.dim)
	end
	function menu:OnMousePressed() end

	-- Colonne de boutons
	local col = vgui.Create("DPanel", menu)
	col:SetPos(S(90), S(200)) col:SetSize(S(380), ScrH() - S(260))
	function col:Paint() end
	local M = Astral.Menu
	bigButton(col, "Reprendre", nil, C.good, close)
	bigButton(col, "Menu principal", "Quêtes, recherche, marché, factions… (F3)", C.accent, function() close() if M then M.Open() end end)
	bigButton(col, "Boutique", "Machines, armes et objets (F4)", C.accent2, function() close() if UI.OpenShop then UI.OpenShop() end end)
	bigButton(col, "Règles du serveur", nil, C.warn, function() close() if M and M.OpenPage then M.OpenPage("Règles") end end)
	bigButton(col, "Aide", "Les bases pour bien démarrer", C.accent, function() close() if M and M.OpenPage then M.OpenPage("Aide") end end)
	bigButton(col, "Paramètres du jeu", "Graphismes, son, touches (menu Garry's Mod)", C.dim, function()
		close()
		bypass = true
		gui.ActivateGameUI()
		timer.Simple(0.5, function() bypass = false end)
	end)
	bigButton(col, "Se déconnecter", nil, C.bad, function()
		Derma_Query("Quitter Astral BaseWars ?", "Déconnexion", "Se déconnecter", function() RunConsoleCommand("disconnect") end, "Annuler")
	end)

	-- Carte joueur et serveur
	local card = vgui.Create("DPanel", menu)
	local cw, ch = S(360), S(250)
	card:SetSize(cw, ch) card:SetPos(ScrW() - cw - S(90), ScrH() - ch - S(90))
	local av = vgui.Create("AvatarImage", card)
	av:SetSize(S(56), S(56)) av:SetPos(S(20), S(20)) av:SetPlayer(me, 128)
	function card:Paint(w, h)
		if not IsValid(me) then return end
		UI.Card(0, 0, w, h, C.accent)
		draw.SimpleText(UI.Truncate(me:Nick(), "Astral.UI.Big", w - S(110)), "Astral.UI.Big", S(90), S(26), C.text)
		local lvl = me.GetLevel and me:GetLevel() or 0
		draw.SimpleText("Niveau " .. lvl, "Astral.UI.Small", S(90), S(54), C.xp)
		local rows = {
			{ "Argent", me.GetMoney and UI.Money(me:GetMoney()) or "—", C.good },
			{ "Faction", (me.InFaction and me:InFaction()) and team.GetName(me:Team()) or "Aucune", C.text },
			{ "Joueurs en ligne", player.GetCount() .. " / " .. game.MaxPlayers(), C.text },
			{ "Carte", game.GetMap(), C.dim },
			{ "Heure", os.date("%H:%M"), C.dim },
		}
		for i, r in ipairs(rows) do
			local y = S(96) + (i - 1) * S(28)
			draw.SimpleText(r[1], "Astral.UI.Small", S(20), y, C.dim)
			draw.SimpleText(UI.Truncate(r[2], "Astral.UI.Text", w * 0.55), "Astral.UI.Text", w - S(20), y - S(2), r[3], TEXT_ALIGN_RIGHT)
		end
	end
end

hook.Add("OnPauseMenuShow", "Astral.PauseMenu", function()
	if not GetConVar("astral_hud"):GetBool() then return end
	if bypass then bypass = false return end
	if IsValid(menu) then close() return false end
	-- Saisie du chat ouverte : Échap la ferme
	if Astral.Chat and Astral.Chat.IsOpen and Astral.Chat.IsOpen() then Astral.Chat.Close() return false end
	-- Menu F3 ouvert : Échap le ferme, sans ouvrir le menu pause par-dessus
	if Astral.Menu and IsValid(Astral.Menu.Frame) then Astral.Menu.Frame:Close() return false end
	-- Tableau des joueurs épinglé : Échap le ferme
	if Astral.Scoreboard and Astral.Scoreboard.IsOpen and Astral.Scoreboard.IsOpen() then Astral.Scoreboard.Close() return false end
	open()
	return false
end, HOOK_HIGH)

concommand.Add("astral_menu_echap", function() if IsValid(menu) then close() else open() end end)

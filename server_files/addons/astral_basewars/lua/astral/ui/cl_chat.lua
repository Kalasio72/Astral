-- Astral UI — chat.
-- Remplace l'affichage de la chatbox Garry's Mod, pas son fonctionnement :
--   * envoi par « say » / « say_team » : commandes ULX (!), BaseWars (/) et messages privés inchangés ;
--   * réception par chat.AddText (enveloppé, l'original est toujours appelé pour la console) et le hook ChatText ;
--   * hooks StartChat / FinishChat / ChatTextChanged relancés pour les addons qui en dépendent.
-- Touche « parler » (Y) : tout le monde ; « parler à l'équipe » (U) : sa faction.
-- Fermé : les derniers messages s'effacent après 12 s. Ouvert : historique (200 messages) avec molette.
-- « astral_hud 0 » rend la main au chat d'origine.

local UI = Astral.UI
local C, S = UI.Colors, UI.Scale

Astral.Chat = Astral.Chat or {}
local CH = Astral.Chat
CH.Messages = CH.Messages or {}
local MAX_HISTORY, SHOW_CLOSED, FADE_AFTER = 200, 8, 12

local cvar = GetConVar("astral_hud")
local function enabled() return cvar and cvar:GetBool() end

local function fonts()
	surface.CreateFont("Astral.UI.Chat", { font = "Roboto", size = S(18), weight = 600, extended = true })
	surface.CreateFont("Astral.UI.ChatTime", { font = "Roboto", size = S(13), weight = 600, extended = true })
end
fonts()
hook.Add("OnScreenSizeChanged", "Astral.Chat.Fonts", function() fonts() CH.Layout() end)

---------------------------------------------------------------------------
-- Messages
---------------------------------------------------------------------------
local function push(segments)
	table.insert(CH.Messages, { segs = segments, born = RealTime(), time = os.date("%H:%M") })
	if #CH.Messages > MAX_HISTORY then table.remove(CH.Messages, 1) end
	CH.scroll = 0
end

-- Convertit les arguments de chat.AddText en segments { couleur, texte }
local function segmentsOf(args)
	local segs, col = {}, color_white
	for _, a in ipairs(args) do
		if IsColor(a) or (istable(a) and a.r and a.g and a.b) then
			col = Color(a.r, a.g, a.b)
		elseif isentity(a) and IsValid(a) and a:IsPlayer() then
			segs[#segs + 1] = { team.GetColor(a:Team()), a:Nick() }
		elseif isentity(a) then
			segs[#segs + 1] = { col, "Console" }
		elseif a ~= nil then
			segs[#segs + 1] = { col, tostring(a) }
		end
	end
	return segs
end

CH.OriginalAddText = CH.OriginalAddText or chat.AddText
function chat.AddText(...)
	if enabled() then push(segmentsOf({ ... })) end
	return CH.OriginalAddText(...)
end

-- Messages système (connexions, changements de cvar serveur…)
hook.Add("ChatText", "Astral.Chat", function(_, _, text, kind)
	if not enabled() then return end
	if kind == "joinleave" or kind == "none" or kind == "servermsg" or kind == "namechange" or kind == "teamchange" then
		push({ { C.dim, text } })
	end
end)

---------------------------------------------------------------------------
-- Mise en page : découpage en lignes selon la largeur
---------------------------------------------------------------------------
local function wrap(msg, maxW)
	if msg.wrapW == maxW then return msg.lines end
	surface.SetFont("Astral.UI.Chat")
	local lines, cur, curW = {}, {}, 0
	local space = surface.GetTextSize(" ")
	local function newLine() lines[#lines + 1] = cur cur, curW = {}, 0 end
	for _, seg in ipairs(msg.segs) do
		local col = seg[1]
		for word, sep in string.gmatch((seg[2]:gsub("\n", " ")), "(%S*)(%s*)") do
			if word ~= "" then
				local ww = surface.GetTextSize(word)
				if curW + ww > maxW and curW > 0 then newLine() end
				-- Mot plus long que la ligne : découpe brute
				while ww > maxW do
					local cut = #word
					while cut > 1 and surface.GetTextSize(word:sub(1, cut)) > maxW do cut = cut - 1 end
					cur[#cur + 1] = { col, word:sub(1, cut), curW } newLine()
					word = word:sub(cut + 1) ww = surface.GetTextSize(word)
				end
				cur[#cur + 1] = { col, word, curW }
				curW = curW + ww
			end
			if sep ~= "" and curW > 0 then curW = curW + space end
		end
	end
	if #cur > 0 then newLine() end
	if #lines == 0 then lines[1] = {} end
	msg.wrapW, msg.lines = maxW, lines
	return lines
end

-- Dessine les messages de bas en haut dans la zone (x, y, w, h), en coordonnées de dessin.
-- ox, oy : origine écran de ces coordonnées (dans un Paint de panneau), pour le découpage (scissor) en coordonnées écran.
local function drawMessages(x, y, w, h, open, ox, oy)
	ox, oy = ox or 0, oy or 0
	local lineH = S(22)
	local timeW = S(40)
	local maxW = w - timeW - S(16)
	local now = RealTime()
	local bottom = y + h
	local skip = open and (CH.scroll or 0) or 0
	local shown = 0
	render.SetScissorRect(ox + x, oy + y, ox + x + w, oy + y + h, true)
	for i = #CH.Messages, 1, -1 do
		local msg = CH.Messages[i]
		local alpha = 255
		if not open then
			shown = shown + 1
			if shown > SHOW_CLOSED then break end
			local age = now - msg.born
			if age > FADE_AFTER + 1 then break end
			alpha = 255 * math.Clamp(FADE_AFTER + 1 - age, 0, 1)
		end
		local lines = wrap(msg, maxW)
		for l = #lines, 1, -1 do
			if skip > 0 then skip = skip - 1 else
				bottom = bottom - lineH
				if bottom < y - lineH then break end
				if not open then draw.RoundedBox(S(4), x, bottom, w, lineH, Color(8, 11, 22, 120 * alpha / 255)) end
				if l == 1 then draw.SimpleText(msg.time, "Astral.UI.ChatTime", x + S(8), bottom + lineH / 2, Color(C.dim.r, C.dim.g, C.dim.b, alpha * 0.8), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end
				for _, part in ipairs(lines[l]) do
					local col = part[1]
					draw.SimpleText(part[2], "Astral.UI.Chat", x + timeW + S(8) + part[3] + 1, bottom + lineH / 2 + 1, Color(0, 0, 0, alpha * 0.7), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
					draw.SimpleText(part[2], "Astral.UI.Chat", x + timeW + S(8) + part[3], bottom + lineH / 2, Color(col.r, col.g, col.b, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				end
			end
		end
		if bottom < y then break end
	end
	render.SetScissorRect(0, 0, 0, 0, false)
end

---------------------------------------------------------------------------
-- Fenêtre de saisie
---------------------------------------------------------------------------
local box
function CH.Rect()
	local w, h = math.min(S(560), ScrW() * 0.4), S(260)
	-- Au-dessus de la carte joueur du HUD (bas gauche, hauteur 150 + marge 24)
	return S(24), ScrH() - S(174) - S(16) - h, w, h
end
function CH.Layout() if IsValid(box) then local x, y, w, h = CH.Rect() box:SetPos(x, y) box:SetSize(w, h + S(44)) end end

function CH.IsOpen() return IsValid(box) and box:IsVisible() end

function CH.Close()
	if not CH.IsOpen() then return end
	box:SetVisible(false)
	box:KillFocus()
	hook.Run("FinishChat")
	hook.Run("ChatTextChanged", "")
end

function CH.Open(team)
	if not IsValid(box) then
		box = vgui.Create("EditablePanel")
		function box:Paint(w, h)
			draw.RoundedBox(S(10), 0, 0, w, h, Color(8, 11, 22, 225))
			draw.RoundedBoxEx(S(10), 0, 0, w, S(3), C.accent, true, true, false, false)
			local ox, oy = self:LocalToScreen(0, 0)
			drawMessages(S(4), S(8), w - S(8), h - S(60), true, ox, oy)
			if (CH.scroll or 0) > 0 then draw.SimpleText("▼ " .. CH.scroll .. " ligne(s) plus récente(s)", "Astral.UI.Tiny", w - S(12), h - S(52), C.accent, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM) end
		end
		function box:OnMouseWheeled(d)
			CH.scroll = math.max(0, (CH.scroll or 0) + d * 3)
			return true
		end
		local mode = vgui.Create("DPanel", box)
		mode:SetSize(S(84), S(32))
		function mode:Paint(w, h)
			local col = CH.team and C.accent2 or C.accent
			draw.RoundedBox(S(6), 0, 0, w, h, Color(col.r, col.g, col.b, 50))
			draw.SimpleText(CH.team and "FACTION" or "TOUS", "Astral.UI.Tiny", w / 2, h / 2, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		local entry = vgui.Create("DTextEntry", box)
		entry:SetFont("Astral.UI.Chat") entry:SetPaintBackground(false) entry:SetMaximumCharCount(126)
		entry:SetHistoryEnabled(true)
		function entry:Paint(w, h)
			draw.RoundedBox(S(6), 0, 0, w, h, C.panel)
			self:DrawTextEntryText(C.text, C.accent, C.text)
			if self:GetValue() == "" then
				draw.SimpleText("Message… (Entrée pour envoyer, Échap pour fermer)", "Astral.UI.Small", S(8), h / 2, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end
			local n = #self:GetValue()
			if n > 100 then draw.SimpleText(126 - n, "Astral.UI.Tiny", w - S(8), h / 2, n >= 126 and C.bad or C.warn, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER) end
		end
		function entry:OnChange() hook.Run("ChatTextChanged", self:GetValue()) end
		function entry:OnEnter()
			local text = string.Trim(self:GetValue())
			if text ~= "" then
				self:AddHistory(text)
				RunConsoleCommand(CH.team and "say_team" or "say", text)
			end
			self:SetText("")
			CH.Close()
		end
		-- Échap ferme ; le reste (Entrée → OnEnter, flèches → historique) reste le comportement d'origine
		local base = baseclass.Get("DTextEntry")
		function entry:OnKeyCodeTyped(code)
			if code == KEY_ESCAPE then CH.Close() gui.HideGameUI() return true end
			return base.OnKeyCodeTyped(self, code)
		end
		-- Clic sur la pastille : basculer entre « tous » et « faction »
		function mode:OnMousePressed() CH.team = not CH.team surface.PlaySound("ui/buttonclick.wav") end
		mode:SetCursor("hand")
		function box:PerformLayout(w, h)
			mode:SetPos(S(8), h - S(40))
			entry:SetPos(S(98), h - S(40)) entry:SetSize(w - S(106), S(32))
		end
		box.entry = entry
		CH.Layout()
	end
	CH.team = team and true or false
	CH.scroll = 0
	box:SetVisible(true)
	box:MakePopup()
	box.entry:SetText("")
	box.entry:RequestFocus()
	hook.Run("StartChat", CH.team)
end

-- Touches « parler » : messagemode (tous) / messagemode2 (équipe)
hook.Add("PlayerBindPress", "Astral.Chat", function(_, bind, pressed)
	if not pressed or not enabled() then return end
	if bind == "messagemode" or bind:find("^messagemode%s") then CH.Open(false) return true end
	if bind == "messagemode2" or bind:find("^messagemode2") then CH.Open(true) return true end
end)

-- API chat.* utilisée par d'autres addons
CH.OriginalOpen = CH.OriginalOpen or chat.Open
CH.OriginalClose = CH.OriginalClose or chat.Close
CH.OriginalGetPos = CH.OriginalGetPos or chat.GetChatBoxPos
CH.OriginalGetSize = CH.OriginalGetSize or chat.GetChatBoxSize
function chat.Open(mode) if enabled() then return CH.Open(mode == 0) end return CH.OriginalOpen(mode) end
function chat.Close() if enabled() then return CH.Close() end return CH.OriginalClose() end
function chat.GetChatBoxPos() if enabled() then local x, y = CH.Rect() return x, y end return CH.OriginalGetPos() end
function chat.GetChatBoxSize() if enabled() then local _, _, w, h = CH.Rect() return w, h end return CH.OriginalGetSize() end

-- Chat d'origine masqué ; nos derniers messages dessinés quand la saisie est fermée
hook.Add("HUDShouldDraw", "Astral.Chat", function(name)
	if name == "CHudChat" and enabled() then return false end
end)
hook.Add("HUDPaint", "Astral.Chat", function()
	if not enabled() or CH.IsOpen() then return end
	local x, y, w, h = CH.Rect()
	drawMessages(x, y, w, h, false)
end)

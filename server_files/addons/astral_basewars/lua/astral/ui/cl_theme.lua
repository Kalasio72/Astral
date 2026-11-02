-- Astral UI — charte graphique commune (client) : couleurs, polices adaptées à la résolution, primitives de dessin.
-- Toutes les interfaces Astral passent par ce fichier pour rester cohérentes.

Astral.UI = Astral.UI or {}
local UI = Astral.UI

UI.Colors = {
	bg = Color(10, 13, 26, 225),
	bgSolid = Color(12, 16, 32),
	panel = Color(20, 26, 48, 235),
	line = Color(44, 56, 96),
	accent = Color(110, 205, 255),
	accent2 = Color(170, 130, 255),
	text = Color(232, 236, 248),
	dim = Color(148, 158, 190),
	good = Color(110, 225, 150),
	warn = Color(255, 200, 90),
	bad = Color(255, 105, 115),
	hp = Color(240, 85, 100),
	armor = Color(90, 150, 255),
	xp = Color(170, 130, 255),
	power = Color(255, 210, 90),
}

-- Échelle selon la hauteur d'écran (1080p = 1)
function UI.Scale(v)
	return math.Round(v * math.Clamp(ScrH() / 1080, 0.7, 2))
end

local function createFonts()
	local S = UI.Scale
	surface.CreateFont("Astral.UI.Huge", { font = "Roboto", size = S(30), weight = 800, extended = true })
	surface.CreateFont("Astral.UI.Big", { font = "Roboto", size = S(22), weight = 800, extended = true })
	surface.CreateFont("Astral.UI.Text", { font = "Roboto", size = S(17), weight = 600, extended = true })
	surface.CreateFont("Astral.UI.Small", { font = "Roboto", size = S(14), weight = 600, extended = true })
	surface.CreateFont("Astral.UI.Tiny", { font = "Roboto", size = S(12), weight = 700, extended = true })
end
createFonts()
hook.Add("OnScreenSizeChanged", "Astral.UI.Fonts", createFonts)

-- Carte arrondie avec liseré d'accent à gauche
function UI.Card(x, y, w, h, accent)
	draw.RoundedBox(UI.Scale(8), x, y, w, h, UI.Colors.bg)
	if accent then draw.RoundedBoxEx(UI.Scale(8), x, y, UI.Scale(4), h, accent, true, false, true, false) end
end

local gradUp = Material("gui/gradient_up")
local gradRight = Material("gui/gradient")

-- Barre de progression arrondie avec léger reflet ; frac entre 0 et 1
function UI.Bar(x, y, w, h, frac, col, back)
	frac = math.Clamp(frac or 0, 0, 1)
	local r = math.floor(h / 2)
	draw.RoundedBox(r, x, y, w, h, back or Color(255, 255, 255, 18))
	if frac > 0 then
		local fw = math.max(h, w * frac)
		draw.RoundedBox(r, x, y, fw, h, col)
		surface.SetMaterial(gradUp)
		surface.SetDrawColor(255, 255, 255, 40)
		surface.DrawTexturedRect(x + r / 2, y, fw - r, h / 2)
	end
end

-- Halo dégradé horizontal (accent qui s'efface vers la droite)
function UI.Glow(x, y, w, h, col, alpha)
	surface.SetMaterial(gradRight)
	surface.SetDrawColor(col.r, col.g, col.b, alpha or 40)
	surface.DrawTexturedRectUV(x, y, w, h, 1, 0, 0, 1)
end

-- Tronque un texte avec « … » pour tenir dans maxW pixels
function UI.Truncate(text, font, maxW)
	text = tostring(text or "")
	surface.SetFont(font)
	if surface.GetTextSize(text) <= maxW then return text end
	local len = utf8.len(text) or #text
	while len > 1 do
		len = len - 1
		local cut = utf8.sub and utf8.sub(text, 1, len) or text:sub(1, len)
		if surface.GetTextSize(cut .. "…") <= maxW then return cut .. "…" end
	end
	return "…"
end

-- Texte avec ombre légère
function UI.Text(text, font, x, y, col, ax, ay)
	draw.SimpleText(text, font, x + 1, y + 1, Color(0, 0, 0, 160), ax, ay)
	return draw.SimpleText(text, font, x, y, col, ax, ay)
end

-- Interpolation douce d'une valeur affichée (par clé)
local smooth = {}
function UI.Smooth(key, target, speed)
	local cur = smooth[key]
	if not cur or math.abs(target - cur) > math.abs(target) * 10 + 1e12 then cur = target end
	cur = Lerp(math.min(FrameTime() * (speed or 8), 1), cur, target)
	if math.abs(cur - target) < 0.5 then cur = target end
	smooth[key] = cur
	return cur
end

---------------------------------------------------------------------------
-- Composants Derma au style Astral
---------------------------------------------------------------------------
function UI.Button(parent, text, col, onClick)
	local b = vgui.Create("DButton", parent)
	b:SetText(text) b:SetFont("Astral.UI.Text") b:SetTextColor(UI.Colors.text)
	b:SetTall(UI.Scale(34))
	function b:Paint(w, h)
		local base = self:GetDisabled() and Color(40, 44, 60) or (self:IsHovered() and (col or UI.Colors.accent) or UI.Colors.line)
		draw.RoundedBox(UI.Scale(6), 0, 0, w, h, base)
		self:SetTextColor(self:GetDisabled() and UI.Colors.dim or UI.Colors.text)
	end
	b.DoClick = onClick
	return b
end

function UI.Input(parent, placeholder)
	local e = vgui.Create("DTextEntry", parent)
	e:SetFont("Astral.UI.Text") e:SetTall(UI.Scale(32)) e:SetPlaceholderText(placeholder or "")
	e:SetPaintBackground(false)
	function e:Paint(w, h)
		draw.RoundedBox(UI.Scale(6), 0, 0, w, h, UI.Colors.panel)
		if self:HasFocus() then surface.SetDrawColor(UI.Colors.accent) surface.DrawOutlinedRect(0, 0, w, h, 1) end
		self:DrawTextEntryText(UI.Colors.text, UI.Colors.accent, UI.Colors.text)
		if self:GetValue() == "" and not self:HasFocus() then
			draw.SimpleText(self:GetPlaceholderText(), "Astral.UI.Text", UI.Scale(6), h / 2, UI.Colors.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
	end
	return e
end

function UI.Label(parent, text, font, col)
	local l = vgui.Create("DLabel", parent)
	l:SetFont(font or "Astral.UI.Text") l:SetTextColor(col or UI.Colors.text) l:SetText(text or "")
	l:SizeToContents()
	return l
end

-- Fenêtre modale simple, fermée par Échap ou par un clic sur la croix
function UI.Frame(title, w, h)
	local f = vgui.Create("DFrame")
	f:SetSize(w, h) f:Center() f:SetTitle("") f:MakePopup()
	function f:Paint(pw, ph)
		draw.RoundedBox(UI.Scale(10), 0, 0, pw, ph, UI.Colors.bgSolid)
		draw.RoundedBoxEx(UI.Scale(10), 0, 0, pw, UI.Scale(4), UI.Colors.accent, true, true, false, false)
		draw.SimpleText(title, "Astral.UI.Big", UI.Scale(16), UI.Scale(10), UI.Colors.text)
	end
	function f:OnKeyCodePressed(key) if key == KEY_ESCAPE then self:Close() end end
	-- Boutons Derma « réduire / agrandir » inutiles ; croix de fermeture au style Astral
	if IsValid(f.btnMinim) then f.btnMinim:SetVisible(false) end
	if IsValid(f.btnMaxim) then f.btnMaxim:SetVisible(false) end
	if IsValid(f.btnClose) then
		function f.btnClose:Paint(w, h)
			local hov = self:IsHovered()
			draw.RoundedBox(UI.Scale(6), 4, 2, w - 8, h - 4, hov and UI.Colors.bad or Color(255, 255, 255, 10))
			draw.SimpleText("✕", "Astral.UI.Text", w / 2, h / 2, hov and color_white or UI.Colors.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end
	return f
end

-- Nombres au format français : « 12 345 », puis abrégés « 1,2 M », « 98,8 M », « 1,5 Md », « 1 000 Md »
-- (BaseWars.NumberFormat affiche « 1.2 Million », « 1 Billion » : anglais et ambigu en français).
local function group(n)
	local s = tostring(math.floor(math.abs(n)))
	s = s:reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", "")
	return (n < 0 and "-" or "") .. s
end
function UI.Num(n)
	n = tonumber(n) or 0
	local a = math.abs(n)
	if a < 1e6 then return group(n) end
	local v, unit = n / 1e6, "M"
	if a >= 1e9 then v, unit = n / 1e9, "Md" end
	local s = math.abs(v) >= 100 and group(math.floor(v)) or string.format("%.1f", v):gsub("%.0$", ""):gsub("%.", ",")
	return s .. " " .. unit
end

function UI.Money(n)
	return BaseWars.LANG.CURRENCY .. UI.Num(math.floor(tonumber(n) or 0))
end

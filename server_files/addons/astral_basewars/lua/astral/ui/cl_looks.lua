-- Astral UI — habillage des machines listées dans astral/industry/sh_looks.lua (générateurs, coffres, distributeurs,
-- point de réapparition, machines Astral Industries). Même principe que les imprimantes (cl_printerlook.lua) :
-- coque métal teintée, flancs lumineux (UI.DrawCasing), façade 3D2D sur le dessus tournée vers le joueur, avec une
-- animation propre à chaque famille. Remplace ENT.Draw sur chaque instance ; en cas d'erreur, dessin d'origine.

local UI = Astral.UI
local C = UI.Colors
local L = Astral.Looks
local R = Astral.Resources

surface.CreateFont("Astral.Look.Title", { font = "Roboto", size = 40, weight = 900, extended = true })
surface.CreateFont("Astral.Look.Body", { font = "Roboto", size = 26, weight = 700, extended = true })
surface.CreateFont("Astral.Look.Small", { font = "Roboto", size = 21, weight = 700, extended = true })
surface.CreateFont("Astral.Look.Icon", { font = "Roboto", size = 110, weight = 900, extended = true })

local metal = Material("models/debug/debugwhite")
local gradDown = Material("gui/gradient_down")
local SCALE = 0.05
local DRAW_DIST, SIDE_DIST = 600 ^ 2, 420 ^ 2
local dark, darker, edge = Color(14, 17, 28), Color(6, 8, 14), Color(38, 46, 74)
local function alpha(c, a) return Color(c.r, c.g, c.b, a) end

local function rot(x, y, w, h, ang, col)
	surface.SetDrawColor(col)
	surface.DrawTexturedRectRotated(x, y, w, h, ang)
end

-- Pourcentage dans un texte d'état (« croissance 42 % », « … 75 % »)
local function percentIn(s)
	local p = tonumber((s or ""):match("(%d+)%s*%%"))
	return p and math.Clamp(p / 100, 0, 1) or nil
end

---------------------------------------------------------------------------
-- Animations (centrées en cx, cy, rayon r)
---------------------------------------------------------------------------
local ANIM = {}

function ANIM.gen(ent, cx, cy, r, col, on, t)
	draw.NoTexture()
	local glow = on and (0.6 + 0.4 * math.sin(t * 3)) or 0.15
	draw.RoundedBox(r, cx - r, cy - r, r * 2, r * 2, alpha(col, 30 * glow))
	for ring = 1, 3 do
		local rr = r * (0.35 + ring * 0.2)
		local n = 10 + ring * 4
		local speed = (ring % 2 == 0 and -1 or 1) * (on and (30 + ring * 25) or 0)
		for i = 0, n - 1 do
			local a = math.rad(t * speed + i * 360 / n)
			if i % 3 ~= 0 then
				rot(cx + math.cos(a) * rr, cy - math.sin(a) * rr, rr * 6.28 / n * 0.62, 8, math.deg(a) + 90, alpha(col, (90 + ring * 50) * (on and 1 or 0.3)))
			end
		end
	end
	local core = r * (0.28 + 0.04 * math.sin(t * 5))
	draw.RoundedBox(core, cx - core, cy - core, core * 2, core * 2, alpha(col, on and 255 or 60))
	draw.RoundedBox(core * 0.5, cx - core * 0.5, cy - core * 0.5, core, core, Color(255, 255, 255, on and 230 * glow or 30))
end

function ANIM.drill(ent, cx, cy, r, col, on, t)
	draw.NoTexture()
	ent.AstralSpin = ((ent.AstralSpin or 0) + FrameTime() * (on and 360 or 0)) % 360
	draw.RoundedBox(r, cx - r, cy - r, r * 2, r * 2, edge)
	draw.RoundedBox(r - 8, cx - r + 8, cy - r + 8, (r - 8) * 2, (r - 8) * 2, darker)
	for i = 0, 5 do
		local a = ent.AstralSpin + i * 60
		local ra = math.rad(a)
		rot(cx + math.cos(ra) * r * 0.42, cy - math.sin(ra) * r * 0.42, r * 0.75, 22, a + 25, alpha(col, on and 230 or 70))
	end
	draw.RoundedBox(24, cx - 24, cy - 24, 48, 48, col)
end

function ANIM.refinery(ent, cx, cy, r, col, on, t)
	draw.RoundedBox(16, cx - r, cy - r, r * 2, r * 2, darker)
	local n, bw = 7, (r * 2 - 40) / 7
	for i = 0, n - 1 do
		local hgt = on and (0.35 + 0.55 * math.abs(math.sin(t * (2 + i * 0.37) + i))) or 0.08
		local h = (r * 2 - 40) * hgt
		local x = cx - r + 20 + i * bw
		draw.RoundedBox(6, x + 3, cy + r - 20 - h, bw - 6, h, Color(255, 200 - 120 * hgt, 60, 230))
		draw.RoundedBox(6, x + 3, cy + r - 20 - h, bw - 6, 10, Color(255, 240, 180, on and 220 or 40))
	end
	surface.SetMaterial(gradDown)
	surface.SetDrawColor(255, 120, 40, on and 60 or 0)
	surface.DrawTexturedRectUV(cx - r, cy - r, r * 2, r * 2, 0, 1, 1, 0)
end

function ANIM.greenhouse(ent, cx, cy, r, col, on, t)
	draw.RoundedBox(16, cx - r, cy - r, r * 2, r * 2, darker)
	-- Lampes de croissance
	for i = 0, 3 do
		draw.RoundedBox(4, cx - r + 18 + i * (r * 2 - 36) / 4, cy - r + 14, (r * 2 - 36) / 4 - 10, 8, on and Color(255, 120, 230, 220) or edge)
	end
	surface.SetMaterial(gradDown)
	surface.SetDrawColor(255, 120, 230, on and 40 or 0)
	surface.DrawTexturedRect(cx - r + 10, cy - r + 22, r * 2 - 20, r)
	draw.NoTexture()
	local grow = percentIn(ent:GetNW2String("AstralStatus", "")) or 0
	local crop = R and R.Get(ent:GetNW2String("AstralCrop", ""))
	local pc = crop and crop.color or col
	local base, top = cy + r - 26, cy + r - 26 - (r * 1.5) * math.max(grow, 0.08)
	draw.RoundedBox(4, cx - 4, top, 8, base - top, Color(80, 170, 80))
	local leaves = math.floor(2 + grow * 8)
	for i = 1, leaves do
		local y = base - (base - top) * i / (leaves + 1)
		local side = i % 2 == 0 and 1 or -1
		local sway = math.sin(t * 1.5 + i) * 4
		rot(cx + side * 26 + sway, y, 48, 18, side * 25, alpha(col, 230))
	end
	if grow > 0.85 then draw.RoundedBox(14, cx - 14, top - 18, 28, 28, pc) end
	draw.RoundedBox(6, cx - r + 14, base + 6, r * 2 - 28, 12, Color(90, 60, 40))
end

function ANIM.battery(ent, cx, cy, r, col, on, t)
	local frac = ent.GetMaxPower and ent:GetMaxPower() > 0 and ent:GetPower() / ent:GetMaxPower() or 0
	draw.RoundedBox(14, cx - r * 0.7, cy - r, r * 1.4, r * 2, edge)
	draw.RoundedBox(8, cx - r * 0.25, cy - r - 14, r * 0.5, 18, edge)
	local n = 5
	local ch = (r * 2 - 30 - (n - 1) * 8) / n
	for i = 0, n - 1 do
		local filled = frac >= (i + 0.5) / n
		local y = cy + r - 15 - (i + 1) * ch - i * 8
		local blink = (not filled and frac >= i / n) and (math.floor(t * 3) % 2 == 0)
		draw.RoundedBox(6, cx - r * 0.7 + 14, y, r * 1.4 - 28, ch, (filled or blink) and col or darker)
	end
end

function ANIM.container(ent, cx, cy, r, col, on, t)
	local inv = Astral.Inv and Astral.Inv.Decode(ent:GetNW2String("AstralInv", "")) or {}
	local items = {}
	for _, id in ipairs(R and R.order or {}) do if inv[id] then items[#items + 1] = R.list[id] end end
	local count = Astral.Inv and Astral.Inv.Count(inv) or 0
	local filled = math.min(9, math.ceil(count / 20))
	local s = (r * 2 - 32) / 3
	for i = 0, 8 do
		local x, y = cx - r + 8 + (i % 3) * (s + 8), cy - r + 8 + math.floor(i / 3) * (s + 8)
		local it = items[(i % math.max(#items, 1)) + 1]
		if i < filled then
			local c = it and it.color or col
			draw.RoundedBox(8, x, y, s, s, Color(c.r * 0.5, c.g * 0.5, c.b * 0.5))
			draw.RoundedBox(6, x + 6, y + 6, s - 12, s * 0.28, c)
		else
			draw.RoundedBox(8, x, y, s, s, darker)
		end
	end
end

function ANIM.fabricator(ent, cx, cy, r, col, on, t)
	draw.NoTexture()
	local frac = percentIn(ent:GetNW2String("AstralStatus", "")) or (on and (t * 0.2 % 1) or 0)
	local n = 48
	for i = 0, n - 1 do
		local a = math.rad(90 - i * 360 / n)
		local lit = i / n <= frac
		rot(cx + math.cos(a) * r * 0.8, cy - math.sin(a) * r * 0.8, 14, 30, math.deg(a) + 90, lit and col or edge)
	end
	draw.SimpleText(math.floor(frac * 100) .. " %", "Astral.Look.Title", cx, cy, C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

function ANIM.dispenser(ent, cx, cy, r, col, on, t)
	local look = L.Get(ent)
	local pulse = 0.6 + 0.4 * math.sin(t * 2.5)
	draw.RoundedBox(r, cx - r, cy - r, r * 2, r * 2, alpha(col, 50 * pulse))
	draw.RoundedBox(r - 10, cx - r + 10, cy - r + 10, (r - 10) * 2, (r - 10) * 2, darker)
	draw.SimpleText(look and look.icon or "+", "Astral.Look.Icon", cx, cy, alpha(col, on and 255 or 80), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

-- Fermes Astral (astral/farms/sh_farms.lua) : une animation selon la machine
local FARM = {}

function FARM.plant(ent, cx, cy, r, col, on, t, prog)
	draw.RoundedBox(16, cx - r, cy - r, r * 2, r * 2, darker)
	for i = 0, 2 do draw.RoundedBox(4, cx - r + 16 + i * (r * 2 - 32) / 3, cy - r + 12, (r * 2 - 32) / 3 - 8, 8, on and Color(255, 140, 230, 220) or edge) end
	draw.NoTexture()
	local base, top = cy + r - 24, cy + r - 24 - r * 1.45 * math.max(prog, 0.1)
	draw.RoundedBox(4, cx - 4, top, 8, base - top, Color(70, 150, 70))
	-- Feuilles à 5 folioles
	local n = math.floor(2 + prog * 6)
	for i = 1, n do
		local y = base - (base - top) * i / (n + 1)
		local s = 0.6 + 0.4 * (1 - i / (n + 1))
		local sway = math.sin(t * 1.3 + i) * 3
		for k = -2, 2 do
			rot(cx + sway + k * 12 * s, y - math.abs(k) * 4, 46 * s, 10, 90 + k * 28, alpha(col, 230))
		end
	end
	draw.RoundedBox(6, cx - r + 14, base + 4, r * 2 - 28, 12, Color(90, 60, 40))
end

function FARM.dryer(ent, cx, cy, r, col, on, t, prog)
	draw.RoundedBox(16, cx - r, cy - r, r * 2, r * 2, darker)
	draw.NoTexture()
	for row = 0, 2 do
		local y = cy - r + 24 + row * (r * 2 - 40) / 3
		draw.RoundedBox(2, cx - r + 14, y, r * 2 - 28, 4, edge)
		for k = 0, 4 do
			local sway = math.sin(t * 1.2 + k + row) * 3
			local dry = math.Clamp(prog * 1.3 - row * 0.15, 0, 1)
			local c = Color(Lerp(dry, 90, col.r), Lerp(dry, 170, col.g), Lerp(dry, 70, col.b))
			rot(cx - r + 34 + k * (r * 2 - 60) / 4 + sway, y + 26, 18, 40, sway * 3, c)
		end
	end
	surface.SetMaterial(gradDown)
	surface.SetDrawColor(255, 140, 40, on and 30 or 0)
	surface.DrawTexturedRectUV(cx - r, cy - r, r * 2, r * 2, 0, 1, 1, 0)
end

local function flask(x, y, w, h, liquid, col, t, bubbles)
	draw.RoundedBox(8, x, y, w, h, edge)
	draw.RoundedBox(6, x + 4, y + 4, w - 8, h - 8, darker)
	local lh = (h - 8) * liquid
	draw.RoundedBox(6, x + 4, y + h - 4 - lh, w - 8, lh, alpha(col, 200))
	if bubbles then
		for i = 1, 4 do
			local p = (t * 0.8 + i * 0.27) % 1
			local bx = x + 10 + (i * 17) % (w - 24)
			draw.RoundedBox(4, bx, y + h - 8 - lh * p, 8, 8, Color(255, 255, 255, 140 * (1 - p)))
		end
	end
end

function FARM.lab(ent, cx, cy, r, col, on, t, prog)
	draw.RoundedBox(16, cx - r, cy - r, r * 2, r * 2, darker)
	local w = (r * 2 - 50) / 3
	for i = 0, 2 do
		local lvl = math.Clamp(prog * 1.5 - i * 0.25, 0.1, 0.9)
		flask(cx - r + 15 + i * (w + 10), cy - r * 0.6 + (i % 2) * 20, w, r * 1.3, lvl, i == 2 and col or Color(150, 200, 120), t + i, on)
	end
end

function FARM.cook(ent, cx, cy, r, col, on, t, prog)
	draw.RoundedBox(16, cx - r, cy - r, r * 2, r * 2, darker)
	local heat = ent:GetNW2Float("AstralFarmHeat", 20)
	local hf = math.Clamp((heat - 20) / 80, 0, 1)
	local danger = heat >= 80 and math.floor(t * 4) % 2 == 0
	flask(cx - r + 16, cy - r * 0.7, r * 1.25, r * 1.5, 0.35 + prog * 0.5, col, t, on)
	-- Thermomètre
	local tx, th = cx + r * 0.5, r * 1.6
	draw.RoundedBox(10, tx, cy - th / 2, 22, th, edge)
	local fill = th * hf
	local hc = heat >= 80 and C.bad or (heat >= 60 and C.warn or C.good)
	draw.RoundedBox(8, tx + 4, cy + th / 2 - 4 - fill, 14, fill, hc)
	draw.SimpleText(math.floor(heat) .. "°", "Astral.Look.Small", tx + 11, cy - th / 2 - 22, hc, TEXT_ALIGN_CENTER)
	if danger then draw.RoundedBox(16, cx - r, cy - r, r * 2, r * 2, Color(255, 60, 60, 50)) end
end

function FARM.rockets(ent, cx, cy, r, col, on, t, prog)
	draw.RoundedBox(16, cx - r, cy - r, r * 2, r * 2, darker)
	draw.NoTexture()
	local stock = ent:GetNW2Int("AstralFarmStock", 0)
	for i = 0, 4 do
		local x = cx - r + 24 + i * (r * 2 - 48) / 4
		local ready = i < stock
		local c = ready and HSVToColor((i * 70 + t * 30) % 360, 0.7, 1) or (i == stock and alpha(col, 120 + 100 * prog) or edge)
		draw.RoundedBox(4, x - 9, cy - r * 0.5, 18, r * 1.1, c)
		rot(x, cy - r * 0.5 - 8, 22, 22, 45, c)
		draw.RoundedBox(2, x - 2, cy + r * 0.6, 4, 18, Color(200, 200, 200))
	end
end

function ANIM.farm(ent, cx, cy, r, col, on, t)
	local def = ent.Farm
	local fn = def and FARM[def.anim]
	if fn then fn(ent, cx, cy, r, col, on, t, ent:GetNW2Float("AstralFarmProg", 0)) end
end

function ANIM.spawn(ent, cx, cy, r, col, on, t)
	for k = 0, 2 do
		local p = (t * 0.5 + k / 3) % 1
		local rr = r * (0.25 + p * 0.75)
		draw.RoundedBox(rr, cx - rr, cy - rr, rr * 2, rr * 2, alpha(col, 120 * (1 - p)))
	end
	draw.RoundedBox(r * 0.3, cx - r * 0.3, cy - r * 0.3, r * 0.6, r * 0.6, col)
end

---------------------------------------------------------------------------
-- Façade du dessus
---------------------------------------------------------------------------
local function name(ent)
	local look = L.Get(ent)
	if look and look.label then return look.label end
	return UI.ItemLabel and UI.ItemLabel(ent.PrintName or "Machine") or (ent.PrintName or "Machine")
end

-- Lignes d'information selon la famille
local function infoLines(ent, look)
	local lines = {}
	if look.style == "gen" then
		lines[#lines + 1] = { "Production", UI.Num(ent.PowerGenerated or 0) .. " / cycle", C.good }
		lines[#lines + 1] = { "Portée", math.floor((ent.TransmitRadius or 600) * 0.01905) .. " m", C.text }
	elseif look.style == "dispenser" then
		lines[#lines + 1] = { "Utilisation", "Appuie sur E", C.accent }
	elseif look.style == "spawn" then
		lines[#lines + 1] = { "Réapparition", "Ici après la mort", C.accent }
	elseif look.style == "farm" and ent.Farm then
		local def, F = ent.Farm, Astral.Farms
		local stock = ent:GetNW2Int("AstralFarmStock", 0)
		lines[#lines + 1] = { F.Products[def.product].name, "lot " .. math.floor(ent:GetNW2Float("AstralFarmProg", 0) * 100) .. " %", def.color }
		lines[#lines + 1] = { "En attente", stock .. " / " .. def.stock .. " lots", stock >= def.stock and C.warn or C.text }
		if stock > 0 then lines[#lines + 1] = { "Maj + E : récolter  ·  E : menu", nil, C.accent } end
		if def.heat then
			local heat = ent:GetNW2Float("AstralFarmHeat", 20)
			lines[#lines + 1] = { "Cuve", math.floor(heat) .. " °C", heat >= 80 and C.bad or C.text }
		end
	else
		local st = ent:GetNW2String("AstralStatus", "")
		if st ~= "" then lines[#lines + 1] = { st, nil, st:find("Hors tension") and C.bad or C.text } end
		local inv = Astral.Inv and Astral.Inv.Decode(ent:GetNW2String("AstralInv", "")) or {}
		for _, id in ipairs(R and R.order or {}) do
			if inv[id] and #lines < 4 then lines[#lines + 1] = { R.list[id].name, "× " .. UI.Num(inv[id]), R.list[id].color } end
		end
	end
	return lines
end

local function bar(x, y, w, label, frac, col, txt)
	draw.SimpleText(label, "Astral.Look.Small", x, y, C.dim)
	draw.SimpleText(txt, "Astral.Look.Small", x + w, y, C.text, TEXT_ALIGN_RIGHT)
	draw.RoundedBox(5, x, y + 28, w, 10, darker)
	if frac > 0 then draw.RoundedBox(5, x, y + 28, math.max(10, w * math.Clamp(frac, 0, 1)), 10, col) end
end

local function face(ent, look, FW, FH, col, on, t)
	draw.RoundedBox(28, 0, 0, FW, FH, alpha(col, on and 150 or 40))
	draw.RoundedBox(26, 3, 3, FW - 6, FH - 6, edge)
	draw.RoundedBox(24, 6, 6, FW - 12, FH - 12, dark)
	surface.SetMaterial(gradDown)
	surface.SetDrawColor(col.r, col.g, col.b, on and 22 or 6)
	surface.DrawTexturedRect(6, 6, FW - 12, FH * 0.6)

	-- Zone animée et zone d'informations : côte à côte si la face est large, empilées sinon
	local vertical = FW < 620
	local ax, ay, ar, ix, iy, iw
	if look.style == "vault" then
		-- Écran du coffre (DrawDisplay, 432 × 272) dessiné à part ; ici le cadre et la plaque
		local sx = (FW - 432) / 2
		draw.RoundedBox(18, sx - 6, 24, 444, 284, alpha(col, on and 90 or 20))
		draw.RoundedBox(16, sx - 4, 26, 440, 280, darker)
		ax, ay, ar = FW / 2, 300 + (FH - 300) / 2 - 30, math.min(FH - 300, FW) / 2 - 50
		ix, iy, iw = 40, FH - 70, FW - 80
		draw.SimpleText(look.brand, "Astral.Look.Title", FW / 2, ay - 10, C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText(name(ent), "Astral.Look.Body", FW / 2, ay + 34, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	elseif vertical then
		ar = math.min(FW, FH) * 0.24
		ax, ay = FW / 2, 30 + ar
		ix, iy, iw = 28, ay + ar + 20, FW - 56
	else
		ar = math.min(FH * 0.42, FW * 0.22)
		ax, ay = FW - 40 - ar, FH / 2
		ix, iy, iw = 40, 34, FW - ar * 2 - 110
	end
	if look.style ~= "vault" then
		local anim = ANIM[look.style]
		if anim then anim(ent, ax, ay, ar, col, on, t) end
		-- Titre
		draw.SimpleText(UI.Truncate(name(ent), "Astral.Look.Title", iw), "Astral.Look.Title", ix, iy, C.text)
		draw.RoundedBox(3, ix, iy + 48, math.min(iw, 120), 5, col)
		local y = iy + 66
		for _, l in ipairs(infoLines(ent, look)) do
			if y > FH - 110 then break end
			if l[2] then
				draw.SimpleText(UI.Truncate(l[1], "Astral.Look.Small", iw * 0.55), "Astral.Look.Small", ix, y, C.dim)
				draw.SimpleText(l[2], "Astral.Look.Body", ix + iw, y - 3, l[3], TEXT_ALIGN_RIGHT)
			else
				draw.SimpleText(UI.Truncate(l[1], "Astral.Look.Body", iw), "Astral.Look.Body", ix, y - 3, l[3])
			end
			y = y + 36
		end
	end
	-- Barres : énergie (si la machine en a) et points de vie
	local by = FH - 60
	if ent.GetMaxPower and ent:GetMaxPower() > 0 and look.style ~= "vault" then
		local p, mp = ent:GetPower(), ent:GetMaxPower()
		bar(ix, by - 50, iw, "Énergie", p / mp, C.warn, UI.Num(p) .. " / " .. UI.Num(mp))
	end
	local hp, hmax = math.max(ent:Health(), 0), math.max(ent:GetMaxHealth(), 1)
	if look.style ~= "vault" then bar(ix, by, iw, "Points de vie", hp / hmax, hp / hmax < 0.25 and C.bad or C.good, UI.Num(hp)) end
	-- Voyant
	local led = on and C.good or C.bad
	draw.RoundedBox(12, FW - 40, 16, 24, 24, alpha(led, 60))
	draw.RoundedBox(8, FW - 36, 20, 16, 16, led)
end

local function powered(ent)
	if ent.IsGenerator then return not (ent.BadlyDamaged and ent:BadlyDamaged()) end
	if ent.IsPowered then return ent:IsPowered() end
	return true
end

local function lookDraw(self, look)
	local col = look.color
	if self:GetClass() == "bw_vault_vip" then col = HSVToColor(CurTime() % 6 * 60, 0.6, 1) end
	render.MaterialOverride(metal)
	render.SetColorModulation(0.16 + col.r / 255 * 0.12, 0.17 + col.g / 255 * 0.12, 0.22 + col.b / 255 * 0.12)
	self:DrawModel()
	render.SetColorModulation(1, 1, 1)
	render.MaterialOverride(nil)

	local dist = EyePos():DistToSqr(self:GetPos())
	if dist > DRAW_DIST then return end
	local on = powered(self)
	if dist < SIDE_DIST then UI.DrawCasing(self, col, { title = look.brand, sub = name(self), lit = on }) end

	local mins, maxs = self:OBBMins(), self:OBBMaxs()
	local FW, FH = (maxs.y - mins.y) / SCALE, (maxs.x - mins.x) / SCALE
	local ang = self:GetAngles()
	ang:RotateAroundAxis(ang:Up(), 90)
	if (EyePos() - self:GetPos()):Dot(ang:Right()) < 0 then ang:RotateAroundAxis(ang:Up(), 180) end
	local top = self:LocalToWorld(Vector((maxs.x + mins.x) / 2, (maxs.y + mins.y) / 2, maxs.z + 0.15))
	local pos = top - ang:Forward() * (FW / 2 * SCALE) - ang:Right() * (FH / 2 * SCALE)
	cam.Start3D2D(pos, ang, SCALE)
		face(self, look, FW, FH, col, on, RealTime() + self:EntIndex())
	cam.End3D2D()
	if look.style == "vault" and self.DrawDisplay then
		local spos = pos + ang:Forward() * ((FW - 432) / 2 * SCALE) + ang:Right() * (30 * SCALE) + ang:Up() * 0.05
		cam.Start3D2D(spos, ang, SCALE)
			pcall(self.DrawDisplay, self, spos, ang, SCALE)
		cam.End3D2D()
	end
end

local function patch(ent)
	if not IsValid(ent) or ent.AstralLook or not ent.Draw then return end
	local look = L.Get(ent)
	if not look then return end
	local original = ent.Draw
	ent.AstralLook = true
	ent.Draw = function(self, flags)
		local ok, err = pcall(lookDraw, self, look)
		if not ok then
			render.SetColorModulation(1, 1, 1)
			render.MaterialOverride(nil)
			ErrorNoHalt("[Astral:looks] " .. self:GetClass() .. " : " .. tostring(err) .. "\n")
			self.Draw = original
		end
	end
end

---------------------------------------------------------------------------
-- Machines au modèle fonctionnel (tourelles, radar, tesla…) : modèle conservé, plaque holographique
-- (nom, propriétaire, PV) et anneau lumineux au sol
---------------------------------------------------------------------------
local TAGGED = {
	{ find = "bw_turret_*", label = "Tourelle", color = Color(255, 105, 115) },
	{ find = "bw_radar", label = "Radar", color = Color(110, 205, 255) },
	{ find = "bw_tesla", label = "Bobine Tesla", color = Color(170, 130, 255) },
	{ find = "bw_healthpad", label = "Plateforme de soin", color = Color(110, 225, 150) },
	{ find = "bw_vendingmachine", label = "Distributeur automatique", color = Color(255, 200, 90) },
}
surface.CreateFont("Astral.Tag.Name", { font = "Roboto", size = 40, weight = 900, extended = true })
surface.CreateFont("Astral.Tag.Sub", { font = "Roboto", size = 26, weight = 700, extended = true })

local function tagDraw(self, tag)
	local d = EyePos():Distance(self:GetPos())
	if d > 450 then return end
	local a = math.Clamp((450 - d) / 120, 0, 1)
	local col = tag.color
	local mins, maxs = self:OBBMins(), self:OBBMaxs()
	-- Anneau au sol
	local r = math.max(maxs.x - mins.x, maxs.y - mins.y) * 6
	cam.Start3D2D(self:GetPos() + Vector(0, 0, 1), Angle(0, 0, 0), 0.1)
		local p = (RealTime() * 0.5 + self:EntIndex() * 0.1) % 1
		local rr = r * (0.8 + p * 0.4)
		draw.RoundedBox(rr, -rr, -rr, rr * 2, rr * 2, Color(col.r, col.g, col.b, 50 * (1 - p) * a))
	cam.End3D2D()
	-- Plaque
	local pos = self:LocalToWorld(Vector(0, 0, maxs.z + 14))
	local ang = Angle(0, (EyePos() - pos):Angle().y + 90, 90)
	local name = (UI.ItemLabel and self.PrintName and UI.ItemLabel(self.PrintName)) or tag.label
	if name == self.PrintName then name = tag.label end
	local owner = self.CPPIGetOwner and self:CPPIGetOwner()
	local hp, hmax = math.max(self:Health(), 0), math.max(self:GetMaxHealth(), 1)
	cam.Start3D2D(pos, ang, 0.05)
		surface.SetFont("Astral.Tag.Name")
		local w = math.max(surface.GetTextSize(name) + 60, 300)
		draw.RoundedBox(16, -w / 2, -100, w, 110, Color(10, 13, 26, 215 * a))
		draw.RoundedBoxEx(16, -w / 2, -100, w, 6, Color(col.r, col.g, col.b, 255 * a), true, true, false, false)
		draw.SimpleText(name, "Astral.Tag.Name", 0, -88, Color(232, 236, 248, 255 * a), TEXT_ALIGN_CENTER)
		draw.SimpleText(IsValid(owner) and owner:Nick() or "Monde", "Astral.Tag.Sub", 0, -44, Color(col.r, col.g, col.b, 230 * a), TEXT_ALIGN_CENTER)
		draw.RoundedBox(4, -w / 2 + 20, -10, w - 40, 8, Color(6, 8, 14, 230 * a))
		draw.RoundedBox(4, -w / 2 + 20, -10, (w - 40) * math.Clamp(hp / hmax, 0, 1), 8, Color(110, 225, 150, 255 * a))
	cam.End3D2D()
end

local function patchTag(ent, tag)
	if not IsValid(ent) or ent.AstralTag or not ent.Draw then return end
	local original = ent.Draw
	ent.AstralTag = true
	ent.Draw = function(self, flags)
		original(self, flags)
		local ok, err = pcall(tagDraw, self, tag)
		if not ok then ErrorNoHalt("[Astral:looks] " .. self:GetClass() .. " : " .. tostring(err) .. "\n") self.Draw = original end
	end
end

local function sweep()
	for class in pairs(L.Classes) do for _, e in ipairs(ents.FindByClass(class)) do patch(e) end end
	for _, tag in ipairs(TAGGED) do for _, e in ipairs(ents.FindByClass(tag.find)) do patchTag(e, tag) end end
end
hook.Add("OnEntityCreated", "Astral.Looks", function(ent) timer.Simple(1, function() patch(ent) end) end)
hook.Add("InitPostEntity", "Astral.Looks", sweep)
timer.Create("Astral.Looks.Sweep", 2, 0, sweep)
sweep()

-- Astral UI — boîtier des imprimantes (bw_printer_*) : bloc PHX (sh_printers.lua) habillé côté client.
--   Coque : métal sombre brillant, légèrement teinté par la couleur du tier.
--   Flancs : bande lumineuse à la couleur du tier, grilles d'aération, logo « ASTRAL PRINT » sur les grands côtés.
--   Dessus : façade avec liseré lumineux, écran (ENT.DrawDisplay, voir cl_printers.lua), ventilateur animé,
--            plaque du modèle et voyants des améliorations.
-- Remplace ENT.Draw sur chaque instance, y compris les imprimantes SpaceVX qui avaient leur propre Draw (bois,
-- plastique, ferraille, VIP) : toutes partagent le même boîtier. En cas d'erreur, retour au dessin d'origine.
-- UI.DrawCasing (flancs lumineux) est aussi utilisé par la Banque Astral (entities/bw_astral_bank.lua).
--
-- Repère 3D2D (mesuré en jeu avec cam.GetModelMatrix) : x suit ang:Forward(), y suit ang:Right(), la face regarde ang:Up().

local UI = Astral.UI
local C = UI.Colors
local P = Astral.Printers

surface.CreateFont("Astral.PrinterLook.Brand", { font = "Roboto", size = 36, weight = 900, extended = true })
surface.CreateFont("Astral.PrinterLook.Side", { font = "Roboto", size = 56, weight = 900, extended = true })
surface.CreateFont("Astral.PrinterLook.SideSmall", { font = "Roboto", size = 30, weight = 700, extended = true })
surface.CreateFont("Astral.PrinterLook.Tag", { font = "Roboto", size = 20, weight = 800, extended = true })

-- Matériau éclairé (models/shiny s'affiche quasiment sans ombrage et écrase la teinte sombre : constaté en jeu)
local metal = Material("models/debug/debugwhite")
local gradDown = Material("gui/gradient_down")
local gradUp = Material("gui/gradient_up")
local SCALE = 0.05
local SW, SH = 432, 272          -- écran SpaceVX/Astral (cl_printers.lua)
local DRAW_DIST = 600 ^ 2        -- façade et écran
local SIDE_DIST = 420 ^ 2        -- flancs (détails moins visibles de loin)
local SHORT = { speed = "VITESSE", overclock = "OVERCLOCK", capacity = "CAPACITÉ", armor = "BLINDAGE" }
local dark, darker, edge = Color(14, 17, 28), Color(6, 8, 14), Color(38, 46, 74)

local function alpha(c, a) return Color(c.r, c.g, c.b, a) end

-- Teinte de la coque : métal sombre avec une pointe de la couleur du tier
local function bodyTint(col)
	return 0.16 + col.r / 255 * 0.14, 0.17 + col.g / 255 * 0.14, 0.22 + col.b / 255 * 0.14
end

-- Halo lumineux (bande + dégradé) : imite une LED diffusante
local function glowBar(x, y, w, h, col, intensity)
	draw.RoundedBox(h / 2, x, y, w, h, col)
	surface.SetMaterial(gradDown)
	surface.SetDrawColor(col.r, col.g, col.b, 70 * intensity)
	surface.DrawTexturedRect(x, y + h, w, h * 5)
	surface.SetMaterial(gradUp)
	surface.SetDrawColor(col.r, col.g, col.b, 50 * intensity)
	surface.DrawTexturedRect(x, y - h * 3, w, h * 3)
end

---------------------------------------------------------------------------
-- Flancs : une face 3D2D par côté du bloc (repère calculé depuis la normale, texte toujours à l'endroit)
---------------------------------------------------------------------------
local SIDES = { Vector(1, 0, 0), Vector(-1, 0, 0), Vector(0, 1, 0), Vector(0, -1, 0) }

-- opts : { title, sub, skip = { [index] = true }, lit = bool }
function UI.DrawCasing(ent, col, opts)
	opts = opts or {}
	local mins, maxs = ent:OBBMins(), ent:OBBMaxs()
	local up = ent:GetUp()
	local height = (maxs.z - mins.z)
	local lit = opts.lit ~= false
	local pulse = lit and (0.75 + 0.25 * math.sin(RealTime() * 2 + ent:EntIndex())) or 0.15
	for i, n in ipairs(SIDES) do
		if not (opts.skip and opts.skip[i]) then
			local half = n.x ~= 0 and maxs.x or maxs.y
			local length = n.x ~= 0 and (maxs.y - mins.y) or (maxs.x - mins.x)
			local normal = ent:LocalToWorld(n) - ent:GetPos()
			-- Ne dessine que les flancs tournés vers la caméra
			local center = ent:LocalToWorld(n * (math.abs(half) + 0.15) + Vector(0, 0, (maxs.z + mins.z) / 2))
			if (EyePos() - center):Dot(normal) > 0 then
				local tangent = up:Cross(normal)
				local ang = tangent:AngleEx(normal)
				-- Échelle proportionnelle à la hauteur du bloc : même rendu sur une imprimante plate et un gros réacteur
				local sc = math.max(SCALE, height / 250)
				local w, h = length / sc, height / sc
				local pos = center - tangent * (w / 2 * sc) + up * (h / 2 * sc)
				cam.Start3D2D(pos, ang, sc)
					-- Liseré lumineux en haut et en bas
					glowBar(16, 14, w - 32, 8, alpha(col, 255 * pulse), pulse)
					draw.RoundedBox(2, 16, h - 18, w - 32, 4, alpha(col, 120 * pulse))
					-- Disposition : face allongée = logo à gauche et aérations à droite ;
					-- face carrée = logo centré en haut, rangée d'aérations en dessous
					local long = w > 560
					local slots, sw, gx, gy, gh = 0, 16, 0, h * 0.38, h * 0.36
					if not opts.title then
						slots = math.floor((w - 80) / 30) gx = w - 40 - slots * 30
					elseif long then
						slots = math.floor((w * 0.32 - 40) / 30) gx = w * 0.68
					else
						slots = math.floor((w - 60) / 30) gx = (w - slots * 30 + 14) / 2 gy, gh = h * 0.56, h * 0.28
					end
					for k = 0, slots - 1 do
						draw.RoundedBox(6, gx + k * 30, gy, sw, gh, darker)
						draw.RoundedBox(6, gx + k * 30 + 2, gy + 2, sw - 4, 6, alpha(col, 30 * pulse))
					end
					if opts.title and long then
						draw.SimpleText(opts.title, "Astral.PrinterLook.Side", 40, h * 0.40, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
						if opts.sub then
							draw.SimpleText(opts.sub, "Astral.PrinterLook.SideSmall", 42, h * 0.40 + 46, alpha(col, 230), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
						end
					elseif opts.title then
						surface.SetFont("Astral.PrinterLook.SideSmall")
						local tf = surface.GetTextSize(opts.title) <= w - 30 and "Astral.PrinterLook.SideSmall" or "Astral.PrinterLook.Tag"
						draw.SimpleText(UI.Truncate(opts.title, tf, w - 20), tf, w / 2, h * 0.27, C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
						if opts.sub then
							draw.SimpleText(UI.Truncate(opts.sub, "Astral.Printer.Small", w - 30), "Astral.Printer.Small", w / 2, h * 0.27 + 30, alpha(col, 230), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
						end
					end
				cam.End3D2D()
			end
		end
	end
end

---------------------------------------------------------------------------
-- Dessus
---------------------------------------------------------------------------
-- Ventilateur : carter, anneau lumineux, 7 pales tournantes, grille
local function fan(ent, cx, cy, r, col, on)
	local oc = P.Rank(ent, "overclock")
	ent.AstralFanSpeed = Lerp(FrameTime() * 2, ent.AstralFanSpeed or 0, on and (480 + 360 * oc) or 0)
	ent.AstralFanAngle = ((ent.AstralFanAngle or 0) + ent.AstralFanSpeed * FrameTime()) % 360
	local ring = oc > 0 and on and Color(255, 120, 70) or col
	local glow = on and (0.55 + 0.45 * math.abs(math.sin(RealTime() * (2 + oc)))) or 0.1
	draw.RoundedBox(r + 10, cx - r - 10, cy - r - 10, (r + 10) * 2, (r + 10) * 2, alpha(ring, 40 * glow))
	draw.RoundedBox(r, cx - r, cy - r, r * 2, r * 2, alpha(ring, 200 * glow + 40))
	draw.RoundedBox(r - 6, cx - r + 6, cy - r + 6, (r - 6) * 2, (r - 6) * 2, edge)
	draw.RoundedBox(r - 12, cx - r + 12, cy - r + 12, (r - 12) * 2, (r - 12) * 2, darker)
	draw.NoTexture()
	local blade = on and Color(200, 210, 230) or Color(70, 76, 96)
	local a0 = ent.AstralFanAngle
	for i = 0, 6 do
		local a = a0 + i * (360 / 7)
		local rad, d = math.rad(a), (r - 12) * 0.5
		surface.SetDrawColor(blade)
		surface.DrawTexturedRectRotated(cx + math.cos(rad) * d, cy - math.sin(rad) * d, (r - 12) * 0.86, 18, a + 18)
	end
	draw.RoundedBox(22, cx - 22, cy - 22, 44, 44, edge)
	draw.RoundedBox(10, cx - 10, cy - 10, 20, 20, alpha(ring, on and 255 or 60))
	-- (pas de surface.DrawCircle / DrawLine : en 3D2D, ils tracent une ligne parasite jusque dans le décor)
end

local function face(ent, FW, FH, col)
	local on = ent:IsPowered() and not ent:GetNWBool("printer_disabled")
	local money, cap = tonumber(ent:GetMoney()) or 0, P.Capacity(ent)
	local full = cap > 0 and money >= cap
	local glow = full and (0.5 + 0.5 * math.abs(math.sin(RealTime() * 4))) or 1
	local rim = full and C.warn or col
	-- Plaque et liseré lumineux
	draw.RoundedBox(28, 0, 0, FW, FH, alpha(rim, on and 160 * glow or 40))
	draw.RoundedBox(26, 3, 3, FW - 6, FH - 6, edge)
	draw.RoundedBox(24, 6, 6, FW - 12, FH - 12, dark)
	surface.SetMaterial(gradDown)
	surface.SetDrawColor(col.r, col.g, col.b, on and 22 or 6)
	surface.DrawTexturedRect(6, 6, FW - 12, FH * 0.6)
	-- Lunette de l'écran (écran dessiné ensuite par DrawDisplay)
	local SX, SY = 22, 22
	draw.RoundedBox(18, SX - 6, SY - 6, SW + 12, SH + 12, alpha(col, on and 90 or 20))
	draw.RoundedBox(16, SX - 4, SY - 4, SW + 8, SH + 8, darker)
	-- Ventilateur
	local fx = SX + SW + (FW - SX - SW) / 2 - 2
	fan(ent, fx, SY + SH / 2, 106, col, on)
	-- Plaque du modèle
	local by = SY + SH + 20
	local bh = FH - by - 18
	draw.RoundedBox(16, SX - 4, by, FW - (SX - 4) * 2, bh, darker)
	glowBar(SX + 10, by + 12, 6, bh - 24, col, on and 1 or 0.2)
	draw.SimpleText("ASTRAL", "Astral.PrinterLook.Brand", SX + 32, by + 14, C.text)
	surface.SetFont("Astral.PrinterLook.Brand")
	local bw = surface.GetTextSize("ASTRAL ")
	draw.SimpleText("PRINT", "Astral.PrinterLook.Brand", SX + 32 + bw, by + 14, col)
	local name = UI.ItemLabel and UI.ItemLabel(ent.PrintName or "Imprimante") or (ent.PrintName or "Imprimante")
	draw.SimpleText(UI.Truncate(name, "Astral.PrinterLook.Tag", 236), "Astral.PrinterLook.Tag", SX + 34, by + 58, C.dim)
	draw.SimpleText(string.format("NIV. %d / %d", ent:GetLevel() or 1, ent.MaxLevel or 1), "Astral.PrinterLook.Tag", SX + 34, by + 84, alpha(col, 220))
	-- Voyants des améliorations : segments lumineux
	local x0, colW = SX + 296, 94
	for i, u in ipairs(P.Upgrades) do
		local x, rank = x0 + (i - 1) * colW, P.Rank(ent, u.id)
		local ucol = u.id == "overclock" and Color(255, 140, 80) or col
		draw.SimpleText(SHORT[u.id] or u.name, "Astral.Printer.Small", x + colW / 2, by + 22, rank > 0 and C.text or C.dim, TEXT_ALIGN_CENTER)
		local pw, gap = 12, 5
		local total = u.max * pw + (u.max - 1) * gap
		for k = 1, u.max do
			local px = x + colW / 2 - total / 2 + (k - 1) * (pw + gap)
			if k <= rank then
				draw.RoundedBox(4, px - 2, by + 56, pw + 4, 30, alpha(ucol, 50))
				draw.RoundedBox(4, px, by + 58, pw, 26, ucol)
			else
				draw.RoundedBox(4, px, by + 58, pw, 26, edge)
			end
		end
	end
	-- Voyant d'état
	local led = not on and C.bad or (full and C.warn or C.good)
	draw.RoundedBox(12, FW - 40, 16, 24, 24, alpha(led, 60))
	draw.RoundedBox(8, FW - 36, 20, 16, 16, led)
end

local function astralDraw(self)
	-- Énergie : le serveur applique le surcoût d'overclock (sv_printers.lua) ; le client doit le connaître pour IsPowered
	self.AstralBasePower = self.AstralBasePower or self.PowerRequired or 5
	self.PowerRequired = math.ceil(self.AstralBasePower * P.PowerMul(self))
	if self.AstralVIP then self.FontColor = HSVToColor(CurTime() % 6 * 60, 1, 1) end
	local col = UI.PrinterColor(self)

	render.MaterialOverride(metal)
	render.SetColorModulation(bodyTint(col))
	self:DrawModel()
	render.SetColorModulation(1, 1, 1)
	render.MaterialOverride(nil)

	local dist = EyePos():DistToSqr(self:GetPos())
	if dist > DRAW_DIST then return end
	local on = self:IsPowered() and not self:GetNWBool("printer_disabled")
	if dist < SIDE_DIST then
		UI.DrawCasing(self, col, { title = "ASTRAL PRINT", sub = UI.ItemLabel and UI.ItemLabel(self.PrintName or "") or self.PrintName, lit = on })
	end

	-- Dessus : face centrée sur le bloc ; x le long du grand côté (y local), y le long du petit côté (x local)
	local mins, maxs = self:OBBMins(), self:OBBMaxs()
	local FW, FH = (maxs.y - mins.y) / SCALE, (maxs.x - mins.x) / SCALE
	local ang = self:GetAngles()
	ang:RotateAroundAxis(ang:Up(), 90)
	-- Façade toujours lisible : le bas du texte (axe y = ang:Right()) est tourné vers le joueur qui regarde
	if (EyePos() - self:GetPos()):Dot(ang:Right()) < 0 then ang:RotateAroundAxis(ang:Up(), 180) end
	local top = self:LocalToWorld(Vector((maxs.x + mins.x) / 2, (maxs.y + mins.y) / 2, maxs.z + 0.15))
	local pos = top - ang:Forward() * (FW / 2 * SCALE) - ang:Right() * (FH / 2 * SCALE)
	cam.Start3D2D(pos, ang, SCALE)
		face(self, FW, FH, col)
	cam.End3D2D()
	if self.DrawDisplay then
		local spos = pos + ang:Forward() * (22 * SCALE) + ang:Right() * (22 * SCALE) + ang:Up() * 0.05
		cam.Start3D2D(spos, ang, SCALE)
			pcall(self.DrawDisplay, self, spos, ang, SCALE)
		cam.End3D2D()
	end
end

local function patch(ent)
	if not IsValid(ent) or ent.AstralLook or not P.IsPrinter(ent) or not ent.Draw then return end
	local original = ent.Draw
	ent.AstralLook = true
	ent.AstralVIP = ent:GetClass():sub(1, 14) == "bw_printer_vip"
	ent.Draw = function(self, flags)
		local ok, err = pcall(astralDraw, self)
		if not ok then
			render.SetColorModulation(1, 1, 1)
			render.MaterialOverride(nil)
			ErrorNoHalt("[Astral:printerlook] " .. self:GetClass() .. " : " .. tostring(err) .. "\n")
			self.Draw = original
		end
	end
end

-- Même méthode que cl_printers.lua : la table Lua de l'entité n'est pas toujours prête à OnEntityCreated
local function sweep() for _, e in ipairs(ents.FindByClass("bw_printer_*")) do patch(e) end end
hook.Add("OnEntityCreated", "Astral.PrinterLook", function(ent) timer.Simple(1, function() patch(ent) end) end)
hook.Add("InitPostEntity", "Astral.PrinterLook", sweep)
timer.Create("Astral.PrinterLook.Sweep", 2, 0, sweep)
sweep()

-- Astral UI — HUD principal.
-- Remplace les deux HUD SpaceVX (« BaseWars.HUD.Paint » : vie/armure/karma/niveau/infos d'entité, et
-- « BaseWars.PlayTime_Money.Paint » : argent/temps de jeu). Notifications, raid, AFK, réapparition (anti-RDM)
-- et minimap sont redessinés par cl_overlays.lua ; les halos de karma SpaceVX restent en place.
-- Convar client astral_hud 0 : revenir au HUD SpaceVX d'origine (sans redémarrage).

local UI = Astral.UI
local C = UI.Colors
local S = UI.Scale

local cvar = CreateClientConVar("astral_hud", "1", true, false, "1 = HUD Astral, 0 = HUD BaseWars d'origine")

local REPLACED = {
	{ "HUDPaint", "BaseWars.HUD.Paint" },
	{ "HUDPaint", "BaseWars.PlayTime_Money.Paint" },
	{ "HUDPaint", "BaseWars.Notify.Paint" },
	{ "HUDPaint", "BaseWars.AFK.Paint" },
	{ "HUDPaint", "BaseWars.Raid.Paint" },
	{ "HUDPaint", "BaseWars.AntiRDM.Paint" }, -- compte à rebours de réapparition (cl_overlays.lua)
	{ "HUDPaint", "MiniMap" },                -- radar SpaceVX (bw_radar), redessiné dans cl_overlays.lua
	{ "Think", "BaseWars.Menu.Open" }, -- menu F3 SpaceVX, remplacé par cl_menu.lua
}
local saved = {}

-- Les notifications SpaceVX passent par BaseWars.Notify:Add : on les redirige vers les toasts Astral
local function hookNotify()
	local notify = BaseWars.Notify
	if not notify or notify.AstralOriginalAdd then return end
	notify.AstralOriginalAdd = notify.Add
	notify.Add = function(self, str, col)
		if cvar:GetBool() and UI.Toast then return UI.Toast(str, col) end
		return self.AstralOriginalAdd(self, str, col)
	end
end

local function apply()
	hookNotify()
	local enabled = cvar:GetBool()
	for _, h in ipairs(REPLACED) do
		local key = h[1] .. "|" .. h[2]
		local current = (hook.GetTable()[h[1]] or {})[h[2]]
		if enabled then
			if current then saved[key] = current hook.Remove(h[1], h[2]) end
		elseif saved[key] and not current then
			hook.Add(h[1], h[2], saved[key])
		end
	end
end
cvars.AddChangeCallback("astral_hud", function() apply() end, "Astral.HUD")
hook.Add("InitPostEntity", "Astral.HUD.Apply", apply)
apply()

---------------------------------------------------------------------------
-- Carte joueur (bas gauche)
---------------------------------------------------------------------------
-- Avatar Steam (panneau VGUI persistant, repositionné à chaque image)
local avatar
local function avatarPanel(me, x, y, size, visible)
	if not IsValid(avatar) then
		avatar = vgui.Create("AvatarImage")
		avatar:SetPaintedManually(true)
		avatar:SetPlayer(me, 64)
	end
	avatar:SetSize(size, size)
	avatar:SetPos(x, y)
	if visible then
		render.ClearStencil()
		avatar:PaintManual()
	end
end

-- Gains / pertes d'argent animés au-dessus de la carte
local floats, lastMoney = {}, nil
local function trackMoney(me)
	local m = me:GetMoney()
	if lastMoney and m ~= lastMoney then
		table.insert(floats, { delta = m - lastMoney, born = RealTime() })
		if #floats > 5 then table.remove(floats, 1) end
	end
	lastMoney = m
end

-- Montée de niveau : bandeau central bref
local lastLevel, levelFlash
local function trackLevel(me)
	local lvl = me:GetLevel()
	if lastLevel and lvl > lastLevel then
		levelFlash = { level = lvl, born = RealTime() }
		surface.PlaySound("buttons/bell1.wav")
	end
	lastLevel = lvl
end

local function drawLevelFlash()
	if not levelFlash then return end
	local age = RealTime() - levelFlash.born
	if age > 3.5 then levelFlash = nil return end
	local a = math.Clamp(math.min(age / 0.25, (3.5 - age) / 0.6), 0, 1)
	local y = ScrH() * 0.28 - (1 - a) * S(20)
	UI.Text("NIVEAU SUPÉRIEUR", "Astral.UI.Small", ScrW() / 2, y, ColorAlpha(C.xp, 255 * a), TEXT_ALIGN_CENTER)
	UI.Text("Niveau " .. levelFlash.level, "Astral.UI.Huge", ScrW() / 2, y + S(18), ColorAlpha(C.text, 255 * a), TEXT_ALIGN_CENTER)
end

local function playerCard(me)
	local pad = S(14)
	local w, h = S(360), S(150)
	local x, y = S(24), ScrH() - h - S(24)
	UI.Card(x, y, w, h, C.accent)
	UI.Glow(x + S(4), y, w * 0.6, S(46), C.accent, 25)

	-- Avatar
	local av = S(40)
	draw.RoundedBox(S(6), x + pad + S(2), y + pad - S(2), av + S(4), av + S(4), C.line)
	avatarPanel(me, x + pad + S(4), y + pad, av, true)

	local ix = x + pad + av + S(16)
	local iw = w - (ix - x) - pad
	local fx = x + pad + S(4) -- colonne pleine largeur (barres)
	local fw = w - pad * 2 - S(4)

	-- Nom + faction
	local nameW = UI.Text(UI.Truncate(me:Nick(), "Astral.UI.Text", iw - S(90)), "Astral.UI.Text", ix, y + pad - S(2), C.text)
	if me.InFaction and me:InFaction() then
		local fac = me:GetFaction()
		local col = team.GetColor(me:Team())
		surface.SetFont("Astral.UI.Tiny")
		local tw = surface.GetTextSize(fac)
		local bx = ix + nameW + S(8)
		local label = UI.Truncate(fac, "Astral.UI.Tiny", S(90))
		tw = surface.GetTextSize(label)
		draw.RoundedBox(S(4), bx, y + pad, tw + S(10), S(16), ColorAlpha(col, 160))
		draw.SimpleText(label, "Astral.UI.Tiny", bx + S(5), y + pad + S(1), C.text)
	end

	-- Argent (animé) + gains/pertes flottants
	local money = UI.Smooth("money", me:GetMoney(), 6)
	local mw = UI.Text(UI.Money(money), "Astral.UI.Huge", ix, y + pad + S(14), C.accent)
	local now = RealTime()
	for i = #floats, 1, -1 do
		local f = floats[i]
		local age = now - f.born
		if age > 2.2 then table.remove(floats, i) else
			local a = math.Clamp((2.2 - age) / 0.6, 0, 1)
			local txt = (f.delta > 0 and "+" or "-") .. UI.Money(math.abs(f.delta))
			UI.Text(txt, "Astral.UI.Small", ix + mw + S(10), y + pad + S(24) - age * S(14) - (#floats - i) * S(14), ColorAlpha(f.delta > 0 and C.good or C.bad, 255 * a))
		end
	end

	-- Vie / armure (pleine largeur, avec libellés)
	local hp, maxhp = math.max(me:Health(), 0), math.max(me:GetMaxHealth(), 1)
	local ar = math.max(me:Armor(), 0)
	local by = y + pad + S(56)
	local low = hp / maxhp < 0.3
	local hpCol = low and Color(255, 80 + math.sin(RealTime() * 8) * 40, 90) or C.hp
	UI.Text("VIE", "Astral.UI.Tiny", fx, by - S(3), C.dim)
	UI.Bar(fx + S(46), by, fw - S(96), S(8), UI.Smooth("hp", hp, 10) / maxhp, hpCol)
	UI.Text(tostring(hp), "Astral.UI.Small", fx + fw, by - S(4), low and C.bad or C.text, TEXT_ALIGN_RIGHT)
	UI.Text("ARMURE", "Astral.UI.Tiny", fx, by + S(13), C.dim)
	UI.Bar(fx + S(46), by + S(16), fw - S(96), S(8), UI.Smooth("ar", ar, 10) / 100, C.armor)
	UI.Text(tostring(ar), "Astral.UI.Small", fx + fw, by + S(12), C.dim, TEXT_ALIGN_RIGHT)

	-- Niveau / XP
	local lvl, xp, need = me:GetLevel(), me:GetXP(), math.max(me:GetXPNextLevel(), 1)
	local ly = by + S(34)
	draw.RoundedBox(S(4), fx, ly, S(54), S(18), ColorAlpha(C.xp, 60))
	draw.SimpleText("Niv. " .. lvl, "Astral.UI.Tiny", fx + S(27), ly + S(9), C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	UI.Bar(fx + S(62), ly + S(6), fw - S(62), S(6), xp / need, C.xp)

	-- Session, XP chiffrée (karma retiré à la demande du propriétaire, 2026-11-02)
	local iy = ly + S(24)
	if me.GetSessionTable then
		local t = me:GetSessionTable()
		UI.Text(string.format("Session %dh%02d", t.h, t.m), "Astral.UI.Tiny", fx, iy, C.dim)
	end
	UI.Text(string.format("%s / %s XP", UI.Num(xp), UI.Num(need)), "Astral.UI.Tiny", fx + fw, iy, C.dim, TEXT_ALIGN_RIGHT)
end

---------------------------------------------------------------------------
-- Munitions (bas droite) — remplace l'affichage HL2
---------------------------------------------------------------------------
local function ammoCard(me)
	local wep = me:GetActiveWeapon()
	if not IsValid(wep) then return end
	local clip, maxClip = wep:Clip1(), wep:GetMaxClip1()
	local reserve = me:GetAmmoCount(wep:GetPrimaryAmmoType())
	if maxClip <= 0 and reserve <= 0 then return end
	local w, h = S(230), S(74)
	local x, y = ScrW() - w - S(24), ScrH() - h - S(24)
	UI.Card(x, y, w, h, C.warn)
	local name = UI.Truncate(language.GetPhrase(wep:GetPrintName() or wep:GetClass()), "Astral.UI.Small", w - S(40))
	UI.Text(name, "Astral.UI.Small", x + S(18), y + S(10), C.dim)
	local cw = UI.Text(maxClip > 0 and tostring(math.max(clip, 0)) or tostring(reserve), "Astral.UI.Huge", x + S(18), y + S(28), clip == 0 and C.bad or C.text)
	if maxClip > 0 then UI.Text("/ " .. reserve, "Astral.UI.Text", x + S(26) + cw, y + S(38), C.dim) end
	if maxClip > 0 then UI.Bar(x + w - S(70), y + S(44), S(52), S(6), clip / maxClip, C.warn) end
end

hook.Add("HUDShouldDraw", "Astral.HUD.Ammo", function(name)
	if (name == "CHudAmmo" or name == "CHudSecondaryAmmo") and cvar:GetBool() then return false end
end)

---------------------------------------------------------------------------
-- Haut de l'écran : heure, raccourcis, annonce admin
---------------------------------------------------------------------------
local hints = CreateClientConVar("astral_hud_hints", "1", true, false)

local function topBar()
	local w = ScrW()
	local y = S(10)
	if BaseWars.PSAText then
		surface.SetFont("Astral.UI.Text")
		local tw = surface.GetTextSize(BaseWars.PSAText)
		draw.RoundedBox(S(6), w / 2 - tw / 2 - S(12), y, tw + S(24), S(26), Color(C.warn.r, C.warn.g, C.warn.b, 40))
		UI.Text(BaseWars.PSAText, "Astral.UI.Text", w / 2, y + S(13), C.warn, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		y = y + S(32)
	end
	UI.Text(os.date("%H:%M"), "Astral.UI.Big", w / 2, y, C.text, TEXT_ALIGN_CENTER)
	-- Événement en cours : pastille sous l'heure
	local evId, ev
	if Astral.Events then evId, ev = Astral.Events.Current() end -- (pas de « and » : il tronquerait le 2e retour)
	if evId and ev then
		local left = math.max(0, GetGlobal2Float("AstralEventEnds", 0) - CurTime())
		local text = string.format("%s  ·  %d:%02d", ev.name, math.floor(left / 60), math.floor(left % 60))
		surface.SetFont("Astral.UI.Small")
		local tw = surface.GetTextSize(text)
		local px, py = w / 2 - tw / 2 - S(14), y + S(30)
		local pulse = 160 + math.sin(RealTime() * 3) * 60
		draw.RoundedBox(S(12), px, py, tw + S(28), S(24), ColorAlpha(C.accent2, 70))
		draw.RoundedBox(S(4), px + S(8), py + S(9), S(6), S(6), ColorAlpha(C.accent2, pulse))
		draw.SimpleText(text, "Astral.UI.Small", w / 2 + S(4), py + S(12), C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	if hints:GetBool() then
		-- Raccourcis : touche en pastille + libellé, de droite à gauche
		local keys = { { "F3", "Menu" }, { "F4", "Boutique" }, { "Tab", "Joueurs" }, { "Échap", "Serveur" } }
		local x = w - S(16)
		for i = #keys, 1, -1 do
			local k = keys[i]
			surface.SetFont("Astral.UI.Tiny")
			local lw = surface.GetTextSize(k[2])
			local kw = surface.GetTextSize(k[1]) + S(10)
			x = x - lw
			UI.Text(k[2], "Astral.UI.Tiny", x, S(13), C.dim)
			x = x - kw - S(5)
			draw.RoundedBox(S(4), x, S(10), kw, S(18), Color(C.line.r, C.line.g, C.line.b, 200))
			draw.SimpleText(k[1], "Astral.UI.Tiny", x + kw / 2, S(19), C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			x = x - S(14)
		end
	end
end

---------------------------------------------------------------------------
-- Entité visée : carte sous le viseur (machines BaseWars et Astral)
---------------------------------------------------------------------------
local function targetCard(me)
	local ent = me:GetEyeTrace().Entity
	if not IsValid(ent) or ent:GetPos():DistToSqr(me:GetPos()) > 200 * 200 then return end
	if not (ent.IsElectronic or ent.IsGenerator or ent.DrawStructureDisplay or ent.IsAstralMachine) then return end

	local w = S(260)
	local upg = ent.GetLevel and ent.MaxLevel and ent:GetNWInt("UpgradeCost", 0) > 0
	local rows = 1 + (ent:Health() > 0 and 1 or 0) + (ent.GetPower and ent:GetMaxPower() > 0 and 1 or 0) + (upg and 1 or 0)
	local h = S(30) + rows * S(18)
	local x, y = ScrW() / 2 - w / 2, ScrH() / 2 + S(110) -- sous l'invite « E » de SpaceVX (cl_interactions)
	UI.Card(x, y, w, h, C.accent2)
	local ix, iw = x + S(14), w - S(28)
	local cy = y + S(8)

	local owner = ent.CPPIGetOwner and ent:CPPIGetOwner()
	local label = UI.ItemLabel and UI.ItemLabel(ent.PrintName or ent:GetClass()) or (ent.PrintName or ent:GetClass())
	UI.Text(UI.Truncate(label, "Astral.UI.Text", iw * 0.58), "Astral.UI.Text", ix, cy, C.text)
	if IsValid(owner) and owner.Nick then UI.Text(UI.Truncate(owner:Nick(), "Astral.UI.Tiny", iw * 0.4), "Astral.UI.Tiny", ix + iw, cy + S(4), C.dim, TEXT_ALIGN_RIGHT) end
	cy = cy + S(24)

	if ent:Health() > 0 then
		local maxh = math.max(ent:GetMaxHealth(), 1)
		UI.Bar(ix, cy + S(3), iw - S(70), S(7), ent:Health() / maxh, ent.BadlyDamaged and ent:BadlyDamaged() and C.bad or C.hp)
		UI.Text(ent:Health() .. " PV", "Astral.UI.Tiny", ix + iw, cy, C.dim, TEXT_ALIGN_RIGHT)
		cy = cy + S(18)
	end
	if ent.GetPower and ent:GetMaxPower() > 0 then
		local p, mp = ent:GetPower(), ent:GetMaxPower()
		UI.Bar(ix, cy + S(3), iw - S(70), S(7), p / mp, p > 0 and C.power or C.bad)
		UI.Text(p > 0 and (p .. " énergie") or "Hors tension", "Astral.UI.Tiny", ix + iw, cy, p > 0 and C.dim or C.bad, TEXT_ALIGN_RIGHT)
		cy = cy + S(18)
	end
	if upg then
		local lvl, max = ent:GetLevel(), ent.MaxLevel
		UI.Bar(ix, cy + S(3), iw - S(70), S(7), lvl / max, C.xp)
		UI.Text("Niveau " .. lvl .. "/" .. max, "Astral.UI.Tiny", ix + iw, cy, lvl >= max and C.good or C.dim, TEXT_ALIGN_RIGHT)
	end
end

---------------------------------------------------------------------------
-- Message « coincé » (repris du HUD SpaceVX)
---------------------------------------------------------------------------
local stuckSince
local function stuckHint(me)
	if me.Stuck and me:Stuck() and me:GetMoveType() == MOVETYPE_WALK then
		stuckSince = stuckSince or CurTime()
		if CurTime() > stuckSince + 1 then
			UI.Text("Coincé ? Accroupis-toi puis saute pour te dégager.", "Astral.UI.Big", ScrW() / 2, ScrH() / 2 - S(80), C.warn, TEXT_ALIGN_CENTER)
		end
	else
		stuckSince = nil
	end
end

hook.Add("HUDPaint", "Astral.HUD", function()
	if not cvar:GetBool() then return end
	local me = LocalPlayer()
	if not IsValid(me) or not me.GetMoney then return end
	topBar()
	trackMoney(me)
	trackLevel(me)
	drawLevelFlash()
	if UI.DrawOverlays then UI.DrawOverlays(me) end
	if me:Alive() then
		playerCard(me)
		ammoCard(me)
		targetCard(me)
		-- stuckHint désactivé : Player:Stuck() côté client renvoie des faux positifs (vérifié au spawn d'Evocity,
		-- le serveur répondait false). Le déblocage par saut de SpaceVX (init.lua KeyPress) reste actif.
	end
end)

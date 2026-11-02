-- Astral UI — écrans 3D2D des machines SpaceVX : imprimantes (bw_base_moneyprinter et ses 33 variantes),
-- coffres-forts (bw_vault, bw_vault_vip) et tours (soin, acide, gel).
-- Remplace seulement le DESSIN (ENT.DrawDisplay) : mêmes données (argent, capacité, niveau, papier, énergie),
-- même emplacement et même échelle (Calc3D2DParams d'origine). Les imprimantes qui ont leur propre écran
-- sont laissées telles quelles. Convar astral_hud 0 : écran SpaceVX d'origine.

local UI = Astral.UI
local C = UI.Colors

surface.CreateFont("Astral.Printer.Title", { font = "Roboto", size = 30, weight = 800, extended = true })
surface.CreateFont("Astral.Printer.Huge", { font = "Roboto", size = 54, weight = 900, extended = true })
surface.CreateFont("Astral.Printer.Body", { font = "Roboto", size = 22, weight = 700, extended = true })
surface.CreateFont("Astral.Printer.Small", { font = "Roboto", size = 18, weight = 600, extended = true })

local W, H = 432, 272   -- surface de l'écran d'origine (216 × 136 × 2, échelle 0,05)
local bg, track = Color(10, 13, 26, 245), Color(36, 46, 82)

local function money(n) return UI.Money(n) end

-- Couleur d'identité de l'imprimante (cuivre, or, émeraude…), lisible sur fond sombre
local function identity(ent)
	local f, b = ent.FontColor, ent.BackColor
	local function pale(c) return c and c.r + c.g + c.b > 690 end
	local function dark(c) return c and c.r + c.g + c.b < 60 end
	if f and not pale(f) and not dark(f) then return f end
	if b and not pale(b) and not dark(b) then return Color(math.min(255, b.r * 1.6 + 40), math.min(255, b.g * 1.6 + 40), math.min(255, b.b * 1.6 + 40)) end
	return C.accent
end

UI.PrinterColor = identity   -- réutilisé par le boîtier (cl_printerlook.lua) et le menu (cl_upgrade.lua)

local function duration(s)
	s = math.max(0, math.floor(s))
	if s >= 3600 then return string.format("%d h %02d min", math.floor(s / 3600), math.floor(s / 60) % 60) end
	if s >= 60 then return string.format("%d min %02d s", math.floor(s / 60), s % 60) end
	return s .. " s"
end

local function bar(x, y, w, h, frac, col)
	draw.RoundedBox(h / 2, x, y, w, h, track)
	frac = math.Clamp(frac or 0, 0, 1)
	if frac > 0 then draw.RoundedBox(h / 2, x, y, math.max(h, w * frac), h, col) end
end

local function astralDisplay(self, pos, ang, scale)
	local id = identity(self)
	local name = UI.ItemLabel and UI.ItemLabel(self.PrintName or "Imprimante") or self.PrintName
	draw.RoundedBox(14, 0, 0, W, H, bg)
	draw.RoundedBoxEx(14, 0, 0, W, 8, id, true, true, false, false)
	draw.SimpleText(UI.Truncate(name, "Astral.Printer.Title", W - 150), "Astral.Printer.Title", 20, 18, C.text)

	local lv, maxLv = self:GetLevel() or 1, self.MaxLevel or 1
	local badge = maxLv > 1 and string.format("Niv. %d / %d", lv, maxLv) or "Niv. max"
	surface.SetFont("Astral.Printer.Small")
	local bw = surface.GetTextSize(badge) + 20
	draw.RoundedBox(8, W - bw - 16, 20, bw, 28, ColorAlpha(id, 45))
	draw.SimpleText(badge, "Astral.Printer.Small", W - bw / 2 - 16, 34, id, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	if self:GetNWBool("printer_disabled") then
		draw.SimpleText("IMPRIMANTE DÉSACTIVÉE", "Astral.Printer.Title", W / 2, H / 2, C.bad, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText("par un administrateur", "Astral.Printer.Small", W / 2, H / 2 + 28, C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		return
	end
	if not self:IsPowered() then
		local pulse = math.abs(math.sin(RealTime() * 3)) * 0.5 + 0.5
		draw.SimpleText("HORS TENSION", "Astral.Printer.Huge", W / 2, H / 2 + 4, ColorAlpha(C.bad, 255 * pulse), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText("Place un générateur à proximité", "Astral.Printer.Small", W / 2, H / 2 + 46, C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		return
	end

	-- Argent stocké
	local cash = self:GetMoney() or 0
	local cap = Astral.Printers and Astral.Printers.Capacity(self) or tonumber(self:GetCapacity()) or 0
	local frac = (cap > 0 and cap ~= math.huge) and cash / cap or 0
	local full = frac >= 1
	local cw = draw.SimpleText(money(cash), "Astral.Printer.Huge", 20, 60, full and C.good or C.text)
	draw.SimpleText("/ " .. money(cap), "Astral.Printer.Body", 28 + cw, 84, C.dim)
	draw.SimpleText(math.floor(frac * 100) .. " %", "Astral.Printer.Title", W - 20, 70, full and C.good or id, TEXT_ALIGN_RIGHT)
	bar(20, 124, W - 40, 16, frac, full and C.good or id)

	-- Remplissage / récolte
	-- Production réelle par seconde (niveau^1,3 et améliorations Astral : sh_printers.lua)
	local rate = Astral.Printers and Astral.Printers.PerMinute(self) / 60 or (self.PrintAmount or 0) * lv / math.max(self.PrintInterval or 1, 0.01)
	local status
	if full then
		local blink = math.floor(RealTime() * 2) % 2 == 0
		status = { "Pleine — Maj + E pour récupérer", blink and C.good or C.warn }
	else
		status = { "Pleine dans " .. duration(rate > 0 and (cap - cash) / rate or 0) .. "  ·  " .. money(rate) .. "/s", C.dim }
	end
	draw.SimpleText(status[1], "Astral.Printer.Body", 20, 150, status[2])

	-- Papier
	local paper, maxPaper = math.floor(self:GetPaper() or 0), self.MaxPaper or 1
	draw.SimpleText("Papier", "Astral.Printer.Small", 20, 190, C.dim)
	bar(96, 196, W - 220, 10, paper / math.max(maxPaper, 1), paper > 0 and C.accent2 or C.bad)
	draw.SimpleText(paper > 0 and tostring(paper) or "VIDE", "Astral.Printer.Small", W - 20, 190, paper > 0 and C.text or C.bad, TEXT_ALIGN_RIGHT)

	-- Amélioration
	draw.RoundedBox(0, 20, 223, W - 40, 2, track)   -- pas de surface.DrawLine en 3D2D (ligne parasite)
	local mine = (self.CPPIGetOwner and self:CPPIGetOwner()) == LocalPlayer()
	local upg = mine and "E : menu et améliorations  ·  Maj + E : récolter" or (lv >= maxLv and "Niveau maximum" or ("Niveau suivant : " .. money(lv * self:GetNWInt("UpgradeCost"))))
	draw.SimpleText(upg, "Astral.Printer.Small", 20, 236, mine and C.accent or C.dim)
end

---------------------------------------------------------------------------
-- Coffre-fort (bw_vault, bw_vault_vip) : face avant du meuble, surface 432 × 272
---------------------------------------------------------------------------
local function vaultDisplay(self)
	local vip = self:GetClass() == "bw_vault_vip"
	local id = vip and HSVToColor(CurTime() % 6 * 60, 0.7, 1) or C.good
	local cash = self:GetMoney() or 0
	draw.RoundedBox(14, 0, 0, W, H, bg)
	draw.RoundedBoxEx(14, 0, 0, W, 8, id, true, true, false, false)
	draw.SimpleText(vip and "Coffre-fort VIP" or "Coffre-fort", "Astral.Printer.Title", 20, 18, C.text)
	draw.SimpleText("Intérêts " .. string.format("%g", (self.InterestRate or 0) * 100):gsub("%.", ",") .. " %", "Astral.Printer.Small", W - 20, 26, id, TEXT_ALIGN_RIGHT)
	draw.SimpleText(money(cash), "Astral.Printer.Huge", W / 2, 112, cash > 0 and C.text or C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	if self.IsPowered and not self:IsPowered() then
		local pulse = math.abs(math.sin(RealTime() * 3)) * 0.5 + 0.5
		draw.SimpleText("HORS TENSION — n'aspire plus l'argent", "Astral.Printer.Body", W / 2, 166, ColorAlpha(C.bad, 255 * pulse), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	else
		draw.SimpleText("Prochain gain : " .. money(math.floor(cash * (self.InterestRate or 0))) .. " dans " .. (self.CollectInterval or 10) .. " s", "Astral.Printer.Body", W / 2, 166, C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	draw.RoundedBox(0, 20, 203, W - 40, 2, track)
	draw.SimpleText("Aspire l'argent de tes imprimantes à moins de " .. math.floor((self.Radius or 600) * 0.01905) .. " m", "Astral.Printer.Small", W / 2, 222, C.dim, TEXT_ALIGN_CENTER)
	draw.SimpleText(cash > 0 and "Appuie sur E pour récupérer" or "Vide", "Astral.Printer.Small", W / 2, 246, cash > 0 and C.good or C.dim, TEXT_ALIGN_CENTER)
end

---------------------------------------------------------------------------
-- Tours (soin, acide, gel : bw_turret_healer et dérivées) : panneau flottant centré sur (0, 0)
---------------------------------------------------------------------------
local TOWER_NAMES = { ["Healing Tower"] = "Tour de soin", ["Acid Tower"] = "Tour à acide", ["Freezing Tower"] = "Tour de gel" }
local TOWER_COLORS = { ["Healing Tower"] = Color(110, 225, 150), ["Acid Tower"] = Color(190, 230, 80), ["Freezing Tower"] = Color(120, 200, 255) }

local function towerDisplay(self)
	local tw, th = 300, 92
	local id = TOWER_COLORS[self.PrintName] or C.accent
	local lv, maxLv = self:GetLevel() or 1, self.MaxLevel or 1
	local x, y = -tw / 2, -th
	draw.RoundedBox(12, x, y, tw, th, bg)
	draw.RoundedBoxEx(12, x, y, tw, 6, id, true, true, false, false)
	draw.SimpleText(TOWER_NAMES[self.PrintName] or self.PrintName, "Astral.Printer.Body", x + 16, y + 14, C.text)
	draw.SimpleText(string.format("Niv. %d / %d", lv, maxLv), "Astral.Printer.Small", x + tw - 16, y + 17, id, TEXT_ALIGN_RIGHT)
	local powered = not self.IsPowered or self:IsPowered()
	local line = not powered and "HORS TENSION" or (lv >= maxLv and "Niveau maximum" or ("Amélioration : " .. money(self:getUpgradeCost(lv))))
	draw.SimpleText(line, "Astral.Printer.Small", x + 16, y + 52, not powered and C.bad or (lv >= maxLv and C.good or C.dim))
end

---------------------------------------------------------------------------
-- Application (entités existantes et futures). Seul ENT.DrawDisplay est remplacé, et seulement s'il est encore
-- celui de la classe de base SpaceVX : un écran personnalisé par une classe dérivée n'est jamais touché.
---------------------------------------------------------------------------
local cvar = GetConVar("astral_hud")
local SCREENS = {
	{ base = "bw_base_moneyprinter", find = "bw_printer_*", draw = astralDisplay },
	{ base = "bw_vault", find = "bw_vault*", draw = vaultDisplay },
	{ base = "bw_turret_healer", find = "bw_turret_*", draw = towerDisplay },
}

-- DrawDisplay SpaceVX de chaque base, lu au premier besoin (les entités peuvent être enregistrées après ce fichier)
local function resolve(s)
	if s.original then return s.original end
	local stored = scripted_ents.GetStored(s.base)
	s.original = stored and stored.t and stored.t.DrawDisplay
	if s.original then
		local original, draw = s.original, s.draw
		s.wrapped = function(self, pos, ang, scale)
			if cvar and not cvar:GetBool() then return original(self, pos, ang, scale) end
			local ok, err = pcall(draw, self, pos, ang, scale)
			if not ok then
				ErrorNoHalt("[Astral:screens] " .. s.base .. " : " .. tostring(err) .. "\n")
				self.DrawDisplay = original   -- en cas d'erreur, cette machine revient à l'écran d'origine
			end
		end
	end
	return s.original
end

local function patch(ent)
	if not IsValid(ent) or not ent.DrawDisplay then return end
	for _, s in ipairs(SCREENS) do
		if resolve(s) and ent.DrawDisplay == s.original then ent.DrawDisplay = s.wrapped return end
	end
end

-- Au moment de OnEntityCreated, la table Lua de l'entité n'est pas toujours prête (constaté en jeu) :
-- nouvel essai une seconde plus tard, plus un balayage léger toutes les 2 s (classes concernées uniquement).
local function sweep() for _, s in ipairs(SCREENS) do for _, e in ipairs(ents.FindByClass(s.find)) do patch(e) end end end
hook.Add("OnEntityCreated", "Astral.Printers", function(ent) timer.Simple(1, function() patch(ent) end) end)
hook.Add("InitPostEntity", "Astral.Printers", sweep)
timer.Create("Astral.Printers.Sweep", 2, 0, sweep)
sweep()

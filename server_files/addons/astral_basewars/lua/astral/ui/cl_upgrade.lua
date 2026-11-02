-- Astral UI — menus de gestion des machines.
--   E sur sa propre imprimante   : menu complet (stock, production, énergie, PV, récolte, niveau SpaceVX et
--                                  améliorations Astral : vitesse, overclock, capacité, blindage).
--   Maj + E sur son imprimante   : récolte directe.
--   E sur sa Banque Astral       : menu banque (total, récolte, imprimantes connectées, améliorations groupées).
--   Maj + E sur une autre machine améliorable à soi : panneau de niveau.
--   Machine d'un autre joueur    : comportement E d'origine (rien n'est intercepté).
-- Tous les achats passent par le serveur, qui revérifie tout : niveau (astral/economy/sv_upgrade.lua),
-- améliorations, récolte et banque (astral/industry/sv_printers.lua). Définitions et coûts : sh_printers.lua.

local UI = Astral.UI
local C, S = UI.Colors, UI.Scale
local P = Astral.Printers
local RANGE = 150 ^ 2

local function owned(ent)
	local me = LocalPlayer()
	if not IsValid(ent) or (ent.CPPIGetOwner and ent:CPPIGetOwner()) ~= me then return false end
	return me:GetPos():DistToSqr(ent:GetPos()) < RANGE
end
local function upgradable(ent) return ent.GetLevel and ent.MaxLevel and ent:GetNWInt("UpgradeCost", 0) > 0 end
local function isBank(ent) return IsValid(ent) and ent:GetClass() == "bw_astral_bank" end
local function label(ent) return UI.ItemLabel and UI.ItemLabel(ent.PrintName or "Machine") or (ent.PrintName or "Machine") end

local function duration(s)
	s = math.max(0, math.floor(s))
	if s >= 3600 then return string.format("%d h %02d min", math.floor(s / 3600), math.floor(s / 60) % 60) end
	if s >= 60 then return string.format("%d min %02d s", math.floor(s / 60), s % 60) end
	return s .. " s"
end
local function pct(v) return (v >= 0 and "+" or "−") .. math.Round(math.abs(v) * 100) .. " %" end

-- Coût total pour passer de lvl à lvl + n (plafonné au niveau max)
local function costFor(ent, n)
	local base, lvl, total, steps = ent:GetNWInt("UpgradeCost", 0), ent:GetLevel(), 0, 0
	for k = lvl, math.min(lvl + n, ent.MaxLevel) - 1 do total = total + base * k steps = steps + 1 end
	return total, steps
end

-- Effet cumulé d'un type d'amélioration au rang r (texte court)
local function effect(u, r)
	if r <= 0 then return "aucun" end
	if u.id == "speed" then return "intervalle " .. pct(-u.step * r) end
	if u.id == "overclock" then return "production " .. pct(u.step * r) .. ", énergie " .. pct(u.power * r) end
	if u.id == "capacity" then return "stockage " .. pct(u.step * r) end
	return "PV " .. pct(u.step * r)
end

local function send(name, ent, ...)
	if not IsValid(ent) then return end
	net.Start(name) net.WriteEntity(ent)
	local args = { ... }
	for i = 1, #args, 2 do net.WriteUInt(args[i], args[i + 1]) end
	net.SendToServer()
	surface.PlaySound("ui/buttonclick.wav")
end

local function sectionTitle(text, x, y) draw.SimpleText(text, "Astral.UI.Tiny", x, y, C.dim) end

-- Ligne « libellé … valeur » dans le panneau d'informations
local function row(w, y, name, value, col)
	draw.SimpleText(name, "Astral.UI.Small", S(16), y, C.dim)
	draw.SimpleText(value, "Astral.UI.Text", w - S(16), y - S(2), col or C.text, TEXT_ALIGN_RIGHT)
end

local frame
local function closeFrame() if IsValid(frame) then frame:Close() end end

---------------------------------------------------------------------------
-- Carte « Niveau » (+1, +5, max) : commune aux imprimantes et aux autres machines
---------------------------------------------------------------------------
local function levelCard(parent, ent)
	local card = vgui.Create("DPanel", parent)
	card:Dock(TOP) card:DockMargin(0, 0, 0, S(8)) card:SetTall(S(132))
	local printer = P.IsPrinter(ent)
	function card:Paint(w, h)
		if not IsValid(ent) then return end
		local lvl, max = ent:GetLevel(), ent.MaxLevel
		UI.Card(0, 0, w, h, C.xp)
		draw.SimpleText("NIVEAU", "Astral.UI.Tiny", S(16), S(10), C.dim)
		draw.SimpleText(lvl .. " / " .. max, "Astral.UI.Big", S(16), S(24), lvl >= max and C.good or C.xp)
		if printer and lvl < max then
			draw.SimpleText(UI.Money(P.PerMinute(ent)) .. " / min  →  " .. UI.Money(P.PerMinute(ent, lvl + 1)) .. " / min au niveau " .. (lvl + 1),
				"Astral.UI.Small", w - S(16), S(30), C.dim, TEXT_ALIGN_RIGHT)
		end
		UI.Bar(S(16), S(56), w - S(32), S(6), lvl / math.max(max, 1), C.xp)
	end
	local btns = {}
	local bar = vgui.Create("DPanel", card)
	bar:Dock(BOTTOM) bar:DockMargin(S(16), 0, S(16), S(12)) bar:SetTall(S(36)) bar:SetPaintBackground(false)
	for _, def in ipairs({ { "+1", 1 }, { "+5", 5 }, { "Max", 255 } }) do
		local b = UI.Button(bar, "", C.xp, function() send("Astral.Upgrade", ent, def[2], 8) end)
		b:Dock(LEFT) b:DockMargin(0, 0, S(8), 0) b:SetFont("Astral.UI.Small")
		b.tag, b.n = def[1], def[2]
		btns[#btns + 1] = b
	end
	function bar:PerformLayout(w)
		for _, b in ipairs(btns) do b:SetWide((w - S(16)) / 3) end
	end
	function card:Think()
		if not IsValid(ent) then return end
		local money = LocalPlayer():GetMoney()
		for _, b in ipairs(btns) do
			local cost, steps = costFor(ent, b.n)
			if steps <= 0 then
				b:SetText("Niveau max") b:SetDisabled(true)
			else
				b:SetText((b.n == 255 and ("Max (+" .. steps .. ")") or b.tag) .. "  ·  " .. UI.Money(cost))
				-- +5 et max : le serveur s'arrête au dernier niveau payable ; on n'interdit que si même +1 est impossible
				b:SetDisabled(money < ent:GetNWInt("UpgradeCost", 0) * ent:GetLevel())
			end
		end
	end
	return card
end

---------------------------------------------------------------------------
-- Carte d'une amélioration Astral
---------------------------------------------------------------------------
local function upgradeCard(parent, ent, u)
	local card = vgui.Create("DPanel", parent)
	card:Dock(TOP) card:DockMargin(0, 0, 0, S(8)) card:SetTall(S(78))
	local btn = UI.Button(card, "", C.accent, function() send("Astral.Printer.Upgrade", ent, u.index, 4) end)
	btn:SetSize(S(170), S(36))
	function card:PerformLayout(w, h) btn:SetPos(w - btn:GetWide() - S(14), (h - btn:GetTall()) / 2) end
	function card:Paint(w, h)
		if not IsValid(ent) then return end
		local r = P.Rank(ent, u.id)
		local col = u.id == "overclock" and C.warn or C.accent
		UI.Card(0, 0, w, h, col)
		draw.SimpleText(u.name, "Astral.UI.Text", S(16), S(10), C.text)
		-- Pastilles des rangs
		surface.SetFont("Astral.UI.Text")
		local x = S(24) + surface.GetTextSize(u.name)
		for k = 1, u.max do
			draw.RoundedBox(S(3), x + (k - 1) * S(14), S(15), S(10), S(10), k <= r and col or C.line)
		end
		draw.SimpleText(u.desc, "Astral.UI.Small", S(16), S(34), C.dim)
		local now = "Actuel : " .. effect(u, r)
		if r < u.max then now = now .. "   →   " .. effect(u, r + 1) end
		draw.SimpleText(UI.Truncate(now, "Astral.UI.Tiny", w - S(210)), "Astral.UI.Tiny", S(16), S(54), r > 0 and col or C.dim)
	end
	function card:Think()
		if not IsValid(ent) then return end
		local cost = P.Cost(ent, u.id)
		if not cost then btn:SetText("Rang max") btn:SetDisabled(true) return end
		btn:SetText(UI.Money(cost))
		btn:SetDisabled(LocalPlayer():GetMoney() < cost)
	end
end

---------------------------------------------------------------------------
-- Menu d'imprimante (ou panneau de niveau pour une autre machine)
---------------------------------------------------------------------------
local function openMachine(ent)
	closeFrame()
	local printer = P.IsPrinter(ent)
	frame = UI.Frame(label(ent), math.min(S(printer and 880 or 480), ScrW() - S(40)), math.min(S(printer and 600 or 260), ScrH() - S(40)))
	local body = vgui.Create("DPanel", frame)
	body:Dock(FILL) body:DockMargin(S(4), S(30), S(4), S(4)) body:SetPaintBackground(false)

	if printer then
		local left = vgui.Create("DPanel", body)
		left:Dock(LEFT) left:SetWide(S(330)) left:DockMargin(0, 0, S(10), 0)
		function left:Paint(w, h)
			if not IsValid(ent) then return end
			local id = UI.PrinterColor(ent)
			draw.RoundedBox(S(8), 0, 0, w, h, C.panel)
			draw.RoundedBoxEx(S(8), 0, 0, w, S(4), id, true, true, false, false)
			-- Stock
			local money, cap = tonumber(ent:GetMoney()) or 0, P.Capacity(ent)
			local frac = cap > 0 and money / cap or 0
			sectionTitle("STOCK", S(16), S(16))
			draw.SimpleText(UI.Money(money), "Astral.UI.Huge", S(16), S(30), frac >= 1 and C.good or C.text)
			draw.SimpleText("sur " .. UI.Money(cap) .. "  ·  " .. math.floor(frac * 100) .. " %", "Astral.UI.Small", S(16), S(66), C.dim)
			UI.Bar(S(16), S(88), w - S(32), S(8), frac, frac >= 1 and C.good or id)
			-- État
			local disabled, powered = ent:GetNWBool("printer_disabled"), ent:IsPowered()
			local state, scol = "En marche", C.good
			if disabled then state, scol = "Désactivée par un admin", C.bad
			elseif not powered then state, scol = "Hors tension", C.bad
			elseif (ent:GetPaper() or 0) <= 0 then state, scol = "Plus de papier", C.bad
			elseif frac >= 1 then state, scol = "Pleine", C.warn end
			local perMin = P.PerMinute(ent)
			local y, step = S(116), S(30)
			row(w, y, "État", state, scol) y = y + step
			row(w, y, "Production", UI.Money(perMin) .. " / min", C.good) y = y + step
			row(w, y, "Plein dans", frac >= 1 and "—" or (perMin > 0 and duration((cap - money) / (perMin / 60)) or "—")) y = y + step
			local interval = (scripted_ents.GetStored(ent:GetClass()) or { t = {} }).t.PrintInterval or ent.PrintInterval or 1
			row(w, y, "Cycle", (string.format("%.2f s", interval * P.IntervalMul(ent)):gsub("%.", ","))) y = y + step
			-- Papier
			local paper, maxPaper = math.floor(ent:GetPaper() or 0), ent.MaxPaper or 1
			row(w, y, "Papier", UI.Num(paper) .. " / " .. UI.Num(maxPaper), paper > 0 and C.text or C.bad)
			UI.Bar(S(16), y + S(20), w - S(32), S(5), paper / math.max(maxPaper, 1), C.accent2) y = y + step + S(8)
			-- Énergie
			local pw, pmax = ent:GetPower() or 0, math.max(ent:GetMaxPower() or 1, 1)
			row(w, y, "Énergie", UI.Num(pw) .. " / " .. UI.Num(pmax), powered and C.text or C.bad)
			UI.Bar(S(16), y + S(20), w - S(32), S(5), pw / pmax, C.warn) y = y + step + S(8)
			row(w, y, "Consommation", UI.Num(ent.PowerRequired or 0) .. " / cycle", P.PowerMul(ent) > 1 and C.warn or C.text) y = y + step
			-- PV
			local hp, hmax = math.max(ent:Health(), 0), math.max(ent:GetMaxHealth(), 1)
			row(w, y, "Points de vie", UI.Num(hp) .. " / " .. UI.Num(hmax), hp / hmax < 0.25 and C.bad or C.text)
			UI.Bar(S(16), y + S(20), w - S(32), S(5), hp / hmax, C.good)
		end
		local collect = UI.Button(left, "", C.good, function() send("Astral.Printer.Collect", ent) end)
		collect:Dock(BOTTOM) collect:DockMargin(S(12), 0, S(12), S(12)) collect:SetTall(S(40))
		function collect:Think()
			if not IsValid(ent) then return end
			local m = tonumber(ent:GetMoney()) or 0
			self:SetText(m > 0 and ("Récolter " .. UI.Money(m)) or "Rien à récolter")
			self:SetDisabled(m <= 0)
		end

		local right = vgui.Create("DScrollPanel", body)
		right:Dock(FILL)
		levelCard(right, ent)
		local hdr = vgui.Create("DPanel", right)
		hdr:Dock(TOP) hdr:SetTall(S(24)) hdr:DockMargin(S(2), S(4), 0, S(2))
		function hdr:Paint(w, h) draw.SimpleText("AMÉLIORATIONS ASTRAL", "Astral.UI.Tiny", 0, h / 2, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end
		for _, u in ipairs(P.Upgrades) do upgradeCard(right, ent, u) end
	else
		levelCard(body, ent)
	end

	frame.ent = ent
	function frame:Think() if not owned(ent) then self:Close() end end
end

---------------------------------------------------------------------------
-- Menu de la Banque Astral
---------------------------------------------------------------------------
local function openBank(bank)
	closeFrame()
	frame = UI.Frame("Banque Astral", math.min(S(920), ScrW() - S(40)), math.min(S(720), ScrH() - S(40)))
	local body = vgui.Create("DPanel", frame)
	body:Dock(FILL) body:DockMargin(S(4), S(30), S(4), S(4)) body:SetPaintBackground(false)
	local function connected()
		local list = {}
		for _, e in ipairs(bank:AstralConnected()) do if IsValid(e) then list[#list + 1] = e end end
		return list
	end

	-- Résumé
	local top = vgui.Create("DPanel", body)
	top:Dock(TOP) top:SetTall(S(104)) top:DockMargin(0, 0, 0, S(8))
	local take = UI.Button(top, "", C.good, function() send("Astral.Bank.Action", bank, P.BankActions.collect, 3, 0, 4) end)
	take:SetSize(S(200), S(40))
	function top:PerformLayout(w, h) take:SetPos(w - take:GetWide() - S(16), (h - take:GetTall()) / 2) end
	function top:Paint(w, h)
		if not IsValid(bank) then return end
		local list, rate, stock = connected(), 0, 0
		for _, e in ipairs(list) do
			rate = rate + (e:IsPowered() and P.PerMinute(e) or 0)
			stock = stock + (tonumber(e:GetMoney()) or 0)
		end
		UI.Card(0, 0, w, h, C.good)
		sectionTitle("EN BANQUE", S(18), S(14))
		draw.SimpleText(UI.Money(bank:GetMoney()), "Astral.UI.Huge", S(18), S(28), C.good)
		draw.SimpleText(#list .. " imprimante(s) connectée(s)  ·  " .. UI.Money(rate) .. " / min  ·  en attente : " .. UI.Money(stock),
			"Astral.UI.Small", S(18), S(70), C.dim)
		local powered = bank:IsPowered()
		draw.SimpleText(powered and "EN LIGNE" or "HORS TENSION", "Astral.UI.Tiny", w - S(232), S(14), powered and C.good or C.bad, TEXT_ALIGN_RIGHT)
	end
	function take:Think()
		if not IsValid(bank) then return end
		local m = bank:GetMoney()
		self:SetText(m > 0 and ("Tout récolter") or "Banque vide")
		self:SetDisabled(m <= 0 or not bank:IsPowered())
	end

	-- Améliorations groupées
	local actions = vgui.Create("DPanel", body)
	actions:Dock(BOTTOM) actions:SetTall(S(150)) actions:DockMargin(0, S(8), 0, 0)
	function actions:Paint(w, h)
		UI.Card(0, 0, w, h, C.accent)
		sectionTitle("TOUT AMÉLIORER  ·  des imprimantes les moins chères aux plus chères, tant que ton argent suffit", S(18), S(12))
	end
	local grid = actions
	local defs = { { name = "Niveau +1", action = P.BankActions.level, kind = 0 } }
	for _, u in ipairs(P.Upgrades) do defs[#defs + 1] = { name = u.name, action = P.BankActions.upgrade, kind = u.index, u = u } end
	for _, d in ipairs(defs) do
		local b = UI.Button(grid, "", d.u and (d.u.id == "overclock" and C.warn or C.accent) or C.xp, function()
			send("Astral.Bank.Action", bank, d.action, 3, d.kind, 4)
		end)
		b:SetSize(S(250), S(44))
		b:SetFont("Astral.UI.Small")
		function b:Think()
			if not IsValid(bank) then return end
			local total, n = 0, 0
			for _, e in ipairs(connected()) do
				local c
				if d.u then c = P.Cost(e, d.u.id)
				elseif e:GetLevel() < e.MaxLevel then c = e:GetNWInt("UpgradeCost", 0) * e:GetLevel() end
				if c then total, n = total + c, n + 1 end
			end
			if n == 0 then self:SetText(d.name .. "  ·  rien à améliorer") self:SetDisabled(true) return end
			self:SetText(d.name .. " (" .. n .. ")  ·  " .. UI.Money(total))
			self:SetDisabled(false)
		end
	end
	-- Boutons placés à la main sur 3 colonnes (DIconLayout recalculait mal les largeurs : boutons coupés)
	function actions:PerformLayout(w, h)
		local cols, gap = 3, S(8)
		local bw = math.floor((w - S(32) - gap * (cols - 1)) / cols)
		for i, c in ipairs(self:GetChildren()) do
			local col, line = (i - 1) % cols, math.floor((i - 1) / cols)
			c:SetPos(S(16) + col * (bw + gap), S(36) + line * (S(44) + gap))
			c:SetSize(bw, S(44))
		end
	end

	-- Liste des imprimantes connectées : en-tête fixe + lignes défilantes
	local list = vgui.Create("DPanel", body)
	list:Dock(FILL)
	local RH = S(32)
	function list:Paint(w, h)
		if not IsValid(bank) then return end
		draw.RoundedBox(S(8), 0, 0, w, h, C.panel)
		sectionTitle("IMPRIMANTE", S(16), S(10))
		sectionTitle("NIVEAU", w * 0.42, S(10))
		sectionTitle("AMÉLIORATIONS", w * 0.54, S(10))
		sectionTitle("STOCK", w * 0.76, S(10))
		draw.SimpleText("PROD. / MIN", "Astral.UI.Tiny", w - S(30), S(10), C.dim, TEXT_ALIGN_RIGHT)
		if #connected() == 0 then
			draw.SimpleText("Aucune imprimante à toi dans un rayon de " .. math.floor((bank.Radius or 1200) * 0.01905) .. " m.",
				"Astral.UI.Text", w / 2, h / 2, C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end
	local scroll = vgui.Create("DScrollPanel", list)
	scroll:Dock(FILL) scroll:DockMargin(0, S(28), 0, S(6))
	local sbar = scroll:GetVBar()
	sbar:SetWide(S(8))
	function sbar:Paint(w, h) draw.RoundedBox(S(4), 0, 0, w, h, Color(255, 255, 255, 8)) end
	function sbar.btnGrip:Paint(w, h) draw.RoundedBox(S(4), 0, 0, w, h, C.line) end
	sbar.btnUp:SetVisible(false) sbar.btnDown:SetVisible(false)
	local rows = vgui.Create("DPanel", scroll)
	rows:Dock(TOP)
	function rows:Think()
		local n = IsValid(bank) and #connected() or 0
		if self:GetTall() ~= n * RH then self:SetTall(n * RH) end
	end
	function rows:Paint(w, h)
		if not IsValid(bank) then return end
		local items = connected()
		table.sort(items, function(a, b) return P.PerMinute(a) > P.PerMinute(b) end)
		w = list:GetWide() - S(14)
		local rh, y = RH, 0
		for i, e in ipairs(items) do
			if i % 2 == 0 then draw.RoundedBox(S(4), S(6), y, w - S(12), rh, Color(255, 255, 255, 6)) end
			local id = UI.PrinterColor(e)
			draw.RoundedBox(S(3), S(16), y + rh / 2 - S(6), S(12), S(12), id)
			local col = e:IsPowered() and C.text or C.bad
			draw.SimpleText(UI.Truncate(label(e), "Astral.UI.Small", w * 0.42 - S(48)), "Astral.UI.Small", S(36), y + rh / 2, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText(e:GetLevel() .. " / " .. e.MaxLevel, "Astral.UI.Small", w * 0.42, y + rh / 2, C.xp, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			local px = w * 0.54
			for _, u in ipairs(P.Upgrades) do
				local r = P.Rank(e, u.id)
				for k = 1, u.max do
					draw.RoundedBox(S(2), px, y + rh / 2 - S(4), S(6), S(8), k <= r and (u.id == "overclock" and C.warn or C.accent) or C.line)
					px = px + S(8)
				end
				px = px + S(8)
			end
			draw.SimpleText(UI.Money(e:GetMoney()), "Astral.UI.Small", w * 0.76, y + rh / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText(e:IsPowered() and UI.Money(P.PerMinute(e)) or "hors tension", "Astral.UI.Small", w - S(16), y + rh / 2,
				e:IsPowered() and C.good or C.bad, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			y = y + rh
		end
	end

	frame.ent = bank
	function frame:Think() if not owned(bank) then self:Close() end end
end

---------------------------------------------------------------------------
-- Touches
---------------------------------------------------------------------------
hook.Add("PlayerBindPress", "Astral.Upgrade", function(ply, bind, pressed)
	if not pressed or not bind:find("+use", 1, true) then return end
	local ent = ply:GetEyeTrace().Entity
	if not owned(ent) then return end   -- machine d'un autre joueur : comportement d'origine
	local shift = input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT)
	if P.IsPrinter(ent) then
		if shift then send("Astral.Printer.Collect", ent) else openMachine(ent) end
		return true
	elseif isBank(ent) then
		if shift then send("Astral.Bank.Action", ent, P.BankActions.collect, 3, 0, 4) else openBank(ent) end
		return true
	elseif shift and upgradable(ent) then
		openMachine(ent)
		return true
	end
end)

-- Indication à l'écran en visant sa machine
hook.Add("HUDPaint", "Astral.Upgrade.Hint", function()
	if IsValid(frame) or not GetConVar("astral_hud"):GetBool() then return end
	local ent = LocalPlayer():GetEyeTrace().Entity
	if not owned(ent) then return end
	local txt
	if P.IsPrinter(ent) then txt = "E  ·  Gérer et améliorer      Maj + E  ·  Récolter"
	elseif isBank(ent) then txt = "E  ·  Ouvrir la banque      Maj + E  ·  Tout récolter"
	elseif upgradable(ent) then txt = "Maj + E  ·  Améliorer (niveau " .. ent:GetLevel() .. "/" .. ent.MaxLevel .. ")"
	else return end
	surface.SetFont("Astral.UI.Small")
	local tw, th = surface.GetTextSize(txt)
	local x, y = ScrW() / 2 - tw / 2 - S(12), ScrH() / 2 + S(84)
	draw.RoundedBox(S(6), x, y, tw + S(24), th + S(10), Color(10, 13, 26, 200))
	draw.SimpleText(txt, "Astral.UI.Small", ScrW() / 2, y + (th + S(10)) / 2, C.accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

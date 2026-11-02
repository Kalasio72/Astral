-- Astral UI — fermes : menu d'une ferme (E), récolte directe (Maj + E), revente au receleur, tarifs,
-- indicateur du sac et effet des feux d'artifice. Logique serveur : astral/farms/sv_farms.lua.

local UI = Astral.UI
local C, S = UI.Colors, UI.Scale
local F = Astral.Farms

local function send(name, ent)
	net.Start(name) if ent then net.WriteEntity(ent) end net.SendToServer()
	surface.PlaySound("ui/buttonclick.wav")
end
local function duration(s)
	s = math.max(0, math.floor(s))
	if s >= 60 then return string.format("%d min %02d s", math.floor(s / 60), s % 60) end
	return s .. " s"
end

---------------------------------------------------------------------------
-- Menu d'une ferme
---------------------------------------------------------------------------
local frame
local function openFarm(ent)
	if IsValid(frame) then frame:Close() end
	local def = ent.Farm
	if not def then return end
	local prod = F.Products[def.product]
	frame = UI.Frame(def.name, S(560), S(def.heat and 470 or 400))
	local info = vgui.Create("DPanel", frame)
	info:Dock(FILL) info:DockMargin(S(6), S(34), S(6), S(8))
	function info:Paint(w, h)
		if not IsValid(ent) then return end
		draw.RoundedBox(S(8), 0, 0, w, h, C.panel)
		draw.RoundedBoxEx(S(8), 0, 0, w, S(4), def.color, true, true, false, false)
		local stock, prog = ent:GetNW2Int("AstralFarmStock", 0), ent:GetNW2Float("AstralFarmProg", 0)
		local on = ent:IsPowered()
		draw.SimpleText("PRODUIT", "Astral.UI.Tiny", S(16), S(16), C.dim)
		draw.RoundedBox(S(4), S(16), S(36), S(14), S(14), prod.color)
		draw.SimpleText(prod.name, "Astral.UI.Big", S(38), S(30), C.text)
		draw.SimpleText(UI.Money(prod.value) .. " / unité chez le receleur", "Astral.UI.Small", w - S(16), S(34), C.good, TEXT_ALIGN_RIGHT)
		-- Lot en cours
		local full = stock >= def.stock
		local state = not on and "Hors tension" or (full and "Stock plein : récolte !" or ("Lot suivant dans " .. duration((1 - prog) * def.seconds / (Astral.Events and Astral.Events.Mult("farm") or 1))))
		draw.SimpleText("PRODUCTION", "Astral.UI.Tiny", S(16), S(76), C.dim)
		draw.SimpleText(state, "Astral.UI.Text", S(16), S(92), (not on) and C.bad or (full and C.warn or C.text))
		UI.Bar(S(16), S(122), w - S(32), S(10), full and 1 or prog, full and C.warn or def.color)
		-- Stock
		draw.SimpleText("EN ATTENTE", "Astral.UI.Tiny", S(16), S(150), C.dim)
		draw.SimpleText(stock .. " / " .. def.stock .. " lots  ·  " .. (stock * def.yield) .. " unités  ·  " .. UI.Money(stock * def.yield * prod.value),
			"Astral.UI.Text", S(16), S(166), C.text)
		for i = 1, def.stock do
			draw.RoundedBox(S(4), S(16) + (i - 1) * S(34), S(196), S(28), S(12), i <= stock and def.color or C.line)
		end
		-- Température (labo de méthamphétamine)
		if def.heat then
			local heat = ent:GetNW2Float("AstralFarmHeat", 20)
			local hc = heat >= 80 and C.bad or (heat >= 60 and C.warn or C.good)
			draw.SimpleText("TEMPÉRATURE DE LA CUVE", "Astral.UI.Tiny", S(16), S(226), C.dim)
			draw.SimpleText(math.floor(heat) .. " °C", "Astral.UI.Big", S(16), S(242), hc)
			draw.SimpleText("Explosion à 100 °C : purge régulièrement", "Astral.UI.Small", w - S(16), S(248), heat >= 80 and C.bad or C.dim, TEXT_ALIGN_RIGHT)
			UI.Bar(S(16), S(276), w - S(32), S(10), (heat - 20) / 80, hc)
		end
		-- Sac
		local bag = F.Bag(LocalPlayer())
		draw.SimpleText("Ton sac : " .. F.BagCount(bag) .. " / " .. F.BagMax .. " unités  ·  " .. UI.Money(F.BagValue(bag)),
			"Astral.UI.Small", S(16), h - S(30), C.dim)
	end
	local btns = vgui.Create("DPanel", frame)
	btns:Dock(BOTTOM) btns:SetTall(S(44)) btns:DockMargin(S(6), 0, S(6), S(6)) btns:SetPaintBackground(false)
	local collect = UI.Button(btns, "Mettre dans mon sac", C.good, function() send("Astral.Farm.Collect", ent) end)
	collect:Dock(FILL)
	if def.heat then
		local vent = UI.Button(btns, "Purger la cuve", C.warn, function() send("Astral.Farm.Vent", ent) end)
		vent:Dock(RIGHT) vent:SetWide(S(200)) vent:DockMargin(S(8), 0, 0, 0)
	end
	function frame:Think()
		if not IsValid(ent) or LocalPlayer():GetPos():DistToSqr(ent:GetPos()) > 200 ^ 2 then self:Close() return end
		collect:SetDisabled(ent:GetNW2Int("AstralFarmStock", 0) <= 0)
	end
end

net.Receive("Astral.Farm.Open", function()
	local ent = net.ReadEntity()
	if IsValid(ent) and ent.IsAstralFarm then openFarm(ent) end
end)

-- Maj + E sur sa ferme : récolte directe (E seul : menu, via le serveur)
hook.Add("PlayerBindPress", "Astral.Farms", function(ply, bind, pressed)
	if not pressed or not bind:find("+use", 1, true) then return end
	if not (input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT)) then return end
	local ent = ply:GetEyeTrace().Entity
	if not (IsValid(ent) and ent.IsAstralFarm) then return end
	if (ent.CPPIGetOwner and ent:CPPIGetOwner()) ~= ply or ply:GetPos():DistToSqr(ent:GetPos()) > 150 ^ 2 then return end
	send("Astral.Farm.Collect", ent)
	return true
end)

---------------------------------------------------------------------------
-- Receleur : revente et tarifs
---------------------------------------------------------------------------
function F.OpenDealer(npc)
	if IsValid(frame) then frame:Close() end
	frame = UI.Frame("Silas — Receleur", S(560), S(460))
	local list = vgui.Create("DPanel", frame)
	list:Dock(FILL) list:DockMargin(S(6), S(34), S(6), S(8))
	function list:Paint(w, h)
		draw.RoundedBox(S(8), 0, 0, w, h, C.panel)
		local bag, y = F.Bag(LocalPlayer()), S(16)
		draw.SimpleText("CONTENU DE TON SAC", "Astral.UI.Tiny", S(16), y, C.dim)
		y = y + S(24)
		local mult = Astral.Events and Astral.Events.Mult("farm_sell") or 1
		local any = false
		for _, id in ipairs(F.ProductOrder) do
			local q = bag[id]
			if q and q > 0 then
				any = true
				local p = F.Products[id]
				draw.RoundedBox(S(4), S(16), y + S(5), S(14), S(14), p.color)
				draw.SimpleText(p.name .. "  × " .. q, "Astral.UI.Text", S(40), y, C.text)
				draw.SimpleText(UI.Money(p.value * q * mult), "Astral.UI.Text", w - S(16), y, C.good, TEXT_ALIGN_RIGHT)
				y = y + S(32)
			end
		end
		if not any then draw.SimpleText("Ton sac est vide. Produis dans tes fermes, puis reviens.", "Astral.UI.Text", S(16), y, C.dim) y = y + S(32) end
		surface.SetDrawColor(C.line) surface.DrawRect(S(16), y + S(6), w - S(32), 1)
		draw.SimpleText("Total", "Astral.UI.Big", S(16), y + S(16), C.text)
		draw.SimpleText(UI.Money(F.BagValue(bag) * mult), "Astral.UI.Big", w - S(16), y + S(16), C.good, TEXT_ALIGN_RIGHT)
		if mult > 1 then draw.SimpleText("Événement en cours : prix × " .. mult, "Astral.UI.Small", S(16), y + S(50), C.warn) end
		draw.SimpleText("Attention : si tu meurs, ton sac tombe au sol.", "Astral.UI.Small", S(16), h - S(30), C.dim)
	end
	local row = vgui.Create("DPanel", frame)
	row:Dock(BOTTOM) row:SetTall(S(44)) row:DockMargin(S(6), 0, S(6), S(6)) row:SetPaintBackground(false)
	local sell = UI.Button(row, "Tout vendre", C.good, function() send("Astral.Farm.Sell", npc) end)
	sell:Dock(FILL)
	local fire = UI.Button(row, "Tirer un feu d'artifice", Color(255, 90, 200), function() send("Astral.Farm.Launch") end)
	fire:Dock(RIGHT) fire:SetWide(S(220)) fire:DockMargin(S(8), 0, 0, 0)
	function frame:Think()
		local bag = F.Bag(LocalPlayer())
		sell:SetDisabled(F.BagCount(bag) <= 0)
		fire:SetDisabled((bag.firework or 0) <= 0)
		if not IsValid(npc) or LocalPlayer():GetPos():DistToSqr(npc:GetPos()) > 200 ^ 2 then self:Close() end
	end
end

function F.OpenPrices()
	if IsValid(frame) then frame:Close() end
	frame = UI.Frame("Les fermes Astral", S(720), S(470))
	local p = vgui.Create("DPanel", frame)
	p:Dock(FILL) p:DockMargin(S(6), S(34), S(6), S(6))
	function p:Paint(w, h)
		draw.RoundedBox(S(8), 0, 0, w, h, C.panel)
		local cols = { S(16), w * 0.40, w * 0.58, w * 0.76 }
		for i, t in ipairs({ "MACHINE (F4 → Astral Fermes)", "NIVEAU", "PRIX", "RAPPORT / LOT" }) do draw.SimpleText(t, "Astral.UI.Tiny", cols[i], S(14), C.dim) end
		for i, class in ipairs(F.MachineOrder) do
			local def = F.Machines[class]
			local prod = F.Products[def.product]
			local y = S(40) + (i - 1) * S(62)
			if i % 2 == 0 then draw.RoundedBox(S(6), S(6), y - S(6), w - S(12), S(56), Color(255, 255, 255, 6)) end
			draw.RoundedBox(S(4), S(16), y + S(4), S(12), S(12), def.color)
			draw.SimpleText(def.name, "Astral.UI.Text", S(36), y, C.text)
			draw.SimpleText(prod.name .. " · " .. def.yield .. " u. toutes les " .. duration(def.seconds), "Astral.UI.Small", S(36), y + S(22), C.dim)
			draw.SimpleText(tostring(def.level), "Astral.UI.Text", cols[2], y, C.xp)
			draw.SimpleText(UI.Money(def.price), "Astral.UI.Text", cols[3], y, C.text)
			draw.SimpleText(UI.Money(def.yield * prod.value), "Astral.UI.Text", cols[4], y, C.good)
		end
		draw.SimpleText("Labo de méthamphétamine : purge la cuve avant 100 °C, sinon il explose.", "Astral.UI.Small", S(16), h - S(30), C.warn)
	end
end

---------------------------------------------------------------------------
-- Indicateur du sac (au-dessus du HUD, seulement s'il contient quelque chose)
---------------------------------------------------------------------------
hook.Add("HUDPaint", "Astral.Farms.Bag", function()
	local me = LocalPlayer()
	if not IsValid(me) or not me:Alive() or not GetConVar("astral_hud"):GetBool() then return end
	local bag = F.Bag(me)
	local n = F.BagCount(bag)
	if n <= 0 then return end
	local txt = "Sac : " .. n .. " / " .. F.BagMax .. "  ·  " .. UI.Money(F.BagValue(bag))
	surface.SetFont("Astral.UI.Small")
	local tw, th = surface.GetTextSize(txt)
	local w, h = tw + S(40), th + S(14)
	local x, y = S(24), ScrH() - S(200) - h
	draw.RoundedBox(S(8), x, y, w, h, C.bg)
	draw.RoundedBox(S(3), x + S(10), y + h / 2 - S(5), S(10), S(10), Color(255, 150, 80))
	draw.SimpleText(txt, "Astral.UI.Small", x + S(28), y + h / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end)

---------------------------------------------------------------------------
-- Feux d'artifice (aussi déclenchés par les événements)
---------------------------------------------------------------------------
local glow = Material("sprites/light_glow02_add")
function F.PlayFirework(start, burst, hue)
	local emitter = ParticleEmitter(start)
	if not emitter then return end
	sound.Play("weapons/rpg/rocketfire1.wav", start, 80, 140)
	local t0, rise = CurTime(), 1.4
	local id = "Astral.Firework." .. math.random(1, 1e6)
	hook.Add("Think", id, function()
		local f = (CurTime() - t0) / rise
		if f >= 1 then
			hook.Remove("Think", id)
			sound.Play("ambient/explosions/explode_" .. math.random(1, 3) .. ".wav", burst, 100, math.random(110, 140))
			local base = HSVToColor(hue, 0.8, 1)
			for i = 1, 140 do
				local c = (i % 3 == 0) and HSVToColor((hue + 40) % 360, 0.6, 1) or base
				local p = emitter:Add(glow, burst)
				if p then
					p:SetVelocity(VectorRand():GetNormalized() * math.Rand(250, 420))
					p:SetDieTime(math.Rand(1.6, 2.4))
					p:SetStartAlpha(255) p:SetEndAlpha(0)
					p:SetStartSize(math.Rand(18, 26)) p:SetEndSize(2)
					p:SetColor(c.r, c.g, c.b)
					p:SetGravity(Vector(0, 0, -160)) p:SetAirResistance(70)
				end
			end
			emitter:Finish()
			local dl = DynamicLight(math.random(4000, 5000))
			if dl then dl.pos = burst dl.r, dl.g, dl.b = base.r, base.g, base.b dl.brightness = 6 dl.size = 1400 dl.decay = 1500 dl.dietime = CurTime() + 1.5 end
			return
		end
		local pos = LerpVector(f * f, start, burst)
		local p = emitter:Add(glow, pos)
		if p then
			p:SetDieTime(0.5) p:SetStartAlpha(220) p:SetEndAlpha(0)
			p:SetStartSize(14) p:SetEndSize(0) p:SetColor(255, 200, 120)
		end
	end)
end

net.Receive("Astral.Firework", function()
	local start, burst, hue = net.ReadVector(), net.ReadVector(), net.ReadUInt(9)
	F.PlayFirework(start, burst, hue)
end)

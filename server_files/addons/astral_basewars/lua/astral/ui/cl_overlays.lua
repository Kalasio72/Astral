-- Astral UI — notifications (toasts), écran d'absence et bandeau de raid.
-- Remplace les affichages SpaceVX « BaseWars.Notify.Paint », « BaseWars.AFK.Paint » et « BaseWars.Raid.Paint ».
-- Les données restent celles de SpaceVX (BaseWars.Notify:Add, ply.afk, BaseWars.Raid) : seul le dessin change.
-- Le remplacement des hooks est géré par cl_hud.lua (Astral.UI.Replace) et suit la convar astral_hud.

local UI = Astral.UI
local C = UI.Colors
local S = UI.Scale

---------------------------------------------------------------------------
-- Toasts
---------------------------------------------------------------------------
local toasts = {}
local LIFETIME, MAX = 6, 6

-- Les couleurs SpaceVX (rouge, vert, magenta pur…) sont converties vers la charte Astral
local function themeColor(col)
	if not col then return C.accent end
	local map = {
		[BASEWARS_NOTIFICATION_ERROR] = C.bad,
		[BASEWARS_NOTIFICATION_MONEY] = C.good,
		[BASEWARS_NOTIFICATION_RAID] = C.warn,
		[BASEWARS_NOTIFICATION_GENRL] = C.accent2,
		[BASEWARS_NOTIFICATION_DRUG] = C.accent,
	}
	for ref, themed in pairs(map) do
		if ref and ref.r == col.r and ref.g == col.g and ref.b == col.b then return themed end
	end
	return C.accent
end

function UI.Toast(text, col)
	table.insert(toasts, 1, { text = tostring(text), col = themeColor(col), born = RealTime() })
	while #toasts > MAX do table.remove(toasts) end
end

local function drawToasts()
	local now = RealTime()
	local x = ScrW() - S(24)
	local y = S(40)
	surface.SetFont("Astral.UI.Text")
	for i = #toasts, 1, -1 do
		if now - toasts[i].born > LIFETIME then table.remove(toasts, i) end
	end
	for _, t in ipairs(toasts) do
		local age = now - t.born
		local appear = math.Clamp(age / 0.2, 0, 1)
		local fade = math.Clamp((LIFETIME - age) / 0.5, 0, 1)
		local tw, th = surface.GetTextSize(t.text)
		local w, h = tw + S(32), th + S(16)
		local slide = (1 - appear) * S(40)
		local bx = x - w + slide
		local a = 255 * fade
		draw.RoundedBox(S(6), bx, y, w, h, ColorAlpha(C.bg, C.bg.a * fade))
		draw.RoundedBoxEx(S(6), bx, y, S(4), h, ColorAlpha(t.col, a), true, false, true, false)
		draw.SimpleText(t.text, "Astral.UI.Text", bx + S(16), y + h / 2, ColorAlpha(C.text, a), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		y = y + h + S(6)
	end
end

---------------------------------------------------------------------------
-- Écran d'absence
---------------------------------------------------------------------------
local function drawAFK(me)
	if not me.afk or not me.AFKTime then return end
	local w, h = S(320), S(90)
	local x, y = ScrW() / 2 - w / 2, ScrH() / 3 - h / 2
	UI.Card(x, y, w, h, C.warn)
	UI.Text("Vous êtes absent", "Astral.UI.Big", ScrW() / 2, y + S(14), C.warn, TEXT_ALIGN_CENTER)
	UI.Text(BaseWars.UTIL.TimeParse(math.floor(me:AFKTime())), "Astral.UI.Huge", ScrW() / 2, y + S(42), C.text, TEXT_ALIGN_CENTER)
end

---------------------------------------------------------------------------
-- Bandeau de raid
---------------------------------------------------------------------------
local function drawRaid(me)
	local raid = BaseWars.Raid
	if not raid or not raid:IsOnGoing() then return end
	local left = raid.State.TimeRemaining or 0
	local total = math.max(BaseWars.Config.Raid.Time, 1)
	local ok, n1, n2 = pcall(raid.GetVersus, raid)
	local versus = ok and (n1 .. "  contre  " .. n2) or "Raid"
	local w, h = S(420), S(78)
	local x, y = ScrW() / 2 - w / 2, ScrH() - h - S(24)
	local pulse = left >= total - 5 and (math.sin(RealTime() * 8) * 0.5 + 0.5) or 0
	UI.Card(x, y, w, h, Color(C.bad.r, C.bad.g * (1 - pulse * 0.5), C.bad.b))
	UI.Text(me:InRaid() and "RAID EN COURS — VOUS PARTICIPEZ" or "RAID EN COURS", "Astral.UI.Small", ScrW() / 2, y + S(8), C.bad, TEXT_ALIGN_CENTER)
	UI.Text(versus, "Astral.UI.Big", ScrW() / 2, y + S(24), C.text, TEXT_ALIGN_CENTER)
	UI.Bar(x + S(20), y + h - S(18), w - S(110), S(6), left / total, C.bad)
	UI.Text(string.format("%d:%02d", math.floor(left / 60), left % 60), "Astral.UI.Text", x + w - S(20), y + h - S(24), C.text, TEXT_ALIGN_RIGHT)
end

---------------------------------------------------------------------------
-- Annonces administrateur : bandeau central quelques secondes + ligne de chat
---------------------------------------------------------------------------
local announce
net.Receive("Astral.Announce", function()
	local text = net.ReadString()
	announce = { text = text, born = RealTime() }
	chat.AddText(C.warn, "[Annonce] ", C.text, text)
	surface.PlaySound("buttons/blip1.wav")
end)

local function drawAnnounce()
	if not announce then return end
	local age = RealTime() - announce.born
	if age > 8 then announce = nil return end
	local a = math.Clamp(math.min(age / 0.3, (8 - age) / 0.6), 0, 1)
	surface.SetFont("Astral.UI.Big")
	local tw = surface.GetTextSize(announce.text)
	local w, h = tw + S(60), S(70)
	local x, y = ScrW() / 2 - w / 2, S(70)
	draw.RoundedBox(S(10), x, y, w, h, ColorAlpha(C.bg, 235 * a))
	draw.RoundedBoxEx(S(10), x, y, w, S(4), ColorAlpha(C.warn, 255 * a), true, true, false, false)
	draw.SimpleText("ANNONCE", "Astral.UI.Tiny", ScrW() / 2, y + S(14), ColorAlpha(C.warn, 255 * a), TEXT_ALIGN_CENTER)
	draw.SimpleText(announce.text, "Astral.UI.Big", ScrW() / 2, y + S(30), ColorAlpha(C.text, 255 * a), TEXT_ALIGN_CENTER)
end

---------------------------------------------------------------------------
-- Réapparition (anti-RDM SpaceVX : NWInt « RespawnTime » posé par le serveur)
---------------------------------------------------------------------------
local respawnMax = 0
local function drawRespawn(me)
	if me:Alive() or (me.IsAFK and me:IsAFK()) then respawnMax = 0 return end
	local left = me.GetRespawnTime and me:GetRespawnTime() or 0
	if left < 1 then respawnMax = 0 return end
	respawnMax = math.max(respawnMax, left)
	local w, h = S(300), S(104)
	local x, y = ScrW() / 2 - w / 2, ScrH() / 3 - h / 2
	UI.Card(x, y, w, h, C.bad)
	UI.Text("RÉAPPARITION DANS", "Astral.UI.Small", ScrW() / 2, y + S(12), C.bad, TEXT_ALIGN_CENTER)
	UI.Text(string.format("%02d:%02d", math.floor(left / 60) % 60, math.floor(left) % 60), "Astral.UI.Huge", ScrW() / 2, y + S(32), C.text, TEXT_ALIGN_CENTER)
	UI.Bar(x + S(24), y + h - S(18), w - S(48), S(6), 1 - left / math.max(respawnMax, 1), C.bad)
end

---------------------------------------------------------------------------
-- Radar (minimap SpaceVX : actif quand le joueur possède un bw_radar alimenté, NW2Bool « BaseWars_HasRadar »)
-- Même calcul que cl_minimap.lua : vue du dessus tournée avec le regard du joueur, portée Config.RadarRange.
---------------------------------------------------------------------------
local circleCache = {}
local function circle(x, y, r, seg)
	local k = x .. ":" .. y .. ":" .. r
	local poly = circleCache[k]
	if not poly then
		poly = {}
		for i = 1, seg do
			local a = math.rad(i / seg * 360)
			poly[i] = { x = x + math.cos(a) * r, y = y + math.sin(a) * r }
		end
		circleCache[k] = poly
	end
	draw.NoTexture()
	surface.DrawPoly(poly)
end

local function ring(x, y, r, col)
	surface.SetDrawColor(col)
	local seg, prev = 48
	for i = 0, seg do
		local a = math.rad(i / seg * 360)
		local px, py = x + math.cos(a) * r, y + math.sin(a) * r
		if prev then surface.DrawLine(prev[1], prev[2], px, py) end
		prev = { px, py }
	end
end

local function blip(x, y, size, yaw, col)
	local a = math.rad(yaw)
	local function pt(ang, r) return { x = x + math.sin(a + ang) * r, y = y - math.cos(a + ang) * r } end
	surface.SetDrawColor(col)
	draw.NoTexture()
	surface.DrawPoly({ pt(0, size), pt(2.5, size * 0.8), pt(math.pi, size * 0.25), pt(-2.5, size * 0.8) })
end

local function drawRadar(me)
	if not me:Alive() or not me:GetNW2Bool("BaseWars_HasRadar", false) then return end
	local range = BaseWars.Config.RadarRange or 1500
	local R = S(78)
	local cx, cy = ScrW() - S(24) - R, ScrH() - S(24) - S(74) - S(16) - R   -- au-dessus de la carte de munitions
	surface.SetDrawColor(ColorAlpha(C.bg, 225)) circle(cx, cy, R, 48)
	ring(cx, cy, R, ColorAlpha(C.accent, 120))
	ring(cx, cy, R * 0.5, ColorAlpha(C.line, 160))
	surface.SetDrawColor(ColorAlpha(C.line, 120))
	surface.DrawLine(cx - R, cy, cx + R, cy) surface.DrawLine(cx, cy - R, cx, cy + R)
	-- Balayage
	local sweep = RealTime() * 1.6
	surface.SetDrawColor(ColorAlpha(C.accent, 60))
	surface.DrawLine(cx, cy, cx + math.cos(sweep) * R, cy + math.sin(sweep) * R)

	local myYaw = me:EyeAngles().y
	local myPos = me:GetPos()
	local myFac = me:InFaction() and me:GetFaction()
	for _, ply in ipairs(player.GetAll()) do
		if ply ~= me and ply:Alive() then
			local d = ply:GetPos() - myPos
			d.z = 0
			local dist = d:Length()
			if dist <= range then
				-- angle relatif au regard : devant = haut du radar
				local rel = math.rad(math.AngleDifference(d:Angle().y, myYaw))
				local r = dist / range * (R - S(8))
				local px, py = cx - math.sin(rel) * r, cy - math.cos(rel) * r
				local col = (myFac and ply:InFaction(myFac)) and C.good or ((me:InRaid() and ply:InRaid()) and C.bad or C.text)
				blip(px, py, S(6), -math.AngleDifference(ply:EyeAngles().y, myYaw), col)
			end
		end
	end
	blip(cx, cy, S(8), 0, C.accent)
	UI.Text("RADAR", "Astral.UI.Tiny", cx, cy - R + S(6), C.dim, TEXT_ALIGN_CENTER)
	UI.Text(math.floor(range * 0.01905) .. " m", "Astral.UI.Tiny", cx, cy + R - S(18), C.dim, TEXT_ALIGN_CENTER)
end

function UI.DrawOverlays(me)
	drawAnnounce()
	drawToasts()
	drawAFK(me)
	drawRaid(me)
	drawRespawn(me)
	drawRadar(me)
end

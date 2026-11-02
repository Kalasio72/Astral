-- Astral UI — ambiance des événements (astral/events) : bannière animée et flash coloré au lancement, son,
-- particules d'ambiance autour du joueur tant que l'événement dure. Les feux d'artifice viennent du serveur
-- (Astral.Farms.Firework). Convar astral_hud 0 : pas de bannière ni de particules.

local UI = Astral.UI
local C, S = UI.Colors, UI.Scale
local E = Astral.Events

surface.CreateFont("Astral.Event.Kicker", { font = "Roboto", size = S(18), weight = 800, extended = true })
surface.CreateFont("Astral.Event.Title", { font = "Roboto", size = S(54), weight = 900, extended = true })
surface.CreateFont("Astral.Event.Desc", { font = "Roboto", size = S(22), weight = 600, extended = true })

local banner   -- { ev, start, starting }

net.Receive("Astral.EventFX", function()
	local id, starting = net.ReadString(), net.ReadBool()
	local ev = E.List[id]
	if not ev then return end
	banner = { ev = ev, start = RealTime(), starting = starting }
	if starting then
		surface.PlaySound("ambient/alarms/warningbell1.wav")
		timer.Simple(0.6, function() surface.PlaySound("ambient/levels/citadel/weapon_disintegrate" .. math.random(1, 4) .. ".wav") end)
	else
		surface.PlaySound("buttons/button19.wav")
	end
end)

hook.Add("HUDPaint", "Astral.Events.Banner", function()
	if not banner or not GetConVar("astral_hud"):GetBool() then return end
	local t = RealTime() - banner.start
	local life = banner.starting and 6 or 3.5
	if t > life then banner = nil return end
	local ev, col = banner.ev, banner.ev.fx and banner.ev.fx.color or C.accent
	-- Flash plein écran au début
	if banner.starting and t < 0.8 then
		surface.SetDrawColor(col.r, col.g, col.b, 70 * (1 - t / 0.8))
		surface.DrawRect(0, 0, ScrW(), ScrH())
	end
	local a = math.min(1, t * 3, (life - t) * 2)
	local slide = (1 - math.min(1, t * 2.5)) ^ 3
	local w, h = math.min(ScrW() - S(80), S(820)), S(150)
	local x, y = ScrW() / 2 - w / 2, ScrH() * 0.15 - slide * S(60)
	surface.SetAlphaMultiplier(a)
	draw.RoundedBox(S(12), x, y, w, h, Color(10, 13, 26, 235))
	draw.RoundedBox(S(12), x, y, w, S(5), col)
	-- Reflet qui balaie la bannière
	local sweep = (t * 0.6 % 1) * (w + S(200)) - S(200)
	draw.RoundedBox(0, x + math.max(0, sweep), y + S(5), math.min(S(120), math.max(0, w - sweep)), h - S(5), Color(255, 255, 255, 8))
	draw.SimpleText(banner.starting and "ÉVÉNEMENT EN COURS" or "ÉVÉNEMENT TERMINÉ", "Astral.Event.Kicker", ScrW() / 2, y + S(18), col, TEXT_ALIGN_CENTER)
	draw.SimpleText(ev.name, "Astral.Event.Title", ScrW() / 2, y + S(40), C.text, TEXT_ALIGN_CENTER)
	draw.SimpleText(banner.starting and ev.desc or "Merci d'avoir participé !", "Astral.Event.Desc", ScrW() / 2, y + S(104), C.dim, TEXT_ALIGN_CENTER)
	surface.SetAlphaMultiplier(1)
end)

---------------------------------------------------------------------------
-- Particules d'ambiance
---------------------------------------------------------------------------
local glow = Material("sprites/light_glow02_add")
local smoke = Material("particle/particle_smokegrenade")
local AMB = {
	money = function(p, col)
		p:SetColor(math.random() < 0.5 and 110 or 255, math.random() < 0.5 and 225 or 205, 90)
		p:SetVelocity(Vector(math.Rand(-20, 20), math.Rand(-20, 20), -math.Rand(60, 110)))
		p:SetStartSize(math.Rand(3, 6)) p:SetEndSize(3) p:SetRoll(math.Rand(0, 360)) p:SetRollDelta(math.Rand(-3, 3))
	end,
	leaves = function(p, col)
		p:SetColor(math.random(80, 140), math.random(180, 230), 70)
		p:SetVelocity(Vector(math.Rand(-40, 40), math.Rand(-40, 40), -math.Rand(40, 70)))
		p:SetStartSize(math.Rand(3, 5)) p:SetEndSize(2) p:SetRollDelta(math.Rand(-4, 4))
	end,
	crystals = function(p, col)
		p:SetColor(col.r, col.g, col.b)
		p:SetVelocity(Vector(0, 0, -math.Rand(150, 260)))
		p:SetStartSize(math.Rand(4, 7)) p:SetEndSize(1)
	end,
	sparks = function(p, col)
		p:SetColor(255, math.random(120, 200), 60)
		p:SetVelocity(Vector(math.Rand(-30, 30), math.Rand(-30, 30), math.Rand(20, 60)))
		p:SetStartSize(math.Rand(2, 4)) p:SetEndSize(0) p:SetGravity(Vector(0, 0, -60))
	end,
	smoke = function(p, col)
		p:SetColor(60, 50, 50)
		p:SetVelocity(Vector(math.Rand(-15, 15), math.Rand(-15, 15), math.Rand(5, 20)))
		p:SetStartSize(math.Rand(30, 50)) p:SetEndSize(80) p:SetStartAlpha(25)
	end,
}

local emitter
timer.Create("Astral.Events.Ambient", 0.12, 0, function()
	local id, ev = E.Current()
	local amb = ev and ev.fx and AMB[ev.fx.ambient]
	local me = LocalPlayer()
	if not amb or not IsValid(me) or not GetConVar("astral_hud"):GetBool() then return end
	emitter = emitter or ParticleEmitter(me:GetPos())
	if not emitter then return end
	local col = ev.fx.color or C.accent
	for _ = 1, 3 do
		local isSmoke = ev.fx.ambient == "smoke"
		local pos = me:GetPos() + Vector(math.Rand(-600, 600), math.Rand(-600, 600), isSmoke and math.Rand(0, 40) or math.Rand(250, 450))
		local p = emitter:Add(isSmoke and smoke or glow, pos)
		if p then
			p:SetDieTime(isSmoke and 6 or 4)
			p:SetStartAlpha(220) p:SetEndAlpha(0)
			p:SetCollide(true) p:SetBounce(0.1)
			amb(p, col)
		end
	end
end)

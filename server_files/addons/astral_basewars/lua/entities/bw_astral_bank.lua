-- Banque Astral : centralise l'argent de toutes les imprimantes de son propriétaire dans un rayon de 1 200 unités
-- (≈ 23 m) et permet de les améliorer toutes d'un coup (menu : E sur sa banque, astral/ui/cl_upgrade.lua).
-- Hérite du coffre-fort SpaceVX (bw_vault) : aspiration toutes les 10 s, récolte avec E, mêmes règles de raid
-- (hook BaseWars_PlayerCanEmptyPrinter). Différences : rayon doublé, aucun intérêt (pas de nouvelle source
-- d'argent), 2 000 PV.
AddCSLuaFile()

ENT.Base = "bw_vault"
ENT.Type = "anim"
ENT.PrintName = "Banque Astral"
ENT.Author = "Astral"
ENT.Model = "models/hunter/blocks/cube075x1x075.mdl"
ENT.Radius = 1200
ENT.InterestRate = 0
ENT.PowerRequired = 15
ENT.PresetMaxHealth = 2000
ENT.IsAstralMachine = true

if SERVER then return end

local UI = Astral and Astral.UI
local metal = Material("models/debug/debugwhite")
local W, H = 432, 272

function ENT:Calc3D2DParams()
	local pos, ang = self:GetPos(), self:GetAngles()
	pos = pos + ang:Forward() * 18.15 + ang:Right() * 21.6 + ang:Up() * 15
	ang:RotateAroundAxis(ang:Up(), 90)
	ang:RotateAroundAxis(ang:Forward(), 90)
	return pos, ang, 0.1
end

-- Imprimantes connectées (visibles par le client) : mêmes critères que le serveur
function ENT:AstralConnected()
	if (self.nextScan or 0) > RealTime() then return self.connected or {} end
	self.nextScan = RealTime() + 1
	local owner = self.CPPIGetOwner and self:CPPIGetOwner()
	local list = {}
	if Astral and Astral.Printers then
		for _, e in ipairs(ents.FindInSphere(self:GetPos(), self.Radius)) do
			if Astral.Printers.IsPrinter(e) and e.CPPIGetOwner and e:CPPIGetOwner() == owner then list[#list + 1] = e end
		end
	end
	self.connected = list
	return list
end

function ENT:DrawDisplay()
	if not UI then return end
	local C = UI.Colors
	local list = self:AstralConnected()
	local rate, stock = 0, 0
	for _, e in ipairs(list) do
		if IsValid(e) then
			rate = rate + (e:IsPowered() and Astral.Printers.PerMinute(e) or 0)
			stock = stock + (tonumber(e:GetMoney()) or 0)
		end
	end
	draw.RoundedBox(14, 0, 0, W, H, Color(10, 13, 26, 245))
	draw.RoundedBoxEx(14, 0, 0, W, 8, C.accent, true, true, false, false)
	draw.SimpleText("BANQUE ASTRAL", "Astral.Printer.Title", 20, 18, C.text)
	local powered = self:IsPowered()
	draw.SimpleText(powered and "EN LIGNE" or "HORS TENSION", "Astral.Printer.Small", W - 20, 26, powered and C.good or C.bad, TEXT_ALIGN_RIGHT)
	draw.SimpleText(UI.Money(self:GetMoney()), "Astral.Printer.Huge", W / 2, 104, C.good, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleText(#list .. " imprimante(s) connectée(s)", "Astral.Printer.Body", W / 2, 152, C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleText("Production : " .. UI.Money(rate) .. " / min  ·  en attente : " .. UI.Money(stock), "Astral.Printer.Small", W / 2, 184, C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.RoundedBox(0, 20, 213, W - 40, 2, Color(36, 46, 82))
	draw.SimpleText("E : ouvrir la banque", "Astral.Printer.Small", W / 2, 240, C.accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

function ENT:Draw()
	render.MaterialOverride(metal)
	render.SetColorModulation(0.17, 0.2, 0.3)
	self:DrawModel()
	render.SetColorModulation(1, 1, 1)
	render.MaterialOverride(nil)
	if EyePos():DistToSqr(self:GetPos()) > 600 ^ 2 then return end
	-- Flancs lumineux communs aux machines Astral (astral/ui/cl_printerlook.lua) ; la face avant (+x) porte l'écran
	if UI and UI.DrawCasing then
		UI.DrawCasing(self, UI.Colors.accent, { title = "BANQUE ASTRAL", sub = "Coffre central des imprimantes", skip = { [1] = true }, lit = self:IsPowered() })
	end
	local pos, ang, scale = self:Calc3D2DParams()
	cam.Start3D2D(pos, ang, scale)
		pcall(self.DrawDisplay, self)
	cam.End3D2D()
end

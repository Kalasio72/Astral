-- Astral Industries — menu de choix de recette du fabricateur (client).
-- Le serveur vérifie propriétaire, distance et recette (sv_industry.lua) ; ce menu ne fait qu'afficher et envoyer le choix.

local UI = Astral.UI
local C = UI.Colors
local S = UI.Scale

local function money(n) return UI.Money(n) end

local function open(fab)
	if not IsValid(fab) then return end
	local current = fab:GetNW2String("AstralRecipe", "")
	local f = UI.Frame("Fabricateur — choisir une recette", S(620), S(520))
	local scroll = vgui.Create("DScrollPanel", f)
	scroll:Dock(FILL) scroll:DockMargin(S(6), S(30), S(6), S(6))
	for _, id in ipairs(Astral.Recipes.order) do
		local r = Astral.Recipes.Get(id)
		local out = Astral.Resources.Get(r.output)
		local inputValue = 0
		local parts = {}
		for res, q in SortedPairs(r.inputs) do
			local d = Astral.Resources.Get(res)
			parts[#parts + 1] = q .. " × " .. d.name
			inputValue = inputValue + d.value * q
		end
		local card = scroll:Add("DButton")
		card:Dock(TOP) card:DockMargin(0, 0, 0, S(8)) card:SetTall(S(84)) card:SetText("")
		function card:Paint(w, h)
			local active = id == current
			draw.RoundedBox(S(8), 0, 0, w, h, active and C.line or (self:IsHovered() and C.panel or ColorAlpha(C.panel, 150)))
			draw.RoundedBox(S(4), S(14), S(16), S(14), S(14), out.color)
			draw.SimpleText(r.name, "Astral.UI.Big", S(38), S(10), C.text)
			draw.SimpleText(table.concat(parts, "  +  "), "Astral.UI.Small", S(38), S(40), C.dim)
			draw.SimpleText(string.format("%d s  ·  vaut %s (ingrédients %s)", r.seconds, money(out.value * r.qty), money(inputValue)), "Astral.UI.Small", S(38), S(60), C.accent)
			if active then draw.SimpleText("ACTIVE", "Astral.UI.Tiny", w - S(16), S(12), C.good, TEXT_ALIGN_RIGHT) end
		end
		card.DoClick = function()
			net.Start("Astral.Fabricator.SetRecipe") net.WriteEntity(fab) net.WriteString(id) net.SendToServer()
			f:Close()
		end
	end
end

net.Receive("Astral.Fabricator.Open", function() open(net.ReadEntity()) end)

-- Serre : choix de la culture
local function openGreenhouse(gh)
	if not IsValid(gh) then return end
	local current = gh:GetNW2String("AstralCrop", "")
	local f = UI.Frame("Serre — choisir une culture", S(560), S(440))
	local scroll = vgui.Create("DScrollPanel", f)
	scroll:Dock(FILL) scroll:DockMargin(S(6), S(30), S(6), S(6))
	for _, id in ipairs(Astral.Resources.order) do
		local c = Astral.Resources.Get(id)
		if c.kind == "crop" then
			local card = scroll:Add("DButton")
			card:Dock(TOP) card:DockMargin(0, 0, 0, S(8)) card:SetTall(S(70)) card:SetText("")
			function card:Paint(w, h)
				draw.RoundedBox(S(8), 0, 0, w, h, id == current and C.line or (self:IsHovered() and C.panel or ColorAlpha(C.panel, 150)))
				draw.RoundedBox(S(4), S(14), S(14), S(14), S(14), c.color)
				draw.SimpleText(c.name, "Astral.UI.Big", S(38), S(8), C.text)
				local perMin = c.yield * c.value / c.grow * 60
				draw.SimpleText(string.format("%d unité(s) toutes les %d s  ·  %s l'unité  ·  ≈ %s/min", c.yield, c.grow, money(c.value), money(perMin)), "Astral.UI.Small", S(38), S(40), C.dim)
				if id == current then draw.SimpleText("EN CULTURE", "Astral.UI.Tiny", w - S(16), S(12), C.good, TEXT_ALIGN_RIGHT) end
			end
			card.DoClick = function()
				net.Start("Astral.Greenhouse.SetCrop") net.WriteEntity(gh) net.WriteString(id) net.SendToServer()
				f:Close()
			end
		end
	end
end
net.Receive("Astral.Greenhouse.Open", function() openGreenhouse(net.ReadEntity()) end)

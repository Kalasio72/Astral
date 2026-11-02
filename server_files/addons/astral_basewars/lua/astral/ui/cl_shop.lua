-- Astral UI — boutique moderne.
-- Lit BaseWars.SpawnList (le catalogue SpaceVX, Astral Industries compris) et achète via la commande serveur
-- existante « basewars_spawn » : prix, niveau, VIP et limites restent vérifiés par le serveur SpaceVX.
-- Accès : premier onglet du menu de création (touche du spawnmenu), touche F4, ou « !boutique » dans le chat.
-- L'onglet SpaceVX d'origine reste disponible dans le même menu.

local UI = Astral.UI
local C = UI.Colors
local S = UI.Scale

---------------------------------------------------------------------------
-- Traduction d'affichage (les clés internes, utilisées par basewars_spawn, ne changent pas)
---------------------------------------------------------------------------
local CATEGORY_WORDS = {
	{ "Printers", "Imprimantes" }, { "Generators", "Générateurs" }, { "Consumables", "Consommables" },
	{ "Defense", "Défense" }, { "Dispensers", "Distributeurs" }, { "Structures", "Structures" },
	{ "Ammo Kits", "Munitions" }, { "Drugs", "Drogues" }, { "Medical", "Médical" }, { "Raid Tools", "Outils de raid" },
	{ "Vehicles", "Véhicules" }, { "Weapons (Grenades)", "Grenades" }, { "Weapons", "Armes" },
}
local function categoryLabel(name)
	for _, w in ipairs(CATEGORY_WORDS) do
		if name:find(w[1], 1, true) then return (name:gsub(w[1]:gsub("%p", "%%%0"), w[2], 1)) end
	end
	return name
end

local ITEM_WORDS = {
	{ "Printer", "Imprimante" }, { "Generator", "Générateur" }, { "Wooden", "en bois" }, { "Gas", "à gaz" },
	{ "Solar Panel", "Panneau solaire" }, { "Paper", "Papier" }, { "Turret", "Tourelle" }, { "Dispenser", "Distributeur" },
	-- Matériaux des imprimantes (affichage seulement)
	{ "Copper", "en cuivre" }, { "Silver", "en argent" }, { "Gold", "en or" }, { "Platinum", "en platine" },
	{ "Diamond", "en diamant" }, { "Emerald", "d'émeraude" }, { "Obsidian", "d'obsidienne" }, { "Plastic", "en plastique" },
	{ "Scrap", "de récupération" }, { "Nuclear", "nucléaire" }, { "Quantum", "quantique" }, { "Unknown", "inconnue" },
}
-- Noms complets traduits tels quels (prioritaires sur les motifs ci-dessus)
local EXACT = {
	["Gas Generator"] = "Générateur à gaz", ["Coal Fired Generator"] = "Générateur à charbon", ["Fission Reactor"] = "Réacteur à fission",
	["Hydro-Electric Generator"] = "Centrale hydroélectrique", ["Hydro-Electric Reactor"] = "Centrale hydroélectrique",
	["Fusion Reactor"] = "Réacteur à fusion", ["Dark Fusion Reactor"] = "Réacteur à matière noire",
	["Money Vault"] = "Coffre-fort", ["Vending Machine"] = "Distributeur automatique",
	["Ammo Dispenser"] = "Distributeur de munitions", ["Ammo Dispenser v2"] = "Distributeur de munitions v2",
	["Armour Dispenser"] = "Distributeur d'armure", ["Armour Dispenser v2"] = "Distributeur d'armure v2",
	["Printer-Paper Refiller"] = "Recharge de papier", ["HealthPad"] = "Plateforme de soin", ["Spawnpoint"] = "Point de réapparition",
	["SpawnPoint"] = "Point de réapparition", ["Drug Lab"] = "Labo de drogues", ["Radar"] = "Radar", ["Radar Transmitter"] = "Radar",
	["Explosive Mine"] = "Mine explosive", ["Fast Mine"] = "Mine rapide", ["Powerful Mine"] = "Mine puissante", ["Shock Mine"] = "Mine à choc",
	["Ballistic Turret"] = "Tourelle balistique", ["Laser Turret"] = "Tourelle laser", ["Rapid Laser Turret"] = "Tourelle laser rapide",
	["Controllable Turret"] = "Tourelle pilotable", ["Tesla Coil"] = "Bobine Tesla", ["Repair Kit"] = "Kit de réparation",
	["Armour Kit"] = "Kit de blindage", ["Capacity Kit"] = "Kit de capacité", ["Battery Kit"] = "Kit de batterie",
	["Heavy Armour Kit"] = "Kit de blindage lourd", ["Heavy Capacity Kit"] = "Kit de capacité lourd", ["Medkit"] = "Trousse de soin",
	["Blowtorch"] = "Chalumeau", ["Heal Gun"] = "Pistolet soignant", ["BigBomb"] = "Grosse bombe", ["Nuke"] = "Bombe nucléaire",
	["Smoke"] = "Fumigène", ["Flash"] = "Flashbang", ["Frag"] = "Grenade", ["Crate"] = "Caisse de munitions", ["Kit"] = "Kit de munitions",
	["40mm Grenades"] = "Grenades 40 mm", ["Jeep"] = "Jeep", ["DoubleJump"] = "Double saut", ["Regen"] = "Régénération",
	["PainKiller"] = "Antidouleur", ["Steroid"] = "Stéroïdes", ["Adrenaline"] = "Adrénaline", ["Rage"] = "Rage", ["Shield"] = "Bouclier",
	["Antidote"] = "Antidote", ["Healing Tower"] = "Tour de soin",
}

local function itemLabel(name)
	if EXACT[name] then return EXACT[name] end
	-- « Wooden Printer » → « Imprimante en bois » : on ne traduit que les motifs simples et sûrs
	local base = name
	local noun, adj
	for _, w in ipairs(ITEM_WORDS) do
		if base:find(w[1], 1, true) and (w[1] == "Printer" or w[1] == "Generator" or w[1] == "Turret" or w[1] == "Dispenser") then noun = w end
	end
	if not noun then return name end
	local rest = base:gsub(noun[1], ""):gsub("%s+", " "):Trim()
	for _, w in ipairs(ITEM_WORDS) do if rest == w[1] then adj = w[2] end end
	return noun[2] .. " " .. (adj or rest)
end
UI.ItemLabel = itemLabel   -- réutilisé par les écrans d'imprimantes (cl_printers.lua)

---------------------------------------------------------------------------
-- Logique d'achat (mêmes règles d'affichage que SpaceVX)
---------------------------------------------------------------------------
local function requiredLevel(item)
	local level = item.Level
	if item.Gun and (not level or level < BaseWars.Config.LevelSettings.BuyWeapons) then level = BaseWars.Config.LevelSettings.BuyWeapons end
	return level
end

local function canSee(ply, item)
	local level = requiredLevel(item)
	local hasLevel = not level or ply:HasLevel(level)
	local hasVIP = not item.VIP or BaseWars.Config.VIPRanks[ply:GetUserGroup()] or ply:IsAdmin()
	return hasLevel, hasVIP, level
end

local function confirm(text, onYes)
	local f = vgui.Create("DFrame")
	f:SetSize(S(420), S(150)) f:Center() f:SetTitle("") f:MakePopup() f:ShowCloseButton(false)
	function f:Paint(w, h) draw.RoundedBox(S(8), 0, 0, w, h, C.bgSolid) draw.RoundedBox(S(8), 0, 0, w, S(4), C.accent) end
	local l = vgui.Create("DLabel", f)
	l:SetFont("Astral.UI.Text") l:SetTextColor(C.text) l:SetWrap(true) l:SetText(text)
	l:SetPos(S(20), S(24)) l:SetSize(S(380), S(60))
	local function btn(label, x, col, fn)
		local b = vgui.Create("DButton", f)
		b:SetText(label) b:SetFont("Astral.UI.Text") b:SetTextColor(C.text)
		b:SetPos(x, S(100)) b:SetSize(S(180), S(34))
		function b:Paint(w, h) draw.RoundedBox(S(6), 0, 0, w, h, self:IsHovered() and col or C.line) end
		b.DoClick = function() f:Remove() if fn then fn() end end
	end
	btn("Acheter", S(20), C.good, onYes)
	btn("Annuler", S(220), C.bad)
end

local function buy(kind, cat, name, item)
	local ply = LocalPlayer()
	local hasLevel, hasVIP = canSee(ply, item)
	if not hasLevel or not hasVIP then surface.PlaySound("buttons/button10.wav") return end
	local money, price = ply:GetMoney(), item.Price or 0
	if price > money then
		surface.PlaySound("buttons/button10.wav")
		if UI.Toast then UI.Toast("Pas assez d'argent pour " .. itemLabel(name) .. ".", BASEWARS_NOTIFICATION_ERROR) end
		return
	end
	local function doIt() RunConsoleCommand("basewars_spawn", kind, cat, name) surface.PlaySound("ui/buttonclickrelease.wav") end
	if price > 0 and money / 100 <= price then
		confirm(string.format("Acheter « %s » pour %s ?", itemLabel(name), UI.Money(price)), doIt)
	else
		doIt()
	end
end

---------------------------------------------------------------------------
-- Panneau boutique (réutilisé dans le spawnmenu et dans la fenêtre F4)
---------------------------------------------------------------------------
-- Couleur d'aperçu des machines habillées (sh_looks.lua, fermes, imprimantes) ; nil = icône classique
local shopMetal = Material("models/debug/debugwhite")
local function shopTint(class)
	if not isstring(class) then return nil end
	local look = Astral.Looks and Astral.Looks.Classes[class]
	if look then return look.color end
	if class == "bw_astral_bank" then return C.accent end
	if class:sub(1, 11) == "bw_printer_" and UI.PrinterColor then
		local stored = scripted_ents.GetStored(class)
		if stored and stored.t then return UI.PrinterColor(stored.t) end
	end
end

local function card(parent, kind, cat, name, item)
	local w, h = S(150), S(190)
	local p = vgui.Create("DButton", parent)
	p:SetSize(w, h) p:SetText("")
	local icon
	local tint = shopTint(item.ClassName)
	if tint then
		-- Machines habillées Astral (blocs PHX) : aperçu 3D teinté et tournant au lieu d'une icône grise
		icon = vgui.Create("DModelPanel", p)
		icon:SetModel(item.Model or "models/error.mdl")
		local ent = icon:GetEntity()
		if IsValid(ent) then
			local mn, mx = ent:GetRenderBounds()
			local size = math.max(mx.x - mn.x, mx.y - mn.y, mx.z - mn.z)
			icon:SetFOV(40) icon:SetCamPos(Vector(size * 1.6, size * 1.1, size * 1.0)) icon:SetLookAt((mn + mx) / 2)
		end
		function icon:LayoutEntity(e) e:SetAngles(Angle(0, RealTime() * 25 % 360, 0)) end
		function icon:PreDrawModel()
			render.MaterialOverride(shopMetal)
			render.SetColorModulation(0.08 + tint.r / 255 * 0.42, 0.08 + tint.g / 255 * 0.42, 0.12 + tint.b / 255 * 0.42)
		end
		function icon:PostDrawModel() render.SetColorModulation(1, 1, 1) render.MaterialOverride(nil) end
	else
		icon = vgui.Create("SpawnIcon", p)
		icon:SetModel(item.Model or "models/error.mdl")
		icon:SetTooltip(false)
	end
	icon:SetSize(S(96), S(96)) icon:SetPos((w - S(96)) / 2, S(10))
	icon:SetMouseInputEnabled(false)
	local label = itemLabel(name)
	function p:Paint(pw, ph)
		local ply = LocalPlayer()
		local hasLevel, hasVIP, level = canSee(ply, item)
		local price = item.Price or 0
		local afford = price <= ply:GetMoney()
		local locked = not hasLevel or not hasVIP
		draw.RoundedBox(S(8), 0, 0, pw, ph, self:IsHovered() and not locked and C.line or C.panel)
		draw.SimpleText(label, "Astral.UI.Small", pw / 2, S(114), locked and C.dim or C.text, TEXT_ALIGN_CENTER)
		local priceText = price > 0 and UI.Money(price) or "Gratuit"
		draw.SimpleText(priceText, "Astral.UI.Text", pw / 2, S(136), locked and C.dim or (afford and C.good or C.bad), TEXT_ALIGN_CENTER)
		if not hasVIP then
			draw.RoundedBox(S(4), S(8), S(8), S(40), S(18), C.warn)
			draw.SimpleText("VIP", "Astral.UI.Tiny", S(28), S(17), C.bgSolid, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		elseif not hasLevel then
			draw.RoundedBox(S(4), S(8), S(8), S(56), S(18), C.accent2)
			draw.SimpleText("Niv. " .. level, "Astral.UI.Tiny", S(36), S(17), C.bgSolid, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		if item.Limit and item.Limit < 100 then
			draw.SimpleText("Limite " .. item.Limit, "Astral.UI.Tiny", pw / 2, S(162), C.dim, TEXT_ALIGN_CENTER)
		end
	end
	p.DoClick = function() buy(kind, cat, name, item) end
	return p
end

function UI.BuildShop(parent)
	local root = vgui.Create("DPanel", parent)
	root:Dock(FILL)
	function root:Paint(w, h) draw.RoundedBox(S(8), 0, 0, w, h, C.bgSolid) end

	local side = vgui.Create("DScrollPanel", root)
	side:Dock(LEFT) side:SetWide(S(210)) side:DockMargin(S(8), S(8), 0, S(8))

	local main = vgui.Create("DPanel", root)
	main:Dock(FILL) main:DockMargin(S(8), S(8), S(8), S(8))
	function main:Paint() end

	local top = vgui.Create("DPanel", main)
	top:Dock(TOP) top:SetTall(S(36)) function top:Paint() end
	local title = vgui.Create("DLabel", top)
	title:Dock(LEFT) title:SetWide(S(380)) title:SetFont("Astral.UI.Big") title:SetTextColor(C.text)
	local search = vgui.Create("DTextEntry", top)
	search:Dock(RIGHT) search:SetWide(S(240)) search:SetFont("Astral.UI.Text")
	search:SetPlaceholderText("Rechercher…")

	local scroll = vgui.Create("DScrollPanel", main)
	scroll:Dock(FILL) scroll:DockMargin(0, S(8), 0, 0)
	local grid = vgui.Create("DIconLayout", scroll)
	grid:Dock(FILL) grid:SetSpaceX(S(8)) grid:SetSpaceY(S(8))

	local current = { kind = nil, cat = nil }
	local function fill()
		grid:Clear()
		local q = search:GetValue():lower()
		local count = 0
		for kind, cats in SortedPairs(BaseWars.SpawnList) do
			for cat, items in SortedPairs(cats) do
				if cat ~= "__inf" and (q ~= "" or (kind == current.kind and cat == current.cat)) then
					for name, item in SortedPairsByMemberValue(items, "Price") do
						if q == "" or name:lower():find(q, 1, true) or itemLabel(name):lower():find(q, 1, true) then
							grid:Add(card(grid, kind, cat, name, item))
							count = count + 1
						end
					end
				end
			end
		end
		title:SetText(q ~= "" and (count .. " résultat(s)") or categoryLabel(current.cat or ""))
		grid:Layout()
	end
	search.OnChange = fill

	local first
	for kind, cats in SortedPairs(BaseWars.SpawnList) do
		local header = vgui.Create("DLabel", side)
		header:Dock(TOP) header:DockMargin(S(6), S(10), 0, S(4))
		header:SetFont("Astral.UI.Tiny") header:SetTextColor(C.accent)
		header:SetText(string.upper(cats.__inf and cats.__inf.name or kind))
		for cat in SortedPairs(cats) do
			if cat ~= "__inf" then
				local b = vgui.Create("DButton", side)
				b:Dock(TOP) b:DockMargin(0, 0, S(4), S(3)) b:SetTall(S(30))
				b:SetText("") b.kind, b.cat = kind, cat
				local label = categoryLabel(cat)
				function b:Paint(w, h)
					local active = current.kind == self.kind and current.cat == self.cat and search:GetValue() == ""
					draw.RoundedBox(S(6), 0, 0, w, h, active and C.line or (self:IsHovered() and C.panel or Color(0, 0, 0, 0)))
					if active then draw.RoundedBox(S(2), 0, S(6), S(3), h - S(12), C.accent) end
					draw.SimpleText(label, "Astral.UI.Small", S(12), h / 2, active and C.text or C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				end
				b.DoClick = function() current.kind, current.cat = kind, cat search:SetValue("") fill() end
				-- On ouvre de préférence sur Astral Industries
				if not first or cat == "Astral Industries" then first = { kind, cat } end
			end
		end
	end
	if first then current.kind, current.cat = first[1], first[2] end
	fill()
	return root
end

---------------------------------------------------------------------------
-- Accès : onglet du spawnmenu, fenêtre F4, commande de chat
---------------------------------------------------------------------------
spawnmenu.AddCreationTab("Boutique Astral", function()
	local holder = vgui.Create("DPanel")
	function holder:Paint() end
	UI.BuildShop(holder)
	return holder
end, "icon16/cart.png", -200)

local frame
function UI.OpenShop()
	if IsValid(frame) then frame:Remove() return end
	frame = vgui.Create("DFrame")
	frame:SetSize(math.min(ScrW() - S(80), S(1100)), math.min(ScrH() - S(80), S(700)))
	frame:Center() frame:SetTitle("") frame:MakePopup()
	function frame:Paint(w, h)
		draw.RoundedBox(S(10), 0, 0, w, h, C.bg)
		draw.SimpleText("ASTRAL", "Astral.UI.Big", S(16), S(8), C.accent)
		draw.SimpleText("Boutique", "Astral.UI.Big", S(110), S(8), C.text)
	end
	local inner = vgui.Create("DPanel", frame)
	inner:Dock(FILL) inner:DockMargin(0, S(10), 0, 0)
	function inner:Paint() end
	UI.BuildShop(inner)
end

hook.Add("PlayerBindPress", "Astral.Shop.F4", function(ply, bind, pressed)
	if pressed and bind == "gm_showspare2" then UI.OpenShop() return true end
end)

hook.Add("OnPlayerChat", "Astral.Shop.Chat", function(ply, text)
	if ply == LocalPlayer() and (text:lower() == "!boutique" or text:lower() == "/boutique") then UI.OpenShop() end
end)
concommand.Add("astral_shop", function() UI.OpenShop() end)

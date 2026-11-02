-- Astral Industries — registre des ressources et petits inventaires de machines (partagé).
-- Les ressources n'existent que DANS les machines et conteneurs (physiques, destructibles en raid) :
-- pas d'inventaire joueur à ce stade.
--
-- Astral.Resources.Register(id, { name, value, color, kind = "ore"|"product", weight, refinesTo })
--   value     : prix de rachat par le serveur (unité)
--   weight    : probabilité relative d'extraction par une foreuse (minerais uniquement)
--   refinesTo : ressource produite par la raffinerie (RefineryOrePerIngot minerais → 1 produit)

Astral.Resources = Astral.Resources or { list = {}, order = {} }
local R = Astral.Resources

function R.Register(id, def)
	assert(isstring(id) and id:match("^[a-z_]+$"), "identifiant de ressource invalide : " .. tostring(id))
	def.id = id
	def.weight = def.weight or 0
	if not R.list[id] then R.order[#R.order + 1] = id end
	R.list[id] = def
end

function R.Get(id) return R.list[id] end

-- Équilibrage : voir BALANCE.md. Minerai moyen ≈ 34,5 £ ; un produit raffiné vaut 1,5× ses 2 minerais.
R.Register("iron_ore",      { name = "Minerai de fer",      kind = "ore",     value = 15,   weight = 35,  color = Color(170, 120, 100), refinesTo = "iron_ingot" })
R.Register("copper_ore",    { name = "Minerai de cuivre",   kind = "ore",     value = 25,   weight = 25,  color = Color(210, 130, 70),  refinesTo = "copper_ingot" })
R.Register("coal",          { name = "Charbon",             kind = "ore",     value = 10,   weight = 25,  color = Color(80, 80, 80) })
R.Register("silicon",       { name = "Silicium",            kind = "ore",     value = 40,   weight = 12.5, color = Color(170, 190, 210), refinesTo = "silicon_wafer" })
R.Register("rare_ore",      { name = "Minerai rare",        kind = "ore",     value = 400,  weight = 2,   color = Color(200, 120, 255), refinesTo = "rare_alloy" })
R.Register("energy_crystal",{ name = "Cristal énergétique", kind = "ore",     value = 1500, weight = 0.5, color = Color(120, 230, 255) })
R.Register("iron_ingot",    { name = "Lingot de fer",       kind = "product", value = 45,   color = Color(200, 200, 210) })
R.Register("copper_ingot",  { name = "Lingot de cuivre",    kind = "product", value = 75,   color = Color(230, 150, 90) })
R.Register("silicon_wafer", { name = "Plaquette de silicium", kind = "product", value = 120, color = Color(150, 200, 255) })
R.Register("rare_alloy",    { name = "Alliage rare",        kind = "product", value = 1200, color = Color(220, 150, 255) })

-- Composants fabriqués (fabricateur) : valeur ≈ 1,3 à 1,4× la valeur de leurs ingrédients
R.Register("steel_plate",   { name = "Plaque d'acier",        kind = "component", value = 200,  color = Color(150, 160, 175) })
R.Register("circuit",       { name = "Circuit électronique",  kind = "component", value = 380,  color = Color(110, 225, 150) })
R.Register("alloy_frame",   { name = "Châssis en alliage",    kind = "component", value = 2200, color = Color(200, 140, 255) })
R.Register("power_cell",    { name = "Cellule énergétique",   kind = "component", value = 3200, color = Color(110, 205, 255) })

-- Cultures (serre) : grow = secondes par récolte, yield = unités par récolte
R.Register("wheat",         { name = "Blé",                   kind = "crop", value = 20,  grow = 60,  yield = 4, color = Color(230, 200, 110) })
R.Register("tomato",        { name = "Tomates",               kind = "crop", value = 35,  grow = 90,  yield = 3, color = Color(240, 90, 80) })
R.Register("herbs",         { name = "Herbes médicinales",    kind = "crop", value = 80,  grow = 120, yield = 2, color = Color(120, 210, 110) })
R.Register("astral_flower", { name = "Fleur astrale",         kind = "crop", value = 900, grow = 300, yield = 1, color = Color(180, 140, 255) })
-- Produits agricoles transformés (fabricateur)
R.Register("ration",        { name = "Ration de survie",      kind = "component", value = 110,  color = Color(220, 180, 120) })
R.Register("medicine",      { name = "Médicament",            kind = "component", value = 340,  color = Color(140, 230, 200) })
R.Register("astral_essence",{ name = "Essence astrale",       kind = "component", value = 1800, color = Color(200, 160, 255) })

---------------------------------------------------------------------------
-- Recettes du fabricateur
---------------------------------------------------------------------------
Astral.Recipes = Astral.Recipes or { list = {}, order = {} }
local RC = Astral.Recipes

-- RC.Register(id, { name, inputs = { [ressource] = quantité }, output = ressource, qty = 1, seconds })
function RC.Register(id, def)
	def.id = id
	def.qty = def.qty or 1
	if not RC.list[id] then RC.order[#RC.order + 1] = id end
	RC.list[id] = def
end
function RC.Get(id) return RC.list[id] end

RC.Register("steel_plate", { name = "Plaque d'acier",       inputs = { iron_ingot = 3, coal = 1 },                 output = "steel_plate", seconds = 12 })
RC.Register("circuit",     { name = "Circuit électronique", inputs = { copper_ingot = 2, silicon_wafer = 1 },      output = "circuit",     seconds = 18 })
RC.Register("alloy_frame", { name = "Châssis en alliage",   inputs = { rare_alloy = 1, steel_plate = 2 },          output = "alloy_frame", seconds = 30 })
RC.Register("power_cell",  { name = "Cellule énergétique",  inputs = { energy_crystal = 1, circuit = 2 },          output = "power_cell",  seconds = 40 })
RC.Register("ration",      { name = "Ration de survie",     inputs = { wheat = 2, tomato = 1 },                    output = "ration",      seconds = 10 })
RC.Register("medicine",    { name = "Médicament",           inputs = { herbs = 3 },                                output = "medicine",    seconds = 20 })
RC.Register("astral_essence", { name = "Essence astrale",   inputs = { astral_flower = 1, circuit = 1 },           output = "astral_essence", seconds = 35 })

-- Tirage pondéré d'un minerai
local function weight(id, rareMult)
	local w = R.list[id].weight
	if rareMult and (id == "rare_ore" or id == "energy_crystal") then w = w * rareMult end
	-- Événement « Pluie de cristaux » : minerais rares et cristaux plus fréquents
	if (id == "rare_ore" or id == "energy_crystal") and Astral.Events and Astral.Events.Mult then w = w * Astral.Events.Mult("rare_ore") end
	return w
end

-- rareMult : bonus de recherche du propriétaire de la foreuse (« Forage profond »)
function R.RandomOre(rareMult)
	local total = 0
	for _, id in ipairs(R.order) do total = total + weight(id, rareMult) end
	local roll = math.Rand(0, total)
	for _, id in ipairs(R.order) do
		roll = roll - weight(id, rareMult)
		if R.list[id].weight > 0 and roll <= 0 then return id end
	end
	return "iron_ore"
end

---------------------------------------------------------------------------
-- Inventaires : simples tables { [id] = quantité }, réseau via une chaîne compacte "id=n;id=n"
---------------------------------------------------------------------------
Astral.Inv = Astral.Inv or {}
local I = Astral.Inv

function I.Count(inv)
	local n = 0
	for _, q in pairs(inv) do n = n + q end
	return n
end

function I.Add(inv, id, qty)
	inv[id] = (inv[id] or 0) + qty
	if inv[id] <= 0 then inv[id] = nil end
end

function I.Encode(inv)
	local parts = {}
	for _, id in ipairs(R.order) do
		if inv[id] and inv[id] > 0 then parts[#parts + 1] = id .. "=" .. inv[id] end
	end
	return table.concat(parts, ";")
end

function I.Decode(str)
	local inv = {}
	for id, q in string.gmatch(str or "", "([%w_]+)=(%d+)") do inv[id] = tonumber(q) end
	return inv
end

function I.Value(inv)
	local total = 0
	for id, q in pairs(inv) do
		local def = R.list[id]
		if def then total = total + def.value * q end
	end
	return total
end

---------------------------------------------------------------------------
-- Affichage commun des machines (client)
---------------------------------------------------------------------------
if CLIENT then
	surface.CreateFont("Astral.Machine.Title", { font = "Roboto", size = 34, weight = 800 })
	surface.CreateFont("Astral.Machine.Body", { font = "Roboto", size = 22, weight = 600, extended = true })
	local bg, accent, text, dim = Color(11, 14, 28, 230), Color(120, 210, 255), Color(230, 234, 245), Color(150, 160, 190)

	local line, power, bad = Color(44, 56, 96), Color(255, 210, 90), Color(255, 105, 115)

	-- Panneau 3D2D tourné vers le joueur, au-dessus de l'entité (fondu avec la distance)
	function Astral.DrawMachinePanel(ent, title, status, inv)
		local ply = LocalPlayer()
		local d2 = ply:GetPos():DistToSqr(ent:GetPos())
		if d2 > 500 * 500 then return end
		local alpha = math.Clamp((500 - math.sqrt(d2)) / 120, 0, 1)
		local pos = ent:LocalToWorld(Vector(0, 0, ent:OBBMaxs().z + 22))
		local ang = Angle(0, ply:EyeAngles().y - 90, 90)
		local rows, total = {}, 0
		for _, id in ipairs(R.order) do
			if inv[id] then rows[#rows + 1] = { R.list[id], inv[id] } total = total + inv[id] end
		end
		local hasPower = ent.GetPower and ent.GetMaxPower and ent:GetMaxPower() > 0
		local W = 460
		local h = 104 + (hasPower and 34 or 0) + math.ceil(#rows / 2) * 34
		surface.SetAlphaMultiplier(alpha)
		cam.Start3D2D(pos, ang, 0.075)
			draw.RoundedBox(12, -W / 2, -h, W, h, bg)
			draw.RoundedBoxEx(12, -W / 2, -h, W, 6, accent, true, true, false, false)
			draw.SimpleText(title, "Astral.Machine.Title", -W / 2 + 22, -h + 16, text, TEXT_ALIGN_LEFT)
			draw.SimpleText(total > 0 and (total .. " u.") or "", "Astral.Machine.Body", W / 2 - 22, -h + 22, dim, TEXT_ALIGN_RIGHT)
			local y = -h + 58
			draw.SimpleText(status, "Astral.Machine.Body", -W / 2 + 22, y, status:find("Hors tension") and bad or accent, TEXT_ALIGN_LEFT)
			y = y + 34
			if hasPower then
				local p, mp = ent:GetPower(), ent:GetMaxPower()
				draw.RoundedBox(6, -W / 2 + 22, y + 6, W - 150, 12, line)
				if p > 0 then draw.RoundedBox(6, -W / 2 + 22, y + 6, (W - 150) * math.Clamp(p / mp, 0, 1), 12, power) end
				draw.SimpleText(p .. " / " .. mp, "Astral.Machine.Body", W / 2 - 22, y, dim, TEXT_ALIGN_RIGHT)
				y = y + 34
			end
			for i, r in ipairs(rows) do
				local col = (i - 1) % 2
				local x = -W / 2 + 22 + col * (W / 2 - 10)
				local ry = y + math.floor((i - 1) / 2) * 34
				draw.RoundedBox(4, x, ry + 6, 14, 14, r[1].color)
				draw.SimpleText(r[1].name, "Astral.Machine.Body", x + 22, ry, text, TEXT_ALIGN_LEFT)
				draw.SimpleText(tostring(r[2]), "Astral.Machine.Body", x + W / 2 - 34, ry, dim, TEXT_ALIGN_RIGHT)
			end
		cam.End3D2D()
		surface.SetAlphaMultiplier(1)
	end
end

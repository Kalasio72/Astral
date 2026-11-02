-- Astral BaseWars — vérifie que chaque classe de la boutique existe sur le serveur
-- Lancement depuis la console serveur : lua_openscript astral_tools/check_shop.lua

local missing, total = {}, 0
for _, cat in pairs(BaseWars.SpawnList) do
	for key, sub in pairs(cat) do
		if key == "__inf" then continue end
		for name, item in pairs(sub) do
			local class = item.ClassName
			if not class or class == "prop_physics" or item.Drug then continue end
			total = total + 1
			if not weapons.Get(class) and not scripted_ents.Get(class) then
				missing[#missing + 1] = name .. "=" .. class
			end
		end
	end
end
print("[Astral Shop] " .. total .. " classes vérifiées, " .. #missing .. " manquantes")
for _, m in ipairs(missing) do print("[Astral Shop] MANQUANT " .. m) end

local cw = {}
for _, w in ipairs(weapons.GetList()) do
	if w.ClassName:sub(1, 3) == "cw_" then cw[#cw + 1] = w.ClassName end
end
table.sort(cw)
print("[Astral Shop] CW installées : " .. table.concat(cw, " "))

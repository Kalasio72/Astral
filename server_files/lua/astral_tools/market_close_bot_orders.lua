-- Astral BaseWars — clôture les offres de marché laissées ouvertes par des BOTS de test (SteamID64 9007199…).
-- Aucune suppression : status = 2 (annulée), qty_left = 0. Les offres des vrais joueurs ne sont jamais touchées.
-- Console serveur : lua_openscript astral_tools/market_close_bot_orders.lua
local db = Astral.DB.Conn()
db:Fetch("SELECT id, seller, resource, qty_left, proceeds, status FROM astral_market WHERE seller LIKE '9007199%' AND status = 0", { callback = function(e, rows)
	if e then return print("[Astral Test] ERREUR " .. tostring(e)) end
	print("[Astral Test] offres de bots ouvertes : " .. #(rows or {}))
	for _, r in ipairs(rows or {}) do
		print(string.format("[Astral Test]   #%s %s ×%s, produit non versé %s", r.id, r.resource, r.qty_left, r.proceeds))
		db:Execute("UPDATE astral_market SET status = 2, qty_left = 0, closed_at = {2} WHERE id = {1} AND status = 0 AND seller LIKE '9007199%'", {
			params = { r.id, os.time() },
			callback = function(e2, res)
				Astral.Market.Orders[tonumber(r.id)] = nil
				print(string.format("[Astral Test]   #%s clôturée → %s", r.id, (not e2 and res and res.rows_affected == 1) and "OK" or "ECHEC"))
			end,
		})
	end
end })

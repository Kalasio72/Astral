# Astral BaseWars — Compatibilité

## Addons installés

| Addon | Version / origine | Rôle | Compatibilité constatée | Points d'attention |
|---|---|---|---|---|
| Srlion's Hook Library | 3.0.0, GitHub, MIT | Remplace `lua/includes/modules/hook.lua` | [S] chargée, test `hook.Author == "Srlion"` passé (`include.lua:1-3`) | Tout addon qui remplace aussi `hook.lua` (ULib en a une version ? [?]) cassera BaseWars. Les hooks `PRE_HOOK_RETURN` sont utilisés (`sv_raid.lua:145-147`). |
| goobie-sql | 4.16.6, binaire `linux` 32 bits | Client MySQL asynchrone | [S] connecté | Le binaire doit suivre la branche du serveur : si l'hébergeur passe en x64 (`GMOD_X64`, non modifiable par nous), il faudra `gmsv_goobie_mysql_4_linux64.dll`. |
| Falco's Prop Protection | `master` GitHub | CPPI, protection des props | [S] chargé sans erreur | Non enregistré comme fournisseur `BaseWars.CPPI` → parcours `ents.GetAll()` (voir P1). Double logique de permission : FPP **et** les hooks `GM:PhysgunPickup/CanTool` de BaseWars (`shared.lua:228-276`). Le comportement réel en raid reste à tester. |
| CFC Fading Doors | `master` GitHub, GPL-3.0 | Outil `fading_door` | [S] chargé | BaseWars ne restreint pas cet outil (seulement exclu des logs, `shared.lua:256-263`). Interaction avec le blocage d'outils en raid à tester. |

## Dépendances manquantes ou à décider

| Besoin | Option gratuite | État |
|---|---|---|
| Armes de la boutique (`cw_*`) | CW 2.0 + packs via collection Workshop, **ou** remplacer la liste par des armes gratuites hébergées sur GitHub, **ou** les armes HL2 | À décider |
| Admin mod | **ULX + ULib** (GitHub TeamUlysses, gratuit) — intégration native `integration/ulx/bw_admin_ulx.lua` | Non installé |
| Token Steam (GSLT) | Gratuit sur steamcommunity.com/dev/managegameservers | Non configuré |
| Map BaseWars | Maps `bw_*` / `basewars_*` du Workshop. Les PNJ d'aide ne sont configurés que pour 6 maps (`config.lua:280-349`) | À choisir |

## Conflits connus ou probables

1. **Préfixe des commandes** : sans admin mod, BaseWars accepte `!`, `/` et `.` ; avec ULX/SAM, seulement `/` et `.` (`commands.lua:5-7`) pour laisser `!` à l'admin mod.
2. **Un seul admin mod** : SAM et ULX ensemble provoquent une erreur volontaire (`integration/admin_menus.lua:21`).
3. **Pseudos personnalisés** (`customnick.lua`) : remplacent `Player:Nick()` pour **tous** les addons, y compris les logs et les admin mods. À désactiver avant d'installer des outils de modération.
4. **HUD** : le HUD Astral devra désactiver le module `hud` de SpaceVX (`modules/hud/client/cl_hud.lua`) plutôt que de dessiner par-dessus.

## Règles de compatibilité pour Astral

- Ne jamais modifier les tables SQL `basewars*` ; utiliser des tables `astral_*`.
- Passer par `ply:GiveMoney/TakeMoney/GetMoney` pour l'argent (pas d'accès direct à `ply.BaseWarsMoney`).
- Entités Astral : dériver de `bw_base_electronics` / `bw_base_generator` pour réutiliser santé, énergie, explosion et paiement à la destruction (`CurrentValue`).
- Acheter via le spawnmenu SpaceVX (ajout d'entrées `BaseWars.GSL` dans `SpawnList`) pour hériter des contrôles d'argent, de niveau et de limite.

# Modifications apportées à SpaceVX BaseWars

À réappliquer après chaque mise à jour du gamemode depuis GitHub. Chemins relatifs à `garrysmod/gamemodes/basewars/`.

| # | Date | Fichier | Modification | Raison |
|---|---|---|---|---|
| P1 | 2026-11-02 | `gamemode/server/mysql.lua` l. 4-8 | Hôte, utilisateur, mot de passe et base MySQL renseignés | Exigé par le README SpaceVX |
| P2 | 2026-11-02 | `gamemode/server/mysql.lua` (fonction `Connect`) | `include("server/thirdparty/goobie-sql.lua")` → `include((GM or GAMEMODE).FolderName .. "/gamemode/server/thirdparty/goobie-sql.lua")` | Le chemin relatif échouait au runtime (erreur `File not found`) |
| P3 | 2026-11-02 | `gamemode/integration/admin_menus.lua` (`AdminMenus:Register`) | Ajout de `path = (GM or GAMEMODE).FolderName .. "/gamemode/" .. path` | `AddCSLuaFile: Couldn't find 'integration/sam/...'` |
| P4 | 2026-11-02 | `gamemode/config.lua` l. 19 | `BASEWARS_CHOSEN_LANGUAGE = "FRENCH"` | Serveur français |
| P5 | 2026-11-02 | `gamemode/config.lua` l. 243 | `ExtraStuff = false` | Corrige S1 (pseudos arbitraires). Désactive aussi `hostnamefix.lua` |
| P6 | 2026-11-02 | `gamemode/language.lua`, bloc FRENCH | Grands nombres à l'échelle française (Milliard, Billion, Billiard, Trillion). Ajout des 4 clés manquantes (`OnItemCoolDown`, `BountyInFaction`, `BountyIsFriend`, `BountyOnSelf`) et de `PayDayAFKMissed`, `PayDayAFKReduced` | Évite `INVALID STRING TRANSLATION` et localise la paye |
| P7 | 2026-11-02 | `gamemode/language.lua`, bloc ENGLISH | Ajout de `PayDayAFKMissed`, `PayDayAFKReduced` | Garder l'anglais utilisable |
| P8 | 2026-11-02 | `gamemode/modules/economy/server/sv_payday.lua` l. 23, 26 | Textes anglais codés en dur remplacés par `BaseWars.LANG.PayDayAFKMissed/Reduced` | Localisation |
| P9 | 2026-11-02 | `gamemode/config.lua`, boutique d'armes | 9 armes `cw_g4p_*` (pack introuvable) remplacées, prix inchangés : USP→P99 `cw_p99`, FiveSeven→`cw_fiveseven`, MP412→Makarov `cw_makarov`, UMP→`cw_ump45`, Magpul→FAMAS G2 `cw_famasg2_official`, FN FAL→M14 `cw_m14`, XM8→AKM `cw_akm_official`, AWM→L115 `cw_l115`, M98b→SVD `cw_svd_official` | Armes réellement fournies par la collection Workshop |
| P10 | 2026-11-02 | Bloc 1 sécurité : `sv_factions.lua`, `textscreens.lua`, `commands.lua`, `admin.lua`, `bw_druglab.lua`, `init.lua`, `spawnmenu.lua` | Correctifs S2 à S9 et S11, chacun marqué d'un commentaire `-- Astral Sx` dans le code. Source exacte des remplacements : `patches/bloc1_securite.psd1`, réapplicable avec `tools/patch_remote.ps1` (idempotent) | Voir SECURITY_AUDIT.md |
| P11 | 2026-11-02 | `gamemode/config.lua` (bloc `Raid`), `modules/raid/server/sv_raid.lua` (`MODULE:Start`) | Règle G3 : `Raid.AttackerCoolDown = 300` ; au lancement d'un raid, l'attaquant (ou sa faction) reçoit `__AstralAttackCooldownUntil = fin du raid + 5 min`, vérifié avant tout nouveau raid. Source : `patches/g3_cooldown_attaquant.psd1` | Décision du propriétaire |
| P12 | 2026-11-02 | `entities/bw_turret_healer.lua`, `bw_turret_acid.lua`, `bw_turret_freezer.lua` | Tours de défense réparées (T1) : variable réseau `Radius` déclarée (plantage à l'apparition), coût d'amélioration sans erreur avant achat, plus de `math.random(1, 0)` quand aucune cible, `GetPrestige` inexistant retiré (tour de gel), (la restriction « en raid » ajoutée un temps a été annulée par T1b : ciblage SpaceVX d'origine). Lignes marquées `-- Astral T1`. Sources : `patches/t1_tours.psd1`, `patches/t1b_tours_mecanique_origine.psd1`. Tours retirées de la boutique | Demande du propriétaire |

Règles G1 et G2 : pas de modification du gamemode, elles sont dans `addons/astral_basewars/lua/autorun/server/astral_rules.lua` (hook `BaseWars_PlayerCanEmptyPrinter` ; enveloppe de `bw_base_generator.TransmitPower`). G4 : moteur d'origine conservé (un seul raid à la fois).

Hors gamemode : variable de démarrage `WORKSHOP_ID = 3832089289` (collection Steam « Astral BaseWars » : Chuck's Weaponry 2.0 `349050451` + Extra `358608166`).

Addon Astral (début) : `garrysmod/addons/astral_basewars/lua/autorun/server/astral_workshop.lua` — `resource.AddWorkshop` des 2 packs CW pour que les joueurs les téléchargent (source locale : `server_files/addons/astral_basewars/`).

Fichiers ajoutés (pas des modifications) : `gamemode/server/thirdparty/goobie-sql.lua` ; hors gamemode, `garrysmod/lua/bin/gmsv_goobie_mysql_4_linux.dll` et `garrysmod/lua/astral_tools/backup_db.lua`.

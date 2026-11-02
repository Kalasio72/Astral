# Astral BaseWars — Architecture

Partie 1 : ce qui existe (audité). Partie 2 : ce qui est proposé pour Astral (rien n'est encore codé).
Chemins relatifs à `gamemodes/basewars/` sauf mention contraire. Les numéros de ligne renvoient à `reference/server_snapshot_2026-11-02/`.

---

## Partie 1 — SpaceVX BaseWars tel qu'il est installé

### 1.1 Chaîne de chargement [V]

```
init.lua / cl_init.lua
 └─ include.lua            vérifie hook.Author == "Srlion" (sinon erreur fatale), DeriveGamemode("sandbox")
     ├─ shared.lua          table BaseWars, BaseWars.UTIL, GSL(), hooks GM:Physgun/CanTool/CanProperty…
     ├─ language.lua        BaseWars.LANG (7 langues, dont FRENCH)
     ├─ config.lua          BaseWars.Config + SpawnList (113 entrées GSL) — chargé en pcall
     ├─ default_config.lua  valeurs par défaut fusionnées
     ├─ shared/*            spawnmenu (achats), cppi, admin (bwa), utf8, playuhr, customnick*, hostnamefix*
     ├─ integration/*       admin_menus (SAM/ULX), mlogs, blogs, bitminers, double-or-nothing, gprotect
     └─ server/*            mysql.lua (goobie-sql), commands.lua, hooks.lua
 └─ modules.lua            ModuleLoader : gamemode/modules/<nom>/{shared,server,client}/*.lua
```
\* chargés seulement si `Config.ExtraStuff = true` (c'est le cas, `config.lua:243`).

Modules présents (15 dossiers, 12 chargés côté serveur car `adverts`, `hud`, `notify` sont purement clients) :
`adverts, afk, antirdm (+karma), bounty, drugs, economy, ents, events, factions, hud, notify, npcs, player_util, prop_remover, raid`.

Convention module : chaque fichier lit/écrit la table globale `MODULE` et `Curry(f)` ; le module est publié dans `BaseWars[MODULE.Name]` (`modules.lua:60-65`).

### 1.2 Données persistantes [V]

| Table MySQL | Colonnes | Écrite par |
|---|---|---|
| `basewars` | `sid64` PK, `money` BIGINT UNSIGNED, `karma`, `time`, `xp`, `level` | `mysql.lua:SaveVar` à **chaque** changement d'argent/XP/niveau |
| `basewars_crash_refunds` | `sid64`, `session_id`, `amount` | toutes les 5 s (`init.lua:313-316` → `sh_payout.lua:61-63`) |
| `basewars_textscreen_configs` | `sid64` PK, `config` TEXT ≤ 16 000 | à chaque clic textscreen |

**Non persisté** : factions (mémoire uniquement, perdues au redémarrage), entités (remboursées au `ShutDown`/`PreCleanupMap`), bounties, drogues.
PData (SQLite local `sv.db`) : pseudos personnalisés (`customnick.lua:52`). FPP : tables SQLite propres.

### 1.3 Économie [V]

- Argent : `ply.BaseWarsMoney` + envoi `net "BaseWars.Money"` (WriteDouble). `SetMoney` arrondit, interdit < 0 et NaN (`sv_money.lua:57-64`). Pas de plafond haut.
- Sources : paye toutes les 180 s (`sv_payday.lua`, dégressive selon la richesse), imprimantes (`bw_base_moneyprinter.lua:112-126`, plafond = `Capacity`), revente/destruction (`sh_payout.lua`, 60 % de la valeur investie), coffre `bw_vault`.
- Puits : achats spawnmenu, améliorations d'imprimantes (`coût × niveau`), papier.
- Transferts joueur→joueur : commande `/pay` **désactivée** (commentée, `commands.lua:247-294`).

### 1.4 Énergie [V]

- `bw_base` : NetworkVars `Power`/`MaxPower`, santé, explosion, dégâts d'eau.
- `bw_base_generator` : produit `PowerGenerated × périodes`, transmet aux entités `IsElectronic` dans `TransmitRadius` (600), liste mise en cache 2 s (`bw_base_generator.lua:80-113`). **Aucun contrôle de propriétaire** : un générateur alimente aussi les machines voisines ennemies.
- `bw_base_electronics` : consomme `PowerRequired` par période, Think toutes les `0,2 s × ThinkPeriods`.
- 9 générateurs, 32 imprimantes (dont 5 VIP), batterie, tourelles, dispensers, drug lab, assembleur d'armes.

### 1.5 Raids [V]

- Un **seul raid à la fois sur tout le serveur** (état global `MODULE.State`, `sh_raid.lua:7-15`).
- Démarrage par `net "BaseWars.Raid"` mode 0 ; conditions : même statut faction/sans faction, cible « raidable » (≥ `NeededPrinters` entités `IsValidRaidable`), cooldown cible 30 min.
- Pendant un raid : physgun/outils bloqués pour les participants (`shared.lua:207-221`), dégâts aux props/entités autorisés seulement entre participants (`init.lua:144-185`).

### 1.6 Propriété / protection [V]

- Abstraction `BaseWars.CPPI` (`shared/cppi.lua`) avec fournisseurs enregistrables. **Seul gProtect est enregistré** (`integration/gprotect/sv_gprotect.lua`). Avec FPP, on retombe sur `ent:CPPIGetOwner()` et `ForEachOwned` parcourt `ents.GetAll()`.

### 1.7 Points d'extension disponibles (hooks réellement appelés) [V]

Achats : `BaseWars_PlayerCanBuyGun|Drug|Entity|Prop` (retour `false, msg` bloque), `BaseWars_PlayerBuyGun|Drug|Entity|Prop`.
Imprimantes/coffre : `BaseWars_PlayerCanEmptyPrinter`, `BaseWars_PlayerEmptyPrinter`.
Économie : `BW_PayDay` (peut remplacer le montant), `BaseWars_MoneyTransferred`, `BaseWars_PlayerLevelChanged`, `BaseWars_KarmaChanged`.
Factions : `CanJoinFaction`, `CanLeaveFaction`, `CanCreateFaction`, `BaseWars_FactionJoined|Left|Created|Disbanded`.
Raids : `PlayerIsRaidable`, `RaidStart`, `RaidEnded`.
Données : `LoadData(ply)`, `PostLoadData(ply)`. Commandes : `BaseWarsCommand`, `BaseWars.Commands.AddCommand`. Menu F : `BaseWars_GenerateMenu` (client).
Admin : `CAMI` embarqué (`shared/sh_cami.lua`).

### 1.8 Dépendances [V]

| Dépendance | Obligatoire | Source / licence | État |
|---|---|---|---|
| Srlion's Hook Library 3.0.0 | Oui (erreur fatale sinon) | GitHub Srlion/Hook-Library | Installée |
| goobie-sql 4.16.6 + `gmsv_goobie_mysql_4_linux.dll` | Oui | GitHub Srlion/goobie-sql | Installé |
| MySQL | Oui | Fourni par l'hébergeur (1 base max) | Connecté |
| Protection CPPI | Oui | FPP (gratuit) à la place de gProtect (payant) | Installé |
| Fading door | Recommandé | CFC-Servers/cfc_fading_doors (GPL-3.0) | Installé |
| CW 2.0 + packs | Oui pour la boutique actuelle | Steam Workshop | **Manquant** |
| Contenu BaseWars (`Workshop 939081277`) | [?] | Steam Workshop | Non vérifié |

---

## Partie 2 — Architecture proposée pour Astral (à valider)

### 2.1 Principe : un addon séparé, pas une réécriture

```
garrysmod/addons/astral_basewars/
  lua/autorun/astral_init.lua         chargeur (attend que BaseWars soit chargé : hook "PostGamemodeLoaded")
  lua/astral/core/                    config, validation, logs, rate-limit, permissions (CAMI)
  lua/astral/<module>/{sh,sv,cl}_*.lua
  lua/entities/astral_*/              entités dérivées de bw_base_electronics / bw_base_generator
  data_static/astral/                 recettes, ressources, quêtes (tables Lua)
```

Raisons : SpaceVX reste mis à jour depuis GitHub sans conflit ; les correctifs indispensables à SpaceVX sont isolés et listés dans un fichier `PATCHES.md` ; Astral ne parle à SpaceVX que par les hooks et méthodes de la §1.7, et par héritage d'entités.

Alternative écartée pour l'instant : gamemode dérivé (`DeriveGamemode("basewars")`). Le ModuleLoader et la FastDL de SpaceVX s'appuient sur `GM.Folder` (`modules.lua:27`, `init.lua:10`) et risquent de pointer au mauvais endroit — à tester avant de l'envisager.

### 2.2 Correspondance modules demandés ↔ existant

| Module Astral | Décision | Raison |
|---|---|---|
| Core, Security, Logs, Diagnostics | **Nouveau** (socle phase C) | Rien d'équivalent : logs = `MsgC` console, aucun rate-limit |
| Economy | **Étendre** `BaseWars.Economy` | Garder `GiveMoney/TakeMoney` ; ajouter journal des transactions, plafonds, batch SQL |
| Energy | **Étendre** le système `Power` existant | Ajouter propriété des réseaux, batteries, indicateurs ; ne pas créer un 2e système |
| Industries, Inventory, Crafting, Farming | **Nouveau** | Aucune ressource ni recette dans SpaceVX (l'assembleur d'armes utilise des compteurs de composants internes) |
| Progression | **Étendre** XP/niveaux existants (MaxLevel 9999) | Ajouter spécialisations/prestige par-dessus |
| Quests, Events, Market, Statistics | **Nouveau** | `modules/events` ne contient que 12 lignes [V] |
| Factions | **Corriger puis étendre** | Bugs (cf. sécurité), non persistées |
| Raids | **Corriger** (cooldown attaquant), étendre (historique, alertes) | Garder le moteur existant |
| UI | **Nouveau HUD** en remplacement du module `hud` client | Le reste des menus SpaceVX est conservé tant qu'il n'est pas remplacé |
| Admin, Moderation | S'appuyer sur **ULX** (gratuit, intégré par SpaceVX) + CAMI | Pas de menu admin maison redondant |
| Persistence | Nouvelles tables préfixées `astral_` + table `astral_schema_version` | Ne pas modifier les tables SpaceVX |

### 2.3 Socle Astral — implémenté (phase C, v0.1.0, 2026-11-02)

Source : `server_files/addons/astral_basewars/`, déployé par `tools/deploy.ps1`.

| Fichier | Rôle | API publique |
|---|---|---|
| `lua/autorun/astral_init.lua` | Chargeur ; attend `PostGamemodeLoaded` (BaseWars doit exister), envoie les fichiers partagés/clients | hook `Astral.CoreLoaded` |
| `lua/astral/config/sh_config.lua` | Valeurs réglables du socle (aucun secret : fichier envoyé aux clients) | `Astral.Config` |
| `lua/astral/core/sh_core.lua` | Journal console, lecture sûre de la config, identifiant joueur | `Astral.Log`, `Astral.Cfg(path, défaut)`, `Astral.PlayerID(ply)` |
| `lua/astral/core/sv_config.lua` | Règles de validation ; une valeur invalide est remplacée par son défaut et signalée | `Astral.ConfigRule(path, règle)`, `Astral.ValidateConfig()`, `Astral.ConfigProblems` |
| `lua/astral/core/sv_permissions.lua` | Privilèges CAMI (visibles et attribuables dans ULX) : `Astral.Admin` (superadmin), `Astral.Diagnostics`, `Astral.Logs` (admin) | `Astral.HasAccess(ply, clé, callback)` |
| `lua/astral/core/sv_net.lua` | **Point d'entrée unique** des messages client→serveur : taille max, seau à jetons par joueur et par message, joueur vivant, `pcall`, journal des rejets. Message de santé `Astral.Ping` → `Astral.Pong` | `Astral.Net.Receive(nom, {rate, burst, maxBytes, alive}, handler)`, `Astral.Net.Stats` |
| `lua/astral/core/sv_db.lua` | Réutilise la connexion goobie-sql de BaseWars ; migrations numérotées, définitives, appliquées au démarrage | `Astral.DB.OnReady(fn)`, `Astral.DB.Conn()`, hook `Astral.DBReady` |
| `lua/astral/core/sv_logs.lua` | Journal SQL en file, écrit par paquets (pas une requête par événement), file bornée, vidé à l'arrêt, rétention 30 j | `Astral.Logs.Write(catégorie, ply, data)` |
| `lua/astral/core/sv_diag.lua` | Commande `astral_diag` (lecture seule) : config, base, journaux, réseau, entités par classe et par joueur, mémoire Lua | `astral_diag` |
| `lua/astral/core/cl_core.lua` | Partie client : `Astral.Ping()` | `Astral.LastPong` |

**Schéma SQL ajouté** (migration 1) : `astral_schema_version (id, version)` ; `astral_logs (id, ts, category, sid64, data JSON, index (category, ts), (sid64, ts), (ts))`.

**Catégories journalisées** : `join`, `leave` (avec l'argent), `buy`, `collect`, `money_transfer`, `level`, `faction_create/disband/join/leave`, `raid_start`, `raid_end`, `admin_command` (toutes les commandes ULX), `net_reject`, `net_error`, `diag`.

### 2.4 Phase D — implémenté (2026-11-02)

| Fichier | Rôle |
|---|---|
| `lua/astral/economy/sv_economy.lua` | Enveloppe `BaseWars.Economy.SetMoney` (point de passage unique de l'argent) : chaque variation → ligne `money` `{delta, balance, source}` ; la source est déduite du fichier appelant (achat, paye, imprimante, remboursement/destruction, admin_ulx, astral_industrie…). Alerte `economy_alert` + message aux admins si un joueur gagne plus de `Economy.AlertGain` en `Economy.AlertWindow` s. |
| `lua/astral/admin/sv_admin.lua` + `cl_admin.lua` | **Menu admin** : `!astral` ou `/astral` dans le chat (ou `astral_menu`). Onglets Diagnostic, Économie (gains/dépenses sur 24 h par joueur et par source, historique d'un joueur), Journaux (filtre par catégorie). Requêtes via `Astral.Net.Receive("Astral.Admin.Request")`, droit CAMI vérifié côté serveur à chaque demande, réponses compressées. |
| `lua/astral/industry/sh_resources.lua` | Registre des ressources (`Astral.Resources.Register`), tirage pondéré, inventaires `{id = quantité}` (`Astral.Inv`), panneau 3D2D commun des machines. |
| `lua/astral/industry/sv_industry.lua` | Transferts toutes les 5 s entre machines **du même propriétaire** dans un rayon de 400 : foreuse → raffinerie (minerais raffinables), foreuse/raffinerie → conteneur ; vente du conteneur (vidé avant paiement). |
| `lua/astral/industry/sh_spawnlist.lua` | Catégorie « Astral Industries » dans la boutique BaseWars (contrôles d'argent, de niveau et de limite hérités). |
| `lua/entities/astral_drill.lua`, `astral_refinery.lua` | Dérivées de `bw_base_electronics` (énergie, santé, destruction, remboursement). Production incrémentale par temps écoulé, uniquement si la machine est alimentée. |
| `lua/entities/astral_container.lua` | Dérivée de `bw_base` (sans énergie). E = vente par le propriétaire. |

Les ressources n'existent que dans les machines (pas d'inventaire joueur ni de table SQL) : elles sont perdues au redémarrage, comme les entités BaseWars, qui sont remboursées à leur prix.

### 2.5 Règles techniques communes

- Toute action réseau : `Astral.Net.Receive(nom, {rate = n/s, maxLen = octets}, handler)` qui centralise limite de fréquence, taille, validation de propriétaire et journalisation.
- Production industrielle/agricole calculée **à la demande** à partir d'horodatages (`last_tick`, `rate`, `cap`) — pas de timer par machine.
- Écritures SQL regroupées (file d'attente vidée toutes les N secondes + à la déconnexion), transactions pour tout échange entre joueurs.
- Aucune donnée sensible dans un fichier `AddCSLuaFile`.

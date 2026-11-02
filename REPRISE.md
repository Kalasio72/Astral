# Prompt de reprise — Astral BaseWars (2026-11-02, ~16 h 40)

Copie tout ce qui suit dans une nouvelle conversation, ouverte dans le dossier du projet `astral-basewars/`.

---

Tu reprends le projet **Astral BaseWars 2026** : un serveur Garry's Mod BaseWars français, basé sur le gamemode SpaceVX et hébergé chez YorkHost (Pterodactyl, serveur `434e787a`, 83.150.218.165:27000). Tout le projet est dans ce dossier.

**À lire d'abord :** `PROJECT_STATUS.md` (état détaillé et ce qui est vérifié), `NEXT_STEPS.md` (file de travail et décisions du propriétaire), `PATCHES.md` et `SECURITY_AUDIT.md`.

## Règles permanentes (ne jamais déroger)

- **Déploiement** : lancer `tools\backup.ps1` avant chaque déploiement, puis déployer **seulement si la sauvegarde réussit**. Enchaîner avec `if ($LASTEXITCODE -eq 0) { powershell -File tools\deploy.ps1 -Restart }`. La sauvegarde pèse environ 50 Mo et prend plusieurs minutes : la lancer en arrière-plan.
- **Après chaque déploiement**, vérifier la console avec `tools\panel_console.ps1 -Seconds N -Command '…'` : aucune erreur Lua.
- **Patches SpaceVX** : uniquement des fichiers `.psd1` appliqués par `tools\patch_remote.ps1 -PatchFile …`.
- **Compte du propriétaire** (Kalasio Kaven RP, 76561198150326843) : ne jamais le modifier. Les tests d'argent se font avec des bots (`player.CreateNextBot`). Les objets doivent être placés hors des `trigger_remove` du spawn (voir `lua/astral_tools/test_upgrade.lua`).
- **Base de données** : aucune opération destructive.
- **Textes joueurs** : tout en français. Nombres au format français avec `UI.Num` / `UI.Money` (« 1,5 Md »).
- **Tests** : ne jamais déclarer un test réussi sans l'avoir exécuté.
- **Documentation** : mettre à jour `PROJECT_STATUS.md` et `NEXT_STEPS.md` à chaque étape.
- **Secrets** : ne jamais afficher `GMOD_PANEL_KEY`, ni créer ou saisir de GSLT ou d'identifiants.
- **Addons piratés** : ne jamais installer, réparer ou configurer les copies piratées du « DarkRP Addon Pack » ni leurs bibliothèques (zclib, VoidLib, mysqloo). Les 22 addons piégés sont en quarantaine dans `garrysmod/addons_quarantaine/`.
- **Addons laissés inactifs exprès** : ULX-Essentials (commandes `urlban` et `micon` abusives), ulx-extended (alerte de sécurité), physgun et GmodAdminSuite-Config (dépendent de GmodAdminSuite, payant et absent).
- **Façon de travailler** : le propriétaire veut que tu enchaînes toute la to-do list **sans demander de confirmation**. Il peut ajouter des éléments en route. Il veut un rendu « pro » partout.
- **Client de test** : le client GMod piloté par les outils `mcp__gmod__*` est **le compte du propriétaire**. S'il joue (activité dans les journaux), ne pas agir dans son client et ne pas redémarrer sans prévenir.
- **Captures de l'interface** : `render.Capture` dans un hook `PostRenderVGUI`, enregistré dans `data/`, puis lire `C:\Program Files (x86)\Steam\steamapps\common\GarrysMod\garrysmod\data\*.jpg`.

## Fait et déployé aujourd'hui (détails dans PROJECT_STATUS.md)

- **Sécurité** : Astral Shield (bouclier anti-porte dérobée) ; onglet Sécurité du panel local (`panel/`, http://127.0.0.1:8420) avec analyse des fichiers et suppression ou restauration de ligne.
- **Addons** : quarantaine des addons piégés ; Srlion's Hook Library remis en place ; correctif `cl_compat.lua` (un hook InitPostEntity qui plante ne bloque plus les autres) ; SIMPSit (sièges).
- **Interfaces** : menu Tab pro (`cl_scoreboard.lua`) ; menu Échap Astral (`cl_pausemenu.lua`) ; écran d'accueil (`cl_welcome.lua`) avec le MOTD ULX coupé (patch M1) ; chat Astral (`cl_chat.lua`) ; HUD peaufiné.
- **Karma** : supprimé (patch K1 et retrait des interfaces).
- **Amélioration des machines** : Maj+E avec niveau +1, +5 et max (`astral/economy/sv_upgrade.lua`, `cl_upgrade.lua`). Testé 4/4 avec un bot, et utilisé par le propriétaire.

## EN COURS, NON DÉPLOYÉ (reprendre ici)

Demande du propriétaire :
- des imprimantes modernes, dans le style des captures « PrintMax Pro » (boîtiers colorés avec écran ; c'est un addon payant, donc ne rien copier) ;
- un vrai menu d'imprimante avec toutes les infos et des améliorations (vitesse, overclock…) ;
- une **banque** qui centralise l'argent de toutes les imprimantes et permet de les améliorer toutes d'un coup.

Aucun modèle Workshop gratuit convenable n'a été trouvé. Choix retenu : un boîtier construit avec le contenu de base de GMod (bloc PHX `models/hunter/blocks/cube05x075x025.mdl`, 36 × 24 × 12), teint à la couleur du tier et habillé en 3D2D.

**Déjà écrit (non déployé) :**
1. `lua/astral/industry/sh_printers.lua` : `Astral.Printers`.
   - Changement de modèle de tous les `bw_printer_*` et des icônes de la boutique.
   - Améliorations : speed (5 rangs, −10 % d'intervalle), overclock (3 rangs, +25 % de production et +50 % d'énergie), capacity (5 rangs, +50 %), armor (3 rangs, +50 % de PV).
   - Coût = UpgradeCost × facteur × rang visé.
   - `P.PerMinute`, `P.Cost`, `P.Rank` (NWInt `Astral.Upg.<id>`).
2. `lua/astral/industry/sv_printers.lua` : effets (`P.Apply`), `P.Buy`, net `Astral.Printer.Upgrade` (index uint4) et `Astral.Printer.Collect`, banque (`P.Connected`, `P.BankAction` : collect 1, level 2, upgrade 3), net `Astral.Bank.Action` (uint3 action, uint4 type).
3. `lua/entities/bw_astral_bank.lua` : Banque Astral, base `bw_vault`, rayon 1200, intérêts 0, 2 000 PV, écran façade. Ajoutée à la boutique dans `sh_spawnlist.lua` (250 000 £, niveau 10, limite 1).
4. `lua/astral/ui/cl_printers.lua` : `UI.PrinterColor` exportée, production réelle sur l'écran, indication « E : menu · Maj+E : récolter ».

**Reste à faire :**
5. Ajouter dans `lua/autorun/astral_init.lua` : `astral/industry/sh_printers.lua` dans SHARED (après sh_spawnlist) et `astral/industry/sv_printers.lua` dans SERVER_ONLY.
6. Écrire `lua/astral/ui/cl_printerlook.lua` (et l'ajouter à CLIENT_ONLY) :
   - remplacer `ent.Draw` sur chaque instance `bw_printer_*` (balayage comme dans `cl_printers.lua`) ;
   - `DrawModel` avec `render.MaterialOverride(Material("models/shiny"))` et `SetColorModulation` à la couleur `UI.PrinterColor` ;
   - face du dessus en 3D2D : origine `LocalToWorld(Vector(-12.1, -18.05, 6.3))`, angle `GetAngles()` puis `RotateAroundAxis(Up, 90)`, échelle 0.05, soit 722 × 484 px (x vers +y local, y vers +x local) ;
   - sur cette face : cadre sombre, écran `DrawDisplay` (432 × 272) en (20, 20), ventilateur animé à droite (plus rapide en overclock, arrêté hors tension), bandeau « ASTRAL PRINT », voyants des rangs ;
   - côté client, ajuster `PowerRequired` × `P.PowerMul`.
7. Réécrire `lua/astral/ui/cl_upgrade.lua` :
   - **E** sur sa propre imprimante ouvre le menu complet : infos (stock, capacité, production par minute, temps avant plein, papier, énergie, PV), bouton Récolter, cartes Niveau (+1, +5, max via `Astral.Upgrade`) et les 4 améliorations ;
   - **Maj+E** récolte directement ;
   - **E** sur sa Banque ouvre le menu banque : total, Tout récolter, liste des imprimantes connectées, boutons « tout améliorer » (niveau et chaque type) avec coût estimé ;
   - un ennemi garde le comportement E d'origine.
8. Ajouter `upgrade` dans les catégories si nécessaire (déjà fait), puis tester :
   - un script bot du type `test_upgrade.lua` pour `P.Buy`, les effets (intervalle, capacité, PV) et `P.BankAction` ;
   - des captures en jeu.
9. Déployer aussi :
   - la traduction ULX déjà prête : `server_files/data/ulx/adverts.txt` (annonces en français) ;
   - le patch `patches/m2_ulx_bienvenue.psd1` (message de bienvenue).

## File restante ensuite (NEXT_STEPS.md)

- Modèles cohérents pour les autres entités. Générateurs incohérents : machine à laver, palettes, journal « Hentai Generator ». Modèles CS:S (`de_nuke`, `de_train`) non montés chez les joueurs. Kits en carton. N'utiliser que du contenu HL2 ou PHX, avec vérification `file.Exists` et des tailles raisonnables.
- Bitminers 2 (SpaceVX a une intégration : `gamemode/integration/bitminers/`) et Blue's Farm : adapter à l'argent BaseWars, habillage Astral, ajout en boutique.
- À vérifier à l'écran : HUD peaufiné, refus d'amélioration sur la machine d'un autre joueur, siège sur un rebord.

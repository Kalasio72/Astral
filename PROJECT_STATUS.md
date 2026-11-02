# Astral BaseWars 2026 — État du projet

Dernière mise à jour : 2026-11-02, fin d'après-midi (voir les sections datées ci-dessous, la plus récente en premier).

## Imprimantes, banque, habillage des machines, fermes, PNJ, commandes et événements (2026-11-02, 16 h 40 – 19 h)

Demandes du propriétaire : imprimantes modernes, menu d'imprimante avec améliorations, banque centrale, visuels « pro » de toutes les entités, fermes (weed, meth, coke, tabac, feux d'artifice), remplacer les PNJ « soin », commandes fun/utiles dans `!astral` et Tab, événements activables avec effets et boosts.

**Imprimantes** (`industry/sh_printers.lua`, `sv_printers.lua`, `ui/cl_printerlook.lua`, `ui/cl_upgrade.lua`) — déployé, testé.
- Boîtier PHX `cube05x075x025` pour tous les `bw_printer_*` : coque métal éclairée (matériau `models/debug/debugwhite`, « shiny » s'affichait sans ombrage), flancs lumineux à la couleur du tier, aérations, logo « ASTRAL PRINT », façade sur le dessus centrée et tournée vers le joueur qui regarde (écran, ventilateur animé, plaque, voyants des rangs).
- Repère 3D2D **mesuré en jeu** (`cam.GetModelMatrix`) : x = `ang:Forward()`, **y = `ang:Right()`** (la première version supposait −Right : façade décalée d'une demi-hauteur, signalé par le propriétaire).
- `surface.DrawLine` / `surface.DrawCircle` en 3D2D tracent une ligne parasite jusque dans le décor : remplacés par des rectangles (aussi dans `cl_printers.lua` et la banque).
- Bug SpaceVX contourné : la NetworkVar String « Capacity » peut rester à 0 côté client (VIP 4 : 2,75 Md au serveur, 0 au client) → `P.Capacity` retombe sur la valeur de la classe.
- Améliorations : vitesse (5), overclock (3, énergie arrondie à l'entier), capacité (5), blindage (3). E = menu complet, Maj + E = récolte. Notifications serveur au format français (`P.Money`).
- Test bot `astral_tools/test_printer_upgrades.lua` : **18/18 OK** (deux fois, avant et après redéploiement).
- Banque Astral (`entities/bw_astral_bank.lua`) : menu E avec total, liste défilante des imprimantes connectées, « tout améliorer » par type ; récolte refusée hors tension. Vérifié en capture (menu complet visible).

**Habillage de toutes les machines** (`industry/sh_looks.lua`, `ui/cl_looks.lua`) — déployé, vérifié en capture (vitrine `astral_tools/test_looks.lua`, 14 machines).
- Générateurs (gaz, solaire, charbon, fission, hydro, fusion, matière noire), coffres-forts, distributeurs (munitions, armure, papier), point de réapparition, machines Astral Industries (foreuse, raffinerie, conteneur, fabricateur, serre, batterie) : bloc PHX vérifié sur le serveur (`file.Exists`), couleur d'identité, flancs lumineux (`UI.DrawCasing`, échelle proportionnelle à la taille du bloc), façade animée par famille (cœur de réacteur, foret, flammes, plante, cellules, caisses, anneau de progression, icône, ondes).
- Noms français : champ `label` + dictionnaire `EXACT` dans `cl_shop.lua` (« Money Vault » → « Coffre-fort », etc.).
- Non touchés exprès : tourelles, radar, tesla, distributeur automatique, explosifs, soins (modèles fonctionnels).

**PNJ** (`entities/astral_npc.lua`, `world/sv_npcs.lua`, `ui/cl_npcs.lua`) — déployé, vérifié en capture (guide).
- Les `bw_npc` SpaceVX (tenue de médecin, pris pour des PNJ de soin) sont retirés (hook `BaseWars.NPCs.CreateNPCs` supprimé). Trois PNJ Astral aux mêmes emplacements sur evocity : Ava (guide : aide, raccourcis, règles, boutique), Barney (quêtes, classements, recherche), Silas (receleur, à −6297 −5742).
- Plaque holographique, anneau lumineux au sol, boîte de dialogue au style Astral.

**Fermes Astral** (`farms/sh_farms.lua`, `farms/sv_farms.lua`, `entities/astral_farm_base.lua`, `entities/astral_bag.lua`, `ui/cl_farms.lua`) — **écrit de zéro**, aucune ligne reprise des addons piratés en quarantaine.
- 5 machines (F4 → Astral Fermes) : culture de cannabis (15 000 £, niv. 3), séchoir à tabac (25 000 £, niv. 5), atelier pyrotechnique (60 000 £, niv. 8), labo de cocaïne (120 000 £, niv. 15), labo de méthamphétamine (400 000 £, niv. 25, surchauffe : purge obligatoire avant 100 °C sinon explosion).
- Récolte dans un sac (60 unités max) ; revente au receleur ; à la mort, le sac tombe au sol (`astral_bag`) et peut être ramassé. Feux d'artifice : revente ou tir (effet visible par tous).
- Valeurs et prix : 🔸 à valider par le propriétaire (`F.Products`, `F.Machines`).

**Événements** (`events/sh_events.lua`, `sv_events.lua`, `ui/cl_events.lua`) : 10 événements (5 nouveaux : frénésie d'impression, récolte record, marché noir, ruée vers l'or, nuit des feux d'artifice). Lancement : bannière animée, flash coloré, son, feux d'artifice ; pendant : particules d'ambiance. Menu `!astral` : durée au choix (5 à 60 min).

**Commandes** : `!astral` → clic droit joueur : sous-menus « Commandes utiles » (soigner, armure, invincibilité, invisibilité, noclip, réapparition, retirer les armes) et « Commandes fun » (gifler, envoyer en l'air, enflammer, rétrécir) ; nouvel onglet « Commandes » (soigner tout le monde, geler/dégeler tous, effacer les impacts, feux d'artifice, pluie de billets, ralenti). Chat pour tous (`social/sv_commands.lua`) : `!roll`, `!pile`, `!me`, `!donner`, `!saluer`, `!danse`, `!rire`, `!applaudir`, `!salut`, `!ok`, `!sac`, `!feu`, `!commandes` ; boutons dans la fiche Tab (« FUN & SOCIAL »).

## Astral UI — itération 1 : HUD (2026-11-02, boucle autonome)

Fichiers : `lua/astral/ui/cl_theme.lua` (charte : couleurs, polices adaptées à la résolution, cartes, barres, animation des valeurs) et `lua/astral/ui/cl_hud.lua`.
- Remplace `BaseWars.HUD.Paint` et `BaseWars.PlayTime_Money.Paint` ; les fonctions d'origine sont conservées en mémoire et rétablies si le joueur tape `astral_hud 0`.
- Carte joueur (nom, faction, argent animé, vie, armure, niveau/XP, karma, session), barre du haut (heure, annonce admin, raccourcis), carte de l'entité visée (propriétaire, PV, énergie), message « coincé ».

Vérifié en jeu (capture d'écran) : nouveau HUD affiché, anciens hooks retirés (`BaseWars.HUD.Paint` et `BaseWars.PlayTime_Money.Paint` absents, `Astral.HUD` présent), serveur sans erreur Lua. Non vérifiés : carte d'entité visée, `astral_hud 0`, rendu en 720p/1440p. Toujours au style SpaceVX : notifications (haut gauche), message AFK, raid, anti-RDM, minimap, menus F3 et achat.

## Chat Astral (2026-11-02, 16 h 15)

- **`astral/ui/cl_chat.lua`** remplace l'affichage de la chatbox Garry's Mod, pas son fonctionnement :
  - envoi par `say` / `say_team` ;
  - réception par `chat.AddText`, enveloppé (l'original reste appelé, la console garde les messages), et par le hook `ChatText` ;
  - `StartChat`, `FinishChat` et `ChatTextChanged` sont relancés ; `chat.Open`, `chat.Close`, `chat.GetChatBoxPos` et `chat.GetChatBoxSize` sont redirigés.
- **Affichage** :
  - au-dessus de la carte joueur ; heure de chaque message, couleurs d'équipe, retour à la ligne automatique ;
  - quand le chat est fermé, les 8 derniers messages s'effacent après 12 s ;
  - quand il est ouvert : historique de 200 messages avec molette, pastille TOUS / FACTION cliquable, compteur de caractères au-delà de 100 (limite 126), historique de saisie avec les flèches, Échap pour fermer.
  - `astral_hud 0` rend la main au chat d'origine.
- **Vérifié en jeu (capture)** : affichage ouvert, messages système, longs messages découpés, messages d'équipe. Le propriétaire l'a utilisé en même temps : ses messages sont partis par le nouveau chat et la commande ULX `!astral` a ouvert le menu admin.
- **À traduire** : le message de bienvenue SpaceVX « Welcome to Astral BaseWars | FR! We're playing … » (en anglais) et l'aide « Appuyez et maintenez 'C' … » d'un addon.

## Accueil Astral et HUD peaufiné (2026-11-02, 16 h)

- **Écran d'accueil** (`astral/ui/cl_welcome.lua`) :
  - Affiché à chaque connexion, avec les raccourcis F3, F4, Tab, E, Maj+E, Échap et les boutons « Lire les règles » et « Commencer à jouer ».
  - Rouvrable avec `astral_accueil`.
  - Le MOTD ULX par défaut, en anglais, est coupé par le patch M1 (`data/ulx/config.txt` : `showMotd 2 → 0`).
  - Vérifié en jeu (capture) : l'accueil s'affiche et le MOTD ULX n'apparaît plus.
- **Nombres au format français** (`UI.Num` dans `cl_theme.lua`, utilisé par `UI.Money` et donc par toutes les interfaces Astral) : « 12 345 », « 1,2 M », « 1,5 Md », « 1 000 Md », au lieu de « 1.2 Million » ou « 1 Billion ». Testé sur 10 valeurs.
- **HUD** :
  - Raccourcis du haut en pastilles : F3 Menu, F4 Boutique, Tab Joueurs, Échap Serveur. L'ancien texte indiquait « A Boutique » à tort.
  - Carte de l'entité visée : nom traduit et barre de niveau pour les machines améliorables.

## Amélioration des machines — interface Astral (2026-11-02, 15 h 45)

- **`astral/ui/cl_upgrade.lua`** :
  - Maj + E en visant sa propre machine améliorable ouvre un panneau. E seul récolte toujours l'argent.
  - Le panneau affiche : niveau sur 25 avec barre, production par minute actuelle et au niveau suivant, stock et capacité, papier, état « hors service ».
  - Boutons +1, +5 et niveau max, avec le coût exact.
  - Une indication « Maj + E · Gérer et améliorer » s'affiche quand on vise sa machine.
- **`astral/economy/sv_upgrade.lua`** (`Astral.Upgrade.Do`) :
  - Réutilise `ENT:Upgrade` de SpaceVX : mêmes coûts (coût de base × niveau), même plafond, même gain que `/upg` et `/maxupg`. L'équilibrage ne change pas.
  - Contrôles : machine du joueur, à portée (200 unités), joueur vivant, 2 demandes par seconde au maximum.
  - Nouvelle catégorie de journal `upgrade` (panel et menu admin).
- **Vérifié** : `astral_tools/test_upgrade.lua`, avec un bot et une imprimante de test supprimés ensuite, passe 4/4 OK (niveau 1, +1 débite 1 000 £, +5 s'arrête au dernier niveau payable, quantité invalide refusée).
- **Non vérifié** : le refus de la machine d'un autre joueur (aucun joueur connecté au moment du test).
- **Utilisé en conditions réelles par le propriétaire (16 h 06)** : imprimante VIP 4 montée du niveau 1 au niveau 7 pour 945 Md. Le coût est conforme à la formule SpaceVX : 45 Md × (1+2+…+6). C'est journalisé dans `upgrade`.

## Addons du propriétaire, quarantaine et premier lot d'alternatives (2026-11-02, 13 h – 14 h 30)

- **Installation du propriétaire (13 h)** : 28 addons.
  - Srlion's Hook Library a disparu pendant l'opération : BaseWars ne démarrait plus. Il est remis depuis la sauvegarde et fait maintenant partie de `server_files/`.
  - 22 addons piégés (copies du « DarkRP Addon Pack ») sont **en quarantaine** dans `garrysmod/addons_quarantaine/` à la demande du propriétaire. Déplacés, non supprimés.
  - Après redémarrage : aucune erreur Lua, 0 blocage du bouclier.
  - Restent installés : Bitminers-2, Bitminers-2-Extras, Blues-Farm, GmodAdminSuite-Config, ULX-Essentials, physgun, ulx-extended.
- **Panne client trouvée** : le hook `atlaschat.CreateChatbox` plantait à la connexion (conflit avec pixel-ui piraté) et bloquait les hooks suivants. Résultat : argent affiché à £0 et erreur CW 2.0 à chaque image. Correctif `astral/ui/cl_compat.lua` : les hooks InitPostEntity des addons tiers sont protégés.
  - Vérifié en jeu : argent correct, initialisation de CW 2.0 faite.
- **Sièges** : SIMPSit (Apache-2.0, `addons/simpsit`), avec une règle anti-abus Astral (`sh_astral.lua`) qui interdit de s'asseoir sur les props ou machines d'un autre joueur.
  - Vérifié côté serveur : chargé, commande `sit`, règle active.
  - SIMPSit ne fait asseoir que sur un rebord (banc, muret, prop), pas sur un sol plat : c'est le comportement d'origine de l'addon.
  - Non testé en jeu : un siège réussi sur un rebord.
- **Menu Tab Astral** (`cl_scoreboard.lua`, réécrit en version complète) :
  - Mode épinglé au clic, recherche par nom ou SteamID, onglets Tous / Factions / Staff, tri par colonne.
  - Colonnes : rang, niveau, temps de jeu, frags, morts, ping avec barres.
  - Fiche joueur avec actions : profil Steam, SteamID, message privé, micro, masquer son chat. Actions staff selon les droits ULX : aller à, amener, renvoyer, geler, observer, muet, sans voix, expulser, bannir avec durée.
  - Priorité haute sur les autres tableaux.
- **Menu Échap Astral** (`cl_pausemenu.lua`) : Reprendre, Menu principal, Boutique, Règles, Aide, Paramètres du jeu, Se déconnecter, plus une carte joueur et serveur. Vérifié à l'écran.
- **Karma désactivé** (demande du propriétaire) : patch K1 dans `config.lua` (plus de perte, plus de délai de réapparition lié au karma, plus de halo), et retiré du HUD, du menu F3, de la fiche joueur et du menu admin. Le délai anti-RDM de base (+4 s par meurtre gratuit) reste en place.

## Panel — onglet Sécurité, analyse des fichiers et suppression de ligne (2026-11-02, 12 h 50)

- **Analyseur** `astral/admin/sv_security.lua` :
  - Parcourt addons/, lua/, gamemodes/ et les addons Workshop montés, en tâche de fond (4 ms par tick).
  - Se lance 30 s après chaque démarrage, ou avec la commande `astral_securite_analyse`.
  - Rapport dans `data/astral/securite_analyse.json`, avec pour chaque faille : gravité, type, addon, chemin, ligne et extrait.
  - Signatures détectées : les adresses connues ; les appels masqués en \x / \ddd ; le code caché dans un tableau d'octets ; le téléchargement suivi d'une exécution ; l'exécution d'un fichier de données ; l'exécution de code reçu par le réseau ; le code décodé (Base64, compressé ou inversé) puis exécuté ; les rangs donnés en dur ; les changements du mot de passe RCON ; les SteamID écrits en dur ; les noms de fonction masqués ; les faux .vtf, .png ou .jpg.
  - Les lignes de commentaire sont ignorées, ainsi que la ligne officielle de `player_auth.lua`.
- **Astral Shield** : chaque blocage indique maintenant l'addon, le fichier et la ligne. Pendant une réponse HTTP, c'est le fichier qui a envoyé la requête qui est indiqué.
- **Onglet Sécurité du panel** :
  - Indicateurs en haut de page, filtres par gravité et par addon.
  - Lien qui ouvre le fichier dans l'onglet Fichiers.
  - Tableau des tentatives bloquées en direct.
  - Bouton **Supprimer la ligne**. La ligne est remplacée par un commentaire, ce qui garde les numéros de ligne. Avant la suppression, une copie est faite dans `data/astral/failles_sauvegardes/`. Après, le serveur de jeu compile le fichier (`astral_securite_syntaxe`) ; si la syntaxe est cassée, l'original est remis automatiquement. Tableau « Lignes supprimées » avec un bouton **Restaurer**.
- **Vérifié** :
  - `securite_tests/test_analyse.lua` : 8/8 OK.
  - Analyse réelle du serveur : 1 029 fichiers en 12 s, 0 faille, après correction de 3 faux positifs (ligne officielle de GMod, SteamID d'exemple en commentaire).
  - Test de bout en bout sur un faux addon piégé (hors autorun, retiré ensuite) : 5/5 OK. Les 2 failles sont trouvées avec le bon addon et la bonne ligne. Une suppression qui casse la syntaxe est refusée et le fichier reste identique. La suppression de la ligne RunString passe la vérification de syntaxe. La restauration redonne un fichier identique.
  - Rendu de l'onglet vérifié dans le navigateur.
- **Non vérifié** : un vrai addon infecté, et la nouvelle attribution d'addon d'Astral Shield en conditions réelles (aucun blocage depuis le déploiement).

## Astral Shield — bouclier anti-porte dérobée (2026-11-02, 12 h 20)

- `addons/astral_basewars/lua/autorun/server/!!!astral_shield.lua`, chargé avant tous les autres fichiers autorun serveur. Bloque : les adresses des portes dérobées trouvées (kvcdoor.ovh, panelpetitvac.xyz, vcmod.xyz, sinax.site) ; tout RunString / RunStringEx / CompileString exécuté pendant une réponse HTTP ; tout code qui télécharge puis exécute (signature des fausses textures .vtf) ; les commandes console sensibles (rcon_password, sv_password, ulx, lua_run, sv_allowcslua, sv_cheats) envoyées depuis une réponse HTTP ; toute promotion de rang faite hors ULX / ULib / CAMI / Astral. Chaque blocage : message rouge en console, avertissement aux superadmins connectés, ligne dans le journal `security` (panel → Journaux, menu admin → Journaux).
- Vérifié : démarrage sans erreur et sans faux positif (ULX et le reste fonctionnent) ; `securite_tests/test_bouclier.lua` → 7/7 OK (adresse bloquée avant envoi, chargeur refusé à la compilation, RunString normal toujours autorisé, RunString dans une réponse HTTP bloqué, sv_password depuis HTTP bloqué, promotion superadmin d'un bot hors ULX bloquée) ; blocages visibles dans le journal via le panel.
- Limites : ne protège pas contre un code malveillant qui n'utilise ni le réseau ni l'exécution dynamique (ex. un addon qui donne de l'argent ou des droits directement dans son code) ; une copie piratée reste à éviter (SECURITY_AUDIT.md A1).

## Retour aux mécaniques de base pour les tours (2026-11-02, 11 h 40)

- Sur consigne du propriétaire : patch T1b (`patches/t1b_tours_mecanique_origine.psd1`) remet le ciblage d'origine des tours gel/acide, et la catégorie « Tours de défense » est retirée de la boutique (vérifié : absente après redémarrage, aucune erreur Lua). Les seuls correctifs de plantage T1 restent dans les fichiers SpaceVX.

## Vérification des panneaux des machines Astral (2026-11-02, midi)

- Vitrine d'un bot (`astral_tools/test_astral_showcase.lua`, retirée après 120 s) photographiée en jeu : serre (« Hors tension (lumière éteinte) », 0 / 2000), conteneur (contenu, valeur, « E pour vendre »), raffinerie (« En attente de minerai », barre d'énergie 30 / 3000, minerai reçu du conteneur), foreuse (« Hors tension »). Aucune modification de code nécessaire ; affichage simulé côté client seulement (caméra et position, restaurées).

## Tours de défense réparées et en vente (2026-11-02, midi)

- Patch P12 / T1 (`patches/t1_tours.psd1`, appliqué par `tools/patch_remote.ps1`) sur les trois tours SpaceVX, puis nouvelle catégorie boutique « Tours de défense » : Tour de soin (30 000 £, niv. 6), Tour de gel (60 000 £, niv. 12), Tour à acide (75 000 £, niv. 15), 2 de chaque au maximum.
- Vérifié (`astral_tools/test_towers.lua`, tours d'un bot) : les 3 tours apparaissent sans erreur (rayon 300), coût d'amélioration calculé (1,2 M / 2,4 M / 3 M £ au niveau 1), la tour de soin soigne son propriétaire (50 → 74 PV en 6 s), aucune erreur Lua pendant le fonctionnement sans cible ; `check_shop.lua` : classes reconnues. Non testé : achat réel par la boutique, gel/acide pendant un vrai raid à 2 joueurs.

## Astral UI — coffres-forts et tours (2026-11-02, midi)

- `ui/cl_printers.lua` généralisé (table `SCREENS`) : écran Astral aussi pour le coffre-fort et le coffre-fort VIP (montant stocké en grand, taux d'intérêt, prochain gain, rayon d'aspiration en mètres, « HORS TENSION », « Appuie sur E pour récupérer ») et pour les tours soin / acide / gel (nom français, niveau, coût d'amélioration). Même règle : seul `DrawDisplay` hérité de la base SpaceVX est remplacé, retour automatique à l'écran d'origine en cas d'erreur, `astral_hud 0` pour l'écran SpaceVX.
- Vérifié en jeu (capture d'une vitrine appartenant à un bot) : coffre (123 456 £, hors tension), coffre VIP (0 £, « Vide », couleur arc-en-ciel), imprimantes toujours correctes, panneau de la tour de soin affiché ; remplacement automatique confirmé sur les 5 entités, aucune erreur client.
- Constat SpaceVX (non corrigé) : `bw_turret_healer` lève une erreur à l'apparition (`GetRadius` nil, `bw_turret_healer.lua:152`) ; les trois tours ne sont de toute façon pas vendues dans la boutique.

## Panel — page Marché (2026-11-02, fin de matinée)

- Nouvelle page « Marché » du panel local (lecture seule) : offres ouvertes (ressource, vendeur, reste, prix), unités sous séquestre, 100 dernières ventes (acheteur, vendeur, achat, total), ventes / volume / taxe détruite sur 7 jours, taux de taxe en vigueur (réglage d'équilibrage). Route `GET /api/astral/market`. Le panel suit aussi désormais les liens directs `#page` sans rechargement.
- Vérifié : panel redémarré, API (2 ventes de test, 650 £ échangés, 32 £ de taxe — cohérent avec le test des bots), page affichée dans le navigateur intégré, passage #community → #market sans rechargement.

## Menu admin — équilibrage en jeu (2026-11-02, fin de matinée)

- Migration 7 : `astral_settings` (réglage, valeur, auteur, date). `admin/sv_settings.lua` : 38 réglages modifiables depuis `!astral` → onglet « Équilibrage » — économie (alertes), industrie (vitesses, stocks, capacité, rayon), marché (taxe, bornes, limites), événements (intervalle, durée, joueurs min.) et prix de vente des 21 ressources. Chaque valeur est validée par sa règle (type, entier, min, max), appliquée immédiatement, envoyée aux clients, journalisée (`admin_action` / `setting`) et réappliquée au démarrage. « Rétablir » réécrit la valeur par défaut du fichier (aucune suppression). Lecture : staff (Diagnostics) ; modification : privilège Admin (superadmin).
- Ajouts : `Astral.SetCfg` (partagé), `Astral.CheckConfigValue`, règles de validation du marché.
- Vérifié : `astral_tools/test_settings.lua` → 4 refus corrects (non numérique, hors plage, non entier, réglage non modifiable), écriture du prix du charbon 10 → 11 en base, **réappliquée après un vrai redémarrage**, puis rétablie à 10. En jeu : onglet chargé (38 réglages), modification envoyée par le menu acceptée côté serveur, aucune erreur client. Rendu non vu en capture.

## Astral UI — écrans des imprimantes (2026-11-02, matin)

- `ui/cl_printers.lua` : nouvel écran 3D2D pour les 33 imprimantes SpaceVX (seul `ENT.DrawDisplay` est remplacé ; même emplacement, mêmes données). Fond sombre, bandeau et badge de niveau dans la couleur d'identité du modèle (cuivre, or, VIP arc-en-ciel…), argent stocké en grand + pourcentage + barre, « Pleine dans … · £/s » ou « Pleine — appuie sur E » clignotant, jauge de papier, coût d'amélioration, « HORS TENSION » pulsé, « Imprimante désactivée ». Noms traduits (« Imprimante en cuivre », « en or »…, aussi dans la boutique). Suit `astral_hud` ; en cas d'erreur de dessin, l'imprimante revient d'elle-même à l'écran d'origine.
- Vérifié en jeu (capture d'une vitrine d'imprimantes appartenant à un bot, retirée ensuite) : rendu correct pour cuivre (44 %), or (pleine) et VIP 0 (hors tension). Premier déploiement : le remplacement ne s'appliquait pas (table d'entité pas prête à `OnEntityCreated`) → nouvel essai à 1 s + balayage toutes les 2 s ; après redéploiement, remplacement automatique confirmé sur les 3 modèles, aucune erreur client. Le correctif final d'espace double dans « Imprimante VIP 0 » est déployé sans erreur serveur mais pas revu en jeu.

## Marché entre joueurs (2026-11-02, matin)

- Migration 6 : `astral_market` (une ligne par offre : vendeur, ressource, quantités, prix unitaire, `proceeds` = argent dû au vendeur, statut 0 ouverte / 1 vendue / 2 annulée). Aucune suppression.
- `market/sv_market.lua` : mise en vente depuis les conteneurs industriels (ressources sous séquestre en base), achat (débit → livraison → mise à jour **conditionnelle** `status = 0 AND qty_left >= n` ; refus = annulation complète), verrou par offre pendant l'écriture, taxe 5 % détruite, paiement du vendeur par remise à zéro conditionnelle de `proceeds` (immédiat s'il est connecté, sinon à sa prochaine connexion), annulation avec restitution. Bornes : prix 0,25× à 10× la valeur de référence, 500 unités et 5 offres par joueur (`Config.Market`). Journal : `market_list/buy/cancel/payout`.
- F3 → page « Marché » (onglets Acheter / Vendre / Mes offres, boîte de dialogue quantité + prix avec total, taxe et somme nette calculés en direct ; tout est revérifié par le serveur).
- Vérifié avec deux bots (`astral_tools/test_market.lua`, 12/12 OK) : séquestre, prix hors bornes refusé, achat de sa propre offre refusé, quantité excessive refusée, achat partiel (8 livrés, 400 débités, vendeur payé 380), double achat simultané (un seul exécuté), annulation (7 rendus), base cohérente. Premier essai interrompu (conteneur de test de l'acheteur disparu à cause de son emplacement) : l'offre de test n° 1 restée ouverte a été clôturée par `astral_tools/market_close_bot_orders.lua` (offres de bots uniquement, statut 2, sans suppression). En jeu : page ouverte, 3 onglets parcourus, aucune erreur client. Non testé avec de vrais joueurs ; rendu non vu en capture.

## Panel — onglet Communauté (2026-11-02, matin)

- Nouvelle page « Communauté » du panel local : indicateurs (profils joueurs et actifs de la semaine, factions actives, technologies débloquées, quêtes réclamées), 5 classements à onglets (mêmes critères que F3, vrais comptes Steam uniquement, clic → fiche joueur), factions persistées (couleur, chef, membres, mot de passe 🔒, date), barres Recherche (joueurs par technologie) et Quêtes (réclamées / commencées). Route `GET /api/astral/community`, lecture seule. Les noms affichés dans tout le panel viennent maintenant d'abord de `astral_players`.
- Vérifié : panel redémarré, API appelée (Fortune et Niveau corrects, 1 profil, 2 quêtes commencées, 0 faction), page affichée dans le navigateur intégré sans erreur console, onglet « Niveau » cliqué.

## Astral UI — réapparition et radar (2026-11-02, matin)

- Les deux derniers affichages SpaceVX sont remplacés (suivent `astral_hud`, comme les autres) : compte à rebours de réapparition (`BaseWars.AntiRDM.Paint` → carte « Réapparition dans » + barre) et minimap (`MiniMap` → radar Astral : disque sombre, anneaux, balayage, flèches orientées, alliés en vert, adversaires de raid en rouge, portée en mètres, placé au-dessus de la carte de munitions). Données inchangées (NWInt `RespawnTime`, NW2Bool `BaseWars_HasRadar`, `Config.RadarRange`). Les halos de karma SpaceVX restent.
- Vérifié en jeu (capture) : hooks d'origine retirés, radar affiché (portée 78 m), carte de réapparition affichée (00:14) ; affichages simulés côté client uniquement (fonctions remplacées 10–20 s puis restaurées, aucun changement serveur ni de compte). Aucune erreur Lua client. Non vérifié : points des autres joueurs sur le radar (aucun autre joueur connecté).
- Indicateurs d'énergie (phase D) : déjà présents dans le code (barre d'énergie sur les panneaux 3D2D et la carte d'entité visée, noms tronqués) ; rendu non revérifié dans cette itération.

## Factions persistées (2026-11-02, matin)

- Migration 5 : `astral_factions` (nom, chef, couleur, sel + SHA-256 du mot de passe, création, `disbanded_at`) et `astral_faction_members` (une ligne par joueur, `faction = NULL` après départ). Aucune suppression : une faction dissoute est seulement marquée.
- `factions/sv_factions.lua`, sans modifier le gamemode : écrit création/adhésion/départ/dissolution (hooks `BaseWars_Faction*`) ; remplace le hook `PlayerDisconnected` « BaseWars.Factions.Clean » pour les factions persistées (la déconnexion du chef ne dissout plus la faction) ; recrée au démarrage les factions actives (équipe + couleur) ; remet chaque joueur dans sa faction (et chef) 3 s après sa connexion ; le mot de passe n'est plus gardé en clair (vérification par `CanJoinFaction`) ; un nom de faction hors ligne ne peut pas être repris (`CanCreateFaction`). Le délai de raid stocké sur la faction survit donc aussi aux déconnexions.
- Vérifié avec des bots (aucun vrai joueur touché) : `test_factions.lua` → création, hachage, mauvais mot de passe refusé / bon accepté, ligne en base, faction conservée après déconnexion du chef, dissolution marquée en base : tout OK. `test_factions_restart_a/b.lua` → après un vrai redémarrage : faction rechargée, équipe recréée, chef reconnecté remis dans sa faction avec son rôle et son équipe, dissolution : tout OK. Restent en base deux factions de test marquées dissoutes (« Astral Test Faction », « Astral Test Restart »).
- Non testé : avec de vrais joueurs (menu F3, plusieurs membres, raid entre factions persistées).
- **Correctif journal** trouvé pendant ce test : une ligne de journal sans joueur (bot, ou `raid_end`) faisait échouer l'écriture groupée (`missing parameter`) et bloquait **définitivement** le journal jusqu'au redémarrage, en perdant le paquet. Corrigé dans `sv_logs.lua` (identifiant vide → NULL, `pcall` qui libère la file et remet le paquet en attente). Vérifié : 3 lignes sans joueur écrites, 0 échec.
- Classements : les bots sont désormais exclus (seuls les SteamID64 `7656119…` sont classés).

## Statistiques et classements (2026-11-02, matin)

- Migration 4 : table `astral_players` (pseudo, dernière connexion, gains industriels cumulés, unités produites). Les tables `basewars*` ne sont que lues.
- `stats/sv_stats.lua` : gains (`Astral.IndustrySold`) et production (`Astral.Produced`) cumulés en mémoire, écrits toutes les 60 s, à la déconnexion et à l'arrêt (delta remis en attente si l'écriture échoue). 5 classements (Fortune, Niveau, Temps de jeu, Industriels, Producteurs), top 10, valeurs en direct des joueurs connectés, cache 60 s.
- F3 → nouvelle page « Classements » (onglets, médailles or/argent/bronze, pastille « en ligne », ligne du joueur surlignée). Les pages Factions/Raids/Règles/Aide passent en 5 à 8.
- Vérifié : redémarrage sans erreur Lua (seule erreur : matériau de la map, déjà présente), migration 4 appliquée ; `astral_tools/test_leaders.lua` → 5 classements construits en 45 ms, second appel servi par le cache ; en jeu, données reçues par le client avec pseudo et statut en ligne, menu ouvert et 5 onglets parcourus sans erreur client. Rendu visuel non vérifié par capture (render.Capture n'inclut pas le Derma).
- Limite : les joueurs jamais reconnectés depuis la migration s'affichent « Joueur hors ligne » (pseudo enregistré à la prochaine connexion).

## Phase E — agriculture (2026-11-02, nuit)

- `astral_greenhouse` (Serre hydroponique, 20 000 £, niv. 4, limite 4) : culture choisie avec E (propriétaire, vérifié serveur), croissance par temps écoulé quand la serre est alimentée, replantation automatique, stock 30, récoltes envoyées vers les conteneurs et fabricateurs. 4 cultures (blé, tomates, herbes médicinales, fleur astrale) et 3 recettes de transformation au fabricateur (ration de survie, médicament, essence astrale). Nouvelle quête du jour « Main verte » (compteur `harvest`).
- Vérifié : `astral_tools/test_farming.lua` → 4 blés récoltés en 60 s, replantation (24 % au contrôle), machines supprimées. Non testés : menu de culture en jeu, autres cultures, recettes agricoles.
- Effet de bord : l'ajout d'une quête au tirage change la sélection du jour (tirage déterministe sur la liste) ; la progression déjà enregistrée reste en base.

## Phase E — arbre de recherche (2026-11-02, nuit)

- `astral/research/` : 7 technologies sur 3 niveaux (Forage optimisé, Fonderie avancée, Logistique ; Forage profond, Ateliers automatisés, Négoce ; Réseau intelligent), coût en argent + composants pris dans les conteneurs du joueur, prérequis, effets appliqués aux machines du propriétaire (vitesse foreuse/raffinerie/fabricateur, minerais rares, capacité conteneur, ventes, débit batterie). Migration SQL **3** (`astral_research`). Paiement en une étape puis enregistrement ; **remboursement complet** si l'écriture en base échoue. Page **Recherche** dans F3 (statut, stock de composants « 4/10 », bouton).
- Vérifié : migration 3 appliquée ; test `astral_tools/test_research.lua` (en mémoire, état restauré, rien en base) : bonus foreuse 1,5625, rares 1,5, capacité +250, vente 1 → **4/4 OK** ; page Recherche ouverte sans erreur et synchronisée. Non testé : déblocage réel (aurait débité le compte du propriétaire).

## Phase E — événements (2026-11-02, nuit)

- `astral/events/` : 5 événements (Ruée minière ×2 foreuses, Hauts fourneaux ×2 raffineries/fabricateurs, Paye doublée via le hook SpaceVX `BW_PayDay`, Pluie de cristaux ×8 minerais rares/cristaux, Boom du marché +50 % ventes). Automatiques (≥ 2 joueurs, 45 min après le précédent, durée 10 min — `Astral.Config.Events`) ou manuels : onglet admin « Annonce & événements », ou `astral_event <id|stop>` (privilège Astral.Admin ; console serveur). Annonce + pastille animée dans le HUD avec compte à rebours. Journal `event_start` / `event_end`.
- Vérifié en jeu : `astral_event mining_rush` → multiplicateur foreuse = 2 côté serveur, pastille « Ruée minière · 9:51 » et annonce affichées ; arrêt par `astral_event stop`. **Bug trouvé et corrigé pendant le test** : `a and f()` tronquait le 2e retour → erreur Lua dans le HUD pendant un événement. Non testés : déclenchement automatique (il faut 2 joueurs), effets réels sur la production/paye/vente.

## Phase E — quêtes journalières et hebdomadaires (2026-11-02, nuit)

- `astral/quests/sh_quests.lua` (6 quêtes quotidiennes, 5 hebdomadaires, récompenses argent + XP), `sv_quests.lua` (tirage identique pour tous : 3 par jour, 2 par semaine ; réinitialisation à minuit / lundi minuit heure serveur ; progression en mémoire, sauvegarde groupée toutes les 60 s + déconnexion + arrêt ; récompense verrouillée et enregistrée **avant** paiement), migration SQL **2** (`astral_quests`), page **Quêtes** dans le menu F3 (cartes, barres, temps avant réinitialisation, bouton Réclamer).
- Compteurs : argent récolté sur les imprimantes, machines achetées, minutes de jeu hors AFK, lingots raffinés, composants fabriqués (`hook Astral.Produced`), ventes industrielles (`hook Astral.IndustrySold`), raids lancés.
- Vérifié : migration 2 appliquée ; quêtes du jour (Présence, Fonderie, Commerce industriel) et de la semaine (Pilier du serveur, Conquérant) envoyées au client ; page Quêtes ouverte sans erreur ; temps AFK non compté (0 après 2 min d'inactivité) ; avec activité simulée : 2 min comptées sur la quête du jour et de la semaine, **lignes présentes en base**. Non testé : réclamation de récompense (aurait crédité le compte du propriétaire), changement de période, autres compteurs en conditions réelles.

## Phase D (suite) : fabricateur, recettes, batterie (2026-11-02, nuit)

- 4 composants (`steel_plate`, `circuit`, `alloy_frame`, `power_cell`) et 4 recettes (`Astral.Recipes`, sh_resources.lua). Entités `astral_fabricator` (60 000 £, niv. 12, menu de recette avec E, réservé au propriétaire, vérifié serveur) et `astral_battery` (15 000 £, niv. 6, 25 000 d'énergie, redistribue 200/s aux machines du propriétaire). Transferts : le fabricateur prend uniquement les ingrédients de sa recette (5 cycles d'avance max) dans les conteneurs/raffineries ; les conteneurs récupèrent ses produits.
- Outil `lua/astral_tools/test_industry.lua` : test automatique sans débit d'argent (crée, alimente, vérifie, supprime).
- **Test exécuté sur le serveur** : 2 plaques d'acier produites à partir de 6 lingots de fer + 2 charbon (ratio exact), statut « En attente : Lingot de fer » ensuite ; batterie chargée par les générateurs (84 / 25 000 après 40 s) ; machines de test supprimées. Non testés : menu de recette en jeu, redistribution de la batterie vers une machine vide, autres recettes.

## Polish « pro » du HUD + zones de spawn (2026-11-02, nuit)

- HUD : avatar Steam, reflet sur les barres, halo d'accent, gains/pertes d'argent animés, vie qui clignote sous 30 %, badge de niveau, bandeau « Niveau supérieur », carte munitions moderne (remplace CHudAmmo), noms longs tronqués (`UI.Truncate`).
- Panneaux 3D2D des machines refaits (liseré, statut coloré, barre d'énergie, ressources en grille avec pastilles, fondu à distance).
- **Bug trouvé sur Evocity** : la zone de spawn contient des `trigger_remove` (9 sur la map) qui suppriment sans remboursement tout objet acheté dedans. Correctif (`astral_rules.lua`) : achat refusé avec un message si la position d'apparition ou le joueur est dans une de ces zones.
- Vérifié en jeu sur Evocity : avatar et nouvelle carte joueur affichés ; achat au spawn refusé (toast affiché, argent non débité) ; libellés VIE/ARMURE corrigés. Message « Coincé ? » retiré (faux positif de `Player:Stuck()` côté client), à redéployer. Non vérifiés : panneaux 3D2D refaits, carte munitions, flottants d'argent, bandeau de niveau (il faut sortir de la zone de spawn pour acheter des machines).

## Map et contenu Workshop (2026-11-02, nuit)

Collection `3832089289` : 5 items — CW 2.0 + Extra, **Basewars_Evocity_v2** (296828130, 114 Mo, map BaseWars la plus abonnée), **basewars_bangclaw_v1** (425998560, 14 Mo), **Keypad Tool and Cracker** (108424005, Willox). Map par défaut `basewars_evocity_v2` (variable SRCDS_MAP), `cfg/mapcycle.txt` = evocity puis bangclaw. Les joueurs reçoivent le keypad et la map en cours (`astral_workshop.lua`). Alias en minuscules des positions de PNJ SpaceVX (`astral_rules.lua`), sinon les PNJ n'apparaissaient pas sur Linux.
Vérifié côté serveur : les 5 items sont téléchargés, les deux .bsp sont présents, la map active est evocity, **3 PNJ d'aide** créés, aucune erreur Lua (seul avertissement : un matériau de la map, `receptiondesk_display_01_.vmt`). Non vérifiés : connexion d'un joueur sur la nouvelle map, outil keypad en jeu. 🔸 Choix de map fait par Claude sur délégation du propriétaire : modifiable dans le panel (Configuration → SRCDS_MAP).

## Panel web local + menu admin enrichi (2026-11-02, nuit)

- `panel/` : panel local http://127.0.0.1:8420 remplaçant YorkHost (détail et tests : panel/README.md).
- Menu admin `!astral` : nouveaux onglets **Joueurs** (argent, niveau, karma, faction, entités, ping, état ; clic droit : donner/retirer de l'argent, définir le niveau, aller vers, ramener, geler, rembourser ses entités, expulser, bannir via ULib, copier SteamID64), **Machines** (toutes les entités bw_/astral_ triées par distance ; aller vers, supprimer avec remboursement), **Annonce** (bandeau 8 s + chat). Actions réservées au privilège CAMI `Astral.Admin`, journalisées en `admin_action`.
- Vérifié en jeu : onglet Joueurs rempli (ton compte, superadmin), onglet Machines vide (attendu après redémarrage), annonce affichée (bandeau, chat, toast « Annonce envoyée à 1 joueur(s) »), écran d'absence Astral visible. Non testés (pour ne pas toucher au compte du propriétaire et faute de 2e joueur) : argent/niveau/kick/ban/gel/ramener/remboursement, suppression d'entité.

## Astral UI — itération 4 : menu principal F3 (2026-11-02)

`lua/astral/ui/cl_menu.lua` (+ composants `UI.Button/Input/Label/Frame` dans `cl_theme.lua`, règles dans `Astral.Config.Rules`) : Accueil (statistiques), Factions (créer avec palette, rejoindre, quitter avec confirmation), Raids (lancer, abandonner), Règles, Aide en français. Remplace le hook Think SpaceVX `BaseWars.Menu.Open` (rétabli par `astral_hud 0`).
Vérifié en jeu : ancien hook retiré, les 5 pages s'ouvrent sans erreur Lua, création d'une faction « Astral Test » via la fonction client utilisée par le menu → faction active et affichée dans la liste. Non vérifiés : rendu visuel, rejoindre/quitter, raids (2 joueurs). 🔸 Les règles par défaut sont une proposition : à valider par le propriétaire.

## Astral UI — itération 3 : boutique (2026-11-02)

`lua/astral/ui/cl_shop.lua` : boutique moderne (catégories à gauche, recherche, cartes avec modèle, nom et catégorie traduits à l'affichage, prix coloré selon l'argent, badges Niveau/VIP, limite, confirmation au style Astral). Achat par la commande serveur SpaceVX `basewars_spawn` (contrôles serveur inchangés). Accès : 1er onglet « Boutique Astral » du menu de création, touche **F4**, `!boutique`, `astral_shop`. L'onglet SpaceVX d'origine reste présent.
Vérifié en jeu : ouverture sur « Astral Industries » (3 cartes), achat d'un conteneur par clic sur sa carte (conteneur créé, toast d'achat), onglet enregistré dans le spawnmenu, panneau 3D2D du conteneur lisible. Non vérifiés : rendu visuel de la fenêtre (l'outil de capture ne montre pas les interfaces Derma), recherche, confirmation, affichage dans le spawnmenu. Défaut vu : sur la carte d'entité visée, un nom long chevauche le nom du propriétaire.

## Astral UI — itération 2 : notifications, absence, raid (2026-11-02)

`lua/astral/ui/cl_overlays.lua` : toasts (haut droite, couleurs SpaceVX converties vers la charte, 6 s, glissement), carte d'absence, bandeau de raid (camps, temps restant, barre). `BaseWars.Notify:Add` est redirigé vers les toasts ; les hooks `BaseWars.Notify.Paint`, `BaseWars.AFK.Paint`, `BaseWars.Raid.Paint` sont retirés (rétablis par `astral_hud 0`).
Vérifié en jeu : toasts d'achat et de test affichés, ancienne boîte de notifications disparue, hooks retirés, carte d'entité visée affichée (propriétaire, PV, « Hors tension »). Corrigé ensuite (non encore redéployé à cette ligne) : la carte d'entité chevauchait l'invite « E » de SpaceVX, elle est descendue. Non vérifiés : écran d'absence et bandeau de raid (nécessitent 30 s d'inactivité / un raid à 2 joueurs).

## Phase D — économie, menu admin, Astral Industries (2026-11-02)

| Test réellement exécuté | Résultat |
|---|---|
| Démarrage sans erreur Lua | OK après correction (`continue` est un mot réservé en GLua) |
| Achat de 3 générateurs, 1 foreuse, 1 raffinerie, 1 conteneur via la boutique | OK, 76 500 £ débités |
| Foreuse alimentée → extraction | OK |
| Raffinerie : réception des minerais et production | OK (lingots de fer et de cuivre produits) |
| Conteneur : collecte automatique | OK (charbon + lingots) |
| Vente du conteneur (E) | OK : « Vendu 4 ressources pour £140 » (2×10 + 45 + 75), conteneur vidé |
| Menu admin `!astral` | Ouvert ; Diagnostic rempli ; Économie : 76 500 £ dépensés, source « achat » ; Journaux : 111 lignes |
| Journal `money` avec source | OK (source « achat ») |

Constats : la raffinerie était à court d'énergie pendant le test (3 générateurs à gaz pour foreuse + raffinerie) ; le panneau 3D2D au-dessus du conteneur n'a pas été vérifié visuellement (hors champ, et l'outil de capture ne montre pas les interfaces Derma). Non testés : refus de vente et de transfert pour un autre joueur, alerte économique, destruction en raid.
Compte de test : niveau et XP du propriétaire modifiés par lui-même via ULX à 02:27 (niveau 9 999, XP 1 250 250), d'où un niveau qui remonte à chaque gain d'XP.

## Phase C — socle Astral v0.1.0 (2026-11-02)

Détail dans ARCHITECTURE.md §2.3. Tests réellement exécutés sur le serveur :

| Test | Résultat |
|---|---|
| Chargement du socle au démarrage, sans erreur Lua | OK (`[Astral:core] Socle Astral 0.1.0 chargé`) |
| Migration 1 appliquée, schéma à jour | OK (`Migration 1 appliquée`, `schéma v1`) |
| Validation de la config | OK, 0 correction |
| Socle présent côté client | OK (`Astral.Version == "0.1.0"`) |
| Limite de fréquence réseau : 5 `Astral.Ping` envoyés d'un coup | 2 acceptés (rafale = 2), 3 rejetés, **1 seule** ligne `net_reject` journalisée |
| Journal SQL : connexion et achat d'une imprimante | Lignes `join`, `net_reject`, `buy` présentes dans `astral_logs`, écrites en un paquet |
| `astral_diag` depuis la console serveur | OK |

Non testé : `astral_diag` lancé par un joueur (refus/accès via CAMI), journal `admin_command`, vidage à l'arrêt, rétention, comportement si MySQL est indisponible.

## 0. Bloc 0 — fait le 2026-11-02

| Action | Vérification |
|---|---|
| ULib + ULX (GitHub TeamUlysses, `master`) installés | [S] console : `Loading SHARED module: ulx_init.lua` et `Srlion Hook Library: Stopped ULX/ULib from loading it's hook library!` (cohabitation prévue par la Hook Library) |
| Intégration BaseWars ↔ ULX active | [S] `BaseWars.AdminMenus.Active == "ulx"`, 9 commandes dans la catégorie ULX « BaseWars », préfixe des commandes BaseWars : `/` et `.` |
| `STEAM_0:1:95030557` (Kalasio Kaven RP) → `superadmin` | [S] `ulx adduserid` + lecture de `ULib.ucl.users` |
| Langue `FRENCH`, traduction complétée (voir `PATCHES.md` P4, P6 à P8) | [S] `BaseWars.LANG.PayDay` renvoie le texte français |
| Pseudos personnalisés désactivés (`ExtraStuff = false`), ce qui corrige S1 | [S] `BaseWars.Config.ExtraStuff == false` |
| `server.cfg` : `hostname "Astral BaseWars \| FR"`, `sv_allowcslua 0`, `sv_allowupload 0` | [S] `GetHostName()` |
| Outil de sauvegarde `tools/backup.ps1` + `BACKUP.md` | [V] exécuté : archive de 590 Ko avec l'export SQL JSON |
| Redémarrage après ces changements | [S] aucune erreur Lua au démarrage |

Pas encore fait dans le Bloc 0 : armes, GSLT, map, tickrate (décisions à prendre), symbole monétaire (toujours « £ »). Le menu et le HUD en français n'ont pas été revus en jeu.

Légende : **[V]** vérifié (fichier lu ou commande exécutée), **[S]** vérifié sur le serveur hébergé, **[?]** à vérifier.

## 1. Ce qui tourne réellement sur le serveur

| Élément | État | Preuve |
|---|---|---|
| Gamemode `basewars` (spacevx/gmod-basewars, branche `master`, octobre 2026) | En ligne | [S] console : `Changing gamemode to BaseWars (basewars)` |
| Modules BaseWars chargés | 12 sur 12 | [S] console : `[BWML] STATS: Loaded 12 modules` |
| MySQL `s7635_basewars` via goobie-sql v4.16.6 (module 32 bits) | Connecté | [S] console : `[BaseWars] Connected to MySQL with goobie-sql` |
| Srlion's Hook Library 3.0.0 | Chargée (obligatoire) | [S] `Adding Filesystem Addon 'addons/srlion_hook_library'` |
| Falco's Prop Protection (CPPI) | Chargé | [S] idem `addons/fpp` |
| CFC Fading Doors | Chargé | [S] idem `addons/cfc_fading_doors` |
| Erreurs Lua au démarrage | Aucune après correctifs | [S] journal du 2e redémarrage |
| Armes CW 2.0 de la boutique | Installées via la collection Workshop `3832089289` ; 9 entrées remappées (PATCHES P9) | [S] `Mounted 2 of 2 workshop addons!` ; `astral_tools/check_shop.lua` : seules `weapon_crowbar` et `prop_vehicle_jeep` (classes moteur, non détectables par ce test) ressortent. Achat testé en jeu : P99 acheté (−5 000 £), ramassé (E), équipé avec 15 balles. Au 1er essai le modèle était invisible (packs non envoyés aux clients) → ajout de `addons/astral_basewars/lua/autorun/server/astral_workshop.lua` (`resource.AddWorkshop`) ; après reconnexion, les modèles CW existent côté client [V `file.Exists`]. Rendu visuel de l'arme non revérifié. Avertissement client : police `Prototype` introuvable au 1er chargement (fournie par CW, extraite pendant la connexion) |
| Admin mod | ULX + ULib (installés pendant le Bloc 0, voir §0) | [S] |
| Token Steam (GSLT) | **Absent** | [S] `No account token specified` |
| Nom du serveur | « Astral BaseWars \| FR » (Bloc 0) | [S] `GetHostName()` |
| Langue du gamemode | `FRENCH` (Bloc 0) | [S] |
| Map | `gm_flatgrass` (aucun PNJ configuré pour cette map) | [S] ligne de démarrage ; [V] `config.lua:280-349` |
| Tickrate | 22 | [S] ligne de démarrage — bas pour du PvP |

## 2. Modifications déjà faites sur SpaceVX (à conserver lors des mises à jour)

1. `gamemode/server/mysql.lua` — identifiants MySQL (lignes 4-8) et chemin d'inclusion de goobie-sql rendu absolu (`(GM or GAMEMODE).FolderName .. "/gamemode/server/thirdparty/goobie-sql.lua"`). Raison : l'inclusion relative échouait au runtime ([S] erreur `File not found` au 1er démarrage).
2. `gamemode/integration/admin_menus.lua` — `AdminMenus:Register` préfixe le chemin par `FolderName/gamemode/`. Raison : `AddCSLuaFile: Couldn't find 'integration/sam/bw_admin_sam.lua'` ([S]).
3. Ajout `gamemode/server/thirdparty/goobie-sql.lua` et `lua/bin/gmsv_goobie_mysql_4_linux.dll` (exigés par le README SpaceVX).

Copie locale exacte de l'état serveur : `reference/server_snapshot_2026-11-02/` (gamemode, addons, cfg — sans le binaire).

## 3. Tests en jeu réalisés (2026-11-02, 1 joueur, client GMod x64 piloté via gmcl_mcp)

| Test | Résultat | Preuve |
|---|---|---|
| Connexion au serveur, chargement du gamemode | OK | Lua client : `engine.ActiveGamemode() == "basewars"` |
| Argent de départ chargé depuis MySQL | OK (5 000 £) | `LocalPlayer():GetMoney()` |
| HUD SpaceVX (argent, niveau, XP, karma, horloge) | OK, en anglais avec « £ » | capture d'écran |
| Achat générateur à gaz (500 £) + imprimante en bois (200 £) via `basewars_spawn` | OK, argent 5 000 → 4 300, XP 0 → 136 | Lua client + messages console |
| Propriété CPPI (FPP) sur les entités achetées | OK | `CPPIGetOwner()` = le joueur |
| Transmission d'énergie générateur → imprimante, impression | OK | `GetPower()`, `GetMoney()` de l'imprimante |
| Collecte de l'imprimante (touche E) | OK, +48 £ | argent 4 300 → 4 348 |
| Persistance MySQL de l'argent et de l'XP | OK : la ligne `basewars` contient 4 348 / 136 | requête SQL via la console serveur |
| Erreurs Lua client | Aucune | journal console client |
| Son `mvm/mvm_money_pickup.wav` | **Manquant** (contenu TF2 non monté chez le client) | journal console client |

Incident : GMod client a planté (`engine.dll`, `0xc0000409`) lors d'un `connect` lancé **avec la DLL gmcl_mcp déjà injectée**. Connexion manuelle puis injection une fois en jeu : aucun problème. Procédure retenue : toujours se connecter d'abord, injecter ensuite.

## 3 bis. Ce qui n'a PAS encore été testé

- Reconnexion (chargement après déconnexion), redémarrage serveur (remboursement), amélioration et revente, raid, factions — **non testés**.
- Menus F3 / spawnmenu ouverts visuellement — **non testés**.
- Comportement de FPP avec les entités `bw_*` — **non testé**.
- Charge (nombre d'entités, joueurs simultanés) — **non mesurée**.

## 4. Verdict

Le serveur **n'est pas prêt à ouvrir**. Il démarre proprement, mais la boutique d'armes est cassée, les failles S2 à S8 de `SECURITY_AUDIT.md` ne sont pas corrigées, seuls les tests de base ont été faits en jeu, et la restauration d'une sauvegarde n'a jamais été testée.

Voir `NEXT_STEPS.md` pour l'ordre de travail.

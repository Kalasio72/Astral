# Astral BaseWars — Prochaines étapes

Ordre de priorité. Les décisions marquées 🔸 attendent une réponse du propriétaire du serveur.

## Fait le 2026-11-02 (16 h 40 – 18 h) pendant l'absence du propriétaire

Imprimantes modernes + menu + banque, habillage de toutes les machines, PNJ Astral (guide, quêtes, receleur) à la place des PNJ « soin », fermes Astral (cannabis, tabac, feux d'artifice, cocaïne, méthamphétamine), 5 nouveaux événements avec effets, commandes admin utiles/fun, commandes de chat pour tous. Détails et tests : PROJECT_STATUS (section du jour, la première).

🔸 À valider par le propriétaire :
1. Prix, niveaux et rendements des fermes (`farms/sh_farms.lua`) et des produits chez le receleur.
2. Position du receleur (−6297, −5742 sur evocity : loin du spawn, voulu pour le risque) ; positions du guide et de Barney (anciens PNJ SpaceVX).
3. Commandes fun du menu admin (enflammer, gifler, ralenti) : à garder ou retirer.
4. Le sac de marchandise est perdu à la déconnexion (pas sauvegardé en base).

À faire ensuite :
1. Tester en jeu à 2 joueurs : vol d'un sac lâché, raid sur des fermes, explosion du labo dans une base.
2. Habillage restant (volontairement non fait) : tourelles, radar, tesla, distributeur automatique, plateforme de soin, explosifs.
3. Bitminers 2 et Blue's Farm (sains) : toujours en attente d'accord, à adapter à l'argent BaseWars.

## Bloc 0 — Remise à niveau du serveur

Fait le 2026-11-02 : ULX/ULib, superadmin, français, pseudos désactivés, `server.cfg`, outil de sauvegarde (voir PROJECT_STATUS §0).

Reste :
1. ~~Armes~~ : fait (collection Workshop `3832089289`, PATCHES P9). Reste à tester un achat d'arme en jeu ; armes installées non vendues : MP7, MP9, Saiga 12K, XM1014, VSS.
2. 🔸 Symbole monétaire : « £ » par défaut (`language.lua:2`). Proposition : un symbole propre à Astral (par exemple « ₳ » ou « CR »).
3. 🔸 **GSLT — action du propriétaire** (demandé le 2026-11-02, message console « No account token specified ») : créer le token sur https://steamcommunity.com/dev/managegameservers (App ID **4000**, mémo « Astral BaseWars »), puis le coller dans le panel YorkHost > Démarrage > variable `STEAM_ACC`, et redémarrer. Claude ne crée ni ne saisit ce token (identifiant lié au compte Steam). Autres décisions : map, tickrate (22 actuellement).
4. Liens `Config.Discord/Forums/SteamGroup/Workshop` (`config.lua:36-42`), qui pointent encore vers l'auteur d'origine : à remplacer par ceux d'Astral, ou à vider.
5. ~~restore_db.lua~~ : écrit, testé en mode test. Le mode live reste à exécuter une fois par le propriétaire avant l'ouverture.

## Bloc 1 — Correctifs SpaceVX

Fait le 2026-11-02 (PATCHES P10). Reste : tests à 2 joueurs de S3, S4, S7, S8.
Gameplay G1 à G4 : décidé et appliqué (PATCHES P11, `astral_rules.lua`). À tester à 2 joueurs.
Avant l'ouverture : remettre à zéro le compte de test du propriétaire (argent fixé à 1 000 milliards £ via ULX le 2026-11-02 à 02:27).

## Bloc 2 — Phase C : socle Astral

Fait le 2026-11-02 (v0.1.0, voir PROJECT_STATUS). Reste à tester : accès CAMI à `astral_diag` pour un joueur non admin, journal des commandes ULX, comportement sans MySQL.

## Demandes du propriétaire du 2026-11-02 (nuit) — à traiter dans cet ordre

1. ~~Panel web local remplaçant YorkHost~~ : fait (`panel/`, voir panel/README.md).
2. HUD et interfaces « niveau pro » : polish (animations, icônes, cohérence), panneaux 3D2D des machines refaits, nom long tronqué sur la carte d'entité.
3. ~~Menu admin enrichi~~ : fait (Joueurs, Machines, Annonce). ~~Outils d'équilibrage~~ : fait (onglet « Équilibrage », 38 réglages persistés). Reste éventuel : prix et niveaux des machines de la boutique (catalogue SpaceVX, non modifiable à chaud pour l'instant).
4. ~~Map~~ : fait (evocity v2 + bangclaw, keypad). Ancien texte : Map BaseWars + contenu Workshop utile : à rechercher, ajouter à la collection `3832089289` seulement si gratuit et compatible ; 🔸 le choix final de la map revient au propriétaire si plusieurs candidates.

## Sécurité (demandes du propriétaire du 2026-11-02, après-midi)

1. ~~Bouclier anti-porte dérobée~~ : fait (Astral Shield).
2. ~~Onglet Sécurité du panel, avec la faille, le chemin et l'addon~~ : fait. ~~Bouton pour supprimer la ligne fautive~~ : fait (copie d'origine gardée, vérification de syntaxe, bouton Restaurer).
3. Choix du propriétaire : seule la ligne est supprimée, pas le fichier ni l'addon. Limites :
   - une faille écrite sur plusieurs lignes est refusée, et le fichier reste intact ;
   - un addon Workshop (.gma) ne peut pas être modifié ;
   - le changement prend effet au prochain redémarrage.
4. À tester avec un vrai addon infecté s'il est installé un jour : la suppression a été testée uniquement sur un faux addon de test.
5. 🔸 **2026-11-02, 13 h** : le propriétaire a installé 28 addons, dont les copies piratées de ses archives. Bilan :
   - **Srlion's Hook Library avait disparu**, ce qui empêchait BaseWars de démarrer. Il est remis en place depuis la sauvegarde de 12 h 42 et fait maintenant partie des fichiers déployés (`server_files/addons/srlion_hook_library`).
   - L'analyse trouve **21 addons piégés (70 failles critiques)** : atlaschat, awarn3, blogs, help_menu, itemstore, pastel_finesystem, pixel-f4-master, pixel-ui-master (les copies du pack, pas celles de `addons_officiels/`), prokect-echap, rogue-scoreboard, sh_accessory_system, sh_reports, sh_safezones, sits, the_cocaine_factory, tomascustoms_printers, voidcases, et zeros_methlab02, oilrush, pyrocrafter02, retrominingsystem, weedfarm.
   - Le bouclier a bloqué le chargeur d'atlaschat, et GMod a bloqué `kvac.cz`.
   - **Décision du propriétaire (2026-11-02)** : la quarantaine est refusée, les addons restent installés. Claude ne configure ni ne répare les copies piratées. La protection repose sur Astral Shield, la liste de blocage de GMod et l'onglet Sécurité.
   - Sains : Bitminers-2, Bitminers-2-Extras, Blues-Farm (ce sont des addons DarkRP, ils doivent être adaptés à l'argent BaseWars avant d'être utilisables), ULX-Essentials, physgun, GmodAdminSuite-Config (inutile sans GmodAdminSuite, qui est payant et absent).
   - ulx-extended : 1 alerte moyenne à vérifier (`extented.lua:718`).
   - Défaut à corriger : un blocage survenu quand le socle Astral ne charge pas n'est jamais écrit dans le journal (il reste en mémoire).
   - Défaut de procédure : `backup.ps1` a échoué (export SQL impossible avec BaseWars en panne) et le déploiement a continué. Il faut enchaîner avec `if ($?)`.

## Boucle « finition pro » (lancée le 2026-11-02 vers 14 h, pendant l'absence du propriétaire)

Décisions du propriétaire (2026-11-02, après-midi) :
- addons piégés mis en quarantaine (`addons_quarantaine/`, réversible) ;
- karma supprimé (patch K1 + interface) ;
- il veut un rendu « pro » partout.

File de travail, dans l'ordre :
1. ~~Menu Tab pro~~ : fait (voir PROJECT_STATUS).
2. ~~HUD plus abouti~~ : première passe faite (montants en français, raccourcis, niveau des machines). Boucle arrêtée à 16 h 10 au retour du propriétaire. Il reste à vérifier le nouveau HUD à l'écran.
3. ~~Chat Astral moderne~~ : fait et vérifié (voir PROJECT_STATUS). Reste à traduire le message de bienvenue SpaceVX, qui est en anglais.
4. ~~Imprimantes : panneau d'amélioration~~ : fait (Maj + E, voir PROJECT_STATUS). Reste à le vérifier à l'écran.
4 bis. ~~MOTD ULX en anglais~~ : remplacé par l'accueil Astral (patch M1). ~~Nombres « 1 Billion »~~ : corrigé (UI.Num).
5. Modèles des entités cohérents. 🔸 Le propriétaire a refusé les premiers choix Workshop (« trop vieux ») : proposer des captures avant d'ajouter quoi que ce soit à la collection `3832089289`, qu'il gère lui-même.
6. Habillage Astral des addons sains : SIMPSit, ULX-Essentials, Bitminers 2 et Blue's Farm. Pour ces deux derniers, un accord est nécessaire avant de les rendre actifs, car ce sont des ajouts de gameplay.

## Astral UI (priorité 1 de la boucle autonome)

Fait : HUD principal ; toasts, absence, raid ; boutique (F4 / onglet Q). Prochaines itérations, dans l'ordre :
1. ~~Anti-RDM et minimap au style Astral ; troncature des noms~~ : fait (radar et réapparition vérifiés en capture). Reste : vérifier les points des autres joueurs sur le radar à 2 joueurs.
2. 🔸 Décision propriétaire : traduire les noms des objets SpaceVX dans le catalogue lui-même (`config.lua`), ce qui change les clés d'achat, ou garder la traduction d'affichage actuelle (partielle : imprimantes, générateurs, catégories).
3. Menu F3 (`cl_bwmenu.lua`) → menu principal Astral (aide, factions, raids, règles).
4. ~~Panneaux 3D2D des machines unifiés avec la charte~~ : machines Astral (déjà) et imprimantes SpaceVX (fait, vérifié en capture). ~~Coffre-fort, tours~~ : faits. Reste éventuel : assembleur d'armes (écran complexe). Tours : plantages corrigés (P12) mais **retirées de la boutique** le 2026-11-02 à 11 h 42 (consigne du propriétaire : rester sur les mécaniques BaseWars de base ; elles n'étaient pas vendues à l'origine). Ciblage remis à l'identique de SpaceVX (patch T1b).
🔸 **Consigne du propriétaire (2026-11-02, 11 h 40) : « reste sur les mécaniques de base de BaseWars ».** Avant toute nouvelle fonctionnalité de gameplay, lui demander ; il doit dire quels ajouts Astral garder (industrie, serre, marché, recherche, quêtes, événements…).

## Phase D — première tranche faite le 2026-11-02

Journal des transactions + alertes, menu admin `!astral`, ressources, foreuse, raffinerie, conteneur, vente au serveur (voir PROJECT_STATUS, BALANCE.md).

Reste en phase D :
1. Tests à 2 joueurs : refus de vente/transfert entre propriétaires différents, destruction en raid.
2. Mesurer les revenus réels et ajuster BALANCE.md.
3. ~~Fabricateur + recettes~~ : fait (4 recettes).
4. ~~Batterie~~ : fait. ~~Indicateur d'énergie~~ : fait et vérifié en capture le 2026-11-02 (serre, conteneur, raffinerie, foreuse : état, barre d'énergie, contenu). Phase D terminée hormis les tests à 2 joueurs et la mesure des revenus réels.

## Phase E — prochaine étape de la boucle

Fait : quêtes journalières/hebdomadaires, événements, recherche, agriculture (serre). 🔸 Coûts des technologies à valider (sh_research.lua).

## Suite proposée (boucle)

1. ~~Classements dans F3~~ : fait (5 classements, `astral_players`). ~~Panel web~~ : fait (onglet Communauté). 🔸 Exclure ou non les comptes staff des classements (le compte de test du propriétaire, à 1 000 milliards £, occupe la 1re place tant qu'il n'est pas remis à zéro).
2. ~~Marché entre joueurs~~ : fait (F3 → Marché, testé avec deux bots). ~~Historique dans le panel~~ : fait (page Marché). Reste : test avec de vrais joueurs. 🔸 Décisions propriétaire : taxe (5 %), bornes de prix (0,25× à 10×), limites (5 offres, 500 unités) dans `Config.Market` ; les ressources en vente sont à l'abri des raids (une offre peut servir de coffre) : ajouter des frais de mise en vente non remboursables ou une expiration des offres ?
3. ~~Factions persistées en base~~ : fait (testé avec des bots, y compris à travers un redémarrage). Reste : test avec de vrais joueurs. 🔸 Décisions propriétaire : dissoudre automatiquement les factions inactives après N jours ? Un chef absent bloque l'abandon de raid pour ses membres : transférer le rôle de chef au membre le plus ancien après N jours ?
4. ~~Panel : statistiques Recherche/Quêtes~~ : fait (onglet Communauté). Reste : carte des machines.
5. Tester en jeu le menu de culture et les 3 recettes agricoles.

🔸 Montants des récompenses de quêtes à valider par le propriétaire (sh_quests.lua).

## Bloc 3 et suivants

Économie (journal, écritures groupées), ressources et stockage, Industries, marché, agriculture, recherche, quêtes et événements, factions persistées, interface, statistiques (voir FEATURES §2).

## Tests en jeu restant à faire

Reconnexion (persistance), redémarrage serveur (remboursement), amélioration et revente, création et jonction de faction, raid à 2 joueurs, menus F3 et spawnmenu en français, commandes ULX de la catégorie BaseWars.
Procédure gmcl_mcp : se connecter d'abord, injecter ensuite (un `connect` lancé avec la DLL déjà injectée a fait planter le client).

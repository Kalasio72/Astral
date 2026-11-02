# Astral BaseWars — Audit de sécurité et de performance

Périmètre : code SpaceVX installé (`reference/server_snapshot_2026-11-02/gamemodes/basewars/`) et points d'entrée réseau des addons. Chaque constat vient d'une lecture du code. **Aucun n'a été reproduit en jeu** : la colonne « Reproduit » restera à « non » tant qu'un test réel n'est pas fait.

Gravité : **Haute** (exploitable par un joueur normal, impact sur d'autres joueurs ou le serveur) · **Moyenne** (abus possible, impact limité) · **Basse** (bug ou risque futur).

## 1. Sécurité

| ID | Gravité | Constat | Emplacement | Reproduit |
|---|---|---|---|---|
| S1 | Haute — **corrigé** le 2026-11-02 (`ExtraStuff = false`, PATCHES P5) | N'importe quel joueur peut se donner un pseudo arbitraire (100 caractères) via le message réseau `nname`, sans permission ni limite de fréquence. Le pseudo est persistant (PData), diffusé à tous, et `Player:Nick()` est remplacé globalement → usurpation d'un admin ou d'un joueur dans le chat, les notifications et les raids, plus spam réseau (1 message reçu = 1 diffusion à tous). Activé car `ExtraStuff = true`. | `shared/customnick.lua:71-78`, `:87-89` ; `config.lua:243` | non |
| A1 | **Critique** | Archives d'addons fournies par le propriétaire le 2026-11-02 (Téléchargements : « DarkRP Addon Pack.zip », Zero's MethLab 2, PyroCrafter 2, VoidCases, VoidFactions, AWarn3, pCasino, OneHUD, Prokect-Échap) : **porte dérobée** dans toutes. Variantes : `lua/autorun/server/npc_help.lua` ou `models.lua` qui exécutent une fausse texture (`materials/npc/help.vtf`, `materials/models/black.vtf`) ; ou tableau d'octets dans `sv_server_funcs.lua` / `sv_functions.lua`. Toutes téléchargent puis exécutent du code distant (`kvcdoor.ovh`, `panelpetitvac.xyz`, `vcmod.xyz`, `sinax.site`) via `RunString`. 35 des 40 addons du pack sont touchés, y compris les addons libres (Bitminers 2, Blue's Farm, PIXEL UI…). | Archives sur le PC du propriétaire | Vérifié : **rien sur le serveur ni dans le GMod local**. Ne jamais déployer ; reprendre les addons libres depuis le GitHub officiel de leurs auteurs. Atténuation déployée : Astral Shield (bloque ces 4 adresses et tout code téléchargé puis exécuté). |
| S2 | Haute | Les mots de passe de faction sont écrits **en clair dans la console serveur** à la création, et conservés en clair en mémoire. | `modules/factions/server/sv_factions.lua:222` | oui : masqué dans la console (P10) ; depuis le 2026-11-02 matin, remplacé en mémoire par sel + SHA-256 et stocké haché en base (`astral/factions/sv_factions.lua`) |
| S3 | Moyenne | `Factions:Set` fait quitter la faction actuelle **avant** de vérifier le mot de passe. Un chef qui tape un mauvais mot de passe pour rejoindre une autre faction **dissout sa propre faction**. | `sv_factions.lua:81-87` | non |
| S4 | Moyenne | Création de faction sans limite de fréquence : chaque création fait un `team.SetUp` et une diffusion `net.WriteTable`, et l'identifiant d'équipe croît sans fin. Créer et dissoudre en boucle = trafic réseau et tables d'équipes qui grossissent. | `sv_factions.lua:203-248` | non |
| S5 | Moyenne | `textscreens_upload` : aucune limite de fréquence. Chaque message (jusqu'à 16 000 octets) déclenche une écriture SQL. Un client peut l'envoyer sans passer par l'outil → saturation de la base. | `entities/weapons/gmod_tool/stools/textscreens.lua:7-13` | non |
| S6 | Moyenne | Injection Lua potentielle : le texte `reason` renvoyé par une commande est inséré dans du code `SendLua` entre guillemets, sans échappement. Inoffensif aujourd'hui (seules des chaînes de langue fixes sont renvoyées), mais **toute commande Astral qui renverrait un texte contenant un nom de joueur permettrait d'exécuter du code chez le client**. Même schéma dans `bwa.Error`. | `server/commands.lua:71,85` ; `shared/admin.lua:15-18` | non |
| S7 | Basse | Drug lab : la condition `not Ent.Status == "..."` est toujours fausse (priorité des opérateurs), donc on peut relancer une cuisson pendant une cuisson ; le nom de drogue envoyé par le client n'est pas validé (rejeté plus loin par `ApplyDrug`, ce qui donne une boisson sans effet) ; la distance n'est pas vérifiée. | `entities/entities/bw_druglab.lua:24-33` | non |
| S8 | Basse | Dégâts : `not Attacker == Owner` vaut toujours `false`, donc la branche « membre de la même faction » de `RaidLogic` ne s'applique jamais. Pendant un raid, des membres d'une même faction peuvent détruire les entités de leurs coéquipiers. | `gamemode/init.lua:165` | non |
| S9 | Basse | `basewars_spawn` (achats) n'a pas de limite de fréquence. L'impact reste borné par l'argent et `DefaultLimit = 5`, mais chaque appel fait une trace et plusieurs hooks. | `shared/spawnmenu.lua:228-231` | non |
| S11 | Basse | Erreur `attempt to perform arithmetic on a nil value` dans `LimitDeduct` lors du remboursement général à l'arrêt du serveur (2 occurrences au redémarrage du 2026-11-02). Le compteur `limit_<classe>` du joueur est nil au moment du `OnRemove`. Aucun impact constaté sur l'argent, mais à protéger. | `shared/spawnmenu.lua:11` | **oui** (console serveur) |
| S10 | Info | L'assembleur d'armes accepte n'importe quelle classe dans `SetSelectedClass` (filtrée ensuite par `craftables`, donc sans effet). Propriétaire et distance sont bien vérifiés. | `bw_weapon_assembler.lua:608-618` | non |

**Bloc 1 — 2026-11-02 :** S2, S3, S4, S5, S6, S7, S8, S9 et S11 corrigés (PATCHES P10). Redémarrage sans erreur Lua.
Vérifié en jeu : S9 (5 achats envoyés d'un coup → 1 seul accepté), revente et rachat après correctif S11 (compteur de limite correct), messages en français.
Non vérifiés en jeu (nécessitent 2 joueurs ou des scénarios dédiés) : S3, S4, S5, S7, S8. S2 et S6 vérifiés par relecture du code modifié uniquement.

Contrôles **corrects** relevés : achats vérifiés côté serveur (argent, niveau, VIP, limite) `spawnmenu.lua:44-120` ; `SetMoney` refuse les montants négatifs et NaN `sv_money.lua:57-64` ; `PayOut` bloque NaN et l'infini `sh_payout.lua:14-17` ; kick et remboursement admin vérifient `IsAdmin` côté serveur `admin.lua:98,129` ; raids : la cible doit être un joueur `sv_raid.lua:61` ; requêtes SQL paramétrées `mysql.lua`.

## 2. Choix de gameplay

**Décidé le 2026-11-02 par le propriétaire et appliqué :** G1 = seul le propriétaire collecte hors raid (le camp adverse peut collecter pendant un raid contre lui) ; G2 = un générateur n'alimente que les machines de son propriétaire ; G3 = délai de 5 min pour l'attaquant après la fin d'un raid ; G4 = un seul raid à la fois (inchangé). Vérifié : les 3 règles sont chargées sur le serveur, et un générateur alimente toujours les machines de son propre propriétaire. **Non vérifié en jeu** (nécessite 2 joueurs) : refus de collecte et d'alimentation pour un autre joueur, délai G3.

État d'origine :

| ID | Constat | Emplacement |
|---|---|---|
| G1 | **N'importe quel joueur** peut vider l'argent d'une imprimante ou d'un coffre d'autrui (touche E), même hors raid. Le hook `BaseWars_PlayerCanEmptyPrinter` permet de restreindre. | `bw_base_moneyprinter.lua:127-145`, `bw_vault.lua:61` |
| G2 | Un générateur alimente toutes les machines électriques dans son rayon, **y compris celles des ennemis**. | `bw_base_generator.lua:93-99` |
| G3 | L'attaquant voit son cooldown remis à 0 au lancement d'un raid : il peut enchaîner les raids sans attendre. | `modules/raid/server/sv_raid.lua:105` |
| G4 | Un seul raid à la fois sur tout le serveur. | `modules/raid/shared/sh_raid.lua:7-15` |

## 3. Performance

| ID | Constat | Emplacement |
|---|---|---|
| P1 | Toutes les 5 s : calcul de remboursement de toutes les entités possédées. FPP n'étant pas un fournisseur indexé, cela parcourt `ents.GetAll()`, puis fait **une requête SQL par joueur**. Dans la même passe, un 2e parcours de `ents.GetAll()` éteint les entités en feu. | `init.lua:313-347`, `sh_payout.lua:41-63`, `shared/cppi.lua:53-60` |
| P2 | Chaque modification d'argent, d'XP ou de niveau = un `UPDATE` SQL immédiat (collecte d'imprimante, paye, achat, XP). | `sv_money.lua:57-64`, `sv_playerlevel.lua:61-90` |
| P3 | Chaque événement de dégâts sur un joueur fait 2 `ents.FindInSphere`. | `init.lua:248-274` |
| P4 | Imprimantes : Think toutes les 0,2 s par imprimante. Autres électroniques : toutes les 0,6 s. | `bw_base.lua:59-68`, `bw_base_moneyprinter.lua:12` |

## 4. Hébergement

- Le panel autorise **0 sauvegarde** et **1 base de données** ([S], `feature_limits`). Il faudra une procédure de sauvegarde manuelle (archive des fichiers par l'API, et dump SQL à définir).
- `cfg/server.cfg` est vide : pas de `hostname`, pas de `rcon_password`, et aucun réglage `sv_*` anti-abus.
- Le mot de passe MySQL est dans `gamemode/server/mysql.lua`, côté serveur uniquement (fichier jamais envoyé au client : `include` sans `AddCSLuaFile`) [V].

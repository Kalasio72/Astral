# Astral BaseWars — Fonctionnalités

Statuts : **Natif** (fourni par SpaceVX, code lu) · **Natif cassé** (présent mais non fonctionnel en l'état) · **Prévu** (Astral, non codé) · **Écarté**.
Aucune fonctionnalité n'a encore été testée avec un joueur en jeu.

## 1. Existant SpaceVX

| Domaine | Fonctionnalité | Statut | Source |
|---|---|---|---|
| Économie | Argent persistant MySQL, paye dégressive toutes les 3 min, remboursement après crash | Natif | `modules/economy/*`, `server/mysql.lua` |
| Économie | Transfert `/pay`, primes `/bounty` | Désactivés par l'auteur | `server/commands.lua:247-322` |
| Production | 32 imprimantes (27 + 5 VIP), papier, améliorations jusqu'au niveau 25, plafond de stockage | Natif | `entities/bw_printer_*`, `bw_base_moneyprinter.lua` |
| Énergie | 9 générateurs, batterie, transmission par rayon | Natif | `bw_base_generator.lua`, `bw_gen_*` |
| Défense | Tourelles (balistique, laser, acide, gel, soin, manuelle), tesla, mines, radar, point d'apparition | Natif | `entities/bw_turret_*` etc. |
| Raid | Raid unique global de 5 min, C4, grosse bombe, nuke, chalumeau, désamorçage | Natif | `modules/raid`, `bw_explosive_*`, `bw_blowtorch` |
| Factions | Création, jonction par mot de passe, pas de tir ami | Natif (non persisté, bugs) | `modules/factions` |
| Progression | XP (achats, collecte), niveaux jusqu'à 9999, objets verrouillés par niveau | Natif | `sv_playerlevel.lua`, `sv_rewards.lua` |
| Social | Karma / anti-RDM (délai de réapparition), AFK, messages privés `/pm` | Natif | `modules/antirdm`, `modules/afk` |
| Drogues | 9 effets, drug lab | Natif | `modules/drugs`, `bw_druglab.lua` |
| Armes | Boutique d'armes CW 2.0 (environ 30 entrées) | **Natif cassé** (addon absent) | `config.lua:549-609` |
| Craft | Assembleur d'armes à composants | Natif (dépend des armes CW) | `bw_weapon_assembler*.lua` |
| Interface | HUD, notifications, menu F (aide, commandes), minimap, PNJ d'aide, textscreens | Natif (anglais par défaut) | `client/*`, `modules/hud` |
| Admin | Kick et « Rembourser tout » par menu contextuel, intégrations ULX/SAM | Natif (ULX/SAM non installés) | `shared/admin.lua`, `integration/*` |
| Divers | Pseudos personnalisés, correctifs moteur | Natif (risqué, voir SECURITY_AUDIT) | `shared/customnick.lua` |

Points d'identité à traiter : générateur `bw_gen_hentai` (nom à remplacer), textes de paye codés en dur en anglais avec « £ » (`sv_payday.lua:23,26`), liens par défaut vers les forums et le Discord de l'auteur d'origine (`config.lua:36-42`).

## 2. Astral — prévu (par ordre de priorité)

| # | Module | Contenu minimal viable | Dépend de |
|---|---|---|---|
| 1 | Core / Security / Logs / Diagnostics | Config validée au démarrage, `Astral.Net.Receive` (limite de fréquence, tailles, propriétaire), journal SQL des actions sensibles, commande `astral_diag` | — |
| 2 | Economy (extension) | Journal des transactions, écritures SQL groupées, détection d'anomalies (gain par minute), outils admin | 1 |
| 3 | Ressources et stockage | Registre configurable (fer, cuivre, charbon, silicium, minerai rare, cristal), conteneur industriel | 1 |
| 4 | Industries | Foreuse, raffineur, fabricateur, alimentés par le système `Power` existant, production par horodatage | 2, 3 |
| 5 | Market | Vente à des acheteurs serveur (prix dynamiques bornés), historique | 2, 3 |
| 6 | Farming | Graines, croissance par horodatage, serre, récolte | 3 |
| 7 | Research | Arbre de technologies débloquant recettes et bonus | 3, 4 |
| 8 | Quests / Events | Quêtes journalières et hebdomadaires persistées, événements configurables | 2 à 6 |
| 9 | Factions et Raids | Correction des bugs, persistance des factions, historique et alertes de raid | 1 |
| 10 | Astral UI | HUD, menus machines, inventaire, marché, quêtes, charte sombre spatiale | Tous |
| 11 | Statistics, classements, prestige | | 2, 8 |

Écarté : menu d'administration maison (ULX + CAMI suffisent), second système d'énergie parallèle à `Power`.

## 3. Restant à faire

Tout le tableau de la section 2, la remise en état du natif cassé (armes), et le test en jeu de chaque ligne de la section 1.

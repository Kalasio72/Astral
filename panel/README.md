# Astral Panel — panel local du serveur

Remplace le panel YorkHost pour l'usage courant, depuis ton PC : http://127.0.0.1:8420

## Lancer

Double-clic sur **`Lancer le panel.bat`** (installe la dépendance au premier lancement, ouvre le navigateur, laisse la fenêtre ouverte).
Prérequis : Node.js ≥ 20 et la variable d'environnement utilisateur `GMOD_PANEL_KEY` (déjà en place sur ce PC).

## Sections

| Section | Ce qu'elle fait |
|---|---|
| Tableau de bord | État, joueurs/slots, map, CPU et RAM en direct (graphiques), console récente, fiche serveur (adresse, collection Workshop, tickrate, VAC, GSLT…) |
| Console | Console en direct + envoi de commandes, raccourcis (`astral_diag`, `status`, vérification boutique, export base) |
| Joueurs | Joueurs connectés (requête Source), actions ULX : kick, ban 24 h, téléporter, geler ; fiche joueur (argent, niveau, XP, karma, historique) |
| Économie | Comptes, argent créé/dépensé sur 24 h, sources d'argent, plus riches, alertes, activité par catégorie |
| Marché | Offres ouvertes, ressources sous séquestre, dernières ventes, volume et taxe sur 7 jours |
| Communauté | Classements (fortune, niveau, temps de jeu, industriels, producteurs), factions persistées, technologies débloquées, quêtes réclamées |
| Journaux | Table `astral_logs` filtrable par catégorie et recherche (texte ou SteamID64) |
| Fichiers | Navigation dans le serveur et édition des fichiers texte (Ctrl+S) |
| Configuration | Variables de démarrage (map, collection Workshop, gamemode, slots, tickrate, token GSLT…) |
| Sauvegardes | Lance `tools/backup.ps1` et liste les archives locales |
| Boutons du haut | Démarrer, redémarrer, arrêter, forcer l'arrêt (avec confirmation) |

## Sécurité

- Écoute **uniquement** sur 127.0.0.1 : inaccessible depuis Internet ou le réseau local.
- La clé API YorkHost et le mot de passe MySQL restent dans le processus Node ; ils ne sont jamais envoyés au navigateur ni écrits sur disque.
- Chaque requête doit porter un jeton aléatoire régénéré à chaque lancement et injecté dans la page.
- Base de données : lecture seule (aucune requête d'écriture dans `server.mjs`).

Testé le 2026-11-02 : accès sans jeton refusé (403) ; état, adresse, console connectée ; requête Source (nom, map gm_flatgrass, 1/32, VAC) ; joueurs ; résumé économique (sources paye / astral_industrie / achat) ; journaux filtrés ; liste et lecture de fichiers ; liste des sauvegardes. Non testé : rendu visuel dans un navigateur, boutons d'alimentation, écriture de fichier, sauvegarde depuis le panel, actions ULX.

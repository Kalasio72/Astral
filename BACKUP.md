# Sauvegarde et restauration

Le panel YorkHost n'autorise **aucune sauvegarde** (`feature_limits.backups = 0`). Les sauvegardes sont donc faites par `tools/backup.ps1`, qui utilise l'API du panel.

## Sauvegarder

Prérequis : variable d'environnement `GMOD_PANEL_KEY` (clé client du panel) et serveur **allumé** (l'export SQL passe par le serveur).

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\backup.ps1
```

Ce que fait le script :
1. Il copie `server_files/lua/astral_tools/backup_db.lua` sur le serveur, puis l'exécute avec `lua_openscript`. Le script exporte les tables `basewars`, `basewars_crash_refunds` et `basewars_textscreen_configs` en JSON, dans `garrysmod/data/astral_backups/db_<date>.json`. Il ne fait que des `SELECT`.
2. Il archive `gamemodes/basewars`, `addons`, `cfg`, `data` (qui contient l'export SQL et les rangs ULX) et `sv.db` (PData, FPP), puis télécharge l'archive dans `backups/astral_backup_<date>.tar.gz` et la supprime du serveur.

Le script s'arrête avec une erreur si l'export SQL n'est pas confirmé.
Testé le 2026-11-02 : archive de 590 Ko, 1 ligne `basewars` exportée, `data/ulib/users.txt` présent.

**À faire avant chaque modification importante du serveur.** Les archives contiennent `mysql.lua`, donc le mot de passe MySQL : ne pas les partager.

## Restaurer

**Fichiers** (non testé) : arrêter le serveur, envoyer l'archive dans `/garrysmod` par le gestionnaire de fichiers du panel, la décompresser en écrasant, supprimer l'archive, redémarrer.

**Base de données** : `lua/astral_tools/restore_db.lua` (source : `server_files/lua/astral_tools/restore_db.lua`), en transaction (rien n'est modifié en cas d'erreur). Dans la console du panel :

```
lua_run ASTRAL_RESTORE_FILE = "astral_backups/db_AAAAMMJJ_HHMMSS.json"
lua_run ASTRAL_RESTORE_MODE = "test"
lua_openscript astral_tools/restore_db.lua
```

- Mode `test` : écrit dans des tables `*_restore_test` (créées si besoin), pour vérifier un export sans toucher aux vraies données. **Testé le 2026-11-02** : la ligne restaurée est identique à l'export (4 029 £, 136 XP, niveau 1).
- Mode `live` : remplace le contenu des vraies tables. Refusé si un joueur est connecté. **Jamais exécuté** : c'est une opération destructrice, à lancer soi-même après une sauvegarde fraîche.

Les tables `*_restore_test` du test du 2026-11-02 sont restées dans la base (leur suppression a été bloquée par une protection de Claude Code) ; elles sont inoffensives et peuvent être supprimées à la main.

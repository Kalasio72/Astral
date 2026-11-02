# Astral BaseWars — Hypothèses d'équilibrage

Toutes les valeurs se règlent sans toucher au code : `lua/astral/config/sh_config.lua` (vitesses, stocks, alertes) et `lua/astral/industry/sh_resources.lua` (prix, probabilités). Prix et niveaux des machines : `lua/astral/industry/sh_spawnlist.lua`.
**Ces chiffres sont des hypothèses de départ, pas des mesures** : aucun test avec de vrais joueurs n'a encore été fait.

## Astral Industries v0.1

| Machine | Prix | Niveau | Limite | Énergie |
|---|---|---|---|---|
| Foreuse | 25 000 £ | 5 | 4 | 10 par période de 0,2 s (≈ 50/s) |
| Raffinerie | 40 000 £ | 8 | 2 | 15 par période (≈ 75/s) |
| Conteneur industriel | 10 000 £ | 5 | 2 | aucune |

Un générateur à gaz (500 £) produit environ 75/s : il faut compter à peu près **1 générateur à gaz par foreuse** et **1 à 2 par raffinerie**.

### Extraction (foreuse : 1 minerai toutes les 6 s, soit 10/min)

| Minerai | Probabilité | Prix | Raffiné en (2 → 1) | Prix du produit |
|---|---|---|---|---|
| Fer | 35 % | 15 £ | Lingot de fer | 45 £ |
| Cuivre | 25 % | 25 £ | Lingot de cuivre | 75 £ |
| Charbon | 25 % | 10 £ | — | — |
| Silicium | 12,5 % | 40 £ | Plaquette de silicium | 120 £ |
| Minerai rare | 2 % | 400 £ | Alliage rare | 1 200 £ |
| Cristal énergétique | 0,5 % | 1 500 £ | — | — |

- Valeur moyenne d'un minerai ≈ **34,5 £**, soit ≈ **345 £/min** ≈ **20 700 £/h** par foreuse, vendu brut.
- Raffiner rapporte **+50 %** sur les minerais raffinables (2 minerais → 1 produit valant 1,5× leur somme). Une raffinerie traite 1 lot toutes les 8 s (15 lingots/min), assez pour environ 3 foreuses.
- **Retour sur investissement** (foreuse + générateur, minerai vendu brut) : environ 1 h 15. Avec une raffinerie partagée entre 3 foreuses : environ 1 h 10 pour l'ensemble.

### Fabricateur (v0.2)

| Recette | Ingrédients (valeur) | Produit | Durée |
|---|---|---|---|
| Plaque d'acier | 3 lingots de fer + 1 charbon (145 £) | 200 £ | 12 s |
| Circuit électronique | 2 lingots de cuivre + 1 plaquette de silicium (270 £) | 380 £ | 18 s |
| Châssis en alliage | 1 alliage rare + 2 plaques d'acier (1 600 £) | 2 200 £ | 30 s |
| Cellule énergétique | 1 cristal énergétique + 2 circuits (2 260 £) | 3 200 £ | 40 s |

Gain de transformation ≈ +35 à +40 % par étape. Le fabricateur consomme 20 par période (≈ 100/s) : prévoir une batterie ou 2 générateurs.
**Batterie** : 25 000 de réserve, redistribue 200/s aux machines du même propriétaire à moins de 400 unités.

### Serre (v0.3)

| Culture | Récolte | Durée | Prix unitaire | ≈ £/min par serre |
|---|---|---|---|---|
| Blé | 4 | 60 s | 20 £ | 80 |
| Tomates | 3 | 90 s | 35 £ | 70 |
| Herbes médicinales | 2 | 120 s | 80 £ | 80 |
| Fleur astrale | 1 | 300 s | 900 £ | 180 |

Revenu brut volontairement inférieur à une foreuse (≈ 345 £/min) : l'intérêt est la transformation (ration 110 £, médicament 340 £, essence astrale 1 800 £) et la quête « Main verte ». Consommation : 8 par période (≈ 40/s).

### Marché entre joueurs (v0.4)

- Taxe de 5 % sur chaque vente, payée par le vendeur : l'argent est détruit (puits monétaire).
- Prix unitaire borné entre 0,25× et 10× la valeur de référence : empêche de transférer de grosses sommes entre deux comptes via une offre à prix absurde (ex. lingot de fer : 12 £ à 450 £).
- 5 offres ouvertes et 500 unités par offre au maximum.
- Intérêt attendu : vendre à un autre joueur au-dessus du prix serveur (qui achète au prix de référence), acheter les composants qui manquent pour une recette ou une recherche.

### Limites anti-AFK

- La foreuse s'arrête quand son stock interne (40) est plein ; la raffinerie à 40 en sortie ; le conteneur à 500 unités (≈ 17 000 à 25 000 £).
- Sans vente par le propriétaire (touche E, à moins de 200 unités du conteneur), la production totale est donc plafonnée.
- Les machines ne produisent que si elles sont alimentées en continu (générateurs à entretenir, cibles de raid).

### Points à surveiller lors des tests

1. Comparer le revenu horaire avec les imprimantes du même niveau (Copper Printer, niveau 3, 12 500 £ ; Silver, niveau 7, 20 000 £).
2. Le cristal énergétique (0,5 %) crée des pics de gain : vérifier qu'il ne déclenche pas l'alerte économique.
3. L'alerte économie se déclenche au-delà de **5 M£ gagnés en 5 minutes** (`Economy.AlertGain`) : à abaisser une fois les revenus normaux mesurés.

## Scénarios de test proposés

| Profil | Situation | À mesurer |
|---|---|---|
| Débutant (niv. 1-4) | Imprimantes T0/T1 uniquement | Temps pour atteindre 35 000 £ et le niveau 5 (1re foreuse) |
| Intermédiaire (niv. 5-10) | 2 foreuses + 1 conteneur + 2 générateurs | £/h réel, nombre de ventes par heure |
| Avancé (niv. 8+) | 4 foreuses + raffinerie + conteneur | £/h, part des alliages rares, charge serveur (`astral_diag`) |

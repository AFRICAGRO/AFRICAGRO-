# Outils géographiques

Scripts Python qui transforment de vraies données géographiques gratuites en ressources pour le jeu.
Voir [../GEOGRAPHIE-REELLE.md](../GEOGRAPHIE-REELLE.md) pour la démarche et les licences.

## Installation

```bash
pip install rasterio numpy scipy pillow shapely mgrs
```

## `terrain_reel.py` — un lieu réel devient un terrain Unreal

```bash
python3 terrain_reel.py --nom ile-depart --bbox 5.585 -1.475 5.665 -1.385 \
    --taille 2017 --rotation 35 --miroir --echelle 0.5 \
    --scene S2B_31MGU_20250819_0_L2A --sortie ../terrains/ile-depart
```

| Option | Rôle |
|---|---|
| `--bbox O S E N` | Zone réelle en degrés (longitude ouest, latitude sud, longitude est, latitude nord) |
| `--taille` | 505, 1009, 2017, 4033 ou 8129 pixels (tailles recommandées par Unreal) |
| `--rotation`, `--miroir` | Rendent le lieu méconnaissable |
| `--echelle` | Réduit ou agrandit le lieu (le relief suit) |
| `--exageration` | Accentue seulement les hauteurs |
| `--scene` | Image Sentinel-2 à superposer (identifiant de scène, peu nuageuse de préférence) |

Produit : heightmap PNG 16 bits, aperçu du relief, image satellite alignée, fichier `_infos.json`
(échelles d'import Unreal, sources et mentions obligatoires).

Le relief est téléchargé automatiquement (tuiles Copernicus). Pour l'image, utiliser
`chercher_scene.py` ci-dessous. Pour une zone intérieure, le point bas est ramené vers 0 m
(meilleure précision) ; l'altitude réelle de ce zéro est notée dans `_infos.json`.

## `chercher_scene.py` — image satellite la moins nuageuse

```bash
python3 chercher_scene.py --bbox 10.23 -0.70 10.29 -0.64 --annees 2023 2024 2025 --mois 12 1 2 6 7 8
```

Mesure les nuages **sur la zone elle-même** (pas sur toute la tuile de 110 km) et classe les
scènes. Choisir les mois de saison sèche de la région.

## `modifier_terrain.py` — ajouter des éléments fictifs (volcan, plateaux…)

```bash
python3 modifier_terrain.py --terrain ../terrains/port-wanzala \
    --elements ../terrains/port-wanzala/elements_fictifs.json --nom port-wanzala-fictif
```

Types d'éléments : `greffe` (relief d'une vraie montagne ou d'un vrai volcan, réduit et posé),
`volcan` (cône calculé, moins réaliste), `plateau` (aplanit une zone ; `"altitude_m": "auto"`
arase au niveau du haut de la colline), `repere` (simple nom de lieu). Les positions sont en
fraction du cadre (0 à 1). L'outil lit toujours le terrain d'origine : on peut le relancer
autant de fois que nécessaire en modifiant le fichier JSON.

## `carte_afrique.py` — carte des pays fictifs

```bash
python3 carte_afrique.py --donnees DOSSIER --sortie ../carte-afrique-fictive.svg
```

Les noms et positions des pays sont dans la liste `PAYS` en haut du fichier : déplacer une
capitale déplace toutes les frontières autour d'elle.

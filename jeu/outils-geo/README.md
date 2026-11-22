# Outils géographiques

Scripts Python qui transforment de vraies données géographiques gratuites en ressources pour le jeu.
Voir [../GEOGRAPHIE-REELLE.md](../GEOGRAPHIE-REELLE.md) pour la démarche et les licences.

## Installation

```bash
pip install rasterio numpy scipy pillow shapely
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

Pour trouver le relief d'une zone : les tuiles Copernicus sont téléchargées automatiquement.
Pour trouver une image Sentinel-2 peu nuageuse : chercher la zone sur le navigateur gratuit
*Copernicus Browser* (browser.dataspace.copernicus.eu), noter la date et la tuile (ex. `31MGU`),
puis construire l'identifiant `S2B_31MGU_AAAAMMJJ_0_L2A`.

## `carte_afrique.py` — carte des pays fictifs

```bash
python3 carte_afrique.py --donnees DOSSIER --sortie ../carte-afrique-fictive.svg
```

Les noms et positions des pays sont dans la liste `PAYS` en haut du fichier : déplacer une
capitale déplace toutes les frontières autour d'elle.

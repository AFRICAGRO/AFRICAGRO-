#!/usr/bin/env python3
"""
Transforme un vrai morceau d'Afrique (relief satellite + image satellite) en terrain
prêt à importer dans Unreal Engine 5 (Landscape).

Sources (gratuites, usage commercial autorisé avec mention) :
  - Relief : Copernicus DEM GLO-30 (ESA / Union européenne), ~30 m par pixel
  - Image  : Sentinel-2 L2A « vraies couleurs » (Copernicus), 10 m par pixel

Exemple (île d'Annobón, modèle de l'île de départ) :
  python3 terrain_reel.py --nom ile-depart --bbox 5.585 -1.475 5.665 -1.385 \
      --taille 2017 --rotation 35 --miroir \
      --scene S2B_31MGU_20250819_0_L2A --sortie ../terrains/ile-depart

Dépendances : pip install rasterio numpy scipy pillow
"""
import argparse
import json
import math
import os

import numpy as np
import rasterio
from PIL import Image
from rasterio.crs import CRS
from rasterio.transform import from_bounds
from rasterio.warp import Resampling, reproject, transform_bounds
from scipy import ndimage

DEM_URL = ("https://copernicus-dem-30m.s3.amazonaws.com/"
           "Copernicus_DSM_COG_10_{ns}{lat:02d}_00_{ew}{lon:03d}_00_DEM/"
           "Copernicus_DSM_COG_10_{ns}{lat:02d}_00_{ew}{lon:03d}_00_DEM.tif")
S2_URL = ("https://sentinel-cogs.s3.us-west-2.amazonaws.com/sentinel-s2-l2a-cogs/"
          "{zone}/{band}/{sq}/{year}/{month}/{scene}/TCI.tif")
TAILLES_UNREAL = (505, 1009, 2017, 4033, 8129)


def tuiles_dem(w, s, e, n):
    """URLs des tuiles Copernicus (1° x 1°) qui couvrent la zone."""
    urls = []
    for lat in range(math.floor(s), math.floor(n) + 1):
        for lon in range(math.floor(w), math.floor(e) + 1):
            urls.append(DEM_URL.format(ns="N" if lat >= 0 else "S", lat=abs(lat),
                                       ew="E" if lon >= 0 else "W", lon=abs(lon)))
    return urls


def crs_utm(lon, lat):
    zone = int((lon + 180) // 6) + 1
    return CRS.from_epsg((32600 if lat >= 0 else 32700) + zone)


def grille_carree(bbox, crs, taille, marge=0.08):
    """Grille carrée en mètres (UTM) centrée sur la zone, avec une marge de mer."""
    x0, y0, x1, y1 = transform_bounds("EPSG:4326", crs, *bbox)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    demi = max(x1 - x0, y1 - y0) / 2 * (1 + marge)
    b = (cx - demi, cy - demi, cx + demi, cy + demi)
    return b, from_bounds(*b, taille, taille), (2 * demi) / (taille - 1)


def grille_etendue(bornes, taille, facteur=1.45):
    """Même grille, mais plus grande : la rotation ne fait alors entrer que de vraies données
    dans le cadre final (pas de bords étirés dans les coins)."""
    cx, cy = (bornes[0] + bornes[2]) / 2, (bornes[1] + bornes[3]) / 2
    px = (bornes[2] - bornes[0]) / taille
    grand = int(taille * facteur) | 1
    demi = grand * px / 2
    b = (cx - demi, cy - demi, cx + demi, cy + demi)
    return b, from_bounds(*b, grand, grand), grand


def recadrer(a, taille):
    d = (a.shape[0] - taille) // 2
    return a[d:d + taille, d:d + taille]


def lire_dem(bbox, crs, transform, taille):
    dst = np.full((taille, taille), np.nan, dtype=np.float32)
    with rasterio.Env(GDAL_DISABLE_READDIR_ON_OPEN="EMPTY_DIR"):
        for url in tuiles_dem(*bbox):
            try:
                src = rasterio.open(url)
            except rasterio.errors.RasterioIOError:
                continue  # tuile absente = pleine mer
            tmp = np.full_like(dst, np.nan)
            reproject(rasterio.band(src, 1), tmp, dst_transform=transform, dst_crs=crs,
                      dst_nodata=np.nan, resampling=Resampling.cubic)
            dst = np.where(np.isnan(dst), tmp, dst)
    return dst


def lire_sentinel(scene, crs, transform, taille):
    zone, band, sq = scene.split("_")[1][:2], scene.split("_")[1][2], scene.split("_")[1][3:]
    date = scene.split("_")[2]
    url = S2_URL.format(zone=zone, band=band, sq=sq, year=date[:4], month=int(date[4:6]),
                        scene=scene)
    rgb = np.zeros((3, taille, taille), dtype=np.uint8)
    with rasterio.Env(GDAL_DISABLE_READDIR_ON_OPEN="EMPTY_DIR"):
        src = rasterio.open(url)
        for i in range(3):
            reproject(rasterio.band(src, i + 1), rgb[i], dst_transform=transform, dst_crs=crs,
                      resampling=Resampling.bilinear)
    return np.moveaxis(rgb, 0, -1), url


def fond_marin(h, px_m, profondeur_max=40.0, pente=0.04):
    """Remplace la mer par un fond qui descend doucement depuis la côte."""
    mer = np.isnan(h) | (h <= 0.5)
    dist = ndimage.distance_transform_edt(mer) * px_m
    out = h.copy()
    out[mer] = -np.minimum(profondeur_max, 1.5 + dist[mer] * pente)
    return out


def transformer(a, rotation, miroir, ordre):
    if miroir:
        a = a[:, ::-1]
    if rotation:
        a = ndimage.rotate(a, rotation, reshape=False, order=ordre, mode="nearest")
    return a


def ombrage(h, px_m):
    gy, gx = np.gradient(h, px_m)
    pente = np.arctan(np.hypot(gx, gy))
    aspect = np.arctan2(-gx, gy)
    az, alt = math.radians(315), math.radians(45)
    v = np.sin(alt) * np.cos(pente) + np.cos(alt) * np.sin(pente) * np.cos(az - aspect)
    return np.clip(v, 0, 1)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--nom", required=True)
    p.add_argument("--bbox", nargs=4, type=float, required=True, metavar=("OUEST", "SUD", "EST", "NORD"))
    p.add_argument("--taille", type=int, default=2017, choices=TAILLES_UNREAL)
    p.add_argument("--rotation", type=float, default=0.0, help="degrés, pour rendre le lieu méconnaissable")
    p.add_argument("--miroir", action="store_true", help="symétrie gauche-droite")
    p.add_argument("--echelle", type=float, default=1.0, help="<1 rétrécit l'île (relief compris)")
    p.add_argument("--exageration", type=float, default=1.0, help="multiplie seulement les hauteurs")
    p.add_argument("--scene", help="identifiant Sentinel-2, ex. S2B_31MGU_20250819_0_L2A")
    p.add_argument("--sortie", required=True)
    a = p.parse_args()
    os.makedirs(a.sortie, exist_ok=True)

    w, s, e, n = a.bbox
    crs = crs_utm((w + e) / 2, (s + n) / 2)
    bornes, _, px_m = grille_carree(a.bbox, crs, a.taille)
    bornes_g, transform, grand = grille_etendue(bornes, a.taille)
    bbox_g = transform_bounds(crs, "EPSG:4326", *bornes_g)

    h = lire_dem(bbox_g, crs, transform, grand)
    h = fond_marin(h, px_m)
    h = recadrer(transformer(h, a.rotation, a.miroir, ordre=3), a.taille)
    h = ndimage.gaussian_filter(h, 0.6)  # adoucit les marches du suréchantillonnage
    # zone sans mer (intérieur des terres) : on ramène le point bas vers 0 m pour garder
    # toute la précision verticale ; l'altitude réelle de ce « zéro » est notée dans _infos.json
    base = math.floor(float(h.min())) - 2 if h.min() > 2 else 0
    h = (h - base) * a.echelle * a.exageration
    px_jeu = px_m * a.echelle

    # Encodage Unreal : 32768 = 0 m ; hauteur(m) = (v - 32768) / 128 * ZScale / 100
    zscale = math.ceil(max(abs(h.min()), abs(h.max())) * 1.05 / 256 * 100)
    v = np.clip(np.round(32768 + h * 128 * 100 / zscale), 0, 65535).astype(np.uint16)
    Image.fromarray(v).save(os.path.join(a.sortie, f"{a.nom}_heightmap_{a.taille}.png"))

    sh = ombrage(h, px_jeu)
    terre = h > 0
    apercu = np.dstack([np.where(terre, 90 + sh * 150, 30 + sh * 20),
                        np.where(terre, 110 + sh * 120, 80 + sh * 30),
                        np.where(terre, 60 + sh * 70, 130 + sh * 40)]).astype(np.uint8)
    Image.fromarray(apercu).save(os.path.join(a.sortie, f"{a.nom}_apercu_relief.jpg"), quality=88)

    meta = {
        "nom": a.nom,
        "taille_px": a.taille,
        "metres_par_pixel_jeu": round(px_jeu, 3),
        "cote_km_jeu": round(px_jeu * (a.taille - 1) / 1000, 3),
        "altitude_min_m": round(float(h.min()), 1),
        "altitude_max_m": round(float(h.max()), 1),
        "altitude_reelle_du_zero_m": base,
        "surface_terres_km2": round(float(terre.sum()) * px_jeu ** 2 / 1e6, 2),
        "unreal_import": {"Scale_X_cm": round(px_jeu * 100, 2), "Scale_Y_cm": round(px_jeu * 100, 2),
                          "Scale_Z": zscale},
        "transformations": {"rotation_deg": a.rotation, "miroir": a.miroir, "echelle": a.echelle,
                            "exageration": a.exageration},
        "zone_reelle_wgs84": a.bbox,
        "sources": ["Copernicus DEM GLO-30 — © DLR e.V. 2010-2014 et © Airbus Defence and Space GmbH "
                    "2014-2018, fourni dans le cadre du programme COPERNICUS par l'ESA et l'Union européenne"],
    }

    if a.scene:
        rgb, url = lire_sentinel(a.scene, crs, transform, grand)
        rgb = np.dstack([recadrer(transformer(rgb[..., i], a.rotation, a.miroir, ordre=1), a.taille)
                         for i in range(3)])
        # éclaircit la vraie couleur (les images Sentinel-2 TCI sont sombres), avec un gain
        # adapté à chaque image pour ne pas « brûler » les zones claires (villes, savane sèche)
        rgb = rgb.astype(np.float32)
        terres = rgb[h > 0]
        gain = 1.8 if terres.size == 0 else float(np.clip(225 / max(np.percentile(terres, 97), 1), 1.0, 2.2))
        rgb = np.clip(rgb * gain + 6, 0, 255)
        # au large, on remplace l'image (bords de tuile, reflets) par une mer unie ;
        # on garde la vraie couleur près des côtes (récifs, sable, eaux peu profondes)
        large = ndimage.gaussian_filter((h < -6 * a.echelle).astype(np.float32), 3)[..., None]
        rgb = (rgb * (1 - large) + np.array([28, 62, 84]) * large).astype(np.uint8)
        Image.fromarray(rgb).save(os.path.join(a.sortie, f"{a.nom}_satellite.jpg"), quality=90)
        meta["sources"].append(f"Contient des données Copernicus Sentinel modifiées ({a.scene[10:18]}) — {url}")

    with open(os.path.join(a.sortie, f"{a.nom}_infos.json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False, indent=2)
    print(json.dumps(meta, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()

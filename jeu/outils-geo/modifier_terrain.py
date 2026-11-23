#!/usr/bin/env python3
"""
Ajoute des éléments FICTIFS à un terrain réel (volcan, plateau aplani pour un monument…),
pour le rendre méconnaissable et lui donner une identité propre au jeu.

  python3 modifier_terrain.py --terrain ../terrains/port-wanzala \
      --elements ../terrains/port-wanzala/elements_fictifs.json --nom port-wanzala-fictif

Le fichier d'éléments (JSON) décrit chaque ajout ; les positions sont en fraction du cadre
(0,0 = coin haut-gauche ; 1,1 = coin bas-droit) et les distances en mètres :

  {"type": "volcan", "x": 0.78, "y": 0.2, "rayon_m": 2400, "altitude_m": 1400,
   "cratere_rayon_m": 260, "cratere_profondeur_m": 140}
  {"type": "plateau", "x": 0.21, "y": 0.6, "rayon_m": 550, "altitude_m": 120, "talus_m": 250,
   "couleur": [196, 160, 110]}
  {"type": "greffe", "x": 0.78, "y": 0.22, "rayon_m": 3200, "altitude_m": 1450,
   "source_centre": [8.77, 3.606], "source_rayon_m": 11000, "rotation": 40}
     (relief d'un vrai volcan réduit et posé sur le terrain ; ici le Pico Basilé, Bioko)
  {"type": "repere", "x": 0.65, "y": 0.4, "nom": "Palais présidentiel"}

Produit : nouvelle heightmap, aperçu du relief, image guide retouchée et _infos.json mis à jour.
"""
import argparse
import glob
import json
import math
import os

import numpy as np
from PIL import Image
from scipy import ndimage

from terrain_reel import crs_utm, lire_dem, transformer
from rasterio.transform import from_bounds
from rasterio.warp import transform as transformer_coords


def lire(dossier):
    """Lit toujours le terrain d'ORIGINE (fichiers préfixés du nom du dossier), jamais une sortie."""
    base = os.path.basename(os.path.normpath(dossier))
    infos = json.load(open(os.path.join(dossier, f"{base}_infos.json"), encoding="utf-8"))
    hm = glob.glob(os.path.join(dossier, f"{base}_heightmap_*.png"))[0]
    v = np.array(Image.open(hm)).astype(np.float64)
    z = infos["unreal_import"]["Scale_Z"]
    h = (v - 32768) / 128 * z / 100
    sat = glob.glob(os.path.join(dossier, f"{base}_satellite.jpg"))
    rgb = np.array(Image.open(sat[0])).astype(np.float64) if sat else None
    return infos, h, rgb


def champ_bruit(n, graine, echelle_px):
    """Bruit doux et irrégulier (somme de bruits lissés à plusieurs échelles), entre -1 et 1."""
    rng = np.random.default_rng(graine)
    out = np.zeros((n, n))
    for k, poids in ((1, 1.0), (0.45, 0.5), (0.2, 0.25)):
        b = ndimage.gaussian_filter(rng.standard_normal((n, n)), max(echelle_px * k, 1), mode="wrap")
        out += poids * b / (b.std() + 1e-9)
    return out / 1.75


def ravines(ang, r_norm, bruit, graine):
    """Ravines rayonnantes irrégulières (érosion) sur les flancs du volcan."""
    rng = np.random.default_rng(graine)
    out = np.zeros_like(ang)
    for k in (9, 17, 29):
        out += np.abs(np.sin(ang * k / 2 + rng.uniform(0, 6.3) + bruit * 2.5)) / k ** 0.5
    return -(out - out.mean()) * r_norm


def volcan(h, rgb, el, px, graine=7):
    n = h.shape[0]
    cy, cx = el["y"] * n, el["x"] * n
    yy, xx = np.mgrid[0:n, 0:n]
    dx, dy = (xx - cx) * px, (yy - cy) * px
    bruit = champ_bruit(n, graine, 1200 / px)
    r = np.hypot(dx, dy) * (1 + 0.12 * bruit)                     # contour irrégulier
    R, H = el["rayon_m"], el["altitude_m"]
    rn = np.clip(r / R, 0, 1)
    sol = float(np.median(h[np.hypot(dx, dy) < R * 0.3]))         # altitude du relief sous le sommet
    profil = (1 - rn) ** 1.8 * (1 + 0.45 * ravines(np.arctan2(dy, dx), rn, bruit, graine))
    bosses = champ_bruit(n, graine + 3, 250 / px) * np.sin(np.pi * rn) * 0.06   # coulées, cônes secondaires
    ajout = (H - sol) * (profil + bosses)
    rc, pc = el.get("cratere_rayon_m", 0), el.get("cratere_profondeur_m", 0)
    if rc:
        rr = np.hypot(dx, dy)
        cuvette = pc * np.clip(1 - (rr / rc) ** 2, 0, 1) ** 0.8
        ajout -= cuvette
    # le volcan s'ajoute au relief existant : les collines restent visibles sur ses pentes basses
    h2 = h + ajout
    if rgb is not None:
        lum = rgb.mean(-1, keepdims=True) / 128
        roche = np.clip((h2 - (sol + (H - sol) * 0.35)) / ((H - sol) * 0.3) + 0.25 * bruit, 0, 1)[..., None]
        cendre = np.array([96, 88, 82]) * (0.7 + 0.3 * lum)
        rgb = rgb * (1 - roche) + cendre * roche
        if rc:
            lac = ndimage.gaussian_filter((np.hypot(dx, dy) < rc * 0.5).astype(float), 2)[..., None]
            rgb = rgb * (1 - lac) + np.array([64, 104, 96]) * lac  # lac de cratère
    return h2, rgb


def greffe(h, rgb, el, px):
    """Greffe le relief d'un VRAI volcan (ou de toute montagne) réduit à la taille voulue."""
    n = h.shape[0]
    lon, lat = el["source_centre"]
    crs = crs_utm(lon, lat)
    xs, ys = transformer_coords("EPSG:4326", crs, [lon], [lat])
    Rs, R = el["source_rayon_m"], el["rayon_m"]
    m = int(2 * R / px) | 1                         # taille de la pièce en pixels du jeu
    b = (xs[0] - Rs, ys[0] - Rs, xs[0] + Rs, ys[0] + Rs)
    bbox_ll = (lon - Rs / 100000, lat - Rs / 100000, lon + Rs / 100000, lat + Rs / 100000)
    src = lire_dem(bbox_ll, crs, from_bounds(*b, m, m), m)
    src = np.nan_to_num(src, nan=0.0)
    src = transformer(src, el.get("rotation", 0), el.get("miroir", False), ordre=3)
    yy, xx = np.mgrid[0:m, 0:m]
    rn = np.hypot(xx - m // 2, yy - m // 2) / (m / 2)
    base = float(np.percentile(src[(rn > 0.85) & (rn < 1)], 30))
    piece = np.clip(src - base, 0, None)
    piece = piece / max(piece.max(), 1)                                  # 0..1
    masque = np.clip((1 - rn) / 0.35, 0, 1)
    masque = masque * masque * (3 - 2 * masque)                         # raccord doux sur le bord
    cy, cx = int(el["y"] * n), int(el["x"] * n)
    y0, x0 = cy - m // 2, cx - m // 2
    ys_, xs_ = slice(max(y0, 0), min(y0 + m, n)), slice(max(x0, 0), min(x0 + m, n))
    py, px_ = slice(ys_.start - y0, ys_.stop - y0), slice(xs_.start - x0, xs_.stop - x0)
    zone = h[ys_, xs_]
    sol = float(np.median(zone[(masque[py, px_] > 0.9)]))
    ajout = piece[py, px_] * (el["altitude_m"] - sol) * masque[py, px_]
    h2 = h.copy()
    h2[ys_, xs_] = zone + ajout
    if rgb is not None:
        rgb = rgb.copy()
        haut = np.clip((piece[py, px_] - 0.45) / 0.3, 0, 1)[..., None] * masque[py, px_][..., None]
        lum = rgb[ys_, xs_].mean(-1, keepdims=True) / 128
        rgb[ys_, xs_] = rgb[ys_, xs_] * (1 - haut) + np.array([98, 90, 84]) * (0.7 + 0.3 * lum) * haut
    return h2, rgb


def plateau(h, rgb, el, px):
    n = h.shape[0]
    cy, cx = el["y"] * n, el["x"] * n
    yy, xx = np.mgrid[0:n, 0:n]
    bruit = champ_bruit(n, int(el["x"] * 1000), 300 / px)
    r = np.hypot((xx - cx) * px, (yy - cy) * px) * (1 + 0.18 * bruit)   # contour irrégulier
    R, t = el["rayon_m"], el.get("talus_m", 200)
    w = np.clip(1 - (r - R) / t, 0, 1)
    w = w * w * (3 - 2 * w)                                       # transition douce
    alt = el["altitude_m"]
    if alt == "auto":  # au niveau du haut de la colline : on arase, on ne creuse pas
        alt = float(np.percentile(h[r < R], 85))
        el["altitude_m"] = round(alt, 1)
    h2 = h * (1 - w) + alt * w
    if rgb is not None and "couleur" in el:
        lum = rgb.mean(-1, keepdims=True) / 128
        c = (np.clip(1 - (r - R * 0.85) / (t * 0.6), 0, 1) * 0.85)[..., None]
        rgb = rgb * (1 - c) + np.array(el["couleur"]) * (0.8 + 0.2 * lum) * c
    return h2, rgb


def ombrage(h, px):
    gy, gx = np.gradient(h, px)
    pente = np.arctan(np.hypot(gx, gy))
    aspect = np.arctan2(-gx, gy)
    az, alt = math.radians(315), math.radians(45)
    return np.clip(np.sin(alt) * np.cos(pente) + np.cos(alt) * np.sin(pente) * np.cos(az - aspect), 0, 1)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--terrain", required=True)
    p.add_argument("--elements", required=True)
    p.add_argument("--nom", required=True)
    a = p.parse_args()

    infos, h, rgb = lire(a.terrain)
    px = infos["metres_par_pixel_jeu"]
    elements = json.load(open(a.elements, encoding="utf-8"))["elements"]
    for el in elements:
        if el["type"] == "volcan":
            h, rgb = volcan(h, rgb, el, px)
        elif el["type"] == "greffe":
            h, rgb = greffe(h, rgb, el, px)
        elif el["type"] == "plateau":
            h, rgb = plateau(h, rgb, el, px)

    taille = h.shape[0]
    zscale = math.ceil(max(abs(h.min()), abs(h.max())) * 1.05 / 256 * 100)
    v = np.clip(np.round(32768 + h * 128 * 100 / zscale), 0, 65535).astype(np.uint16)
    Image.fromarray(v).save(os.path.join(a.terrain, f"{a.nom}_heightmap_{taille}.png"))

    sh = ombrage(h, px)
    terre = h > 0
    apercu = np.dstack([np.where(terre, 90 + sh * 150, 30 + sh * 20),
                        np.where(terre, 110 + sh * 120, 80 + sh * 30),
                        np.where(terre, 60 + sh * 70, 130 + sh * 40)]).astype(np.uint8)
    Image.fromarray(apercu).save(os.path.join(a.terrain, f"{a.nom}_apercu_relief.jpg"), quality=88)
    if rgb is not None:
        # léger ombrage du relief sur l'image guide pour que le volcan se lise
        rgb = rgb * (0.75 + 0.35 * sh[..., None])
        Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)).save(
            os.path.join(a.terrain, f"{a.nom}_guide.jpg"), quality=90)

    infos.update({
        "nom": a.nom,
        "altitude_min_m": round(float(h.min()), 1),
        "altitude_max_m": round(float(h.max()), 1),
        "surface_terres_km2": round(float(terre.sum()) * px ** 2 / 1e6, 2),
        "elements_fictifs": elements,
    })
    infos["unreal_import"]["Scale_Z"] = zscale
    with open(os.path.join(a.terrain, f"{a.nom}_infos.json"), "w", encoding="utf-8") as f:
        json.dump(infos, f, ensure_ascii=False, indent=2)
    print(json.dumps({k: infos[k] for k in ("altitude_max_m", "surface_terres_km2", "unreal_import")},
                     ensure_ascii=False))


if __name__ == "__main__":
    main()

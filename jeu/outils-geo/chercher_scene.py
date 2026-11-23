#!/usr/bin/env python3
"""
Cherche l'image Sentinel-2 la moins nuageuse AU-DESSUS D'UNE ZONE précise
(la couverture nuageuse officielle concerne toute la tuile de 110 km, pas notre zone).

  python3 chercher_scene.py --bbox 10.04 5.60 10.10 5.66 --annees 2023 2024 2025 --mois 12 1 2

Affiche les meilleures scènes ; la première peut être passée à terrain_reel.py --scene.
Dépendances : pip install rasterio numpy mgrs
"""
import argparse
import json
import re
import urllib.request

import mgrs
import numpy as np
import rasterio
from rasterio.warp import transform_bounds
from rasterio.windows import from_bounds

BASE = "https://sentinel-cogs.s3.us-west-2.amazonaws.com"


def lister(prefixe):
    url = f"{BASE}/?list-type=2&prefix={prefixe}&delimiter=/"
    with urllib.request.urlopen(url, timeout=60) as r:
        return re.findall(r"<Prefix>([^<]*)</Prefix>", r.read().decode())[1:]


def nuages_locaux(url, bbox):
    """Part de pixels très clairs (nuages) dans la zone, lue en basse résolution."""
    with rasterio.Env(GDAL_DISABLE_READDIR_ON_OPEN="EMPTY_DIR"):
        d = rasterio.open(url)
        b = transform_bounds("EPSG:4326", d.crs, *bbox)
        win = from_bounds(*b, d.transform)
        a = d.read(window=win, out_shape=(3, 120, 120)).astype(float)
    if a.size == 0 or (a.sum(0) == 0).mean() > 0.2:
        return 1.0  # zone hors de l'image
    return float((a.mean(0) > 170).mean())


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--bbox", nargs=4, type=float, required=True)
    p.add_argument("--annees", nargs="+", type=int, default=[2024, 2025])
    p.add_argument("--mois", nargs="+", type=int, default=list(range(1, 13)))
    p.add_argument("--max-tuile", type=float, default=40, help="nuages max sur la tuile entière (%%)")
    p.add_argument("--essais", type=int, default=10)
    a = p.parse_args()
    w, s, e, n = a.bbox
    tuile = mgrs.MGRS().toMGRS((s + n) / 2, (w + e) / 2, MGRSPrecision=0)
    zone, bande, carre = tuile[:2], tuile[2], tuile[3:5]
    print("tuile Sentinel-2 :", tuile)
    candidats = []
    for an in a.annees:
        for m in a.mois:
            for prod in lister(f"sentinel-s2-l2a-cogs/{zone}/{bande}/{carre}/{an}/{m}/"):
                nom = prod.rstrip("/").split("/")[-1]
                try:
                    with urllib.request.urlopen(f"{BASE}/{prod}{nom}.json", timeout=60) as r:
                        props = json.load(r)["properties"]
                except Exception:
                    continue
                if props.get("eo:cloud_cover", 100) <= a.max_tuile:
                    candidats.append((props["eo:cloud_cover"], nom, f"{BASE}/{prod}TCI.tif"))
    candidats.sort()
    res = []
    for cc, nom, url in candidats[: a.essais * 3]:
        try:
            res.append((nuages_locaux(url, a.bbox), cc, nom))
        except Exception:
            continue
    res.sort()
    for loc, cc, nom in res[: a.essais]:
        print(f"{nom}  nuages zone {loc * 100:5.1f} %   tuile {cc:5.1f} %")


if __name__ == "__main__":
    main()

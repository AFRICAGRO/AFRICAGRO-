#!/usr/bin/env python3
"""
Carte de l'Afrique RÉELLE (côtes, fleuves, lacs) découpée en pays FICTIFS.

Les frontières sont générées (cellules de Voronoï autour de « capitales » placées à la main,
puis déformées pour paraître naturelles) : elles ne suivent volontairement aucune frontière
réelle. Les côtes, fleuves et lacs viennent de Natural Earth (domaine public).

  python3 carte_afrique.py --donnees DOSSIER_NATURAL_EARTH --sortie ../carte-afrique-fictive.svg

Le dossier doit contenir (téléchargeables sur github.com/nvkelso/natural-earth-vector/geojson) :
  ne_50m_admin_0_countries.geojson, ne_50m_lakes.geojson, ne_50m_rivers_lake_centerlines.geojson
"""
import argparse
import json
import math
import os

import shapely
from shapely.geometry import MultiPoint, Point, box, shape
from shapely.ops import unary_union

# (nom, longitude, latitude de la « capitale » fictive) — noms inventés, provisoires
PAYS = [
    ("Azanor", -7, 31), ("Tafilane", 1, 28), ("Medjara", 9, 31), ("Sirtane", 18, 27),
    ("Nilora", 30, 26), ("Sahelore", -12, 19), ("Talouma", -2, 17), ("Kessora", 10, 17),
    ("Doranga", 19, 14), ("Ourouba", 31, 15), ("Amaniké", 39, 10), ("Zéphyra", 46, 6),
    ("Sounkara", -12, 11), ("Ondoré", -6, 7.5), ("WANZALA", 5, 7.5), ("Kalimbé", 12, 9),
    ("Mbérou", 20, 6), ("Boukessa", 30, 4), ("Ilémbo", 12, 0), ("Lubaya", 22, 0),
    ("Varesso", 24, -7), ("Nyassoro", 36, -1), ("Kimbara", 33, -10), ("Rumbeka", 16, -12),
    ("Tazenda", 26, -16), ("Sabéla", 18, -24), ("Sombrane", 34, -19), ("Ivuma", 26, -29),
    ("Ankarova", 47, -19),
]
COULEURS = ["#e9c46a", "#f4a261", "#a8c686", "#d4a373", "#cdb4db", "#b5c99a", "#ffd6a5",
            "#e5989b", "#bde0fe", "#c9ada7"]
BBOX = (-19, -36, 53, 38)  # ouest, sud, est, nord
LARGEUR = 900


def bruit(x, y):
    """Déformation douce et déterministe (même résultat des deux côtés d'une frontière)."""
    return (0.9 * math.sin(x * 0.55 + y * 0.31) + 0.5 * math.sin(x * 1.3 - y * 1.1 + 2.0)
            + 0.25 * math.sin(x * 3.1 + y * 2.7 + 1.0))


def deformer(geom):
    def f(coords):
        return [(x + 0.8 * bruit(x, y), y + 0.8 * bruit(y + 7, x - 3)) for x, y in coords]
    poly = shapely.segmentize(geom, 0.25)
    return shapely.Polygon(f(poly.exterior.coords))


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--donnees", required=True)
    p.add_argument("--sortie", required=True)
    a = p.parse_args()

    def charger(nom):
        with open(os.path.join(a.donnees, nom), encoding="utf-8") as fh:
            return json.load(fh)["features"]

    afrique = unary_union([shape(f["geometry"]) for f in charger("ne_50m_admin_0_countries.geojson")
                           if f["properties"].get("CONTINENT") == "Africa"]).buffer(0)
    cadre = box(*BBOX)
    lacs = [shape(f["geometry"]).intersection(afrique) for f in charger("ne_50m_lakes.geojson")]
    lacs = [g for g in lacs if not g.is_empty and g.area > 0.05]
    fleuves = [shape(f["geometry"]).intersection(afrique)
               for f in charger("ne_50m_rivers_lake_centerlines.geojson")
               if f["properties"].get("scalerank", 9) <= 5]
    fleuves = [g for g in fleuves if not g.is_empty]

    graines = MultiPoint([(lon, lat) for _, lon, lat in PAYS])
    cellules = shapely.voronoi_polygons(graines, extend_to=box(-40, -60, 80, 60))
    pays = []
    for cell in cellules.geoms:
        idx = next(i for i, (_, lon, lat) in enumerate(PAYS) if cell.contains(Point(lon, lat)))
        terr = shapely.make_valid(deformer(cell)).intersection(afrique)
        pays.append((idx, terr))

    # projection équirectangulaire corrigée à l'équateur
    w, s, e, n = BBOX
    k = LARGEUR / (e - w)
    hauteur = round((n - s) * k)

    def xy(x, y):
        return (x - w) * k, (n - y) * k

    def chemin(g):
        out = []
        for poly in getattr(g, "geoms", [g]):
            if poly.geom_type != "Polygon":
                continue
            for ring in [poly.exterior, *poly.interiors]:
                pts = [xy(*c) for c in ring.coords]
                out.append("M" + "L".join(f"{x:.1f},{y:.1f}" for x, y in pts) + "Z")
        return "".join(out)

    def ligne(g):
        out = []
        for l in getattr(g, "geoms", [g]):
            if l.geom_type == "LineString":
                out.append("M" + "L".join(f"{x:.1f},{y:.1f}" for x, y in (xy(*c) for c in l.coords)))
        return "".join(out)

    svg = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {LARGEUR} {hauteur}" '
           'font-family="Segoe UI, Arial, sans-serif">',
           "<title>Afrique réelle, pays fictifs — brouillon v0.1</title>",
           f'<rect width="{LARGEUR}" height="{hauteur}" fill="#2f6f99"/>']
    for idx, g in pays:
        nom = PAYS[idx][0]
        coul = "#c0392b" if nom == "WANZALA" else COULEURS[idx % len(COULEURS)]
        svg.append(f'<path d="{chemin(g)}" fill="{coul}" stroke="#fff" stroke-width="1.2" '
                   f'stroke-linejoin="round"><title>{nom}</title></path>')
    svg.append(f'<path d="{"".join(ligne(r) for r in fleuves)}" fill="none" stroke="#3a86b4" '
               'stroke-width="1.3" stroke-linecap="round"/>')
    svg.append(f'<path d="{"".join(chemin(l) for l in lacs)}" fill="#3a86b4"/>')
    svg.append(f'<path d="{chemin(afrique)}" fill="none" stroke="#173d55" stroke-width="1.4"/>')

    for idx, g in pays:
        nom = PAYS[idx][0]
        c = g.representative_point() if nom != "WANZALA" else Point(PAYS[idx][1], PAYS[idx][2])
        x, y = xy(c.x, c.y)
        grand = nom == "WANZALA"
        svg.append(f'<text x="{x:.0f}" y="{y:.0f}" text-anchor="middle" font-size="{15 if grand else 11}" '
                   f'font-weight="{800 if grand else 600}" fill="{"#fff" if grand else "#2b2b2b"}" '
                   f'stroke="{"#7a1f16" if grand else "none"}" stroke-width="{3 if grand else 0}" '
                   f'paint-order="stroke">{nom}</text>')

    # île de départ (position fictive au large de Wanzala)
    ix, iy = xy(4.2, 3.2)
    svg.append(f'<circle cx="{ix:.0f}" cy="{iy:.0f}" r="5" fill="#ffd60a" stroke="#000"/>'
               f'<text x="{ix - 8:.0f}" y="{iy + 20:.0f}" font-size="12" font-weight="700" fill="#fff" '
               f'text-anchor="middle">Île de Talanké</text>')
    svg.append(f'<text x="20" y="{hauteur - 70}" font-size="22" font-weight="800" fill="#fff">AFRIQUE</text>'
               f'<text x="20" y="{hauteur - 46}" font-size="22" font-weight="800" fill="#fff">PAYS FICTIFS</text>'
               f'<text x="20" y="{hauteur - 26}" font-size="11" fill="#dbeefa">Côtes, fleuves, lacs réels (Natural Earth)</text>'
               f'<text x="20" y="{hauteur - 11}" font-size="11" fill="#dbeefa">Frontières et noms inventés · v0.1</text>')
    svg.append("</svg>")
    with open(a.sortie, "w", encoding="utf-8") as fh:
        fh.write("\n".join(svg))
    print("écrit :", a.sortie, f"({len(pays)} pays)")


if __name__ == "__main__":
    main()

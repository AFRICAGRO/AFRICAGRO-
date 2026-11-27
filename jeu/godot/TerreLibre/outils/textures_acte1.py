"""Images de la fin de l'acte 1 (missions 1 et 12), dessinées par programme :
- data/textures/affiche_cobra.png  : l'affiche du Front du Cobra collée sur la fresque (Port-Néré occupée)
- data/textures/fresque_samuel.png : la fresque repeinte de la coopérative, Samuel au centre, et dans un coin,
                                     Faris dessiné par un enfant (Port-Néré libérée)
- data/textures/fin_acte1.png      : la carte de fin d'acte (à partir de jeu/carte-afrique-fictive.svg) :
                                     l'île de Talanké aux couleurs des Racines, Wanzala en gris
Usage : python3 outils/textures_acte1.py  (depuis la racine du projet Godot)
"""
import math
import os
import re
import subprocess

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

rng = np.random.default_rng(12)
POLICE_GRASSE = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
POLICE = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
VERT, OR, LATERITE = (47, 107, 52), (232, 178, 58), (181, 83, 42)


def police(taille, grasse=True):
    return ImageFont.truetype(POLICE_GRASSE if grasse else POLICE, taille)


def grain(img, force=18):
    """Grain de peinture murale : bruit + légères coulures."""
    a = np.asarray(img).astype(np.int16)
    a += rng.integers(-force, force + 1, a.shape[:2])[..., None]
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


def affiche():
    w, h = 512, 720
    img = Image.new("RGB", (w, h), (24, 18, 16))
    d = ImageDraw.Draw(img)
    d.rectangle([18, 18, w - 18, h - 18], outline=(170, 30, 24), width=10)
    # le serpent enroulé : une spirale épaisse, la tête dressée
    pts = []
    for i in range(260):
        t = i / 259 * 3.2 * math.pi
        r = 150 - t * 11
        pts.append((w / 2 + r * math.cos(t), 300 + r * 0.62 * math.sin(t)))
    d.line(pts, fill=(170, 30, 24), width=30, joint="curve")
    tete = pts[0]
    d.ellipse([tete[0] - 30, tete[1] - 64, tete[0] + 30, tete[1] - 14], fill=(170, 30, 24))
    d.line([tete, (tete[0], tete[1] - 30)], fill=(170, 30, 24), width=30)
    d.ellipse([tete[0] - 12, tete[1] - 52, tete[0] - 2, tete[1] - 42], fill=(240, 200, 60))
    d.ellipse([tete[0] + 2, tete[1] - 52, tete[0] + 12, tete[1] - 42], fill=(240, 200, 60))
    for i, (t, f, y) in enumerate([("FRONT DU COBRA", police(44), 500), ("ORDRE · TRAVAIL · OBÉISSANCE", police(26), 572),
                                   ("Couvre-feu à 19 h. Tout contrevenant sera abattu.", police(19, False), 630)]):
        l = d.textlength(t, font=f)
        d.text(((w - l) / 2, y), t, font=f, fill=(235, 225, 210) if i != 0 else (220, 40, 30))
    img = grain(img, 14)
    # bords déchirés et coin arraché
    masque = Image.new("L", (w, h), 255)
    md = ImageDraw.Draw(masque)
    for x in range(0, w, 6):
        md.rectangle([x, 0, x + 6, int(rng.integers(0, 12))], fill=0)
        md.rectangle([x, h - int(rng.integers(0, 14)), x + 6, h], fill=0)
    md.polygon([(w, 0), (w - 120, 0), (w, 90)], fill=0)
    img.putalpha(masque)
    img.save("data/textures/affiche_cobra.png")


def fresque():
    w, h = 1600, 500
    img = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(img)
    # ciel de l'aube et soleil levant
    for y in range(h):
        t = y / h
        c = (int(250 - 40 * t), int(170 + 40 * t), int(90 + 60 * t))
        d.line([(0, y), (w, y)], fill=c)
    d.ellipse([w / 2 - 170, 120, w / 2 + 170, 460], fill=(250, 210, 90))
    # collines et rangées de champs
    for k, (base, coul) in enumerate([(320, (70, 130, 60)), (360, VERT), (400, (90, 70, 40))]):
        pts = [(0, h)] + [(x, base + 25 * math.sin(x / 140 + k)) for x in range(0, w + 20, 20)] + [(w, h)]
        d.polygon(pts, fill=coul)
    for i in range(14):
        x0 = 80 + i * 110
        d.line([(x0, h), (w / 2 + (x0 - w / 2) * 0.35, 380)], fill=(60, 45, 25), width=5)
    # Samuel au centre : chapeau de paille, la houe levée vers le soleil
    cx, sol = w / 2, 445
    peau, chemise = (92, 58, 38), (232, 178, 58)
    d.rectangle([cx - 34, sol - 200, cx + 34, sol - 80], fill=chemise)              # torse
    d.rectangle([cx - 30, sol - 82, cx - 6, sol], fill=(60, 50, 40))               # jambes
    d.rectangle([cx + 6, sol - 82, cx + 30, sol], fill=(60, 50, 40))
    d.ellipse([cx - 26, sol - 262, cx + 26, sol - 202], fill=peau)                  # tête
    d.ellipse([cx - 62, sol - 252, cx + 62, sol - 230], fill=(214, 180, 100))       # bord du chapeau
    d.ellipse([cx - 30, sol - 282, cx + 30, sol - 238], fill=(214, 180, 100))
    d.line([(cx + 30, sol - 190), (cx + 92, sol - 300)], fill=peau, width=20)      # bras levé
    d.line([(cx + 70, sol - 250), (cx + 135, sol - 330)], fill=(110, 80, 50), width=10)   # manche de la houe
    d.polygon([(cx + 128, sol - 346), (cx + 172, sol - 326), (cx + 136, sol - 312)], fill=(150, 150, 150))
    d.line([(cx - 30, sol - 190), (cx - 70, sol - 120)], fill=peau, width=20)
    # les familles de la coopérative, de part et d'autre
    for s in (-1, 1):
        for i in range(3):
            x = cx + s * (230 + i * 150)
            hh = 150 - (i % 2) * 25
            d.rectangle([x - 22, sol - hh, x + 22, sol - 45], fill=[VERT, LATERITE, (60, 90, 160), (200, 80, 120)][i])
            d.ellipse([x - 18, sol - hh - 40, x + 18, sol - hh], fill=peau)
            d.ellipse([x - 40, sol - hh - 70, x + 40, sol - hh - 38], fill=(240, 200, 100) if i % 2 == 0 else (90, 140, 70))  # panier sur la tête
            d.rectangle([x - 18, sol - 46, x + 18, sol], fill=(70, 55, 40))
    # le proverbe, en lettres peintes
    f = police(58)
    t = "ZALA KA WAN, WAN KA ZALA"
    l = d.textlength(t, font=f)
    d.text(((w - l) / 2 + 3, 26 + 3), t, font=f, fill=(40, 30, 20))
    d.text(((w - l) / 2, 26), t, font=f, fill=(255, 246, 220))
    f2 = police(26, False)
    t2 = "La terre est à tous, et tous sont à la terre — Coopérative de Port-Néré, fondée par Samuel"
    d.text(((w - d.textlength(t2, font=f2)) / 2, 458), t2, font=f2, fill=(245, 235, 210))   # au pied de la fresque, sur la terre
    img = grain(img, 16)
    # dans le coin, au crayon gras : Faris, dessiné par un enfant
    d = ImageDraw.Draw(img)
    x0, y0 = 1490, 470
    craie = (250, 250, 245)            # craie blanche, bien visible sur la terre
    d.ellipse([x0 - 14, y0 - 118, x0 + 14, y0 - 90], outline=craie, width=4)
    d.line([(x0, y0 - 90), (x0 + 2, y0 - 40)], fill=craie, width=4)
    d.line([(x0 + 2, y0 - 40), (x0 - 16, y0 - 4)], fill=craie, width=4)
    d.line([(x0 + 2, y0 - 40), (x0 + 18, y0 - 6)], fill=craie, width=4)
    d.line([(x0 - 22, y0 - 74), (x0 + 26, y0 - 80)], fill=craie, width=4)
    d.arc([x0 - 8, y0 - 110, x0 + 8, y0 - 96], 20, 160, fill=craie, width=3)       # sourire
    fx = 1436
    for i, c in enumerate("FARIS"):
        d.text((fx + i * 22, 312 + (i % 2) * 6), c, font=police(26), fill=(200, 30, 30))
    img.save("data/textures/fresque_samuel.png")


def carte_fin():
    src = open("../../carte-afrique-fictive.svg", encoding="utf-8").read()
    # Wanzala : encore gris (le continent reste à libérer)
    src = src.replace('fill="#c0392b" stroke="#fff" stroke-width="1.2" stroke-linejoin="round"><title>WANZALA',
                      'fill="#7b7b7b" stroke="#fff" stroke-width="1.2" stroke-linejoin="round"><title>WANZALA')
    src = src.replace('stroke="#7a1f16" stroke-width="3" paint-order="stroke">WANZALA', 'stroke="#333" stroke-width="3" paint-order="stroke">WANZALA')
    # l'île : un disque aux couleurs des Racines (vert, liseré or)
    src = re.sub(r'<circle cx="290" cy="435" r="5" fill="#ffd60a" stroke="#000"/>',
                 '<circle cx="290" cy="435" r="9" fill="#2f6b34" stroke="#e8b23a" stroke-width="2.5"/>', src)
    src = src.replace('viewBox="0 0 900 925"', 'viewBox="190 285 230 185"')
    src = src.replace('>Île de Talanké<', '><')      # notre propre étiquette la remplace
    open("/tmp/fin_acte1.svg", "w", encoding="utf-8").write(src)
    subprocess.run(["rsvg-convert", "-w", "1280", "/tmp/fin_acte1.svg", "-o", "/tmp/fin_acte1_brut.png"], check=True)
    img = Image.open("/tmp/fin_acte1_brut.png").convert("RGB")
    d = ImageDraw.Draw(img)
    w, h = img.size
    # (290,435) dans le viewBox -> pixels
    ix, iy = (290 - 190) / 230 * w, (435 - 285) / 185 * h
    for r in (60, 44):
        d.ellipse([ix - r, iy - r, ix + r, iy + r], outline=OR, width=4)
    f = police(34)
    d.text((ix + 70, iy - 20), "Île de Talanké — libérée", font=f, fill=(255, 255, 255), stroke_width=4, stroke_fill=VERT)
    d.text((ix + 70, iy + 22), "Acte 2 : Lagunaville, sur le continent", font=police(24, False), fill=(240, 240, 240), stroke_width=3, stroke_fill=(30, 30, 30))
    img.save("data/textures/fin_acte1.png")


if __name__ == "__main__":
    os.makedirs("data/textures", exist_ok=True)
    affiche()
    fresque()
    carte_fin()
    print("ok")

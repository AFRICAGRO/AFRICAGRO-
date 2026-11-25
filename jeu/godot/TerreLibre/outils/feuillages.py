"""Textures de végétation pour les arbres proches, buissons et herbes.
Feuilles détourées depuis la planche de feuilles de « island_tree_01 » (Poly Haven, CC0),
assemblées en rameaux ; herbes dessinées par programme."""
import math, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

SRC = "/tmp/imp/island_tree_01/textures/"
DST = "/home/claude/godot/TerreLibre/data/vegetation/"
rng = random.Random(5)

planche = Image.open(SRC + "island_tree_01_leaves_diff_1k.jpg").convert("RGB")
a = np.asarray(planche).astype(np.float32)
masque = a.max(axis=2) > 28
lab, n = ndimage.label(masque)
feuilles = []
for sl in ndimage.find_objects(lab):
    h = sl[0].stop - sl[0].start
    w = sl[1].stop - sl[1].start
    if h < 80 or w < 25:
        continue
    crop = a[sl]
    m = (lab[sl] > 0).astype(np.float32)
    m = ndimage.gaussian_filter(m, 0.8)
    rgba = np.dstack([crop, np.clip(m * 255 * 1.4, 0, 255)]).astype(np.uint8)
    feuilles.append(Image.fromarray(rgba, "RGBA"))
print("feuilles :", len(feuilles))


def rameau(taille, teinte, echelle, nb, graine):
    r = random.Random(graine)
    im = Image.new("RGBA", (taille, taille), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # tige principale qui monte en s'incurvant
    pts = [(taille * 0.5 + 18 * math.sin(t * 2.2) * (t), taille * (0.98 - 0.9 * t)) for t in np.linspace(0, 1, 30)]
    for k in range(len(pts) - 1):
        wd = max(1, int(5 * (1 - k / len(pts))))
        d.line([pts[k], pts[k + 1]], fill=(70, 58, 40, 255), width=wd)
    for i in range(nb):
        t = 0.12 + 0.88 * i / nb
        x, y = pts[int(t * (len(pts) - 1))]
        f = feuilles[r.randrange(len(feuilles))]
        s = echelle * r.uniform(0.75, 1.1) * (1.0 - 0.35 * t)
        f2 = f.resize((max(2, int(f.width * s)), max(2, int(f.height * s))), Image.LANCZOS)
        cote = -1 if i % 2 == 0 else 1
        ang = cote * r.uniform(35, 75) + r.uniform(-10, 10)
        if i == nb - 1:
            ang = r.uniform(-12, 12)
        f2 = f2.rotate(ang, resample=Image.BICUBIC, expand=True)
        # la feuille part du rameau : on décale vers le côté où elle penche
        dx = -math.sin(math.radians(ang)) * f2.height * 0.32
        dy = -math.cos(math.radians(ang)) * f2.height * 0.32
        im.alpha_composite(f2, (int(x + dx - f2.width / 2), int(y + dy - f2.height / 2)))
    arr = np.asarray(im).astype(np.float32)
    arr[..., :3] *= np.array(teinte, dtype=np.float32)
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")


for nom, teinte, echelle, nb in [("rameau_clair", (0.74, 0.93, 0.6), 0.42, 22), ("rameau_sombre", (0.55, 0.74, 0.55), 0.32, 30)]:
    atlas = Image.new("RGBA", (1024, 512), (0, 0, 0, 0))
    for v in range(2):
        atlas.alpha_composite(rameau(512, teinte, echelle * (1.0 if v == 0 else 0.9), nb, hash(nom) + v), (v * 512, 0))
    # bords transparents : on « étale » la couleur sous l'alpha pour éviter les liserés noirs (mipmaps)
    arr = np.asarray(atlas).astype(np.float32)
    al = arr[..., 3:4] / 255.0
    flou = np.asarray(atlas.convert("RGB").filter(ImageFilter.GaussianBlur(6))).astype(np.float32)
    poids = np.asarray(Image.fromarray((al[..., 0] * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(6))).astype(np.float32)[..., None] / 255.0
    fond = flou / np.maximum(poids, 0.02)
    arr[..., :3] = arr[..., :3] * al + np.clip(fond, 0, 255) * (1 - al)
    Image.fromarray(arr.astype(np.uint8), "RGBA").save(DST + nom + ".png")
    print(nom)

# herbes : touffes de brins effilés, verts et secs
def herbe(sec):
    r = random.Random(11 if sec else 12)
    im = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for i in range(95):
        # brins partant d'un pied commun, de hauteurs très inégales (silhouette irrégulière)
        x0 = 256 + r.gauss(0, 60)
        h = 512 * min(0.97, r.betavariate(2.2, 2.0))
        pench = (x0 - 256) * 1.2 + r.uniform(-70, 70)
        w = r.uniform(3, 7)
        if sec:
            c = (int(r.uniform(140, 190)), int(r.uniform(125, 160)), int(r.uniform(70, 95)))
        else:
            c = (int(r.uniform(70, 115)), int(r.uniform(105, 140)), int(r.uniform(40, 62)))
        pts_g, pts_d = [], []
        for t in np.linspace(0, 1, 12):
            x = x0 + pench * t * t
            y = 511 - h * t
            ww = w * (1 - t) + 0.3
            pts_g.append((x - ww, y))
            pts_d.append((x + ww, y))
        d.polygon(pts_g + pts_d[::-1], fill=c + (255,))
    arr = np.asarray(im).astype(np.float32)
    arr[..., :3] *= np.linspace(1.1, 0.5, 512)[:, None, None]
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")

atlas = Image.new("RGBA", (1024, 512), (0, 0, 0, 0))
atlas.alpha_composite(herbe(False), (0, 0))
atlas.alpha_composite(herbe(True), (512, 0))
atlas.save(DST + "herbes.png")
for s, d in [("island_tree_01_branches_diff_1k.jpg", "ecorce_diff.jpg"), ("island_tree_01_branches_nor_gl_1k.jpg", "ecorce_nor.jpg")]:
    Image.open(SRC + s).convert("RGB").resize((512, 512), Image.LANCZOS).save(DST + d, quality=88)
print("FINI")

# litière : feuilles mortes et brindilles éparses, posées à plat sous les arbres
def litiere(graine):
    r = random.Random(graine)
    im = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for i in range(14):  # brindilles
        x, y = r.uniform(40, 472), r.uniform(40, 472)
        a = r.uniform(0, math.pi)
        l = r.uniform(40, 130)
        d.line([(x, y), (x + math.cos(a) * l, y + math.sin(a) * l)], fill=(70, 52, 35, 255), width=r.randint(2, 4))
    for i in range(70):
        f = feuilles[r.randrange(len(feuilles))]
        s = r.uniform(0.18, 0.32)
        f2 = f.resize((max(2, int(f.width * s)), max(2, int(f.height * s))), Image.LANCZOS).rotate(r.uniform(0, 360), resample=Image.BICUBIC, expand=True)
        arr = np.asarray(f2).astype(np.float32)
        lum = arr[..., :3].mean(axis=2, keepdims=True)
        brun = np.array([r.uniform(0.8, 1.05), r.uniform(0.42, 0.58), r.uniform(0.2, 0.3)], dtype=np.float32)
        arr[..., :3] = np.clip(lum * brun * 1.25, 0, 255)
        f2 = Image.fromarray(arr.astype(np.uint8), "RGBA")
        # densité plus forte au centre, éparse sur les bords (raccord invisible avec le sol)
        rr = 220 * math.sqrt(r.random())
        t = r.uniform(0, 2 * math.pi)
        im.alpha_composite(f2, (int(256 + rr * math.cos(t) - f2.width / 2), int(256 + rr * math.sin(t) - f2.height / 2)))
    return im

atlas = Image.new("RGBA", (1024, 512), (0, 0, 0, 0))
atlas.alpha_composite(litiere(1), (0, 0))
atlas.alpha_composite(litiere(2), (512, 0))
atlas.save(DST + "litiere.png")
print("litiere")

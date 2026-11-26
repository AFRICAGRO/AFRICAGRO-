"""Textures originales créées par programme (aucune image tierce) :
- data/textures/roseaux_diff.jpg / roseaux_nor.jpg : mur de roseaux serrés, liés par des cordes tous les 40 cm
  (1 m x 1 m de mur, répétable) ;
- data/vegetation/banane.png : feuille de bananier (nervure centrale, nervures parallèles, bords déchirés par le vent),
  avec transparence ; la feuille occupe toute l'image dans le sens de la longueur (bas = pétiole)."""
import numpy as np
from PIL import Image, ImageFilter

rng = np.random.default_rng(26)
DST = "/home/claude/godot/TerreLibre/data/"

# ---------------- roseaux ----------------
N = 512
h = np.zeros((N, N))
col = np.zeros((N, N, 3))
x = 0
while x < N:
    w = int(rng.integers(7, 12))  # tige de 1,4 à 2,3 cm
    u = np.linspace(-1, 1, w)
    profil = np.sqrt(np.clip(1 - u ** 2, 0, 1))
    teinte = np.array([0.66, 0.56, 0.38]) * rng.uniform(0.75, 1.1) + rng.uniform(-0.04, 0.04, 3)
    # noeuds des roseaux, à hauteur variable
    noeuds = rng.uniform(0, N, 3)
    for i in range(w):
        if x + i >= N:
            break
        h[:, x + i] = profil[i]
        y = np.arange(N)
        bande = np.ones(N)
        for n0 in noeuds:
            bande -= 0.25 * np.exp(-((y - n0) % N) ** 2 / 8.0)
        strie = 1.0 + 0.08 * np.sin(y * rng.uniform(0.05, 0.12) + rng.uniform(0, 6))
        col[:, x + i] = teinte[None, :] * (0.55 + 0.45 * profil[i]) * (bande * strie)[:, None]
    x += w
# cordes horizontales tous les 40 cm (205 px), en fibre sombre torsadée
for y0 in (100, 305):
    for dy in range(-6, 7):
        y = (y0 + dy) % N
        torsade = 0.5 + 0.5 * np.sin(np.arange(N) * 0.6 + dy * 0.9)
        prof = np.sqrt(max(0.0, 1 - (dy / 6.5) ** 2))
        h[y, :] = 1.2 * prof
        col[y, :] = np.array([0.32, 0.25, 0.16])[None, :] * (0.6 + 0.4 * torsade[:, None]) * (0.6 + 0.4 * prof)
# saleté au pied et grain
grain = rng.normal(0, 0.03, (N, N, 1))
col = np.clip(col + grain, 0, 1)
Image.fromarray((col * 255).astype(np.uint8)).save(DST + "textures/roseaux_diff.jpg", quality=90)
gx = np.roll(h, -1, 1) - np.roll(h, 1, 1)
gy = np.roll(h, -1, 0) - np.roll(h, 1, 0)
n = np.dstack([-gx * 2.0, gy * 2.0, np.ones_like(h)])
n /= np.linalg.norm(n, axis=2, keepdims=True)
Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8)).save(DST + "textures/roseaux_nor.jpg", quality=92)
print("roseaux ok")

# ---------------- feuille de bananier ----------------
W, H = 256, 1024
img = np.zeros((H, W, 4))
yy, xx = np.mgrid[0:H, 0:W]
t = yy / (H - 1)            # 0 = pointe, 1 = pétiole
u = (xx - W / 2) / (W / 2)  # -1 .. 1 en travers
# contour : feuille oblongue, pointe arrondie, base qui se resserre
demi = np.clip(np.sin(np.pi * np.clip(t * 1.02, 0, 1)) ** 0.35, 0, 1) * 0.96
demi = np.where(t > 0.9, demi * (1 - (t - 0.9) / 0.1 * 0.85), demi)
dans = np.abs(u) < demi
# déchirures du vent : fentes fines qui suivent les nervures obliques, du bord vers la nervure centrale
pente = 0.45   # les nervures montent vers la pointe en s'éloignant du milieu
for k in range(46):
    y0 = rng.uniform(H * 0.08, H * 0.95)
    d = rng.uniform(0.25, 1.0) if rng.uniform() < 0.7 else rng.uniform(0.85, 1.0)
    cote = 1 if rng.uniform() < 0.5 else -1
    ligne = y0 - np.abs(u) * (W / 2) * pente
    fente = (np.sign(u) == cote) & (np.abs(u) > demi * (1 - d)) & (np.abs(u) > 0.05) & (np.abs(yy - ligne) < rng.uniform(0.7, 1.6))
    dans &= ~fente
# bout de la pointe un peu effiloché
dans &= ~((t < 0.06) & (rng.uniform(size=(H, W)) < 0.15))
vert = np.array([0.22, 0.45, 0.12])
clair = np.array([0.42, 0.62, 0.2])
nerv = 0.5 + 0.5 * np.cos((yy + np.abs(u) * (W / 2) * pente) * 0.9)  # nervures parallèles obliques
couleur = vert[None, None, :] * (0.85 + 0.15 * nerv[..., None]) + (clair - vert)[None, None, :] * (np.abs(u) ** 0.5)[..., None] * 0.35
centrale = np.abs(u) < 0.035
couleur[centrale] = np.array([0.6, 0.68, 0.32])
# bords secs et taches brunes de vieillesse
bord = (np.abs(u) > demi * 0.86) & dans
couleur[bord] = couleur[bord] * 0.6 + np.array([0.45, 0.35, 0.15]) * 0.4
for k in range(14):
    cy, cx = rng.uniform(0, H), rng.uniform(0, W)
    r = rng.uniform(5, 18)
    tache = (yy - cy) ** 2 + (xx - cx) ** 2 < r ** 2
    couleur[tache] = couleur[tache] * 0.55 + np.array([0.38, 0.3, 0.12]) * 0.45
img[..., :3] = np.clip(couleur + rng.normal(0, 0.015, couleur.shape), 0, 1)
img[..., 3] = dans.astype(float)
Image.fromarray((img * 255).astype(np.uint8), "RGBA").filter(ImageFilter.SMOOTH).save(DST + "vegetation/banane.png")
print("banane ok")

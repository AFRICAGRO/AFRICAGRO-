"""Ombrage du relief pour la carte du jeu (data/carte_ombre.png), calculé une fois pour toutes
à partir de data/talanke_505.f32 : lumière du nord-ouest, versants à l'ombre assombris, mer transparente."""
import numpy as np
from PIL import Image

N, TAILLE = 505, 5383.0
h = np.fromfile("data/talanke_505.f32", dtype=np.float32).reshape(N, N)
pas = TAILLE / (N - 1)
dz, dx = np.gradient(h, pas)
nor = np.dstack([-dx * 2.5, np.ones_like(h), -dz * 2.5])
nor /= np.linalg.norm(nor, axis=2, keepdims=True)
lum = np.array([-0.6, 0.65, -0.45]); lum /= np.linalg.norm(lum)
e = np.clip(nor @ lum, 0, 1)
a = np.clip((0.82 - e) * 1.1, 0, 0.6)
a[h <= 0] = 0
img = np.zeros((N, N, 4), np.uint8)
img[..., 0], img[..., 1], img[..., 2] = 13, 10, 15
img[..., 3] = (a * 255).astype(np.uint8)
Image.fromarray(img, "RGBA").resize((1010, 1010), Image.BICUBIC).save("data/carte_ombre.png")
print("ok")

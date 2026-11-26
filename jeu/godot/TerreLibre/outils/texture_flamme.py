"""Texture de flamme (data/textures/flamme.png) : langue de feu en goutte, cœur presque blanc,
bords orangés, transparence douce et fines ondulations. Utilisée en additif par les particules."""
import numpy as np
from PIL import Image
W, H = 128, 256
y, x = np.mgrid[0:H, 0:W].astype(float)
u = (x - W / 2) / (W / 2)            # -1..1
v = 1.0 - y / H                      # 0 en bas, 1 en haut
rng = np.random.default_rng(3)
ond = 0.12 * np.sin(v * 9.0 + 1.3) + 0.06 * np.sin(v * 23.0)
largeur = 0.95 * np.clip(np.sin(np.pi * np.clip(v * 1.15, 0, 1)) ** 0.7 * (1.0 - v * 0.75), 0, 1)
d = np.abs(u - ond * v) / np.maximum(largeur, 1e-3)
forme = np.clip(1.0 - d, 0, 1) ** 1.3 * np.clip((1.0 - v) * 1.6, 0, 1) * np.clip(v * 8.0, 0, 1)
coeur = np.clip(1.0 - d * 1.8, 0, 1) ** 2 * np.clip(1.0 - v * 1.4, 0, 1)
r = np.clip(forme * 1.2 + coeur, 0, 1)
g = np.clip(forme * 0.55 + coeur * 0.9, 0, 1)
b = np.clip(forme * 0.12 + coeur * 0.65, 0, 1)
a = np.clip(forme * 1.1, 0, 1)
img = (np.dstack([r, g, b, a]) * 255).astype(np.uint8)
Image.fromarray(img, "RGBA").save("data/textures/flamme.png")
print("ok")

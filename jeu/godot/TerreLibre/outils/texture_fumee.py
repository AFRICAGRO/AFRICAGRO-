"""Bouffée de fumée douce (data/textures/fumee_douce.png) : disque flou bosselé, transparent sur les bords."""
import numpy as np
from PIL import Image, ImageFilter
N = 128
y, x = np.mgrid[0:N, 0:N].astype(float)
u, v = (x - N / 2) / (N / 2), (y - N / 2) / (N / 2)
r = np.sqrt(u * u + v * v)
a = np.arctan2(v, u)
rng = np.random.default_rng(5)
bosses = 0.12 * np.sin(a * 5 + 1.0) + 0.08 * np.sin(a * 9 + 2.0)
alpha = np.clip(1.0 - r / (0.85 + bosses), 0, 1) ** 1.6
bruit = rng.random((N // 8, N // 8))
bruit = np.array(Image.fromarray((bruit * 255).astype(np.uint8)).resize((N, N), Image.BICUBIC)) / 255.0
alpha *= 0.65 + 0.35 * bruit
img = np.dstack([np.full((N, N), 235), np.full((N, N), 235), np.full((N, N), 235), alpha * 255]).astype(np.uint8)
Image.fromarray(img, "RGBA").filter(ImageFilter.GaussianBlur(1.5)).save("data/textures/fumee_douce.png")
print("ok")

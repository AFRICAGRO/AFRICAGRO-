"""Textures originales du cheval (créées par programme) :
- poil_diff.jpg / poil_nor.jpg : grain du poil ras (fines stries orientées, répétables), multiplie la robe ;
- meche.png : mèche de crins (brins fins, plus clairs aux pointes) avec transparence, pour la crinière et la queue."""
import numpy as np
from PIL import Image, ImageFilter
rng = np.random.default_rng(11)
N = 512
# grain du poil : bruit étiré dans une direction (poils couchés), répété sans couture
b = rng.normal(size=(N, N))
f = np.fft.fft2(b)
ky, kx = np.meshgrid(np.fft.fftfreq(N), np.fft.fftfreq(N), indexing="ij")
filtre = np.exp(-((kx * 6.0) ** 2 + (ky * 0.9) ** 2) * 900)  # long en y, fin en x
h = np.real(np.fft.ifft2(f * filtre))
h = (h - h.min()) / (h.max() - h.min())
# reflets : bandes de lumière irrégulières (poil brillant)
lum = 0.86 + 0.14 * h
Image.fromarray((np.dstack([lum, lum, lum]) * 255).astype(np.uint8)).save("/home/claude/kofi/poil_diff.jpg", quality=92)
gx = np.roll(h, -1, 1) - np.roll(h, 1, 1)
gy = np.roll(h, -1, 0) - np.roll(h, 1, 0)
n = np.dstack([-gx * 3.0, gy * 3.0, np.ones_like(h)])
n /= np.linalg.norm(n, axis=2, keepdims=True)
Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8)).save("/home/claude/kofi/poil_nor.jpg", quality=92)

# mèche de crins : 256 x 1024, la racine en haut, les pointes en bas
W, H = 256, 1024
img = np.zeros((H, W, 4))
for k in range(170):
    x0 = rng.uniform(8, W - 8)
    longueur = rng.uniform(0.65, 1.0) * H
    ondule = rng.uniform(2, 9)
    phase = rng.uniform(0, 6.28)
    larg = rng.uniform(0.8, 2.2)
    teinte = rng.uniform(0.55, 1.0)
    for y in range(int(longueur)):
        t = y / longueur
        x = x0 + ondule * np.sin(t * 3.2 + phase) + t * rng.uniform(-0.04, 0.04) * 60
        w = larg * (1 - 0.7 * t)
        xi0, xi1 = int(max(0, x - w - 1)), int(min(W - 1, x + w + 1))
        for xi in range(xi0, xi1 + 1):
            a = max(0.0, 1 - abs(xi - x) / (w + 0.5)) * (1 - t ** 3)
            if a > img[y, xi, 3]:
                c = teinte * (0.75 + 0.25 * t)  # pointes un peu plus claires (décolorées)
                img[y, xi] = [c, c, c, a]
Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8), "RGBA").save("/home/claude/kofi/meche.png")
print("textures cheval ok")

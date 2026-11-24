"""Motifs wax originaux, tuilables 1024 px (création procédurale, aucun motif existant copié)."""
import math, random
from PIL import Image, ImageDraw, ImageFilter
import numpy as np
S = 1024
def grain(im, seed):
    rng = np.random.default_rng(seed)
    a = np.asarray(im).astype(np.float32)
    n = rng.normal(0, 7, (S, S, 1))
    # légère variation d'encre (aspect imprimé)
    b = Image.fromarray(rng.normal(0, 1, (64, 64)).astype(np.float32) * 40 + 128).convert("L").resize((S, S), Image.BICUBIC)
    a = a * (0.93 + 0.07 * np.asarray(b)[..., None] / 255) + n
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))
def tuile(draw_fn, fond):
    im = Image.new("RGB", (S, S), fond)
    d = ImageDraw.Draw(im)
    for ox in (-S, 0, S):
        for oy in (-S, 0, S):
            draw_fn(d, ox, oy)
    return im
def cercles(pal, fond):
    def f(d, ox, oy):
        for i in range(4):
            for j in range(4):
                cx, cy = ox + i * 256 + (128 if j % 2 else 0), oy + j * 256 + 128
                for k, r in enumerate([118, 96, 74, 52, 30, 12]):
                    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=pal[k % len(pal)])
    return f
def losanges(pal, fond):
    def f(d, ox, oy):
        for i in range(5):
            for j in range(5):
                cx, cy = ox + i * 256, oy + j * 256
                for k, r in enumerate([128, 100, 70, 40]):
                    d.polygon([(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)], fill=pal[k % len(pal)])
                d.ellipse([cx + 108, cy + 108, cx + 148, cy + 148], fill=pal[-1])
    return f
def bandes(pal, fond):
    def f(d, ox, oy):
        for j in range(8):
            y = oy + j * 128
            d.rectangle([ox, y, ox + S, y + 40], fill=pal[j % 2])
            for i in range(16):
                x = ox + i * 64 + (32 if j % 2 else 0)
                d.ellipse([x - 14, y + 70, x + 14, y + 98], fill=pal[2])
                d.ellipse([x - 6, y + 78, x + 6, y + 90], fill=pal[3])
    return f
def feuilles(pal, fond):
    def f(d, ox, oy):
        rng = random.Random(7)
        for i in range(4):
            for j in range(4):
                cx, cy = ox + i * 256 + 128, oy + j * 256 + 128
                a0 = (i + j) % 2 * math.pi / 4
                for k in range(6):
                    a = a0 + k * math.pi / 3
                    pts = []
                    for t in np.linspace(0, 1, 14):
                        w = math.sin(t * math.pi) * 26
                        r = 20 + t * 96
                        pts.append((cx + r * math.cos(a) - w * math.sin(a), cy + r * math.sin(a) + w * math.cos(a)))
                    for t in np.linspace(1, 0, 14):
                        w = -math.sin(t * math.pi) * 26
                        r = 20 + t * 96
                        pts.append((cx + r * math.cos(a) - w * math.sin(a), cy + r * math.sin(a) + w * math.cos(a)))
                    d.polygon(pts, fill=pal[k % 2])
                d.ellipse([cx - 22, cy - 22, cx + 22, cy + 22], fill=pal[2])
    return f
motifs = {
  "wax_cercles_vert": (cercles, [(20, 110, 70), (240, 190, 40), (150, 30, 35), (245, 235, 210)], (30, 40, 90)),
  "wax_losanges_ocre": (losanges, [(200, 110, 30), (60, 30, 20), (230, 200, 120), (20, 90, 110)], (110, 25, 30)),
  "wax_bandes_indigo": (bandes, [(25, 35, 90), (200, 160, 60), (230, 90, 30), (245, 240, 225)], (235, 225, 200)),
  "wax_feuilles_rouge": (feuilles, [(25, 85, 45), (230, 170, 35), (245, 235, 215)], (150, 25, 30)),
}
for nom, (fn, pal, fond) in motifs.items():
    im = tuile(fn(pal, fond), fond).filter(ImageFilter.GaussianBlur(0.8))
    grain(im, hash(nom) % 1000).save(f"/home/claude/faris/tex/{nom}.jpg", quality=90)
    print(nom)

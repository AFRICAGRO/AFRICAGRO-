"""Motif original du tapis de selle : bordure en chevrons, losanges emboîtés, rangs de perles (rouge, or, indigo)."""
import numpy as np
from PIL import Image
W, H = 512, 512   # x = travers (côté droit -> gauche), y = longueur (garrot -> rein)
y, x = np.mgrid[0:H, 0:W]
ROUGE = np.array([0.62, 0.08, 0.06]); OR = np.array([0.85, 0.62, 0.15]); INDIGO = np.array([0.08, 0.12, 0.35])
CREME = np.array([0.9, 0.85, 0.72]); NOIR = np.array([0.06, 0.05, 0.05]); VERT = np.array([0.1, 0.35, 0.22])
img = np.zeros((H, W, 3)); img[:] = ROUGE
u = np.abs(x - W / 2) / (W / 2)   # 0 au milieu du dos, 1 au bord des pans
# losanges emboîtés au milieu des pans
cx = (x % 64) - 32; cy = (y % 64) - 32
d = np.abs(cx) + np.abs(cy)
zone = (u > 0.35) & (u < 0.82)
img[zone & (d < 26)] = OR
img[zone & (d < 19)] = INDIGO
img[zone & (d < 12)] = CREME
img[zone & (d < 5)] = ROUGE
# bandes et chevrons en bordure des pans
ch = ((y + (np.abs(x - W / 2) * 0.0)) % 24)
bord = (u > 0.86)
img[bord] = INDIGO
img[bord & ((np.abs(((x % 24) - 12)) + (y % 24) * 0.0) < 0)] = OR
zig = np.abs(((y % 20) - 10)) * 1.6
img[(u > 0.83) & (u < 0.86)] = OR
img[(u > 0.9) & (np.abs((W / 2 - np.abs(x - W / 2)) - 18 - zig) < 3)] = OR
img[(u > 0.965)] = NOIR
# milieu du dos : bande verte à pointillés crème (sous la selle)
mil = u < 0.3
img[mil] = VERT
img[mil & ((y % 16) < 6) & (np.abs(x - W / 2) % 30 < 6)] = CREME
img[(u > 0.3) & (u < 0.35)] = OR
# rangs de perles sur les lignes or
perle = ((x % 8 - 4) ** 2 + (y % 8 - 4) ** 2) < 7
img[((u > 0.83) & (u < 0.86) | ((u > 0.3) & (u < 0.35))) & perle] = CREME
img = img * (0.92 + 0.08 * np.random.default_rng(3).random((H, W, 1)))
Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).save(__file__.replace(".py", ".png"))
print("tapis ok")

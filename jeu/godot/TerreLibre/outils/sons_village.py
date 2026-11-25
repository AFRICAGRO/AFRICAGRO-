"""Sons du village de Bomé, créés par programme (aucun enregistrement tiers).
- pilon.wav : un coup de pilon dans le mortier par seconde (cale sur l'animation « Piler », 24 images) ;
- houe.wav  : un coup de houe dans la terre toutes les 1,25 s (animation « Biner », 30 images) ;
- village.wav : fond de village (poules, voix lointaines, pilons au loin, coq de temps en temps)."""
import numpy as np
from scipy import signal
from scipy.io import wavfile

SR = 22050
DST = "/home/claude/godot/TerreLibre/sons/"
rng = np.random.default_rng(6)


def bruit_rose(n):
    b = rng.normal(size=n)
    f = np.fft.rfft(b)
    k = np.arange(len(f)); k[0] = 1
    return np.fft.irfft(f / np.sqrt(k), n)


def passe_bande(x, lo, hi, ordre=2):
    return signal.sosfilt(signal.butter(ordre, [lo, hi], btype="band", fs=SR, output="sos"), x)


def passe_bas(x, fc, ordre=2):
    return signal.sosfilt(signal.butter(ordre, fc, fs=SR, output="sos"), x)


def boucle(x, fondu=1.0):
    n = int(fondu * SR)
    t = np.linspace(0, 1, n)
    debut = x[:n].copy()
    x = x[n:].copy()
    x[-n:] = x[-n:] * np.cos(t * np.pi / 2) + debut * np.sin(t * np.pi / 2)
    return x


def ecrire(nom, x, gain=0.8):
    x = x / (np.abs(x).max() + 1e-9) * gain
    wavfile.write(DST + nom, SR, (x * 32767).astype(np.int16))
    print(nom, round(len(x) / SR, 2), "s")


def coup_pilon(n):
    """Choc sourd du bois dans le mortier plein : grave amorti + claquement court."""
    tt = np.arange(n) / SR
    f = 95 * (1 + 0.6 * np.exp(-tt * 40))
    grave = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt * 22)
    claque = passe_bande(rng.normal(size=n), 400, 2200) * np.exp(-tt * 90) * 0.6
    bois = np.sin(2 * np.pi * 310 * tt) * np.exp(-tt * 45) * 0.35
    return grave + claque + bois


def coup_houe(n):
    """La lame entre dans la terre : souffle mat + petit tintement de fer."""
    tt = np.arange(n) / SR
    terre = passe_bas(rng.normal(size=n), 700) * np.exp(-tt * 30)
    fer = np.sin(2 * np.pi * 1850 * tt) * np.exp(-tt * 60) * 0.15
    return terre + fer


# pilon : impact au milieu du cycle (pilon au fond du mortier à t = 0,5 s)
n = SR
x = np.zeros(n)
i = int(0.5 * SR)
x[i:] += coup_pilon(n - i)
x += passe_bas(bruit_rose(n), 300) * 0.01
ecrire("pilon.wav", x, 0.85)

# houe : impact à mi-cycle de 1,25 s, terre qui retombe ensuite
n = int(1.25 * SR)
x = np.zeros(n)
i = int(0.625 * SR)
x[i:] += coup_houe(n - i)
j = int(0.8 * SR)
x[j:] += passe_bande(rng.normal(size=n - j), 1500, 5000) * np.exp(-np.arange(n - j) / SR * 18) * 0.08
ecrire("houe.wav", x, 0.6)

# fond de village
d = 30.0
n = int(d * SR)
t = np.arange(n) / SR
v = passe_bas(bruit_rose(n), 350) * 0.25  # air, feuillage
# poules : gloussements en courtes rafales
for k in range(55):
    t0 = rng.uniform(0, d - 1.5)
    for r in range(rng.integers(2, 6)):
        i0 = int((t0 + r * rng.uniform(0.13, 0.22)) * SR)
        m = int(rng.uniform(0.05, 0.09) * SR)
        tt = np.arange(m) / SR
        f0 = rng.uniform(380, 520) * (1 + 0.4 * tt / tt[-1])
        cri = signal.sawtooth(2 * np.pi * np.cumsum(f0) / SR, 0.3)
        cri = passe_bande(cri, 600, 3200) * np.sin(np.pi * tt / tt[-1]) ** 2
        v[i0:i0 + m] += cri * rng.uniform(0.08, 0.22)
# voix lointaines (formants), plus rares qu'en ville
for k in range(90):
    t0 = rng.uniform(0, d - 1)
    dur = rng.uniform(0.15, 0.4)
    i0 = int(t0 * SR); m = int(dur * SR)
    tt = np.arange(m) / SR
    f0 = rng.uniform(120, 260)
    voix = signal.sawtooth(2 * np.pi * f0 * tt * (1 + 0.06 * np.sin(2 * np.pi * 5 * tt)))
    voix = passe_bande(voix, 400, 1400)
    v[i0:i0 + m] += voix * np.sin(np.pi * tt / dur) * rng.uniform(0.04, 0.12)
# pilons lointains, deux femmes en alternance
for per, dec in ((1.0, 0.0), (1.1, 0.37)):
    tk = dec
    while tk < d - 0.5:
        i0 = int(tk * SR); m = int(0.4 * SR)
        v[i0:i0 + m] += passe_bas(coup_pilon(m), 600) * 0.12
        tk += per
# coq au loin, deux fois
for t0 in (7.0, 21.5):
    m = int(1.3 * SR)
    tt = np.arange(m) / SR
    contour = np.interp(tt, [0, 0.15, 0.35, 0.8, 1.3], [520, 700, 760, 720, 480])
    coq = signal.sawtooth(2 * np.pi * np.cumsum(contour) / SR, 0.4)
    coq = passe_bande(coq, 700, 3000) * np.interp(tt, [0, 0.05, 1.0, 1.3], [0, 1, 0.8, 0])
    i0 = int(t0 * SR)
    v[i0:i0 + m] += passe_bas(coq, 2500) * 0.18
ecrire("village.wav", boucle(v), 0.5)

# rivière : courant clair sur les cailloux (bruit filtré, bulles et clapotis)
d = 20.0
n = int(d * SR)
x = passe_bande(bruit_rose(n), 250, 2500) * 0.6
x += passe_bande(rng.normal(size=n), 2500, 7000) * 0.08
for k in range(900):
    i0 = int(rng.uniform(0, d - 0.05) * SR)
    m = int(rng.uniform(0.008, 0.025) * SR)
    tt = np.arange(m) / SR
    f = rng.uniform(600, 2200) * (1 + 1.5 * tt / tt[-1])
    x[i0:i0 + m] += np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt * 140) * rng.uniform(0.05, 0.25)
ecrire("riviere.wav", boucle(x), 0.6)

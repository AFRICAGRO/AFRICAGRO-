"""Sons d'ambiance créés par programme (aucun enregistrement tiers) : boucles sans couture."""
import numpy as np
from scipy import signal
from scipy.io import wavfile

SR = 22050
DST = "/home/claude/godot/TerreLibre/sons/"
rng = np.random.default_rng(4)


def bruit_rose(n):
    b = rng.normal(size=n)
    f = np.fft.rfft(b)
    k = np.arange(len(f)); k[0] = 1
    return np.fft.irfft(f / np.sqrt(k), n)


def passe_bande(x, lo, hi, ordre=2):
    sos = signal.butter(ordre, [lo, hi], btype="band", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def passe_bas(x, fc, ordre=2):
    return signal.sosfilt(signal.butter(ordre, fc, fs=SR, output="sos"), x)


def boucle(x, fondu=1.0):
    """Fondu enchaîné fin→début pour une boucle sans clic."""
    n = int(fondu * SR)
    t = np.linspace(0, 1, n)
    debut = x[:n].copy()
    x = x[n:].copy()
    x[-n:] = x[-n:] * np.cos(t * np.pi / 2) + debut * np.sin(t * np.pi / 2)
    return x


def ecrire(nom, x, gain=0.8):
    x = x / (np.abs(x).max() + 1e-9) * gain
    wavfile.write(DST + nom, SR, (x * 32767).astype(np.int16))
    print(nom, round(len(x) / SR, 1), "s")


d = 24.0
n = int(d * SR)
t = np.arange(n) / SR

# vagues : houle qui monte, se brise (souffle aigu), puis reflue sur le sable
vagues = np.zeros(n)
debut = 0.0
while debut < d:
    per = rng.uniform(5.5, 8.0)
    env = np.zeros(n)
    m = (t >= debut) & (t < debut + per)
    u = (t[m] - debut) / per
    env[m] = np.where(u < 0.35, (u / 0.35) ** 2, np.exp(-(u - 0.35) * 4.5))
    vagues += passe_bas(bruit_rose(n), 900) * env * 1.0
    vagues += passe_bande(rng.normal(size=n), 1500, 6000) * env ** 3 * 0.25
    debut += per * rng.uniform(0.55, 0.8)
vagues += passe_bas(bruit_rose(n), 300) * 0.35
ecrire("vagues.wav", boucle(vagues))

# vent doux dans les palmes
v = passe_bande(bruit_rose(n), 150, 2500)
mod = 0.55 + 0.45 * np.sin(2 * np.pi * t / 7.3) * np.sin(2 * np.pi * t / 3.1 + 1)
ecrire("vent.wav", boucle(v * mod), 0.6)

# cigales (journée) : bourdonnement aigu pulsé, plusieurs insectes décalés
cig = np.zeros(n)
for k in range(5):
    f0 = rng.uniform(4200, 6200)
    puls = (np.sin(2 * np.pi * rng.uniform(38, 60) * t) > 0.2).astype(float)
    env = 0.5 + 0.5 * np.sin(2 * np.pi * t / rng.uniform(5, 11) + rng.uniform(0, 6))
    cig += np.sin(2 * np.pi * f0 * t) * puls * env ** 2 * rng.uniform(0.4, 1)
cig = passe_bande(cig + rng.normal(size=n) * 0.05, 3000, 9000)
ecrire("cigales.wav", boucle(cig), 0.35)

# grillons (nuit) : stridulations régulières
gr = np.zeros(n)
for k in range(6):
    f0 = rng.uniform(3800, 4800)
    rythme = rng.uniform(1.5, 3.0)
    phase = rng.uniform(0, 1)
    tri = ((t * rythme + phase) % 1.0) < 0.22
    stri = (np.sin(2 * np.pi * 30 * t) > 0).astype(float)
    gr += np.sin(2 * np.pi * f0 * t) * tri * stri * rng.uniform(0.3, 1)
ecrire("grillons.wav", boucle(passe_bande(gr, 2500, 7000)), 0.3)

# oiseaux tropicaux : sifflements, trilles et roucoulements épars
ois = np.zeros(n)
for k in range(38):
    t0 = rng.uniform(0, d - 2)
    i0 = int(t0 * SR)
    sorte = rng.integers(0, 3)
    if sorte == 0:  # sifflement montant-descendant
        dur = rng.uniform(0.25, 0.6)
        tt = np.arange(int(dur * SR)) / SR
        f = rng.uniform(1800, 3200) * (1 + 0.35 * np.sin(np.pi * tt / dur))
    elif sorte == 1:  # trille
        dur = rng.uniform(0.4, 0.9)
        tt = np.arange(int(dur * SR)) / SR
        f = rng.uniform(2500, 4000) + 400 * np.sin(2 * np.pi * rng.uniform(14, 22) * tt)
    else:  # roucoulement grave (tourterelle)
        dur = rng.uniform(0.6, 1.0)
        tt = np.arange(int(dur * SR)) / SR
        f = rng.uniform(450, 600) * (1 - 0.15 * tt / dur)
    ph = 2 * np.pi * np.cumsum(f) / SR
    env = np.sin(np.pi * tt / dur) ** 2
    note = np.sin(ph) * env * rng.uniform(0.3, 1)
    if sorte == 2:
        note *= (np.sin(2 * np.pi * 3 * tt) > -0.3)
    ois[i0:i0 + len(note)] += note[: max(0, min(len(note), n - i0))]
ecrire("oiseaux.wav", boucle(ois), 0.5)

# mouette : cri rauque qui descend (« kiaou »)
dm = 0.7
tt = np.arange(int(dm * SR)) / SR
f = 1150 * np.exp(-tt * 1.4) + 650
ph = 2 * np.pi * np.cumsum(f) / SR
cri = sum(np.sin(ph * h) / h for h in range(1, 7)) * np.sin(np.pi * tt / dm) ** 0.6
cri += passe_bande(rng.normal(size=len(tt)), 800, 3000) * 0.15
ecrire("mouette.wav", cri, 0.7)

# pluie : crépitement dense
pl = passe_bande(rng.normal(size=n), 400, 8000) * 0.6 + passe_bas(bruit_rose(n), 600) * 0.4
gouttes = np.zeros(n); gouttes[rng.integers(0, n, 9000)] = rng.uniform(0.2, 1, 9000)
pl += passe_bande(gouttes, 1500, 7000) * 3
ecrire("pluie.wav", boucle(pl), 0.6)

# moteur de moto 125 au ralenti / en route (boucle de 2 s)
dmo = 2.0
tt = np.arange(int(dmo * SR)) / SR
f0 = 52.0
moto = sum(signal.sawtooth(2 * np.pi * f0 * h * tt) / h for h in (1, 2, 3))
moto *= 0.6 + 0.4 * (np.sin(2 * np.pi * f0 * tt) > 0)  # explosions du monocylindre
moto = passe_bas(moto + rng.normal(size=len(tt)) * 0.25, 1400) 
ecrire("moto.wav", moto, 0.6)

# rumeur de la ville : murmure de voix lointaines (formants), klaxons rares, musique lointaine étouffée
ru = np.zeros(n)
for k in range(260):
    t0 = rng.uniform(0, d - 1)
    dur = rng.uniform(0.12, 0.35)
    i0 = int(t0 * SR); m_ = int(dur * SR)
    tt = np.arange(m_) / SR
    f0 = rng.uniform(110, 240)
    voix = signal.sawtooth(2 * np.pi * f0 * tt * (1 + 0.05 * np.sin(2 * np.pi * 4 * tt)))
    for fo in (rng.uniform(500, 800), rng.uniform(1000, 1600)):
        voix = voix + passe_bande(voix, fo * 0.8, fo * 1.2) * 2
    ru[i0:i0 + m_] += voix * np.sin(np.pi * tt / dur) * rng.uniform(0.1, 0.4)
ru = passe_bas(ru, 1800) + passe_bas(bruit_rose(n), 400) * 0.6
for k in range(3):  # klaxons lointains
    t0 = rng.uniform(1, d - 2); i0 = int(t0 * SR); m_ = int(0.35 * SR)
    tt = np.arange(m_) / SR
    ru[i0:i0 + m_] += passe_bas(signal.square(2 * np.pi * 420 * tt), 1500) * 0.25
ecrire("ville.wav", boucle(ru), 0.5)

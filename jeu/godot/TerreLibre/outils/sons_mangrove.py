"""Ambiance de la mangrove de la baie du Sud (mission 9), synthétisée :
grenouilles (coassements par salves), insectes (stridulations aiguës), moustique qui passe,
clapotis de l'eau contre les racines. Boucle de 16 s sans couture.
Usage : python3 outils/sons_mangrove.py  (depuis la racine du projet) -> sons/mangrove.wav
"""
import wave
import numpy as np

SR = 44100
DUREE = 16.0
rng = np.random.default_rng(9)
n = int(SR * DUREE)
t = np.arange(n) / SR


def lisse(x, fc):
    # passe-bas récursif simple
    a = np.exp(-2 * np.pi * fc / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a) * x[i] + a * acc
        y[i] = acc
    return y


def boucle(i0, signal):
    """Ajoute un signal en bouclant sur la durée totale (pas de couture)."""
    out = np.zeros(n)
    idx = (i0 + np.arange(len(signal))) % n
    np.add.at(out, idx, signal)
    return out


x = np.zeros(n)
# grenouilles : 4 individus, chacun avec sa hauteur et son rythme
for g in range(4):
    f0 = rng.uniform(380, 720)
    periode = rng.uniform(0.9, 2.4)
    tt = rng.uniform(0, periode)
    while tt < DUREE:
        salve = rng.integers(2, 6)
        for k in range(salve):
            d = rng.uniform(0.05, 0.09)
            m = int(d * SR)
            u = np.arange(m) / SR
            env = np.sin(np.pi * u / d) ** 2
            # coassement : son pulsé (modulation d'amplitude rapide) et riche en harmoniques
            pulse = 0.5 + 0.5 * np.sign(np.sin(2 * np.pi * rng.uniform(55, 90) * u))
            son = (np.sin(2 * np.pi * f0 * u) + 0.5 * np.sin(4 * np.pi * f0 * u) + 0.25 * np.sin(6 * np.pi * f0 * u))
            x += boucle(int((tt + k * d * 1.4) * SR), son * env * pulse * rng.uniform(0.15, 0.3))
        tt += periode * rng.uniform(0.7, 1.4)

# insectes : stridulation continue, légèrement battante
for f in (4300.0, 5100.0, 6150.0):
    batt = 0.5 + 0.5 * np.sin(2 * np.pi * (DUREE ** -1) * round(rng.uniform(20, 60)) * t)
    x += np.sin(2 * np.pi * f * t) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 31 * t))) * batt * 0.025

# moustique qui passe (deux fois par boucle)
for t0 in (3.0, 10.5):
    d = 2.2
    m = int(d * SR)
    u = np.arange(m) / SR
    env = np.sin(np.pi * u / d) ** 3
    f = 590 + 25 * np.sin(2 * np.pi * 0.7 * u)
    phase = 2 * np.pi * np.cumsum(f) / SR
    x += boucle(int(t0 * SR), (np.sin(phase) + 0.4 * np.sin(2 * phase)) * env * 0.05)

# clapotis : petits chocs d'eau filtrés
bruit = rng.standard_normal(n)
gouttes = np.zeros(n)
for _ in range(int(DUREE * 7)):
    i = rng.integers(0, n)
    m = int(0.12 * SR)
    u = np.arange(m) / SR
    gouttes += boucle(i, np.exp(-u / 0.03) * rng.uniform(0.3, 1.0))
x += lisse(bruit * gouttes, 900.0) * 0.6

x = x / np.max(np.abs(x)) * 0.8
with wave.open("sons/mangrove.wav", "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes((x * 32767).astype(np.int16).tobytes())
print("ok")

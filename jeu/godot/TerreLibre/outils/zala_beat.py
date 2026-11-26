"""« Zala-beat » : premier morceau original de Radio Racines (WANZALA : FREEDOM), composé et synthétisé ici.
Highlife / afrobeat léger à 112 BPM : grosse caisse, caisse claire, shaker en doubles croches,
cloche (gankogui) en motif 12/8 simplifié, basse ronde, guitare highlife en arpèges (Karplus-Strong)
et balafon (lames de bois à harmoniques inharmoniques). 8 mesures en boucle parfaite.
Sortie : sons/radio_racines.wav (22,05 kHz, mono)."""
import numpy as np, wave

SR = 22050
BPM = 112
T = 60.0 / BPM            # une noire
MESURES = 8
N = int(SR * T * 4 * MESURES)
mix = np.zeros(N)
rng = np.random.default_rng(7)

def place(sig, t, gain=1.0):
    i = int(t * SR) % N
    fin = min(N, i + len(sig))
    mix[i:fin] += sig[:fin - i] * gain
    reste = len(sig) - (fin - i)
    if reste > 0:          # la boucle est parfaite : la queue revient au début
        mix[:reste] += sig[fin - i:] * gain

def env(n, a=0.002, d=0.2):
    t = np.arange(n) / SR
    return np.minimum(1, t / a) * np.exp(-t / d)

def kick():
    n = int(0.35 * SR); t = np.arange(n) / SR
    f = 50 + 90 * np.exp(-t * 30)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * env(n, 0.001, 0.16)

def caisse():
    n = int(0.22 * SR); t = np.arange(n) / SR
    bruit = rng.normal(0, 1, n)
    bruit = np.convolve(bruit, [1, -0.6], "same")
    return (0.7 * bruit * np.exp(-t / 0.06) + 0.5 * np.sin(2 * np.pi * 190 * t) * np.exp(-t / 0.05))

def shaker(fort):
    n = int(0.07 * SR); t = np.arange(n) / SR
    b = rng.normal(0, 1, n); b = b - np.convolve(b, np.ones(6) / 6, "same")
    return b * np.minimum(1, t / 0.01) * np.exp(-t / 0.025) * (0.35 if fort else 0.2)

def cloche(f):
    n = int(0.25 * SR); t = np.arange(n) / SR
    return (np.sin(2 * np.pi * f * t) + 0.5 * np.sin(2 * np.pi * f * 2.76 * t)) * env(n, 0.001, 0.07)

def basse(f, duree):
    n = int(duree * SR); t = np.arange(n) / SR
    s = np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * 2 * f * t) + 0.12 * np.sin(2 * np.pi * 3 * f * t)
    return s * np.minimum(1, t / 0.01) * np.exp(-t / (duree * 0.9))

def guitare(f, duree=0.5):
    # Karplus-Strong : corde pincée, son clair de guitare highlife
    n = int(duree * SR); p = int(SR / f)
    buf = rng.uniform(-1, 1, p); out = np.zeros(n)
    for i in range(n):
        out[i] = buf[i % p]
        buf[i % p] = 0.5 * (buf[i % p] + buf[(i + 1) % p]) * 0.996
    return out * np.minimum(1, np.arange(n) / (0.003 * SR))

def balafon(f):
    n = int(0.6 * SR); t = np.arange(n) / SR
    s = np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * f * 3.93 * t) * np.exp(-t / 0.05) + 0.15 * np.sin(2 * np.pi * f * 9.4 * t) * np.exp(-t / 0.02)
    bourdon = 1 + 0.25 * np.sin(2 * np.pi * 11 * t)          # le grésillement de la calebasse
    return s * bourdon * env(n, 0.001, 0.22)

note = lambda m: 440.0 * 2 ** ((m - 69) / 12)
# progression highlife (ré majeur) : I - IV - V - I, deux fois
accords = [[62, 66, 69], [67, 71, 74], [69, 73, 76], [62, 66, 69]] * 2
basses = [38, 43, 45, 38] * 2
# balafon : petite mélodie de réponse (appel / réponse), 2 mesures sur 4
melodie = [(0, 74), (0.75, 76), (1.5, 78), (2.5, 76), (3, 74), (4.5, 81), (5.25, 78), (6, 76), (6.5, 74), (7, 71)]

for m in range(MESURES):
    t0 = m * 4 * T
    for b in range(4):
        place(kick(), t0 + b * T, 0.9 if b in (0, 2) else 0.55)
    for b in (1, 3):
        place(caisse(), t0 + b * T, 0.45)
    for k in range(16):
        place(shaker(k % 4 == 2), t0 + k * T / 4 + rng.uniform(-0.004, 0.004))
    for k in (0, 1.5, 2, 3, 3.5):                              # cloche : motif proche du gankogui
        place(cloche(880 if k in (0, 2) else 1175), t0 + k * T, 0.18)
    f = note(basses[m])
    for k, d in ((0, 0.75), (1.5, 0.4), (2, 0.75), (3.25, 0.4)):
        place(basse(f * (1.5 if k == 3.25 else 1), d * T * 2), t0 + k * T, 0.55)
    acc = accords[m]
    for k in range(8):                                         # guitare : arpèges en croches syncopées
        n_ = acc[[0, 1, 2, 1, 2, 0, 1, 2][k]] + (12 if k in (2, 6) else 0)
        place(guitare(note(n_), 0.45), t0 + k * T / 2 + (T / 4 if k % 2 else 0) * 0.0, 0.16)
    if m % 4 in (1, 3):
        for (k, n_) in melodie:
            if (m % 4 == 1 and k < 4) or (m % 4 == 3 and k >= 4):
                place(balafon(note(n_)), t0 + (k % 4) * T, 0.33)

# léger écho de cour (salle en tôle de la radio), puis normalisation douce
d = int(0.19 * SR)
echo = np.roll(mix, d) * 0.18
mix = mix + echo
mix = np.tanh(mix / np.percentile(np.abs(mix), 99.7) * 0.9) * 0.85
data = (mix * 32767).astype(np.int16)
with wave.open("sons/radio_racines.wav", "wb") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(data.tobytes())
print("ok", len(data) / SR, "s")

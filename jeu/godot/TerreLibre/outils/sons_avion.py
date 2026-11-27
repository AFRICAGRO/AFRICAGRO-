"""Sons de la mission 10 « L'Avion », synthétisés :
- sons/avion.wav  : bimoteur à hélices (bourdon grave, battement des deux hélices, souffle), boucle de 4 s
- sons/sirene.wav : sirène d'alerte de la piste (montée-descente), boucle de 3 s
Usage : python3 outils/sons_avion.py  (depuis la racine du projet)
"""
import wave
import numpy as np

SR = 44100
rng = np.random.default_rng(10)


def ecrire(nom, x):
    x = x / (np.max(np.abs(x)) + 1e-9) * 0.85
    with wave.open(nom, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


def lisse(x, fc):
    a = np.exp(-2 * np.pi * fc / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a) * x[i] + a * acc
        y[i] = acc
    return y


def avion():
    d = 4.0
    t = np.arange(int(SR * d)) / SR
    x = np.zeros_like(t)
    # deux moteurs légèrement désaccordés : le battement typique des bimoteurs
    # (fréquences choisies pour un nombre entier de périodes en 4 s : boucle sans couture)
    for f0 in (88.0, 89.5):
        phase = 2 * np.pi * f0 * t
        moteur = sum(np.sin(k * phase) / k ** 1.1 for k in range(1, 12))
        x += moteur
    # passage des pales (4 par tour, deux hélices)
    pales = 0.5 + 0.5 * np.sin(2 * np.pi * 44.0 * t) ** 8
    souffle = lisse(rng.standard_normal(len(t)), 1800.0) * 1.8
    x = x * (0.75 + 0.25 * pales) + souffle * (0.6 + 0.4 * pales)
    # raccord de boucle : fondu croisé sur 50 ms
    m = int(0.05 * SR)
    x[:m] = x[:m] * np.linspace(0, 1, m) + x[-m:] * np.linspace(1, 0, m)
    return x[:-m]


def sirene():
    d = 3.0
    t = np.arange(int(SR * d)) / SR
    f = 620 + 380 * (0.5 - 0.5 * np.cos(2 * np.pi * t / d))
    phase = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(phase) + 0.35 * np.sin(2 * phase) + 0.15 * np.sign(np.sin(phase))


if __name__ == "__main__":
    ecrire("sons/avion.wav", avion())
    ecrire("sons/sirene.wav", sirene())
    print("ok")

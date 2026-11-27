"""Sons de la mission 8 « Nuit à Tikané », synthétisés (aucun échantillon extérieur) :
- sons/tonnerre.wav  : craquement proche puis roulement qui s'éloigne (7 s)
- sons/flechette.wav : tir de fusil à air comprimé, « pfft » sec et court
Usage : python3 outils/sons_orage.py  (depuis la racine du projet)
"""
import wave
import numpy as np

SR = 44100
rng = np.random.default_rng(8)


def ecrire(nom, x):
    x = x / (np.max(np.abs(x)) + 1e-9) * 0.9
    y = (x * 32767).astype(np.int16)
    with wave.open(nom, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(y.tobytes())


def passe_bas(x, fc):
    # filtre récursif du premier ordre, appliqué deux fois (pente de 12 dB/octave)
    a = np.exp(-2 * np.pi * fc / SR)
    for _ in range(2):
        y = np.empty_like(x)
        acc = 0.0
        for i in range(len(x)):
            acc = (1 - a) * x[i] + a * acc
            y[i] = acc
        x = y
    return x


def tonnerre():
    n = int(SR * 7.0)
    t = np.arange(n) / SR
    bruit = rng.standard_normal(n)
    # craquement : bruit large bande très bref
    crac = bruit * np.exp(-t / 0.05) * (t < 0.4)
    # roulement : bruit grave modulé par des « éclats » aléatoires qui s'espacent
    env = np.zeros(n)
    tt = 0.08
    while tt < 6.2:
        i = int(tt * SR)
        largeur = rng.uniform(0.25, 0.7)
        amp = np.exp(-tt / 2.2) * rng.uniform(0.5, 1.0)
        k = np.arange(n - i) / SR
        env[i:] += amp * np.exp(-k / largeur) * (1 - np.exp(-k / 0.03))
        tt += rng.uniform(0.15, 0.6) * (1 + tt * 0.25)
    roul = passe_bas(bruit, 160.0) * env * 6.0
    grave = passe_bas(rng.standard_normal(n), 45.0) * env * 14.0
    x = passe_bas(crac, 2500.0) * 0.8 + roul + grave
    x *= np.minimum(1.0, (7.0 - t) / 1.0)   # fin en fondu
    return x


def flechette():
    n = int(SR * 0.35)
    t = np.arange(n) / SR
    souffle = rng.standard_normal(n) * np.exp(-t / 0.035)
    souffle = souffle - passe_bas(souffle, 900.0)          # air comprimé : surtout des aigus
    clic = np.sin(2 * np.pi * 1700 * t) * np.exp(-t / 0.004)
    corps = np.sin(2 * np.pi * 210 * t) * np.exp(-t / 0.03) * 0.4
    return souffle + clic * 0.6 + corps


if __name__ == "__main__":
    ecrire("sons/tonnerre.wav", tonnerre())
    ecrire("sons/flechette.wav", flechette())
    print("ok")

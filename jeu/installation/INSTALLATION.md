# Installation de l'atelier « Terre Libre »

Objectif : un PC prêt à créer le jeu, avec Claude branché directement sur **Unreal Engine** et
**Blender**, plus les connecteurs claude.ai pour l'organisation et le design.

Temps estimé : 2 à 4 heures, surtout pour les téléchargements (Unreal fait plus de 50 Go).

## Vue d'ensemble

| # | Quoi | Où | Comment | Gratuit |
|---|---|---|---|---|
| 1 | Logiciels (Git, Python, uv, Blender, Epic Launcher, Krita, GIMP, Inkscape, Audacity, QGIS, Claude) | Votre PC | `installer-windows.ps1` (automatique) | Oui |
| 2 | Unreal Engine 5 | Votre PC | Epic Games Launcher (manuel, compte Epic) | Oui (5 % de royalties au-delà de 1 M$) |
| 3 | Projet Unreal « TerreLibre » | Votre PC | Création manuelle puis `configurer-projet-unreal.ps1` | — |
| 4 | Connecteur **Blender** pour Claude | Votre PC | Automatique (étape 1) + fichier `.mcp.json` du dépôt | Oui (MIT) |
| 5 | Connecteur **Unreal** pour Claude | Votre PC | Fichier `.mcp.json` du dépôt + étape 3 | Oui (MIT) |
| 6 | Connecteurs claude.ai : Notion, Figma, Whimsical | Navigateur | claude.ai → Paramètres → Connecteurs | Plans gratuits |
| 7 | Relier le PC à Claude (Remote Control) | Application Claude | Paramètres → Claude Code → Remote Control | Oui |

---

## Étape 1 — Installer les logiciels (automatique)

1. Récupérer le dépôt sur le PC (bouton **Code → Download ZIP** sur GitHub, ou `git clone`).
2. Ouvrir **PowerShell en administrateur** dans le dossier `jeu\installation`.
3. Taper :
   ```powershell
   Set-ExecutionPolicy -Scope Process Bypass
   .\installer-windows.ps1
   ```
   Ajouter `-AvecVisualStudio` pour installer aussi Visual Studio 2022 (≈ 30 Go). Il n'est
   nécessaire que pour écrire du C++ dans Unreal ; on peut l'ajouter plus tard.
4. À la fin, le script affiche ce qui a échoué. Pour chaque ligne, installer le logiciel depuis
   son site officiel ou relancer le script dans une nouvelle fenêtre PowerShell.

Le script vérifie aussi la mémoire, la carte graphique et l'espace disque.

## Étape 2 — Installer Unreal Engine 5

1. Ouvrir **Epic Games Launcher**, créer un compte Epic (gratuit) et se connecter.
2. Onglet **Unreal Engine → Bibliothèque → +** : choisir la **dernière version 5.x**, puis Installer.

## Étape 3 — Créer le projet et le préparer pour Claude

1. Lancer Unreal : **Jeux → Third Person**, Blueprint, qualité **Maximale**, avec le contenu de démarrage.
   - Emplacement : `…\AFRICAGRO-\jeu\unreal\`
   - Nom : `TerreLibre`
2. **Fermer Unreal**, puis dans PowerShell :
   ```powershell
   .\configurer-projet-unreal.ps1 -Projet "C:\…\AFRICAGRO-\jeu\unreal\TerreLibre\TerreLibre.uproject"
   ```
   Le script active les plugins nécessaires (Python, Remote Control, Water, PCG, Landmass,
   véhicules) et autorise Claude à piloter l'éditeur **depuis cet ordinateur uniquement**.
3. Rouvrir le projet et accepter l'activation des plugins.

## Étape 4 — Vérifier les connecteurs Blender et Unreal

1. Ouvrir **Blender**. Dans la barre latérale de la vue 3D (touche **N**), onglet **MCP** :
   cliquer sur **Connect to Claude**.
2. Garder **Unreal** ouvert avec le projet TerreLibre.
3. Dans un terminal, dans le dossier du dépôt `AFRICAGRO-`, taper `claude`.
   Claude Code détecte le fichier `.mcp.json` et propose les serveurs **blender** et **unreal** :
   les accepter.
4. Taper `/mcp` : les deux connecteurs doivent apparaître comme connectés.
5. Test : demander à Claude « crée un cube dans Blender » puis « liste les acteurs du niveau Unreal ».

> Sécurité : ces connecteurs permettent à Claude d'exécuter du code dans Blender et Unreal. Ils
> n'écoutent que sur l'ordinateur lui-même. Ne pas ouvrir leurs ports sur Internet, et ne lancer
> que des projets de confiance.

## Étape 5 — Connecteurs claude.ai (navigateur)

Sur **claude.ai → Paramètres → Connecteurs** (claude.ai/customize/connectors) :

| Connecteur | État | Usage |
|---|---|---|
| **Notion** | Connexion commencée, **à terminer** | Wiki du jeu, tableau de production, bugs |
| **Figma** | À ajouter | Interface du jeu : HUD, menus, téléphone du héros, carte |
| **Whimsical** | À ajouter | Arbres de missions, organigrammes des factions |
| GitHub, Google Drive/Docs, Canva, Gamma, ElevenLabs | **Déjà connectés** | Code, bible du jeu, planches d'ambiance, présentation, voix provisoires |

Les connecteurs sont chargés au démarrage d'une session : en ouvrir une nouvelle après les avoir ajoutés.

## Étape 6 — Relier le PC à Claude (recommandé)

Pour que Claude puisse travailler **directement sur votre PC** depuis l'application Claude
(lancer les scripts, piloter Unreal et Blender, importer les terrains) :

1. Ouvrir l'**application Claude** (installée à l'étape 1) et se connecter.
2. **Paramètres → Claude Code → Remote Control** : ajouter le dossier `AFRICAGRO-`.
3. Laisser l'application ouverte : une session Claude pourra alors demander l'accès à ce
   dossier (vous validez à chaque fois).

---

## Liste de contrôle

- [ ] Script d'installation lancé, bilan sans échec
- [ ] Unreal Engine 5 installé
- [ ] Projet `jeu/unreal/TerreLibre` créé et configuré
- [ ] Blender : extension MCP active, « Connect to Claude » cliqué
- [ ] `claude` puis `/mcp` : blender ✅ unreal ✅
- [ ] Notion terminé, Figma et Whimsical ajoutés
- [ ] Remote Control activé sur le dossier du dépôt
- [ ] Premier test : importer `jeu/terrains/ile-depart/ile-depart_heightmap_2017.png` dans Unreal

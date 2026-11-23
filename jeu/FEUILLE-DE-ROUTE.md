# Feuille de route

Principe : **pas de précipitation**. Chaque phase se termine par une validation écrite
(qu'est-ce qui marche, qu'est-ce qui ne marche pas) avant de passer à la suivante.

## Phase 0 — Préproduction papier (mois 1–2) ← NOUS SOMMES ICI

- [x] Vision, histoire, factions, mécaniques (README.md)
- [x] Cartographie générale et île de départ (CARTOGRAPHIE.md, cartes SVG)
- [x] Liste des missions de l'acte 1 (MISSIONS.md)
- [x] Liste des outils et connecteurs (OUTILS.md)
- [x] Vraie carte de l'Afrique découpée en pays fictifs (GEOGRAPHIE-REELLE.md)
- [x] Terrains réels des 5 régions : île, côte, plateau, forêt, monts (terrains/)
- [x] Renommer l'île de départ → **île de Talanké** (« Kassa » existe réellement en Guinée)
- [ ] Valider le titre, le nom du héros et du pays
- [ ] Planche d'ambiance visuelle (Canva) : 50–100 photos de référence par lieu
- [ ] Fiches personnages détaillées (apparence, voix, motivations)
- [ ] Bible des langues/noms fictifs, drapeaux, monnaie, marques fictives
- [ ] Choisir et installer le PC de développement → suivre [installation/INSTALLATION.md](installation/INSTALLATION.md)
- [x] Kit d'installation prêt : script Windows, configuration Unreal, `.mcp.json` (Blender + Unreal), Git LFS

## Phase 1 — Installation et apprentissage (mois 2–3)

- [ ] Installer Unreal Engine 5, Blender, Git, Git LFS → `jeu/installation/installer-windows.ps1`
- [ ] Brancher Claude Code sur Blender et Unreal (`.mcp.json` fourni) → `jeu/installation/INSTALLATION.md`
- [ ] Créer le projet Unreal (modèle « Third Person », World Partition activé)
- [ ] Tutoriels : Landscape, PCG, MetaHuman, Chaos Vehicles, Behavior Trees

## Phase 2 — Prototype « gris » de l'île (mois 3–5)

- [ ] Heightmap de l'île importée
- [ ] Blockout (formes simples) de Port-Néré, Akwa, Bomé, du camp
- [ ] Personnage jouable : marcher, courir, nager, se mettre à couvert, tirer
- [ ] Une moto et une pirogue conduisibles
- [ ] Un ennemi avec IA de base (patrouille, détection, combat)
- [ ] Mission 4 « Première Étincelle » jouable en version grise
- **Validation :** est-ce que c'est amusant même sans graphismes ?

## Phase 3 — Systèmes de base (mois 5–9)

- [ ] Libération de zone + changement visuel
- [ ] Jauge de confiance, système d'alerte
- [ ] Coopérative (version simple)
- [ ] Civils avec routines, cycle jour/nuit, météo
- [ ] Sauvegarde/chargement, téléphone, carte en jeu

## Phase 4 — Tranche verticale (mois 9–15)

- [ ] Port-Néré en qualité finale (graphismes, sons, PNJ)
- [ ] Missions 1 à 6 complètes avec dialogues provisoires (ElevenLabs)
- [ ] Optimisation (60 i/s sur PC milieu de gamme)
- [ ] Bande-annonce + pitch deck (Gamma) → recherche de financement / éditeur / talents

## Phase 5 — Acte 1 complet (mois 15–24)

- [ ] Toute l'île, 12 missions, activités secondaires
- [ ] Doublage professionnel, musique originale
- [ ] Tests joueurs, corrections, classification PEGI
- [ ] Sortie possible de l'acte 1 seul (Steam / Epic Games Store)

## Phases suivantes

Actes 2 à 5, chacun ≈ 12–18 mois selon la taille de l'équipe.

---

## Ce qu'il faut pour commencer dès maintenant

1. **Relire et valider** ces documents (titre, héros, pays, île, missions) — vos corrections d'abord.
2. **Terminer la connexion Notion** sur claude.ai (ou choisir Google Docs) comme tableau de bord.
3. **Ajouter Figma** et **Whimsical** dans les connecteurs claude.ai (gratuits).
4. **Préparer le PC** de développement (voir OUTILS.md §4) et installer Unreal Engine 5 + Blender.
5. **Installer Claude Code sur ce PC** pour brancher Blender MCP et Unreal MCP.
6. **Commencer la planche d'ambiance** dans Canva (photos de villes côtières, marchés, villages,
   mangroves, architecture) — c'est la base de tout le travail graphique.

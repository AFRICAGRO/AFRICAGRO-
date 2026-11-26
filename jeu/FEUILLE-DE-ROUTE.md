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
- [x] Titre : **WANZALA : FREEDOM** · héros : **Faris** · pays : **Wanzala**
- [ ] Planche d'ambiance visuelle (Canva) : 50–100 photos de référence par lieu
- [x] Fiches personnages détaillées → PERSONNAGES.md
- [x] Bible du monde : langue wazalé, noms, drapeaux, hymne, monnaie (kauri), marques → BIBLE-DU-MONDE.md
- [ ] Choisir et installer le PC de développement → suivre [installation/INSTALLATION.md](installation/INSTALLATION.md)
- [x] Kit d'installation prêt : script Windows, configuration Unreal, `.mcp.json` (Blender + Unreal), Git LFS

> **Décision du 24 novembre 2026 — moteur.** Le PC actuel ne fait pas tourner Unreal Engine 5.
> Le prototype et la tranche verticale se font donc sous **Godot 4** (rendu « Compatibilité »), dans
> [godot/TerreLibre/](godot/TerreLibre/README.md). Le relief, les textures, les ciels et le modèle de Faris
> sont réutilisables tels quels dans Unreal le jour où une machine plus puissante sera disponible.
> Déjà fait sous Godot : île réelle jouable, sol et ciels photographiés, arbres réalistes, cocotiers,
> 5 ambiances lumineuses, Faris (corps MakeHuman, chemise wax, 5 animations).

## Phase 1 — Installation et apprentissage (mois 2–3)

- [x] ~~Unreal Engine 5~~ → moteur retenu : **Godot 4 (rendu Compatibilité)**, adapté à un PC modeste. Installer Godot, Blender, Git → `jeu/installation/installer-windows.ps1`
- [ ] Brancher Claude Code sur Blender et Unreal (`.mcp.json` fourni) → `jeu/installation/INSTALLATION.md`
- [ ] Créer le projet Unreal (modèle « Third Person », World Partition activé)
- [ ] Tutoriels : Landscape, PCG, MetaHuman, Chaos Vehicles, Behavior Trees

## Phase 2 — Prototype « gris » de l'île (mois 3–5)

- [x] Heightmap de l'île importée
- [x] Blockout (formes simples) de Port-Néré, Akwéri, Bomé, du camp
- [ ] Personnage jouable : marcher, courir, nager, se mettre à couvert, tirer
- [x] Une moto et une pirogue conduisibles
- [ ] Un ennemi avec IA de base (patrouille, détection, combat)
- [x] Mission 4 « Première Étincelle » jouable en version grise
- **Validation :** est-ce que c'est amusant même sans graphismes ?

## Phase 3 — Systèmes de base (mois 5–9)

- [ ] Libération de zone + changement visuel
- [ ] Jauge de confiance, système d'alerte
- [ ] Coopérative (version simple)
- [x] Civils avec routines, cycle jour/nuit, météo
- [x] Sauvegarde/chargement, carte en jeu, téléphone (Zala Money, preuves, radio)

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

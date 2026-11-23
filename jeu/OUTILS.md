# Outils indispensables et connecteurs Claude

Priorité : **gratuit** ou **gratuit jusqu'à un seuil**. Les prix et licences changent : vérifier
la page officielle avant de s'engager (état vérifié en novembre 2026).

## 0. Point important : où travaille Claude ?

Il existe deux sortes de « connecteurs » :

| Type | Où ça tourne | Exemples | Comment l'activer |
|---|---|---|---|
| **Connecteurs claude.ai** | Dans le cloud, s'activent en un clic | GitHub, Google Drive, Notion, Figma, Canva | claude.ai → Paramètres → Connecteurs |
| **Serveurs MCP locaux** | Sur **votre PC**, à côté du logiciel | Unreal Engine, Blender | Claude Code ou Claude Desktop installé sur le PC + une commande d'installation |

Unreal Engine et Blender doivent tourner **sur votre ordinateur** (avec une bonne carte
graphique). Claude les pilote depuis Claude Code ou Claude Desktop installé sur ce même PC.
La session cloud actuelle (sans écran ni carte graphique) sert à la conception, aux documents
et au code ; la production 3D se fera sur votre machine.

## 1. Logiciels de création (tous gratuits)

| Besoin | Outil | Coût | Rôle dans le projet |
|---|---|---|---|
| **Moteur de jeu** | **Unreal Engine 5** | Gratuit ; 5 % de royalties seulement au-delà de 1 M$ de revenus bruts par jeu | Rendu réaliste (Lumen/Nanite), monde ouvert (World Partition), PCG, véhicules (Chaos), IA |
| Humains réalistes | **MetaHuman** (intégré à Unreal) | Gratuit dans Unreal | Personnages principaux et PNJ, toutes carnations et morphologies |
| Modélisation 3D | **Blender** | Gratuit, open source | Bâtiments, objets, véhicules, armes fictives |
| Textures | **Material Maker**, **ArmorPaint** (ou Substance plus tard) | Gratuit / très bas coût | Matériaux : latérite, tôle rouillée, banco, wax |
| Terrain | **Gaea** (version Community) ou **World Machine** (version basique) | Gratuit pour usage non commercial ou limité | Détail fin du relief (érosion, rochers) |
| Cartographie / SIG | **QGIS** | Gratuit, open source | Explorer les données satellites, choisir les « jumeaux réels » |
| Données géographiques | **Copernicus DEM, Sentinel-2, ESA WorldCover, Natural Earth** | Gratuites (mention obligatoire) | Relief et paysages réels — voir [GEOGRAPHIE-REELLE.md](GEOGRAPHIE-REELLE.md) |
| Peinture / concept art | **Krita**, **GIMP** | Gratuit | Croquis, cartes, affiches fictives |
| Vectoriel / UI | **Inkscape**, **Figma** (plan gratuit) | Gratuit | Logos, HUD, menus |
| Animations | **Mixamo** (Adobe) | Gratuit | Animations de base (marche, course, combat) en attendant la motion capture |
| Motion capture à petit prix | **Move.ai** / **Rokoko Video** (offres gratuites limitées) | Gratuit limité | Mocap à partir d'une simple vidéo |
| Son | **Audacity**, **Reaper** (essai), **LMMS** | Gratuit | Montage audio, ambiance |
| Musique | **LMMS**, **Cakewalk** | Gratuit | Musiques originales des radios fictives |
| Versionnage du code | **Git + GitHub** | Gratuit | Code C++, configs, documents |
| Versionnage des gros fichiers 3D | **Perforce P4 (Helix Core)** | Gratuit jusqu'à 5 utilisateurs | Standard de l'industrie pour Unreal (fichiers de plusieurs Go) |
| Gestion de projet | **Notion** ou **Trello** / **Linear** (plans gratuits) | Gratuit | Tâches, bugs, planning |
| Communication équipe | **Discord** | Gratuit | Équipe, testeurs, communauté |

## 2. Banques de ressources gratuites (vérifier chaque licence)

| Ressource | Licence | Usage |
|---|---|---|
| **Poly Haven** | CC0 (libre, même commercial) | Textures, ciels HDRI, modèles |
| **ambientCG** | CC0 | Textures PBR |
| **Fab** (marché d'Epic, ex-Quixel/Megascans) | Contenus gratuits mensuels + payants | Rochers, plantes, sols scannés |
| **Freesound** | CC0 / CC-BY selon le son | Bruitages (marché, pluie, moto) |
| **Sketchfab** (filtre « téléchargeable + CC ») | Variable | Références et modèles libres |

**Règle :** tenir un registre `CREDITS.md` de chaque ressource externe (source, licence, auteur).

## 3. Connecteurs Claude

### 3.a Déjà connectés à votre compte (utilisables tout de suite)

| Connecteur | Usage dans le jeu |
|---|---|
| **GitHub** | Dépôt du projet, code, documents de conception, suivi des tâches (Issues) |
| **Google Drive / Google Docs** | Bible du jeu partagée, scénario, dialogues, tableaux de missions |
| **Canva** | Planches d'ambiance (moodboards), affiches fictives, logos de factions |
| **Gamma** | Présentation (« pitch deck ») pour partenaires et financeurs |
| **ElevenLabs** | Voix provisoires des personnages, ambiances (offre gratuite limitée en crédits) |
| **Notion** | Connexion **à terminer** sur claude.ai → idéal comme wiki et tableau de production |

### 3.b À ajouter depuis claude.ai (plans gratuits disponibles)

| Connecteur | Pourquoi |
|---|---|
| **Figma** | Maquettes du HUD, menus, téléphone du héros, carte en jeu |
| **Whimsical** | Arbres de missions, organigrammes des factions, schémas de systèmes |
| **Todoist** ou **Linear** | Liste de tâches quotidienne si on ne prend pas Notion |

### 3.c Serveurs MCP locaux (gratuits, open source) — les plus importants pour la 3D

| Serveur | Ce que Claude peut faire | Configuration |
|---|---|---|
| **Blender MCP** (`mcp-for-blender`, ex-`blender-mcp`, licence MIT) | Créer et modifier des scènes 3D, voir la vue 3D, chercher des modèles Sketchfab | Déclaré dans `.mcp.json` à la racine du dépôt ; extension Blender installée par le script |
| **Unreal Engine MCP** (`unreal-engine-mcp`, licence MIT, Unreal 5.0+, testé sur 5.8) | 162 outils : acteurs, niveaux, Blueprints, matériaux, import, compilation… | Déclaré dans `.mcp.json` ; projet préparé par `configurer-projet-unreal.ps1` |
| **Git / système de fichiers** | Intégrés à Claude Code | Rien à installer |

`unreal-engine-mcp` a été préféré à UEMCP, qui n'est donné compatible que jusqu'à Unreal 5.6.

**Installation complète : [installation/INSTALLATION.md](installation/INSTALLATION.md)**
(script automatique pour Windows, configuration du projet Unreal, liste de contrôle).

## 4. Matériel minimum recommandé (PC de développement)

| Composant | Minimum | Confortable |
|---|---|---|
| Processeur | 8 cœurs (Ryzen 7 / Core i7 récent) | 12–16 cœurs |
| Mémoire vive | 32 Go | 64 Go |
| Carte graphique | RTX 3060 12 Go | RTX 4070 / 4080 ou supérieure |
| Stockage | SSD NVMe 1 To | 2 To NVMe + disque de sauvegarde |
| Système | Windows 10/11 64 bits | — |

## 5. Talents à réunir progressivement

Même avec Claude, certains rôles humains sont indispensables : directeur artistique, artistes
3D/environnement, animateur, concepteur de niveaux, compositeur, comédiens de doublage
(accents authentiques), testeurs, et des **consultants culturels** de plusieurs pays africains.
Les écoles d'art et la communauté Discord du projet sont de bons viviers.

# Cartographie de la République de Wanzala

Voir aussi : [carte-monde.svg](carte-monde.svg) et [carte-ile-kassa.svg](carte-ile-kassa.svg).

## 1. Vue d'ensemble

Superficie jouable totale visée (jeu complet) : **≈ 120 km²** (GTA V ≈ 80 km²). On ne la
construit **pas** d'un coup : chaque acte ajoute une région. L'île seule fait ≈ 4 km².

| # | Région | Taille | Biomes | Débloquée | Ville / lieux clés |
|---|---|---|---|---|---|
| 1 | **Île de Kassa** | ~4 km² | Plage, cocoteraie, mangrove, colline volcanique, forêt | Début (Acte 1) | Port-Néré (petite ville), 3 villages, camp du Cobra |
| 2 | **Côte de Lagunaville** | ~18 km² | Lagune, mangroves, plages, zones industrielles | Acte 2 | Lagunaville (ville moyenne), port à conteneurs, raffinerie, bidonville sur pilotis |
| 3 | **Plateau d'Ébène** | ~30 km² | Savane arborée, champs, baobabs, villages | Acte 3 | Bourg de Sanké, grandes plantations, aérodrome de brousse |
| 4 | **Forêt de la Mbali** | ~25 km² | Forêt dense humide, fleuve, cascades | Acte 3 | Mines d'or illégales, base du Général Okapi, scierie |
| 5 | **Monts Kouré** | ~20 km² | Hauts plateaux, thé, brouillard, falaises | Acte 4 | Barrage hydroélectrique, relais télécom, ville de Kouré |
| 6 | **Port-Wanzala (capitale)** | ~23 km² | Grande ville : centre d'affaires, quartiers populaires, palais | Acte 5 | Palais présidentiel, ministères, aéroport international, stade, cathédrale, grand marché |

Liaisons : bac et pirogues (île ↔ côte), route nationale côtière, fleuve Mbali navigable,
voie ferrée minière (plateau ↔ capitale), aérodromes.

## 2. L'île de Kassa en détail (zone de départ)

Île volcanique de ≈ 2,5 km × 1,6 km, orientée nord-est / sud-ouest, à ~3 km de la côte.

| Zone | Description | Gameplay |
|---|---|---|
| **Port-Néré** (sud-ouest) | Petite ville de ~2 000 habitants : port de pêche, marché, église, mosquée, maquis, station-service, gendarmerie corrompue, maison familiale du héros | Hub : planque, garage, marché, premières missions ; ville **occupée** au départ (barrages, couvre-feu) |
| **Quai et entrepôts** | Port de pêche + entrepôt du Cobra (stockage de la récolte illicite) | Mission d'infiltration, poursuite en pirogue |
| **Village d'Akwa** (ouest, littoral) | Pêcheurs, pirogues, fumoirs à poisson | Premier village libéré, tutoriel de confiance |
| **Village de Bomé** (centre) | Cultivateurs de manioc et cacao | Champs illicites à brûler, première coopérative |
| **Village de Tiko** (est) | Village isolé dans la forêt, otages | Mission de sauvetage nocturne |
| **Cocoteraie et plantations** (nord) | Grandes parcelles saisies par la milice | Zone de champs ennemis, patrouilles |
| **Mont Kassa** (centre, ~300 m) | Ancien volcan, grottes, antenne radio | Point de vue, relais radio à saboter, chemin d'escalade |
| **Mangrove du Nord-Est** | Chenaux étroits, cabane de contrebandiers | Pirogue, furtivité |
| **Camp du Cobra** (est, ancienne mission catholique) | Quartier général fortifié du Commandant Mamba | Mission finale de l'acte 1 |
| **Phare de la Pointe** (sud-est) | Phare abandonné | Planque secrète, objets à collecter |
| **Piste d'atterrissage** (nord) | Piste de terre des trafiquants | Avion de contrebande à intercepter |

### Ordre de libération de l'île

```
Port-Néré (arrivée, occupé)
   └─> Akwa (village de pêcheurs) ─> Quai/entrepôts
          └─> Bomé (1re coopérative) ─> Cocoteraie/plantations
                 └─> Mont Kassa (radio) ─> Tiko (otages) ─> Mangrove ─> Piste
                        └─> Camp du Cobra (fin de l'acte 1) ─> Port-Néré libérée ─> Bac vers la côte
```

### Ce qui change visuellement à la libération

| Avant | Après |
|---|---|
| Barrages, drapeaux du Cobra, couvre-feu, rues vides la nuit | Barrages démontés, drapeaux de la coopérative, maquis animés |
| Champs illicites gardés | Champs de manioc/cacao, villageois au travail |
| Marché à moitié fermé | Marché plein, nouveaux marchands, prix plus bas |
| Pas d'électricité le soir | Lampadaires solaires, musique, fêtes |

## 3. Échelle et règles de construction (pour l'équipe)

- Unité : **1 unité Unreal = 1 cm**. Une rue de ville : 8–12 m ; une case : 4–6 m de diamètre.
- Terrain de l'île : heightmap 4 033 × 4 033 (≈ 1 m par pixel) — standard Unreal Landscape.
- **World Partition** activé dès le départ (même pour l'île) pour que l'extension aux autres
  régions soit naturelle.
- Densité : la végétation et les objets décoratifs seront placés via **PCG** (graphes
  procéduraux), les bâtiments importants placés à la main.
- Chaque lieu nommé possède une fiche (rôle, ambiance, références photo, missions liées).

## 4. Prochaines étapes cartographiques

1. Valider le tracé de l'île (cette version est un brouillon).
2. Dessiner la carte de l'île à l'échelle dans un outil (Gaea / World Machine / Krita).
3. Produire la heightmap, l'importer dans Unreal, faire un « blockout » (formes grises) de
   Port-Néré et se promener dedans pour vérifier les distances et le rythme.
4. Seulement ensuite : textures, végétation, bâtiments définitifs.

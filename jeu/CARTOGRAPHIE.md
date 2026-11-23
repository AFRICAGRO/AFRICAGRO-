# Cartographie de la République de Wanzala

Voir aussi : [carte-afrique-fictive.svg](carte-afrique-fictive.svg) (Wanzala sur la vraie carte de
l'Afrique), [carte-monde.svg](carte-monde.svg), [carte-ile-talanke.svg](carte-ile-talanke.svg) et
[GEOGRAPHIE-REELLE.md](GEOGRAPHIE-REELLE.md) (relief et images satellites réels).

## 1. Vue d'ensemble

Superficie jouable totale visée (jeu complet) : **≈ 120 km²** (GTA V ≈ 80 km²). On ne la
construit **pas** d'un coup : chaque acte ajoute une région. L'île seule fait ≈ 5 km².

| # | Région | Taille | Biomes | Débloquée | Ville / lieux clés |
|---|---|---|---|---|---|
| 1 | **Île de Talanké** | ~5 km² | Plage, cocoteraie, mangrove, colline volcanique, forêt | Début (Acte 1) | Port-Néré (petite ville), 3 villages, camp du Cobra |
| 2 | **Côte de Lagunaville** | ~18 km² | Lagune, mangroves, plages, zones industrielles | Acte 2 | Lagunaville (ville moyenne), port à conteneurs, raffinerie, bidonville sur pilotis |
| 3 | **Plateau d'Ébène** | ~30 km² | Savane arborée, champs, baobabs, villages | Acte 3 | Bourg de Sanké, grandes plantations, aérodrome de brousse |
| 4 | **Forêt de la Mbali** | ~25 km² | Forêt dense humide, fleuve, cascades | Acte 3 | Mines d'or illégales, base du Général Okapi, scierie |
| 5 | **Monts Kouré** | ~20 km² | Hauts plateaux, thé, brouillard, falaises | Acte 4 | Barrage hydroélectrique, relais télécom, ville de Kouré |
| 6 | **Port-Wanzala (capitale)** | ~23 km² | Grande ville : centre d'affaires, quartiers populaires, palais | Acte 5 | Palais présidentiel, ministères, aéroport international, stade, cathédrale, grand marché |

Liaisons : bac et pirogues (île ↔ côte), route nationale côtière, fleuve Mbali navigable,
voie ferrée minière (plateau ↔ capitale), aérodromes.

## 2. L'île de Talanké en détail (zone de départ)

Île volcanique d'environ 5 km² et 290 m d'altitude, avec un lac de cratère. Son relief est **tiré
de données satellites réelles** (île d'Annobón réduite de moitié, tournée et retournée) :
[terrains/ile-depart/](terrains/ile-depart/). La carte [carte-ile-talanke.svg](carte-ile-talanke.svg)
place les lieux sur l'image satellite réelle : la ville est au nord, sur la seule zone plate et
déjà habitée ; l'intérieur est une forêt volcanique en pente.

| Zone | Description | Gameplay |
|---|---|---|
| **Port-Néré** (nord, plaine côtière) | Petite ville de ~2 000 habitants : port de pêche, marché, église, mosquée, maquis, station-service, gendarmerie corrompue, maison familiale du héros | Hub : planque, garage, marché, premières missions ; ville **occupée** au départ (barrages, couvre-feu) |
| **Quai et entrepôts** (nord-ouest, jetée) | Port de pêche + entrepôt du Cobra (stockage de la récolte illicite) ; arrivée du bac | Mission d'infiltration, poursuite en pirogue |
| **Piste d'atterrissage** (nord, à la sortie de la ville) | Piste des trafiquants | Avion de contrebande à intercepter |
| **Phare de la Pointe** (pointe nord-est) | Phare abandonné | Planque secrète, objets à collecter |
| **Plantations** (ouest, clairières rouges) | Grandes parcelles saisies par la milice | Zone de champs ennemis, patrouilles |
| **Village de Bomé** (centre-ouest, ~150 m) | Cultivateurs de manioc et cacao, sur les pentes | Champs illicites à brûler, première coopérative |
| **Village d'Akwa** (côte ouest) | Pêcheurs, pirogues, fumoirs à poisson | Premier village libéré, tutoriel de confiance |
| **Lac du cratère** (centre) | Ancien cratère rempli d'eau, entouré de forêt | Lieu sacré, point de rencontre secret de la résistance |
| **Mont Talanké** (≈ 290 m, au sud du lac) | Sommet boisé, grottes, antenne radio | Point de vue, relais radio à saboter, sentier d'escalade |
| **Village de Tiko** (côte est) | Village isolé, otages | Mission de sauvetage nocturne |
| **Camp du Cobra** (sud-est, ancienne mission catholique) | Quartier général fortifié du Commandant Mamba | Mission finale de l'acte 1 |
| **Baie du Sud** (mangrove à créer) | Côte découpée, chenaux et cabane de contrebandiers | Pirogue, furtivité (mission « Le Chenal ») |

### Ordre de libération de l'île

```
Port-Néré (arrivée, occupé)
   └─> Akwa (village de pêcheurs) ─> Quai/entrepôts
          └─> Bomé (1re coopérative) ─> Plantations
                 └─> Mont Talanké (radio) ─> Tiko (otages) ─> Baie du Sud ─> Piste
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
- Terrain de l'île : heightmap 2 017 × 2 017 (2,67 m par pixel), déjà générée à partir de données
  réelles ; on pourra monter à 4 033 × 4 033 pour plus de détail.
- **World Partition** activé dès le départ (même pour l'île) pour que l'extension aux autres
  régions soit naturelle.
- Densité : la végétation et les objets décoratifs seront placés via **PCG** (graphes
  procéduraux), les bâtiments importants placés à la main.
- Chaque lieu nommé possède une fiche (rôle, ambiance, références photo, missions liées).

## 4. Prochaines étapes cartographiques

1. ~~Valider le tracé de l'île~~ → relief réel généré ; ~~choisir le nom~~ → île de Talanké.
2. ~~Replacer les lieux sur le vrai relief~~ → fait (carte-ile-talanke.svg v0.2).
3. Importer la heightmap dans Unreal, faire un « blockout » (formes grises) de
   Port-Néré et se promener dedans pour vérifier les distances et le rythme.
4. Seulement ensuite : textures, végétation, bâtiments définitifs.

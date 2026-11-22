# Géographie réelle : vraie Afrique, pays fictifs

**Réponse courte : oui.** On peut utiliser la vraie carte de l'Afrique et de vraies données
satellites pour le relief, la végétation et les couleurs, tout en inventant les pays et leurs
frontières. C'est même la meilleure façon de représenter fidèlement l'Afrique. Ce document
explique comment, avec quelles données gratuites, et quelles précautions prendre.

Fichiers produits :

| Fichier | Contenu |
|---|---|
| [carte-afrique-fictive.svg](carte-afrique-fictive.svg) | Afrique réelle (côtes, fleuves, lacs) découpée en 29 pays fictifs |
| [terrains/ile-depart/](terrains/ile-depart/) | Terrain de l'île de départ tiré de vraies données satellites, prêt pour Unreal |
| [outils-geo/terrain_reel.py](outils-geo/terrain_reel.py) | Outil : n'importe quel lieu d'Afrique → heightmap Unreal + image satellite |
| [outils-geo/carte_afrique.py](outils-geo/carte_afrique.py) | Outil : régénère la carte des pays fictifs (modifier noms et positions dans le fichier) |

## 1. Deux niveaux de carte

L'Afrique fait 30 millions de km² ; un grand monde ouvert en fait environ 100. On ne peut donc
pas reproduire tout le continent à l'échelle 1:1. On travaille sur deux niveaux :

| Niveau | Ce qui est réel | Ce qui est inventé | Usage dans le jeu |
|---|---|---|---|
| **Carte du continent** | Forme de l'Afrique, côtes, fleuves, lacs, déserts, forêts | Frontières, noms des pays, capitales | Menu, voyages entre actes, actualités, contexte politique |
| **Zones jouables** | Relief, végétation, couleurs du sol, profil des côtes, tirés de lieux réels | Villes, villages, routes, noms des lieux, histoire | Ce que le joueur parcourt réellement |

Chaque zone jouable a un **« jumeau réel »** : un lieu existant dont on prend le relief et les
couleurs, puis qu'on **tourne, retourne, réduit et retouche** pour qu'il ne soit pas
identifiable. On peut aussi assembler plusieurs lieux réels dans une même région.

## 2. Jumeaux réels proposés

| Zone du jeu | Lieu réel servant de modèle | Pourquoi | État |
|---|---|---|---|
| Île de départ | **Annobón** (Guinée équatoriale) | Île volcanique, lac de cratère, forêt, côtes rocheuses | ✅ Terrain généré (échelle 0,5 ; tourné de 35° ; en miroir) |
| Côte de Lagunaville | Lagune Ébrié (Côte d'Ivoire) ou lagunes du golfe du Bénin | Lagunes, mangroves, cordons de sable | À générer |
| Plateau d'Ébène | Plateau de l'Adamaoua (Cameroun) ou savanes du nord du Ghana | Savane arborée, plateaux | À générer |
| Forêt de la Mbali | Bassin de l'Ogooué (Gabon) | Forêt dense, grand fleuve, rapides | À générer |
| Monts Kouré | Hauts plateaux de l'Ouest du Cameroun / Fouta-Djallon (Guinée) | Reliefs verts, chutes, terrasses | À générer |
| Port-Wanzala (capitale) | Site côtier en baie + urbanisme inventé | Ville construite à la main | À concevoir |

Mélanger des modèles de **plusieurs pays** renforce le caractère fictif de Wanzala.

## 3. L'île de départ, résultat obtenu

| Mesure | Valeur dans le jeu |
|---|---|
| Surface des terres | ≈ 5,1 km² |
| Point culminant | ≈ 290 m (le « Mont Kassa » du document de conception, avec son lac de cratère) |
| Heightmap | 2017 × 2017 pixels, 16 bits, 2,67 m par pixel |
| Import Unreal | Échelle X = Y = 267,01 ; Z = 120 (voir `ile-depart_infos.json`) |

Le relief réel vient du modèle **Copernicus DEM** (30 m de résolution) ; Unreal et des outils
comme Gaea ajouteront le détail fin (rochers, ravines, plages). L'image **Sentinel-2** (10 m)
sert de **guide** pour peindre la végétation, les plages et les zones habitées. Elle ne sert
pas de texture finale : vue de près dans le jeu, elle serait floue.

Pour importer dans Unreal : *Landscape Mode → Import from File →* `ile-depart_heightmap_2017.png`,
puis saisir l'échelle X/Y/Z indiquée.

## 4. Données gratuites autorisées

| Donnée | Source | Résolution | Licence | Mention obligatoire |
|---|---|---|---|---|
| Relief | **Copernicus DEM GLO-30** | 30 m | Gratuite, usage commercial permis | Oui (voir `*_infos.json`) |
| Relief (alternative) | **NASADEM / SRTM** (NASA) | 30 m | Domaine public | Recommandée |
| Images couleur | **Sentinel-2** (Copernicus) | 10 m | Gratuite, usage commercial permis | « Contient des données Copernicus Sentinel modifiées [année] » |
| Images (alternative) | **Landsat 8/9** (USGS) | 30 m | Domaine public | Recommandée |
| Occupation des sols | **ESA WorldCover** | 10 m | CC BY 4.0 | Oui — utile pour placer forêts/champs automatiquement (PCG) |
| Côtes, fleuves, lacs | **Natural Earth** | Carte continentale | Domaine public | Non |
| Routes, bâtiments (référence) | **OpenStreetMap** | Détaillé | ODbL | Oui ; à utiliser comme **inspiration** pour l'urbanisme, pas copié tel quel |

**Interdit :** extraire des images ou du relief de **Google Earth / Google Maps / Bing Maps**.
Leurs conditions d'utilisation l'interdisent, même pour un usage personnel dans un jeu.

Toutes les mentions seront regroupées dans les crédits du jeu (fichier `CREDITS.md` à tenir à jour).

## 5. Précautions politiques et juridiques

1. **Pas de frontières réelles, pas de vrais noms d'États ni de dirigeants.** Les frontières de la
   carte sont générées automatiquement et traversent les frontières réelles. Précédent : en 2017,
   la Bolivie a protesté officiellement auprès de la France contre *Ghost Recon Wildlands*, qui
   montrait la vraie Bolivie gouvernée par un cartel.
2. **Wanzala ne doit correspondre à aucun pays réel en particulier.** Dans ce brouillon, elle
   recouvre une partie de plusieurs pays du golfe de Guinée ; sa position peut encore bouger
   (une seule ligne à changer dans `carte_afrique.py`).
3. **Attention aux noms qui existent déjà.** Vérification faite : une vraie **île de Kassa**
   existe dans les îles de Loos, en face de Conakry (Guinée). Je recommande de **renommer**
   notre île de départ pour éviter toute confusion (à vous de choisir le nom).
4. Les noms des 29 pays fictifs sont des propositions ; il faudra vérifier qu'aucun ne
   correspond à une ethnie, une région ou une marque existante.

## 6. Prochaines étapes

- [ ] Choisir le nouveau nom de l'île de départ
- [ ] Valider (ou déplacer) la position de Wanzala et les noms des pays
- [ ] Générer les terrains des autres régions avec `terrain_reel.py`
- [ ] Ajouter le relief ombré à la carte du continent et la carte d'occupation des sols (ESA WorldCover)
- [ ] Sur le PC de développement : importer la heightmap dans Unreal et faire une première promenade

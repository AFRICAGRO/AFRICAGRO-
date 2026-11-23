# Géographie réelle : vraie Afrique, pays fictifs

**Réponse courte : oui.** On peut utiliser la vraie carte de l'Afrique et de vraies données
satellites pour le relief, la végétation et les couleurs, tout en inventant les pays et leurs
frontières. C'est même la meilleure façon de représenter fidèlement l'Afrique. Ce document
explique comment, avec quelles données gratuites, et quelles précautions prendre.

Fichiers produits :

| Fichier | Contenu |
|---|---|
| [carte-afrique-fictive.svg](carte-afrique-fictive.svg) | Afrique réelle (côtes, fleuves, lacs) découpée en 29 pays fictifs |
| [terrains/](terrains/) | Terrains des 5 régions tirés de vraies données satellites, prêts pour Unreal (tableau et aperçu) |
| [outils-geo/terrain_reel.py](outils-geo/terrain_reel.py) | Outil : n'importe quel lieu d'Afrique → heightmap Unreal + image satellite |
| [outils-geo/chercher_scene.py](outils-geo/chercher_scene.py) | Outil : trouve l'image satellite la moins nuageuse au-dessus d'une zone |
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
| Côte de Lagunaville | Cordon littoral et lagune Ébrié, vers Jacqueville (Côte d'Ivoire) | Océan, plage, cordon sableux habité, lagune | ✅ Généré (rotation −20°, miroir) |
| Plateau d'Ébène | Plateau de l'Adamaoua, vers Ngaoundéré (Cameroun) | Savane arborée, champs, galeries forestières, pitons | ✅ Généré (rotation 120°) |
| Forêt de la Mbali | Fleuve Ogooué, vers Lambaréné (Gabon) | Forêt dense, grand fleuve, bancs de sable | ✅ Généré (rotation 75°, miroir) |
| Monts Kouré | Monts Bamboutos (Cameroun) | Crêtes, vallées cultivées en terrasses, 1 450 m de dénivelé | ✅ Généré (rotation −40°) |
| Port-Wanzala (capitale) | Presqu'île de Freetown (Sierra Leone) | Plaine côtière pour le centre-ville et le port, collines jusqu'à 750 m pour les quartiers riches et le palais, plages, baie et estuaire | ✅ Généré (rotation 160°, miroir) — voir §2 bis |

Mélanger des modèles de **plusieurs pays** (ici Guinée équatoriale, Côte d'Ivoire, Cameroun, Gabon, Sierra Leone)
renforce le caractère fictif de Wanzala. Détails, échelles d'import et limites : [terrains/README.md](terrains/README.md).

## 2 bis. Pourquoi la presqu'île de Freetown pour la capitale

Trois sites ont été comparés sur leur relief réel : la presqu'île de Freetown (Sierra Leone),
la côte de Limbé au pied du mont Cameroun, et Cape Coast (Ghana).

| Critère pour une grande ville de jeu | Freetown | Limbé | Cape Coast |
|---|---|---|---|
| Plaine côtière pour le centre, le port, les quartiers populaires | ✅ | Étroite | ✅ |
| Collines dominant la ville (quartiers riches, palais, poursuites en lacets) | ✅ jusqu'à 750 m | ✅ volcan de 4 000 m, trop grand | ❌ presque plat |
| Plages, baies, estuaire, presqu'île (variété, port, aéroport) | ✅ | Partiel | Partiel |
| Ville déjà dense sur l'image (guide pour les rues et les quartiers) | ✅ | Petite ville | Petite ville |

C'est le même principe que les grandes villes de jeux en monde ouvert : un centre plat au bord
de l'eau, des collines chics au-dessus, et la nature tout autour. Le palais présidentiel sera
placé sur une crête qui domine toute la ville, et on le verra de partout.

**Précautions propres à ce choix :**
- Freetown est une vraie capitale. Le terrain est donc **retourné en miroir et tourné de 160°**,
  et toute la ville sera **reconstruite de zéro** : aucune rue, aucun bâtiment ni monument réel.
- La Sierra Leone a connu une guerre civile liée aux rebelles et aux diamants. Notre histoire
  (rebelles, mines, corruption) pourrait y faire penser si le site était reconnaissable : c'est
  une raison de plus de le transformer, et de ne jamais reprendre de faits, de noms ou d'images
  de cette guerre.
- **Alternative** si vous préférez éviter tout rapprochement : la côte de Limbé (Cameroun), avec
  le volcan en toile de fond, mais une plaine plus étroite pour la ville.

## 3. L'île de départ, résultat obtenu

| Mesure | Valeur dans le jeu |
|---|---|
| Surface des terres | ≈ 5,1 km² |
| Point culminant | ≈ 290 m (le « Mont Talanké » du document de conception, avec son lac de cratère) |
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
3. **Attention aux noms qui existent déjà.** Une vraie **île de Kassa** existe dans les îles
   de Loos, en face de Conakry (Guinée) : notre île de départ a donc été **renommée île de
   Talanké** (aucun lieu réel connu sous ce nom). **Wanzala** n'existe pas non plus : conservé.
4. Les noms des 29 pays fictifs sont des propositions ; il faudra vérifier qu'aucun ne
   correspond à une ethnie, une région ou une marque existante.

## 6. Prochaines étapes

- [x] Nouveau nom de l'île de départ : **Talanké**
- [x] Wanzala conservé à sa position
- [ ] Valider les noms des 28 autres pays fictifs
- [x] Générer les terrains des autres régions (côte, plateau, forêt, monts)
- [x] Choisir le modèle de la capitale Port-Wanzala et générer son terrain (presqu'île de Freetown)
- [ ] Ajouter le relief ombré à la carte du continent et la carte d'occupation des sols (ESA WorldCover)
- [ ] Sur le PC de développement : importer la heightmap dans Unreal et faire une première promenade

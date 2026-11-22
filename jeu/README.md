# TERRE LIBRE — Dossier de conception (GDD v0.1)

> Titre provisoire. Jeu d'action-aventure en monde ouvert, en 3D réaliste, à la troisième personne.
> Ce dossier est le **document de référence** : toute décision de conception y est consignée avant
> d'être produite. On avance lentement et proprement : chaque étape est validée avant la suivante.

| Document | Contenu |
|---|---|
| [README.md](README.md) | Vision, histoire, mécaniques, factions (ce fichier) |
| [CARTOGRAPHIE.md](CARTOGRAPHIE.md) | Le monde, les régions, l'île de départ en détail, l'ordre de déblocage |
| [GEOGRAPHIE-REELLE.md](GEOGRAPHIE-REELLE.md) | Vraie Afrique + pays fictifs, données satellites, licences, précautions |
| [carte-afrique-fictive.svg](carte-afrique-fictive.svg) | Afrique réelle découpée en pays fictifs |
| [terrains/](terrains/) | Terrains tirés de vraies données satellites (île de départ prête) |
| [outils-geo/](outils-geo/) | Outils : lieu réel → terrain Unreal ; régénération de la carte |
| [carte-monde.svg](carte-monde.svg) | Carte schématique du monde |
| [carte-ile-kassa.svg](carte-ile-kassa.svg) | Carte schématique de l'île de départ |
| [MISSIONS.md](MISSIONS.md) | Arc narratif et liste des missions de l'acte 1 |
| [OUTILS.md](OUTILS.md) | Logiciels, connecteurs Claude (gratuits en priorité), matériel |
| [FEUILLE-DE-ROUTE.md](FEUILLE-DE-ROUTE.md) | Phases de production, jalons, ce qu'il faut pour commencer |

---

## 1. Vision en une phrase

Un enfant du pays revient sur son île natale occupée par une milice, la libère village après
village, puis remonte toute la chaîne — trafiquants, seigneurs de guerre, ministres, président —
pour **rendre la terre à ceux qui la cultivent**.

## 2. Ce qui rend le jeu différent

1. **Libérer, puis reconstruire.** Chaque zone libérée n'est pas juste « nettoyée » : les champs
   illicites détruits deviennent des **coopératives agricoles** (cacao, manioc, anacarde, café, riz)
   qui produisent des revenus et des alliés. La libération est visible : marchés qui rouvrent,
   écoles, routes, lumière la nuit.
2. **Une progression verticale.** On commence contre des petits chefs locaux, on finit contre
   le sommet de l'État. Chaque acte change d'échelle (île → côte → intérieur → capitale).
3. **Le peuple est un système, pas un décor.** Une jauge de **Confiance** par région : protéger
   les civils, libérer les otages, partager les récoltes l'augmente ; les dégâts collatéraux la
   font chuter. La confiance débloque informateurs, planques, véhicules, recrues.
4. **Des choix moraux sur les chefs.** Arrêter et livrer à la justice, ou éliminer. Les
   conséquences changent la suite (témoins au procès, vengeance, stabilité de la région).

## 3. Cadre — un pays fictif (règle absolue)

Le jeu se déroule dans la **République fédérale de Wanzala**, pays fictif placé sur la **vraie
carte de l'Afrique** (golfe de Guinée), au milieu d'autres pays fictifs (voir
[GEOGRAPHIE-REELLE.md](GEOGRAPHIE-REELLE.md)). Les reliefs et paysages sont tirés de **vraies
données satellites** ; les frontières, les villes et les personnes sont inventées,, avec ses langues, ses drapeaux, ses monnaies, ses partis, ses personnages — **tous
inventés**. Raisons :

- **Juridique** : aucune attaque contre de vrais États, dirigeants, groupes ethniques ou partis
  (diffamation, interdiction de vente, problèmes de classification).
- **Créatif** : liberté totale sur la géographie et l'histoire.
- **Respect** : l'ennemi est la **corruption et le crime**, jamais un peuple. Les factions ennemies
  sont mixtes ; les alliés aussi.

L'inspiration visuelle (architecture, végétation, musique, tissus, cuisine, marchés) puise dans
toute l'Afrique, avec documentation sérieuse et, à terme, des consultants culturels.

## 4. Histoire (synopsis acte par acte)

**Héros :** *Kofi Adébayo Mensah* (nom provisoire), 32 ans, ancien ingénieur agronome parti
travailler à l'étranger. Il revient sur l'île de Kassa pour l'enterrement de son père, un chef de
coopérative assassiné. Il découvre que la milice du **Front du Cobra** a pris les terres, force
les paysans à cultiver des plantations illicites et contrôle le port.

| Acte | Lieu | Ennemi principal | Enjeu |
|---|---|---|---|
| **1 — L'Île** | Île de Kassa (Port-Néré + villages) | Front du Cobra, chef « Commandant Mamba » | Libérer l'île, rouvrir le port, créer la 1re coopérative |
| **2 — La Côte** | Ville côtière de Lagunaville, mangroves, raffinerie | Cartel portuaire, douaniers corrompus | Couper la route du trafic vers l'intérieur |
| **3 — La Savane et les Forêts** | Plateau agricole, forêt dense, fleuve | Seigneur de guerre « Général Okapi », mines illégales | Libérer les mines et les grandes plantations, rallier les régions |
| **4 — Les Montagnes** | Hauts plateaux, barrage hydroélectrique | Gouverneurs régionaux, armée privée | Prendre le contrôle de l'énergie et des communications |
| **5 — La Capitale** | Port-Wanzala (capitale) | Ministres, puis le président Ezéchiel Bantou | Révéler la corruption au monde, procès ou chute du régime |

Fil rouge : un **réseau de preuves** (documents, enregistrements, comptes) que le joueur
rassemble pour relier chaque chef local au sommet de l'État. La fin dépend de ce qui a été prouvé
et de la confiance du peuple (fin « justice », fin « révolution », fin « nouveau tyran »).

## 5. Boucle de jeu

```
Explorer → Renseigner (informateurs, drone, écoute) → Planifier (approche furtive ou frontale)
   → Mission (assaut, sabotage, sauvetage, poursuite) → Libérer la zone
   → Reconstruire (coopérative, marché, école) → Revenus + alliés + équipement
   → Zone suivante, ennemis plus puissants
```

## 6. Mécaniques principales

| Système | Description | Priorité |
|---|---|---|
| Déplacement à pied | Course, saut, escalade, nage, couverture | Indispensable (île) |
| Combat | Tir à la 3e personne, corps à corps, armes réalistes fictives | Indispensable |
| Furtivité | Cacher les corps, neutraliser sans tuer, détection visuelle/sonore | Indispensable |
| Véhicules | Motos, pick-up, pirogues motorisées, bateaux ; plus tard camions, hélicoptères | Moto + pirogue sur l'île |
| Monde vivant | Civils avec routines (marché, champs, pêche), cycle jour/nuit, météo (saison des pluies) | Indispensable |
| Libération de zones | Camps et champs ennemis à prendre, la zone change visuellement | Indispensable |
| Coopératives | Gestion légère : choisir les cultures, affecter des villageois, revenus | Acte 1 (version simple) |
| Confiance | Jauge par région, conséquences visibles | Indispensable |
| Recherche (« Alerte ») | Niveau d'alerte milice/police, renforts, barrages | Indispensable |
| Progression du héros | Compétences (agronomie, tir, furtivité, mécanique, leadership) | Acte 1 (simple) |
| Alliés | Recruter des compagnons ; ordres simples | Acte 2 |
| Téléphone | Missions, carte, Mobile Money (clin d'œil à AfriCard), radio | Acte 1 (simple) |

**Règles éthiques intégrées au gameplay :**
- Les civils ne sont **jamais** des cibles de mission ; les blesser fait chuter la confiance.
- Les **enfants soldats** ne sont jamais combattus : missions de **sauvetage** non létales uniquement.
- Les drogues/plantations sont détruites, jamais vendues par le joueur.

## 7. Factions

| Faction | Rôle | Exemples d'unités |
|---|---|---|
| **Les Racines** (alliés) | Résistance paysanne fondée par le héros | Fermiers, pêcheurs, mécanos, infirmière, ancienne journaliste |
| **Front du Cobra** | Milice de l'île, plantations illicites | Sentinelles, patrouilles moto, mitrailleur, chef de camp |
| **Le Syndicat des Docks** | Trafic portuaire, contrebande | Gros bras, snipers, douaniers corrompus |
| **Armée du Général Okapi** | Seigneur de guerre de l'intérieur | Soldats équipés, blindés légers |
| **Garde présidentielle** | Bras armé du régime | Forces spéciales, hélicoptères |
| **Civils** | Neutres, influencés par la confiance | Marchands, enfants, anciens, moto-taxis |

## 8. Direction artistique

- **Réalisme photographique**, lumière chaude et saturée de l'Afrique de l'Ouest, latérite rouge,
  verts profonds de la saison des pluies, ciel d'harmattan brumeux en saison sèche.
- **Villes** : maisons en parpaing et tôle, marchés couverts, maquis, églises et mosquées,
  stations-service, moto-taxis, peintures murales, panneaux publicitaires fictifs.
- **Villages** : cases en banco, greniers, puits, palabres sous le baobab, champs alentour.
- **Sons** : langues fictives inspirées des langues réelles + français/anglais, radios locales
  fictives avec musique originale (afrobeat, coupé-décalé, highlife, makossa… **compositions
  originales**, jamais de morceaux sous droits sans licence).

## 9. Fiche technique cible

| Élément | Choix | Justification |
|---|---|---|
| Moteur | **Unreal Engine 5** (dernière version stable) | Rendu réaliste (Lumen, Nanite), monde ouvert (World Partition), génération procédurale (PCG), humains réalistes (MetaHuman), gratuit jusqu'à 1 M$ de revenus |
| Plateforme d'abord | PC Windows | Développement et tests plus simples ; consoles plus tard |
| Langages | Blueprints + C++ | Prototyper en Blueprints, optimiser en C++ |
| Classification visée | PEGI 18 / ESRB M | Violence réaliste |
| Langues | Français, anglais au lancement | Puis portugais, swahili, arabe… |

## 10. Réalisme sur l'ambition

GTA V a demandé plusieurs centaines de développeurs pendant environ 5 ans. Notre stratégie pour
ne pas bâcler :

1. **Tranche verticale** : l'île de Kassa seule (≈ 5 km²), finie et belle, avec 10–12 missions.
   C'est notre « démo » pour trouver financement, partenaires et talents.
2. **Sortie épisodique possible** : Acte 1 vendu seul, financement des actes suivants.
3. **Monde construit de façon procédurale** (PCG Unreal + Claude pilotant l'éditeur) pour
   compenser la petite taille de l'équipe, puis retouché à la main.

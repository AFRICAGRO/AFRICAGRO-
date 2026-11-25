# WANZALA : FREEDOM — projet Godot (dossier TerreLibre)

Projet Godot 4 de l'île de Talanké. Rendu **Compatibilité** (OpenGL 3.3) pour tourner
sur un PC modeste avec carte graphique intégrée.

## Ouvrir le projet

1. Lancer Godot → **Importer** → choisir `jeu/godot/TerreLibre/project.godot`.
2. La première ouverture prend un moment : Godot prépare les fichiers.
3. Appuyer sur **F5** (ou le bouton ▶ en haut à droite) pour jouer.

## Commandes

| Touche | Action |
|---|---|
| Clic | Contrôler la caméra avec la souris |
| Z Q S D (ou W A S D, flèches) | Marcher |
| Maj | Courir |
| Espace | Sauter |
| C | S'accroupir / se relever (discrétion, meilleure précision) |
| F | Maîtriser un milicien par derrière · ligoter un milicien qui s'est rendu |
| Clic droit (maintenu) | Viser (caméra par-dessus l'épaule) |
| Clic gauche | Tirer |
| R | Recharger |
| 1 / 2 | Choix final face au lieutenant Dossou |
| P | Aller directement à Port-Néré (place de l'Indépendance) |
| N | Changer d'ambiance : heure dorée → midi harmattan → pluie → nuit → aube |
| Échap | Libérer la souris |

En haut à gauche : lieu actuel, ambiance, vitesse et **images par seconde (i/s)**.
Notez ce chiffre sur votre PC : c'est notre mesure de performance.

## Ce qui est en place (v0.2 — passage au réalisme)

| Élément | Fichier | État |
|---|---|---|
| Relief réel de l'île (5,4 km, 505 × 505 points) + collisions | `scripts/terrain.gd`, `data/talanke_505.f32` | ✅ |
| Sol photographié : sable, latérite, herbe, sol de forêt, roche (couleur + relief fin), guidé par le satellite | `shaders/terrain.gdshader`, `data/textures/` | ✅ |
| Ciels photographiés (HDRI) pour 5 ambiances, soleil aligné sur chaque ciel | `scripts/ambiances.gd`, `data/ciels/` | ✅ |
| Arbres réalistes (rendus de vrais arbres scannés, sur plans croisés, balancement au vent) | `scripts/vegetation.gd`, `shaders/imposteur.gdshader`, `data/arbres/` | ✅ |
| Cocotiers : tronc photographié, palmes découpées, courbure variée | `scripts/vegetation.gd` | ✅ |
| Mer animée qui s'assombrit sous la pluie et la nuit, lac du cratère | `shaders/water.gdshader` | ✅ |
| **Village d'Akwéri** (mission 4) : terrain aplani, 12 cases en banco et chaume, 2 maisons en planches et tôle, 5 fumoirs fumants, 9 pirogues peintes, mât au drapeau du Cobra, caisses et fûts, séchoirs à filets, cocotiers, repères de mission (départ, 3 vagues, civils, refuges) — disposition du blockout | `scripts/village_akweri.gd` | ✅ |
| Pluie, sol mouillé, harmattan (herbe sèche) | `scripts/ambiances.gd` | ✅ |
| Faris : vrai modèle humain (MakeHuman, morphologie africaine), chemise en wax original, pantalon, chaussures, cheveux courts | `personnages/faris.glb` | ✅ |
| **Habitants de Talanké** : 8 corps de plus avec le même squelette — 2 femmes (pagne, foulard), femme âgée, ancien, 2 hommes, **un garçon et une fille** ; chaque visage est unique ; **démarche féminine** propre (bassin qui balance, pas sur une ligne) ; 4 motifs wax originaux | `personnages/*.glb` | ✅ |
| Animations de Faris : repos, marche, course, saut, nage, accroupi, visée, rendu, ligoté, mort | `scripts/joueur.gd` | ✅ (animations faites à la main, voir plus bas) |
| **Nature autour du joueur** : vrais arbres en 3D (tronc, branches, écorce, rameaux feuillus qui bougent au vent) jusqu'à 70 m, puis les arbres photographiés au-delà ; touffes d'herbe (verte en forêt, sèche sur la plaine côtière), buissons, cailloux, feuilles mortes au pied des arbres. Construit par cases de 32 m autour de Faris | `scripts/vegetation_proche.gd`, `shaders/feuillage|ecorce|herbe.gdshader` | ✅ |
| **Visages et peau** : sourcils, lèvres, paupières et paumes plus claires peints dans chaque modèle ; grain de peau et pores ; cheveux crépus en relief ; lisière des cheveux et cols lissés ; **coiffures** : court, afro, chignon, macarons (fillette), foulard noué haut avec son nœud | `scripts/apparence.gd`, `outils/construire_personnage.py` | ✅ |
| **Vêtements variés** : pêcheurs torse nu en short, jeunes en tee-shirt et jean, anciens en grand boubou à manches longues ; démarche plus lente et dos un peu voûté des personnes âgées | `outils/construire_personnage.py` (variantes pecheur, homme3, ancien…) | ✅ |
| **Mer et plage** : couleur selon la profondeur réelle (lagon turquoise sur le sable, bleu profond au large), écume qui roule et se brise sur la plage ; mouettes qui tournent au-dessus du rivage le plus proche | `shaders/water.gdshader`, `scripts/oiseaux.gd` | ✅ |
| **Port-Néré** : ~430 bâtiments (parpaing enduit et peint, tôle rouillée ou neuve, persiennes, boutiques avec auvent et enseigne, immeubles à citerne, chantiers inachevés, concessions), boulevard du front de mer éclairé la nuit, avenue, ruelles en latérite avec poteaux électriques ; marché, église, mosquée, gendarmerie, station-service, maquis de Mama Rokia, maison de Faris, barrages du Cobra | `scripts/ville_port_nere.gd` | ✅ v1 |
| **Vie de Port-Néré** : passants (marchandes avec bassine sur la tête, enfants), motos-taxis avec client, taxis jaunes, voitures, pick-up de patrouille du Cobra avec deux miliciens, ~25 véhicules garés ; phares allumés la nuit ; chaises monobloc, casiers, bouteilles de gaz, bidons, pneus, groupes électrogènes, sacs de ciment, poubelles | `scripts/circulation.gd`, `vehicules/`, `props/` | ✅ v1 |
| **Mission 4 « Première Étincelle »** jouable de bout en bout (voir ci-dessous) | `scripts/mission4.gd`, `pnj.gd`, `arme.gd` | ✅ v1 |

## Mission 4 « Première Étincelle » — déroulé

1. **Sans arme** : approcher accroupi le milicien isolé près des fumoirs, F dans son dos → il est ligoté, Faris récupère son fusil.
2. **Vague 1** : 4 miliciens sur la plage. **Vague 2** : renforts en haut du village. **Vague 3** : le lieutenant Dossou et 2 gardes derrière les pirogues.
3. Les miliciens patrouillent, entendent les tirs, cherchent un abri (navigation calculée au lancement), tirent par rafales. Blessés, ils **se rendent** : F pour les ligoter (épargnés).
4. Les 12 villageois fuient vers les refuges et s'y cachent. Le jeu **refuse de tirer** quand un civil est sous le viseur.
5. Choix final face à Dossou : **1** le laisser partir, **2** le faire prisonnier (compte pour la fin « Justice »).
6. Libération : le drapeau du Cobra est remplacé par celui des Racines, la jauge **Confiance de l'île** apparaît. Mort de Faris : retour au refuge, la vague en cours recommence.

Limites connues de la v1 : pas encore de pick-up de la milice ni de diversion d'Ama ; les enfants sont des civils : ils ne peuvent jamais être blessés ; animations faites à la main en attendant une vraie capture de mouvement.

## Prochaines étapes

1. Mission 4 : pick-up de la milice, diversion d'Ama, voix.
2. Port-Néré : le quai et les entrepôts (mission 5), intérieurs, conduire soi-même une moto ou une voiture.
3. Moto et pirogue conduisibles.

## Faris et les habitants : comment ils sont faits

- Corps : **MakeHuman / MPFB2** (licence CC0), réglé en homme africain de 1,77 m, squelette **compatible Mixamo**.
- Vêtements : chemise au **motif wax créé pour le jeu** (original, sans droits tiers), pantalon et chaussures en textures Poly Haven (CC0).
- Un seul script fabrique tous les personnages : `VARIANTE=femme python outils/construire_personnage.py`
  (variantes : faris, homme2, villageois, ancien, femme, femme2, femme_agee, garcon, fille). Chaque visage
  combine ~14 traits MakeHuman (nez, lèvres, menton, pommettes, front…) tirés au hasard à partir du nom. Les femmes portent un vrai pagne (jupe
  portefeuille pondérée sur le bassin et les cuisses) et un foulard noué. Les motifs wax viennent de
  `outils/motifs_wax.py` (créés pour le jeu).
- Animations : créées par programme dans Blender (même script). Elles sont correctes mais pas aussi
  naturelles qu'une capture de mouvement. Comme le squelette est compatible Mixamo, on pourra plus tard remplacer
  ces animations par des captures de mouvement Mixamo (gratuites avec un compte Adobe), sans rien refaire.

## Règles du projet

- Tout le code est en GDScript, commenté en français.
- Unités : 1 unité = 1 mètre. Le centre de l'île est en (0, 0, 0) ; le nord est vers −Z.
- Le dossier `.godot/` est un cache : ne pas le copier ni le mettre sur GitHub.
- Mentions obligatoires (relief et image) : voir `jeu/terrains/README.md` (Copernicus).

## Crédits des ressources

- Textures de sol, écorce de palmier, ciels HDRI et modèles d'arbres : **Poly Haven** (polyhaven.com), licence **CC0**
  (domaine public, usage commercial libre). Arbres : Island Tree 01 et 02, Jacaranda Tree.
- Palmes, motif wax et drapeau du Cobra : créés pour le projet.
- Matières d'Akwéri (banco, chaume, planches, tôle, bois peint, pierres) : Poly Haven, CC0.
- Feuilles et écorce des arbres proches : « island_tree_01 » de **Poly Haven** (CC0), feuilles détourées et assemblées en rameaux par `outils/feuillages.py` ; herbes, grain de peau et cheveux : textures créées par programme pour le jeu.
- Objets de rue (chaise monobloc, casier, bidon, pneu, voiture bâchée, fût, poubelle, groupe électrogène, bouteille de gaz, sac de ciment) : modèles **Poly Haven**, CC0 (convertis par `outils/props_glb.py`).
- Véhicules (berline, taxi, pick-up, moto 125) : modélisés pour le jeu par programme (`outils/construire_vehicules.py`), sans modèle tiers.
- Matières de Port-Néré (enduit peint, enduit abîmé, parpaing, asphalte, pavés de trottoir) : Poly Haven, CC0. Enseignes, noms de commerces et drapeau national : fictifs, créés pour le jeu.
- Corps de Faris : MakeHuman / MPFB2 (makehumancommunity), licence CC0.
- Relief et image satellite : Copernicus (voir `jeu/terrains/README.md`).

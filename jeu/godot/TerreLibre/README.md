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
| N | Changer d'ambiance : heure dorée → midi harmattan → pluie → nuit → aube |
| G | Monter à cheval / descendre (près du cheval, devant la maison de Faris) |
| E | Enfourcher la moto ou embarquer dans une pirogue / descendre |
| C · F · clic droit · clic gauche · R | S'accroupir · maîtriser · viser · tirer · recharger (mission 4) |
| P · B · T | Aller à Port-Néré · Bomé · Tikané |
| M | Carte de l'île (clic gauche : poser une balise, clic droit : l'enlever) |
| F5 · F9 | Sauvegarder · reprendre la dernière sauvegarde (sauvegarde automatique toutes les 3 min) |
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
| Pluie, sol mouillé, harmattan (herbe sèche) | `scripts/ambiances.gd` | ✅ |
| Faris : vrai modèle humain (MakeHuman, morphologie africaine), chemise en wax original, pantalon, chaussures, cheveux courts | `personnages/faris.glb` | ✅ |
| Animations de Faris : repos, marche, course, saut, nage (enchaînées selon la vitesse) | `scripts/joueur.gd` | ✅ (animations faites à la main, voir plus bas) |

## Déjà ajouté depuis la v0.2

- Port-Néré (ville, marché, circulation), Akwéri, Bomé (terrasses, champs, greniers), Tikané (rivière, village occupé).
- Foule à trois niveaux (habitants proches, passants, silhouettes lointaines) et scènes de vie quotidienne.
- Mission 4 « Première Étincelle » jouable (combat, maîtrise non létale, libération d'Akwéri).
- Cheval (G), moto (E) et pirogue à la perche (E) : la pirogue part de Port-Néré et de l'embarcadère de Tikané.
- Personnages : mains complètes, vêtements amples, sandales, chèche drapé, marche et course réalistes.
- Barrages du Cobra à Port-Néré tenus par des miliciens : passer au pas sans arme, barrage forcé = fusillade,
  couvre-feu la nuit (sommation puis tirs), miliciens qui se rendent (F pour ligoter), barrage levé une fois vidé.
- Troncs d'arbres et de cocotiers solides autour du joueur (on ne les traverse plus à moto ou à cheval).
- Routes de latérite (≈ 6 km) qui prolongent le boulevard et l'avenue de Port-Néré au-delà des barrages :
  vers Akwéri, vers Bomé, puis de Bomé à Tikané. Tracé calculé sur le vrai relief (évite pentes, mer et maisons),
  ornières, emprise dégagée, panneaux indicateurs avec la distance.
- Patrouilles du Cobra : trois pick-up font la ronde sur les pistes. Après une alerte (barrage forcé, coups de feu,
  homme armé repéré), le plus proche fonce par la piste puis à travers la brousse, pile à 15 m et ses deux
  miliciens sautent à terre pour combattre (reddition et ligotage possibles). Trop loin, il abandonne.
- Fusillades : les miliciens se mettent à couvert derrière les murets et les pick-up ; les passants à moins de
  90 m s'enfuient en courant à l'opposé des tirs, puis reprennent leur chemin.
- Carte de l'île (M) sur l'image satellite ombrée par le relief : pistes, rues, lieux, barrages (rouges, verts une
  fois levés), patrouilles en chasse, moto, cheval, pirogues, Faris ; balise avec colonne de lumière et distance.
  Mini-carte permanente en bas à droite.
- Sauvegarde (F5) et reprise (F9), automatique toutes les 3 minutes et à la libération d'Akwéri.

## Prochaines étapes

1. Réalisme par photos réelles : textures de matières (banco, latérite, tôle, chaume) et objets scannés.
2. Textures et objets tirés des photos réelles (dès réception), puis missions 1 à 3.
3. Missions 1 à 3 et 5 à 6, jauge de confiance, sauvegarde.

## Faris : comment il est fait

- Corps : **MakeHuman / MPFB2** (licence CC0), réglé en homme africain de 1,77 m, squelette **compatible Mixamo**.
- Vêtements : chemise au **motif wax créé pour le jeu** (original, sans droits tiers), pantalon et chaussures en textures Poly Haven (CC0).
- Animations : créées par programme dans Blender (`outils/construire_faris.py`). Elles sont correctes mais pas aussi
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
- Palmes et motif wax : textures créées pour le projet.
- Corps de Faris : MakeHuman / MPFB2 (makehumancommunity), licence CC0.
- Relief et image satellite : Copernicus (voir `jeu/terrains/README.md`).

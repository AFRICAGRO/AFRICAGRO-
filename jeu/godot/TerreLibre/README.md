# WANZALA : FREEDOM — projet Godot (dossier TerreLibre)

Projet Godot 4 de l'île de Talanké. Rendu **Compatibilité** (OpenGL 3.3) pour tourner
sur un PC modeste avec carte graphique intégrée.

## Jouer sans Godot (Windows)

Télécharger `WANZALA.exe` (un seul fichier, le jeu est inclus dedans) et double-cliquer dessus.
Windows peut afficher « Windows a protégé votre ordinateur » (le fichier n'est pas signé) :
cliquer sur **Informations complémentaires** → **Exécuter quand même**. Pour refaire l'exécutable
depuis Godot : **Projet → Exporter… → Windows Desktop** (le préréglage est dans `export_presets.cfg` ;
il faut d'abord installer les modèles d'exportation de Godot 4.7.2 depuis cette même fenêtre).

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
| N | Changer d'ambiance : heure dorée → midi harmattan → pluie → nuit → aube → nuit d'orage |
| G | Monter à cheval / descendre (près du cheval, devant la maison de Faris) |
| E | Enfourcher la moto ou embarquer dans une pirogue / descendre (pirogue à moteur, mission 3 : Z gaz, relâcher pour glisser) |
| F (pendant une scène) | Passer à la réplique suivante |
| 1 · 2 · 3 | Choisir une réponse (barrage de la mission 1) |
| C · F · clic droit · clic gauche · R | S'accroupir · maîtriser · viser · tirer · recharger (mission 4) |
| P · B · T | Aller à Port-Néré · Bomé · Tikané |
| M | Carte de l'île (clic gauche : poser une balise, clic droit : l'enlever) |
| F5 · F9 | Sauvegarder · reprendre la dernière sauvegarde (sauvegarde automatique toutes les 3 min) |
| X | Lancer un caillou là où l'on regarde (le garde le plus proche va voir) — mission 5 |
| Tab | Téléphone : missions, Zala Money (achats), preuves, radio, carte |
| Espace contre une paroi claire | Grimper (ZQSD), mission 7 |
| V | Fusil ↔ fusil à fléchettes anesthésiantes (mission 8) |
| H | Ordre aux familles escortées : suivre → attendre → se cacher → courir (mission 8) |
| K · clic gauche | Appareil photo du téléphone · déclencher (mission 9) |
| Clic droit à moto | Viser en roulant (clic gauche : tirer), mission 10 |
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
- Mission 5 « Les Graines » jouable (après Akwéri, balise posée sur la carte) : entrepôt du Cobra sur pilotis au
  quai, de nuit. Entrer par la trappe depuis l'eau (Ama attend en pirogue) ou par la porte ; couper le groupe
  électrogène (2 min de noir, torches des gardes) ; caillou pour attirer un garde ; maîtriser, traîner et cacher
  un garde derrière les caisses (un camarade ligoté découvert = alerte) ; crocheter la chambre froide ; descendre
  les 12 sacs par la trappe ; registre des chargements (preuve). Alerte : fuite avec les sacs déjà sauvés
  (réussite partielle) ou nouvel essai plus tard.
- Mission 6 « Champs de Cendre » jouable (après la mission 5) : lire le vent à la manche à air (l'harmattan descend
  vers Bomé), brûler les 3 parcelles du Cobra par lignes de feu. Le feu court dans le sens du vent et remonte
  lentement contre lui : allumé du mauvais côté, il saute dans les herbes et file vers une maison (à éteindre à
  plusieurs, F). Coupe-feu avec les cultivateurs. Riposte des contremaîtres, des miradors et d'une patrouille ;
  la fumée cache Faris. Puis la coopérative : cultures, familles, part du village → revenus en ZLM.
- Téléphone de Faris (Tab) : journal des missions, Zala Money (solde, historique ; munitions, soins, dons),
  preuves recueillies, radio (Lagune FM du Cobra, puis Radio Racines), carte ; notifications.
- Mission 7 « La Voix de l'Île » jouable (après Bomé) : lac de cratère à l'aube dans la brume, sanctuaire
  (offrande), point de vue panoramique ; escalade de la face nord (jauge d'endurance, corniches, jamais de mort) ;
  poste du sommet (5 gardes, l'antenne à ne pas toucher) ; Joël l'opérateur radio ; premier message au choix
  (espoir, vérité, défi) avec ses effets. Radio Racines diffuse ensuite un morceau original de « zala-beat »
  (composé et synthétisé : outils/zala_beat.py) dans le téléphone et dans tout Port-Néré.
- Mission 8 « Nuit à Tikané » jouable (après Radio Racines) : appel chuchoté de la Dr Nadia ; nuit d'orage
  (pluie, éclairs qui révèlent tout : pendant l'éclair les gardes voient deux fois plus loin, tonnerre synthétisé :
  outils/sons_orage.py) ; fusil à fléchettes de Kwame (12, silencieux) ; 7 gardes adultes (fléchette, prise
  dans le dos ou combat) ; 6 jeunes recrues enrôlées de force qui ne sont **jamais des cibles** (réticule bloqué,
  aucune arme ne les blesse, ils ne tirent jamais) : on les désarme dans leur dos, ou la Dr Nadia leur parle ;
  crochetage de la maison du chef ; escorte des familles jusqu'aux pirogues d'Ama avec des ordres simples ;
  choix de l'aube (poursuivre le pick-up ou protéger les familles) ; la Dr Nadia rejoint les Racines (soins plus rapides).
- Mission 9 « Le Chenal » jouable (après Tikané) : une mangrove créée dans la baie du Sud (îlots de vase aux bords
  irréguliers, chenaux creusés dans le relief, ~850 palétuviers sur racines-échasses, vase sombre et luisante,
  grenouilles, insectes et clapotis synthétisés : outils/sons_mangrove.py) ; filature d'une barge à la perche avec
  Ama (jauge de distance 25–60 m, pauses d'écoute, projecteur qui balaie le sillage, reprise si l'on est vu ou
  semé) ; marée qui monte (un banc de vase s'ouvre, une arche de racines se ferme) ; appareil photo du téléphone
  (sacs, acheteur, navire LGV 2047 au large) ; cabane sur pilotis : écouter sous le plancher, voler le registre ou
  attaquer (le registre peut tomber à l'eau) ; le registre signé « H.S. » relie le Cobra au Syndicat des Docks.
- Mission 10 « L'Avion » jouable (après le registre) : la piste de terre du nord aplanie le long de la côte (bornes,
  manche à air, hangar de tôle, citerne, caisses) ; garage de Kwame sur la place de Port-Néré et moto gonflée de
  Moto-Moto (~140 km/h, tir en roulant) ; approche au choix (route : alarme immédiate ; à pied : saboter le réservoir
  sous l'aile ; par la plage) ; bimoteur WZ-AKT construit pour le jeu, décollage et poursuite entre deux pick-up dont
  les tireurs vous visent ; viser le train ou un moteur (le cockpit : le témoin meurt, on recommence) ; sortie de piste,
  ou décollage puis atterrissage forcé sur la plage si le réservoir est percé ; interrogatoire du pilote Marc Ndoro
  et choix (témoin des Racines ou clé de casier à Lagunaville) ; sons d'avion et de sirène synthétisés (outils/sons_avion.py).
- Mission 11 « Le Serpent » jouable (après l'avion) : la table de planification dans l'arrière-salle du maquis de
  Mama Rokia (approche discrète, frontale ou mixte ; rôles d'Ama, de Kwame et de la Dr Nadia ; appel de Radio Racines ;
  nombre de villageois volontaires selon la confiance) ; le camp du Cobra construit sur sa terrasse au-dessus de la mer
  (enceinte, dortoirs, cellules, chapelle avec pignons et croix, clocher, pick-up armé, projecteurs) ; villageois alliés
  qui suivent Faris et tirent (jamais visés par Faris) ; Ama tireuse de la plage, pick-up piégé par Kwame, groupe
  électrogène coupé ; Dossou fait défection s'il a été relâché à Akwéri, ou se bat contre Faris s'il a été fait
  prisonnier ; les garçons de Tikané ouvrent les cellules de l'intérieur ; Yaw libéré ; tireur du clocher, contrats
  dans le coffre de la chapelle ; le Commandant Mamba et sa canne-épée ; le choix : l'arrêter ou l'éliminer.
- Mission 12 « L'Aube » jouable (fin de l'acte 1, sans combat) : dès le début du jeu, la fresque délavée de la
  coopérative porte l'affiche du Front du Cobra ; après la libération, elle est repeinte (Samuel au centre, Faris
  dessiné à la craie par un enfant), les barrages et les patrouilles disparaissent, fanions aux couleurs des Racines,
  lampadaires solaires, Radio Racines et danseurs au maquis, marché plein, pêcheurs qui chantent, Petit Prince sur
  son vélo neuf, match de foot sur la latérite (ballon physique, on peut marquer) ; six activités facultatives ;
  le cimetière (chrétiens et musulmans côte à côte, tombe de Samuel gravée du proverbe) au coucher du soleil avec Ama,
  Mamba escorté ou Dossou aux pirogues selon les choix ; le bac de nuit, la voix inconnue à la radio ; la carte de
  Wanzala (outils/textures_acte1.py) et le bilan de l'acte 1, enregistré pour l'acte 2.

- Prologue (missions 1 à 3) : le jeu commence désormais par **« Le Retour »** — la traversée en bac (cinématique,
  le passeur au chapeau de paille), le quai où la milice fouille les sacs et emporte le poisson, Petit Prince
  (tutoriel du téléphone), Mama Rokia au maquis, la vendeuse du marché, la fresque et une page du carnet de Samuel
  (facultative), le barrage de Dossou (choix en 8 secondes : se taire, répondre calmement, provoquer), l'enterrement
  au coucher du soleil (le Père Joseph et l'Imam Salif côte à côte, Baya Efua, « Zala ka wan, wan ka zala »), le
  convoi de Mamba aperçu en contrebas, Ama ; écran-titre. **« La Veillée »** : couvre-feu de nuit, patrouilles à
  lampe torche (jauge « vu », C pour s'accroupir ; plus de patrouilles si Faris a provoqué Dossou ; Petit Prince
  siffle s'il a été bien traité ; repéré, on est ramené au début du quartier, jamais tué), la maison du père fouillée,
  les souvenirs en lumière dorée, la boîte en fer sous la pierre plate du manguier, le tableau des preuves.
  **« Le Pêcheur »** : Akwéri au petit matin, Esther, Ama, le racket du hors-bord (filets tranchés), la poursuite en
  pirogue à moteur (nouveau mode de la pirogue) le long de la côte ouest : deux champs de récifs où le hors-bord racle,
  la vague qui le fait chavirer à moitié, trois heurts = chute à l'eau et reprise au dernier passage ; personne
  n'est blessé ; la crique, Ama rejoint les Racines → retour à Akwéri et mission 4. Les choix (barrage, Petit
  Prince, page du carnet) sont sauvegardés et pèsent sur la suite et sur le bilan de l'acte 1.
- Exportation Windows : `export_presets.cfg` (Windows Desktop, jeu inclus dans l'exécutable).

## Prochaines étapes

1. Réalisme par photos réelles : textures de matières (banco, latérite, tôle, chaume) et objets scannés.
2. L'acte 2, Lagunaville. Modèles 3D dédiés à Mamba, Yaw, la Dr Nadia, Moto-Moto, Marc Ndoro, Ama, Baya Efua,
   au passeur et au Père Joseph ; de vrais bateaux 3D (bac, hors-bord, caboteur) ; voix des dialogues.
3. Essais sur un vrai PC Windows : réglage de la poursuite en mer, des patrouilles de nuit et des performances.

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

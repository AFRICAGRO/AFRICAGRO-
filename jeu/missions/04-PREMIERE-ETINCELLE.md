# Mission 4 — « Première Étincelle »

> **Mission prioritaire :** c'est celle qu'on rendra jouable en premier, en **version grise**
> (formes simples, sans décor final), pour vérifier que le jeu est amusant.

| | |
|---|---|
| **Acte** | 1 — Île de Talanké |
| **Lieux** | Village d'Akwéri (plage, ruelles entre les cases, fumoirs, pirogues tirées sur le sable) |
| **Durée visée** | 15 à 20 minutes |
| **Moment** | Fin d'après-midi, puis crépuscule pendant le combat (fumées et lueurs des fumoirs) |
| **Ce que le joueur apprend** | **Tir à la troisième personne**, mise à couvert, recharger, neutraliser sans tuer, protéger les civils |
| **Personnages** | Faris, Ama, villageois d'Akwéri, lieutenant Dossou, 8 à 12 miliciens |
| **Résultat** | **Akwéri est le premier village libéré** : la jauge de confiance et la libération de zone apparaissent |

**Intention :** le moment où Faris passe de témoin à combattant, pour une raison claire et juste :
protéger le village. Le joueur doit sentir à la fois la tension du combat et le soulagement du
village libéré.

---

## Scène 1 — La vengeance du Cobra (cinématique)

Faris et Ama rentrent à Akwéri. Deux pick-up et le hors-bord de la milice sont déjà là. Le lieutenant
**Dossou** a rassemblé les villageois sur la plage. Les miliciens commencent à mettre le feu aux
pirogues.

> **DOSSOU** *(au porte-voix)* — Une pirogue a volé la taxe du Commandant. Tant que la voleuse ne se
> rend pas, une pirogue brûle toutes les cinq minutes.
>
> **AMA** *(cachée avec Faris derrière les fumoirs)* — C'est moi qu'ils veulent. J'y vais.
>
> **FARIS** *(il la retient)* — Si tu y vas, ils brûleront le village quand même.

Faris remarque un milicien isolé près des fumoirs, une arme posée contre un mur.

## Scène 2 — La première arme (jouable : furtivité puis choix)

- Faris s'approche en furtivité (acquis en mission 2) et **neutralise le milicien à mains nues**
  (prise d'étranglement, non létale). Il récupère son **fusil**.
- Moment de pause : Faris regarde l'arme. Ama : *« Tu sais t'en servir ? »* — *« J'ai fait mon
  service. Je pensais ne plus jamais en toucher une. »*
- **Tutoriel :** viser, tirer, se mettre à couvert, recharger.

## Scène 3 — Libérer la plage (jouable : combat)

**Trois vagues de combat**, dans un espace compact (le village est petit).

| Vague | Situation | Ce que le jeu enseigne |
|---|---|---|
| **1** | 4 miliciens sur la plage autour des villageois | Viser avec précision : **ne pas toucher les civils** (sinon la confiance baisse et Ama proteste) |
| **2** | Renforts du pick-up : 4 miliciens, dont un mitrailleur sur le plateau | **Contourner** par les ruelles entre les cases ; Ama crée une diversion en lançant une pirogue en feu vers le pick-up |
| **3** | Dossou et ses 2 derniers hommes retranchés derrière les barques | Mise à couvert, avancer d'abri en abri ; possibilité de **désarmer** au lieu de tuer |

**Règles de jeu importantes**
- Les **villageois** fuient, se cachent ou aident (un pêcheur lance un filet sur un milicien).
- Viser un civil fait **dévier le tir** et fait apparaître un avertissement ; le toucher fait chuter
  la confiance.
- Les miliciens à terre peuvent être **désarmés et ligotés** au lieu d'être achevés : chaque
  ennemi épargné compte pour la fin « Justice ».

## Scène 4 — Dossou (cinématique, choix du joueur)

Dossou, blessé à la jambe, a perdu son arme. Faris le tient en joue.

> **DOSSOU** — Vas-y. Le Commandant m'aurait tué de toute façon pour cet échec.
>
> **AMA** — Où est mon frère ? Yaw Mensah ! Il est au camp ?
>
> **DOSSOU** *(un temps)* — … Il est vivant. C'est tout ce que je dirai.

**Choix du joueur :**

| Choix | Conséquence |
|---|---|
| **Le laisser partir** | Dossou s'enfuit en boitant. Il se souviendra de ce geste : sa **défection** devient possible à la mission 11. Une partie des villageois trouve Faris trop clément (légère baisse de confiance) |
| **Le faire prisonnier** | Les Racines l'enferment dans la cave de l'église. Il pourra être interrogé plus tard (indice sur le camp), mais le Cobra lancera une mission de sauvetage (mission secondaire) |

*(Il n'y a pas d'option « l'exécuter » : Faris n'abat pas un homme désarmé. C'est une règle du
personnage.)*

## Scène 5 — Akwéri libéré (jouable puis cinématique)

- Les villageois éteignent les pirogues. Le drapeau du Cobra est arraché du mât de la plage.
- **Ama** plante une branche de baobab peinte au sommet du mât : premier symbole des **Racines**.
- Les villageois scandent : ***« Zaladou ! Zaladou ! »*** (« Terre libre ! »)
- À l'écran : **« Akwéri libéré »**. La **jauge de confiance** de l'île apparaît pour la première fois,
  et la carte change de couleur autour du village.
- La zone change pour de bon : plus de miliciens, les pêcheurs gardent leur poisson, le marché
  d'Akwéri rouvre (nouveaux marchands dans les missions suivantes).

> **VIEUX MENSAH** — Le Commandant va revenir avec plus d'hommes.
>
> **FARIS** — Alors on sera plus nombreux, nous aussi.

Objectif suivant : **« Récupérer les semences de la coopérative à l'entrepôt du port »** → mission 5.

---

## Notes de production — version grise (prototype)

| Domaine | Besoin minimum pour le prototype |
|---|---|
| **Terrain** | Plage d'Akwéri sur le relief réel de l'île (`jeu/terrains/ile-depart`), formes grises pour les cases (cubes), fumoirs (cylindres), pirogues (blocs allongés) |
| **Personnage jouable** | Modèle « Third Person » d'Unreal : course, accroupi, couverture, visée, tir, rechargement, prise non létale |
| **Ennemis** | IA simple : patrouille, alerte, mise à couvert, tir, fuite quand blessé ; état « à terre » pour désarmer |
| **Civils** | 10 à 15 PNJ qui fuient vers des points de refuge ; détection des tirs proches |
| **Systèmes** | Jauge de confiance, compteur d'ennemis épargnés, libération de zone (changement de l'état du village) |
| **Test de réussite** | Les testeurs ont-ils envie de **rejouer** le combat autrement (plus furtif, plus clément) ? Si oui, le cœur du jeu fonctionne |

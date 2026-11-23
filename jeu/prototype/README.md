# Prototype gris — Mission 4 « Première Étincelle »

**But :** vérifier, le plus tôt possible, que le cœur du jeu est **amusant** :
se battre pour protéger un village, épargner des ennemis, voir la zone libérée.
**Version grise** = formes simples, sans décor final, sans personnages définitifs.

Référence de la mission : [../missions/04-PREMIERE-ETINCELLE.md](../missions/04-PREMIERE-ETINCELLE.md)

---

## Étapes (dans l'ordre, chacune validée avant la suivante)

| # | Étape | Fait par | Comment vérifier |
|---|---|---|---|
| 1 | Projet Unreal **TerreLibre** (modèle Third Person) prêt, plugins activés | Claude sur le PC | `configurer-projet-unreal.ps1` passé, projet qui s'ouvre |
| 2 | Nouveau niveau **L_Talanke_Proto** (World Partition) | Claude sur le PC | Niveau ouvert et sauvegardé |
| 3 | **Import du terrain** de l'île : `jeu/terrains/ile-depart/ile-depart_heightmap_2017.png`, échelle **X = Y = 267,01**, **Z = 120** | **Vous**, à la main (Unreal ne permet pas de créer un Landscape par script) | Le volcan et le lac de cratère sont visibles |
| 4 | **Eau** autour de l'île (plugin Water : Water Body Ocean) | Claude sur le PC | La mer entoure l'île, la plage est au bon niveau |
| 5 | **Blockout d'Akwéri** : lancer `jeu/prototype/blockout_akweri.py` | Claude sur le PC | Cases, fumoirs, pirogues et repères posés au sol, au bord de la mer |
| 6 | **Personnage jouable** : celui du modèle Third Person + accroupi, couverture, visée, tir, rechargement, prise non létale | Claude + vous | On peut traverser le village et tirer sur une cible |
| 7 | **Ennemis** (BP_Milicien + Behavior Tree) | Claude | Ils patrouillent, repèrent, se mettent à couvert, tirent, peuvent être mis « à terre » |
| 8 | **Civils** (BP_Civil) | Claude | Ils fuient vers les refuges quand ça tire |
| 9 | **Systèmes** : confiance, ennemis épargnés, libération de zone | Claude | Les compteurs s'affichent et réagissent |
| 10 | **La mission** : 3 vagues, choix pour Dossou, scène de libération simplifiée | Claude + vous | La mission se joue du début à la fin |
| 11 | **Test** avec 3 à 5 personnes | **Vous** | Questionnaire ci-dessous |

## Ce qu'il faut coder (spécification simple)

### Personnage (BP_Faris, à partir de BP_ThirdPersonCharacter)
| Action | Touche (clavier / manette) | Détail |
|---|---|---|
| S'accroupir | C / B | Plus discret, plus lent |
| Se mettre à couvert | Espace près d'un mur / A | Colle au couvert ; tir en se penchant |
| Viser / tirer | Clic droit / clic gauche (LT / RT) | Caméra par-dessus l'épaule |
| Recharger | R / X | 30 balles par chargeur |
| Prise non létale | F derrière un ennemi / Y | L'ennemi passe « à terre » (pas mort) |
| Ligoter un ennemi à terre | F / Y | Compte comme **épargné** |

### Ennemi (BP_Milicien)
- États : **Patrouille → Suspicion → Combat → À terre** (blessé) → **Ligoté** ou **Mort**.
- En combat : cherche un couvert proche, tire par rafales de 3, change de couvert toutes les 5 à 8 s.
- Points de vie : 100 ; sous 25, il **se rend** (lâche son arme) au lieu de continuer à se battre.

### Civil (BP_Civil)
- Rassemblé sur la plage au début ; dès un tir à moins de 30 m, court vers le **Refuge** le plus proche.
- **Ne peut pas être visé** : le réticule devient blanc barré et le tir est dévié.

### Règles et compteurs (GameState)
| Événement | Effet |
|---|---|
| Civil touché (balle perdue malgré tout) | Confiance **−10** ; Ama proteste à la radio |
| Pirogue sauvée du feu | Confiance **+2** |
| Ennemi ligoté ou rendu | Compteur « épargnés » **+1** |
| Ennemi tué | Compteur « tués » **+1** |
| Tous les ennemis neutralisés | **Akwéri libéré** : drapeau du Cobra retiré, message « Zaladou ! », jauge de confiance affichée |

Valeur de départ de la confiance : **50 / 100**.

### Les trois vagues (repères posés par le script)
| Vague | Repères | Nombre | Déclenchement |
|---|---|---|---|
| 1 | `Ennemi_V1_*` (plage) | 4 | Au premier tir ou si le joueur est repéré |
| 2 | `Ennemi_V2_*` (pick-up) | 4 dont 1 mitrailleur | Quand la vague 1 est à 1 ennemi restant |
| 3 | `Ennemi_V3_*` (barques) | Dossou + 2 | Quand la vague 2 est neutralisée |

## Questionnaire de test (après chaque partie)

1. Sur 10, à quel point vous êtes-vous amusé ?
2. Avez-vous eu envie de **rejouer** autrement (plus discret, plus clément) ?
3. Avez-vous compris qu'il fallait protéger les villageois ?
4. Le moment de la libération (« Zaladou ! ») vous a-t-il fait quelque chose ?
5. Qu'est-ce qui vous a le plus agacé ?

**Seuil de réussite :** moyenne d'au moins **7/10** à la question 1 et une majorité de « oui » à la
question 2. Sinon, on corrige le combat avant de construire autre chose.

---

## Message à coller dans la conversation Claude de votre PC

```
On construit le prototype gris de la mission 4 du jeu WANZALA : FREEDOM.
Lis d'abord : jeu/prototype/README.md, jeu/missions/04-PREMIERE-ETINCELLE.md et jeu/terrains/README.md.
Suis les étapes du tableau du README dans l'ordre, une à la fois.
À chaque étape : dis-moi en une phrase simple ce que tu vas faire, fais-le avec les connecteurs Unreal et Blender,
vérifie avec une capture d'écran, puis attends mon « ok » avant de passer à la suivante.
Pour l'étape 3 (import du terrain), guide-moi pas à pas, car je dois la faire à la main.
Après chaque étape réussie, enregistre le travail sur GitHub (branche claude/jeu-3d-afrique-liberation-yfwhpj).
Parle-moi simplement, sans jargon.
```

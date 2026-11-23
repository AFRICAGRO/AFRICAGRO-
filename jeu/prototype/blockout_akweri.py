"""
Blockout gris du village d'Akwéri (mission 4 « Première Étincelle »).

À exécuter DANS l'éditeur Unreal (Python Editor Script Plugin) :
  - menu Outils > Exécuter un script Python, ou
  - via le connecteur Unreal de Claude (ue_exec_python / ue_python).

Prérequis : le terrain de l'île est importé dans le niveau
(jeu/terrains/ile-depart/ile-depart_heightmap_2017.png, échelle X/Y 267,01 et Z 120).

Le script :
  1. trouve le Landscape et calcule où se trouve Akwéri (position tirée de la carte de l'île) ;
  2. cherche de quel côté est la mer ;
  3. pose des formes simples (cases, fumoirs, pirogues, mât, couverts) posées au sol ;
  4. place des points repères : départ du joueur, apparitions d'ennemis par vague, civils, refuges.

Tout est rangé dans le dossier « Blockout/Akweri » de l'Outliner. Relancer le script efface
d'abord l'ancien blockout. Les positions sont à ajuster à la main ensuite : c'est un point de départ.
"""
import math

import unreal

# --- Paramètres -------------------------------------------------------------------------
TAILLE_HEIGHTMAP = 2017          # pixels
CM_PAR_PIXEL = 267.01            # échelle X/Y utilisée à l'import
# Position d'Akwéri sur la heightmap (pixels), d'après carte-ile-talanke.svg
AKWERI_PX = (484, 1129)
DOSSIER = "Blockout/Akweri"

CUBE = "/Engine/BasicShapes/Cube.Cube"
CYLINDRE = "/Engine/BasicShapes/Cylinder.Cylinder"

acteurs = unreal.get_editor_subsystem(unreal.EditorActorSubsystem)
monde = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()


def trouver_landscape():
    for a in acteurs.get_all_level_actors():
        if isinstance(a, unreal.LandscapeProxy):
            return a
    raise RuntimeError("Aucun Landscape dans le niveau : importez d'abord le terrain de l'île.")


def hauteur_sol(x, y):
    """Altitude du sol (cm) à la position x, y, par un rayon vertical."""
    debut = unreal.Vector(x, y, 200000.0)
    fin = unreal.Vector(x, y, -200000.0)
    hit = unreal.SystemLibrary.line_trace_single(
        monde, debut, fin, unreal.TraceTypeQuery.TRACE_TYPE_QUERY1, False, [],
        unreal.DrawDebugTrace.NONE, True)
    if hit is None:
        return None
    for nom in ("impact_point", "location"):
        if hasattr(hit, nom):
            return getattr(hit, nom).z
    t = hit.to_tuple()  # versions où HitResult n'expose que to_tuple()
    for v in t:
        if isinstance(v, unreal.Vector) and abs(v.z) < 200000.0 and (v.x, v.y) == (x, y):
            return v.z
    for v in t:
        if isinstance(v, unreal.Vector):
            return v.z
    return None


def effacer_ancien_blockout():
    for a in acteurs.get_all_level_actors():
        if str(a.get_folder_path()).startswith(DOSSIER):
            acteurs.destroy_actor(a)


def poser(maillage, nom, x, y, echelle, yaw=0.0, dz=0.0, sous_dossier=""):
    z = hauteur_sol(x, y)
    if z is None:
        unreal.log_warning(f"Pas de sol sous {nom}, ignoré")
        return None
    mesh = unreal.load_asset(maillage)
    a = acteurs.spawn_actor_from_object(mesh, unreal.Vector(x, y, z + dz), unreal.Rotator(0, 0, yaw))
    a.set_actor_scale3d(unreal.Vector(*echelle))
    a.set_actor_label(nom)
    a.set_folder_path(DOSSIER + sous_dossier)
    return a


def repere(nom, x, y, sous_dossier="/Reperes"):
    z = hauteur_sol(x, y) or 0.0
    a = acteurs.spawn_actor_from_class(unreal.TargetPoint, unreal.Vector(x, y, z + 100))
    a.set_actor_label(nom)
    a.set_folder_path(DOSSIER + sous_dossier)
    return a


# --- 1. Où est Akwéri ? ---------------------------------------------------------------------
land = trouver_landscape()
origine, etendue = land.get_actor_bounds(False)
coin_x, coin_y = origine.x - etendue.x, origine.y - etendue.y
cx = coin_x + AKWERI_PX[0] * CM_PAR_PIXEL
cy = coin_y + AKWERI_PX[1] * CM_PAR_PIXEL
unreal.log(f"Akwéri : x={cx:.0f} y={cy:.0f} (cm)")

# --- 2. De quel côté est la mer ? (direction où le sol descend le plus) -----------------
meilleur, angle_mer = None, 0.0
for i in range(16):
    ang = i * math.pi / 8
    z = hauteur_sol(cx + math.cos(ang) * 8000, cy + math.sin(ang) * 8000)
    if z is not None and (meilleur is None or z < meilleur):
        meilleur, angle_mer = z, ang
mx, my = math.cos(angle_mer), math.sin(angle_mer)   # vers la mer
px, py = -my, mx                                     # le long de la plage
unreal.log(f"Mer vers {math.degrees(angle_mer):.0f}°")


def local(avant, cote):
    """Coordonnées monde à partir d'un décalage local en mètres (avant = vers la mer)."""
    return cx + (mx * avant + px * cote) * 100, cy + (my * avant + py * cote) * 100


yaw_plage = math.degrees(math.atan2(py, px))

# --- 3. Formes grises ------------------------------------------------------------------------
effacer_ancien_blockout()

# Cases : deux rangées, avec ruelles entre elles (diamètre 5 m, hauteur 3 m)
for rangee, avant in enumerate((-25, -45)):
    for k in range(-3, 4):
        x, y = local(avant + (k % 2) * 4, k * 12)
        poser(CYLINDRE, f"Case_{rangee}_{k + 3}", x, y, (5, 5, 3), dz=150, sous_dossier="/Cases")

# Fumoirs : abris bas, couverture idéale pour le joueur
for k in range(-2, 3):
    x, y = local(-8, k * 14 + 5)
    poser(CUBE, f"Fumoir_{k + 2}", x, y, (3, 2, 1.4), yaw_plage, dz=70, sous_dossier="/Couverts")

# Pirogues tirées sur le sable (couverts bas), perpendiculaires à la plage
for k in range(-4, 5):
    x, y = local(8 + (k % 3) * 2, k * 9)
    poser(CUBE, f"Pirogue_{k + 4}", x, y, (8, 1.2, 0.8), yaw_plage + 90, dz=40, sous_dossier="/Couverts")

# Mât du drapeau sur la plage (le drapeau du Cobra sera remplacé à la libération)
x, y = local(4, 0)
poser(CYLINDRE, "Mat_Drapeau", x, y, (0.2, 0.2, 8), dz=400)

# Pick-up de la milice (renforts de la vague 2) en haut du village
x, y = local(-60, 20)
poser(CUBE, "PickUp_Milice", x, y, (5, 2.2, 1.8), yaw_plage, dz=90, sous_dossier="/Vehicules")

# Fumoirs incendiés / couvertures centrales de la place
for k, (a, c) in enumerate([(-15, -6), (-15, 6), (-35, 0)]):
    x, y = local(a, c)
    poser(CUBE, f"Couvert_Place_{k}", x, y, (2, 2, 1.2), yaw_plage, dz=60, sous_dossier="/Couverts")

# --- 4. Repères de jeu ------------------------------------------------------------------------
x, y = local(-90, -40)
depart = acteurs.spawn_actor_from_class(unreal.PlayerStart, unreal.Vector(x, y, (hauteur_sol(x, y) or 0) + 120))
depart.set_actor_label("Depart_Joueur")
depart.set_folder_path(DOSSIER + "/Reperes")

for k, (a, c) in enumerate([(10, -10), (12, 5), (6, 15), (2, -20)]):          # vague 1 : plage
    repere(f"Ennemi_V1_{k}", *local(a, c))
for k, (a, c) in enumerate([(-60, 15), (-58, 25), (-62, 30), (-55, 20)]):     # vague 2 : pick-up
    repere(f"Ennemi_V2_{k}", *local(a, c))
for k, (a, c) in enumerate([(14, -30), (16, -25), (12, -35)]):                # vague 3 : Dossou
    repere(f"Ennemi_V3_{k}", *local(a, c))
for k in range(12):                                                            # villageois rassemblés
    repere(f"Civil_{k}", *local(5 + (k % 3) * 2, -2 + (k // 3) * 2))
for k, (a, c) in enumerate([(-40, -40), (-50, 35), (-70, 0)]):                # refuges des civils
    repere(f"Refuge_{k}", *local(a, c))

unreal.log("Blockout d'Akwéri terminé : voir le dossier Blockout/Akweri dans l'Outliner.")

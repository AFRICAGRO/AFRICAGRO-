"""Véhicules de Port-Néré, modélisés par programme dans Blender (aucun modèle tiers) :
berline (taxi jaune ou voiture particulière), pick-up (milice du Cobra), moto 125 (moto-taxi).
Repère : X = largeur, -Y = avant, Z = haut (glTF : l'avant devient +Z dans Godot... voir l'export).
Les roues sont des objets séparés (Roue_*) pour pouvoir les faire tourner dans le jeu.
usage : python construire_vehicules.py  -> /home/claude/vehicules/*.glb
"""
import bpy, bmesh, math, os
from mathutils import Vector, Matrix

SORTIE = "/home/claude/vehicules"
os.makedirs(SORTIE, exist_ok=True)


def raz():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(nom, couleur, rough=0.5, metal=0.0, emission=None, alpha=1.0):
    m = bpy.data.materials.get(nom) or bpy.data.materials.new(nom)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*couleur, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emission:
        b.inputs["Emission Color"].default_value = (*emission, 1)
        b.inputs["Emission Strength"].default_value = 1.0
    return m


def objet(nom, bm, materiau, lisse=True):
    me = bpy.data.meshes.new(nom)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(nom, me)
    bpy.context.scene.collection.objects.link(o)
    me.materials.append(materiau)
    for p in me.polygons:
        p.use_smooth = lisse
    return o


def boite(nom, centre, taille, materiau, biseau=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * taille[0], v.co.y * taille[1], v.co.z * taille[2])) + Vector(centre)
    o = objet(nom, bm, materiau, lisse=False)
    if biseau > 0:
        m = o.modifiers.new("b", "BEVEL")
        m.width = biseau
        m.segments = 2
    return o


def cylindre(nom, centre, r, longueur, axe, materiau, cotes=20, r2=None):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=cotes, radius1=r, radius2=r2 if r2 else r, depth=longueur)
    rotm = {"x": Matrix.Rotation(math.pi / 2, 4, "Y"), "y": Matrix.Rotation(math.pi / 2, 4, "X"), "z": Matrix.Identity(4)}[axe]
    bmesh.ops.transform(bm, matrix=Matrix.Translation(Vector(centre)) @ rotm, verts=bm.verts)
    return objet(nom, bm, materiau)


def roue(nom, centre, r, l, m_pneu, m_jante, rayons=False):
    """Pneu + jante, regroupés sous un objet vide pivot au centre de la roue."""
    piv = bpy.data.objects.new(nom, None)
    bpy.context.scene.collection.objects.link(piv)
    piv.location = centre
    p = cylindre(nom + "_pneu", (0, 0, 0), r, l, "x", m_pneu, 24)
    # flanc arrondi : biseau sur les arêtes du pneu
    b = p.modifiers.new("b", "BEVEL")
    b.width = min(0.05, l * 0.35)
    b.segments = 3
    j = cylindre(nom + "_jante", (0, 0, 0), r * 0.62, l + 0.01, "x", m_jante, 16)
    for o in (p, j):
        o.parent = piv
    if rayons:
        for i in range(8):
            a = i * math.pi / 8
            s = boite(nom + "_rayon%d" % i, (0, 0, 0), (0.008, r * 1.15, 0.008), m_jante)
            s.rotation_euler = (a, 0, 0)
            s.parent = piv
    return piv


def appliquer_tout():
    bpy.context.view_layer.update()
    for o in list(bpy.context.scene.objects):
        if o.type == "MESH" and o.modifiers:
            bpy.context.view_layer.objects.active = o
            for m in list(o.modifiers):
                bpy.ops.object.modifier_apply(modifier=m.name)


def exporter(nom):
    appliquer_tout()
    bpy.ops.export_scene.gltf(filepath=os.path.join(SORTIE, nom + ".glb"), export_format="GLB", export_apply=True)
    print("EXPORT", nom)


# ---------- matières communes ----------
def matieres():
    return dict(
        carrosserie=mat("Carrosserie", (0.8, 0.8, 0.8), 0.25, 0.5),
        vitre=mat("Vitre", (0.03, 0.04, 0.05), 0.05, 0.6),
        pneu=mat("Pneu", (0.025, 0.025, 0.025), 0.9),
        jante=mat("Jante", (0.6, 0.6, 0.62), 0.3, 0.9),
        noir=mat("Plastique", (0.04, 0.04, 0.045), 0.6),
        chrome=mat("Chrome", (0.85, 0.85, 0.85), 0.15, 1.0),
        phare=mat("Phare", (1.0, 0.97, 0.9), 0.1, 0.0, emission=(1.0, 0.95, 0.8)),
        feu=mat("Feu", (0.6, 0.02, 0.02), 0.2, 0.0, emission=(0.6, 0.0, 0.0)),
        plaque=mat("Plaque", (0.92, 0.9, 0.8), 0.6),
        siege=mat("Siege", (0.05, 0.04, 0.035), 0.7),
        moteur=mat("Moteur", (0.25, 0.25, 0.26), 0.5, 0.6),
    )


def silhouette_extrudee(nom, profil, largeur, retrecir_haut, z_retrecir, materiau, coupe_vitre=None, m_vitre=None):
    """Profil latéral (x = longueur vers -avant ... , z) extrudé en largeur ; le haut (habitacle) est rétréci."""
    bm = bmesh.new()
    gauche = [bm.verts.new((-largeur / 2, -x, z)) for x, z in profil]
    face = bm.faces.new(gauche)
    ext = bmesh.ops.extrude_face_region(bm, geom=[face])
    nv = [e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)]
    for v in nv:
        v.co.x += largeur
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    # coupes horizontales pour séparer vitres et tôle
    for z in ([coupe_vitre] if coupe_vitre else []):
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, z), plane_no=(0, 0, 1))
    for v in bm.verts:
        if v.co.z > z_retrecir:
            k = min(1.0, (v.co.z - z_retrecir) / 0.25)
            v.co.x *= 1.0 - retrecir_haut * k
    o = objet(nom, bm, materiau, lisse=False)
    if m_vitre:
        o.data.materials.append(m_vitre)
        for p in o.data.polygons:
            c = p.center
            if coupe_vitre and c.z > coupe_vitre and abs(p.normal.z) < 0.75:
                p.material_index = 1
    b = o.modifiers.new("b", "BEVEL")
    b.width = 0.045
    b.segments = 3
    b.limit_method = "ANGLE"
    return o


def evider_passages(corps, positions, r):
    for i, (x, y, z) in enumerate(positions):
        c = cylindre("trou%d" % i, (x, y, z), r, 0.5, "x", corps.data.materials[0], 28)
        m = corps.modifiers.new("trou%d" % i, "BOOLEAN")
        m.object = c
        m.operation = "DIFFERENCE"
        m.solver = "EXACT"
        bpy.context.view_layer.objects.active = corps
        bpy.ops.object.modifier_apply(modifier=m.name)
        bpy.data.objects.remove(c)


# =====================================================================
def berline():
    raz()
    M = matieres()
    # profil : x vers l'avant positif (devient -Y), z en hauteur
    profil = [(2.25, 0.34), (2.32, 0.62), (2.18, 0.78), (0.95, 0.9), (0.3, 1.42), (-0.9, 1.44),
              (-1.6, 1.0), (-2.2, 0.95), (-2.3, 0.8), (-2.27, 0.34)]
    corps = silhouette_extrudee("Carrosserie", profil, 1.74, 0.16, 0.92, M["carrosserie"], 0.97, M["vitre"])
    roues = [(0.78, -1.38, 0.31), (-0.78, -1.38, 0.31), (0.78, 1.42, 0.31), (-0.78, 1.42, 0.31)]
    evider_passages(corps, roues, 0.38)
    # dessous sombre, pare-chocs, phares, feux, plaques, rétroviseurs, poignées
    boite("Dessous", (0, 0, 0.3), (1.6, 3.4, 0.12), M["noir"])
    boite("PareChocAv", (0, -2.3, 0.42), (1.7, 0.12, 0.18), M["noir"], 0.03)
    boite("PareChocAr", (0, 2.3, 0.42), (1.7, 0.12, 0.18), M["noir"], 0.03)
    for s in (-1, 1):
        boite("Phare%d" % s, (s * 0.62, -2.24, 0.7), (0.32, 0.06, 0.12), M["phare"], 0.02)
        boite("Feu%d" % s, (s * 0.66, 2.28, 0.82), (0.3, 0.05, 0.12), M["feu"], 0.02)
        boite("Retro%d" % s, (s * 0.93, -0.75, 1.02), (0.1, 0.12, 0.08), M["noir"], 0.02)
    boite("PlaqueAv", (0, -2.37, 0.45), (0.5, 0.02, 0.11), M["plaque"])
    boite("PlaqueAr", (0, 2.37, 0.6), (0.5, 0.02, 0.11), M["plaque"])
    boite("Calandre", (0, -2.28, 0.6), (0.8, 0.05, 0.12), M["chrome"], 0.01)
    for nom, (x, y, z) in zip(["Roue_AVD", "Roue_AVG", "Roue_ARD", "Roue_ARG"], roues):
        roue(nom, (x, y, z), 0.31, 0.2, M["pneu"], M["jante"])
    exporter("berline")
    # variante taxi : enseigne sur le toit
    boite("Enseigne", (0, -0.2, 1.52), (0.55, 0.2, 0.16), M["phare"], 0.02)
    exporter("taxi")


def pickup():
    raz()
    M = matieres()
    profil = [(2.6, 0.45), (2.66, 0.8), (2.45, 1.02), (1.2, 1.12), (0.6, 1.78), (-0.6, 1.8),
              (-0.7, 1.12), (-2.65, 1.1), (-2.7, 0.45)]
    corps = silhouette_extrudee("Carrosserie", profil, 1.86, 0.1, 1.15, M["carrosserie"], 1.2, M["vitre"])
    roues = [(0.84, -1.62, 0.4), (-0.84, -1.62, 0.4), (0.84, 1.75, 0.4), (-0.84, 1.75, 0.4)]
    evider_passages(corps, roues, 0.47)
    # benne ouverte : on creuse l'arrière
    benne = boite("creux", (0, 1.62, 1.25), (1.66, 1.95, 0.6), M["carrosserie"])
    m = corps.modifiers.new("benne", "BOOLEAN")
    m.object = benne
    m.operation = "DIFFERENCE"
    m.solver = "EXACT"
    bpy.context.view_layer.objects.active = corps
    bpy.ops.object.modifier_apply(modifier="benne")
    bpy.data.objects.remove(benne)
    boite("Dessous", (0, 0, 0.42), (1.7, 4.0, 0.16), M["noir"])
    boite("PareChocAv", (0, -2.66, 0.55), (1.86, 0.16, 0.24), M["chrome"], 0.03)
    boite("PareChocAr", (0, 2.72, 0.55), (1.86, 0.14, 0.2), M["noir"], 0.03)
    boite("Calandre", (0, -2.62, 0.82), (1.2, 0.06, 0.28), M["noir"], 0.02)
    for s in (-1, 1):
        boite("Phare%d" % s, (s * 0.7, -2.58, 0.92), (0.3, 0.06, 0.14), M["phare"], 0.02)
        boite("Feu%d" % s, (s * 0.86, 2.7, 0.92), (0.1, 0.05, 0.3), M["feu"], 0.01)
        boite("Retro%d" % s, (s * 1.02, -0.5, 1.35), (0.1, 0.14, 0.1), M["noir"], 0.02)
    # arceau dans la benne (support de bâche)
    for y in (0.95, 2.3):
        for s in (-1, 1):
            boite("Arceau", (s * 0.8, y, 1.55), (0.05, 0.05, 0.9), M["noir"])
        boite("ArceauH", (0, y, 2.0), (1.65, 0.05, 0.05), M["noir"])
    boite("PlaqueAv", (0, -2.75, 0.55), (0.5, 0.02, 0.11), M["plaque"])
    for nom, (x, y, z) in zip(["Roue_AVD", "Roue_AVG", "Roue_ARD", "Roue_ARG"], roues):
        roue(nom, (x, y, z), 0.4, 0.26, M["pneu"], M["jante"])
    exporter("pickup")


def moto():
    raz()
    M = matieres()
    r = 0.3
    roue("Roue_AV", (0, -0.66, r), r, 0.09, M["pneu"], M["chrome"], rayons=True)
    roue("Roue_AR", (0, 0.66, r), r, 0.11, M["pneu"], M["chrome"], rayons=True)
    # fourche inclinée
    for s in (-1, 1):
        f = boite("Fourche", (s * 0.07, -0.58, 0.62), (0.035, 0.035, 0.72), M["chrome"])
        f.rotation_euler = (math.radians(-24), 0, 0)
    boite("TeteFourche", (0, -0.45, 0.98), (0.18, 0.08, 0.1), M["noir"], 0.02)
    g = cylindre("Guidon", (0, -0.42, 1.06), 0.014, 0.72, "x", M["chrome"], 10)
    for s in (-1, 1):
        cylindre("Poignee", (s * 0.33, -0.42, 1.06), 0.022, 0.12, "x", M["noir"], 10)
        boite("Retro", (s * 0.26, -0.4, 1.22), (0.07, 0.02, 0.05), M["chrome"], 0.01)
    cylindre("Phare", (0, -0.55, 0.92), 0.08, 0.08, "y", M["phare"], 16)
    boite("GardeBoueAv", (0, -0.7, 0.66), (0.12, 0.42, 0.03), M["carrosserie"], 0.01)
    boite("GardeBoueAr", (0, 0.72, 0.68), (0.14, 0.5, 0.03), M["carrosserie"], 0.01)
    # cadre, réservoir, selle, moteur, pot d'échappement, repose-pieds, porte-bagages
    c = boite("Cadre", (0, -0.15, 0.68), (0.06, 0.62, 0.06), M["noir"])
    c.rotation_euler = (math.radians(-28), 0, 0)
    t = boite("Reservoir", (0, -0.17, 0.92), (0.28, 0.42, 0.2), M["carrosserie"], 0.08)
    boite("Selle", (0, 0.28, 0.88), (0.26, 0.66, 0.1), M["siege"], 0.04)
    boite("Moteur", (0, 0.0, 0.46), (0.24, 0.36, 0.28), M["moteur"], 0.03)
    boite("CacheLateral", (0, 0.3, 0.68), (0.24, 0.3, 0.22), M["carrosserie"], 0.03)
    cylindre("Pot", (0.15, 0.45, 0.4), 0.045, 0.7, "y", M["chrome"], 12)
    boite("ReposePieds", (0, 0.02, 0.33), (0.5, 0.04, 0.03), M["noir"])
    boite("PorteBagages", (0, 0.72, 0.9), (0.24, 0.32, 0.025), M["noir"])
    boite("Feu", (0, 0.92, 0.82), (0.1, 0.04, 0.05), M["feu"])
    exporter("moto")


berline()
pickup()
moto()
print("FINI")

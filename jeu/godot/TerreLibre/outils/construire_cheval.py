"""Cheval de Faris : construit entièrement par programme dans Blender (aucun modèle tiers), exporté en glb.
- Corps modelé par des volumes (métaboules) aux proportions d'un cheval de selle (1,55 m au garrot),
  lissé puis allégé (environ 14 000 triangles) ;
- robe gris pommelé, jambes plus sombres, sabots noirs, bout du nez sombre ; crinière et queue en mèches ;
- harnais : tapis de selle brodé (motif original), selle, étriers, bride perlée, rênes ;
- squelette de 25 os et quatre allures : Repos, Pas (4 temps), Trot (2 temps diagonaux), Galop (3 temps).
Le cheval regarde vers -Y dans Blender (soit +Z dans Godot), comme les personnages."""
import bpy, bmesh, math
from mathutils import Vector, Matrix, Quaternion

import os
ICI = os.path.dirname(os.path.abspath(__file__))
SORTIE = os.path.join(ICI, "..", "personnages", "cheval.glb")
TAPIS = os.path.join(ICI, "tapis_selle.png")
MECHE = os.path.join(ICI, "meche.png")

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = 24

# ---------------------------------------------------------------------------
# 1. Volumes du corps (métaboules)
# ---------------------------------------------------------------------------
mb_data = bpy.data.metaballs.new("CorpsMB")
mb_data.resolution = 0.022
mb_data.threshold = 0.6
mb_obj = bpy.data.objects.new("CorpsMB", mb_data)
scene.collection.objects.link(mb_obj)


def ellipse(c, taille, rayon=1.0, raideur=2.0, rot=None):
    e = mb_data.elements.new(type="ELLIPSOID")
    e.co = Vector(c)
    e.radius = rayon
    e.size_x, e.size_y, e.size_z = taille
    e.stiffness = raideur
    if rot is not None:
        e.rotation = rot


def capsule(a, b, r, raideur=2.0):
    a, b = Vector(a), Vector(b)
    d = b - a
    e = mb_data.elements.new(type="CAPSULE")
    e.co = (a + b) / 2
    e.radius = r
    e.size_x = d.length / 2
    e.stiffness = raideur
    e.rotation = Vector((1, 0, 0)).rotation_difference(d.normalized())


# Une métaboule n'apparaît qu'à 58 % de son rayon (raideur 2, seuil 0,6) : on donne ici les
# demi-tailles VISIBLES voulues, converties par V().
K = 1 / 0.58


def V(t):
    return tuple(x * K for x in t)


# tronc : garrot à 1,52 m, ventre à 0,84 m, poitrail profond, croupe ronde
ellipse((0, -0.05, 1.13), V((0.27, 0.56, 0.29)), 1.0, 2.0)     # ventre
ellipse((0, -0.48, 1.12), V((0.25, 0.24, 0.32)), 1.0, 2.0)     # poitrail
ellipse((0, 0.38, 1.2), V((0.27, 0.27, 0.29)), 1.0, 2.0)       # arrière-main
ellipse((0, -0.5, 1.4), V((0.1, 0.17, 0.1)), 1.0, 2.0)         # garrot
ellipse((0, 0.48, 1.33), V((0.2, 0.18, 0.15)), 1.0, 2.0)       # croupe
# encolure inclinée vers l'avant (≈ 45°), large à la base, plus fine à la gorge
cou = [((0, -0.58, 1.3), 0.25), ((0, -0.78, 1.5), 0.2), ((0, -0.94, 1.68), 0.155), ((0, -1.03, 1.8), 0.125)]
for i in range(len(cou) - 1):
    capsule(cou[i][0], cou[i + 1][0], cou[i][1] * K, 2.0)
ellipse((0, -0.82, 1.64), V((0.07, 0.2, 0.1)), 1.0, 2.0, Quaternion((1, 0, 0), math.radians(-40)))   # crête
ellipse((0, -0.72, 1.3), V((0.12, 0.12, 0.16)), 1.0, 1.6)                                           # bas de l'encolure
# tête de profil : un coin allongé (front large et plat, grosse ganache ronde en arrière,
# chanfrein droit qui s'affine, bout du nez avec naseaux et lèvres)
ellipse((0, -1.1, 1.86), V((0.105, 0.11, 0.08)), 1.0, 2.0)                                           # front et nuque
ellipse((0, -1.1, 1.7), V((0.075, 0.13, 0.13)), 1.0, 2.0)                                            # ganache
for sx in (1, -1):
    ellipse((sx * 0.055, -1.11, 1.71), V((0.05, 0.11, 0.11)), 1.0, 1.8)                              # joues larges
capsule((0, -1.18, 1.83), (0, -1.4, 1.58), 0.072 * K, 2.0)                                           # chanfrein
capsule((0, -1.2, 1.66), (0, -1.4, 1.5), 0.06 * K, 2.0)                                              # mâchoire inférieure
ellipse((0, -1.44, 1.5), V((0.07, 0.065, 0.08)), 1.0, 2.0)                                           # bout du nez
ellipse((0, -1.41, 1.44), V((0.05, 0.05, 0.035)), 1.0, 1.8)                                          # lèvre et menton
for s in (1, -1):  # oreilles en cornet : larges à la base, pointues
    ellipse((s * 0.06, -1.05, 1.98), V((0.03, 0.022, 0.06)), 1.0, 2.0, Quaternion((0, 1, 0), math.radians(s * 12)))
    capsule((s * 0.065, -1.05, 2.0), (s * 0.075, -1.07, 2.1), 0.016 * K, 2.2)

# jambes : (épaule ou hanche, coude/grasset, genou/jarret, boulet, sabot)
JAMBES = {
    "AvG": [(0.15, -0.5, 1.12), (0.16, -0.55, 0.9), (0.16, -0.55, 0.52), (0.16, -0.57, 0.18), (0.16, -0.62, 0.04)],
    "AvD": [(-0.15, -0.5, 1.12), (-0.16, -0.55, 0.9), (-0.16, -0.55, 0.52), (-0.16, -0.57, 0.18), (-0.16, -0.62, 0.04)],
    "ArG": [(0.16, 0.42, 1.16), (0.17, 0.3, 0.86), (0.16, 0.52, 0.56), (0.16, 0.5, 0.18), (0.16, 0.45, 0.04)],
    "ArD": [(-0.16, 0.42, 1.16), (-0.17, 0.3, 0.86), (-0.16, 0.52, 0.56), (-0.16, 0.5, 0.18), (-0.16, 0.45, 0.04)],
}
RAYONS = {"Av": [0.1, 0.066, 0.042, 0.038], "Ar": [0.12, 0.074, 0.045, 0.038]}
for nom, p in JAMBES.items():
    rr = RAYONS[nom[:2]]
    for i in range(4):
        capsule(p[i], p[i + 1], rr[i] * K, 2.0)
    ellipse(p[2], V((0.055, 0.058, 0.06)), 1.0, 2.0)          # genou / jarret
    ellipse(p[3], V((0.048, 0.052, 0.048)), 1.0, 2.0)         # boulet
    capsule((p[4][0], p[4][1], 0.0), (p[4][0], p[4][1] - 0.02, 0.08), 0.058 * K, 2.0)  # sabot
    if nom.startswith("Ar"):
        ellipse((p[0][0] * 0.95, p[0][1] - 0.04, p[0][2] - 0.16), V((0.12, 0.16, 0.22)), 1.0, 2.0)  # cuisse
    else:
        ellipse((p[0][0] * 0.9, p[0][1] - 0.03, p[0][2] - 0.08), V((0.1, 0.12, 0.2)), 1.0, 2.0)  # épaule et avant-bras

# muscles : de petites masses qui donnent le relief vivant d'un vrai cheval
for s in (1, -1):
    ellipse((s * 0.2, -0.46, 1.2), V((0.06, 0.12, 0.16)), 1.0, 1.4, Quaternion((1, 0, 0), math.radians(20)))   # épaule
    ellipse((s * 0.17, -0.4, 0.98), V((0.07, 0.1, 0.1)), 1.0, 1.4)       # triceps derrière le coude
    ellipse((s * 0.165, -0.57, 0.76), V((0.055, 0.06, 0.12)), 1.0, 1.5)  # avant-bras
    ellipse((s * 0.12, -0.66, 1.08), V((0.07, 0.06, 0.1)), 1.0, 1.4)     # muscles du poitrail
    ellipse((s * 0.2, 0.46, 1.3), V((0.07, 0.16, 0.12)), 1.0, 1.4)       # fessier
    ellipse((s * 0.17, 0.58, 1.04), V((0.07, 0.08, 0.2)), 1.0, 1.4)     # ischio-jambiers
    ellipse((s * 0.18, 0.34, 0.9), V((0.06, 0.08, 0.12)), 1.0, 1.5)      # grasset
    ellipse((s * 0.17, 0.42, 0.72), V((0.05, 0.08, 0.1)), 1.0, 1.5)      # gaskin (jambe)
    ellipse((s * 0.07, -0.76, 1.42), V((0.06, 0.12, 0.08)), 1.0, 1.3, Quaternion((1, 0, 0), math.radians(-45)))  # encolure
    ellipse((s * 0.06, -1.1, 1.72), V((0.04, 0.08, 0.07)), 1.0, 1.4)     # joue (ganache)
    ellipse((s * 0.03, -1.46, 1.5), V((0.025, 0.035, 0.03)), 1.0, 1.6)   # naseau
ellipse((0, -0.05, 0.9), V((0.22, 0.4, 0.06)), 1.0, 1.2)                  # ventre légèrement rond
ellipse((0, 0.66, 1.33), V((0.06, 0.06, 0.05)), 1.0, 1.5)                 # naissance de la queue

dg = bpy.context.evaluated_depsgraph_get()
mesh = bpy.data.meshes.new_from_object(mb_obj.evaluated_get(dg))
bpy.data.objects.remove(mb_obj)
corps = bpy.data.objects.new("Cheval", mesh)
scene.collection.objects.link(corps)
print("métaboules ->", len(mesh.polygons), "faces")
# allègement puis lissage
dec = corps.modifiers.new("Allege", "DECIMATE")
dec.ratio = min(1.0, 7500 / max(1, len(mesh.polygons)))
lis = corps.modifiers.new("Lisse", "SMOOTH")
lis.factor = 0.5
lis.iterations = 2
dg = bpy.context.evaluated_depsgraph_get()
m2 = bpy.data.meshes.new_from_object(corps.evaluated_get(dg))
corps.modifiers.clear()
corps.data = m2
for p in corps.data.polygons:
    p.use_smooth = True
# coordonnées de texture (pour le grain du poil appliqué dans Godot)
bpy.context.view_layer.objects.active = corps
corps.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.004)
bpy.ops.object.mode_set(mode="OBJECT")
corps.select_set(False)
print("cheval allégé :", len(corps.data.polygons), "faces")

# ---------------------------------------------------------------------------
# 2. Squelette
# ---------------------------------------------------------------------------
arm_data = bpy.data.armatures.new("Squelette")
arm = bpy.data.objects.new("Armature", arm_data)
scene.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
OS = {}


def os_(nom, a, b, parent=None):
    eb = arm_data.edit_bones.new(nom)
    eb.head = Vector(a)
    eb.tail = Vector(b)
    eb.roll = 0.0
    if parent:
        eb.parent = arm_data.edit_bones[parent]
    OS[nom] = (Vector(a), Vector(b))


os_("Racine", (0, 0, 0), (0, -0.3, 0))
os_("Corps", (0, 0.45, 1.18), (0, -0.5, 1.18), "Racine")
os_("Cou1", (0, -0.6, 1.32), (0, -0.84, 1.56), "Corps")
os_("Cou2", (0, -0.84, 1.56), (0, -1.06, 1.82), "Cou1")
os_("Tete", (0, -1.06, 1.82), (0, -1.44, 1.48), "Cou2")
os_("Queue1", (0, 0.62, 1.36), (0, 0.74, 1.12), "Corps")
os_("Queue2", (0, 0.74, 1.12), (0, 0.8, 0.7), "Queue1")
for nom, p in JAMBES.items():
    os_(nom + "1", p[0], p[1], "Corps")
    os_(nom + "2", p[1], p[2], nom + "1")
    os_(nom + "3", p[2], p[3], nom + "2")
    os_(nom + "4", p[3], p[4], nom + "3")
bpy.ops.object.mode_set(mode="OBJECT")


def dist_seg(v, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (v - a).dot(ab) / ab.length_squared))
    return (v - (a + ab * t)).length, t


def poids(v, groupes_autorises=None):
    """Poids des os les plus proches (deux au plus, fondu doux)."""
    cand = []
    for nom, (a, b) in OS.items():
        if nom == "Racine" or (groupes_autorises and nom not in groupes_autorises):
            continue
        d, t = dist_seg(v, a, b)
        cand.append((d, nom))
    cand.sort()
    d0, n0 = cand[0]
    if len(cand) == 1:
        return [(n0, 1.0)]
    d1, n1 = cand[1]
    w0 = 1.0 / (d0 + 0.01) ** 3
    w1 = 1.0 / (d1 + 0.01) ** 3
    if d1 - d0 > 0.08:
        return [(n0, 1.0)]
    s = w0 + w1
    return [(n0, w0 / s), (n1, w1 / s)]


def zone(v):
    """Os autorisés selon la région du corps : évite qu'une jambe attire le ventre."""
    if v.z < 1.0 and abs(v.x) > 0.06:
        cote = "G" if v.x > 0 else "D"
        avant = "Av" if v.y < 0.0 else "Ar"
        noms = [avant + cote + str(i) for i in range(1, 5)]
        if v.z > 0.85:
            noms.append("Corps")
        return noms
    if v.y < -0.62 or v.z > 1.55 and v.y < -0.4:
        return ["Corps", "Cou1", "Cou2", "Tete"]
    if v.y > 0.6 and v.z < 1.3:
        return ["Corps", "Queue1", "Queue2"]
    return None


def lier(obj, force=None):
    obj.parent = arm
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    gr = {nom: obj.vertex_groups.new(name=nom) for nom in OS}
    for v in obj.data.vertices:
        if force:
            gr[force].add([v.index], 1.0, "REPLACE")
            continue
        for nom, w in poids(v.co, zone(v.co)):
            gr[nom].add([v.index], w, "REPLACE")


# ---------------------------------------------------------------------------
# 3. Robe gris pommelé (couleurs aux sommets)
# ---------------------------------------------------------------------------
def srgb(c):
    return [max(0.0, min(1.0, x)) ** (1 / 2.2) for x in c]


def bruit(p):
    return (math.sin(p.x * 23.1 + p.y * 11.7) * math.sin(p.y * 19.3 - p.z * 7.9) * math.sin(p.z * 17.7 + p.x * 5.3))


me = corps.data
col = me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
for poly in me.polygons:
    for li in poly.loop_indices:
        v = me.vertices[me.loops[li].vertex_index].co
        base = Vector((0.36, 0.355, 0.34))
        # pommelures : taches rondes plus claires, cernées de gris plus sombre (comme sur un gris pommelé)
        b0 = bruit(v * 1.7)
        pom = max(0.0, b0) * 0.55 - max(0.0, -b0) * 0.12
        c = base * (1.0 + pom)
        if v.z < 0.9:   # jambes de plus en plus sombres vers le bas
            k = min(1.0, (0.9 - v.z) / 0.6)
            c = c.lerp(Vector((0.2, 0.2, 0.2)), k * 0.85)
        if v.z < 0.1:   # sabots
            c = Vector((0.035, 0.032, 0.03))
        if v.y < -1.36:  # bout du nez
            c = c.lerp(Vector((0.1, 0.09, 0.09)), min(1.0, (-1.36 - v.y) / 0.08))
        if v.z > 1.98 and v.y > -1.1 and v.y < -1.0:  # pointe des oreilles
            c = c * 0.6
        col.data[li].color = srgb(c) + [1.0]


def materiau(nom, couleur=None, rugosite=0.6, vcol=False, image=None, metal=0.0):
    m = bpy.data.materials.new(nom)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = rugosite
    bsdf.inputs["Metallic"].default_value = metal
    if couleur:
        bsdf.inputs["Base Color"].default_value = list(couleur) + [1.0]
    if vcol:
        n = m.node_tree.nodes.new("ShaderNodeVertexColor")
        n.layer_name = "Col"
        m.node_tree.links.new(n.outputs["Color"], bsdf.inputs["Base Color"])
    if image:
        t = m.node_tree.nodes.new("ShaderNodeTexImage")
        t.image = bpy.data.images.load(image)
        m.node_tree.links.new(t.outputs["Color"], bsdf.inputs["Base Color"])
    return m


corps.data.materials.append(materiau("Robe", rugosite=0.55, vcol=True))
lier(corps)

# ---------------------------------------------------------------------------
# 4. Yeux, crinière, queue, harnais
# ---------------------------------------------------------------------------
pieces = bpy.data.meshes.new("Harnais")
bm = bmesh.new()
MATS = ["Yeux", "Crins", "Tapis", "Cuir", "Metal", "Perles", "Paupiere"]


def tube(chemin, rayons, cotes, mi, plat=1.0):
    """Tube le long d'un chemin ; rayons = un rayon par point ; plat < 1 aplatit (lanière)."""
    anneaux = []
    for i, p in enumerate(chemin):
        d = (chemin[min(i + 1, len(chemin) - 1)] - chemin[max(i - 1, 0)]).normalized()
        a = d.cross(Vector((0, 0, 1)))
        if a.length < 0.01:
            a = d.cross(Vector((1, 0, 0)))
        a.normalize()
        b = d.cross(a).normalized()
        anneau = []
        for k in range(cotes):
            t = 2 * math.pi * k / cotes
            anneau.append(bm.verts.new(p + (a * math.cos(t) + b * math.sin(t) * plat) * rayons[i]))
        anneaux.append(anneau)
    for i in range(len(anneaux) - 1):
        for k in range(cotes):
            f = bm.faces.new((anneaux[i][k], anneaux[i][(k + 1) % cotes], anneaux[i + 1][(k + 1) % cotes], anneaux[i + 1][k]))
            f.material_index = mi
            f.smooth = True


def boule(c, r, mi):
    res = bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=6, radius=r)
    for v in res["verts"]:
        v.co += Vector(c)
    for f in {f for v in res["verts"] for f in v.link_faces}:
        f.material_index = mi
        f.smooth = True


uv = bm.loops.layers.uv.new("UVMap")
for s in (1, -1):  # yeux : globe sombre brillant, paupière autour
    boule((s * 0.098, -1.16, 1.84), 0.021, 0)
    paupiere = [Vector((s * 0.1, -1.16, 1.84)) + Vector((0, math.cos(a) * 0.027, math.sin(a) * 0.02)) for a in [2 * math.pi * k / 12 for k in range(13)]]
    tube(paupiere, [0.007] * 13, 5, 6)

import random
random.seed(7)


def carte(racine, pente, longueur, largeur, ondule, mi=1):
    """Une mèche : bande courbe texturée (racine en haut de l'image, pointes en bas)."""
    pts = []
    for k in range(7):
        t = k / 6.0
        pts.append(racine + pente * longueur * t + Vector((0, 0, -0.5 * t * t * longueur)) + Vector((ondule * math.sin(t * 3.0), 0, 0)))
    for k in range(6):
        a, b2 = pts[k], pts[k + 1]
        d = (b2 - a).normalized()
        lat = d.cross(Vector((1, 0, 0))).normalized() * largeur * 0.5
        if lat.length < 0.001:
            lat = Vector((0, largeur * 0.5, 0))
        q = [bm.verts.new(a - lat), bm.verts.new(a + lat), bm.verts.new(b2 + lat), bm.verts.new(b2 - lat)]
        f = bm.faces.new(q)
        f.material_index = mi
        f.smooth = True
        t0, t1 = k / 6.0, (k + 1) / 6.0
        for l, c in zip(f.loops, ((0, 1 - t0), (1, 1 - t0), (1, 1 - t1), (0, 1 - t1))):
            l[uv].uv = c


# crinière : trois rangs de mèches qui tombent sur le côté gauche de l'encolure
for rang in range(3):
    for i in range(30):
        t = (i + random.uniform(-0.3, 0.3)) / 29.0
        racine = Vector((0.0 + rang * 0.012, -1.04 + 0.5 * t, 1.93 - 0.44 * t + 0.01))
        longueur = 0.22 + 0.14 * math.sin(t * math.pi) + random.uniform(-0.04, 0.05)
        pente = Vector((0.55 + 0.15 * rang, random.uniform(-0.1, 0.1), -0.5)).normalized()
        carte(racine, pente, longueur, random.uniform(0.05, 0.08), random.uniform(-0.02, 0.02))
# toupet sur le front
for i in range(5):
    carte(Vector((random.uniform(-0.02, 0.02), -1.06, 1.97)), Vector((random.uniform(-0.2, 0.2), -0.6, -0.4)).normalized(), 0.16, 0.05, 0.01)
# queue : fouet de mèches qui part du tronçon et tombe jusqu'aux jarrets
for i in range(34):
    a = 2 * math.pi * i / 34
    o = Vector((math.cos(a) * 0.035, math.sin(a) * 0.025, 0))
    racine = Vector((0, 0.68, 1.3)) + o
    pente = Vector((o.x * 3.0, 0.35, -1.0)).normalized()
    carte(racine, pente, random.uniform(0.75, 0.95), random.uniform(0.07, 0.11), random.uniform(-0.04, 0.04))

# tapis de selle brodé : nappe épousant le dos et tombant sur les flancs, avec franges
lignes = 10
colonnes = 14
grille = []
for i in range(lignes + 1):
    u = i / lignes                       # de l'avant (garrot) vers l'arrière (rein)
    y = -0.48 + 0.62 * u
    rangee = []
    for j in range(colonnes + 1):
        v = j / colonnes * 2 - 1           # -1 côté droit, +1 côté gauche
        ang = v * 1.35
        r = 0.31 + 0.02 * math.sin(u * math.pi)
        x = math.sin(ang) * r
        z = 1.14 + math.cos(ang) * r * 0.98 + 0.03
        if abs(v) > 0.75:                  # le bas des pans tombe droit
            x = math.copysign(max(abs(x), 0.3), x)
            z -= (abs(v) - 0.75) * 0.55
        rangee.append(bm.verts.new((x, y, z)))
    grille.append(rangee)
for i in range(lignes):
    for j in range(colonnes):
        f = bm.faces.new((grille[i][j], grille[i][j + 1], grille[i + 1][j + 1], grille[i + 1][j]))
        f.material_index = 2
        f.smooth = True
        for l, (a, b) in zip(f.loops, ((i, j), (i, j + 1), (i + 1, j + 1), (i + 1, j))):
            l[uv].uv = (a / lignes, b / colonnes)
# franges et pompons en bas des pans
for cote in (0, colonnes):
    for i in range(0, lignes + 1, 2):
        p = grille[i][cote].co.copy()
        tube([p, p + Vector((0, 0, -0.08))], [0.012, 0.006], 4, 5)
        boule(p + Vector((0, 0, -0.09)), 0.016, 5)
# selle : siège bombé en cuir, pommeau et troussequin arrondis
res = bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=8, radius=1.0)
for v in res["verts"]:
    v.co = Vector((v.co.x * 0.2, v.co.y * 0.27 - 0.16, v.co.z * 0.065 + 1.49))
for f in {f for v in res["verts"] for f in v.link_faces}:
    f.material_index = 3
    f.smooth = True
boule((0, -0.4, 1.53), 0.06, 3)       # pommeau
boule((0, 0.08, 1.53), 0.07, 3)       # troussequin
# étrivières et étriers
for s in (1, -1):
    haut = Vector((s * 0.21, -0.16, 1.47))
    bas = Vector((s * 0.33, -0.16, 0.98))
    tube([haut, bas], [0.012, 0.012], 4, 3, 0.4)
    tube([bas + Vector((0, -0.06, 0)), bas + Vector((0, -0.06, -0.08)), bas + Vector((0, 0.06, -0.08)), bas + Vector((0, 0.06, 0))],
         [0.008] * 4, 5, 4)
    # sangle sous le ventre
    tube([Vector((s * 0.3, -0.3, 1.2)), Vector((s * 0.27, -0.3, 0.98)), Vector((0, -0.3, 0.82))], [0.015, 0.015, 0.015], 4, 3, 0.35)
# bride : muserolle autour du chanfrein, montants jusqu'à la nuque, frontal perlé, mors et rênes
axe = Vector((0, -0.24, -0.27)).normalized()       # direction du chanfrein (vers le bout du nez)
b2 = axe.cross(Vector((1, 0, 0))).normalized()
cn = Vector((0, -1.33, 1.63))
anneau_nez = [cn + Vector((1, 0, 0)) * math.cos(a) * 0.098 + b2 * math.sin(a) * 0.092 for a in [2 * math.pi * k / 16 for k in range(17)]]
tube(anneau_nez, [0.009] * 17, 4, 3, 0.4)
for s in (1, -1):
    tube([cn + Vector((s * 0.098, 0, 0)), Vector((s * 0.108, -1.2, 1.78)), Vector((s * 0.095, -1.09, 1.93)), Vector((0, -1.06, 1.98))],
         [0.009] * 4, 4, 3, 0.4)
    mors = Vector((s * 0.082, -1.39, 1.53))
    boule(mors, 0.018, 4)
    tube([mors, Vector((s * 0.24, -1.0, 1.45)), Vector((s * 0.16, -0.62, 1.52)), Vector((s * 0.05, -0.42, 1.55))], [0.007] * 4, 4, 3, 0.5)  # rênes
frontal = [Vector((math.cos(a) * 0.105, -1.14 + math.sin(a) * 0.04, 1.92)) for a in [math.pi * (k / 10.0) for k in range(11)]]
for p in frontal:
    boule(p, 0.014, 5)

bm.to_mesh(pieces)
bm.free()
harnais = bpy.data.objects.new("Harnais", pieces)
scene.collection.objects.link(harnais)
for nom, c, r, metal in (("Yeux", (0.02, 0.015, 0.012), 0.15, 0.0), ("Crins", None, 0.7, 0.0),
                         ("Tapis", None, 0.8, 0.0), ("Cuir", (0.18, 0.09, 0.04), 0.5, 0.0),
                         ("Metal", (0.7, 0.68, 0.62), 0.3, 0.9), ("Perles", (0.7, 0.08, 0.06), 0.35, 0.0),
                         ("Paupiere", (0.08, 0.075, 0.07), 0.6, 0.0)):
    m = materiau(nom, c, r, image=TAPIS if nom == "Tapis" else (MECHE if nom == "Crins" else None), metal=metal)
    if nom == "Crins":   # crins : la transparence de la mèche découpe les brins
        tex = [n for n in m.node_tree.nodes if n.type == "TEX_IMAGE"][0]
        bsdf = m.node_tree.nodes["Principled BSDF"]
        m.node_tree.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
        m.blend_method = "CLIP"
        m.alpha_threshold = 0.4
    harnais.data.materials.append(m)
# poids du harnais : chaque pièce suit l'os le plus proche, sans fondu entre jambes
harnais.parent = arm
mod = harnais.modifiers.new("Armature", "ARMATURE")
mod.object = arm
gr = {nom: harnais.vertex_groups.new(name=nom) for nom in OS}
for v in harnais.data.vertices:
    p = v.co
    if p.y > 0.6 and p.z < 1.35:
        noms = ["Queue1", "Queue2"]
    elif p.y < -1.0 or (p.z > 1.85 and p.y < -0.85):
        noms = ["Tete", "Cou2"]
    elif p.y < -0.6 and p.z > 1.4:
        noms = ["Cou1", "Cou2", "Tete"]
    else:
        noms = ["Corps"]
    for nom, w in poids(p, noms):
        gr[nom].add([v.index], w, "REPLACE")

# ---------------------------------------------------------------------------
# 5. Allures
# ---------------------------------------------------------------------------
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="POSE")
pb = arm.pose.bones
for b in pb:
    b.rotation_mode = "XYZ"
arm.animation_data_create()


def raz():
    for b in pb:
        b.rotation_euler = (0, 0, 0)
        b.location = (0, 0, 0)


def cle(f):
    for b in pb:
        b.keyframe_insert("rotation_euler", frame=f)
        b.keyframe_insert("location", frame=f)


def nouvelle(nom):
    act = bpy.data.actions.new(nom)
    act.use_fake_user = True
    arm.animation_data.action = act
    return act


def jambe(nom, phase, appui, amplitude, levee, flex_genou):
    """Pose d'une jambe à la phase donnée (0..1). appui = part du cycle au sol.
    Au sol : le membre passe de l'avant vers l'arrière, le boulet s'enfonce sous le poids,
    puis le sabot bascule en fin d'appui. En l'air : le membre se plie, revient, puis s'allonge
    vers l'avant juste avant de reposer."""
    av = nom.startswith("Av")
    if phase < appui:
        u = phase / appui
        balance = amplitude * (1 - 2 * u)
        charge = math.sin(math.pi * u)                      # le boulet descend à mi-appui
        bascule = max(0.0, (u - 0.78) / 0.22)               # le talon décolle, la pince reste au sol
        pb[nom + "1"].rotation_euler.x = math.radians(balance)
        pb[nom + "2"].rotation_euler.x = math.radians(2 * charge if av else -3 * charge)
        pb[nom + "3"].rotation_euler.x = math.radians((-6 if av else 6) * bascule)
        pb[nom + "4"].rotation_euler.x = math.radians(16 * charge - 24 * bascule)
    else:
        u = (phase - appui) / (1 - appui)
        balance = amplitude * (-1 + 2 * (0.5 - 0.5 * math.cos(math.pi * u)))
        pli = math.sin(math.pi * min(1.0, u * 1.25)) if u < 0.8 else 0.0
        tend = max(0.0, (u - 0.7) / 0.3)                    # le membre s'allonge pour se poser
        pb[nom + "1"].rotation_euler.x = math.radians(balance + 4 * tend)
        if av:
            pb[nom + "2"].rotation_euler.x = math.radians(-10 * pli * levee)
            pb[nom + "3"].rotation_euler.x = math.radians(-flex_genou * pli + 4 * tend)
            pb[nom + "4"].rotation_euler.x = math.radians(-42 * pli + 8 * tend)
        else:
            pb[nom + "2"].rotation_euler.x = math.radians(-24 * pli * levee)
            pb[nom + "3"].rotation_euler.x = math.radians(flex_genou * 0.9 * pli - 3 * tend)
            pb[nom + "4"].rotation_euler.x = math.radians(-36 * pli + 6 * tend)


def allure(nom, images, phases, appui, amplitude, levee, flex, saut, tangage, tete):
    nouvelle(nom)
    for f in range(0, images + 1, 2):
        t = f / images
        raz()
        for j, ph in phases.items():
            jambe(j, (t + ph) % 1.0, appui, amplitude, levee, flex)
        rebond = 4 if nom != "Galop" else 2   # au pas et au trot le dos rebondit deux fois par foulée
        pb["Corps"].location.y = saut * (0.5 + 0.5 * math.cos(rebond * math.pi * t))
        pb["Corps"].rotation_euler.x = math.radians(tangage * math.sin(2 * math.pi * t))
        pb["Corps"].rotation_euler.y = math.radians(1.5 * math.sin(2 * math.pi * t))   # roulis
        hoche = rebond if nom == "Pas" else 2                                        # la tête hoche au pas
        pb["Cou1"].rotation_euler.x = math.radians(tete * math.sin(hoche * math.pi * t + 0.6))
        pb["Cou2"].rotation_euler.x = math.radians(tete * 0.4 * math.sin(hoche * math.pi * t + 0.9))
        pb["Tete"].rotation_euler.x = math.radians(-tete * 0.5 * math.sin(hoche * math.pi * t + 0.6))
        pb["Queue1"].rotation_euler.z = math.radians(6 * math.sin(2 * math.pi * t))
        pb["Queue2"].rotation_euler.x = math.radians(8 * math.sin(2 * math.pi * t + 1.0) * (saut * 10))
        cle(f)


nouvelle("Repos")
for f in range(0, 97, 8):
    t = f / 96
    raz()
    pb["Corps"].location.y = 0.006 * math.sin(4 * math.pi * t)            # respiration
    pb["Cou1"].rotation_euler.x = math.radians(4 + 3 * math.sin(2 * math.pi * t))
    pb["Tete"].rotation_euler.x = math.radians(-6 + 2 * math.sin(2 * math.pi * t + 1))
    pb["Cou2"].rotation_euler.z = math.radians(5 * math.sin(2 * math.pi * t))
    pb["Queue1"].rotation_euler.z = math.radians(14 * math.sin(6 * math.pi * t) * max(0.0, math.sin(2 * math.pi * t)))
    pb["ArD3"].rotation_euler.x = math.radians(8)     # repose une jambe arrière
    pb["ArD4"].rotation_euler.x = math.radians(-14)
    pb["ArD1"].rotation_euler.x = math.radians(-3)
    cle(f)

# Pas : 4 temps (postérieur gauche, antérieur gauche, postérieur droit, antérieur droit), 1,1 s
allure("Pas", 26, {"ArG": 0.0, "AvG": 0.75, "ArD": 0.5, "AvD": 0.25}, 0.64, 12, 0.6, 38, 0.012, 1.5, 4)
# Trot : diagonales ensemble, 0,7 s, temps de suspension
allure("Trot", 16, {"AvG": 0.0, "ArD": 0.0, "AvD": 0.5, "ArG": 0.5}, 0.42, 18, 1.0, 75, 0.05, 1.2, 2)
# Galop à droite : postérieur gauche, puis diagonale postérieur droit + antérieur gauche, puis antérieur droit, 0,6 s
allure("Galop", 14, {"ArG": 0.0, "ArD": 0.88, "AvG": 0.88, "AvD": 0.75}, 0.38, 26, 1.2, 90, 0.07, 6, 8)

bpy.ops.object.mode_set(mode="OBJECT")
arm.animation_data.action = bpy.data.actions["Repos"]

# ---------------------------------------------------------------------------
# 6. Export
# ---------------------------------------------------------------------------
for o in scene.objects:
    o.select_set(o.name in ("Cheval", "Harnais", "Armature"))
bpy.context.view_layer.objects.active = arm
bpy.ops.export_scene.gltf(filepath=SORTIE, export_format="GLB", use_selection=True, export_animations=True,
                          export_animation_mode="ACTIONS", export_skins=True, export_yup=True,
                          export_image_format="JPEG", export_jpeg_quality=88)
print("EXPORT OK", [a.name for a in bpy.data.actions])

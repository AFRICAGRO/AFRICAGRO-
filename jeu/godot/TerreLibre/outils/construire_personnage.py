"""Construit Faris (MakeHuman / MPFB2, CC0) avec squelette compatible Mixamo,
vêtements (lin, denim, cuir), cheveux courts, yeux, et 5 animations en place.
Sortie : faris.glb (pour Godot)."""
import bpy, bmesh, sys, importlib, math
from mathutils import Vector, Matrix
import addon_utils

addon_utils.enable("bl_ext.user_default.mpfb", default_set=True)


def imp(name, key):
    for m in list(sys.modules):
        if m.endswith(name):
            return getattr(importlib.import_module(m), key)
    raise ValueError(name)


HumanService = imp("mpfb.services.humanservice", "HumanService")
HOP = imp("mpfb.entities.objectproperties", "HumanObjectProperties")
TargetService = imp("mpfb.services.targetservice", "TargetService")
LocationService = imp("mpfb.services.locationservice", "LocationService")
import os

# ---------- variantes : Faris et les habitants de Talanké ----------
VARIANTE = os.environ.get("VARIANTE", "faris")
L = ("rough_linen_diff.jpg", "rough_linen_nor.jpg")
D = ("denim_fabric_03_diff.jpg", "denim_fabric_03_nor.jpg")
VARIANTES = {
    # macros MPFB, peau, cheveux, haut (texture, teinte), bas (texture, teinte), pagne, foulard (texture, teinte)
    "faris": dict(macros=dict(gender=1.0, age=0.5, muscle=0.62, weight=0.48, height=0.38),
                  peau=(0.10, 0.042, 0.02), cheveux=(0.012, 0.009, 0.008),
                  haut=("wax_diff.jpg", (1, 1, 1)), bas=(D[0], (0.06, 0.075, 0.11))),
    "villageois": dict(macros=dict(gender=1.0, age=0.42, muscle=0.5, weight=0.66, height=0.55),
                       peau=(0.075, 0.032, 0.016), cheveux=(0.012, 0.009, 0.008),
                       haut=(L[0], (0.32, 0.17, 0.07)), bas=(L[0], (0.09, 0.085, 0.075))),
    "ancien": dict(macros=dict(gender=1.0, age=0.84, muscle=0.35, weight=0.42, height=0.42),
                   peau=(0.085, 0.038, 0.02), cheveux=(0.07, 0.068, 0.065),
                   haut=(L[0], (0.3, 0.42, 0.58)), bas=(L[0], (0.3, 0.42, 0.58)), boubou=True, manches=1.6),
    "femme": dict(macros=dict(gender=0.0, age=0.45, muscle=0.45, weight=0.55, height=0.4),
                  peau=(0.095, 0.04, 0.02), cheveux=(0.012, 0.009, 0.008),
                  haut=("wax_cercles_vert.jpg", (1, 1, 1)), bas=("wax_cercles_vert.jpg", (1, 1, 1)),
                  pagne=True, foulard=("wax_feuilles_rouge.jpg", (1, 1, 1))),
    "femme_agee": dict(macros=dict(gender=0.0, age=0.74, muscle=0.35, weight=0.7, height=0.3),
                       peau=(0.07, 0.03, 0.015), cheveux=(0.16, 0.155, 0.15),
                       haut=("wax_losanges_ocre.jpg", (1, 1, 1)), bas=("wax_losanges_ocre.jpg", (1, 1, 1)),
                       pagne=True, foulard=("wax_losanges_ocre.jpg", (1, 1, 1))),
    "femme2": dict(macros=dict(gender=0.0, age=0.38, muscle=0.5, weight=0.45, height=0.55),
                   peau=(0.06, 0.026, 0.013), cheveux=(0.012, 0.009, 0.008),
                   haut=(L[0], (0.45, 0.07, 0.06)), bas=("wax_bandes_indigo.jpg", (1, 1, 1)), pagne=True),
    "homme2": dict(macros=dict(gender=1.0, age=0.36, muscle=0.58, weight=0.4, height=0.48),
                   peau=(0.11, 0.05, 0.025), cheveux=(0.012, 0.009, 0.008),
                   haut=("wax_feuilles_rouge.jpg", (1, 1, 1)), bas=(L[0], (0.25, 0.2, 0.12))),
    "pecheur": dict(macros=dict(gender=1.0, age=0.4, muscle=0.78, weight=0.42, height=0.52),
                    peau=(0.085, 0.037, 0.018), cheveux=(0.012, 0.009, 0.008),
                    haut=(L[0], (1, 1, 1)), bas=(L[0], (0.12, 0.17, 0.24)), torse_nu=True, short=True),
    "homme3": dict(macros=dict(gender=1.0, age=0.3, muscle=0.55, weight=0.5, height=0.45),
                   peau=(0.1, 0.045, 0.022), cheveux=(0.012, 0.009, 0.008),
                   haut=(L[0], (0.05, 0.11, 0.07)), bas=(D[0], (0.07, 0.08, 0.12))),
    "garcon": dict(macros=dict(gender=1.0, age=0.17, muscle=0.5, weight=0.45, height=0.5),
                   peau=(0.09, 0.04, 0.02), cheveux=(0.012, 0.009, 0.008),
                   haut=(L[0], (0.05, 0.09, 0.16)), bas=(L[0], (0.14, 0.12, 0.08))),
    "fille": dict(macros=dict(gender=0.0, age=0.15, muscle=0.5, weight=0.45, height=0.5),
                  peau=(0.08, 0.035, 0.018), cheveux=(0.012, 0.009, 0.008),
                  haut=("wax_losanges_ocre.jpg", (1, 1, 1)), bas=("wax_losanges_ocre.jpg", (1, 1, 1)), pagne=True),
}
COIFFURES = {"homme2": "afro", "femme2": "chignon", "fille": "macarons"}
V = VARIANTES[VARIANTE]
COIFFURE = "foulard" if V.get("foulard") else COIFFURES.get(VARIANTE, "court")
FEMININ = V["macros"]["gender"] < 0.5
AGE = V["macros"]["age"] > 0.7
ENFANT = V["macros"]["age"] < 0.3
print("VARIANTE", VARIANTE)

for o in list(bpy.data.objects):
    bpy.data.objects.remove(o)

h = HumanService.create_human()
for k, v in [("african", 1.0), ("asian", 0.0), ("caucasian", 0.0), ("proportions", 0.7)] + list(V["macros"].items()):
    try:
        HOP.set_value(k, v, entity_reference=h)
    except Exception as e:
        print("macro", k, e)
TargetService.reapply_macro_details(h)
troot = LocationService.get_mpfb_data("targets")
if VARIANTE == "faris":
    visage = [("nose/nose-scale-horiz-incr", 0.35), ("mouth/mouth-scale-horiz-incr", 0.2), ("chin/chin-prominent-incr", 0.2)]
else:
    # visage propre à chaque habitant : ~14 traits tirés au hasard (graine = nom), symétriques gauche/droite
    import random
    rng = random.Random(VARIANTE)
    traits = ["nose/nose-scale-horiz", "nose/nose-scale-vert", "nose/nose-flaring", "nose/nose-nostrils-width",
              "nose/nose-point-width", "nose/nose-volume", "nose/nose-hump", "mouth/mouth-scale-horiz",
              "mouth/mouth-lowerlip-volume", "mouth/mouth-upperlip-volume", "mouth/mouth-scale-vert",
              "chin/chin-width", "chin/chin-prominent", "chin/chin-height", "chin/chin-jaw-drop",
              "forehead/forehead-scale-vert", "forehead/forehead-nubian", "head/head-scale-horiz",
              "head/head-scale-vert", "head/head-fat", "cheek/*-cheek-bones", "cheek/*-cheek-volume",
              "eyes/*-eye-scale", "eyes/*-eye-bag", "ears/*-ear-scale", "ears/*-ear-flap"]
    visage = []
    for t in rng.sample(traits, 14):
        sens = rng.choice(["incr", "decr"])
        w = rng.uniform(0.2, 0.7)
        for cote in (["l", "r"] if "*" in t else [""]):
            visage.append((t.replace("*", cote) + "-" + sens, w))
for rel, w in visage:
    p = os.path.join(troot, rel + ".target.gz")
    if os.path.exists(p):
        TargetService.load_target(h, p, weight=w)
    else:
        print("cible absente", rel)
rig = HumanService.add_builtin_rig(h, "mixamo")
bpy.context.view_layer.update()

# ---------- géométrie de base ----------
bpy.context.view_layer.objects.active = h
for o in bpy.context.selected_objects:
    o.select_set(False)
h.select_set(True)
bpy.ops.object.shape_key_remove(all=True, apply_mix=True)
for m in list(h.modifiers):
    if m.type == "MASK":
        h.modifiers.remove(m)

B = {b.name.replace("mixamorig:", ""): b for b in rig.data.bones}
hips_z = B["Hips"].head_local.z
neck_z = B["Neck"].head_local.z
ankle_z = B["LeftFoot"].head_local.z
print("hauteur", round(h.dimensions.z, 3), "hanches", round(hips_z, 3))


def bras(p):
    """position le long du bras (0 = épaule, 1 = coude) et distance à l'axe ; None si loin du bras"""
    for side in ("Left", "Right"):
        a = B[side + "Arm"].head_local
        e = B[side + "ForeArm"].head_local
        if (p.x > 0) != (side == "Left"):
            continue
        d = e - a
        t = (p - a).dot(d) / d.length_squared
        dist = (p - (a + d * t)).length
        return t, dist
    return None


groupes = {g.index: g.name for g in h.vertex_groups}


def groupe(v):
    best = None
    for g in v.groups:
        n = groupes[g.group]
        if g.weight > 0.5 and (n.startswith("helper") or n == "body"):
            best = n
    return best or "none"


me = h.data
role = [groupe(v) for v in me.vertices]
# ---------- matériaux ----------
TEX = "/home/claude/faris/tex/"


def mat(nom, couleur, rough=0.8, tex=None, normal=None, vcol=False, metal=0.0):
    m = bpy.data.materials.new(nom)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*couleur, 1)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if tex:
        t = nt.nodes.new("ShaderNodeTexImage")
        img = bpy.data.images.load(TEX + tex)
        if couleur != (1, 1, 1):
            # le glTF n'exporte pas les nœuds de mélange : la teinte est cuite dans une copie de l'image
            import numpy as np
            px = np.empty(img.size[0] * img.size[1] * 4, dtype=np.float32)
            img.pixels.foreach_get(px)
            px = px.reshape(-1, 4)
            lin = np.where(px[:, :3] <= 0.04045, px[:, :3] / 12.92, ((px[:, :3] + 0.055) / 1.055) ** 2.4)
            lin = lin * np.array(couleur, dtype=np.float32) / np.maximum(0.02, lin.mean(axis=0))
            lin = np.clip(lin, 0, 1)
            px[:, :3] = np.where(lin <= 0.0031308, lin * 12.92, 1.055 * lin ** (1 / 2.4) - 0.055)
            img2 = bpy.data.images.new(nom + "_teint", img.size[0], img.size[1])
            img2.pixels.foreach_set(px.ravel())
            bpy.context.scene.view_settings.view_transform = "Standard"  # pas de transformation de rendu à l'enregistrement
            bpy.context.scene.view_settings.look = "None"
            img2.filepath_raw = f"/tmp/{VARIANTE}_{nom}.jpg"
            img2.file_format = "JPEG"
            img2.save()
            img = bpy.data.images.load(img2.filepath_raw)
            bsdf.inputs["Base Color"].default_value = (1, 1, 1, 1)
        t.image = img
        nt.links.new(t.outputs["Color"], bsdf.inputs["Base Color"])
    if normal:
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = bpy.data.images.load(TEX + normal)
        t.image.colorspace_settings.name = "Non-Color"
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nm.inputs["Strength"].default_value = 0.35  # îlots UV tournés : un relief fort marbre le tissu
        nt.links.new(t.outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    if vcol:
        a = nt.nodes.new("ShaderNodeVertexColor")
        a.layer_name = "Col"
        nt.links.new(a.outputs["Color"], bsdf.inputs["Base Color"])
    return m


me.materials.clear()
FOULARD = V.get("foulard")
for m in [mat("Peau", (1, 1, 1), 0.55, vcol=True),  # teinte de peau portée par les couleurs de sommets
          (mat("Cheveux", FOULARD[1], 0.9, FOULARD[0], L[1]) if FOULARD else mat("Cheveux", V["cheveux"], 0.95)),
          mat("Chemise", V["haut"][1], 0.9, V["haut"][0], L[1]),
          mat("Pantalon", V["bas"][1], 0.85, V["bas"][0], D[1] if V["bas"][0] == D[0] else L[1]),
          mat("Chaussures", (1, 1, 1), 0.6, "brown_leather_diff.jpg", "brown_leather_nor.jpg"),
          mat("Yeux", (1, 1, 1), 0.15, vcol=True),
          mat("Dents", (0.85, 0.82, 0.75), 0.4)]:
    me.materials.append(m)

bm = bmesh.new()
bm.from_mesh(me)
bm.verts.ensure_lookup_table()
bm.faces.ensure_lookup_table()
deform = bm.verts.layers.deform.verify()
NOMS_ROLES = sorted(set(role))
lr = bm.verts.layers.int.new("role")
for v in bm.verts:
    v[lr] = NOMS_ROLES.index(role[v.index])


def R(v):
    return NOMS_ROLES[v[lr]]



def centre_f(f):
    return sum((v.co for v in f.verts), Vector()) / len(f.verts)


GARDER = {"body", "helper-tights", "helper-l-eye", "helper-r-eye", "helper-upper-teeth", "helper-lower-teeth", "helper-tongue"}
a_suppr = [f for f in bm.faces if any(R(v) not in GARDER for v in f.verts)]
bmesh.ops.delete(bm, geom=a_suppr, context="FACES")

# maillage affiné autour de la tête et de l'encolure : lisière des cheveux et col sans dents de scie
fins = [f for f in bm.faces
        if (R(f.verts[0]) == "body" and centre_f(f).z > neck_z - 0.04)
        or (R(f.verts[0]) == "helper-tights" and abs(centre_f(f).z - (neck_z - 0.035)) < 0.07)]
aretes = list({e for f in fins for e in f.edges})
bmesh.ops.subdivide_edges(bm, edges=aretes, cuts=1, use_grid_fill=True)
bm.verts.ensure_lookup_table()

# matériaux : 0 peau, 1 cheveux, 2 chemise, 3 pantalon, 4 chaussures, 5 yeux, 6 dents
NOMS = ["Peau", "Cheveux", "Chemise", "Pantalon", "Chaussures", "Yeux", "Dents"]


def centre(f):
    return sum((v.co for v in f.verts), Vector()) / len(f.verts)


tete_z = B["Head"].head_local.z
genou_z = B["LeftLeg"].head_local.z
for f in bm.faces:
    r = R(f.verts[0])
    c = centre(f)
    if r in ("helper-l-eye", "helper-r-eye"):
        f.material_index = 5
    elif r in ("helper-upper-teeth", "helper-lower-teeth", "helper-tongue"):
        f.material_index = 6
    elif r == "helper-tights":
        ab = bras(c)
        if c.z > hips_z - 0.12 and c.z < neck_z - 0.035 and (ab is None or ab[0] < V.get("manches", 0.55) or abs(c.x) < 0.17):
            f.material_index = 99 if V.get("torse_nu") else 2
        elif (genou_z + 0.04 if V.get("short") else ankle_z + 0.03) < c.z < hips_z + 0.05 and (ab is None or abs(c.x) < 0.2):
            f.material_index = 3
        else:
            f.material_index = 99
    else:  # peau
        f.material_index = 0
        if c.z < ankle_z + 0.035:
            f.material_index = 4
        # cuir chevelu : haut et arrière du crâne
        rel = c.z - tete_z
        if FOULARD:
            # foulard noué : couvre tout le crâne jusqu'au front et derrière les oreilles
            if rel > 0.115 or (rel > 0.03 and c.y > -0.02) or (rel > 0.085 and c.y > -0.085):
                f.material_index = 1
        elif rel > 0.135 or (rel > 0.05 and c.y > -0.035) or (rel > 0.1 and c.y > -0.075):
            if abs(c.x) < 0.085 or rel > 0.08:
                f.material_index = 1

bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index == 99], context="FACES")

# bords des vêtements (encolure, manches) : on lisse la ligne brisée qui suit les facettes
bord = [e for e in bm.edges if len(e.link_faces) == 1 and e.link_faces[0].material_index in (2, 3)]
voisins = {}
for e in bord:
    a_, b_ = e.verts
    voisins.setdefault(a_, []).append(b_)
    voisins.setdefault(b_, []).append(a_)
for _ in range(10):
    nouv = {}
    for v, vs in voisins.items():
        if len(vs) == 2:
            nouv[v] = v.co * 0.5 + (vs[0].co + vs[1].co) * 0.25
    for v, c in nouv.items():
        v.co = c
print("bords de vêtements lissés :", len(voisins))
# peau cachée sous les vêtements : supprimée (évite qu'elle traverse le tissu)
cache = []
for f in bm.faces:
    if f.material_index != 0:
        continue
    c = centre(f)
    ab = bras(c)
    # bras pendants en A : la droite prolongée du bras frôle la cuisse, d'où les bornes sur t et la distance
    sur_bras = ab is not None and abs(c.x) > 0.16 and ab[1] < 0.075 and -0.1 < ab[0] < 2.35
    bas_tissu = genou_z + 0.07 if V.get("short") else ankle_z + 0.07
    haut_tissu = hips_z - 0.02 if V.get("torse_nu") else neck_z - 0.075
    if bas_tissu < c.z < haut_tissu and not (sur_bras and ab[0] > max(0.4, V.get("manches", 0.55) - 0.15)):
        if not (sur_bras and ab[0] > 0.4):
            cache.append(f)
bmesh.ops.delete(bm, geom=cache, context="FACES")
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")

# épaisseurs : chemise par-dessus le pantalon, cheveux et chaussures légèrement gonflés
bm.normal_update()
gonfle = {2: 0.007, 3: 0.003, 1: 0.022 if FOULARD else 0.004, 4: 0.009}
deplace = {}
for f in bm.faces:
    g = gonfle.get(f.material_index)
    if g:
        for v in f.verts:
            deplace[v] = max(deplace.get(v, 0.0), g)
# cheveux : épaisseur qui croît depuis la lisière (pas de marche franche « calotte »)
v_cheveux = {v for f in bm.faces if f.material_index == 1 for v in f.verts}
lisiere = {v for v in v_cheveux if any(f.material_index != 1 for f in v.link_faces)}
anneau = {v: 0 for v in lisiere}
front = list(lisiere)
while front:
    suivant = []
    for v in front:
        for e in v.link_edges:
            o = e.other_vert(v)
            if o in v_cheveux and o not in anneau:
                anneau[o] = anneau[v] + 1
                suivant.append(o)
    front = suivant
centre_tete = sum((v.co for v in v_cheveux), Vector()) / max(1, len(v_cheveux))
for v, g in deplace.items():
    if v in v_cheveux:
        k = anneau.get(v, 0)
        if COIFFURE == "foulard":
            t = max(0.0, min(1.0, (v.co.z - (tete_z + 0.07)) / 0.11))
            plis = 0.005 * math.sin(math.atan2(v.co.x, v.co.y) * 8 + v.co.z * 70)
            ep = min(0.022, 0.004 + 0.006 * k)
            v.co += v.normal * (ep + plis * min(1, k / 2)) + Vector((0, 0.022 * t, 0.05 * t))
        elif COIFFURE == "afro":
            t = min(1.0, k / 7.0)
            ep = 0.02 * t * t * (3 - 2 * t) + 0.0015  # volume qui monte doucement depuis la lisière
            v.co += v.normal * ep
        else:
            t = min(1.0, k / 4.0)
            v.co += v.normal * (0.0015 + 0.0095 * t * t * (3 - 2 * t))
    else:
        v.co += v.normal * g

# ---------- éléments de coiffure ajoutés (tresses, macarons, nœud du foulard) ----------
gi_tete = {g.name: g.index for g in h.vertex_groups}["mixamorig:Head"]
dl_c = bm.verts.layers.deform.active
r_tete = sum(((v.co - centre_tete).length for v in v_cheveux), 0.0) / max(1, len(v_cheveux))
role_corps = NOMS_ROLES.index("body")


def sommet(co):
    v = bm.verts.new(co)
    v[dl_c][gi_tete] = 1.0
    v[lr] = role_corps
    return v


def tube(chemin, rayon, cotes=6, tresse=False):
    anneaux_t = []
    for i, p in enumerate(chemin):
        t = (chemin[min(i + 1, len(chemin) - 1)] - chemin[max(i - 1, 0)]).normalized()
        a = t.cross(Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))).normalized()
        b = t.cross(a)
        rr = rayon * (1.0 - 0.45 * i / (len(chemin) - 1))
        if tresse:
            rr *= 1.0 + 0.35 * abs(math.sin(i * 1.7))
        anneaux_t.append([sommet(p + (a * math.cos(2 * math.pi * k / cotes) + b * math.sin(2 * math.pi * k / cotes)) * rr) for k in range(cotes)])
    for i in range(len(anneaux_t) - 1):
        for k in range(cotes):
            f = bm.faces.new((anneaux_t[i][k], anneaux_t[i][(k + 1) % cotes], anneaux_t[i + 1][(k + 1) % cotes], anneaux_t[i + 1][k]))
            f.material_index = 1
    bout = sommet(chemin[-1] + (chemin[-1] - chemin[-2]).normalized() * 0.004)
    for k in range(cotes):
        f = bm.faces.new((anneaux_t[-1][k], anneaux_t[-1][(k + 1) % cotes], bout))
        f.material_index = 1


def boule(c, rx, ry, rz, n=10):
    pts = []
    for i in range(n // 2 + 1):
        lat = math.pi * i / (n // 2) - math.pi / 2
        pts.append([sommet(c + Vector((math.cos(lat) * math.cos(2 * math.pi * k / n) * rx, math.cos(lat) * math.sin(2 * math.pi * k / n) * ry, math.sin(lat) * rz))) for k in range(n)])
    for i in range(len(pts) - 1):
        for k in range(n):
            try:
                f = bm.faces.new((pts[i][k], pts[i][(k + 1) % n], pts[i + 1][(k + 1) % n], pts[i + 1][k]))
                f.material_index = 1
            except ValueError:
                pass


if COIFFURE == "tresses":
    import random as _r
    rg = _r.Random(VARIANTE)
    departs = [v.co.copy() for v in v_cheveux if v.co.y > centre_tete.y - 0.005 and v.co.z > centre_tete.z - 0.06]
    rg.shuffle(departs)
    retenus = []
    for p in departs:
        if all((p - q).length > 0.016 for q in retenus):
            retenus.append(p)
        if len(retenus) >= 36:
            break
    for p in retenus:
        d = (p - centre_tete).normalized()
        fin = Vector((p.x * 1.1 + rg.uniform(-0.01, 0.01), centre_tete.y + 0.075 + rg.uniform(0, 0.03), neck_z - rg.uniform(0.0, 0.12)))
        chemin = []
        for i in range(9):
            t = i / 8
            q = p.lerp(fin, t) + d * 0.012
            q += Vector((0, 0.03, 0)) * math.sin(t * math.pi)
            # rester hors du crâne
            dq = q - centre_tete
            if dq.length < r_tete + 0.012:
                q = centre_tete + dq.normalized() * (r_tete + 0.012)
            chemin.append(q)
        tube(chemin, 0.0055, 6, tresse=True)
elif COIFFURE == "chignon":
    boule(centre_tete + Vector((0, 0.085, 0.045)), 0.05, 0.042, 0.045, 12)
elif COIFFURE == "macarons":
    for sx in (-1, 1):
        boule(centre_tete + Vector((sx * 0.065, 0.015, 0.075)), 0.05, 0.05, 0.045)
elif COIFFURE == "foulard":
    # nœud du foulard sur le dessus, deux pans arrondis
    haut = max(v.co.z for v in v_cheveux)
    for sx in (-1, 1):
        boule(centre_tete + Vector((sx * 0.04, -0.01, 0)) + Vector((0, 0, haut - centre_tete.z - 0.005)), 0.05, 0.028, 0.032)
bm.normal_update()
# ---------- pagne : jupe portefeuille de la taille aux chevilles, pondérée sur bassin et cuisses ----------
if V.get("pagne") or V.get("boubou"):
    bm.verts.ensure_lookup_table()
    gi = {g.name: g.index for g in h.vertex_groups}
    g_h, g_l, g_r = gi["mixamorig:Hips"], gi["mixamorig:LeftUpLeg"], gi["mixamorig:RightUpLeg"]
    haut_z, bas_z = hips_z + 0.05, ankle_z + 0.05
    NA, NR = 28, 14
    anneaux = []
    larg_max = None
    for r in range(NR + 1):
        t = r / NR
        z = haut_z + (bas_z - haut_z) * t
        pts = [v.co for v in bm.verts if abs(v.co.z - z) < 0.025 and abs(v.co.x) < 0.3]
        if r == 0 or larg_max is None:
            xs = [p.x for p in pts]; ys = [p.y for p in pts]
            cx, cy = (max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2
            rx, ry = (max(xs) - min(xs)) / 2 + 0.012, (max(ys) - min(ys)) / 2 + 0.012
            if r == 0:
                c0 = (cx, cy)
            larg_max = (rx, ry)
        if pts and r > 0:
            xs = [p.x for p in pts]; ys = [p.y for p in pts]
            mrx, mry = (max(xs) - min(xs)) / 2 + 0.03, (max(ys) - min(ys)) / 2 + 0.03
            larg_max = (max(larg_max[0] * 0.985, mrx), max(larg_max[1] * 0.985, mry))
        rx, ry = larg_max
        anneau = []
        for a in range(NA):
            th = 2 * math.pi * a / NA
            x, y = c0[0] + rx * math.cos(th), c0[1] + ry * math.sin(th)
            v = bm.verts.new((x, y, z))
            v[lr] = NOMS_ROLES.index("helper-tights")
            k = min(1.0, t * 1.15) * 0.9
            s = max(0.0, min(1.0, 0.5 + math.cos(th) * 0.9))
            v[deform][g_h] = 1.0 - k
            if k > 0:
                v[deform][g_l] = k * s
                v[deform][g_r] = k * (1 - s)
            anneau.append(v)
        anneaux.append(anneau)
    for r in range(NR):
        for a in range(NA):
            b = (a + 1) % NA
            f = bm.faces.new((anneaux[r][a], anneaux[r + 1][a], anneaux[r + 1][b], anneaux[r][b]))
            f.material_index = 2 if V.get("boubou") else 3
    bm.normal_update()  # ordre des sommets : normales vers l'extérieur

# ---------- visage et peau peints dans les couleurs de sommets ----------
# teinte de base, sourcils, lèvres, paupières, paumes des mains plus claires, légère marbrure
yeux_v = {v for f in bm.faces if f.material_index == 5 for v in f.verts}
oeil = {}
for cote in (1, -1):
    vs = [v.co for v in yeux_v if v.co.x * cote > 0]
    oeil[cote] = sum(vs, Vector((0, 0, 0))) / max(1, len(vs))
k_tete = abs(oeil[1].x - oeil[-1].x) / 0.062
ez = (oeil[1].z + oeil[-1].z) / 2
ey = (oeil[1].y + oeil[-1].y) / 2
peau_v = [v for v in bm.verts if any(f.material_index == 0 for f in v.link_faces)]
nez = min((v for v in peau_v if abs(v.co.x) < 0.015 * k_tete and ez - 0.075 * k_tete < v.co.z < ez - 0.01 * k_tete), key=lambda v: v.co.y, default=None)
dl = bm.verts.layers.deform.active
mains = {g.index for g in h.vertex_groups if "Hand" in g.name}
bruit_peau = __import__("random").Random(VARIANTE)
graines = [(Vector((bruit_peau.uniform(-1, 1), bruit_peau.uniform(-1, 1), bruit_peau.uniform(0, 2))), bruit_peau.uniform(-0.07, 0.07)) for _ in range(40)]
teinte_v = {}
TP = Vector(V["peau"])
for v in peau_v:
    c = v.co
    f = 1.0
    # marbrure douce (peau vivante, pas une couleur unie)
    for g, a in graines:
        f += a * math.exp(-((c - g).length / 0.25) ** 2)
    m = Vector((f, f, f))
    if abs(c.y - ey) < 0.06 * k_tete or c.y < ey:
        for cote in (1, -1):
            o = oeil[cote]
            dx = (c.x - o.x) * cote  # > 0 vers l'extérieur du visage
            # sourcils : arc au-dessus de l'œil, plus fin vers l'extérieur
            haut = ez + (0.019 + 0.004 * max(0, 1 - abs(dx) / 0.02)) * k_tete
            epais = (0.0048 - 0.0018 * max(0, dx) / (0.028 * k_tete)) * k_tete
            if -0.018 * k_tete < dx < 0.028 * k_tete and abs(c.z - haut) < epais and c.y < ey + 0.01:
                w = 1.0 - (abs(c.z - haut) / epais) ** 2  # bords adoucis
                m = m.lerp(Vector((0.3, 0.26, 0.23)), 0.35 + 0.6 * w)
            # paupières et cernes un peu plus sombres
            elif (c - o).length < 0.019 * k_tete and c.y < o.y + 0.006:
                m = m * 0.78
    if nez is not None:
        zl = nez.co.z - 0.037 * k_tete
        larg = 0.026 * k_tete * max(0.0, 1 - ((c.z - zl) / (0.016 * k_tete)) ** 2) ** 0.5
        if abs(c.z - zl) < 0.016 * k_tete and abs(c.x) < larg and c.y < nez.co.y + 0.04 * k_tete:
            m = Vector((m.x * 0.82, m.y * 0.6, m.z * 0.62))  # lèvres
    if dl is not None and any(gi in mains and w > 0.4 for gi, w in v[dl].items()):
        n = v.normal
        if n.x * (1 if c.x > 0 else -1) < -0.3 or n.z < -0.5:
            m = Vector((1.75, 1.5, 1.4))  # paumes et intérieur des doigts
    teinte_v[v] = Vector((TP.x * m.x, TP.y * m.y, TP.z * m.z))
print("visage : facteur tête", round(k_tete, 2), "nez", nez is not None)

# yeux : iris sombre vers l'avant
col = bm.loops.layers.color.new("Col")
for f in bm.faces:
    for l in f.loops:
        if f.material_index == 0:
            t = teinte_v.get(l.vert, TP)
            # la couche de couleur est stockée en sRGB : on convertit la teinte linéaire
            l[col] = tuple(min(1.0, max(0.0, x)) ** (1 / 2.2) for x in (t.x, t.y, t.z)) + (1,)
        elif f.material_index == 5:
            n = l.vert.normal
            iris = n.y < -0.86
            pup = n.y < -0.975
            l[col] = (0.02, 0.015, 0.01, 1) if pup else ((0.16, 0.08, 0.04, 1) if iris else (0.74, 0.7, 0.64, 1))
        else:
            l[col] = (1, 1, 1, 1)
bm.to_mesh(me)
bm.free()
me.update()

# poids portés par des os qui ne déforment pas (bouts des orteils, etc.) : transférés à l'os parent
deform = {b.name for b in rig.data.bones if b.use_deform}
non_def = {b.name: b for b in rig.data.bones if not b.use_deform}
print("os non déformants", list(non_def)[:10])
idx_groupes = {g.index: g.name for g in h.vertex_groups}
transferts = 0
for v in me.vertices:
    for g in list(v.groups):
        nom = idx_groupes[g.group]
        if nom in non_def and g.weight > 0:
            b = non_def[nom].parent
            while b and b.name not in deform:
                b = b.parent
            if b:
                cible = h.vertex_groups.get(b.name) or h.vertex_groups.new(name=b.name)
                cible.add([v.index], g.weight, "ADD")
                h.vertex_groups[nom].remove([v.index])
                transferts += 1
print("poids transférés", transferts)

# UV pour les tissus (projection automatique, échelle de tissage réaliste)
uv_tissu = me.uv_layers.new(name="Tissu")
me.uv_layers.active = uv_tissu
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.01, scale_to_bounds=False)
bpy.ops.object.mode_set(mode="OBJECT")
uvs_t = me.uv_layers["Tissu"].data
import numpy as np
buf = np.zeros(len(uvs_t) * 2, dtype=np.float32)
uvs_t.foreach_get("uv", buf)
uvs_t.foreach_set("uv", buf * 8.0)
me.update()
for lay in [l.name for l in me.uv_layers if l.name != "Tissu"]:
    me.uv_layers.remove(me.uv_layers[lay])

for p in me.polygons:
    p.use_smooth = True
h.name = VARIANTE.capitalize()
rig.name = "Squelette"

# ---------- animations (en place) ----------
P = {pb.name.replace("mixamorig:", ""): pb for pb in rig.pose.bones}
for pb in rig.pose.bones:
    pb.rotation_mode = "QUATERNION"
X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
vl = bpy.context.view_layer


def raz():
    for pb in rig.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)
    vl.update()


def rot(nom, axe, deg):
    pb = P[nom]
    M = pb.matrix.copy()
    piv = M.translation.copy()
    pb.matrix = Matrix.Translation(piv) @ Matrix.Rotation(math.radians(deg), 4, axe) @ Matrix.Translation(-piv) @ M
    vl.update()


def vers(nom, parent_dir_bone, deg):
    """plie/déplie un os autour de l'axe perpendiculaire à lui et à l'os parent"""
    pb = P[nom]
    d = (pb.tail - pb.head).normalized()
    a = (P[parent_dir_bone].tail - P[parent_dir_bone].head).normalized()
    axe = d.cross(a)
    if axe.length < 1e-4:
        return
    rot(nom, axe.normalized(), deg)


ECH = hips_z / 0.968  # les poses sont réglées sur Faris : on les met à l'échelle des corps plus petits


def bouge_hanches(dz, dx=0.0):
    pb = P["Hips"]
    M = pb.matrix.copy()
    M.translation += Vector((dx, 0, dz)) * ECH
    pb.matrix = M
    vl.update()


def bras_bas(ecart=30, coude=28):
    rot("LeftArm", Y, ecart)
    rot("RightArm", Y, -ecart)
    vers("LeftForeArm", "LeftArm", coude)
    vers("RightForeArm", "RightArm", coude)


def cle(f):
    for pb in rig.pose.bones:
        pb.keyframe_insert("rotation_quaternion", frame=f)
    P["Hips"].keyframe_insert("location", frame=f)


def nouvelle(nom):
    act = bpy.data.actions.new(nom)
    act.use_fake_user = True
    rig.animation_data_create()
    rig.animation_data.action = act
    return act


def jambe(cote, phi, amp_cuisse, amp_genou, genou_appui):
    cuisse = -amp_cuisse * math.cos(phi)
    s = math.sin(phi - math.pi)
    genou = genou_appui + (amp_genou * (max(0.0, s) ** 1.3) if s > 0 else genou_appui * 0.6 * abs(math.sin(phi)))
    rot(cote + "UpLeg", X, cuisse)
    rot(cote + "Leg", X, genou)
    pointe = 12.0 * max(0.0, math.sin(phi - 0.75 * math.pi)) if 0.6 * math.pi < phi % (2 * math.pi) < math.pi * 1.1 else 0.0
    rot(cote + "Foot", X, -(cuisse + genou) * 0.85 + pointe)


def cycle(nom, images, amp_cuisse, amp_genou, genou_appui, amp_bras, coude, rebond, penche, rotation_bassin):
    nouvelle(nom)
    for f in range(0, images + 1, 2):
        phi = 2 * math.pi * f / images
        raz()
        bouge_hanches(-rebond * (0.5 + 0.5 * math.cos(2 * phi)), 0.012 * math.sin(phi))
        rot("Hips", Z, -rotation_bassin * math.cos(phi))
        if FEMININ and not ENFANT:
            # démarche féminine : bassin qui se balance et bascule, pas posés sur une ligne, buste plus droit
            bouge_hanches(0, 0.014 * math.sin(phi))
            rot("Hips", Y, 4.5 * math.sin(phi))
            rot("Spine1", Y, -3.0 * math.sin(phi))
        rot("Spine", X, penche * 0.5 + (9 if AGE else 0))
        rot("Spine1", X, penche * 0.5 + (5 if AGE else 0))
        if AGE:
            rot("Neck", X, -9)
        rot("Spine2", Z, rotation_bassin * 1.2 * math.cos(phi))
        rot("Head", X, -penche * 0.6)
        jambe("Left", phi, amp_cuisse, amp_genou, genou_appui)
        jambe("Right", phi + math.pi, amp_cuisse, amp_genou, genou_appui)
        if FEMININ and not ENFANT:
            rot("LeftUpLeg", Y, 3.5)
            rot("RightUpLeg", Y, -3.5)
            bras_bas(27, coude * 0.8)
            rot("LeftArm", X, amp_bras * 0.7 * math.cos(phi))
            rot("RightArm", X, -amp_bras * 0.7 * math.cos(phi))
        else:
            bras_bas(31, coude)
            rot("LeftArm", X, amp_bras * math.cos(phi))
            rot("RightArm", X, -amp_bras * math.cos(phi))
        cle(f)


# Repos : respiration et léger transfert de poids
nouvelle("Repos")
for f in range(0, 121, 6):
    p = 2 * math.pi * f / 120
    raz()
    bouge_hanches(-0.004 * (1 + math.sin(p)), 0.01 * math.sin(p))
    rot("Spine1", X, -1.2 * math.sin(2 * p))
    rot("Spine2", X, -0.8 * math.sin(2 * p))
    rot("Head", Z, 3 * math.sin(p))
    if FEMININ and not ENFANT:  # appui sur une hanche, l'autre genou fléchi
        bouge_hanches(0, 0.025)
        rot("Hips", Y, 4)
        rot("Spine1", Y, -3)
        rot("LeftUpLeg", Y, 2)
        rot("RightUpLeg", Y, -6)
        rot("RightLeg", X, 14)
    else:
        rot("LeftUpLeg", Y, 2)
        rot("RightUpLeg", Y, -3)
        rot("LeftLeg", X, 3)
        rot("RightLeg", X, 5)
    if AGE:  # dos un peu voûté, genoux légèrement fléchis
        rot("Spine", X, 8)
        rot("Spine1", X, 5)
        rot("Neck", X, -8)
        rot("LeftLeg", X, 6)
        rot("RightLeg", X, 6)
    bras_bas(31 + 1.5 * math.sin(2 * p), 22)
    cle(f)

if AGE:
    # pas plus courts et plus lents, bras qui balancent peu
    cycle("Marche", 42, 15, 36, 6, 8, 20, 0.012, 4, 4)
    cycle("Course", 26, 24, 60, 14, 18, 50, 0.025, 10, 6)
elif FEMININ and not ENFANT:
    cycle("Marche", 34, 19, 44, 5, 13, 18, 0.018, 1, 8)
    cycle("Course", 20, 32, 85, 20, 30, 75, 0.04, 8, 10)
else:
    cycle("Marche", 32, 22, 48, 6, 16, 22, 0.025, 3, 5)
    cycle("Course", 20, 38, 95, 22, 38, 80, 0.05, 12, 9)

nouvelle("Saut")
for f in (0, 10):
    raz()
    rot("Spine", X, 6)
    rot("LeftUpLeg", X, -35)
    rot("LeftLeg", X, 55)
    rot("LeftFoot", X, -15)
    rot("RightUpLeg", X, -10)
    rot("RightLeg", X, 35)
    rot("RightFoot", X, -20)
    bras_bas(10, 40)
    rot("LeftArm", X, -25)
    rot("RightArm", X, -15)
    cle(f)

nouvelle("Nage")
for f in range(0, 41, 2):
    p = 2 * math.pi * f / 40
    raz()
    rot("Spine", X, 15)
    rot("Head", X, -20)
    for cote, s in (("Left", 1), ("Right", -1)):
        rot(cote + "UpLeg", X, -25 + 18 * math.sin(p + (0 if s > 0 else math.pi)))
        rot(cote + "Leg", X, 50 + 25 * math.sin(p + 0.8 + (0 if s > 0 else math.pi)))
        rot(cote + "Arm", Y, s * 75)
        rot(cote + "Arm", Z, s * 25 * math.sin(p * 2))
        vers(cote + "ForeArm", cote + "Arm", 20)
    cle(f)


# ---------- postures de combat (cinématique inverse pour placer les mains) ----------
HAUT = ["Spine", "Spine1", "Spine2", "Neck", "Head", "LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand",
        "RightShoulder", "RightArm", "RightForeArm", "RightHand"]


def cle_haut(f):
    for n in HAUT:
        if n in P:
            P[n].keyframe_insert("rotation_quaternion", frame=f)


def main_vers(cote, cible, pole):
    """Place la main (cote = Left/Right) sur un point du squelette (mètres, repère Blender)."""
    pb = P[cote + "ForeArm"]
    vides = []
    for pos in (cible, pole):
        e = bpy.data.objects.new("cible", None)
        e.location = Vector(pos) * ECH
        bpy.context.scene.collection.objects.link(e)
        vides.append(e)
    c = pb.constraints.new("IK")
    c.target = vides[0]
    c.pole_target = vides[1]
    c.pole_angle = math.radians(-90)
    c.chain_count = 2
    vl.update()
    m_bras = P[cote + "Arm"].matrix.copy()
    m_avant = pb.matrix.copy()
    pb.constraints.remove(c)
    for e in vides:
        bpy.data.objects.remove(e)
    vl.update()
    P[cote + "Arm"].matrix = m_bras
    vl.update()
    pb.matrix = m_avant
    vl.update()


def pose_visee():
    rot("Spine2", Z, 8)
    rot("Head", X, 4)
    rot("Head", Z, -6)
    main_vers("Right", (-0.12, -0.28, 1.31), (-0.75, 0.15, 0.95))
    main_vers("Left", (-0.04, -0.60, 1.35), (0.45, -0.2, 0.85))


nouvelle("Visee")  # haut du corps seulement : se superpose à la marche
for f in (0, 20):
    raz()
    pose_visee()
    cle_haut(f)

nouvelle("Moto")  # assis sur une moto, mains sur le guidon, pieds sur les repose-pieds
for f in (0, 20):
    raz()
    bouge_hanches(-0.13)
    rot("Spine", X, 10)
    rot("Spine1", X, 4)
    rot("Head", X, -10)
    for cote in ("Left", "Right"):
        rot(cote + "UpLeg", X, -68)
        rot(cote + "Leg", X, 82)
        rot(cote + "Foot", X, -12)
    rot("LeftUpLeg", Z, 9)
    rot("RightUpLeg", Z, -9)
    main_vers("Right", (-0.31, -0.50, 1.03), (-0.75, 0.1, 0.85))
    main_vers("Left", (0.31, -0.50, 1.03), (0.75, 0.1, 0.85))
    cle(f)

nouvelle("Accroupi")
for f in range(0, 61, 6):
    p = 2 * math.pi * f / 60
    raz()
    bouge_hanches(-0.36 - 0.006 * math.sin(p))
    rot("Spine", X, 18)
    rot("Spine1", X, 6 + 1.0 * math.sin(2 * p))
    rot("Head", X, -16)
    for cote in ("Left", "Right"):
        rot(cote + "UpLeg", X, -62)
        rot(cote + "Leg", X, 112)
        rot(cote + "Foot", X, -48)
    rot("LeftUpLeg", Z, 8)
    rot("RightUpLeg", Z, -8)
    bras_bas(25, 35)
    cle(f)

nouvelle("AccroupiMarche")
for f in range(0, 37, 2):
    phi = 2 * math.pi * f / 36
    raz()
    bouge_hanches(-0.34 - 0.02 * (0.5 + 0.5 * math.cos(2 * phi)))
    rot("Spine", X, 20)
    rot("Head", X, -18)
    for cote, ph in (("Left", phi), ("Right", phi + math.pi)):
        cuisse = -55 - 22 * math.cos(ph)
        genou = 100 + 25 * max(0.0, math.sin(ph - math.pi))
        rot(cote + "UpLeg", X, cuisse)
        rot(cote + "Leg", X, genou)
        rot(cote + "Foot", X, -(cuisse + genou) * 0.85)
    bras_bas(25, 35)
    rot("LeftArm", X, 10 * math.cos(phi))
    rot("RightArm", X, -10 * math.cos(phi))
    cle(f)

nouvelle("Rendu")  # à genoux, mains sur la tête
for f in range(0, 61, 10):
    p = 2 * math.pi * f / 60
    raz()
    bouge_hanches(-0.47)
    rot("Spine", X, 6 + 1.5 * math.sin(p))
    rot("Head", X, 14)
    for cote in ("Left", "Right"):
        rot(cote + "Leg", X, 92)
        rot(cote + "Foot", X, -30)
    main_vers("Right", (-0.09, 0.0, 1.30), (-0.75, -0.2, 1.15))
    main_vers("Left", (0.09, 0.0, 1.30), (0.75, -0.2, 1.15))
    cle(f)

nouvelle("Ligote")  # à genoux, mains liées dans le dos
for f in (0, 30):
    raz()
    bouge_hanches(-0.47)
    rot("Spine", X, 10)
    rot("Head", X, 20)
    for cote in ("Left", "Right"):
        rot(cote + "Leg", X, 92)
        rot(cote + "Foot", X, -30)
    main_vers("Right", (-0.05, 0.16, 0.55), (-0.6, 0.3, 0.75))
    main_vers("Left", (0.05, 0.16, 0.55), (0.6, 0.3, 0.75))
    cle(f)

nouvelle("Mort")  # allongé sur le dos
for f in (0, 10):
    raz()
    rot("Hips", X, -88)
    bouge_hanches(-0.84)
    rot("Head", Z, 25)
    rot("LeftArm", Y, 55)
    rot("RightArm", Y, -40)
    rot("LeftUpLeg", Z, 6)
    rot("RightLeg", X, 25)
    cle(f)

raz()
rig.animation_data.action = bpy.data.actions["Repos"]
for act in bpy.data.actions:
    for fc in act.fcurves:
        for kp in fc.keyframe_points:
            kp.interpolation = "BEZIER"

bpy.ops.wm.save_as_mainfile(filepath=f"/home/claude/faris/{VARIANTE}.blend")
for o in bpy.context.selected_objects:
    o.select_set(False)
h.select_set(True)
rig.select_set(True)
bpy.ops.export_scene.gltf(filepath=f"/home/claude/faris/{VARIANTE}.glb", export_format="GLB", use_selection=True,
                          export_animations=True, export_animation_mode="ACTIONS", export_skins=True,
                          export_yup=True, export_image_format="JPEG", export_jpeg_quality=88)
print("EXPORT OK", [a.name for a in bpy.data.actions])

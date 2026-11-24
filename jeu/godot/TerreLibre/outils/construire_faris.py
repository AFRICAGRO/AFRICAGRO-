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

for o in list(bpy.data.objects):
    bpy.data.objects.remove(o)

h = HumanService.create_human()
for k, v in [("african", 1.0), ("asian", 0.0), ("caucasian", 0.0), ("gender", 1.0), ("age", 0.5),
             ("muscle", 0.62), ("weight", 0.48), ("height", 0.38), ("proportions", 0.7)]:
    try:
        HOP.set_value(k, v, entity_reference=h)
    except Exception as e:
        print("macro", k, e)
TargetService.reapply_macro_details(h)
troot = LocationService.get_mpfb_data("targets")
for rel, w in [("nose/nose-scale-horiz-incr.target.gz", 0.35), ("mouth/mouth-scale-horiz-incr.target.gz", 0.2),
               ("chin/chin-prominent-incr.target.gz", 0.2)]:
    p = os.path.join(troot, rel)
    if os.path.exists(p):
        TargetService.load_target(h, p, weight=w)
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
        t.image = bpy.data.images.load(TEX + tex)
        if couleur != (1, 1, 1):
            mix = nt.nodes.new("ShaderNodeMix")
            mix.data_type = "RGBA"
            mix.blend_type = "MULTIPLY"
            mix.inputs[0].default_value = 1.0
            nt.links.new(t.outputs["Color"], mix.inputs[6])
            mix.inputs[7].default_value = (*couleur, 1)
            nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
        else:
            nt.links.new(t.outputs["Color"], bsdf.inputs["Base Color"])
    if normal:
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = bpy.data.images.load(TEX + normal)
        t.image.colorspace_settings.name = "Non-Color"
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(t.outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    if vcol:
        a = nt.nodes.new("ShaderNodeVertexColor")
        a.layer_name = "Col"
        nt.links.new(a.outputs["Color"], bsdf.inputs["Base Color"])
    return m


me.materials.clear()
for m in [mat("Peau", (0.10, 0.042, 0.02), 0.55),
          mat("Cheveux", (0.012, 0.009, 0.008), 0.95),
          mat("Chemise", (1, 1, 1), 0.9, "wax_diff.jpg", "rough_linen_nor.jpg"),
          mat("Pantalon", (0.42, 0.40, 0.33), 0.85, "denim_fabric_03_diff.jpg", "denim_fabric_03_nor.jpg"),
          mat("Chaussures", (0.2, 0.15, 0.12), 0.6, "brown_leather_diff.jpg", "brown_leather_nor.jpg"),
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



GARDER = {"body", "helper-tights", "helper-l-eye", "helper-r-eye", "helper-upper-teeth", "helper-lower-teeth", "helper-tongue"}
a_suppr = [f for f in bm.faces if any(R(v) not in GARDER for v in f.verts)]
bmesh.ops.delete(bm, geom=a_suppr, context="FACES")

# matériaux : 0 peau, 1 cheveux, 2 chemise, 3 pantalon, 4 chaussures, 5 yeux, 6 dents
NOMS = ["Peau", "Cheveux", "Chemise", "Pantalon", "Chaussures", "Yeux", "Dents"]


def centre(f):
    return sum((v.co for v in f.verts), Vector()) / len(f.verts)


tete_z = B["Head"].head_local.z
for f in bm.faces:
    r = R(f.verts[0])
    c = centre(f)
    if r in ("helper-l-eye", "helper-r-eye"):
        f.material_index = 5
    elif r in ("helper-upper-teeth", "helper-lower-teeth", "helper-tongue"):
        f.material_index = 6
    elif r == "helper-tights":
        ab = bras(c)
        if c.z > hips_z - 0.12 and c.z < neck_z - 0.035 and (ab is None or ab[0] < 0.55 or abs(c.x) < 0.17):
            f.material_index = 2
        elif ankle_z + 0.03 < c.z < hips_z + 0.05 and (ab is None or abs(c.x) < 0.2):
            f.material_index = 3
        else:
            f.material_index = 99
    else:  # peau
        f.material_index = 0
        if c.z < ankle_z + 0.035:
            f.material_index = 4
        # cuir chevelu : haut et arrière du crâne
        rel = c.z - tete_z
        if rel > 0.135 or (rel > 0.05 and c.y > -0.035) or (rel > 0.1 and c.y > -0.075):
            if abs(c.x) < 0.085 or rel > 0.08:
                f.material_index = 1

bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index == 99], context="FACES")
# peau cachée sous les vêtements : supprimée (évite qu'elle traverse le tissu)
cache = []
for f in bm.faces:
    if f.material_index != 0:
        continue
    c = centre(f)
    ab = bras(c)
    sur_bras = ab is not None and abs(c.x) > 0.16 and ab[1] < 0.12
    if ankle_z + 0.07 < c.z < neck_z - 0.075 and not (sur_bras and ab[0] > 0.4):
        if not (sur_bras and ab[0] > 0.4):
            cache.append(f)
bmesh.ops.delete(bm, geom=cache, context="FACES")
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")

# épaisseurs : chemise par-dessus le pantalon, cheveux et chaussures légèrement gonflés
bm.normal_update()
gonfle = {2: 0.007, 3: 0.003, 1: 0.004, 4: 0.009}
deplace = {}
for f in bm.faces:
    g = gonfle.get(f.material_index)
    if g:
        for v in f.verts:
            deplace[v] = max(deplace.get(v, 0.0), g)
for v, g in deplace.items():
    v.co += v.normal * g
# yeux : iris sombre vers l'avant
col = bm.loops.layers.color.new("Col")
for f in bm.faces:
    for l in f.loops:
        if f.material_index == 5:
            n = l.vert.normal
            iris = n.y < -0.86
            pup = n.y < -0.975
            l[col] = (0.02, 0.015, 0.01, 1) if pup else ((0.16, 0.08, 0.04, 1) if iris else (0.9, 0.88, 0.85, 1))
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
h.name = "Faris"
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


def bouge_hanches(dz, dx=0.0):
    pb = P["Hips"]
    M = pb.matrix.copy()
    M.translation += Vector((dx, 0, dz))
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
        rot("Spine", X, penche * 0.5)
        rot("Spine1", X, penche * 0.5)
        rot("Spine2", Z, rotation_bassin * 1.2 * math.cos(phi))
        rot("Head", X, -penche * 0.6)
        jambe("Left", phi, amp_cuisse, amp_genou, genou_appui)
        jambe("Right", phi + math.pi, amp_cuisse, amp_genou, genou_appui)
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
    rot("LeftUpLeg", Y, 2)
    rot("RightUpLeg", Y, -3)
    rot("LeftLeg", X, 3)
    rot("RightLeg", X, 5)
    bras_bas(31 + 1.5 * math.sin(2 * p), 22)
    cle(f)

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
        e.location = Vector(pos)
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

bpy.ops.wm.save_as_mainfile(filepath="/home/claude/faris/faris.blend")
for o in bpy.context.selected_objects:
    o.select_set(False)
h.select_set(True)
rig.select_set(True)
bpy.ops.export_scene.gltf(filepath="/home/claude/faris/faris.glb", export_format="GLB", use_selection=True,
                          export_animations=True, export_animation_mode="ACTIONS", export_skins=True,
                          export_yup=True, export_image_format="JPEG", export_jpeg_quality=88)
print("EXPORT OK", [a.name for a in bpy.data.actions])

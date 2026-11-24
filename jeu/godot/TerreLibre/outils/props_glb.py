"""Convertit les modèles Poly Haven (glTF 1k) en .glb compacts (textures 512 px) pour le jeu."""
import bpy, os, sys
SRC = "/home/claude/props"
DST = "/home/claude/props_glb"
os.makedirs(DST, exist_ok=True)
for n in sorted(os.listdir(SRC)):
    f = os.path.join(SRC, n, n + ".gltf")
    if not os.path.exists(f):
        continue
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=f)
    for img in bpy.data.images:
        if img.size[0] > 512:
            img.scale(512, 512)
    mins = [1e9] * 3; maxs = [-1e9] * 3
    for o in bpy.data.objects:
        if o.type == "MESH":
            for c in o.bound_box:
                w = o.matrix_world @ __import__("mathutils").Vector(c)
                for k in range(3):
                    mins[k] = min(mins[k], w[k]); maxs[k] = max(maxs[k], w[k])
    print("TAILLE", n, [round(maxs[k] - mins[k], 2) for k in range(3)])
    bpy.ops.export_scene.gltf(filepath=os.path.join(DST, n.lower() + ".glb"), export_format="GLB", export_image_format="JPEG", export_jpeg_quality=85)
print("FINI")

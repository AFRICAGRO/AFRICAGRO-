## Végétation réaliste et légère :
## - forêt : arbres « imposteurs » (rendus photo d'arbres réels sur plans croisés, Poly Haven CC0) ;
## - côte : cocotiers construits en code (tronc texturé, palmes découpées), courbés et variés.
## Tout est en MultiMesh par blocs, masqués au-delà d'une distance, pour un PC modeste.
class_name Vegetation
extends Node3D

const BLOCS := 8
const DISTANCE_ARBRES := 1500.0
const DISTANCE_PALMIERS := 900.0
# espèce -> [échelle min, échelle max, part de la forêt]
const ESPECES := {
	"jacaranda_tree": [0.45, 0.85, 0.45],
	"island_tree_01": [1.8, 3.0, 0.35],
	"island_tree_02": [2.0, 3.2, 0.20],
}

var terrain: Terrain


## zones_vides : liste de Vector3(x, z, rayon) où rien ne pousse (villes, villages, piste).
func construire(t: Terrain, zones_vides: Array = []) -> void:
	terrain = t
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/arbres/arbres.json"))
	var maillages := {}
	for esp in ESPECES:
		maillages[esp] = _maillage_imposteur(meta[esp])
	var palmiers: Array = [_maillage_palmier(rng, 12), _maillage_palmier(rng, 14), _maillage_palmier(rng, 16)]

	var lots := {} # nom du modèle -> { bloc -> [transformations] }
	var demi := Terrain.TAILLE * 0.5
	for i in 160000:
		var x := rng.randf_range(-demi, demi)
		var z := rng.randf_range(-demi, demi)
		var h := terrain.hauteur(x, z)
		if h < 0.8:
			continue
		var libre := true
		for zv in zones_vides:
			if Vector2(x - zv.x, z - zv.y).length() < zv.z:
				libre = false
				break
		if not libre:
			continue
		var p := terrain.pente(x, z)
		var cle := Vector2i(int((x + demi) / Terrain.TAILLE * BLOCS), int((z + demi) / Terrain.TAILLE * BLOCS))
		if h < 16.0 and p < 0.35:
			if rng.randf() < 0.45:
				var k := rng.randi_range(0, 2)
				_ajouter(lots, "palmier%d" % k, cle, x, h, z, rng, 0.8, 1.2, true)
		elif h >= 8.0 and p < 0.95 and rng.randf() < 0.85:
			var r := rng.randf()
			var cumul := 0.0
			for esp in ESPECES:
				cumul += ESPECES[esp][2]
				if r <= cumul:
					_ajouter(lots, esp, cle, x, h, z, rng, ESPECES[esp][0], ESPECES[esp][1], false)
					break
	for nom in lots:
		var mesh: Mesh
		var dist := DISTANCE_ARBRES
		if nom.begins_with("palmier"):
			mesh = palmiers[int(nom.right(1))]
			dist = DISTANCE_PALMIERS
		else:
			mesh = maillages[nom]
		_creer_blocs(lots[nom], mesh, nom, dist)


func _ajouter(lots: Dictionary, nom: String, cle: Vector2i, x: float, h: float, z: float, rng: RandomNumberGenerator, smin: float, smax: float, palmier: bool) -> void:
	if not lots.has(nom):
		lots[nom] = {}
	if not lots[nom].has(cle):
		lots[nom][cle] = []
	var s := rng.randf_range(smin, smax)
	var b := Basis(Vector3.UP, rng.randf() * TAU)
	if palmier: # les cocotiers penchent, souvent vers la mer
		b = b * Basis(Vector3(1, 0, 0), rng.randf_range(0.0, 0.22))
	b = b.scaled(Vector3(s, s * rng.randf_range(0.9, 1.15), s))
	var teinte := Color(rng.randf_range(0.82, 1.08), rng.randf_range(0.88, 1.08), rng.randf_range(0.8, 1.0))
	lots[nom][cle].append([Transform3D(b, Vector3(x, h - 0.3, z)), teinte])


func _creer_blocs(blocs: Dictionary, mesh: Mesh, nom: String, distance: float) -> void:
	for cle in blocs:
		var liste: Array = blocs[cle]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = mesh
		mm.instance_count = liste.size()
		for i in liste.size():
			mm.set_instance_transform(i, liste[i][0])
			mm.set_instance_color(i, liste[i][1])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "%s_%d_%d" % [nom, cle.x, cle.y]
		mmi.multimesh = mm
		mmi.visibility_range_end = distance
		mmi.visibility_range_end_margin = 150.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		add_child(mmi)


## Deux plans croisés portant les deux vues photographiées de l'arbre.
func _maillage_imposteur(vues: Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for v in 2:
		var d: Dictionary = vues[v]
		var g: float = d["gauche"]
		var dr: float = d["droite"]
		var b: float = d["bas"]
		var hh: float = d["haut"]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var coins: Array = []
		if v == 0: # plan XY, vu depuis +Z
			coins = [Vector3(g, hh, 0), Vector3(dr, hh, 0), Vector3(dr, b, 0), Vector3(g, b, 0)]
			st.set_normal(Vector3(0, 0, 1))
		else: # plan ZY, vu depuis +X (la droite de l'image est vers -Z)
			coins = [Vector3(0, hh, -g), Vector3(0, hh, -dr), Vector3(0, b, -dr), Vector3(0, b, -g)]
			st.set_normal(Vector3(1, 0, 0))
		var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_uv(uvs[k])
			st.add_vertex(coins[k])
		mesh = st.commit(mesh)
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/imposteur.gdshader")
		mat.set_shader_parameter("image", load("res://data/arbres/" + d["image"]))
		mesh.surface_set_material(v, mat)
	return mesh


## Cocotier : tronc courbe texturé + couronne de palmes retombantes.
func _maillage_palmier(rng: RandomNumberGenerator, nb_palmes: int) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	# --- tronc ---
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 10
	var cotes := 8
	var hauteur := rng.randf_range(9.0, 13.0)
	var courbure := rng.randf_range(0.6, 1.6)
	var centres: Array = []
	for i in segs + 1:
		var t := float(i) / segs
		centres.append(Vector3(courbure * t * t * 1.6, t * hauteur, 0))
	for i in segs:
		var r0 := lerpf(0.24, 0.15, float(i) / segs)
		var r1 := lerpf(0.24, 0.15, float(i + 1) / segs)
		for j in cotes:
			var a0 := TAU * j / cotes
			var a1 := TAU * (j + 1) / cotes
			var p := [centres[i] + Vector3(cos(a0), 0, sin(a0)) * r0, centres[i] + Vector3(cos(a1), 0, sin(a1)) * r0,
				centres[i + 1] + Vector3(cos(a1), 0, sin(a1)) * r1, centres[i + 1] + Vector3(cos(a0), 0, sin(a0)) * r1]
			var u0 := float(j) / cotes
			var u1 := float(j + 1) / cotes
			var v0: float = centres[i].y / 2.5
			var v1: float = centres[i + 1].y / 2.5
			var uv := [Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)]
			for k in [0, 2, 1, 0, 3, 2]:
				st.set_uv(uv[k])
				st.set_normal((p[k] - centres[i if k < 2 else i + 1]).normalized())
				st.add_vertex(p[k])
	st.generate_tangents()
	mesh = st.commit(mesh)
	var mt := StandardMaterial3D.new()
	mt.albedo_texture = load("res://data/textures/palmier_diff.jpg")
	mt.normal_enabled = true
	mt.normal_texture = load("res://data/textures/palmier_nor.jpg")
	mt.roughness = 0.9
	mesh.surface_set_material(0, mt)
	# --- palmes ---
	var sp := SurfaceTool.new()
	sp.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sommet: Vector3 = centres[segs]
	for f in nb_palmes:
		var az := TAU * f / nb_palmes + rng.randf_range(-0.2, 0.2)
		var longueur := rng.randf_range(4.0, 5.8)
		var montee := rng.randf_range(0.2, 1.3)
		var largeur := rng.randf_range(2.3, 2.9)
		var dir := Vector3(cos(az), 0, sin(az))
		var cote := dir.cross(Vector3.UP).normalized()
		var n := 8
		var pts: Array = []
		for i in n + 1:
			var t := float(i) / n
			# arc : monte puis retombe
			pts.append(sommet + dir * longueur * t + Vector3.UP * (montee * sin(t * PI * 0.8) - t * t * 2.2))
		for i in n:
			var w0 := largeur * 0.5 * sin(PI * clampf(float(i) / n * 1.05, 0.05, 1.0))
			var w1 := largeur * 0.5 * sin(PI * clampf(float(i + 1) / n * 1.05, 0.05, 1.0))
			var q := [pts[i] - cote * w0, pts[i] + cote * w0, pts[i + 1] + cote * w1, pts[i + 1] - cote * w1]
			var t0 := float(i) / n
			var t1 := float(i + 1) / n
			var uv := [Vector2(t0, 0), Vector2(t0, 1), Vector2(t1, 1), Vector2(t1, 0)]
			var d1: Vector3 = pts[i + 1] - pts[i]
			var nrm := d1.cross(cote).normalized()
			if nrm.y < 0:
				nrm = -nrm
			for k in [0, 1, 2, 0, 2, 3]:
				sp.set_uv(uv[k])
				sp.set_normal(nrm.lerp(Vector3.UP, 0.4).normalized())
				sp.add_vertex(q[k])
	mesh = sp.commit(mesh)
	var mp := StandardMaterial3D.new()
	mp.albedo_texture = load("res://data/textures/palme.png")
	mp.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mp.alpha_scissor_threshold = 0.4
	mp.cull_mode = BaseMaterial3D.CULL_DISABLED
	mp.vertex_color_use_as_albedo = false
	mp.roughness = 0.85
	mesh.surface_set_material(1, mp)
	return mesh

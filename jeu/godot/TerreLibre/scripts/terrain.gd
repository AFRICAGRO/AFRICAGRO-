## Terrain de l'île de Talanké, construit à partir du relief satellite réel.
## Les hauteurs viennent de data/talanke_505.f32 (505 × 505 valeurs en mètres, float32).
class_name Terrain
extends Node3D

const N := 505
const TAILLE := 5383.0 # côté du terrain en mètres
const FICHIER := "res://data/talanke_505.f32"

var hauteurs := PackedFloat32Array()
## Terrassements pour poser les villages à plat (remplis avant l'ajout à la scène).
## Chaque entrée : {"centre": Vector2, "avant_min", "avant_max", "cote", "marge", "base", "pente"} ;
## "mer" (direction de la mer) est calculée automatiquement.
var aplanissements: Array = []
var pas := TAILLE / float(N - 1)


func _ready() -> void:
	var f := FileAccess.open(FICHIER, FileAccess.READ)
	if f == null:
		push_error("Relief introuvable : " + FICHIER)
		return
	hauteurs = f.get_buffer(N * N * 4).to_float32_array()
	_aplanir()
	_construire_maillage()
	_construire_collision()


func _aplanir() -> void:
	var demi := TAILLE * 0.5
	for ap in aplanissements:
		var c: Vector2 = ap["centre"]
		# la mer est du côté où le sol descend le plus, à 80 m
		var bas := INF
		var mer := Vector2(-1, 0)
		for i in 16:
			var d := Vector2(cos(i * PI / 8.0), sin(i * PI / 8.0))
			var z := hauteur(c.x + d.x * 80.0, c.y + d.y * 80.0)
			if z < bas:
				bas = z
				mer = d
		ap["mer"] = mer
		var plage := Vector2(-mer.y, mer.x)
		var nouv := hauteurs.duplicate()
		for r in N:
			for col in N:
				var p := Vector2(col * pas - demi, r * pas - demi) - c
				var avant := p.dot(mer)
				var cote := absf(p.dot(plage))
				var dehors := maxf(maxf(ap["avant_min"] - avant, avant - ap["avant_max"]), cote - ap["cote"])
				if dehors > ap["marge"]:
					continue
				var w := 1.0 - smoothstep(0.0, ap["marge"], maxf(dehors, 0.0))
				var cible: float = ap["base"] + maxf(0.0, -avant) * ap["pente"]
				var i := r * N + col
				nouv[i] = lerpf(hauteurs[i], cible, w)
		hauteurs = nouv


func _h(c: int, r: int) -> float:
	return hauteurs[clampi(r, 0, N - 1) * N + clampi(c, 0, N - 1)]


## Hauteur du sol (en mètres) à une position du monde.
func hauteur(x: float, z: float) -> float:
	var u := (x / TAILLE + 0.5) * (N - 1)
	var v := (z / TAILLE + 0.5) * (N - 1)
	if u < 0.0 or v < 0.0 or u > N - 1 or v > N - 1:
		return -20.0
	var c := mini(int(u), N - 2)
	var r := mini(int(v), N - 2)
	var fu := u - c
	var fv := v - r
	var a := _h(c, r) * (1.0 - fu) + _h(c + 1, r) * fu
	var b := _h(c, r + 1) * (1.0 - fu) + _h(c + 1, r + 1) * fu
	return a * (1.0 - fv) + b * fv


## Pente locale (0 = plat, 1 = vertical environ).
func pente(x: float, z: float) -> float:
	var d := 6.0
	var gx := absf(hauteur(x + d, z) - hauteur(x - d, z))
	var gz := absf(hauteur(x, z + d) - hauteur(x, z - d))
	return maxf(gx, gz) / (2.0 * d)


func _construire_maillage() -> void:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var tang := PackedFloat32Array()
	tang.resize(N * N * 4)
	verts.resize(N * N)
	norms.resize(N * N)
	uvs.resize(N * N)
	var demi := TAILLE * 0.5
	for r in N:
		for c in N:
			var i := r * N + c
			verts[i] = Vector3(c * pas - demi, hauteurs[i], r * pas - demi)
			norms[i] = Vector3(_h(c - 1, r) - _h(c + 1, r), 2.0 * pas, _h(c, r - 1) - _h(c, r + 1)).normalized()
			uvs[i] = Vector2(float(c) / (N - 1), float(r) / (N - 1))
			var t := (Vector3.RIGHT - norms[i] * norms[i].x).normalized()
			tang[i * 4] = t.x; tang[i * 4 + 1] = t.y; tang[i * 4 + 2] = t.z; tang[i * 4 + 3] = -1.0
	var idx := PackedInt32Array()
	idx.resize((N - 1) * (N - 1) * 6)
	var k := 0
	for r in N - 1:
		for c in N - 1:
			var i := r * N + c
			idx[k] = i; idx[k + 1] = i + 1; idx[k + 2] = i + N
			idx[k + 3] = i + 1; idx[k + 4] = i + N + 1; idx[k + 5] = i + N
			k += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TANGENT] = tang
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/terrain.gdshader")
	mat.set_shader_parameter("satellite", load("res://data/talanke_satellite.jpg"))
	for m in ["sable", "laterite", "herbe", "foret", "roche"]:
		mat.set_shader_parameter(m + "_c", load("res://data/textures/%s_diff.jpg" % m))
		mat.set_shader_parameter(m + "_n", load("res://data/textures/%s_nor.jpg" % m))
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.name = "Sol"
	mi.mesh = mesh
	add_child(mi)


func _construire_collision() -> void:
	var forme := HeightMapShape3D.new()
	forme.map_width = N
	forme.map_depth = N
	forme.map_data = hauteurs
	var corps := StaticBody3D.new()
	corps.name = "CollisionSol"
	var cs := CollisionShape3D.new()
	cs.shape = forme
	cs.scale = Vector3(pas, 1.0, pas)
	corps.add_child(cs)
	add_child(corps)


func materiau() -> ShaderMaterial:
	return (get_node("Sol") as MeshInstance3D).mesh.surface_get_material(0)

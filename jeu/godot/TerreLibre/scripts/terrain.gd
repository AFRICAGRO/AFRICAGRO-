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
## Zones adoucies (villes) : {"centre": Vector2, "rayon", "passes"} — lisse les bosses du relief
## pour que rues et maisons suivent un sol régulier.
var lissages: Array = []
## Terrasses (villages de colline) : {"centre": Vector2, "rayon", "h"} — sol mis à plat à la hauteur h,
## raccordé en pente douce sur 14 m autour.
var plateformes: Array = []
## Lits de rivière creusés dans le relief : {"pts": PackedVector2Array, "niveaux": PackedFloat32Array, "largeur": float}
var lits: Array = []
## Remparts de cratère : un anneau de relief ajouté au terrain (lac du mont Talanké).
## {centre: Vector2, rayon: m, hauteur: m, largeur: m}
var anneaux: Array = []
var pas := TAILLE / float(N - 1)


func _ready() -> void:
	var f := FileAccess.open(FICHIER, FileAccess.READ)
	if f == null:
		push_error("Relief introuvable : " + FICHIER)
		return
	hauteurs = f.get_buffer(N * N * 4).to_float32_array()
	_aplanir()
	_lisser()
	_anneaux()
	_plateformes()
	_lits()
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


func _lisser() -> void:
	var demi := TAILLE * 0.5
	for z in lissages:
		var c: Vector2 = z["centre"]
		var rayon: float = z["rayon"]
		var c0 := maxi(1, int((c.x - rayon + demi) / pas)); var c1 := mini(N - 2, int((c.x + rayon + demi) / pas) + 1)
		var r0 := maxi(1, int((c.y - rayon + demi) / pas)); var r1 := mini(N - 2, int((c.y + rayon + demi) / pas) + 1)
		for passe in int(z["passes"]):
			var nouv := hauteurs.duplicate()
			for r in range(r0, r1 + 1):
				for col in range(c0, c1 + 1):
					var p := Vector2(col * pas - demi, r * pas - demi)
					var w := 1.0 - smoothstep(rayon * 0.7, rayon, p.distance_to(c))
					if w <= 0.0:
						continue
					var i := r * N + col
					if hauteurs[i] < 0.5:
						continue # on ne touche pas au trait de côte
					var m := 0.0
					for dr in [-1, 0, 1]:
						for dc in [-1, 0, 1]:
							m += hauteurs[i + dr * N + dc] * (4.0 if dr == 0 and dc == 0 else (2.0 if dr == 0 or dc == 0 else 1.0))
					nouv[i] = lerpf(hauteurs[i], maxf(m / 16.0, 0.8), w)
			hauteurs = nouv


func _anneaux() -> void:
	var demi := TAILLE * 0.5
	for an in anneaux:
		var c: Vector2 = an["centre"]
		var r: float = an["rayon"]
		var hm: float = an["hauteur"]
		var l: float = an["largeur"]
		var ext := r + l * 2.5
		var c0 := maxi(0, int((c.x - ext + demi) / pas)); var c1 := mini(N - 1, int((c.x + ext + demi) / pas) + 1)
		var r0 := maxi(0, int((c.y - ext + demi) / pas)); var r1 := mini(N - 1, int((c.y + ext + demi) / pas) + 1)
		for row in range(r0, r1 + 1):
			for col in range(c0, c1 + 1):
				var d := Vector2(col * pas - demi, row * pas - demi).distance_to(c)
				var k := (d - r) / l
				# rempart dissymétrique : flanc intérieur raide, flanc extérieur plus doux
				if k > 0.0:
					k *= 0.6
				hauteurs[row * N + col] += hm * exp(-k * k)


func _plateformes() -> void:
	var demi := TAILLE * 0.5
	var raccord := 14.0
	for pf in plateformes:
		var c: Vector2 = pf["centre"]
		var rayon: float = pf["rayon"]
		var cible: float = pf["h"]
		var c0 := maxi(0, int((c.x - rayon - raccord + demi) / pas)); var c1 := mini(N - 1, int((c.x + rayon + raccord + demi) / pas) + 1)
		var r0 := maxi(0, int((c.y - rayon - raccord + demi) / pas)); var r1 := mini(N - 1, int((c.y + rayon + raccord + demi) / pas) + 1)
		for r in range(r0, r1 + 1):
			for col in range(c0, c1 + 1):
				var d := Vector2(col * pas - demi, r * pas - demi).distance_to(c)
				var w := 1.0 - smoothstep(rayon, rayon + raccord, d)
				if w > 0.0:
					hauteurs[r * N + col] = lerpf(hauteurs[r * N + col], cible, w)


func _lits() -> void:
	var demi := TAILLE * 0.5
	for lit in lits:
		var pts: PackedVector2Array = lit["pts"]
		var niv: PackedFloat32Array = lit["niveaux"]
		var l: float = lit["largeur"]
		var portee := l * 0.5 + 10.0
		var mini_ := Vector2(INF, INF)
		var maxi_ := -mini_
		for p in pts:
			mini_ = mini_.min(p)
			maxi_ = maxi_.max(p)
		var c0 := maxi(0, int((mini_.x - portee + demi) / pas)); var c1 := mini(N - 1, int((maxi_.x + portee + demi) / pas) + 1)
		var r0 := maxi(0, int((mini_.y - portee + demi) / pas)); var r1 := mini(N - 1, int((maxi_.y + portee + demi) / pas) + 1)
		for r in range(r0, r1 + 1):
			for col in range(c0, c1 + 1):
				var q := Vector2(col * pas - demi, r * pas - demi)
				var meilleur := INF
				var niveau := 0.0
				for i in pts.size() - 1:
					var ab := pts[i + 1] - pts[i]
					var t := clampf((q - pts[i]).dot(ab) / ab.length_squared(), 0.0, 1.0)
					var dd := q.distance_to(pts[i] + ab * t)
					if dd < meilleur:
						meilleur = dd
						niveau = lerpf(niv[i], niv[i + 1], t)
				if meilleur > portee:
					continue
				var ancien := hauteurs[r * N + col]
				var cible := lerpf(niveau - 1.6, ancien, smoothstep(l * 0.3, portee, meilleur))
				hauteurs[r * N + col] = minf(ancien, cible)


## Hauteur brute lue directement dans le fichier (avant tout aplanissement), pour préparer un plan
## de village avant la construction du terrain.
static func hauteur_brute(donnees: PackedFloat32Array, x: float, z: float) -> float:
	var pas_ := TAILLE / (N - 1)
	var u := clampf((x + TAILLE * 0.5) / pas_, 0.0, N - 1.001)
	var v := clampf((z + TAILLE * 0.5) / pas_, 0.0, N - 1.001)
	var c := int(u)
	var r := int(v)
	var fu := u - c
	var fv := v - r
	var a := donnees[r * N + c] * (1.0 - fu) + donnees[r * N + c + 1] * fu
	var b := donnees[(r + 1) * N + c] * (1.0 - fu) + donnees[(r + 1) * N + c + 1] * fu
	return a * (1.0 - fv) + b * fv


static func lire_donnees() -> PackedFloat32Array:
	var f := FileAccess.open(FICHIER, FileAccess.READ)
	var d := f.get_buffer(f.get_length()).to_float32_array()
	return d


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
	# même découpage en triangles que le maillage affiché (diagonale de (c+1, r) à (c, r+1))
	if fu + fv <= 1.0:
		return _h(c, r) + fu * (_h(c + 1, r) - _h(c, r)) + fv * (_h(c, r + 1) - _h(c, r))
	return _h(c + 1, r + 1) + (1.0 - fu) * (_h(c, r + 1) - _h(c + 1, r + 1)) + (1.0 - fv) * (_h(c + 1, r) - _h(c + 1, r + 1))


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

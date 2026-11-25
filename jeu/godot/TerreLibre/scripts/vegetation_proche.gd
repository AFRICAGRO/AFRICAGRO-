## Végétation détaillée autour du joueur (rayon ~70 m) :
## - arbres en 3D (tronc, branches, écorce, rameaux feuillus) qui remplacent les arbres « imposteurs » ;
## - touffes d'herbe (verte en forêt et en hauteur, sèche près des côtes), buissons, cailloux.
## La zone autour du joueur est découpée en cases de 32 m, créées et détruites quand il se déplace :
## la carte graphique ne dessine jamais plus que les environs immédiats.
## Textures : feuilles et écorce de « island_tree_01 » (Poly Haven, CC0), herbes dessinées par programme.
class_name VegetationProche
extends Node3D

const CASE := 32.0
const RAYON_CASES := 3          # cases chargées autour du joueur (7 × 7)
const RAYON_ARBRES := 70.0      # distance de bascule arbre 3D / imposteur
const VARIANTES := 2

var terrain: Terrain
var joueur: Node3D
var zones_vides: Array = []
var arbres_par_case := {}       # Vector2i -> [[espèce, Transform3D, Color]]
var cases := {}                 # Vector2i -> Node3D chargé
var case_joueur := Vector2i(999999, 999999)
var modeles := {}               # espèce -> [ArrayMesh, …]
var m_herbes: Array = []        # [verte, sèche]
var m_buissons: Array = []
var m_cailloux: Array = []
var m_litiere: Array = []       # deux plaques de feuilles mortes
var mat_feuilles := {}
var mat_ecorce: ShaderMaterial
var file_attente: Array = []    # cases à construire (une ou deux par image, pour éviter les saccades)


func preparer(t: Terrain, p_joueur: Node3D, p_zones: Array) -> void:
	terrain = t
	joueur = p_joueur
	zones_vides = p_zones
	mat_ecorce = ShaderMaterial.new()
	mat_ecorce.shader = load("res://shaders/ecorce.gdshader")
	mat_ecorce.set_shader_parameter("image", load("res://data/vegetation/ecorce_diff.jpg"))
	mat_ecorce.set_shader_parameter("relief", load("res://data/vegetation/ecorce_nor.jpg"))
	mat_ecorce.set_shader_parameter("rayon_proche", RAYON_ARBRES)
	for nom in ["rameau_clair", "rameau_sombre"]:
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/feuillage.gdshader")
		m.set_shader_parameter("image", load("res://data/vegetation/%s.png" % nom))
		m.set_shader_parameter("rayon_proche", RAYON_ARBRES)
		mat_feuilles[nom] = m
	var rng := RandomNumberGenerator.new()
	rng.seed = 90
	# arbres : mêmes proportions que les arbres photographiés des imposteurs
	modeles["island_tree_01"] = []
	modeles["island_tree_02"] = []
	modeles["jacaranda_tree"] = []
	for v in VARIANTES:
		modeles["island_tree_01"].append(_arbre(rng, {"h": 5.0, "l": 4.8, "fourche": 0.38, "branches": 5, "penche": 0.35, "couronne": 0.62, "aplati": 0.85, "rameaux": 330, "taille_rameau": 0.55, "feuille": "rameau_clair", "troncs": 1, "r_tronc": 0.2}))
		modeles["island_tree_02"].append(_arbre(rng, {"h": 3.39, "l": 4.3, "fourche": 0.3, "branches": 4, "penche": 0.15, "couronne": 0.72, "aplati": 0.55, "rameaux": 260, "taille_rameau": 0.42, "feuille": "rameau_clair", "troncs": 2, "r_tronc": 0.15}))
		modeles["jacaranda_tree"].append(_arbre(rng, {"h": 19.3, "l": 21.0, "fourche": 0.3, "branches": 6, "penche": 0.05, "couronne": 0.68, "aplati": 0.5, "rameaux": 420, "taille_rameau": 2.0, "feuille": "rameau_sombre", "troncs": 1, "r_tronc": 0.55}))
	m_herbes = [_touffe(0.0), _touffe(0.5)]
	var ml := StandardMaterial3D.new()
	ml.albedo_texture = load("res://data/vegetation/litiere.png")
	ml.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	ml.alpha_scissor_threshold = 0.5
	ml.roughness = 0.95
	ml.vertex_color_use_as_albedo = true
	for v in 2:
		var pm := PlaneMesh.new()
		pm.size = Vector2(2.6, 2.6)
		var st := SurfaceTool.new()
		st.create_from(pm, 0)
		var arr := st.commit_to_arrays()
		var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
		for i in uv.size():
			uv[i] = Vector2(uv[i].x * 0.5 + v * 0.5, uv[i].y)
		arr[Mesh.ARRAY_TEX_UV] = uv
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		m.surface_set_material(0, ml)
		m_litiere.append(m)
	for v in 3:
		m_buissons.append(_buisson(rng))
		m_cailloux.append(_caillou(rng))


func ajouter_arbre(espece: String, xf: Transform3D, teinte: Color) -> void:
	var cle := Vector2i(floori(xf.origin.x / CASE), floori(xf.origin.z / CASE))
	if not arbres_par_case.has(cle):
		arbres_par_case[cle] = []
	arbres_par_case[cle].append([espece, xf, teinte])


# =====================================================================
# Fabrication des arbres
# =====================================================================
func _cylindre_le_long(st: SurfaceTool, pts: Array, rayons: Array, cotes: int, poids0: float, poids1: float) -> void:
	# tube qui suit une ligne brisée (tronc ou branche), coordonnées de texture pour l'écorce
	var v_long := 0.0
	var anneaux: Array = []
	for i in pts.size():
		var t: Vector3
		if i == 0:
			t = (pts[1] - pts[0]).normalized()
		elif i == pts.size() - 1:
			t = (pts[i] - pts[i - 1]).normalized()
		else:
			t = (pts[i + 1] - pts[i - 1]).normalized()
		var a := t.cross(Vector3.FORWARD if absf(t.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		var b := t.cross(a).normalized()
		if i > 0:
			v_long += (pts[i] - pts[i - 1]).length()
		var anneau: Array = []
		for k in cotes + 1:
			var ang := TAU * k / cotes
			var n := (a * cos(ang) + b * sin(ang))
			anneau.append([pts[i] + n * rayons[i], n, Vector2(float(k) / cotes * 2.0, v_long / maxf(0.5, rayons[0] * 6.0))])
		anneaux.append(anneau)
	for i in pts.size() - 1:
		var p0 := lerpf(poids0, poids1, float(i) / (pts.size() - 1))
		var p1 := lerpf(poids0, poids1, float(i + 1) / (pts.size() - 1))
		for k in cotes:
			var q := [anneaux[i][k], anneaux[i][k + 1], anneaux[i + 1][k + 1], anneaux[i + 1][k]]
			var w := [p0, p0, p1, p1]
			for j in [0, 2, 1, 0, 3, 2]:
				st.set_color(Color(1, 1, 1, w[j] * 0.35))
				st.set_normal(q[j][1])
				st.set_uv(q[j][2])
				st.add_vertex(q[j][0])


func _courbe(depart: Vector3, fin: Vector3, courbure: Vector3, n: int) -> Array:
	var pts: Array = []
	for i in n + 1:
		var t := float(i) / n
		pts.append(depart.lerp(fin, t) + courbure * sin(t * PI))
	return pts


func _arbre(rng: RandomNumberGenerator, p: Dictionary) -> ArrayMesh:
	var H: float = p["h"]
	var L: float = p["l"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sf := SurfaceTool.new()
	sf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var centre := Vector3(0, H * (1.0 - p["couronne"] * 0.5), 0)
	var ry: float = H * p["couronne"] * 0.5 * p["aplati"] + H * 0.08
	var rx := L * 0.5
	var bouts: Array = []
	var r0: float = H * 0.045 * (p["r_tronc"] / 0.2) if H < 10.0 else p["r_tronc"]
	for tr in p["troncs"]:
		# tronc (un peu penché et tordu), puis branches maîtresses vers la couronne
		var ang0 := rng.randf() * TAU
		var penche: Vector3 = Vector3(cos(ang0), 0, sin(ang0)) * H * p["penche"] * rng.randf_range(0.5, 1.0)
		if p["troncs"] > 1:
			penche = Vector3(cos(ang0 + tr * PI), 0, sin(ang0 + tr * PI)) * H * 0.18
		var hf: float = H * p["fourche"] * rng.randf_range(0.85, 1.15)
		var haut_tronc := Vector3(penche.x, hf, penche.z)
		var tronc := _courbe(Vector3.ZERO, haut_tronc, Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)) * H * 0.04, 6)
		var rt: float = r0 / sqrt(float(p["troncs"]))
		var rayons: Array = []
		for i in tronc.size():
			var t := float(i) / (tronc.size() - 1)
			rayons.append(rt * (1.0 - 0.35 * t) * (1.0 + 0.6 * maxf(0.0, 0.2 - t) * 5.0)) # empattement au pied
		_cylindre_le_long(st, tronc, rayons, 9, 0.0, 0.1)
		for b in p["branches"]:
			var az: float = TAU * b / p["branches"] + rng.randf_range(-0.4, 0.4) + tr
			var dir := Vector3(cos(az), 0, sin(az))
			var fin := centre + dir * rx * rng.randf_range(0.45, 0.8) + Vector3(0, ry * rng.randf_range(-0.2, 0.55), 0)
			var br := _courbe(haut_tronc, fin, Vector3(0, H * 0.05, 0), 5)
			var rb: Array = []
			for i in br.size():
				rb.append(rt * 0.62 * (1.0 - 0.75 * float(i) / (br.size() - 1)))
			_cylindre_le_long(st, br, rb, 6, 0.1, 0.6)
			bouts.append(fin)
			# rameaux secondaires
			for s in 3:
				var t := rng.randf_range(0.45, 0.85)
				var o: Vector3 = br[int(t * (br.size() - 1))]
				var d2 := (dir + Vector3(rng.randf_range(-0.8, 0.8), rng.randf_range(0.0, 0.7), rng.randf_range(-0.8, 0.8))).normalized()
				var f2 := o + d2 * rx * rng.randf_range(0.25, 0.45)
				var b2 := _courbe(o, f2, Vector3(0, H * 0.02, 0), 3)
				_cylindre_le_long(st, b2, [rt * 0.22, rt * 0.15, rt * 0.09, rt * 0.04], 4, 0.4, 0.8)
				bouts.append(f2)
	# rameaux feuillus : surtout dans la coque de la couronne et autour des bouts de branches
	var taille: float = p["taille_rameau"]
	for i in p["rameaux"]:
		var pos: Vector3
		if i % 3 == 0 and bouts.size() > 0:
			pos = bouts[rng.randi() % bouts.size()] + Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.5, 1), rng.randf_range(-1, 1)) * rx * 0.25
		else:
			var u := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
			var r := pow(rng.randf_range(0.35, 1.0), 0.5)
			pos = centre + Vector3(u.x * rx, u.y * ry, u.z * rx) * r
		_rameau(sf, rng, pos, centre, taille * rng.randf_range(0.8, 1.25))
	st.generate_tangents()
	var mesh := st.commit()
	mesh.surface_set_material(0, mat_ecorce)
	sf.commit(mesh)
	mesh.surface_set_material(1, mat_feuilles[p["feuille"]])
	return mesh


## Une carte de rameau (deux faces) orientée vers l'extérieur de la couronne.
func _rameau(sf: SurfaceTool, rng: RandomNumberGenerator, pos: Vector3, centre: Vector3, taille: float) -> void:
	var dehors := (pos - centre).normalized()
	if dehors.length() < 0.1:
		dehors = Vector3.UP
	var axe := (dehors + Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.2, 0.5), rng.randf_range(-0.6, 0.6))).normalized()
	var cote := axe.cross(Vector3.UP if absf(axe.y) < 0.95 else Vector3.RIGHT).normalized().rotated(axe, rng.randf_range(-0.8, 0.8))
	var l := taille * 2.0
	var w := taille * 0.95
	var base := pos - axe * l * 0.35
	var v := rng.randi() % 2
	var u0 := v * 0.5 + 0.13
	var u1 := v * 0.5 + 0.37
	var coins := [base - cote * w * 0.5, base + cote * w * 0.5, base + cote * w * 0.5 + axe * l, base - cote * w * 0.5 + axe * l]
	var uvs := [Vector2(u0, 1.0), Vector2(u1, 1.0), Vector2(u1, 0.0), Vector2(u0, 0.0)]
	var teinte := Color(rng.randf_range(0.85, 1.05), rng.randf_range(0.88, 1.05), rng.randf_range(0.85, 1.0), 1.0)
	for k in [0, 1, 2, 0, 2, 3]:
		var q: Vector3 = coins[k]
		# normale « sphérique » : la couronne s'éclaire comme un volume arrondi
		var n := ((q - centre).normalized() * 0.8 + Vector3.UP * 0.3).normalized()
		sf.set_normal(n)
		var bout := 1.0 if k >= 2 else 0.6
		sf.set_color(Color(teinte.r, teinte.g, teinte.b, bout))
		sf.set_uv(uvs[k])
		sf.add_vertex(q)


func _buisson(rng: RandomNumberGenerator) -> ArrayMesh:
	var sf := SurfaceTool.new()
	sf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := rng.randf_range(0.7, 1.2)
	var centre := Vector3(0, r * 0.55, 0)
	for i in 42:
		var u := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.3, 1), rng.randf_range(-1, 1)).normalized()
		_rameau(sf, rng, centre + Vector3(u.x * r, u.y * r * 0.7, u.z * r) * rng.randf_range(0.3, 1.0), centre - Vector3(0, 0.4, 0), rng.randf_range(0.3, 0.42))
	var mesh := sf.commit()
	mesh.surface_set_material(0, mat_feuilles["rameau_clair"])
	return mesh


func _touffe(u0: float) -> ArrayMesh:
	# petite touffe : trois cartes étroites, tournées et décalées au hasard (silhouette irrégulière)
	# texture : herbe verte à gauche (u0 = 0), sèche à droite (u0 = 0,5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31 + int(u0 * 10)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 4:
		var a := k * PI / 4.0 + rng.randf_range(-0.3, 0.3)
		var l := rng.randf_range(0.22, 0.34)
		var h := rng.randf_range(0.45, 0.8)
		var o := Vector3(rng.randf_range(-0.12, 0.12), 0, rng.randf_range(-0.12, 0.12))
		var d := Vector3(cos(a), 0, sin(a)) * l
		var coins := [o - d, o + d, o + d + Vector3(0, h, 0), o - d + Vector3(0, h, 0)]
		var uvs := [Vector2(u0 + 0.06, 1), Vector2(u0 + 0.44, 1), Vector2(u0 + 0.44, 0), Vector2(u0 + 0.06, 0)]
		for j in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP)
			st.set_color(Color.WHITE)
			st.set_uv(uvs[j])
			st.add_vertex(coins[j])
	var mesh := st.commit()
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/herbe.gdshader")
	m.set_shader_parameter("image", load("res://data/vegetation/herbes.png"))
	mesh.surface_set_material(0, m)
	return mesh


func _caillou(rng: RandomNumberGenerator) -> ArrayMesh:
	var sm := SphereMesh.new()
	sm.radial_segments = 9
	sm.rings = 5
	sm.radius = 0.5
	sm.height = 1.0
	var arr := sm.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var bruit := FastNoiseLite.new()
	bruit.seed = rng.randi()
	bruit.frequency = 1.6
	for i in verts.size():
		var v := verts[i]
		var k := 1.0 + bruit.get_noise_3dv(v) * 0.45
		verts[i] = Vector3(v.x * k * 1.2, maxf(v.y * k * 0.65, -0.15), v.z * k)
	arr[Mesh.ARRAY_VERTEX] = verts
	var st := SurfaceTool.new()
	st.create_from_arrays(arr)
	st.generate_normals()
	var mesh := st.commit()
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://data/textures/roche_diff.jpg")
	m.normal_enabled = true
	m.normal_texture = load("res://data/textures/roche_nor.jpg")
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * 0.8
	m.albedo_color = Color(0.85, 0.8, 0.75)
	m.roughness = 0.95
	mesh.surface_set_material(0, m)
	return mesh


# =====================================================================
# Cases autour du joueur
# =====================================================================
func _process(_delta: float) -> void:
	if joueur == null:
		return
	var p := joueur.global_position
	var c := Vector2i(floori(p.x / CASE), floori(p.z / CASE))
	if c != case_joueur:
		case_joueur = c
		var voulues := {}
		for dx in range(-RAYON_CASES, RAYON_CASES + 1):
			for dz in range(-RAYON_CASES, RAYON_CASES + 1):
				voulues[c + Vector2i(dx, dz)] = true
		for k in cases.keys():
			if not voulues.has(k):
				(cases[k] as Node).queue_free()
				cases.erase(k)
		file_attente.clear()
		for k in voulues:
			if not cases.has(k):
				file_attente.append(k)
		# les plus proches d'abord
		file_attente.sort_custom(func(a, b): return (a - c).length_squared() < (b - c).length_squared())
	for i in 2:
		if file_attente.is_empty():
			break
		var k: Vector2i = file_attente.pop_front()
		if not cases.has(k):
			cases[k] = _construire_case(k)


func _vide(x: float, z: float) -> bool:
	for zv in zones_vides:
		if Vector2(x - zv.x, z - zv.y).length() < zv.z:
			return true
	return false


func _construire_case(k: Vector2i) -> Node3D:
	var n := Node3D.new()
	n.name = "Case_%d_%d" % [k.x, k.y]
	n.position = Vector3((k.x + 0.5) * CASE, 0, (k.y + 0.5) * CASE)
	add_child(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(k)
	var origine := n.position
	# arbres 3D (mêmes positions que les imposteurs)
	if arbres_par_case.has(k):
		var par_modele := {}
		for e in arbres_par_case[k]:
			var esp: String = e[0]
			var mi := rng.randi() % VARIANTES
			var cle := "%s|%d" % [esp, mi]
			if not par_modele.has(cle):
				par_modele[cle] = []
			par_modele[cle].append(e)
		for cle in par_modele:
			var morceaux: PackedStringArray = (cle as String).split("|")
			var liste: Array = par_modele[cle]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = modeles[morceaux[0]][int(morceaux[1])]
			mm.instance_count = liste.size()
			for i in liste.size():
				mm.set_instance_transform(i, (liste[i][1] as Transform3D).translated(-origine))
				mm.set_instance_color(i, liste[i][2])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			n.add_child(mmi)
	# feuilles mortes au pied des arbres, couchées selon la pente
	if arbres_par_case.has(k):
		var plaques: Array = [[], []]
		for e in arbres_par_case[k]:
			var o: Vector3 = (e[1] as Transform3D).origin
			for j in 3:
				var a := rng.randf() * TAU
				var d := rng.randf_range(0.5, 3.5)
				var x := o.x + cos(a) * d
				var z := o.z + sin(a) * d
				var h := terrain.hauteur(x, z)
				if h < 2.2:
					continue
				var nx := terrain.hauteur(x - 0.5, z) - terrain.hauteur(x + 0.5, z)
				var nz := terrain.hauteur(x, z - 0.5) - terrain.hauteur(x, z + 0.5)
				var up := Vector3(nx, 1.0, nz).normalized()
				var b := Basis(Quaternion(Vector3.UP, up)) * Basis(Vector3.UP, rng.randf() * TAU)
				var s := rng.randf_range(0.8, 1.4)
				plaques[j % 2].append(Transform3D(b.scaled(Vector3(s, 1, s)), Vector3(x, h + 0.03, z) - origine))
		for j in 2:
			if plaques[j].is_empty():
				continue
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = m_litiere[j]
			mm.instance_count = plaques[j].size()
			for i in plaques[j].size():
				mm.set_instance_transform(i, plaques[j][i])
				var t := rng.randf_range(0.75, 1.0)
				mm.set_instance_color(i, Color(t, t, t))
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			n.add_child(mmi)
	# herbes, buissons, cailloux (tirés au hasard, mais toujours les mêmes pour une case donnée)
	var herbes: Array = []
	var buissons: Array = []
	var cailloux: Array = []
	for i in 300:
		var x := origine.x + rng.randf_range(-CASE * 0.5, CASE * 0.5)
		var z := origine.z + rng.randf_range(-CASE * 0.5, CASE * 0.5)
		var h := terrain.hauteur(x, z)
		var pe := terrain.pente(x, z)
		if h < 2.2 or _vide(x, z):
			continue
		var tirage := rng.randf()
		if tirage < 0.8:
			if pe > 0.75:
				continue
			# herbe sèche sur la plaine côtière, verte en altitude et en forêt
			var sec := 1.0 - smoothstep(6.0, 22.0, h) + rng.randf_range(-0.25, 0.25)
			for b in rng.randi_range(2, 5):
				var xb := x + rng.randf_range(-0.7, 0.7)
				var zb := z + rng.randf_range(-0.7, 0.7)
				var s := rng.randf_range(0.7, 1.3)
				var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.7, 1.4), s)), Vector3(xb, terrain.hauteur(xb, zb) - 0.04, zb) - origine)
				herbes.append([xf, sec > 0.5])
		elif tirage < 0.93:
			if pe > 0.9 or h < 3.0:
				continue
			var s := rng.randf_range(0.7, 1.5)
			buissons.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.2), s)), Vector3(x, h - 0.15, z) - origine))
		elif pe > 0.25 or rng.randf() < 0.3:
			var s := rng.randf_range(0.25, 1.1) * (1.0 + pe)
			cailloux.append(Transform3D(Basis(Vector3(rng.randf(), rng.randf(), rng.randf()).normalized(), rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(x, h - 0.12 * s, z) - origine))
	for sorte in 2:
		var liste: Array = herbes.filter(func(e): return e[1] == (sorte == 1))
		if liste.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = m_herbes[sorte]
		mm.instance_count = liste.size()
		for i in liste.size():
			mm.set_instance_color(i, Color(rng.randf_range(0.8, 1.1), rng.randf_range(0.85, 1.1), rng.randf_range(0.8, 1.0)))
			mm.set_instance_transform(i, liste[i][0])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(mmi)
	for liste_modeles in [[buissons, m_buissons], [cailloux, m_cailloux]]:
		var liste: Array = liste_modeles[0]
		if liste.is_empty():
			continue
		var par := {}
		for xf in liste:
			var j := rng.randi() % 3
			if not par.has(j):
				par[j] = []
			par[j].append(xf)
		for j in par:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = liste_modeles[1][j]
			mm.instance_count = par[j].size()
			for i in par[j].size():
				mm.set_instance_transform(i, par[j][i])
				mm.set_instance_color(i, Color(rng.randf_range(0.8, 1.05), rng.randf_range(0.85, 1.05), rng.randf_range(0.75, 1.0)))
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			n.add_child(mmi)
	return n

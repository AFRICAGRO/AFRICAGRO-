## Village d'Akwéri (mission 4 « Première Étincelle »), version réaliste.
## Disposition reprise de jeu/prototype/blockout_akweri.py : repère local en mètres,
## « avant » = vers la mer, « côté » = le long de la plage.
## Matières : textures photographiées Poly Haven (CC0) ; drapeau du Cobra créé pour le jeu.
class_name VillageAkweri
extends Node3D

var terrain: Terrain
var centre := Vector2.ZERO
var mer := Vector2(-1, 0)     # direction de la mer
var plage := Vector2(0, 1)    # direction le long de la plage
var rng := RandomNumberGenerator.new()
var mats := {}

## Points utiles pour la mission (remplis à la construction) : départ, vagues, civils, refuges
var reperes := {}
## Obstacles derrière lesquels se mettre à couvert : [position, rayon]
var couverts: Array = []
var drapeau_mat: ShaderMaterial


func construire(t: Terrain, p_centre: Vector2, p_mer: Vector2, vegetation: Vegetation) -> void:
	terrain = t
	centre = p_centre
	mer = p_mer.normalized()
	plage = Vector2(-mer.y, mer.x)
	rng.seed = 404
	_materiaux()
	# Cases : deux rangées avec ruelles (comme le blockout)
	for rangee in 2:
		var avant := -25.0 if rangee == 0 else -45.0
		for k in range(-3, 4):
			var a := avant + (k % 2) * 4.0
			var c := k * 12.0 + rng.randf_range(-1.5, 1.5)
			if rangee == 1 and (k == -3 or k == 3):
				_maison_planches(a, c)
			else:
				_case(a, c, rng.randf_range(2.3, 2.8))
	# Fumoirs (couverts bas) avec fumée
	for k in range(-2, 3):
		_fumoir(-8.0, k * 14.0 + 5.0)
	# Pirogues tirées sur le sable, perpendiculaires à la plage
	var couleurs := [Color(1.0, 0.22, 0.12), Color(1.0, 0.82, 0.2), Color(0.25, 0.5, 1.0), Color(0.2, 0.8, 0.4)]
	for k in range(-4, 5):
		_pirogue(8.0 + (k % 3) * 2.0, k * 9.0, couleurs[(k + 4) % 4], couleurs[(k + 6) % 4])
	# Mât et drapeau du Cobra (remplacé par les Racines à la libération)
	_mat_drapeau(4.0, 0.0)
	# Couverts de la place : caisses et fûts
	for p in [Vector2(-15, -6), Vector2(-15, 6), Vector2(-35, 0)]:
		_couvert(p.x, p.y)
	# Séchoirs à filets
	for c in [-30.0, 22.0]:
		_sechoir_filets(-2.0, c)
	# Cocotiers dans et autour du village
	if vegetation:
		var mesh: ArrayMesh = vegetation._maillage_palmier(rng, 14)
		for p in [Vector2(2, -38), Vector2(-3, 30), Vector2(-18, -36), Vector2(-20, 40), Vector2(-36, -20),
				Vector2(-52, 10), Vector2(-60, -30), Vector2(5, 42), Vector2(-10, 18), Vector2(-30, 44)]:
			var w := _monde(p.x, p.y)
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			var s := rng.randf_range(0.85, 1.15)
			mi.transform = Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(w.x, _sol(w) - 0.3, w.y))
			add_child(mi)
	# Repères de jeu (mêmes valeurs que le blockout)
	reperes["depart"] = [_monde3(-90, -40)]
	reperes["vague1"] = [_monde3(10, -10), _monde3(12, 5), _monde3(6, 15), _monde3(2, -20)]
	reperes["vague2"] = [_monde3(-60, 15), _monde3(-58, 25), _monde3(-62, 30), _monde3(-55, 20)]
	reperes["vague3"] = [_monde3(14, -30), _monde3(16, -25), _monde3(12, -35)]
	reperes["refuges"] = [_monde3(-40, -40), _monde3(-50, 35), _monde3(-70, 0)]
	var civils := []
	for k in 12:
		civils.append(_monde3(5 + (k % 3) * 2, -2 + (k / 3) * 2))
	reperes["civils"] = civils


# ---------- repère local ----------
func _monde(avant: float, cote: float) -> Vector2:
	return centre + mer * avant + plage * cote


func _sol(w: Vector2) -> float:
	return terrain.hauteur(w.x, w.y)


func _monde3(avant: float, cote: float) -> Vector3:
	var w := _monde(avant, cote)
	return Vector3(w.x, _sol(w), w.y)


## Orientation : l'axe +Z local regarde vers la mer.
func _base(avant: float, cote: float, tourne := 0.0) -> Transform3D:
	var w := _monde(avant, cote)
	var angle := atan2(mer.x, mer.y) + tourne
	return Transform3D(Basis(Vector3.UP, angle), Vector3(w.x, _sol(w), w.y))


# ---------- matériaux ----------
func _materiau(nom: String, taille_m: float, teinte := Color.WHITE, rugosite := 0.9, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://data/textures/%s_diff.jpg" % nom)
	m.normal_enabled = true
	m.normal_texture = load("res://data/textures/%s_nor.jpg" % nom)
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / taille_m
	m.albedo_color = teinte
	m.roughness = rugosite
	m.metallic = metal
	return m


func _materiaux() -> void:
	mats["banco"] = _materiau("clay_plaster", 2.5, Color(0.92, 0.78, 0.66))
	mats["banco_bas"] = _materiau("red_mud_stones", 1.5, Color(0.8, 0.62, 0.5))
	mats["chaume"] = _materiau("thatch_roof_angled", 1.6, Color(0.95, 0.88, 0.78))
	mats["planches"] = _materiau("weathered_plank_siding", 2.0)
	mats["tole"] = _materiau("rusty_corrugated_iron", 2.0, Color.WHITE, 0.6, 0.3)
	mats["bois"] = _materiau("weathered_brown_planks", 1.5)
	mats["bois_peint"] = _materiau("wood_peeling_paint_weathered", 1.2)
	mats["bois_peint"].vertex_color_use_as_albedo = true
	var sombre := StandardMaterial3D.new()
	sombre.albedo_color = Color(0.06, 0.05, 0.04)
	sombre.roughness = 1.0
	mats["ombre"] = sombre
	var poisson := StandardMaterial3D.new()
	poisson.albedo_color = Color(0.32, 0.2, 0.1)
	poisson.roughness = 0.5
	mats["poisson"] = poisson
	var fut := _materiau("rusty_corrugated_iron", 1.0, Color(0.35, 0.55, 0.85), 0.5, 0.4)
	mats["fut"] = fut
	var filet := StandardMaterial3D.new()
	filet.albedo_color = Color(0.25, 0.45, 0.4, 0.8)
	filet.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	filet.cull_mode = BaseMaterial3D.CULL_DISABLED
	mats["filet"] = filet


func _piece(mesh: Mesh, mat: Material, xf: Transform3D, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = xf
	parent.add_child(mi)
	return mi


func _collision(parent: Node3D, forme: Shape3D, xf: Transform3D) -> void:
	var corps := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = forme
	cs.transform = xf
	corps.add_child(cs)
	parent.add_child(corps)


func _boite(taille: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = taille
	return b


func _cylindre(r_haut: float, r_bas: float, h: float, cotes := 16) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_haut
	c.bottom_radius = r_bas
	c.height = h
	c.radial_segments = cotes
	c.rings = 1
	return c


# ---------- bâtiments ----------
func _case(avant: float, cote: float, r: float) -> void:
	var n := Node3D.new()
	n.name = "Case"
	n.transform = _base(avant, cote, rng.randf_range(-0.6, 0.6))
	add_child(n)
	couverts.append([n.position, r])
	var h := 2.5
	_piece(_cylindre(r + 0.12, r + 0.18, 0.45, 20), mats["banco_bas"], Transform3D(Basis(), Vector3(0, 0.1, 0)), n)
	_piece(_cylindre(r, r + 0.05, h, 20), mats["banco"], Transform3D(Basis(), Vector3(0, h * 0.5 - 0.2, 0)), n)
	var toit := _cylindre(0.08, r * 1.38, 2.5, 20)
	_piece(toit, mats["chaume"], Transform3D(Basis(), Vector3(0, h + 0.95, 0)), n)
	# porte et petite fenêtre, côté mer
	_piece(_boite(Vector3(0.95, 1.85, 0.12)), mats["ombre"], Transform3D(Basis(), Vector3(0, 0.75, r - 0.02)), n)
	_piece(_boite(Vector3(1.05, 0.12, 0.2)), mats["bois"], Transform3D(Basis(), Vector3(0, 1.72, r + 0.02)), n)
	var fen := Basis(Vector3.UP, 1.1)
	_piece(_boite(Vector3(0.5, 0.45, 0.12)), mats["ombre"], Transform3D(fen, fen * Vector3(0, 1.45, r - 0.02)), n)
	var forme := CylinderShape3D.new()
	forme.radius = r
	forme.height = h + 1.0
	_collision(n, forme, Transform3D(Basis(), Vector3(0, (h + 1.0) * 0.5 - 0.2, 0)))


func _maison_planches(avant: float, cote: float) -> void:
	var n := Node3D.new()
	n.name = "MaisonPlanches"
	n.transform = _base(avant, cote, rng.randf_range(-0.15, 0.15))
	add_child(n)
	couverts.append([n.position, 3.4])
	var l := 6.0
	var p := 4.2
	var h := 2.7
	_piece(_boite(Vector3(l + 0.2, 0.5, p + 0.2)), mats["banco_bas"], Transform3D(Basis(), Vector3(0, 0.05, 0)), n)
	_piece(_boite(Vector3(l, h, p)), mats["planches"], Transform3D(Basis(), Vector3(0, h * 0.5, 0)), n)
	# toit de tôle à un versant, débordant
	var pente := Basis(Vector3(1, 0, 0), -0.16)
	_piece(_boite(Vector3(l + 1.0, 0.06, p + 1.4)), mats["tole"], Transform3D(pente, Vector3(0, h + 0.38, 0)), n)
	# pierres posées sur la tôle contre le vent
	for i in 3:
		_piece(_boite(Vector3(0.3, 0.2, 0.3)), mats["banco_bas"], Transform3D(pente, Vector3(-2 + i * 2.0, h + 0.55, 0.4 * (i - 1))), n)
	_piece(_boite(Vector3(1.0, 2.0, 0.1)), mats["ombre"], Transform3D(Basis(), Vector3(-1.2, 1.0, p * 0.5 + 0.02)), n)
	_piece(_boite(Vector3(0.9, 0.7, 0.1)), mats["ombre"], Transform3D(Basis(), Vector3(1.4, 1.55, p * 0.5 + 0.02)), n)
	_collision(n, _forme_boite(Vector3(l, h + 0.6, p)), Transform3D(Basis(), Vector3(0, (h + 0.6) * 0.5, 0)))


func _forme_boite(t: Vector3) -> BoxShape3D:
	var b := BoxShape3D.new()
	b.size = t
	return b


func _fumoir(avant: float, cote: float) -> void:
	var n := Node3D.new()
	n.name = "Fumoir"
	n.transform = _base(avant, cote, PI * 0.5)
	add_child(n)
	couverts.append([n.position, 1.7])
	_piece(_boite(Vector3(3.0, 1.0, 2.0)), mats["banco_bas"], Transform3D(Basis(), Vector3(0, 0.4, 0)), n)
	_piece(_boite(Vector3(0.6, 0.45, 0.1)), mats["ombre"], Transform3D(Basis(), Vector3(0, 0.35, 1.01)), n)
	for i in 9: # claie de bois
		_piece(_boite(Vector3(3.1, 0.05, 0.08)), mats["bois"], Transform3D(Basis(), Vector3(0, 0.93, -0.9 + i * 0.225)), n)
	var pm := CapsuleMesh.new()
	pm.radius = 0.07
	pm.height = 0.42
	pm.radial_segments = 6
	pm.rings = 2
	for i in 7:
		for j in 5:
			var b := Basis(Vector3(0, 0, 1), PI * 0.5).rotated(Vector3.UP, rng.randf_range(-0.2, 0.2))
			_piece(pm, mats["poisson"], Transform3D(b, Vector3(-1.2 + i * 0.4, 1.0, -0.7 + j * 0.35)), n)
	# poteaux et petit toit de tôle
	for sx in [-1.4, 1.4]:
		for sz in [-0.9, 0.9]:
			_piece(_boite(Vector3(0.1, 2.0, 0.1)), mats["bois"], Transform3D(Basis(), Vector3(sx, 1.0, sz)), n)
	_piece(_boite(Vector3(3.4, 0.05, 2.4)), mats["tole"], Transform3D(Basis(Vector3(1, 0, 0), 0.1), Vector3(0, 2.05, 0)), n)
	var fumee := CPUParticles3D.new()
	fumee.amount = 24
	fumee.lifetime = 5.0
	fumee.position = Vector3(0, 1.1, 0)
	fumee.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	fumee.emission_box_extents = Vector3(1.2, 0.05, 0.7)
	fumee.direction = Vector3(0.2, 1, 0)
	fumee.spread = 12.0
	fumee.gravity = Vector3(0.25, 0.5, 0)
	fumee.initial_velocity_min = 0.3
	fumee.initial_velocity_max = 0.6
	fumee.scale_amount_min = 0.8
	fumee.scale_amount_max = 1.6
	var courbe := Curve.new()
	courbe.add_point(Vector2(0, 0.4))
	courbe.add_point(Vector2(1, 2.6))
	fumee.scale_amount_curve = courbe
	var q := QuadMesh.new()
	q.size = Vector2(1.4, 1.4)
	var mf := StandardMaterial3D.new()
	mf.albedo_texture = load("res://data/textures/fumee.png")
	mf.albedo_color = Color(0.75, 0.74, 0.72, 0.28)
	mf.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mf.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mf.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mf.vertex_color_use_as_albedo = true
	q.material = mf
	fumee.mesh = q
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.0))
	grad.add_point(0.15, Color(1, 1, 1, 0.9))
	grad.set_color(grad.get_point_count() - 1, Color(1, 1, 1, 0.0))
	fumee.color_ramp = grad
	n.add_child(fumee)
	_collision(n, _forme_boite(Vector3(3.0, 1.1, 2.0)), Transform3D(Basis(), Vector3(0, 0.45, 0)))


func _pirogue(avant: float, cote: float, couleur1: Color, couleur2: Color) -> void:
	var n := Node3D.new()
	n.name = "Pirogue"
	n.transform = _base(avant, cote, rng.randf_range(-0.12, 0.12))
	add_child(n)
	couverts.append([n.position, 1.0])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sections := 16
	var pts := 10
	var grille := []
	for i in sections + 1:
		var t := float(i) / sections * 2.0 - 1.0 # -1 (arrière) à 1 (proue)
		var z := t * 4.2
		var larg := 0.72 * pow(maxf(0.0, 1.0 - t * t), 0.6) + 0.03
		var prof := 0.55 * pow(maxf(0.0, 1.0 - t * t), 0.35) + 0.05
		var releve := 0.28 * t * t * t * t
		var ligne := []
		for j in pts + 1:
			var a := PI * float(j) / pts
			ligne.append(Vector3(cos(a) * larg, 0.62 + releve - sin(a) * prof, z))
		grille.append(ligne)
	for i in sections:
		for j in pts:
			var q := [grille[i][j], grille[i + 1][j], grille[i + 1][j + 1], grille[i][j + 1]]
			for k in [0, 2, 1, 0, 3, 2]:
				var v: Vector3 = q[k]
				var bande := v.y - (0.62 + 0.28 * pow(v.z / 4.2, 4.0))
				var col := Color.WHITE
				if bande > -0.16:
					col = couleur1
				elif bande > -0.32:
					col = couleur2
				st.set_color(col)
				st.add_vertex(v)
	st.generate_normals()
	var mesh := st.commit()
	var m: StandardMaterial3D = mats["bois_peint"].duplicate()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := _piece(mesh, m, Transform3D(), n)
	# bancs et pagaie
	for z in [-1.6, 0.0, 1.6]:
		_piece(_boite(Vector3(1.2, 0.05, 0.22)), mats["bois"], Transform3D(Basis(), Vector3(0, 0.5, z)), n)
	_piece(_boite(Vector3(0.08, 0.04, 2.2)), mats["bois"], Transform3D(Basis(Vector3(0, 1, 0), 0.3), Vector3(0.2, 0.56, 0.6)), n)
	# légèrement penchée sur le sable
	n.rotate_object_local(Vector3(0, 0, 1), rng.randf_range(-0.08, 0.08))
	n.position.y -= 0.12
	_collision(n, _forme_boite(Vector3(1.3, 0.8, 8.0)), Transform3D(Basis(), Vector3(0, 0.4, 0)))


func _mat_drapeau(avant: float, cote: float) -> void:
	var n := Node3D.new()
	n.name = "MatDrapeau"
	n.transform = _base(avant, cote)
	add_child(n)
	_piece(_cylindre(0.07, 0.11, 8.0, 8), mats["bois"], Transform3D(Basis(), Vector3(0, 4.0, 0)), n)
	var drap := PlaneMesh.new()
	drap.size = Vector2(2.2, 1.4)
	drap.subdivide_width = 16
	drap.subdivide_depth = 4
	drap.orientation = PlaneMesh.FACE_Z
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode cull_disabled;
uniform sampler2D image : source_color;
void vertex() {
	float f = (VERTEX.x + 1.1) / 2.2;
	VERTEX.z += sin(TIME * 4.0 - VERTEX.x * 3.0) * 0.18 * f;
	VERTEX.y += sin(TIME * 3.0 - VERTEX.x * 2.0) * 0.05 * f;
}
void fragment() { ALBEDO = texture(image, UV).rgb; ROUGHNESS = 0.9; }"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("image", load("res://data/textures/drapeau_cobra.jpg"))
	drapeau_mat = m
	_piece(drap, m, Transform3D(Basis(), Vector3(1.15, 7.1, 0)), n)
	_collision(n, _forme_boite(Vector3(0.25, 8.0, 0.25)), Transform3D(Basis(), Vector3(0, 4.0, 0)))


func _couvert(avant: float, cote: float) -> void:
	var n := Node3D.new()
	n.name = "Couvert"
	n.transform = _base(avant, cote, rng.randf_range(0, TAU))
	add_child(n)
	couverts.append([n.position, 1.6])
	for p in [Vector3(-0.5, 0.3, 0), Vector3(0.5, 0.3, 0.1), Vector3(0, 0.9, 0.05)]:
		_piece(_boite(Vector3(0.95, 0.6, 0.7)), mats["bois"], Transform3D(Basis(Vector3.UP, rng.randf_range(-0.2, 0.2)), p), n)
	for p in [Vector3(1.3, 0.45, -0.6), Vector3(1.5, 0.45, 0.5)]:
		_piece(_cylindre(0.3, 0.3, 0.9, 14), mats["fut"], Transform3D(Basis(), p), n)
	_collision(n, _forme_boite(Vector3(3.2, 1.2, 1.8)), Transform3D(Basis(), Vector3(0.4, 0.6, 0)))


func _sechoir_filets(avant: float, cote: float) -> void:
	var n := Node3D.new()
	n.name = "SechoirFilets"
	n.transform = _base(avant, cote, PI * 0.5)
	add_child(n)
	for x in [-3.0, 0.0, 3.0]:
		_piece(_boite(Vector3(0.1, 2.0, 0.1)), mats["bois"], Transform3D(Basis(), Vector3(x, 1.0, 0)), n)
	_piece(_boite(Vector3(6.2, 0.06, 0.06)), mats["bois"], Transform3D(Basis(), Vector3(0, 1.95, 0)), n)
	var f := PlaneMesh.new()
	f.size = Vector2(6.0, 1.6)
	f.orientation = PlaneMesh.FACE_Z
	_piece(f, mats["filet"], Transform3D(Basis(Vector3(1, 0, 0), 0.08), Vector3(0, 1.15, 0.02)), n)


## Libération : le drapeau des Racines remplace celui du Cobra, les fumoirs reprennent.
func liberer() -> void:
	drapeau_mat.set_shader_parameter("image", load("res://data/textures/drapeau_racines.jpg"))

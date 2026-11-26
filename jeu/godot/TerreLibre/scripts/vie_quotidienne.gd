## Gestes du quotidien : femmes qui pilent au mortier, pêcheurs qui réparent les filets,
## enfants qui jouent au ballon. À Port-Néré dès le départ ; à Akwéri une fois le village libéré
## (la vie reprend).
class_name VieQuotidienne
extends Node3D

var terrain: Terrain
var rng := RandomNumberGenerator.new()
var enfants: Array = []    # [noeud, centre, rayon, vitesse, angle]
var ballons: Array = []
var akweri_fait := false
var pilons: Array = []     # [pilon, attache à la main] : le pilon reste vertical, guidé par la main


func _sol(x: float, z: float) -> float:
	return terrain.hauteur(x, z)


func _perso(modele: String, anim: String, pos: Vector3, angle: float, phase_fixe := -1.0) -> Node3D:
	var p: Node3D = (load("res://personnages/%s.glb" % modele) as PackedScene).instantiate()
	Apparence.ameliorer(p)
	add_child(p)
	p.global_position = pos
	p.rotation.y = angle
	var ap: AnimationPlayer = p.find_child("AnimationPlayer", true, false)
	ap.get_animation(anim).loop_mode = Animation.LOOP_LINEAR
	ap.play(anim)
	var phase := rng.randf() * 1.0 if phase_fixe < 0.0 else phase_fixe
	ap.seek(phase, true)
	p.set_meta("phase", phase)
	return p


## Son 3D calé sur le geste (même cycle que l'animation, même départ).
func _son_geste(p: Node3D, nom: String, volume := 0.0) -> void:
	var s: AudioStreamWAV = load("res://sons/%s.wav" % nom)
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = int(s.get_length() * s.mix_rate)
	var a := AudioStreamPlayer3D.new()
	a.stream = s
	a.unit_size = 4.0
	a.max_distance = 45.0
	a.volume_db = volume
	p.add_child(a)
	a.position.y = 0.6
	a.play(fmod(float(p.get_meta("phase", 0.0)), s.get_length()))


## Femme qui pile : mortier en bois devant elle, pilon tenu dans les mains.
func pileuse(pos: Vector2, angle: float, modele := "femme", phase := -1.0, avec_mortier := true) -> void:
	var h := _sol(pos.x, pos.y)
	var p := _perso(modele, "Piler", Vector3(pos.x, h, pos.y), angle, phase)
	var devant := Vector3(sin(angle), 0, cos(angle))
	if avec_mortier:
		_mortier(Vector3(pos.x, h, pos.y) + devant * 0.36)
	var sq: Skeleton3D = p.find_child("Skeleton3D", true, false)
	var att := BoneAttachment3D.new()
	att.bone_name = "mixamorig_RightHand"
	sq.add_child(att)
	var pilon := MeshInstance3D.new()
	var cp := CylinderMesh.new()
	cp.top_radius = 0.05
	cp.bottom_radius = 0.06
	cp.height = 1.8
	cp.radial_segments = 10
	pilon.mesh = cp
	pilon.material_override = _bois()
	pilon.top_level = true
	att.add_child(pilon)
	pilons.append([pilon, att])
	_son_geste(p, "pilon", -2.0)


## Deux femmes qui pilent ensemble dans le même mortier, en alternance (un coup chacune).
func pilage_duo(pos: Vector2, angle: float, modele_a := "femme", modele_b := "femme_agee") -> void:
	var dir := Vector2(sin(angle), cos(angle))
	var h := _sol(pos.x, pos.y)
	_mortier(Vector3(pos.x, h, pos.y))
	var phase := rng.randf()
	pileuse(pos - dir * 0.42, angle, modele_a, phase, false)
	pileuse(pos + dir * 0.42, angle + PI, modele_b, fmod(phase + 0.5, 1.0), false)


var _maillage_mortier: ArrayMesh
## Mortier creusé dans un tronc : pied évasé, taille étroite, panse large, bord épais (≈ 75 cm).
func _mortier(base: Vector3) -> void:
	if _maillage_mortier == null:
		var profil := [Vector2(0.0, 0.0), Vector2(0.27, 0.0), Vector2(0.28, 0.05), Vector2(0.2, 0.14), Vector2(0.15, 0.28),
			Vector2(0.2, 0.42), Vector2(0.26, 0.58), Vector2(0.27, 0.74), Vector2(0.2, 0.75), Vector2(0.17, 0.62), Vector2(0.0, 0.5)]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var cotes := 18
		for i in profil.size() - 1:
			var a: Vector2 = profil[i]
			var b: Vector2 = profil[i + 1]
			for k in cotes:
				var t0 := TAU * k / cotes
				var t1 := TAU * (k + 1) / cotes
				var q := [Vector3(cos(t0) * a.x, a.y, sin(t0) * a.x), Vector3(cos(t1) * a.x, a.y, sin(t1) * a.x),
					Vector3(cos(t1) * b.x, b.y, sin(t1) * b.x), Vector3(cos(t0) * b.x, b.y, sin(t0) * b.x)]
				var n: Vector3 = (q[1] - q[0]).cross(q[3] - q[0]).normalized()
				for j in [0, 1, 2, 0, 2, 3]:
					st.set_normal(-n)
					st.set_uv(Vector2(float(k) / cotes * 2.0, q[j].y * 2.0))
					st.add_vertex(q[j])
		_maillage_mortier = st.commit()
		var m := _bois()
		m.albedo_color = Color(0.62, 0.46, 0.32)
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_maillage_mortier.surface_set_material(0, m)
	var mi := MeshInstance3D.new()
	mi.mesh = _maillage_mortier
	add_child(mi)
	mi.global_position = base
	mi.rotation.y = rng.randf() * TAU


# ---------------------------------------------------------------------
# Objets de cour : panier de manioc, canaris en terre, bassine émaillée, tabouret
# ---------------------------------------------------------------------
var _mats_cour := {}
func _mat_cour(nom: String) -> StandardMaterial3D:
	if not _mats_cour.has(nom):
		var m := StandardMaterial3D.new()
		match nom:
			"terre_cuite":
				m.albedo_color = Color(0.62, 0.32, 0.18)
				m.roughness = 0.9
			"vannerie":
				m.albedo_texture = load("res://data/textures/thatch_roof_angled_diff.jpg")
				m.uv1_triplanar = true
				m.uv1_scale = Vector3(4, 4, 4)
				m.albedo_color = Color(0.95, 0.8, 0.6)
			"manioc":
				m.albedo_color = Color(0.92, 0.88, 0.78)
				m.roughness = 0.7
			"peau_manioc":
				m.albedo_color = Color(0.45, 0.28, 0.16)
				m.roughness = 0.95
			"verdure":
				m.albedo_color = Color(0.22, 0.45, 0.15)
				m.roughness = 0.8
		_mats_cour[nom] = m
	return _mats_cour[nom]


func _forme(mesh: Mesh, mat: Material, pos: Vector3, rot := 0.0, echelle := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)
	mi.global_transform = Transform3D(Basis(Vector3.UP, rot).scaled(echelle), pos)
	return mi


func _canari(base: Vector3, r: float) -> void:
	var sp := SphereMesh.new()
	sp.radius = r
	sp.height = r * 1.7
	sp.radial_segments = 14
	sp.rings = 8
	_forme(sp, _mat_cour("terre_cuite"), base + Vector3(0, r * 0.8, 0))
	var col := CylinderMesh.new()
	col.top_radius = r * 0.55
	col.bottom_radius = r * 0.5
	col.height = r * 0.3
	col.radial_segments = 14
	_forme(col, _mat_cour("terre_cuite"), base + Vector3(0, r * 1.65, 0))


func _panier(base: Vector3, contenu: String) -> void:
	var cy := CylinderMesh.new()
	cy.top_radius = 0.3
	cy.bottom_radius = 0.22
	cy.height = 0.2
	cy.radial_segments = 16
	_forme(cy, _mat_cour("vannerie"), base + Vector3(0, 0.1, 0))
	if contenu == "manioc":
		var cap := CapsuleMesh.new()
		cap.radius = 0.05
		cap.height = 0.42
		for k in 6:
			var a := rng.randf() * TAU
			var pos := base + Vector3(cos(a) * 0.12, 0.22 + (k / 3) * 0.06, sin(a) * 0.12)
			var mi := _forme(cap, _mat_cour("manioc" if k % 2 == 0 else "peau_manioc"), pos, rng.randf() * TAU)
			mi.rotate_object_local(Vector3.RIGHT, PI * 0.5 + rng.randf_range(-0.2, 0.2))
	else:  # légumes verts (feuilles de manioc, gombo)
		var sp := SphereMesh.new()
		sp.radius = 0.24
		sp.height = 0.16
		_forme(sp, _mat_cour("verdure"), base + Vector3(0, 0.22, 0))


func _bassine(base: Vector3) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = [Color(0.15, 0.2, 0.22), Color(0.85, 0.85, 0.82), Color(0.2, 0.45, 0.7), Color(0.75, 0.15, 0.12)][rng.randi() % 4]
	m.roughness = 0.25
	m.metallic = 0.1
	var cy := CylinderMesh.new()
	cy.top_radius = 0.36
	cy.bottom_radius = 0.24
	cy.height = 0.15
	cy.radial_segments = 20
	_forme(cy, m, base + Vector3(0, 0.075, 0))
	var eau := CylinderMesh.new()  # manioc pilé ou eau dedans
	eau.top_radius = 0.33
	eau.bottom_radius = 0.33
	eau.height = 0.01
	_forme(eau, _mat_cour("manioc"), base + Vector3(0, 0.13, 0))


func _tabouret(base: Vector3, rot: float) -> void:
	var b := _bois()
	var dessus := BoxMesh.new()
	dessus.size = Vector3(0.36, 0.05, 0.26)
	_forme(dessus, b, base + Vector3(0, 0.3, 0), rot)
	var pied := BoxMesh.new()
	pied.size = Vector3(0.05, 0.28, 0.05)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_forme(pied, b, base + Basis(Vector3.UP, rot) * Vector3(sx * 0.14, 0.14, sz * 0.09), rot)


## Une cour qui vit : objets posés autour d'un point (manioc, canaris, bassine, tabouret).
func objets_cour(c: Vector2, angle: float) -> void:
	var dir := Vector2(sin(angle), cos(angle))
	var lat := dir.orthogonal()
	var pts := [c + lat * 1.3 + dir * 0.6, c + lat * 1.9 - dir * 0.3, c - lat * 1.5 + dir * 0.8, c - lat * 2.2 - dir * 0.5,
		c + dir * 1.7, c - lat * 0.9 - dir * 1.4]
	var y := func(q: Vector2) -> Vector3: return Vector3(q.x, _sol(q.x, q.y), q.y)
	_panier(y.call(pts[0]), "manioc")
	_panier(y.call(pts[1]), "verdure")
	_canari(y.call(pts[2]), 0.2)
	_canari(y.call(pts[3]), 0.16)
	_bassine(y.call(pts[4]))
	_tabouret(y.call(pts[5]), angle + 0.4)


## Ancien assis sur une chaise en plastique (djellaba ou boubou, bonnet).
func ancien_chaise(pos: Vector2, angle: float, modele := "ancien") -> void:
	var h := _sol(pos.x, pos.y)
	var chaise: Node3D = (load("res://props/plastic_monobloc_chair_01.glb") as PackedScene).instantiate()
	add_child(chaise)
	chaise.global_transform = Transform3D(Basis(Vector3.UP, angle), Vector3(pos.x, h, pos.y))
	var p := _perso(modele, "Assis", Vector3(pos.x, h + 0.02, pos.y) + Vector3(sin(angle), 0, cos(angle)) * 0.08, angle)
	p.set_meta("assis", true)


# ---------------------------------------------------------------------
# Pêche en pirogue : un pêcheur debout pousse à la perche, un autre tient son épervier
# ---------------------------------------------------------------------
var _maillage_pirogue: ArrayMesh

func _pirogue_maillage() -> ArrayMesh:
	if _maillage_pirogue:
		return _maillage_pirogue
	# coque monoxyle ouverte, effilée aux deux bouts, avec trois bancs en travers
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var l := 6.8
	var stations := 16
	var profil := [Vector2(-1.0, 1.0), Vector2(-0.92, 0.4), Vector2(-0.6, 0.06), Vector2(0.0, 0.0), Vector2(0.6, 0.06), Vector2(0.92, 0.4), Vector2(1.0, 1.0)]
	var anneaux: Array = []
	for i in stations + 1:
		var t := float(i) / stations
		var e := pow(sin(t * PI), 0.55)
		var anneau: Array = []
		for p in profil:
			anneau.append(Vector3(p.x * 0.48 * e, 0.45 * p.y + 0.18 * (1.0 - e) * p.y, (t - 0.5) * l))
		anneaux.append(anneau)
	for i in stations:
		for j in profil.size() - 1:
			var a: Vector3 = anneaux[i][j]
			var b: Vector3 = anneaux[i][j + 1]
			var c2: Vector3 = anneaux[i + 1][j + 1]
			var d: Vector3 = anneaux[i + 1][j]
			var col := Color(0.5, 0.42, 0.32) if j in [1, 2, 3, 4] else Color(0.62, 0.55, 0.45)
			if (j == 0 or j == 5) and i % 5 < 2:
				col = Color(0.2, 0.35, 0.5)   # bande peinte délavée sur le bordé
			var nrm := (b - a).cross(d - a).normalized()
			for v in [[a, Vector2(0, 0)], [b, Vector2(1, 0)], [c2, Vector2(1, 1)], [a, Vector2(0, 0)], [c2, Vector2(1, 1)], [d, Vector2(0, 1)]]:
				st.set_normal(nrm)
				st.set_color(col)
				st.set_uv(v[1])
				st.add_vertex(v[0])
	_maillage_pirogue = st.commit()
	var m := _bois()
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1, 1, 1)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_maillage_pirogue.surface_set_material(0, m)
	var sb := SurfaceTool.new()   # bancs en travers, surface à part
	sb.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in [-1.8, 0.0, 1.8]:
		var bx := BoxMesh.new()
		bx.size = Vector3(0.82, 0.05, 0.2)
		sb.append_from(bx, 0, Transform3D(Basis(), Vector3(0, 0.33, z)))
	_maillage_pirogue = sb.commit(_maillage_pirogue)
	var mb := _bois()
	mb.albedo_color = Color(0.5, 0.4, 0.3)
	_maillage_pirogue.surface_set_material(1, mb)
	return _maillage_pirogue


## Points d'eau peu profonde (1 à 5 m) près d'un lieu, pour poser des pirogues.
func points_mer(c: Vector2, n: int, rmin: float, rmax: float) -> Array:
	var res: Array = []
	for essai in 400:
		if res.size() >= n:
			break
		var a := rng.randf() * TAU
		var p := c + Vector2(cos(a), sin(a)) * rng.randf_range(rmin, rmax)
		var h := _sol(p.x, p.y)
		if h < -1.0 and h > -5.0:
			var libre := true
			for q in res:
				if p.distance_to(q) < 14.0:
					libre = false
			if libre:
				res.append(p)
	return res


func pirogue_peche(pos: Vector2, angle: float, geste: String) -> void:
	var pir := Node3D.new()
	add_child(pir)
	pir.global_transform = Transform3D(Basis(Vector3.UP, angle), Vector3(pos.x, -0.22, pos.y))
	var coque := MeshInstance3D.new()
	coque.mesh = _pirogue_maillage()
	pir.add_child(coque)
	pirogues.append([pir, -0.22, rng.randf() * TAU])
	var p: Node3D = (load("res://personnages/pecheur_lac.glb") as PackedScene).instantiate()
	Apparence.ameliorer(p)
	pir.add_child(p)
	p.position = Vector3(0, 0.12, 0.9 if geste == "Perche" else 0.0)
	p.rotation.y = rng.randf_range(-0.3, 0.3) + (0.0 if geste == "Perche" else PI * 0.5)
	var ap: AnimationPlayer = p.find_child("AnimationPlayer", true, false)
	ap.get_animation(geste).loop_mode = Animation.LOOP_LINEAR
	ap.play(geste)
	ap.seek(rng.randf() * 2.0, true)
	var sq: Skeleton3D = p.find_child("Skeleton3D", true, false)
	var md := BoneAttachment3D.new()
	md.bone_name = "mixamorig_RightHand"
	sq.add_child(md)
	var mg := BoneAttachment3D.new()
	mg.bone_name = "mixamorig_LeftHand"
	sq.add_child(mg)
	if geste == "Perche":
		var perche := MeshInstance3D.new()
		var cy := CylinderMesh.new()
		cy.top_radius = 0.022
		cy.bottom_radius = 0.028
		cy.height = 1.0
		cy.radial_segments = 6
		perche.mesh = cy
		var mb := _bois()
		mb.albedo_color = Color(0.78, 0.66, 0.45)
		perche.material_override = mb
		perche.top_level = true
		add_child(perche)
		perches.append([perche, md, mg])
	else:
		# épervier roulé : cône de filet qui pend de la main gauche, plombs en bas
		var filet := MeshInstance3D.new()
		var cn := CylinderMesh.new()
		cn.top_radius = 0.05
		cn.bottom_radius = 0.2
		cn.height = 0.75
		cn.radial_segments = 10
		filet.mesh = cn
		var mf := StandardMaterial3D.new()
		mf.albedo_color = Color(0.82, 0.76, 0.62)
		mf.roughness = 0.95
		filet.material_override = mf
		filet.top_level = true
		add_child(filet)
		filets.append([filet, mg])


func _peche_process() -> void:
	var tps := Time.get_ticks_msec() * 0.001
	for pr in pirogues:
		var n: Node3D = pr[0]
		var ph: float = pr[2]
		n.position.y = pr[1] + 0.05 * sin(tps * 1.1 + ph)
		n.rotation.z = 0.025 * sin(tps * 0.9 + ph * 1.7)
		n.rotation.x = 0.015 * sin(tps * 0.7 + ph)
	for fi in filets:
		var main: Vector3 = (fi[1] as Node3D).global_position
		(fi[0] as Node3D).global_position = main - Vector3(0, 0.36, 0)
	for pe in perches:
		# la perche passe par les deux mains et descend jusqu'au fond, côté gauche
		var d: Vector3 = (pe[1] as Node3D).global_position
		var g: Vector3 = (pe[2] as Node3D).global_position
		var axe := g - d
		if axe.length() < 0.05:
			continue
		axe = axe.normalized()
		var haut := d - axe * 0.6
		var bas := g + axe * 2.8
		var ay := (haut - bas).normalized()
		var ax := ay.cross(Vector3.FORWARD if absf(ay.z) < 0.9 else Vector3.RIGHT).normalized()
		(pe[0] as Node3D).global_transform = Transform3D(Basis(ax, ay * haut.distance_to(bas), ax.cross(ay)), (haut + bas) * 0.5)


# ---------------------------------------------------------------------
# Corde à sauter : deux enfants font tourner la corde, un troisième saute, d'autres attendent
# ---------------------------------------------------------------------
var cordes: Array = []
var pirogues: Array = []   # [pirogue, hauteur de base, phase] : bercées par la houle
var perches: Array = []    # [perche, main droite, main gauche]
var filets: Array = []     # [épervier roulé, main gauche] : le filet pend sous la main   # [mesh immédiat, main A, main B, lecteur d'animation du sauteur]

func corde_a_sauter(c: Vector2, angle: float) -> void:
	var dir := Vector2(sin(angle), cos(angle))
	var h := _sol(c.x, c.y)
	var a := c - dir * 1.9
	var b := c + dir * 1.9
	var t1 := _perso("garcon", "TournerCorde", Vector3(a.x, _sol(a.x, a.y), a.y), angle, 0.0)
	var t2 := _perso("fille", "TournerCorde", Vector3(b.x, _sol(b.x, b.y), b.y), angle + PI, 0.0)
	var sauteur := _perso(["fille", "garcon"][rng.randi() % 2], "SauterCorde", Vector3(c.x, h, c.y), angle + PI * 0.5, 0.0)
	for k in 2:  # ceux qui attendent leur tour
		var q := c + dir.orthogonal() * (2.6 + k * 0.7) + dir * rng.randf_range(-0.6, 0.6)
		_perso(["garcon", "fille"][k], "Repos", Vector3(q.x, _sol(q.x, q.y), q.y), atan2(c.x - q.x, c.y - q.y))
	var mains: Array = []
	for t in [t1, t2]:
		var sq: Skeleton3D = t.find_child("Skeleton3D", true, false)
		var att := BoneAttachment3D.new()
		att.bone_name = "mixamorig_RightHand"
		sq.add_child(att)
		mains.append(att)
	var im := ImmediateMesh.new()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.85, 0.2, 0.15)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.8
	mi.material_override = m
	mi.top_level = true
	add_child(mi)
	cordes.append([im, mains[0], mains[1], sauteur.find_child("AnimationPlayer", true, false)])


func _dessiner_cordes() -> void:
	var cam := get_viewport().get_camera_3d()
	for co in cordes:
		var im: ImmediateMesh = co[0]
		var a: Vector3 = (co[1] as Node3D).global_position
		var b: Vector3 = (co[2] as Node3D).global_position
		var ap: AnimationPlayer = co[3]
		var t := ap.current_animation_position
		var theta := TAU * t   # en bas (sous les pieds) à t = 0,75, quand le sauteur est en l'air
		var corde := b - a
		var cote := corde.cross(Vector3.UP).normalized()
		var bombe := Vector3.UP * sin(theta) + cote * cos(theta)
		var milieu := (a + b) * 0.5
		var r := milieu.y - _sol(milieu.x, milieu.z) - 0.03   # assez ample pour frôler le sol
		im.clear_surfaces()
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		var vue := (cam.global_position - (a + b) * 0.5).normalized() if cam else Vector3.FORWARD
		for i in 21:
			var s := float(i) / 20.0
			var p := a.lerp(b, s) + bombe * r * sin(PI * s)
			var tangente := (corde + bombe * r * PI * cos(PI * s)).normalized()
			var large := tangente.cross(vue).normalized() * 0.008
			im.surface_set_normal(vue)
			im.surface_add_vertex(p - large)
			im.surface_set_normal(vue)
			im.surface_add_vertex(p + large)
		im.surface_end()


## Pêcheur accroupi qui répare un filet étalé devant lui.
func pecheur(pos: Vector2, angle: float) -> void:
	var h := _sol(pos.x, pos.y)
	_perso("pecheur", "Reparer", Vector3(pos.x, h, pos.y), angle)
	var filet := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2.2, 1.6)
	filet.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_texture = _texture_filet()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.uv1_scale = Vector3(16, 12, 1)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR  # sans mipmaps : les mailles restent visibles de loin
	m.alpha_scissor_threshold = 0.3
	filet.material_override = m
	add_child(filet)
	var devant := Vector3(sin(angle), 0, cos(angle))
	var c := Vector3(pos.x, 0, pos.y) + devant * 0.8
	var nx := _sol(c.x - 0.5, c.z) - _sol(c.x + 0.5, c.z)
	var nz := _sol(c.x, c.z - 0.5) - _sol(c.x, c.z + 0.5)
	var haut := Vector3(nx, 1.0, nz).normalized()
	filet.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, haut)) * Basis(Vector3.UP, angle), Vector3(c.x, _sol(c.x, c.z) + 0.06, c.z))


var _tex_filet: ImageTexture
func _texture_filet() -> ImageTexture:
	if _tex_filet:
		return _tex_filet
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in 32:
		for k in 3:
			img.set_pixel(i, k, Color(0.18, 0.42, 0.38, 1))
			img.set_pixel(k, i, Color(0.18, 0.42, 0.38, 1))
	_tex_filet = ImageTexture.create_from_image(img)
	return _tex_filet


## Enfants qui courent après un ballon en tournant autour d'un point.
func jeu_enfants(centre: Vector2, nb := 3) -> void:
	var ballon := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.11
	sp.height = 0.22
	ballon.mesh = sp
	var m := StandardMaterial3D.new()
	m.albedo_color = [Color(0.9, 0.15, 0.1), Color(0.95, 0.95, 0.9), Color(0.1, 0.35, 0.8)][rng.randi() % 3]
	ballon.material_override = m
	add_child(ballon)
	var r := rng.randf_range(4.0, 6.5)
	ballons.append([ballon, centre, r, rng.randf_range(1.6, 2.2), rng.randf() * TAU])
	for i in nb:
		var p := _perso(["garcon", "fille"][i % 2], "Course", Vector3.ZERO, 0.0)
		var ap: AnimationPlayer = p.find_child("AnimationPlayer", true, false)
		ap.speed_scale = 0.8
		enfants.append([p, ballons.size() - 1, -0.5 - i * 0.45 - rng.randf_range(0, 0.2), rng.randf_range(-0.6, 0.6)])


func port_nere(ville: VillePortNere) -> void:
	terrain = ville.terrain
	rng.seed = 512
	var r: Dictionary = ville.reperes
	# pileuses près du marché et devant des maisons
	if r.has("marche"):
		var m: Vector3 = r["marche"]
		pileuse(Vector2(m.x - 20, m.z + 16), 0.6, "femme")
		pileuse(Vector2(m.x - 17.5, m.z + 17), -1.8, "femme2")
	if r.has("maison_faris"):
		var mf: Vector3 = r["maison_faris"]
		pileuse(Vector2(mf.x + 2.5, mf.z - 1.0), 2.4, "femme_agee")
	# pêcheurs sur la plage, côté mer du boulevard
	var bvd: PackedVector2Array = r["boulevard"]
	for i in 3:
		var p := bvd[bvd.size() * (i + 1) / 5]
		var t := (bvd[mini(bvd.size() - 1, bvd.size() * (i + 1) / 5 + 1)] - p).normalized()
		var n := Vector2(-t.y, t.x)
		if n.x > 0.0:
			n = -n
		var q := p + n * rng.randf_range(16.0, 22.0)
		for essai in 6:
			if _sol(q.x, q.y) > 0.9:
				break
			q -= n * 3.0  # trop près de l'eau : on remonte vers la plage sèche
		pecheur(q, atan2(n.x, n.y) + PI + rng.randf_range(-0.5, 0.5))
	# enfants qui jouent sur la place et dans une ruelle
	if r.has("place"):
		var pl: Vector3 = r["place"]
		jeu_enfants(Vector2(pl.x + 26, pl.z + 12), 3)
	if r.has("eglise"):
		var e: Vector3 = r["eglise"]
		jeu_enfants(Vector2(e.x - 18, e.z + 4), 2)
	if r.has("maison_faris"):
		var mf: Vector3 = r["maison_faris"]
		objets_cour(Vector2(mf.x + 4.5, mf.z - 2.0), 2.4)
	if r.has("maquis"):
		var mq: Vector3 = r["maquis"]
		ancien_chaise(Vector2(mq.x + 3.0, mq.z + 3.5), 0.8)
	if r.has("place"):
		var pl2: Vector3 = r["place"]
		corde_a_sauter(Vector2(pl2.x - 22, pl2.z + 16), 1.2)
		var k := 0
		for q in points_mer(Vector2(pl2.x, pl2.z), 3, 90.0, 260.0):
			pirogue_peche(q, rng.randf() * TAU, "Perche" if k % 2 == 0 else "Epervier")
			k += 1


## Bomé : anciens assis sous l'arbre à palabres, Baya Efua devant le grenier de la coopérative,
## cultivateurs qui binent, femmes qui pilent dans les cours, enfants sur la place.
func bome(v: VillageBome) -> void:
	terrain = v.terrain
	rng.seed = 606
	var r: Dictionary = v.reperes
	var c: Vector3 = r["place"]
	var bancs: Array = r["bancs"]
	var anciens := ["ancien", "villageois", "ancien", "homme3"]
	for i in anciens.size():
		var b: Array = bancs[i * 2 % bancs.size()] if i < 3 else bancs[1]
		var p: Vector3 = b[0]
		var vers := Vector2(c.x - p.x, c.z - p.z)
		var assis := _perso(anciens[i], "Assis", Vector3(p.x, c.y + 0.06, p.z), atan2(vers.x, vers.y))
		assis.global_position += Vector3(vers.normalized().x, 0, vers.normalized().y) * -0.12
	# Baya Efua, appuyée sur sa canne, devant le grenier à semences
	var g: Vector3 = r["grenier"]
	var vg := Vector2(c.x - g.x, c.z - g.z).normalized()
	var pb := Vector2(g.x, g.z) + vg * 4.2
	var baya := _perso("baya", "Repos", Vector3(pb.x, _sol(pb.x, pb.y), pb.y), atan2(vg.x, vg.y))
	_canne(baya)
	# femmes qui pilent dans les cours
	var maisons: Array = r["maisons"]
	var modeles := ["femme", "femme2", "femme_agee", "femme"]
	for i in maisons.size():
		var m: Vector3 = maisons[i]
		var vm := Vector2(c.x - m.x, c.z - m.z).normalized()
		var q := Vector2(m.x, m.z) + vm * 6.5 + vm.orthogonal() * 2.0
		var a := atan2(-vm.x, -vm.y) + rng.randf_range(-0.6, 0.6)
		objets_cour(Vector2(m.x, m.z) + vm * 3.2 - vm.orthogonal() * 3.0, a)
		if i % 3 == 0:
			pilage_duo(q, a, modeles[(i / 3) % modeles.size()], ["femme_agee", "femme2", "femme"][i % 3])
		elif i % 3 == 1 and i < 8:
			ancien_chaise(Vector2(m.x, m.z) + vm * 4.0 + vm.orthogonal() * 4.5, atan2(vm.x, vm.y))
	# cultivateurs à la houe dans les champs de manioc et de maïs
	var champs: Array = r["champs"]
	for k in champs.size():
		if k % 4 == 3:
			continue  # cacaoyère : pas de binage
		var cp: Vector2 = champs[k]
		for j in 2:
			var q := cp + Vector2(rng.randf_range(-9, 9), rng.randf_range(-6, 6))
			var bineur := _perso(["cultivateur", "homme2", "cultivateur", "villageois"][(k + j) % 4], "Biner", Vector3(q.x, _sol(q.x, q.y), q.y), rng.randf() * TAU)
			_houe(bineur)
	jeu_enfants(Vector2(c.x - 12.0, c.z + 10.0), 3)
	corde_a_sauter(Vector2(c.x + 9.0, c.z - 11.0), 0.6)


## Tikané occupé : les familles sont enfermées, seuls les gardes adultes du Cobra sont dehors.
## (Les jeunes recrues ne sont pas montrées ici : la mission 8 les gère, sans jamais en faire des cibles.)
func tikane(v: VillageTikane) -> void:
	terrain = v.terrain
	rng.seed = 808
	var c: Vector3 = v.reperes["place"]
	var gardes: Array = v.reperes["gardes"]
	var modeles := ["homme2", "villageois", "homme3", "homme2", "villageois", "homme3", "homme2"]
	for i in gardes.size():
		var g: Vector3 = gardes[i]
		var regard := Vector2(g.x - c.x, g.z - c.z)
		if i < 2:
			regard = -regard   # devant la prison : face à la place
		var garde := _perso(modeles[i], "Repos", g, atan2(regard.x, regard.y) + rng.randf_range(-0.4, 0.4))
		_camoufler(garde)


func _camoufler(perso: Node3D) -> void:
	var camo: Texture2D = load("res://data/textures/camouflage.jpg")
	for mi in perso.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for k in m.mesh.get_surface_count():
			var mat := m.mesh.surface_get_material(k)
			if mat and mat.resource_name == "Chemise":
				var m2: StandardMaterial3D = (mat as StandardMaterial3D).duplicate()
				m2.albedo_texture = camo
				m2.albedo_color = Color(0.8, 0.85, 0.75)
				m.set_surface_override_material(k, m2)
	var arme := Arme.new()
	perso.add_child(arme)
	arme.tenir(perso)


func _bois() -> StandardMaterial3D:
	var bois := StandardMaterial3D.new()
	bois.albedo_texture = load("res://data/textures/weathered_brown_planks_diff.jpg")
	bois.uv1_triplanar = true
	bois.albedo_color = Color(0.7, 0.56, 0.42)
	return bois


func _main(p: Node3D, os: String) -> BoneAttachment3D:
	var sq: Skeleton3D = p.find_child("Skeleton3D", true, false)
	var att := BoneAttachment3D.new()
	att.bone_name = "mixamorig_%sHand" % os
	sq.add_child(att)
	return att


var cannes: Array = []   # [canne, main] : la canne descend de la main jusqu'au sol
var houes: Array = []    # [houe, main droite, main gauche]


func _canne(p: Node3D) -> void:
	var cn := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 0.013
	cy.bottom_radius = 0.011
	cy.height = 1.0
	cn.mesh = cy
	cn.material_override = _bois()
	cn.top_level = true
	var main := _main(p, "Right")
	main.add_child(cn)
	cannes.append([cn, main])


func _houe(p: Node3D) -> void:
	var houe := Node3D.new()
	houe.top_level = true
	var manche := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 0.02
	cy.bottom_radius = 0.022
	cy.height = 1.0
	manche.mesh = cy
	manche.material_override = _bois()
	manche.rotation.x = PI * 0.5
	manche.position.z = 0.5
	houe.add_child(manche)
	var fer := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(0.2, 0.24, 0.012)
	fer.mesh = bx
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.22, 0.2, 0.19)
	m.metallic = 0.6
	m.roughness = 0.55
	fer.material_override = m
	fer.position = Vector3(0, -0.1, 1.0)
	fer.rotation.x = -0.35
	houe.add_child(fer)
	var md := _main(p, "Right")
	var mg := _main(p, "Left")
	md.add_child(houe)
	houes.append([houe, md, mg])
	_son_geste(p, "houe", -6.0)


func akweri(village: Node, mission: Node) -> void:
	set_meta("village", village)
	set_meta("mission", mission)
	terrain = village.terrain
	var pa: Vector2 = village.centre + village.mer * -1.0 + village.plage * 38.0
	apatam(pa, atan2(village.mer.x, village.mer.y))
	set_meta("apatam", pa)


## Abri de palmes séchées sur six poteaux, au bord de l'eau : on s'y assoit pour parler, à l'ombre.
func apatam(c: Vector2, angle: float) -> void:
	var h := _sol(c.x, c.y)
	var base := Transform3D(Basis(Vector3.UP, angle), Vector3(c.x, h, c.y))
	var b := _bois()
	b.albedo_color = Color(0.55, 0.45, 0.35)
	var poteau := CylinderMesh.new()
	poteau.top_radius = 0.07
	poteau.bottom_radius = 0.09
	poteau.height = 2.6
	poteau.radial_segments = 7
	for sx in [-1.0, 0.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var q := base * Vector3(sx * 2.4, 1.3 - (0.15 if sz > 0 else 0.0), sz * 1.7)
			_forme(poteau, b, q, rng.randf() * TAU)
	var palmes := StandardMaterial3D.new()
	palmes.albedo_texture = load("res://data/textures/thatch_roof_angled_diff.jpg")
	palmes.normal_enabled = true
	palmes.normal_texture = load("res://data/textures/thatch_roof_angled_nor.jpg")
	palmes.uv1_triplanar = true
	palmes.uv1_scale = Vector3(0.6, 0.6, 0.6)
	palmes.albedo_color = Color(0.95, 0.85, 0.65)
	palmes.cull_mode = BaseMaterial3D.CULL_DISABLED
	var toit := BoxMesh.new()
	toit.size = Vector3(6.2, 0.22, 4.4)
	var mi := _forme(toit, palmes, base * Vector3(0, 2.55, 0), angle)
	mi.rotate_object_local(Vector3.RIGHT, 0.06)
	var traverse := BoxMesh.new()
	traverse.size = Vector3(5.2, 0.1, 0.1)
	for sz in [-1.0, 1.0]:
		_forme(traverse, b, base * Vector3(0, 2.42 - (0.15 if sz > 0 else 0.0), sz * 1.7), angle)


## Akwéri libéré : la vie reprend (appelé une seule fois, au moment de la libération).
func _akweri_revit(v) -> void:
	var cv: Vector2 = v.centre
	var mer: Vector2 = v.mer
	var plage: Vector2 = v.plage
	var vers_mer := atan2(mer.x, mer.y)
	pilage_duo(cv + mer * -20.0 + plage * -10.0, vers_mer + 0.7, "femme", "femme2")
	objets_cour(cv + mer * -21.0 + plage * -6.0, vers_mer)
	objets_cour(cv + mer * -38.0 + plage * 14.0, vers_mer + PI)
	corde_a_sauter(cv + mer * -16.0 + plage * 16.0, vers_mer + 1.2)
	# sous l'abri de palmes : les anciens sur leurs chaises, face à l'eau
	var kp := 0
	for q in points_mer(cv + mer * 25.0, 3, 5.0, 60.0):
		pirogue_peche(q, rng.randf() * TAU, "Epervier" if kp % 2 == 0 else "Perche")
		kp += 1
	var pa: Vector2 = get_meta("apatam")
	for k in 3:
		ancien_chaise(pa + plage * (k - 1) * 1.6 - mer * 0.6, vers_mer + rng.randf_range(-0.4, 0.4), ["ancien", "villageois", "pecheur"][k])


func _process(delta: float) -> void:
	_dessiner_cordes()
	_peche_process()
	for pa in pilons:
		var main: Node3D = pa[1]
		(pa[0] as Node3D).global_transform = Transform3D(Basis(), main.global_position + Vector3(0, -0.3, 0))
	for ca in cannes:
		var h: Vector3 = (ca[1] as Node3D).global_position
		var sol := _sol(h.x, h.z)
		var bas := Vector3(h.x, sol, h.z) + (ca[1] as Node3D).global_basis.z.slide(Vector3.UP).normalized() * 0.05
		var l := maxf(0.3, h.y - sol)
		var ay := (h - bas).normalized()
		var ax := ay.cross(Vector3.FORWARD).normalized()
		(ca[0] as Node3D).global_transform = Transform3D(Basis(ax, ay * l, ax.cross(ay)), (h + bas) * 0.5)
	for ho in houes:
		var d: Vector3 = (ho[1] as Node3D).global_position
		var g: Vector3 = (ho[2] as Node3D).global_position
		var axe := d - g
		if axe.length() < 0.05:
			continue
		axe = axe.normalized()
		var haut := Vector3.UP if absf(axe.y) < 0.95 else Vector3.FORWARD
		# le manche passe dans les deux mains et dépasse côté droit jusqu'au fer
		(ho[0] as Node3D).global_transform = Transform3D(Basis.looking_at(-axe, haut), g - axe * 0.25)
	for b in ballons:
		b[4] += b[3] / b[2] * delta
		var c: Vector2 = b[1]
		var x: float = c.x + cos(b[4]) * b[2]
		var z: float = c.y + sin(b[4]) * b[2]
		(b[0] as Node3D).global_position = Vector3(x, _sol(x, z) + 0.11 + absf(sin(b[4] * 6.0)) * 0.15, z)
		(b[0] as Node3D).rotate_x(delta * 8.0)
	for e in enfants:
		var b: Array = ballons[e[1]]
		var a: float = b[4] + e[2]
		var rr: float = b[2] + e[3]
		var c: Vector2 = b[1]
		var x := c.x + cos(a) * rr
		var z := c.y + sin(a) * rr
		var n: Node3D = e[0]
		n.global_position = Vector3(x, _sol(x, z), z)
		var dir := Vector2(-sin(a), cos(a))
		n.rotation.y = atan2(dir.x, dir.y)
	# Akwéri libéré : la vie reprend au village
	if not akweri_fait and has_meta("mission"):
		var mi = get_meta("mission")
		if mi.phase == mi.Phase.LIBERE:
			akweri_fait = true
			if has_meta("foule"):
				(get_meta("foule") as Foule).activer("akweri")
			var v = get_meta("village")
			var civ: Array = v.reperes["civils"]
			_akweri_revit(v)
			pileuse(Vector2(civ[0].x + 2.0, civ[0].z + 1.5), 0.3, "femme")
			pileuse(Vector2(civ[4].x - 1.5, civ[4].z + 2.0), 2.0, "femme_agee")
			pecheur(Vector2(civ[2].x + 3.0, civ[2].z - 2.0), 1.2)
			pecheur(Vector2(civ[7].x - 2.0, civ[7].z + 3.0), -2.0)
			jeu_enfants(Vector2(civ[5].x + 6.0, civ[5].z), 3)

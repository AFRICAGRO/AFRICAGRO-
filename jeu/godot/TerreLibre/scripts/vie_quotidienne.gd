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


func _perso(modele: String, anim: String, pos: Vector3, angle: float) -> Node3D:
	var p: Node3D = (load("res://personnages/%s.glb" % modele) as PackedScene).instantiate()
	Apparence.ameliorer(p)
	add_child(p)
	p.global_position = pos
	p.rotation.y = angle
	var ap: AnimationPlayer = p.find_child("AnimationPlayer", true, false)
	ap.play(anim)
	var phase := rng.randf() * 1.0
	ap.seek(phase)
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
func pileuse(pos: Vector2, angle: float, modele := "femme") -> void:
	var h := _sol(pos.x, pos.y)
	var p := _perso(modele, "Piler", Vector3(pos.x, h, pos.y), angle)
	var bois := StandardMaterial3D.new()
	bois.albedo_texture = load("res://data/textures/weathered_brown_planks_diff.jpg")
	bois.uv1_triplanar = true
	bois.albedo_color = Color(0.75, 0.6, 0.45)
	var mortier := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 0.24
	cy.bottom_radius = 0.18
	cy.height = 0.62
	mortier.mesh = cy
	mortier.material_override = bois
	add_child(mortier)
	var devant := Vector3(sin(angle), 0, cos(angle))
	mortier.global_position = Vector3(pos.x, h + 0.31, pos.y) + devant * 0.36
	var sq: Skeleton3D = p.find_child("Skeleton3D", true, false)
	var att := BoneAttachment3D.new()
	att.bone_name = "mixamorig_RightHand"
	sq.add_child(att)
	var pilon := MeshInstance3D.new()
	var cp := CylinderMesh.new()
	cp.top_radius = 0.045
	cp.bottom_radius = 0.045
	cp.height = 1.7
	pilon.mesh = cp
	pilon.material_override = bois
	pilon.top_level = true
	att.add_child(pilon)
	pilons.append([pilon, att])
	_son_geste(p, "pilon", -2.0)


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
	for i in range(0, maisons.size(), 3):
		var m: Vector3 = maisons[i]
		var vm := Vector2(c.x - m.x, c.z - m.z).normalized()
		var q := Vector2(m.x, m.z) + vm * 6.5 + vm.orthogonal() * 2.0
		pileuse(q, atan2(-vm.x, -vm.y) + rng.randf_range(-0.6, 0.6), modeles[(i / 3) % modeles.size()])
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


func _process(delta: float) -> void:
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
			pileuse(Vector2(civ[0].x + 2.0, civ[0].z + 1.5), 0.3, "femme")
			pileuse(Vector2(civ[4].x - 1.5, civ[4].z + 2.0), 2.0, "femme_agee")
			pecheur(Vector2(civ[2].x + 3.0, civ[2].z - 2.0), 1.2)
			pecheur(Vector2(civ[7].x - 2.0, civ[7].z + 3.0), -2.0)
			jeu_enfants(Vector2(civ[5].x + 6.0, civ[5].z), 3)

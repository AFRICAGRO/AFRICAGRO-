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
	ap.seek(rng.randf() * 1.0)
	return p


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


func akweri(village: Node, mission: Node) -> void:
	set_meta("village", village)
	set_meta("mission", mission)


func _process(delta: float) -> void:
	for pa in pilons:
		var main: Node3D = pa[1]
		(pa[0] as Node3D).global_transform = Transform3D(Basis(), main.global_position + Vector3(0, -0.3, 0))
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
			var v = get_meta("village")
			var civ: Array = v.reperes["civils"]
			pileuse(Vector2(civ[0].x + 2.0, civ[0].z + 1.5), 0.3, "femme")
			pileuse(Vector2(civ[4].x - 1.5, civ[4].z + 2.0), 2.0, "femme_agee")
			pecheur(Vector2(civ[2].x + 3.0, civ[2].z - 2.0), 1.2)
			pecheur(Vector2(civ[7].x - 2.0, civ[7].z + 3.0), -2.0)
			jeu_enfants(Vector2(civ[5].x + 6.0, civ[5].z), 3)

## Mouettes qui tournent au-dessus du rivage le plus proche de Faris : vol plané, quelques battements d'ailes.
## Une seule MultiMesh (très peu coûteuse) ; elles se cachent la nuit.
class_name Oiseaux
extends MultiMeshInstance3D

const NB := 16

var terrain: Terrain
var joueur: Node3D
var centre := Vector3.ZERO
var cible := Vector3.ZERO
var oiseaux: Array = []
var minuterie := 0.0
var rng := RandomNumberGenerator.new()


func preparer(t: Terrain, j: Node3D) -> void:
	terrain = t
	joueur = j
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _mouette()
	mm.instance_count = NB
	multimesh = mm
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in NB:
		oiseaux.append({"rayon": rng.randf_range(15, 45), "angle": rng.randf() * TAU, "vit": rng.randf_range(0.25, 0.5) * (1.0 if rng.randf() < 0.7 else -1.0),
				"haut": rng.randf_range(10, 28), "phase": rng.randf(), "bat": 0.0, "decal": Vector3(rng.randf_range(-15, 15), 0, rng.randf_range(-15, 15))})
	centre = joueur.global_position + Vector3(0, 0, 0)
	cible = centre


func _mouette() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tri := func(a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color):
		for p in [[a, ca], [b, cb], [c, cc]]:
			st.set_color(p[1])
			st.set_normal(Vector3.UP)
			st.add_vertex(p[0])
	var corps := Color(0, 0, 0)
	# corps fuselé (avant = -Z)
	tri.call(Vector3(0, 0, -0.32), Vector3(0.06, 0, 0.1), Vector3(-0.06, 0, 0.1), corps, corps, corps)
	tri.call(Vector3(0.06, 0, 0.1), Vector3(0, 0, 0.3), Vector3(-0.06, 0, 0.1), corps, corps, corps)
	tri.call(Vector3(0, 0.05, -0.2), Vector3(0.05, 0, 0.05), Vector3(-0.05, 0, 0.05), Color(0, 0, 1), Color(0, 0, 1), Color(0, 0, 1))
	for s in [-1.0, 1.0]:
		var c0 := Color(0, 0, 1)
		var c1 := Color(0.5, 0, 1)
		var c2 := Color(1.0, 0, 1)
		var e := Vector3(0.06 * s, 0, -0.06)
		var e2 := Vector3(0.06 * s, 0, 0.1)
		var m1 := Vector3(0.42 * s, 0.03, -0.02)
		var m2 := Vector3(0.42 * s, 0.03, 0.12)
		var b := Vector3(0.78 * s, -0.02, 0.18)
		tri.call(e, m1, m2, c0, c1, c1)
		tri.call(e, m2, e2, c0, c1, c0)
		tri.call(m1, b, m2, c1, c2, c1)
	var m := st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/oiseau.gdshader")
	m.surface_set_material(0, mat)
	return m


func _process(delta: float) -> void:
	if joueur == null:
		return
	minuterie -= delta
	if minuterie <= 0.0:
		minuterie = 6.0
		# point de rassemblement : le rivage le plus bas autour de Faris (sur la mer, près de la plage)
		var p := joueur.global_position
		var meilleur := Vector3.INF
		var hmin := INF
		for i in 12:
			var a := TAU * i / 12.0
			for d in [40.0, 90.0, 150.0]:
				var q: Vector3 = p + Vector3(cos(a), 0, sin(a)) * d
				var h := terrain.hauteur(q.x, q.z)
				if h < 0.5 and h > -6.0 and d < hmin + 200.0:
					if meilleur == Vector3.INF or q.distance_to(p) < meilleur.distance_to(p):
						meilleur = q
					hmin = minf(hmin, d)
		cible = Vector3(meilleur.x, 0, meilleur.z) if meilleur != Vector3.INF else Vector3(p.x, 0, p.z) + Vector3(0, 0, -400)
	centre = centre.lerp(cible, minf(1.0, delta * 0.05))
	for i in NB:
		var o: Dictionary = oiseaux[i]
		o["angle"] += o["vit"] * delta
		# battements de temps en temps, sinon vol plané
		if rng.randf() < delta * 0.25:
			o["bat"] = 1.0
		o["bat"] = maxf(0.0, o["bat"] - delta * 0.6)
		var a: float = o["angle"]
		var r: float = o["rayon"]
		var pos: Vector3 = centre + o["decal"] + Vector3(cos(a) * r, o["haut"] + sin(a * 2.0) * 2.0, sin(a) * r)
		var dir := Vector3(-sin(a), 0, cos(a)) * signf(o["vit"])
		var b := Basis.looking_at(dir, Vector3.UP).rotated(dir, -0.35 * signf(o["vit"]))
		multimesh.set_instance_transform(i, Transform3D(b.scaled(Vector3.ONE * 1.1), pos))
		multimesh.set_instance_custom_data(i, Color(o["phase"], minf(1.0, o["bat"] * 1.5), 0, 0))


func regler_nuit(f: float) -> void:
	visible = f < 0.6

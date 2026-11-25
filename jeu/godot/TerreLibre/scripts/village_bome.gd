## Bomé, village de cultivateurs sur les pentes du centre-ouest de Talanké (mission 6 « Champs de Cendre »).
## - Concessions sur terrasses aplanies : maisons en banco (toit de chaume à quatre pans ou de tôle),
##   cases rondes au toit conique, petits greniers sur pilotis, foyers à trois pierres, murets ;
## - place centrale : grand arbre à palabres, bancs en tronc, grenier à semences de la coopérative ;
## - sentiers en latérite entre les concessions ;
## - champs autour : manioc, maïs, cacaoyers à l'ombre ;
## - trois parcelles clôturées tenues par le Cobra, deux miradors, une manche à air (sens du vent).
## Repères (reperes) prévus pour la mission 6 : parcelles, tours, manche à air, grenier, maisons.
class_name VillageBome
extends VillePortNere

var plan: Dictionary
var proche: VegetationProche
var vent := Vector2(-1, 0.3).normalized()   # le vent de l'après-midi souffle de l'est vers l'ouest


## Plan du village préparé AVANT la construction du terrain (terrasses à aplanir).
static func preparer_plan(c: Vector2) -> Dictionary:
	var d := Terrain.lire_donnees()
	var h := func(x: float, z: float) -> float: return Terrain.hauteur_brute(d, x, z)
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	var plateformes: Array = []
	var sites: Array = []
	var hc: float = h.call(c.x, c.y)
	plateformes.append({"centre": c, "rayon": 17.0, "h": hc})
	var grenier := c + Vector2(23, -8)
	plateformes.append({"centre": grenier, "rayon": 6.0, "h": hc + 0.4})
	for rayon in [36.0, 56.0, 76.0, 96.0, 116.0]:
		var depart := rng.randf() * TAU
		for k in 16:
			var a := depart + TAU * k / 16.0
			var p: Vector2 = c + Vector2(cos(a), sin(a)) * (rayon + rng.randf_range(-5, 5))
			var hp: float = h.call(p.x, p.y)
			var pente: float = (absf(h.call(p.x + 8, p.y) - h.call(p.x - 8, p.y)) + absf(h.call(p.x, p.y + 8) - h.call(p.x, p.y - 8))) / 16.0
			if pente > 0.55 or hp < 12.0 or hp > 150.0:
				continue
			var libre: bool = p.distance_to(grenier) > 18.0
			for s in sites:
				if p.distance_to(s["c"]) < 25.0:
					libre = false
			if libre and sites.size() < 13:
				sites.append({"c": p, "h": hp, "angle": atan2(c.x - p.x, c.y - p.y)})
				plateformes.append({"centre": p, "rayon": 10.5, "h": hp})
	return {"centre": c, "h": hc, "grenier": grenier, "sites": sites, "plateformes": plateformes}


func construire_bome(t: Terrain, p_plan: Dictionary, veg: Vegetation, p_proche: VegetationProche) -> void:
	terrain = t
	plan = p_plan
	proche = p_proche
	centre = plan["centre"]
	rng.seed = 2611
	_materiaux()
	mats["banco"] = _materiau("clay_plaster", 2.5, Color(0.95, 0.78, 0.64), 0.95, 0.0, true)
	mats["chaume"] = _materiau("thatch_roof_angled", 1.6, Color(0.95, 0.88, 0.78), 1.0, 0.0, true)
	mats["pierre"] = _materiau("red_mud_stones", 1.5, Color(0.85, 0.7, 0.6))
	mats["bois_brut"] = _materiau("weathered_brown_planks", 1.5, Color.WHITE, 0.9, 0.0, true)
	mats["laterite"] = _materiau("laterite", 4.0, Color(0.82, 0.7, 0.6), 1.0)
	corps = StaticBody3D.new()
	corps.name = "Collisions"
	add_child(corps)
	_place_centrale(veg)
	for s in plan["sites"]:
		_concession(s)
	_sentiers()
	_champs()
	_plantations_cobra()
	for r in rues:
		_ruban(r)
	_arbres_bome(veg)
	_finir_maillages()
	_poser_objets()
	print("Bomé : %d bâtiments, %d concessions" % [nb_batiments, plan["sites"].size()])


# ---------------------------------------------------------------------
func _toit_chaume_conique(base: Vector3, r: float, h: float) -> void:
	_cylindre("chaume", base, r, h, Color(rng.randf_range(0.85, 1.0), rng.randf_range(0.82, 0.95), rng.randf_range(0.75, 0.9)), 14, 0.08)
	# dessous du toit (visible depuis la porte)
	for i in 14:
		var a0 := TAU * i / 14.0
		var a1 := TAU * (i + 1) / 14.0
		_tri(_st("chaume", base), base + Vector3(cos(a0), 0, sin(a0)) * r, base + Vector3(0, h * 0.6, 0), base + Vector3(cos(a1), 0, sin(a1)) * r, Vector3.DOWN, Color(0.5, 0.45, 0.38))
	# petit chapeau de paille ficelée au sommet
	_cylindre("chaume", base + Vector3(0, h - 0.25, 0), 0.25, 0.55, Color(0.75, 0.68, 0.55), 8, 0.02)


func _case_ronde(p: Vector2, r: float, angle_porte: float, sol: float) -> void:
	var base := Vector3(p.x, sol, p.y)
	var teinte := Color(rng.randf_range(0.88, 1.0), rng.randf_range(0.8, 0.92), rng.randf_range(0.72, 0.85))
	_cylindre("pierre", base + Vector3(0, -0.4, 0), r + 0.12, 0.65, Color.WHITE, 16)
	_cylindre("banco", base, r, 2.3, teinte, 16)
	_toit_chaume_conique(base + Vector3(0, 2.2, 0), r + 0.75, r * 1.05 + 0.9)
	var xf := Transform3D(Basis(Vector3.UP, angle_porte), base + Vector3(sin(angle_porte), 0, cos(angle_porte)) * (r + 0.02))
	_boite("bois_brut", xf, Vector3(0.85, 1.85, 0.06), Color(0.75, 0.6, 0.45))
	_collision(Transform3D(Basis(), base), Vector3(r * 1.6, 2.4, r * 1.6))
	nb_batiments += 1


func _maison_banco(c: Vector2, avant: Vector2, w: float, d: float, sol: float) -> void:
	var xf := _repere(c, avant, sol)
	var teinte := Color(rng.randf_range(0.88, 1.0), rng.randf_range(0.78, 0.9), rng.randf_range(0.68, 0.82))
	_boite("pierre", xf.translated_local(Vector3(0, -0.4, 0)), Vector3(w + 0.2, 0.6, d + 0.2))
	_boite("banco", xf, Vector3(w, 2.5, d), teinte)
	_boite("banco", xf, Vector3(w + 0.02, 0.5, d + 0.02), teinte * Color(0.7, 0.6, 0.52))
	_boite("bois_brut", xf.translated_local(Vector3(rng.randf_range(-w * 0.2, w * 0.2), 0, -d * 0.5 - 0.03)), Vector3(0.9, 2.0, 0.06), Color(0.7, 0.55, 0.42))
	for s in [-1.0, 1.0]:
		_boite("bois", xf.translated_local(Vector3(s * w * 0.32, 1.0, -d * 0.5 - 0.035)), Vector3(0.7, 0.8, 0.05), VOLETS[rng.randi() % VOLETS.size()])
	var haut := xf.translated_local(Vector3(0, 2.5, 0))
	if rng.randf() < 0.65:
		# toit de chaume à quatre pans
		var p := func(x, y, z): return haut * Vector3(x, y, z)
		var hx := w * 0.5 + 0.7
		var hz := d * 0.5 + 0.7
		var hf := d * 0.55 + 0.6
		var f0: Vector3 = p.call(-w * 0.18, hf, 0.0)
		var f1: Vector3 = p.call(w * 0.18, hf, 0.0)
		var c00: Vector3 = p.call(-hx, -0.25, -hz)
		var c10: Vector3 = p.call(hx, -0.25, -hz)
		var c11: Vector3 = p.call(hx, -0.25, hz)
		var c01: Vector3 = p.call(-hx, -0.25, hz)
		var tc := Color(rng.randf_range(0.85, 1.0), rng.randf_range(0.82, 0.95), rng.randf_range(0.75, 0.9))
		_quad("chaume", c00, c10, f1, f0, tc)
		_quad("chaume", c01, f0, f1, c11, tc)
		_tri(_st("chaume", c00), c00, f0, c01, ((f0 - c00).cross(c01 - c00)).normalized() * -1.0, tc)
		_tri(_st("chaume", c10), c10, c11, f1, ((c11 - c10).cross(f1 - c10)).normalized() * -1.0, tc)
		_tri(_st("chaume", c10), c10, f1, c11, Vector3.DOWN, tc * 0.5)
		_tri(_st("chaume", c00), c00, c01, f0, Vector3.DOWN, tc * 0.5)
	else:
		_toit_tole(haut, w, d, rng.randf() < 0.5, Color.WHITE, teinte, "banco")
	_collision(xf, Vector3(w, 2.6, d))
	nb_batiments += 1


func _grenier_pilotis(p: Vector2, r: float, sol: float) -> void:
	var base := Vector3(p.x, sol, p.y)
	for k in 4:
		var a := k * PI * 0.5 + PI * 0.25
		_cylindre("pierre", base + Vector3(cos(a), 0, sin(a)) * r * 0.6, 0.18, 0.7, Color.WHITE, 6)
	_cylindre("banco", base + Vector3(0, 0.7, 0), r, 1.6, Color(0.9, 0.75, 0.6), 14, r * 0.92)
	_toit_chaume_conique(base + Vector3(0, 2.2, 0), r + 0.45, r + 0.9)
	_collision(Transform3D(Basis(), base), Vector3(r * 1.8, 3.0, r * 1.8))
	nb_batiments += 1


func _foyer(p: Vector2, sol: float) -> void:
	# trois pierres, marmite noire, tas de bois
	for k in 3:
		var a := k * TAU / 3.0
		_cylindre("pierre", Vector3(p.x, sol, p.y) + Vector3(cos(a), 0, sin(a)) * 0.28, 0.13, 0.22, Color(0.6, 0.55, 0.5), 6, 0.09)
	_cylindre("sombre", Vector3(p.x, sol + 0.2, p.y), 0.24, 0.3, Color.WHITE, 12, 0.2)
	for k in 6:
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, PI * 0.5), Vector3(p.x + 1.2, sol + 0.06 + (k % 3) * 0.09, p.y + 0.6))
		_cylindre("bois_brut", xf.origin - xf.basis.y * 0.6, 0.045, 1.2, Color(0.6, 0.5, 0.4), 5)


func _concession(s: Dictionary) -> void:
	var c: Vector2 = s["c"]
	var sol: float = s["h"]
	var vers_place := Vector2(sin(s["angle"]), cos(s["angle"]))
	var lat := Vector2(-vers_place.y, vers_place.x)
	# maison principale face à la place, une ou deux cases rondes, un grenier, le foyer
	_maison_banco(c - vers_place * 2.5, vers_place, rng.randf_range(6.5, 8.5), rng.randf_range(4.5, 5.5), sol)
	_case_ronde(c + lat * 6.0 + vers_place * 2.0, rng.randf_range(2.1, 2.6), atan2(vers_place.x, vers_place.y), sol)
	if rng.randf() < 0.6:
		_case_ronde(c - lat * 6.2 + vers_place * 1.5, rng.randf_range(2.0, 2.4), atan2(vers_place.x, vers_place.y), sol)
	if rng.randf() < 0.7:
		_grenier_pilotis(c - lat * 5.5 - vers_place * 6.5, rng.randf_range(1.0, 1.3), sol)
	_foyer(c + vers_place * 5.0 - lat * 1.5, sol)
	arbres.append(c + lat * rng.randf_range(-9.0, 9.0) - vers_place * rng.randf_range(11.0, 14.0))
	_prendre(c, vers_place, 20.0, 18.0, 0.0)
	if not reperes.has("maisons"):
		reperes["maisons"] = []
	reperes["maisons"].append(Vector3(c.x, sol, c.y))


func _place_centrale(veg: Vegetation) -> void:
	var c: Vector2 = plan["centre"]
	var h: float = plan["h"]
	reperes["place"] = Vector3(c.x, h, c.y)
	# arbre à palabres (grand arbre 3D de près, photographié de loin)
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/arbres/arbres.json"))
	var xa := Transform3D(Basis(Vector3.UP, 0.7).scaled(Vector3(0.95, 0.85, 0.95)), Vector3(c.x, h - 0.2, c.y))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = veg._maillage_imposteur(meta["jacaranda_tree"])
	mm.instance_count = 1
	mm.set_instance_transform(0, xa)
	mm.set_instance_color(0, Color(0.85, 0.95, 0.85))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)
	if proche:
		proche.ajouter_arbre("jacaranda_tree", xa, Color(0.85, 0.95, 0.85))
	_collision(Transform3D(Basis(), Vector3(c.x, h, c.y)), Vector3(1.6, 6.0, 1.6))
	# bancs en troncs couchés autour de l'arbre
	for k in 6:
		var a := TAU * k / 6.0 + 0.3
		var p := c + Vector2(cos(a), sin(a)) * 7.0
		var dir := Vector3(-sin(a), 0, cos(a))
		var o := Vector3(p.x, h + 0.25, p.y)
		var xf := Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.z)), o)
		_boite("bois_brut", xf, Vector3(0.42, 0.42, 2.8), Color(0.62, 0.52, 0.42))
		_boite("bois_brut", xf.translated_local(Vector3(0, -0.3, -0.9)), Vector3(0.3, 0.3, 0.3), Color(0.5, 0.42, 0.34))
		_boite("bois_brut", xf.translated_local(Vector3(0, -0.3, 0.9)), Vector3(0.3, 0.3, 0.3), Color(0.5, 0.42, 0.34))
		var d2: Array = reperes.get("bancs", [])
		d2.append([Vector3(p.x, h, p.y), a])
		reperes["bancs"] = d2
	_prendre(c, Vector2(0, 1), 22.0, 22.0, 0.0)
	# grenier à semences de la coopérative
	var g: Vector2 = plan["grenier"]
	var gh: float = h + 0.4
	var base := Vector3(g.x, gh, g.y)
	for k in 6:
		var a := TAU * k / 6.0
		_cylindre("pierre", base + Vector3(cos(a), 0, sin(a)) * 1.6, 0.25, 0.9, Color.WHITE, 6)
	_cylindre("banco", base + Vector3(0, 0.9, 0), 2.4, 2.6, Color(0.92, 0.76, 0.6), 18, 2.25)
	_boite("bois_brut", Transform3D(Basis(Vector3.UP, atan2(c.x - g.x, c.y - g.y)), base + Vector3(0, 1.4, 0) + Vector3(c.x - g.x, 0, c.y - g.y).normalized() * 2.32), Vector3(0.8, 1.2, 0.06), Color(0.55, 0.4, 0.3))
	_toit_chaume_conique(base + Vector3(0, 3.4, 0), 3.2, 2.8)
	_collision(Transform3D(Basis(), base), Vector3(4.6, 4.0, 4.6))
	reperes["grenier"] = base
	nb_batiments += 1


func _sentiers() -> void:
	var c: Vector2 = plan["centre"]
	for s in plan["sites"]:
		var p: Vector2 = s["c"]
		var pts := _onduler(_droite(c + (p - c).normalized() * 12.0, p - (p - c).normalized() * 7.0, 6.0), 1.5, p.x)
		if pts.size() >= 3:
			rues.append({"pts": pts, "l": 1.7, "type": "laterite"})


# ---------------------------------------------------------------------
# Champs
# ---------------------------------------------------------------------
func _plante_manioc() -> ArrayMesh:
	# tiges fines et bouquets de feuilles palmées au sommet
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sf := SurfaceTool.new()
	sf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := RandomNumberGenerator.new()
	r.seed = 11
	for tige in 3:
		var pied := Vector3(r.randf_range(-0.08, 0.08), 0, r.randf_range(-0.08, 0.08))
		var haut := pied + Vector3(r.randf_range(-0.25, 0.25), r.randf_range(1.2, 1.6), r.randf_range(-0.25, 0.25))
		var a := (haut - pied).cross(Vector3.FORWARD).normalized() * 0.015
		for q in [[pied - a, pied + a, haut + a * 0.5, haut - a * 0.5]]:
			for j in [0, 1, 2, 0, 2, 3]:
				st.set_normal(Vector3.UP)
				st.set_color(Color(0.55, 0.45, 0.35, 0.1))
				st.set_uv(Vector2(0.5, 0.5))
				st.add_vertex(q[j])
		for k in 5:
			var dir := Vector3(cos(k * 1.26 + tige), r.randf_range(-0.1, 0.5), sin(k * 1.26 + tige)).normalized()
			var cote := dir.cross(Vector3.UP).normalized()
			var l := 0.45
			var b := haut - Vector3(0, k * 0.08, 0)
			var coins := [b - cote * 0.18, b + cote * 0.18, b + cote * 0.18 + dir * l, b - cote * 0.18 + dir * l]
			var uvs := [Vector2(0.13, 1), Vector2(0.37, 1), Vector2(0.37, 0), Vector2(0.13, 0)]
			for j in [0, 1, 2, 0, 2, 3]:
				sf.set_normal((Vector3.UP + dir).normalized())
				sf.set_color(Color(0.85, 1.0, 0.8, 0.8))
				sf.set_uv(uvs[j])
				sf.add_vertex(coins[j])
	var m := st.commit()
	m.surface_set_material(0, mats["bois_brut"])
	sf.commit(m)
	m.surface_set_material(1, _feuillage_toujours_visible("rameau_clair"))
	return m


func _feuillage_toujours_visible(nom: String) -> ShaderMaterial:
	var f := ShaderMaterial.new()
	f.shader = load("res://shaders/feuillage.gdshader")
	f.set_shader_parameter("image", load("res://data/vegetation/%s.png" % nom))
	f.set_shader_parameter("rayon_proche", 0.0)
	f.set_shader_parameter("vent", 0.6)
	return f


func _plante_mais() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 3:
		var a := k * PI / 3.0
		var d := Vector3(cos(a), 0, sin(a)) * 0.32
		var coins := [-d, d, d + Vector3(0, 2.1, 0), -d + Vector3(0, 2.1, 0)]
		var uvs := [Vector2(0.06, 1), Vector2(0.44, 1), Vector2(0.44, 0), Vector2(0.06, 0)]
		for j in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP)
			st.set_color(Color(0.95, 1.05, 0.8))
			st.set_uv(uvs[j])
			st.add_vertex(coins[j])
	var m := st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/herbe.gdshader")
	mat.set_shader_parameter("image", load("res://data/vegetation/herbes.png"))
	mat.set_shader_parameter("distance_max", 400.0)
	m.surface_set_material(0, mat)
	return m


func _semer(mesh: Mesh, c: Vector2, ang: float, long: float, larg: float, pas_rang: float, pas_plant: float, echelle: Vector2, nom: String) -> void:
	var dir := Vector2(cos(ang), sin(ang))
	var n := Vector2(-dir.y, dir.x)
	var liste: Array = []
	var x := -long * 0.5
	while x < long * 0.5:
		var y := -larg * 0.5
		while y < larg * 0.5:
			var p := c + dir * (x + rng.randf_range(-0.15, 0.15)) + n * (y + rng.randf_range(-0.15, 0.15))
			var h := _sol(p)
			if h > 3.0 and terrain.pente(p.x, p.y) < 0.7 and not bati.has(_cle(p)):
				var s := rng.randf_range(echelle.x, echelle.y)
				liste.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(p.x, h - 0.05, p.y)))
			y += pas_plant
		x += pas_rang
	if liste.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = liste.size()
	var origine := Vector3(c.x, 0, c.y)
	for i in liste.size():
		mm.set_instance_transform(i, (liste[i] as Transform3D).translated(-origine))
		mm.set_instance_color(i, Color(rng.randf_range(0.85, 1.05), rng.randf_range(0.9, 1.05), rng.randf_range(0.85, 1.0)))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = nom
	mmi.multimesh = mm
	mmi.position = origine
	mmi.visibility_range_end = 450.0
	add_child(mmi)


func _champs() -> void:
	var c: Vector2 = plan["centre"]
	var manioc := _plante_manioc()
	var mais := _plante_mais()
	var cacao: ArrayMesh = (proche.modeles["island_tree_02"][1] as ArrayMesh).duplicate() if proche else null
	if cacao:
		for k in cacao.get_surface_count():
			var m: ShaderMaterial = (cacao.surface_get_material(k) as ShaderMaterial).duplicate()
			m.set_shader_parameter("rayon_proche", 0.0)
			cacao.surface_set_material(k, m)
	var champs: Array = []
	var k := 0
	for essai in 72:
		if k >= 9:
			break
		var a := TAU * essai / 36.0 + 0.2
		var p := c + Vector2(cos(a), sin(a)) * (135.0 + 40.0 * float(essai / 36))
		if _sol(p) < 8.0 or terrain.pente(p.x, p.y) > 0.45:
			continue
		var loin := true
		for q in champs:
			if p.distance_to(q) < 46.0:
				loin = false
		if not loin:
			continue
		var ang := a + PI * 0.5 + rng.randf_range(-0.2, 0.2)
		var sorte: String = ["manioc", "manioc", "mais", "cacao"][k % 4]
		k += 1
		if sorte == "manioc":
			_semer(manioc, p, ang, 34.0, 22.0, 1.3, 1.1, Vector2(0.8, 1.15), "Manioc")
		elif sorte == "mais":
			_semer(mais, p, ang, 30.0, 20.0, 0.9, 0.7, Vector2(0.8, 1.1), "Mais")
		elif cacao:
			_semer(cacao, p, ang, 36.0, 26.0, 4.5, 4.5, Vector2(1.0, 1.3), "Cacaoyers")
		champs.append(p)
		_prendre(p, Vector2(cos(ang), sin(ang)).orthogonal(), 36.0, 26.0, 2.0)
		# haie d'arbres en lisière du champ
		for j in 3:
			arbres.append(p + Vector2(cos(ang), sin(ang)) * rng.randf_range(-16, 16) + Vector2(cos(ang), sin(ang)).orthogonal() * (15.0 + rng.randf() * 3.0))
	reperes["champs"] = champs


func _plantations_cobra() -> void:
	# trois parcelles illicites plus haut sur la colline, clôturées, surveillées
	var c: Vector2 = plan["centre"]
	var buisson: ArrayMesh = (proche.m_buissons[1] as ArrayMesh).duplicate() if proche else _plante_manioc()
	var m: ShaderMaterial = (buisson.surface_get_material(0) as ShaderMaterial).duplicate()
	m.set_shader_parameter("rayon_proche", 0.0)
	buisson.surface_set_material(0, m)
	var parcelles: Array = []
	var meilleure := Vector2.ZERO
	var hmax := -INF
	for k in 24:  # côté le plus haut de la colline (vers le Mont Talanké)
		var a := TAU * k / 24.0
		var p := c + Vector2(cos(a), sin(a)) * 220.0
		if _sol(p) > hmax and terrain.pente(p.x, p.y) < 0.6:
			hmax = _sol(p)
			meilleure = (p - c).normalized()
	for i in 3:
		var a := atan2(meilleure.y, meilleure.x) + (i - 1) * 0.42
		var p := c + Vector2(cos(a), sin(a)) * (215.0 + i * 12.0)
		var ang := a + PI * 0.5
		_semer(buisson, p, ang, 40.0, 26.0, 1.6, 1.4, Vector2(0.9, 1.3), "ParcelleCobra")
		_cloture(p, ang, 42.0, 28.0)
		parcelles.append(Vector3(p.x, _sol(p), p.y))
	reperes["parcelles"] = parcelles
	# miradors entre les parcelles et le village, manche à air
	var tours: Array = []
	for i in 2:
		var a := atan2(meilleure.y, meilleure.x) + (i - 0.5) * 0.6
		var p := c + Vector2(cos(a), sin(a)) * 185.0
		_mirador(p)
		tours.append(Vector3(p.x, _sol(p), p.y))
	reperes["tours"] = tours
	var pm := c + meilleure * 170.0 + Vector2(-meilleure.y, meilleure.x) * 30.0
	_manche_a_air(pm)
	reperes["manche_a_air"] = Vector3(pm.x, _sol(pm), pm.y)
	reperes["vent"] = vent


func _cloture(c: Vector2, ang: float, long: float, larg: float) -> void:
	var dir := Vector2(cos(ang), sin(ang))
	var n := Vector2(-dir.y, dir.x)
	var coins := [c - dir * long * 0.5 - n * larg * 0.5, c + dir * long * 0.5 - n * larg * 0.5, c + dir * long * 0.5 + n * larg * 0.5, c - dir * long * 0.5 + n * larg * 0.5]
	for i in 4:
		var a: Vector2 = coins[i]
		var b: Vector2 = coins[(i + 1) % 4]
		var nb := int(a.distance_to(b) / 3.0)
		var prec := Vector3.INF
		for k in nb + 1:
			var p := a.lerp(b, float(k) / nb)
			var base := Vector3(p.x, _sol(p) - 0.2, p.y)
			_cylindre("bois_brut", base, 0.06, 1.7, Color(0.6, 0.5, 0.4), 5)
			if prec != Vector3.INF:
				for hfil in [0.7, 1.3]:
					var u := prec + Vector3(0, hfil, 0)
					var v := base + Vector3(0, hfil, 0)
					var mid := (u + v) * 0.5
					var d := v - u
					var xf := Transform3D(Basis.looking_at(d.normalized(), Vector3.UP), mid)
					_boite("sombre", xf.translated_local(Vector3(0, -0.01, 0)), Vector3(0.02, 0.02, d.length()))
			prec = base


func _mirador(p: Vector2) -> void:
	var h := _sol(p)
	var base := Vector3(p.x, h - 0.2, p.y)
	for k in 4:
		var a := k * PI * 0.5 + PI * 0.25
		_cylindre("bois_brut", base + Vector3(cos(a), 0, sin(a)) * 1.3, 0.1, 5.4, Color(0.6, 0.5, 0.4), 6, 0.08)
	var plat := Transform3D(Basis(), base + Vector3(0, 5.0, 0))
	_boite("bois", plat, Vector3(2.4, 0.15, 2.4), Color(0.6, 0.5, 0.4))
	for s in [-1.0, 1.0]:
		_boite("bois", plat.translated_local(Vector3(0, 0.15, s * 1.15)), Vector3(2.4, 1.0, 0.08), Color(0.55, 0.45, 0.35))
		_boite("bois", plat.translated_local(Vector3(s * 1.15, 0.15, 0)), Vector3(0.08, 1.0, 2.4), Color(0.55, 0.45, 0.35))
	_toit_tole(plat.translated_local(Vector3(0, 2.3, 0)), 2.4, 2.4, true, Color.WHITE, Color(0.6, 0.5, 0.4), "bois_brut")
	for k in 9: # échelle
		_boite("bois", Transform3D(Basis(), base + Vector3(0, 0.5 + k * 0.55, 1.45)), Vector3(0.7, 0.06, 0.06), Color(0.55, 0.45, 0.35))
	_cylindre("metal", base + Vector3(1.2, 5.0, 1.2), 0.04, 3.4, Color(0.5, 0.5, 0.5), 6)
	_drapeau(base + Vector3(1.2, 7.9, 1.2), "drapeau_cobra")
	_collision(Transform3D(Basis(), base), Vector3(2.8, 6.0, 2.8))


func _manche_a_air(p: Vector2) -> void:
	var h := _sol(p)
	var base := Vector3(p.x, h, p.y)
	_cylindre("metal", base, 0.06, 6.0, Color(0.85, 0.85, 0.85), 6)
	# cône rayé orange et blanc, gonflé dans le sens du vent
	var dir := Vector3(vent.x, -0.08, vent.y).normalized()
	var axe := Basis.looking_at(dir, Vector3.UP)
	for k in 4:
		var o := base + Vector3(0, 5.9, 0) + dir * (0.3 + k * 0.42)
		var col := Color(0.95, 0.4, 0.05) if k % 2 == 0 else Color(0.95, 0.95, 0.92)
		var r0 := 0.32 - k * 0.05
		for i in 10:
			var a0 := TAU * i / 10.0
			var a1 := TAU * (i + 1) / 10.0
			var v0 := axe * Vector3(cos(a0), sin(a0), 0)
			var v1 := axe * Vector3(cos(a1), sin(a1), 0)
			_quad("metal", o + v0 * r0, o + v1 * r0, o + dir * 0.42 + v1 * (r0 - 0.05), o + dir * 0.42 + v0 * (r0 - 0.05), col, ((v0 + v1) * 0.5).normalized())


func _arbres_bome(veg: Vegetation) -> void:
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/arbres/arbres.json"))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = veg._maillage_imposteur(meta["island_tree_01"])
	var liste: Array = []
	for c in arbres:
		var q: Vector2 = c
		if bati.has(_cle(q)) or _sol(q) < 3.0:
			continue
		var s := rng.randf_range(1.5, 2.3)
		var xa := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(q.x, _sol(q) - 0.2, q.y))
		var ca := Color(rng.randf_range(0.8, 0.95), rng.randf_range(0.9, 1.0), rng.randf_range(0.8, 0.95))
		liste.append([xa, ca])
		if proche:
			proche.ajouter_arbre("island_tree_01", xa, ca)
	mm.instance_count = liste.size()
	for i in liste.size():
		mm.set_instance_transform(i, liste[i][0])
		mm.set_instance_color(i, liste[i][1])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "ArbresBome"
	mmi.multimesh = mm
	add_child(mmi)

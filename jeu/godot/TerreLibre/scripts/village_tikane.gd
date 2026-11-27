## Tikané, village isolé de la côte est de Talanké, occupé par le Front du Cobra (mission 8 « Nuit à Tikané »).
## - replat au-dessus d'une petite crique ; une rivière descend de la forêt, traverse le replat,
##   tombe en cascade et se jette dans la crique, où Ama attendra avec les pirogues ;
## - concessions en banco et cases rondes, place avec le mât du Cobra ;
## - maison du chef devenue prison (fenêtres condamnées, porte cadenassée), case de santé à l'entrée ;
## - barrage de sacs de sable et pick-up sur la piste de la forêt, braseros des gardes.
## Repères pour la mission 8 : prison, case_sante, gardes (7 postes d'adultes), recrues (6 postes, à
## désarmer seulement), barrage, piste, embarcadere, chemin_fuite.
class_name VillageTikane
extends VillageBome

## Cours de la rivière, relatif au point de Tikané sur la carte (de l'amont vers la mer).
const RIVIERE := [Vector2(140, 240), Vector2(135, 150), Vector2(132, 80), Vector2(138, 10), Vector2(148, -60),
	Vector2(150, -110), Vector2(144, -150), Vector2(139, -172)]

var feux: Array = []   # [lumière, énergie de base, phase]


static func preparer_plan(m: Vector2) -> Dictionary:
	var d := Terrain.lire_donnees()
	var h := func(x: float, z: float) -> float: return Terrain.hauteur_brute(d, x, z)
	var alea := RandomNumberGenerator.new()
	alea.seed = 8
	# rivière : niveau d'eau qui ne remonte jamais vers l'aval
	var pts := PackedVector2Array()
	var niv := PackedFloat32Array()
	var prec := INF
	for r in RIVIERE:
		var p: Vector2 = m + r
		var n: float = minf(h.call(p.x, p.y) - 0.8, prec - 0.3)
		pts.append(p)
		niv.append(n)
		prec = n
	niv[niv.size() - 1] = minf(niv[niv.size() - 1], -0.3)
	niv[niv.size() - 2] = minf(niv[niv.size() - 2], 0.2)
	var c := m + Vector2(90, -55)
	var hc: float = h.call(c.x, c.y)
	var prison := c + Vector2(0, 19)
	var sante := c + Vector2(-50, -8)
	var piste := PackedVector2Array([c + Vector2(-12, 4), c + Vector2(-45, 12), c + Vector2(-80, 26), c + Vector2(-115, 48), c + Vector2(-150, 72), c + Vector2(-185, 92)])
	var plateformes: Array = [
		{"centre": c, "rayon": 15.0, "h": hc},
		{"centre": prison, "rayon": 11.0, "h": hc + 0.3},
		{"centre": sante, "rayon": 7.0, "h": h.call(sante.x, sante.y)},
	]
	var dist_seg := func(q: Vector2, ligne: PackedVector2Array) -> float:
		var best := INF
		for i in ligne.size() - 1:
			var ab := ligne[i + 1] - ligne[i]
			var t := clampf((q - ligne[i]).dot(ab) / ab.length_squared(), 0.0, 1.0)
			best = minf(best, q.distance_to(ligne[i] + ab * t))
		return best
	var sites: Array = []
	for rayon in [32.0, 50.0, 68.0, 86.0]:
		var depart := alea.randf() * TAU
		for k in 14:
			var a := depart + TAU * k / 14.0
			var p: Vector2 = c + Vector2(cos(a), sin(a)) * (rayon + alea.randf_range(-4, 4))
			var hp: float = h.call(p.x, p.y)
			var pente: float = (absf(h.call(p.x + 8, p.y) - h.call(p.x - 8, p.y)) + absf(h.call(p.x, p.y + 8) - h.call(p.x, p.y - 8))) / 16.0
			if pente > 0.5 or hp < 5.0 or hp > 45.0:
				continue
			if dist_seg.call(p, pts) < 20.0 or dist_seg.call(p, piste) < 12.0:
				continue
			if p.distance_to(prison) < 20.0 or p.distance_to(sante) < 16.0:
				continue
			var libre := true
			for s in sites:
				if p.distance_to(s["c"]) < 23.0:
					libre = false
			if libre and sites.size() < 11:
				sites.append({"c": p, "h": hp, "angle": atan2(c.x - p.x, c.y - p.y)})
				plateformes.append({"centre": p, "rayon": 10.0, "h": hp})
	return {"centre": c, "h": hc, "prison": prison, "sante": sante, "piste": piste, "sites": sites,
		"plateformes": plateformes, "lit": {"pts": pts, "niveaux": niv, "largeur": 12.0}}


func construire_tikane(t: Terrain, p_plan: Dictionary, veg: Vegetation, p_proche: VegetationProche) -> void:
	terrain = t
	plan = p_plan
	proche = p_proche
	centre = plan["centre"]
	rng.seed = 808
	_preparer_village()
	var c: Vector2 = centre
	reperes["place"] = Vector3(c.x, plan["h"], c.y)
	_prendre(c, Vector2(0, 1), 26.0, 26.0, 0.0)
	var braise := StandardMaterial3D.new()
	braise.albedo_color = Color(0.2, 0.08, 0.02)
	braise.emission_enabled = true
	braise.emission = Color(1.0, 0.42, 0.1)
	braise.emission_energy_multiplier = 2.0
	mats["braise"] = braise
	_mat_cobra(c)
	_prison(plan["prison"])
	_case_sante(plan["sante"])
	for s in plan["sites"]:
		_concession(s)
	_piste()
	_riviere()
	_embarcadere()
	_occupation()
	_sentiers()
	for r in rues:
		_ruban(r)
	_palmiers(veg)
	_arbres_bome(veg)
	_finir_maillages()
	_poser_objets()
	print("Tikané : %d bâtiments, %d concessions" % [nb_batiments, plan["sites"].size()])


func _process(_delta: float) -> void:
	# flammes des braseros : la lumière vacille
	var tps := Time.get_ticks_msec() * 0.001
	for f in feux:
		var l: OmniLight3D = f[0]
		if l.visible:
			l.light_energy = f[1] * (0.82 + 0.12 * sin(tps * 11.0 + f[2]) + 0.06 * sin(tps * 23.0 + f[2] * 2.0))


func regler_nuit(n: float) -> void:
	for f in feux:
		(f[0] as OmniLight3D).visible = n > 0.05
		f[1] = f[3] * (0.25 + 0.75 * n)
	if mats.has("braise"):
		(mats["braise"] as StandardMaterial3D).emission_energy_multiplier = 1.5 + 4.0 * n


# ---------------------------------------------------------------------
# Bâtiments
# ---------------------------------------------------------------------
func _prison(p: Vector2) -> void:
	# grande maison du chef en banco, véranda à piliers, toit de tôle ; fenêtres clouées de planches,
	# porte cadenassée : les familles y sont enfermées
	var c: Vector2 = centre
	var avant := (c - p).normalized()
	var sol: float = plan["h"] + 0.3
	var w := 13.0
	var dp := 8.0
	var xf := _repere(p, avant, sol)
	_boite("pierre", xf.translated_local(Vector3(0, -0.4, 0)), Vector3(w + 0.4, 0.7, dp + 3.2))
	_boite("banco", xf, Vector3(w, 3.0, dp), Color(0.96, 0.84, 0.7))
	_boite("banco", xf, Vector3(w + 0.02, 0.55, dp + 0.02), Color(0.62, 0.5, 0.4))
	# véranda : dalle, piliers, toit prolongé
	var v := xf.translated_local(Vector3(0, 0, -dp * 0.5 - 1.4))
	_boite("beton", v.translated_local(Vector3(0, -0.05, 0)), Vector3(w, 0.18, 2.8), Color(0.8, 0.76, 0.7))
	for k in 5:
		_boite("bois_brut", v.translated_local(Vector3(-w * 0.5 + 0.4 + k * (w - 0.8) / 4.0, 0, -1.2)), Vector3(0.22, 2.9, 0.22), Color(0.6, 0.5, 0.4))
	_toit_tole(xf.translated_local(Vector3(0, 3.0, -1.4)), w + 0.6, dp + 3.6, false, Color.WHITE, Color(0.9, 0.78, 0.65), "banco")
	# porte à deux battants, barre de fer et cadenas
	var porte := xf.translated_local(Vector3(0, 0, -dp * 0.5 - 0.04))
	reperes["porte_xf"] = porte
	_boite("bois", porte, Vector3(1.6, 2.2, 0.07), Color(0.42, 0.3, 0.2))
	_boite("metal", porte.translated_local(Vector3(0, 1.1, -0.06)), Vector3(1.9, 0.09, 0.05), Color(0.35, 0.33, 0.3))
	_boite("metal", porte.translated_local(Vector3(0.25, 0.95, -0.09)), Vector3(0.09, 0.12, 0.05), Color(0.55, 0.5, 0.3))
	# fenêtres condamnées par des planches clouées en travers
	for s in [-1.0, 1.0]:
		for cote in [0, 1]:
			var f: Transform3D
			if cote == 0:
				f = xf.translated_local(Vector3(s * w * 0.3, 1.5, -dp * 0.5 - 0.05))
			else:
				f = Transform3D(xf.basis * Basis(Vector3.UP, s * PI * 0.5), xf * Vector3(s * (w * 0.5 + 0.05), 1.5, 0))
			_boite("sombre", f, Vector3(1.1, 0.9, 0.04))
			for k in 3:
				_boite("bois_brut", Transform3D(f.basis * Basis(Vector3.BACK, rng.randf_range(-0.2, 0.2)), f * Vector3(0, -0.3 + k * 0.3, -0.04)), Vector3(1.35, 0.16, 0.04), Color(0.72, 0.6, 0.45))
	_collision(xf, Vector3(w, 3.2, dp))
	nb_batiments += 1
	reperes["prison"] = Vector3(p.x, sol, p.y)
	reperes["porte_prison"] = xf * Vector3(0, 0, -dp * 0.5 - 2.2)
	_prendre(p, avant, w + 4.0, dp + 6.0, 0.5)
	# deux lanternes sous la véranda
	for s in [-1.0, 1.0]:
		_lanterne(v * Vector3(s * 2.2, 2.5, -0.9))


func _case_sante(p: Vector2) -> void:
	# petite maison de soins au toit de tôle, auvent, enseigne peinte à la main
	var avant := (centre - p).normalized()
	var sol := _sol(p)
	var xf := _repere(p, avant, sol)
	_boite("pierre", xf.translated_local(Vector3(0, -0.4, 0)), Vector3(6.4, 0.6, 4.6))
	_boite("mur", xf, Vector3(6.0, 2.6, 4.2), Color(0.92, 0.94, 0.9))
	_boite("mur", xf, Vector3(6.02, 0.6, 4.22), Color(0.3, 0.55, 0.5))
	_boite("bois", xf.translated_local(Vector3(-1.2, 0, -2.13)), Vector3(0.9, 2.0, 0.06), Color(0.25, 0.45, 0.42))
	_boite("vitre", xf.translated_local(Vector3(1.4, 1.2, -2.13)), Vector3(1.0, 0.8, 0.04))
	_toit_tole(xf.translated_local(Vector3(0, 2.6, 0)), 6.6, 4.8, true, Color.WHITE, Color(0.92, 0.94, 0.9), "mur")
	var e := Label3D.new()
	e.text = "CASE DE SANTÉ\nDE TIKANÉ"
	e.font_size = 52
	e.pixel_size = 0.006
	e.modulate = Color(0.15, 0.32, 0.3)
	e.outline_size = 0
	e.double_sided = false
	e.transform = Transform3D(xf.basis * Basis(Vector3.UP, PI), xf * Vector3(0.5, 2.25, -2.16))
	add_child(e)
	_collision(xf, Vector3(6.0, 2.8, 4.2))
	nb_batiments += 1
	reperes["case_sante"] = Vector3(p.x, sol, p.y)
	_prendre(p, avant, 9.0, 7.0, 0.5)


func _mat_cobra(c: Vector2) -> void:
	var base := Vector3(c.x + 5.0, plan["h"], c.y - 4.0)
	_cylindre("metal", base, 0.07, 7.5, Color(0.6, 0.6, 0.6), 8)
	_cylindre("pierre", base, 0.6, 0.5, Color.WHITE, 10)
	_drapeau(base + Vector3(0, 6.8, 0), "drapeau_cobra")
	reperes["mat"] = base


func _lanterne(p: Vector3) -> void:
	_cylindre("metal", p, 0.09, 0.28, Color(0.2, 0.2, 0.2), 8)
	_cylindre("braise", p + Vector3(0, 0.05, 0), 0.06, 0.16, Color.WHITE, 8)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.62, 0.3)
	l.omni_range = 9.0
	l.position = p + Vector3(0, 0.1, 0)
	l.shadow_enabled = false
	add_child(l)
	feux.append([l, 1.2, rng.randf() * TAU, 1.2])


func _brasero(p: Vector2) -> void:
	var sol := _sol(p)
	var b := Vector3(p.x, sol, p.y)
	_cylindre("tole", b, 0.3, 0.75, Color(0.45, 0.25, 0.15), 12)
	_cylindre("braise", b + Vector3(0, 0.72, 0), 0.26, 0.1, Color.WHITE, 12, 0.18)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.55, 0.22)
	l.omni_range = 14.0
	l.position = b + Vector3(0, 1.4, 0)
	l.shadow_enabled = true
	add_child(l)
	feux.append([l, 2.2, rng.randf() * TAU, 2.2])


# ---------------------------------------------------------------------
# Occupation : barrage, pick-up, postes de garde
# ---------------------------------------------------------------------
func _occupation() -> void:
	var piste: PackedVector2Array = plan["piste"]
	# barrage sur la piste, à la lisière de la forêt
	var pb := piste[2]
	var tb := (piste[3] - piste[2]).normalized()
	_barrage(pb, tb, 2.4)
	reperes["barrage"] = Vector3(pb.x, _sol(pb), pb.y)
	_brasero(pb + tb.orthogonal() * 5.5 - tb * 2.0)
	# pick-up garé juste derrière le barrage, côté village
	var pp := piste[1] + tb.orthogonal() * 6.0
	var pick: Node3D = (load("res://vehicules/pickup.glb") as PackedScene).instantiate()
	add_child(pick)
	pick.global_transform = Transform3D(Basis(Vector3.UP, atan2(-tb.x, -tb.y) + 0.5), Vector3(pp.x, _sol(pp) + 0.05, pp.y))
	_peindre_vehicule(pick, Color(0.28, 0.31, 0.2))
	_collision(Transform3D(pick.global_transform.basis, pick.global_position), Vector3(2.0, 1.8, 5.0))
	reperes["pickup"] = pick.global_position
	# braseros : place, prison, rivière
	var c: Vector2 = centre
	_brasero(c + Vector2(-6, 5))
	var pr: Vector2 = plan["prison"]
	_brasero(pr + (c - pr).normalized() * 9.0 + (c - pr).normalized().orthogonal() * 7.5)
	# postes des gardes adultes (7) et des jeunes recrues (6 : à désarmer, jamais à combattre)
	var porte: Vector3 = reperes["porte_prison"]
	var gardes: Array = [
		porte + Vector3(1.6, 0, 0), porte + Vector3(-1.6, 0, 0),
		Vector3(pb.x, 0, pb.y) + Vector3(tb.orthogonal().x, 0, tb.orthogonal().y) * 3.5,
		Vector3(pb.x, 0, pb.y) - Vector3(tb.orthogonal().x, 0, tb.orthogonal().y) * 3.5,
		Vector3(c.x + 8, 0, c.y - 6),
		Vector3(c.x + 40, 0, c.y - 12),
		Vector3(c.x - 20, 0, c.y - 30),
	]
	var recrues: Array = [Vector3(c.x - 8, 0, c.y + 8), Vector3(c.x + 12, 0, c.y + 4), Vector3(pr.x - 9, 0, pr.y - 2),
		Vector3(pr.x + 9, 0, pr.y - 2), Vector3(pp.x + 2, 0, pp.y + 2), Vector3(c.x + 30, 0, c.y + 20)]
	for liste in [gardes, recrues]:
		for i in liste.size():
			var q: Vector3 = liste[i]
			q.y = _sol(Vector2(q.x, q.z))
			liste[i] = q
	reperes["gardes"] = gardes
	reperes["recrues"] = recrues
	reperes["piste"] = piste


func _peindre_vehicule(noeud: Node3D, couleur: Color) -> void:
	for mi in noeud.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for k in m.mesh.get_surface_count():
			var mat := m.mesh.surface_get_material(k)
			if mat and mat.resource_name == "Carrosserie":
				var m2: StandardMaterial3D = (mat as StandardMaterial3D).duplicate()
				m2.albedo_color = couleur
				m.set_surface_override_material(k, m2)


func _piste() -> void:
	var piste: PackedVector2Array = plan["piste"]
	rues.append({"pts": piste, "l": 4.2, "type": "laterite"})
	for i in piste.size() - 1:
		var a := piste[i]
		var b := piste[i + 1]
		var n := int(a.distance_to(b) / 3.0)
		for k in n:
			var q := a.lerp(b, float(k) / n)
			occupe[_cle(q)] = true


# ---------------------------------------------------------------------
# Rivière, cascade et embarcadère
# ---------------------------------------------------------------------
func _riviere() -> void:
	var lit: Dictionary = plan["lit"]
	var pts: PackedVector2Array = lit["pts"]
	var niv: PackedFloat32Array = lit["niveaux"]
	# points rapprochés tous les 3 m, lissés
	var fin := PackedVector2Array()
	var nf := PackedFloat32Array()
	for i in pts.size() - 1:
		var n := int(pts[i].distance_to(pts[i + 1]) / 3.0)
		for k in n:
			var t := float(k) / n
			var p0 := pts[maxi(i - 1, 0)]
			var p3 := pts[mini(i + 2, pts.size() - 1)]
			fin.append(pts[i].cubic_interpolate(pts[i + 1], p0, p3, t))
			nf.append(lerpf(niv[i], niv[i + 1], t))
	fin.append(pts[pts.size() - 1])
	nf.append(niv[niv.size() - 1])
	# la rivière s'arrête où elle rejoint la mer
	for i in fin.size():
		if nf[i] <= 0.05:
			fin = fin.slice(0, i + 2)
			nf = nf.slice(0, i + 2)
			break
	# section en 5 points : l'eau reste à niveau au milieu, et ses bords plongent sous les berges
	# (le relief est trop grossier pour un lit étroit : les bords ne flottent jamais au-dessus du sol)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var long := 0.0
	var demi := 4.2
	var travers := [-1.0, -0.5, 0.0, 0.5, 1.0]
	var prec: Array = []
	for i in fin.size():
		if nf[i] < 0.25 and i > 0:
			break
		var dir := (fin[mini(i + 1, fin.size() - 1)] - fin[maxi(i - 1, 0)]).normalized()
		var n := dir.orthogonal()
		if i > 0:
			long += fin[i].distance_to(fin[i - 1])
		var y := nf[i] - 0.2
		var section: Array = []
		for k in travers:
			var q: Vector2 = fin[i] + n * k * demi
			var yy := y
			if absf(k) > 0.1:
				yy = minf(y, _sol(q) - (0.25 if absf(k) > 0.9 else 0.02))
			section.append([Vector3(q.x, yy, q.y), Vector2((k + 1.0) * 0.5, long)])
		if i > 0:
			for k in travers.size() - 1:
				var quad := [prec[k], prec[k + 1], section[k + 1], section[k]]
				for j in [0, 2, 1, 0, 3, 2]:
					st.set_normal(Vector3.UP)
					st.set_uv(quad[j][1])
					st.add_vertex(quad[j][0])
		prec = section
		for k in [-1.0, 0.0, 1.0]:
			occupe[_cle(fin[i] + n * k * 6.0)] = true
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/riviere.gdshader")
	var mi := MeshInstance3D.new()
	mi.name = "Riviere"
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	reperes["riviere"] = fin
	# son de l'eau : courant le long du lit, chute plus forte à la cascade
	for i in range(0, fin.size(), 14):
		var a := AudioStreamPlayer3D.new()
		var s: AudioStreamWAV = load("res://sons/riviere.wav")
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_end = int(s.get_length() * s.mix_rate)
		a.stream = s
		a.unit_size = 5.0
		a.max_distance = 60.0
		a.volume_db = -4.0
		a.position = Vector3(fin[i].x, nf[i] + 0.5, fin[i].y)
		a.autoplay = true
		add_child(a)
		var chute := 0.0
		if i + 4 < nf.size():
			chute = nf[i] - nf[i + 4]
		if chute > 3.0:
			a.volume_db = 2.0
			a.max_distance = 90.0
	# rochers aux berges de la cascade
	for i in fin.size() - 1:
		if nf[i] - nf[i + 1] > 0.7 and rng.randf() < 0.6:
			var dir := (fin[i + 1] - fin[i]).normalized().orthogonal()
			for s in [-1.0, 1.0]:
				var q: Vector2 = fin[i] + dir * s * rng.randf_range(4.5, 6.5)
				_cylindre("pierre", Vector3(q.x, _sol(q) - 0.4, q.y), rng.randf_range(0.6, 1.2), rng.randf_range(0.7, 1.4), Color(0.6, 0.58, 0.55), 7, rng.randf_range(0.3, 0.7))


func _embarcadere() -> void:
	# embouchure : bande de sable au bord de la crique, trois pirogues tirées au sec, une à l'eau
	var lit: Dictionary = plan["lit"]
	var pts: PackedVector2Array = lit["pts"]
	var m := pts[pts.size() - 2]
	var dir := (pts[pts.size() - 1] - pts[pts.size() - 3]).normalized()
	var n := dir.orthogonal()
	var berge := m - n * 11.0
	reperes["embarcadere"] = Vector3(berge.x, _sol(berge), berge.y)
	var mesh := _maillage_pirogue()
	for k in 4:
		var q := berge + dir * (k * 2.6 - 3.0) - n * (0.0 if k < 3 else -8.0)
		var y := maxf(_sol(q), 0.05) + (0.0 if k < 3 else 0.12)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.transform = Transform3D(Basis(Vector3.UP, atan2(n.x, n.y) + rng.randf_range(-0.25, 0.25)), Vector3(q.x, y, q.y))
		add_child(mi)
	# chemin de fuite : de la porte de la prison, le long de la rive, jusqu'aux pirogues
	var porte: Vector3 = reperes["porte_prison"]
	var chemin := PackedVector2Array([Vector2(porte.x, porte.z), centre + Vector2(25, -6)])
	for i in range(4, pts.size() - 1):
		var q := pts[i] - (pts[i + 1] - pts[i - 1]).normalized().orthogonal() * 12.0
		if q.y < chemin[chemin.size() - 1].y:
			chemin.append(q)
	chemin.append(berge)
	reperes["chemin_fuite"] = chemin
	rues.append({"pts": chemin, "l": 1.6, "type": "laterite"})


func _maillage_pirogue() -> ArrayMesh:
	# coque monoxyle effilée aux deux bouts, peinte en bandes
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var l := 6.5
	var stations := 14
	var profil := [Vector2(-1.0, 1.0), Vector2(-0.9, 0.35), Vector2(-0.55, 0.05), Vector2(0.0, 0.0), Vector2(0.55, 0.05), Vector2(0.9, 0.35), Vector2(1.0, 1.0)]
	var anneaux: Array = []
	for i in stations + 1:
		var t := float(i) / stations
		var z := (t - 0.5) * l
		var e := pow(sin(t * PI), 0.6)
		var anneau: Array = []
		for p in profil:
			anneau.append(Vector3(p.x * 0.45 * e, 0.42 * p.y * (0.5 + 0.5 * e) + 0.12 * (1.0 - e) * p.y, z))
		anneaux.append(anneau)
	var couleurs := [Color(0.55, 0.32, 0.18), Color(0.12, 0.35, 0.55), Color(0.85, 0.72, 0.2)]
	for i in stations:
		for j in profil.size() - 1:
			var a: Vector3 = anneaux[i][j]
			var b: Vector3 = anneaux[i][j + 1]
			var c2: Vector3 = anneaux[i + 1][j + 1]
			var d: Vector3 = anneaux[i + 1][j]
			@warning_ignore("integer_division")
			var col: Color = couleurs[0] if (j == 0 or j == profil.size() - 2) and absf(a.y) > 0.3 else couleurs[1 + (i / 3) % 2] if j in [0, 5] else couleurs[0]
			var nrm := (b - a).cross(d - a).normalized()
			for v in [[a, Vector2(0, 0)], [b, Vector2(1, 0)], [c2, Vector2(1, 1)], [a, Vector2(0, 0)], [c2, Vector2(1, 1)], [d, Vector2(0, 1)]]:
				st.set_normal(nrm)
				st.set_color(col)
				st.set_uv(v[1])
				st.add_vertex(v[0])
	var mesh := st.commit()
	var m: StandardMaterial3D = (mats["bois_brut"] as StandardMaterial3D).duplicate()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, m)
	return mesh


func _palmiers(veg: Vegetation) -> void:
	# cocotiers autour de la crique
	var maillage: ArrayMesh = veg._maillage_palmier(rng, 14)
	var pts: PackedVector2Array = (plan["lit"] as Dictionary)["pts"]
	var embouchure := pts[pts.size() - 2]
	var n := 0
	for essai in 120:
		if n >= 16:
			break
		var a := rng.randf() * TAU
		var q := embouchure + Vector2(cos(a), sin(a)) * rng.randf_range(14.0, 75.0)
		var hq := _sol(q)
		if hq < 0.9 or hq > 14.0 or occupe.has(_cle(q)):
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = maillage
		var s := rng.randf_range(0.85, 1.2)
		mi.transform = Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(q.x, hq - 0.3, q.y))
		mi.visibility_range_end = DISTANCE_VUE
		add_child(mi)
		n += 1

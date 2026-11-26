## Routes en latérite qui relient Port-Néré aux villages (Akwéri, Bomé, Tikané).
## Le tracé est calculé sur le vrai relief (recherche de chemin AStarGrid2D) : il contourne les fortes pentes,
## évite la mer et ne franchit la rivière qu'en dernier recours, comme une piste tracée à la main.
## Chaque route : ruban de terre rouge bombé, bords qui se fondent dans le sol, ornières et nids-de-poule
## (texture), vraie surface de collision ; on dégage les arbres et l'herbe de son emprise.
class_name Routes
extends Node3D

const PAS_GRILLE := 12.0       # maille de la recherche de chemin (m)
const LARGEUR := 6.0           # chaussée (m)
const ACCOTEMENT := 2.0        # bande de terre qui se fond dans le sol de chaque côté
const EMPRISE := 7.5           # demi-largeur dégagée (arbres, herbe)
const CASE_OCC := 4.0

var terrain: Terrain
var traces: Array = []         # PackedVector2Array (m), points tous les 3 m
var occupe := {}               # Vector2i -> true : emprise des routes (herbe, arbres)
var mat: StandardMaterial3D


## troncons : liste de [départ: Vector2, arrivée: Vector2, sortie_depart: Vector2, sortie_arrivee: Vector2]
## (sortie = petit segment droit qui prolonge une rue existante, pour un raccord propre).
func construire(t: Terrain, troncons: Array, eviter: Array, rivieres: Array, villes: Array = []) -> void:
	terrain = t
	mat = StandardMaterial3D.new()
	# terre battue caillouteuse (plus claire et plus tassée que le sol autour), ornières plus sombres
	mat.albedo_texture = load("res://data/textures/red_mud_stones_diff.jpg")
	mat.normal_enabled = true
	mat.normal_texture = load("res://data/textures/red_mud_stones_nor.jpg")
	mat.normal_scale = 0.9
	mat.roughness = 0.95
	mat.vertex_color_use_as_albedo = true
	mat.uv1_scale = Vector3(1, 1, 1)
	var grille := _grille(eviter, rivieres)
	# bâtiments des villes et villages : la route passe entre eux, jamais au travers
	var couverture := {}
	var rues := {}
	for v in villes:
		for k in (v as VillePortNere).bati:
			var c := _cellule(Vector2(k.x * 2.0 + 1.0, k.y * 2.0 + 1.0))
			couverture[c] = couverture.get(c, 0) + 1
		for k in (v as VillePortNere).occupe:
			if not (v as VillePortNere).bati.has(k):
				rues[_cellule(Vector2(k.x * 2.0 + 1.0, k.y * 2.0 + 1.0))] = true
	# les rues des villes existent déjà : la piste ne les double pas (elle part du bout de la rue)
	for c in rues:
		if grille.is_in_boundsv(c):
			grille.set_point_solid(c, true)
	for c in couverture:
		if not grille.is_in_boundsv(c):
			continue
		if couverture[c] > 16:
			grille.set_point_solid(c, true)
		else:
			grille.set_point_weight_scale(c, grille.get_point_weight_scale(c) + 25.0)
	for tr in troncons:
		var pts := _chemin(grille, tr[0], tr[1])
		if pts.size() < 2:
			continue
		# raccords : la route prolonge la rue de la ville tout droit sur quelques dizaines de mètres
		var complet := PackedVector2Array()
		for p in tr[2]:
			complet.append(p)
		complet.append_array(pts)
		for p in tr[3]:
			complet.append(p)
		var lisse := _reechantillonner(_chaikin(_chaikin(_chaikin(complet))), 3.0)
		traces.append(lisse)
		_ruban(lisse, (tr[2] as Array).is_empty(), (tr[3] as Array).is_empty())
		_marquer(lisse)
		if tr.size() > 4:
			_panneau(lisse, tr[4])


## Panneau de bord de route : poteau de bois, plaque peinte avec le nom du village et la distance.
func _panneau(pts: PackedVector2Array, nom: String) -> void:
	var longueur := 0.0
	for i in pts.size() - 1:
		longueur += pts[i].distance_to(pts[i + 1])
	var i0 := mini(12, pts.size() - 2)
	var t := (pts[i0 + 1] - pts[i0]).normalized()
	var n := Vector2(-t.y, t.x)
	var p := pts[i0] + n * (LARGEUR * 0.5 + 1.2)
	var h := terrain.hauteur(p.x, p.y)
	var bois := StandardMaterial3D.new()
	bois.albedo_color = Color(0.36, 0.26, 0.17)
	bois.roughness = 0.9
	var poteau := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(0.1, 2.2, 0.1)
	poteau.mesh = bx
	poteau.material_override = bois
	poteau.position = Vector3(p.x, h + 1.1, p.y)
	add_child(poteau)
	var plaque := MeshInstance3D.new()
	var bp := BoxMesh.new()
	bp.size = Vector3(1.5, 0.42, 0.04)
	plaque.mesh = bp
	var peint := StandardMaterial3D.new()
	peint.albedo_color = Color(0.92, 0.9, 0.82)
	peint.roughness = 0.8
	plaque.material_override = peint
	var face := Basis(Vector3.UP, atan2(t.x, t.y))   # la plaque fait face à la route : on la lit en roulant
	plaque.transform = Transform3D(face, Vector3(p.x, h + 1.9, p.y))
	add_child(plaque)
	for cote in [1.0, -1.0]:
		var l := Label3D.new()
		l.text = "%s  %s km" % [nom, String.num(longueur / 1000.0, 1).replace(".", ",")]
		l.font_size = 64
		l.pixel_size = 0.0035
		l.modulate = Color(0.15, 0.12, 0.1)
		l.outline_size = 0
		l.double_sided = false
		l.transform = Transform3D(face * Basis(Vector3.UP, 0.0 if cote > 0 else PI), Vector3(p.x, h + 1.9, p.y) + face.z * 0.025 * cote)
		add_child(l)


# ---------------------------------------------------------------------
# Tracé
# ---------------------------------------------------------------------
func _cellule(p: Vector2) -> Vector2i:
	var demi := Terrain.TAILLE * 0.5
	return Vector2i(int((p.x + demi) / PAS_GRILLE), int((p.y + demi) / PAS_GRILLE))


func _monde(c: Vector2i) -> Vector2:
	var demi := Terrain.TAILLE * 0.5
	return Vector2((c.x + 0.5) * PAS_GRILLE - demi, (c.y + 0.5) * PAS_GRILLE - demi)


func _grille(eviter: Array, rivieres: Array) -> AStarGrid2D:
	var n := int(Terrain.TAILLE / PAS_GRILLE)
	var g := AStarGrid2D.new()
	g.region = Rect2i(0, 0, n, n)
	g.cell_size = Vector2(PAS_GRILLE, PAS_GRILLE)
	g.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	g.default_compute_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	g.update()
	for y in n:
		for x in n:
			var p := _monde(Vector2i(x, y))
			var h := terrain.hauteur(p.x, p.y)
			if h < 1.2:
				g.set_point_solid(Vector2i(x, y), true)     # mer, plage mouillée
				continue
			var s := terrain.pente(p.x, p.y)
			# une piste évite les pentes : coût qui grimpe très vite au-delà de 10 %
			var poids := 1.0 + 30.0 * s * s + (400.0 * (s - 0.18) * (s - 0.18) if s > 0.18 else 0.0)
			for z in eviter:   # traverser une ville ou un village par l'intérieur : à éviter
				if Vector2(p.x - z.x, p.y - z.y).length() < z.z:
					poids += 8.0
			g.set_point_weight_scale(Vector2i(x, y), poids)
	# rivière : franchissable (gué), mais coûteuse
	for lit in rivieres:
		var pts: PackedVector2Array = lit["pts"]
		for i in pts.size() - 1:
			var nb := int(pts[i].distance_to(pts[i + 1]) / 4.0) + 1
			for k in nb:
				var c := _cellule(pts[i].lerp(pts[i + 1], float(k) / nb))
				if g.is_in_boundsv(c) and not g.is_point_solid(c):
					g.set_point_weight_scale(c, 60.0)
	return g


func _chemin(g: AStarGrid2D, a: Vector2, b: Vector2) -> PackedVector2Array:
	var ca := _cellule(a)
	var cb := _cellule(b)
	# les extrémités et leurs abords immédiats restent praticables (bout de rue, place du village)
	for c in [ca, cb]:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var q := Vector2i(c.x + dx, c.y + dy)
				if g.is_in_boundsv(q) and terrain.hauteur(_monde(q).x, _monde(q).y) > 1.2:
					g.set_point_solid(q, false)
	var ids := g.get_id_path(ca, cb, true)
	var res := PackedVector2Array()
	for c in ids:
		res.append(_monde(c))
	if res.size() > 0:
		res[0] = a
		res[res.size() - 1] = b
	return res


func _chaikin(p: PackedVector2Array) -> PackedVector2Array:
	if p.size() < 3:
		return p
	var r := PackedVector2Array([p[0]])
	for i in p.size() - 1:
		r.append(p[i].lerp(p[i + 1], 0.25))
		r.append(p[i].lerp(p[i + 1], 0.75))
	r.append(p[p.size() - 1])
	return r


func _reechantillonner(p: PackedVector2Array, d: float) -> PackedVector2Array:
	var r := PackedVector2Array([p[0]])
	var reste := 0.0
	for i in p.size() - 1:
		var a := p[i]
		var b := p[i + 1]
		var l := a.distance_to(b)
		var t := d - reste
		while t <= l:
			r.append(a.lerp(b, t / l))
			t += d
		reste = l - (t - d)
	if r[r.size() - 1].distance_to(p[p.size() - 1]) > 0.5:
		r.append(p[p.size() - 1])
	return r


# ---------------------------------------------------------------------
# Ruban de latérite
# ---------------------------------------------------------------------
func _ruban(pts: PackedVector2Array, effile_debut := false, effile_fin := false) -> void:
	# section : bord fondu | accotement | chaussée bombée | accotement | bord fondu
	var lat := [-(LARGEUR * 0.5 + ACCOTEMENT), -LARGEUR * 0.5, -2.1, -1.5, -1.0, 0.0, 1.0, 1.5, 2.1, LARGEUR * 0.5, LARGEUR * 0.5 + ACCOTEMENT]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dur := PackedVector3Array()
	var prec: Array = []
	var v_long := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = pts.size()
	for i in pts.size():
		var t := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var n := Vector2(-t.y, t.x)
		if i > 0:
			v_long += pts[i].distance_to(pts[i - 1]) / 6.0
		var ligne: Array = []
		var teinte := Color(1, 1, 1) * rng.randf_range(0.9, 1.05)
		for k in lat.size():
			var l: float = lat[k]
			var largeur_k := 1.0
			if effile_debut:
				largeur_k = minf(largeur_k, 0.35 + 0.65 * clampf(i / 12.0, 0.0, 1.0))
			if effile_fin:
				largeur_k = minf(largeur_k, 0.35 + 0.65 * clampf((pts.size() - 1 - i) / 12.0, 0.0, 1.0))
			var q: Vector2 = pts[i] + n * (l * largeur_k)
			var sol := terrain.hauteur(q.x, q.y)
			var bord := absf(l) > LARGEUR * 0.5 + 0.1
			var h: float
			if bord:
				h = sol - 0.08          # le bord plonge sous le sol : la limite suit les irrégularités du terrain
			else:
				# une piste de terre suit le terrain (pas de remblai) : léger bombement pour l'écoulement des pluies
				var bombe := 0.06 * (1.0 - absf(l) / (LARGEUR * 0.5))
				h = sol + 0.1 + bombe
			# deux ornières tassées et sombres (passage des roues), bande centrale plus claire, bords poussiéreux
			var c := 1.15
			if absf(absf(l) - 1.5) < 0.1:
				c = 0.78
			elif absf(l) < 0.1:
				c = 1.25
			elif bord:
				c = 0.95
			ligne.append([Vector3(q.x, h - (0.035 if c < 0.9 else 0.0), q.y), Vector2((l + LARGEUR) / 6.0, v_long),
					Color(teinte.r * c, teinte.g * c * 0.93, teinte.b * c * 0.82, 1.0)])
		if prec.size() > 0:
			for k in lat.size() - 1:
				var a1: Array = prec[k]
				var b1: Array = prec[k + 1]
				var c1: Array = ligne[k + 1]
				var d1: Array = ligne[k]
				for v in [a1, c1, b1, a1, d1, c1]:   # sens horaire vu du dessus : faces visibles
					st.set_color(v[2])
					st.set_uv(v[1])
					st.add_vertex(v[0])
				if k > 0 and k < lat.size() - 2:
					dur.append_array([a1[0], b1[0], c1[0], a1[0], c1[0], d1[0]])
		prec = ligne
	st.generate_normals()
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var corps := StaticBody3D.new()
	corps.collision_layer = 1
	corps.collision_mask = 0
	var cs := CollisionShape3D.new()
	var forme := ConcavePolygonShape3D.new()
	forme.backface_collision = true
	forme.set_faces(dur)
	cs.shape = forme
	corps.add_child(cs)
	add_child(corps)


func _marquer(pts: PackedVector2Array) -> void:
	for p in pts:
		var r := int(ceil(EMPRISE / CASE_OCC))
		var c := Vector2i(floori(p.x / CASE_OCC), floori(p.y / CASE_OCC))
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var q := Vector2((c.x + dx + 0.5) * CASE_OCC, (c.y + dy + 0.5) * CASE_OCC)
				if q.distance_to(p) < EMPRISE:
					occupe[Vector2i(c.x + dx, c.y + dy)] = true


## Ce point est-il sur l'emprise d'une route ? (arbres et herbe n'y poussent pas)
func sur_route(p: Vector2) -> bool:
	return occupe.has(Vector2i(floori(p.x / CASE_OCC), floori(p.y / CASE_OCC)))

## Port-Néré, petite ville portuaire du nord de Talanké (~2 000 habitants), occupée par le Front du Cobra.
## Construite par programme à partir du relief réel et de l'image satellite :
## - boulevard du front de mer (asphalte, trottoirs, réverbères allumés la nuit, cocotiers) ;
## - avenue de l'Indépendance et rond-point ; ruelles en latérite ;
## - maisons en parpaing enduit et peint, toits de tôle, persiennes, boutiques avec auvent et enseigne,
##   immeubles à toit plat avec citerne, chantiers inachevés, murs d'enceinte ;
## - lieux de l'histoire : marché, église, mosquée, gendarmerie, station-service, maquis de Mama Rokia,
##   maison de la famille de Faris, barrages du Cobra.
## Tout est fusionné par matériau et par blocs de 80 m (peu d'objets à dessiner : bon pour un PC modeste).
## Textures : Poly Haven (CC0). Enseignes et noms : fictifs.
class_name VillePortNere
extends Node3D

const CELLULE := 80.0
const DISTANCE_VUE := 1400.0

var terrain: Terrain
var centre := Vector2.ZERO
var rng := RandomNumberGenerator.new()
var mats := {}
var seaux := {}            # "matériau|cellule" -> SurfaceTool
var occupe := {}           # grille de 2 m déjà prise (rues, bâtiments)
var rues: Array = []       # {"pts": PackedVector2Array, "l": largeur, "type": "asphalte"/"laterite"}
var segments: Array = []   # [a, b, demi-largeur] de toutes les rues
var lampes: Array = []
var corps: StaticBody3D
var reperes := {}
var nb_batiments := 0
var arbres: Array = []     # Transform3D des arbres d'ombre
var palmiers: Array = []
var bati := {}             # cases de 2 m occupées par des bâtiments (pas les rues)
var boutiques: Array = []  # [point devant la vitrine, avant, largeur, enseigne]
var chantiers: Array = []  # [centre, avant, largeur, profondeur]
var objets := {}           # nom du modèle (props/*.glb) -> [Transform3D]

const PEINTURES := [
	Color(0.86, 0.66, 0.42), Color(0.58, 0.72, 0.82), Color(0.93, 0.91, 0.86), Color(0.86, 0.62, 0.56),
	Color(0.66, 0.79, 0.6), Color(0.92, 0.82, 0.48), Color(0.5, 0.75, 0.72), Color(0.95, 0.78, 0.62),
	Color(0.78, 0.74, 0.86), Color(0.9, 0.9, 0.9),
]
const VOLETS := [Color(0.2, 0.42, 0.62), Color(0.25, 0.5, 0.32), Color(0.48, 0.3, 0.18), Color(0.75, 0.72, 0.65), Color(0.6, 0.18, 0.15)]
const ENSEIGNES := [
	"ALIMENTATION LA GRÂCE", "BOUTIQUE DU PEUPLE", "PHARMACIE DE L'ÎLE", "COIFFURE MODERNE",
	"QUINCAILLERIE TALANKÉ", "TRANSFERT D'ARGENT", "TAILLEUR ÉLÉGANCE", "BOULANGERIE DU PORT",
	"CABINE · RECHARGE", "DÉPÔT DE BOISSONS", "MERCERIE AMINATA", "ÉLECTRONIQUE NÉRÉ",
	"PAGNES & WAX", "LIBRAIRIE L'AVENIR", "ATELIER SOUDURE", "POISSONNERIE",
]


func construire(t: Terrain, p_centre: Vector2, vegetation: Vegetation) -> void:
	terrain = t
	centre = p_centre
	rng.seed = 2412
	_materiaux()
	corps = StaticBody3D.new()
	corps.name = "Collisions"
	add_child(corps)
	_tracer_rues()
	for r in rues:
		_marquer_rue(r)
	_lieux()
	for r in rues:
		_lotir(r)
	_remplir_ilots()
	for r in rues:
		_ruban(r)
	_reverberes()
	_mobilier()
	for r in rues:
		if r["type"] == "laterite":
			_ligne_electrique(r)
	_finir_maillages()
	_vegetation(vegetation)
	print("Port-Néré : %d bâtiments, %d rues, %d réverbères" % [nb_batiments, rues.size(), lampes.size()])


# =====================================================================
# Matériaux
# =====================================================================
func _materiau(nom: String, taille_m: float, teinte := Color.WHITE, rugosite := 0.9, metal := 0.0, vcol := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://data/textures/%s_diff.jpg" % nom)
	m.normal_enabled = true
	m.normal_texture = load("res://data/textures/%s_nor.jpg" % nom)
	m.normal_scale = 0.7
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / taille_m
	m.albedo_color = teinte
	m.roughness = rugosite
	m.metallic = metal
	m.vertex_color_use_as_albedo = vcol
	return m


func _uni(c: Color, rugosite := 0.8, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rugosite
	m.metallic = metal
	m.vertex_color_use_as_albedo = true
	return m


func _materiaux() -> void:
	mats["mur"] = _materiau("painted_plaster_wall", 3.0, Color.WHITE, 0.92, 0.0, true)
	mats["brut"] = _materiau("concrete_block_wall", 2.4, Color(1.15, 1.12, 1.08))
	mats["socle"] = _materiau("damaged_plaster", 2.5, Color(0.8, 0.78, 0.74))
	mats["tole"] = _materiau("rusty_corrugated_iron", 2.2, Color.WHITE, 0.6, 0.3, true)
	# tôle neuve galvanisée : même relief ondulé, métal clair
	var tn := _materiau("rusty_corrugated_iron", 2.2, Color.WHITE, 0.35, 0.75, true)
	tn.albedo_texture = null
	tn.albedo_color = Color(0.72, 0.74, 0.76)
	mats["tole_neuve"] = tn
	mats["bois"] = _materiau("wood_peeling_paint_weathered", 1.2, Color.WHITE, 0.85, 0.0, true)
	mats["beton"] = _materiau("concrete_pavement", 3.0, Color(0.95, 0.93, 0.9))
	mats["asphalte"] = _materiau("asphalt_02", 6.0, Color(0.85, 0.85, 0.85), 0.85)
	mats["laterite"] = _materiau("laterite", 5.0, Color(0.95, 0.82, 0.72), 1.0)
	mats["trottoir"] = _materiau("concrete_pavement", 2.0, Color(0.9, 0.88, 0.84))
	mats["metal"] = _uni(Color.WHITE, 0.5, 0.45)
	mats["sombre"] = _uni(Color(0.05, 0.045, 0.04), 1.0)
	var vitre := _uni(Color(0.08, 0.1, 0.12), 0.15, 0.3)
	mats["vitre"] = vitre
	var vn := _uni(Color(0.3, 0.25, 0.18), 0.4)
	vn.emission_enabled = true
	vn.emission = Color(1.0, 0.72, 0.42)
	vn.emission_energy_multiplier = 0.0
	mats["vitre_nuit"] = vn
	var amp := _uni(Color(1, 0.95, 0.85), 0.3)
	amp.emission_enabled = true
	amp.emission = Color(1.0, 0.78, 0.5)
	amp.emission_energy_multiplier = 0.2
	mats["ampoule"] = amp
	var dr := StandardMaterial3D.new()
	dr.albedo_texture = load("res://data/textures/drapeau_cobra.jpg")
	dr.cull_mode = BaseMaterial3D.CULL_DISABLED
	mats["drapeau_cobra"] = dr
	var dw := StandardMaterial3D.new()
	dw.albedo_texture = _drapeau_wanzala()
	dw.cull_mode = BaseMaterial3D.CULL_DISABLED
	mats["drapeau_wanzala"] = dw


## Drapeau national (vert, jaune, rouge en bandes horizontales, étoile noire) dessiné en code.
func _drapeau_wanzala() -> ImageTexture:
	var img := Image.create(96, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 96:
			var c := Color(0.05, 0.5, 0.25) if y < 21 else (Color(0.98, 0.8, 0.1) if y < 43 else Color(0.8, 0.12, 0.12))
			var d := Vector2(x - 48, y - 32)
			var a := atan2(d.y, d.x) + PI / 2.0
			var r := 11.0 * (0.55 + 0.45 * cos(5.0 * a)) # étoile à cinq branches approchée
			if d.length() < r:
				c = Color(0.05, 0.05, 0.05)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# =====================================================================
# Géométrie fusionnée
# =====================================================================
func _st(mat: String, p: Vector3) -> SurfaceTool:
	var cle := "%s|%d|%d" % [mat, floori(p.x / CELLULE), floori(p.z / CELLULE)]
	if not seaux.has(cle):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		seaux[cle] = st
	return seaux[cle]


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3, col: Color) -> void:
	# Godot : face avant = sens horaire vue de devant
	if (b - a).cross(c - a).dot(n) > 0.0:
		var t := b
		b = c
		c = t
	for v in [a, b, c]:
		st.set_normal(n)
		st.set_color(col)
		# coordonnées de texture selon l'axe dominant (pour les tangentes des reliefs)
		st.set_uv(Vector2(v.x, v.z) if absf(n.y) > 0.7 else Vector2(v.x + v.z, v.y))
		st.add_vertex(v)


func _quad(mat: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col := Color.WHITE, n := Vector3.ZERO) -> void:
	if n == Vector3.ZERO:
		n = (b - a).cross(d - a).normalized()
	var st := _st(mat, (a + c) * 0.5)
	_tri(st, a, b, c, n, col)
	_tri(st, a, c, d, n, col)


## Boîte orientée : xf = repère (origine au centre de la face du dessous), taille en mètres.
func _boite(mat: String, xf: Transform3D, t: Vector3, col := Color.WHITE, dessous := false) -> void:
	var hx := t.x * 0.5
	var hz := t.z * 0.5
	var p := func(x, y, z): return xf * Vector3(x, y, z)
	var bx := xf.basis.x.normalized()
	var by := xf.basis.y.normalized()
	var bz := xf.basis.z.normalized()
	_quad(mat, p.call(-hx, t.y, -hz), p.call(hx, t.y, -hz), p.call(hx, t.y, hz), p.call(-hx, t.y, hz), col, by)
	_quad(mat, p.call(-hx, 0, -hz), p.call(hx, 0, -hz), p.call(hx, t.y, -hz), p.call(-hx, t.y, -hz), col, -bz)
	_quad(mat, p.call(-hx, 0, hz), p.call(hx, 0, hz), p.call(hx, t.y, hz), p.call(-hx, t.y, hz), col, bz)
	_quad(mat, p.call(-hx, 0, -hz), p.call(-hx, 0, hz), p.call(-hx, t.y, hz), p.call(-hx, t.y, -hz), col, -bx)
	_quad(mat, p.call(hx, 0, -hz), p.call(hx, 0, hz), p.call(hx, t.y, hz), p.call(hx, t.y, -hz), col, bx)
	if dessous:
		_quad(mat, p.call(-hx, 0, -hz), p.call(hx, 0, -hz), p.call(hx, 0, hz), p.call(-hx, 0, hz), col, -by)


func _cylindre(mat: String, base: Vector3, r: float, h: float, col := Color.WHITE, cotes := 10, r_haut := -1.0, decalage := 0.0) -> void:
	if r_haut < 0.0:
		r_haut = r
	for i in cotes:
		var a0 := TAU * i / cotes + decalage
		var a1 := TAU * (i + 1) / cotes + decalage
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var n := ((d0 + d1) * 0.5).normalized()
		_quad(mat, base + d0 * r, base + d1 * r, base + d1 * r_haut + Vector3.UP * h, base + d0 * r_haut + Vector3.UP * h, col, n)
		var st := _st(mat, base)
		_tri(st, base + Vector3.UP * h, base + d0 * r_haut + Vector3.UP * h, base + d1 * r_haut + Vector3.UP * h, Vector3.UP, col)


func _repere(c: Vector2, avant: Vector2, y: float) -> Transform3D:
	# X le long de la façade, Z vers l'arrière (la façade regarde « avant »)
	var z := Vector3(-avant.x, 0, -avant.y)
	var x := Vector3(-avant.y, 0, avant.x)
	return Transform3D(Basis(x, Vector3.UP, z), Vector3(c.x, y, c.y))


func _sol(p: Vector2) -> float:
	return terrain.hauteur(p.x, p.y)


func _collision(xf: Transform3D, t: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = t
	cs.shape = b
	cs.transform = xf.translated_local(Vector3(0, t.y * 0.5, 0))
	corps.add_child(cs)


func _finir_maillages() -> void:
	var par_cellule := {}
	for cle in seaux:
		var morceaux: PackedStringArray = (cle as String).split("|")
		var cel := morceaux[1] + "|" + morceaux[2]
		if not par_cellule.has(cel):
			par_cellule[cel] = ArrayMesh.new()
		var st: SurfaceTool = seaux[cle]
		st.generate_tangents()
		var mesh: ArrayMesh = par_cellule[cel]
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mats[morceaux[0]])
	for cel in par_cellule:
		var mi := MeshInstance3D.new()
		mi.name = "Ville_" + (cel as String).replace("|", "_")
		mi.mesh = par_cellule[cel]
		# (pas de distance de visibilité ici : ces maillages ont leur origine au centre du monde)
		add_child(mi)
	seaux.clear()


# =====================================================================
# Occupation du sol (grille de 2 m)
# =====================================================================
func _cle(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / 2.0), floori(p.y / 2.0))


func _rect_libre(c: Vector2, avant: Vector2, w: float, d: float, marge := 0.5) -> bool:
	var r := Vector2(-avant.y, avant.x)
	var x := -w * 0.5 - marge
	while x <= w * 0.5 + marge:
		var z := -d * 0.5 - marge
		while z <= d * 0.5 + marge:
			if occupe.has(_cle(c + r * x - avant * z)):
				return false
			z += 1.0
		x += 1.0
	return true


func _prendre(c: Vector2, avant: Vector2, w: float, d: float, marge := 0.5) -> void:
	var r := Vector2(-avant.y, avant.x)
	var x := -w * 0.5 - marge
	while x <= w * 0.5 + marge:
		var z := -d * 0.5 - marge
		while z <= d * 0.5 + marge:
			occupe[_cle(c + r * x - avant * z)] = true
			bati[_cle(c + r * x - avant * z)] = true
			z += 1.0
		x += 1.0


func _terrain_ok(c: Vector2, avant: Vector2, w: float, d: float) -> bool:
	var r := Vector2(-avant.y, avant.x)
	var hmin := INF
	var hmax := -INF
	for sx in [-0.5, 0.5]:
		for sz in [-0.5, 0.5]:
			var h := _sol(c + r * (w * sx) + avant * (d * sz))
			hmin = minf(hmin, h)
			hmax = maxf(hmax, h)
	return hmin > 1.6 and hmax - hmin < 3.2 and hmax < 48.0


# =====================================================================
# Rues
# =====================================================================
func _cote_x(z: float) -> float:
	# trait de côte : en partant de l'intérieur vers l'ouest, premier point sous 1,2 m
	var x := centre.x + 150.0
	while x > centre.x - 520.0:
		if _sol(Vector2(x, z)) < 1.2:
			return x
		x -= 2.0
	return centre.x - 520.0


func _onduler(pts: PackedVector2Array, amp: float, graine: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var l := 0.0
	for i in pts.size():
		if i > 0:
			l += pts[i].distance_to(pts[i - 1])
		var t := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var n := Vector2(-t.y, t.x)
		var bord := minf(1.0, minf(i, pts.size() - 1 - i) / 2.0)
		out.append(pts[i] + n * amp * bord * sin(l * 0.035 + graine))
	return out


func _droite(a: Vector2, b: Vector2, pas := 12.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := maxi(1, int(a.distance_to(b) / pas))
	for i in n + 1:
		pts.append(a.lerp(b, float(i) / n))
	return pts


## Coupe une ligne là où le terrain devient impraticable (mer, colline trop haute).
func _praticable(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		var h := _sol(p)
		if h < 1.5 or h > 40.0 or terrain.pente(p.x, p.y) > 0.28:
			if out.size() >= 3:
				break
			out.clear()
			continue
		out.append(p)
	return out


func _ajouter_rue(pts: PackedVector2Array, largeur: float, type: String) -> void:
	if pts.size() < 3:
		return
	rues.append({"pts": pts, "l": largeur, "type": type})
	for i in pts.size() - 1:
		segments.append([pts[i], pts[i + 1], largeur * 0.5])


func _tracer_rues() -> void:
	# boulevard du front de mer : 24 m à l'intérieur du trait de côte, lissé
	var brut := PackedVector2Array()
	var z := centre.y - 150.0
	while z <= centre.y + 185.0:
		brut.append(Vector2(_cote_x(z) + 24.0, z))
		z += 10.0
	var bvd := PackedVector2Array()
	for i in brut.size():
		var s := Vector2.ZERO
		var n := 0
		for k in range(maxi(0, i - 3), mini(brut.size(), i + 4)):
			s += brut[k]
			n += 1
		bvd.append(s / n)
	bvd = _praticable(bvd)
	_ajouter_rue(bvd, 10.0, "asphalte")
	reperes["boulevard"] = bvd
	# avenue de l'Indépendance (est-ouest), qui part du boulevard
	var z_av := centre.y + 14.0
	var x0 := _x_rue(bvd, z_av)
	var av := _praticable(_onduler(_droite(Vector2(x0, z_av), Vector2(centre.x + 205.0, z_av - 6.0)), 1.5, 0.7))
	_ajouter_rue(av, 9.0, "asphalte")
	reperes["avenue"] = av
	reperes["rond_point"] = Vector2(x0, z_av)
	# piste vers Bomé et les plantations (au sud-est)
	_ajouter_rue(_praticable(_onduler(_droite(av[av.size() - 1], Vector2(centre.x + 330.0, centre.y + 110.0)), 4.0, 2.0)), 7.0, "laterite")
	# ruelles est-ouest
	for zr in [-120.0, -66.0, 68.0, 122.0, 172.0]:
		var zz: float = centre.y + zr + rng.randf_range(-4, 4)
		var xa := _x_rue(bvd, zz)
		_ajouter_rue(_praticable(_onduler(_droite(Vector2(xa, zz), Vector2(centre.x + 190.0, zz + rng.randf_range(-10, 10))), 2.5, zr)), 6.0, "laterite")
	# ruelles nord-sud
	for xr in [-160.0, -100.0, -40.0, 20.0, 80.0, 140.0]:
		var xx: float = centre.x + xr + rng.randf_range(-5, 5)
		_ajouter_rue(_praticable(_onduler(_droite(Vector2(xx, centre.y - 128.0), Vector2(xx + rng.randf_range(-12, 12), centre.y + 190.0)), 2.5, xr)), 6.0, "laterite")


func _x_rue(pts: PackedVector2Array, z: float) -> float:
	for i in pts.size() - 1:
		if (pts[i].y - z) * (pts[i + 1].y - z) <= 0.0:
			var t := (z - pts[i].y) / maxf(0.001, pts[i + 1].y - pts[i].y)
			return lerpf(pts[i].x, pts[i + 1].x, t)
	return pts[0].x


func _marquer_rue(r: Dictionary) -> void:
	var pts: PackedVector2Array = r["pts"]
	var demi: float = r["l"] * 0.5 + (2.4 if r["type"] == "asphalte" else 0.6)
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var n := int(a.distance_to(b) / 1.5) + 1
		for k in n + 1:
			var p := a.lerp(b, float(k) / n)
			var d := -demi
			while d <= demi:
				var t := (b - a).normalized()
				occupe[_cle(p + Vector2(-t.y, t.x) * d)] = true
				d += 1.5


func _dans_autre_rue(p: Vector2, sauf: Dictionary, marge: float) -> bool:
	for s in segments:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		if p.distance_to(a + ab * t) < s[2] + marge:
			# ce segment appartient-il à la rue en cours ?
			var pts: PackedVector2Array = sauf["pts"]
			var a_elle := false
			for k in pts.size() - 1:
				if pts[k] == a and pts[k + 1] == b:
					a_elle = true
					break
			if not a_elle:
				return true
	return false


## Ruban de chaussée qui épouse le sol (+ trottoirs et bordures pour l'asphalte).
func _ruban(r: Dictionary) -> void:
	var pts: PackedVector2Array = r["pts"]
	var asphalte: bool = r["type"] == "asphalte"
	var mat: String = r["type"]
	var hw: float = r["l"] * 0.5
	var dy := 0.13 if asphalte else 0.08
	# ré-échantillonnage tous les 3 m
	var ech := PackedVector2Array()
	for i in pts.size() - 1:
		var n := maxi(1, int(pts[i].distance_to(pts[i + 1]) / 3.0))
		for k in n:
			ech.append(pts[i].lerp(pts[i + 1], float(k) / n))
	ech.append(pts[pts.size() - 1])
	var lat := [-1.0, -0.5, 0.0, 0.5, 1.0]
	var prec: Array = []
	var prec_tr: Array = []
	for i in ech.size():
		var t := (ech[mini(i + 1, ech.size() - 1)] - ech[maxi(i - 1, 0)]).normalized()
		var n := Vector2(-t.y, t.x)
		var ligne: Array = []
		for l in lat:
			var q: Vector2 = ech[i] + n * (hw * l)
			var bombe := 0.04 * (1.0 - absf(l))
			ligne.append(Vector3(q.x, _sol(q) + dy + bombe, q.y))
		if prec.size() > 0:
			for k in lat.size() - 1:
				_quad(mat, prec[k], prec[k + 1], ligne[k + 1], ligne[k], Color.WHITE, Vector3.UP)
		prec = ligne
		if asphalte:
			# trottoirs de 2,2 m, interrompus aux carrefours
			var tr: Array = []
			for cote in [-1.0, 1.0]:
				var q0: Vector2 = ech[i] + n * (hw * cote)
				var q1: Vector2 = ech[i] + n * ((hw + 2.2) * cote)
				var libre := not _dans_autre_rue(ech[i] + n * ((hw + 1.1) * cote), r, 0.5)
				var h := _sol(q1) + 0.27
				tr.append([Vector3(q0.x, _sol(q0) + dy, q0.y), Vector3(q0.x, h, q0.y), Vector3(q1.x, h, q1.y), libre])
			if prec_tr.size() > 0:
				for c in 2:
					if tr[c][3] and prec_tr[c][3]:
						_quad("trottoir", prec_tr[c][1], prec_tr[c][2], tr[c][2], tr[c][1], Color.WHITE, Vector3.UP)
						var nb := Vector3(n.x, 0, n.y) * (-1.0 if c == 0 else 1.0) * -1.0
						_quad("beton", prec_tr[c][0], prec_tr[c][1], tr[c][1], tr[c][0], Color(0.85, 0.85, 0.82), nb)
						if is_same(r, rues[0]) and _cote_mer(pts, -1.0 if c == 0 else 1.0):
							# muret blanc du front de mer, comme une promenade
							var a3: Vector3 = prec_tr[c][2]
							var b3: Vector3 = tr[c][2]
							var mid := (a3 + b3) * 0.5
							var dir := Vector2(b3.x - a3.x, b3.z - a3.z)
							if dir.length() > 0.1:
								var xm := _repere(Vector2(mid.x, mid.z), Vector2(dir.y, -dir.x).normalized(), minf(a3.y, b3.y) - 0.05)
								_boite("beton", xm, Vector3(dir.length() + 0.05, 0.75, 0.3), Color(0.96, 0.95, 0.92))
			prec_tr = tr


# =====================================================================
# Bâtiments
# =====================================================================
## c : centre au sol, avant : direction de la rue, w : largeur de façade, d : profondeur.
## style : {"etages", "peinture", "brut", "toit": "deux_pans"/"un_pan"/"plat", "boutique", "enseigne", "volets"}
func _batiment(c: Vector2, avant: Vector2, w: float, d: float, style: Dictionary) -> void:
	var r := Vector2(-avant.y, avant.x)
	var hmin := INF
	var hmax := -INF
	for sx in [-0.5, 0.5]:
		for sz in [-0.5, 0.5]:
			var h := _sol(c + r * (w * sx) + avant * (d * sz))
			hmin = minf(hmin, h)
			hmax = maxf(hmax, h)
	var base := hmax + 0.2
	var xf := _repere(c, avant, base)
	var etages: int = style.get("etages", 1)
	var brut: bool = style.get("brut", false)
	var peinture: Color = style.get("peinture", PEINTURES[0])
	var mur := "brut" if brut else "mur"
	var H := etages * 3.1 + 0.25
	nb_batiments += 1
	# soubassement qui rattrape la pente
	var hs := base - hmin + 0.4
	_boite("socle", xf.translated_local(Vector3(0, -hs, 0)), Vector3(w + 0.16, hs, d + 0.16))
	# murs
	_boite(mur, xf, Vector3(w, H, d), peinture)
	if not brut:
		# bas des murs salis par la latérite et la pluie
		_boite("mur", xf, Vector3(w + 0.02, 0.75, d + 0.02), peinture * Color(0.62, 0.52, 0.45))
	for k in range(1, etages + 1):
		_boite("beton", xf.translated_local(Vector3(0, k * 3.1 - 0.05, 0)), Vector3(w + 0.14, 0.2, d + 0.14))
	_collision(xf, Vector3(w, H, d))
	# ouvertures
	var volet: Color = style.get("volets", VOLETS[0])
	var porte_x := rng.randf_range(-w * 0.25, w * 0.25)
	for k in etages:
		var y0 := k * 3.1 + 1.0
		for face in 4:
			var long := w if face < 2 else d
			var nb := int((long - 1.2) / 3.2)
			if nb <= 0:
				continue
			for i in nb:
				var x := -long * 0.5 + long * (i + 0.5) / nb
				if k == 0 and face == 0 and absf(x - porte_x) < (2.4 if style.get("boutique", false) else 1.4):
					continue
				if rng.randf() < 0.15:
					continue
				_fenetre(xf, face, x, y0, w, d, volet, brut)
	# porte ou devanture
	var pf := xf.translated_local(Vector3(porte_x, 0, -d * 0.5 - 0.03))
	if brut:
		chantiers.append([c, avant, w, d])
	if style.get("boutique", false):
		boutiques.append([c + avant * (d * 0.5), avant, w, style.get("enseigne", ""), base])
		_boite("sombre", pf, Vector3(3.0, 2.5, 0.06))
		_boite("metal", pf.translated_local(Vector3(0, 1.6, -0.02)), Vector3(3.1, 0.95, 0.06), Color(0.62, 0.62, 0.6))
		_auvent(xf, w, d, porte_x, style)
	else:
		_boite("metal", pf, Vector3(1.0, 2.25, 0.07), VOLETS[rng.randi() % VOLETS.size()] * 0.9)
		_boite("beton", xf.translated_local(Vector3(porte_x, 0, -d * 0.5 - 0.5)), Vector3(1.6, 0.18, 1.0))
	# toit
	var toit: String = style.get("toit", "deux_pans")
	var haut := xf.translated_local(Vector3(0, H, 0))
	if toit == "plat":
		_boite("beton", haut, Vector3(w + 0.1, 0.18, d + 0.1))
		for s in [-1.0, 1.0]:
			_boite(mur, haut.translated_local(Vector3(0, 0.18, s * (d * 0.5 - 0.08))), Vector3(w, 0.6, 0.16), peinture)
			_boite(mur, haut.translated_local(Vector3(s * (w * 0.5 - 0.08), 0.18, 0)), Vector3(0.16, 0.6, d - 0.3), peinture)
		if rng.randf() < 0.7: # citerne d'eau noire sur le toit
			var pc := haut * Vector3(rng.randf_range(-w * 0.25, w * 0.25), 0.18, rng.randf_range(0, d * 0.25))
			_cylindre("metal", pc, 0.65, 1.4, Color(0.06, 0.06, 0.07), 10, 0.6)
		if brut or rng.randf() < 0.3: # fers à béton en attente d'un étage
			for i in 6:
				var px := -w * 0.5 + 0.3 + (w - 0.6) * (i % 3) / 2.0
				var pz := -d * 0.5 + 0.3 if i < 3 else d * 0.5 - 0.3
				_boite("metal", haut.translated_local(Vector3(px, 0.18, pz)), Vector3(0.04, 1.1, 0.04), Color(0.35, 0.18, 0.1))
	else:
		_toit_tole(haut, w, d, toit == "un_pan", style.get("teinte_toit", Color.WHITE), peinture, mur)


func _fenetre(xf: Transform3D, face: int, x: float, y0: float, w: float, d: float, volet: Color, brut: bool) -> void:
	var t: Transform3D
	match face:
		0: t = xf.translated_local(Vector3(x, y0, -d * 0.5 - 0.035))
		1: t = xf.translated_local(Vector3(x, y0, d * 0.5 + 0.035)).rotated_local(Vector3.UP, PI)
		2: t = xf.translated_local(Vector3(-w * 0.5 - 0.035, y0, x)).rotated_local(Vector3.UP, -PI / 2.0)
		_: t = xf.translated_local(Vector3(w * 0.5 + 0.035, y0, x)).rotated_local(Vector3.UP, PI / 2.0)
	# encadrement blanc
	_boite("beton", t.translated_local(Vector3(0, -0.12, 0)), Vector3(1.45, 0.12, 0.12), Color(0.95, 0.95, 0.92))
	if brut and rng.randf() < 0.5:
		_boite("sombre", t, Vector3(1.15, 1.3, 0.05)) # ouverture sans menuiserie
		return
	if rng.randf() < 0.55:
		# persiennes en bois peint
		_boite("bois", t, Vector3(1.15, 1.35, 0.06), volet)
		for i in 5:
			_boite("bois", t.translated_local(Vector3(0, 0.15 + i * 0.25, -0.03)), Vector3(1.1, 0.05, 0.03), volet * 0.8)
	else:
		var allumee := rng.randf() < 0.35
		_boite("vitre_nuit" if allumee else "vitre", t, Vector3(1.15, 1.3, 0.04))
		for i in 4: # barreaux de sécurité
			_boite("metal", t.translated_local(Vector3(-0.42 + i * 0.28, 0, -0.04)), Vector3(0.03, 1.3, 0.03), Color(0.2, 0.2, 0.22))


func _toit_tole(xf: Transform3D, w: float, d: float, un_pan: bool, teinte: Color, peinture: Color, mur: String) -> void:
	var deb := 0.5
	var tole := "tole_neuve" if teinte == Color(0.99, 0.99, 0.99) else "tole"
	var hx := w * 0.5 + deb
	var hz := d * 0.5 + deb
	var col := Color(1, 1, 1) * teinte
	var p := func(x, y, z): return xf * Vector3(x, y, z)
	if un_pan:
		var hf := d * 0.12 + 0.3
		var a: Vector3 = p.call(-hx, hf, -hz)
		var b: Vector3 = p.call(hx, hf, -hz)
		var c: Vector3 = p.call(hx, 0.0, hz)
		var e: Vector3 = p.call(-hx, 0.0, hz)
		_quad(tole, a, b, c, e, col)
		_quad(tole, a, e, c, b, col * 0.55)
		for s in [-1.0, 1.0]:
			_quad(mur, p.call(s * w * 0.5, 0, -d * 0.5), p.call(s * w * 0.5, 0, d * 0.5), p.call(s * w * 0.5, 0.05, d * 0.5), p.call(s * w * 0.5, hf - 0.06, -d * 0.5), peinture)
		_quad(mur, p.call(-w * 0.5, 0, -d * 0.5), p.call(w * 0.5, 0, -d * 0.5), p.call(w * 0.5, hf - 0.06, -d * 0.5), p.call(-w * 0.5, hf - 0.06, -d * 0.5), peinture)
	else:
		var hf := d * 0.11 + 0.35
		var f0: Vector3 = p.call(-hx, hf, 0.0)
		var f1: Vector3 = p.call(hx, hf, 0.0)
		var av0: Vector3 = p.call(-hx, 0.0, -hz)
		var av1: Vector3 = p.call(hx, 0.0, -hz)
		var ar0: Vector3 = p.call(-hx, 0.0, hz)
		var ar1: Vector3 = p.call(hx, 0.0, hz)
		_quad(tole, av0, av1, f1, f0, col)
		_quad(tole, f0, f1, ar1, ar0, col)
		_quad(tole, av0, f0, f1, av1, col * 0.55)
		_quad(tole, f0, ar0, ar1, f1, col * 0.55)
		for s in [-1.0, 1.0]: # pignons
			var st := _st(mur, xf.origin)
			var n: Vector3 = xf.basis.x.normalized() * s
			_tri(st, p.call(s * w * 0.5, 0, -d * 0.5), p.call(s * w * 0.5, 0, d * 0.5), p.call(s * w * 0.5, hf - 0.05, 0), n, peinture)
	_boite("metal", xf.translated_local(Vector3(0, -0.02, -hz + 0.05)), Vector3(w + deb * 2, 0.12, 0.08), Color(0.3, 0.28, 0.25))


func _auvent(xf: Transform3D, w: float, d: float, x: float, style: Dictionary) -> void:
	var lw := minf(w, 6.5)
	var prof := 2.5
	var z0 := -d * 0.5
	var p := func(px, py, pz): return xf * Vector3(px, py, pz)
	var a: Vector3 = p.call(x - lw * 0.5, 3.0, z0)
	var b: Vector3 = p.call(x + lw * 0.5, 3.0, z0)
	var c: Vector3 = p.call(x + lw * 0.5, 2.65, z0 - prof)
	var e: Vector3 = p.call(x - lw * 0.5, 2.65, z0 - prof)
	var teinte: Color = style.get("teinte_toit", Color.WHITE)
	_quad("tole", e, c, b, a, teinte)
	_quad("tole", a, b, c, e, teinte * 0.5)
	for s in [-1.0, 1.0]:
		_boite("bois", xf.translated_local(Vector3(x + s * (lw * 0.5 - 0.15), 0, z0 - prof + 0.15)), Vector3(0.12, 2.68, 0.12), Color(0.55, 0.42, 0.3))
	# enseigne peinte
	var nom: String = style.get("enseigne", "")
	if nom != "":
		var fond: Color = VOLETS[rng.randi() % VOLETS.size()]
		var pan := xf.translated_local(Vector3(x, 3.25, z0 - 0.06))
		_boite("bois", pan, Vector3(lw * 0.9, 0.6, 0.05), fond)
		var lab := Label3D.new()
		lab.text = nom
		lab.font_size = 48
		lab.pixel_size = 0.0055
		lab.outline_size = 0
		lab.modulate = Color(0.97, 0.95, 0.88) if fond.v < 0.6 else Color(0.1, 0.08, 0.06)
		lab.width = lw * 0.88 / lab.pixel_size
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.visibility_range_end = 90.0
		lab.transform = pan.translated_local(Vector3(0, 0.3, -0.035)).rotated_local(Vector3.UP, PI)
		add_child(lab)


func _style_maison(principale: bool) -> Dictionary:
	var s := {}
	var tirage := rng.randf()
	s["brut"] = rng.randf() < (0.06 if principale else 0.14)
	s["peinture"] = PEINTURES[rng.randi() % PEINTURES.size()] * rng.randf_range(0.88, 1.04)
	s["volets"] = VOLETS[rng.randi() % VOLETS.size()]
	s["etages"] = 1
	if principale:
		s["etages"] = 2 if tirage < 0.45 else (3 if tirage < 0.55 else 1)
		s["boutique"] = rng.randf() < 0.6
	else:
		s["etages"] = 2 if tirage < 0.12 else 1
		s["boutique"] = rng.randf() < 0.1
	if s["boutique"]:
		s["enseigne"] = ENSEIGNES[rng.randi() % ENSEIGNES.size()] if rng.randf() < 0.75 else ""
	s["toit"] = "plat" if (s["etages"] > 1 and rng.randf() < 0.7) or (s["brut"] and rng.randf() < 0.6) else ("un_pan" if rng.randf() < 0.35 else "deux_pans")
	var tt := rng.randf()
	s["teinte_toit"] = Color(0.99, 0.99, 0.99) if tt < 0.28 else Color.WHITE if tt < 0.62 else (Color(0.65, 0.3, 0.25) if tt < 0.75 else (Color(0.35, 0.55, 0.45) if tt < 0.88 else Color(0.4, 0.5, 0.7)))
	return s


## Mur d'enceinte en parpaing avec portail métallique, autour d'une concession.
func _enceinte(c: Vector2, avant: Vector2, w: float, d: float, peinture: Color) -> void:
	var r := Vector2(-avant.y, avant.x)
	var coins := [c + r * (-w * 0.5) + avant * (d * 0.5), c + r * (w * 0.5) + avant * (d * 0.5),
			c + r * (w * 0.5) - avant * (d * 0.5), c + r * (-w * 0.5) - avant * (d * 0.5)]
	var brut := rng.randf() < 0.4
	for i in 4:
		var a: Vector2 = coins[i]
		var b: Vector2 = coins[(i + 1) % 4]
		var long := a.distance_to(b)
		var dir := (b - a) / long
		var morceaux := [[0.0, long]]
		if i == 0: # portail au milieu de la façade
			morceaux = [[0.0, long * 0.5 - 1.6], [long * 0.5 + 1.6, long]]
		for m in morceaux:
			var l: float = m[1] - m[0]
			if l < 0.3:
				continue
			var mid: Vector2 = a + dir * ((m[0] + m[1]) * 0.5)
			var h0 := minf(_sol(a + dir * m[0]), _sol(a + dir * m[1]))
			var xf := _repere(mid, Vector2(dir.y, -dir.x), h0 - 0.3)
			_boite("brut" if brut else "mur", xf, Vector3(l, 2.3, 0.2), peinture)
			_collision(xf, Vector3(l, 2.3, 0.2))
		if i == 0:
			var mid: Vector2 = a + dir * (long * 0.5)
			var xg := _repere(mid, Vector2(dir.y, -dir.x), _sol(mid) - 0.1)
			_boite("metal", xg, Vector3(3.1, 2.1, 0.06), VOLETS[rng.randi() % VOLETS.size()] * 0.85)


# =====================================================================
# Lotissement le long des rues et cœurs d'îlots
# =====================================================================
func _lotir(r: Dictionary) -> void:
	var pts: PackedVector2Array = r["pts"]
	var principale: bool = r["type"] == "asphalte"
	var hw: float = r["l"] * 0.5 + (2.4 if principale else 0.7)
	for cote in [-1.0, 1.0]:
		if principale and is_same(r, rues[0]) and _cote_mer(pts, cote):
			continue # côté mer du boulevard : plage, maquis et cocotiers
		var l := 0.0
		var total := 0.0
		for i in pts.size() - 1:
			total += pts[i].distance_to(pts[i + 1])
		l = rng.randf_range(2.0, 6.0)
		while l < total - 4.0:
			var w := rng.randf_range(7.5, 13.0) if principale else rng.randf_range(6.5, 11.0)
			var d := rng.randf_range(9.0, 14.0)
			var p := _point_a(pts, l + w * 0.5)
			var t := (_point_a(pts, l + w * 0.5 + 1.0) - p).normalized()
			var n: Vector2 = Vector2(-t.y, t.x) * cote
			var recul := rng.randf_range(0.3, 1.2) if principale else rng.randf_range(0.5, 3.0)
			var c: Vector2 = p + n * (hw + recul + d * 0.5)
			var avant := -n
			if _rect_libre(c, avant, w, d) and _terrain_ok(c, avant, w, d) and c.distance_to(centre) < 360.0:
				var style := _style_maison(principale)
				if not principale and rng.randf() < 0.28:
					# concession fermée : maison en retrait derrière un mur
					var ew := w + 2.0
					var ed := d + 6.0
					var ec := p + n * (hw + 0.3 + ed * 0.5)
					if _rect_libre(ec, avant, ew, ed, 0.3) and _terrain_ok(ec, avant, ew, ed):
						_prendre(ec, avant, ew, ed, 0.3)
						style["boutique"] = false
						_batiment(ec - avant * 2.0, avant, w - 1.0, d - 1.0, style)
						_enceinte(ec, avant, ew, ed, style["peinture"])
						l += ew + rng.randf_range(0.5, 2.0)
						continue
				_prendre(c, avant, w, d + (5.0 if style.get("boutique", false) else 0.0))
				_batiment(c, avant, w, d, style)
				l += w + (rng.randf_range(0.0, 0.6) if principale else rng.randf_range(0.8, 3.5))
			else:
				l += 3.0


## Vrai si ce côté de la rue est celui de la mer (ouest).
func _cote_mer(pts: PackedVector2Array, cote: float) -> bool:
	var t := (pts[pts.size() / 2 + 1] - pts[pts.size() / 2]).normalized()
	return Vector2(-t.y, t.x).x * cote < 0.0


func _point_a(pts: PackedVector2Array, l: float) -> Vector2:
	for i in pts.size() - 1:
		var s := pts[i].distance_to(pts[i + 1])
		if l <= s:
			return pts[i].lerp(pts[i + 1], l / s)
		l -= s
	return pts[pts.size() - 1]


func _remplir_ilots() -> void:
	# petites maisons et cours au cœur des îlots, alignées sur les rues voisines
	for essai in 2600:
		var c := centre + Vector2(rng.randf_range(-300, 230), rng.randf_range(-140, 200))
		var ang := rng.randf_range(-0.12, 0.12) + (PI * 0.5 * rng.randi_range(0, 3))
		var avant := Vector2(sin(ang), cos(ang))
		var w := rng.randf_range(6.0, 10.0)
		var d := rng.randf_range(7.0, 11.0)
		if _rect_libre(c, avant, w, d, 1.2) and _terrain_ok(c, avant, w, d):
			_prendre(c, avant, w, d, 1.2)
			_batiment(c, avant, w, d, _style_maison(false))
		elif rng.randf() < 0.05 and _rect_libre(c, avant, 4.0, 4.0, 2.5) and _sol(c) > 2.0:
			_prendre(c, avant, 4.0, 4.0, 1.0)
			arbres.append(c)


# =====================================================================
# Lieux de l'histoire
# =====================================================================
func _place(c: Vector2, avant: Vector2, w: float, d: float) -> Transform3D:
	_prendre(c, avant, w, d, 1.0)
	var r := Vector2(-avant.y, avant.x)
	var hmax := -INF
	for sx in [-0.5, 0.5]:
		for sz in [-0.5, 0.5]:
			hmax = maxf(hmax, _sol(c + r * (w * sx) + avant * (d * sz)))
	return _repere(c, avant, hmax + 0.2)


## Cherche près de « vise » un emplacement libre et constructible pour un grand bâtiment.
func _emplacement(vise: Vector2, avant: Vector2, w: float, d: float) -> Vector2:
	for rayon in range(0, 90, 6):
		for i in 12:
			var c := vise + Vector2(cos(i * TAU / 12.0), sin(i * TAU / 12.0)) * rayon
			if _rect_libre(c, avant, w, d, 1.0) and _terrain_ok(c, avant, w, d):
				return c
	return Vector2.INF


func _lieux() -> void:
	var bvd: PackedVector2Array = reperes["boulevard"]
	var rp: Vector2 = reperes["rond_point"]
	# Place de l'Indépendance : rond-point et obélisque
	var h := _sol(rp)
	var xf := _repere(rp, Vector2(0, 1), h + 0.15)
	_cylindre("beton", xf.origin, 5.5, 0.35, Color(0.85, 0.83, 0.78), 24)
	_cylindre("laterite", xf.origin + Vector3(0, 0.35, 0), 5.2, 0.02, Color(0.5, 0.65, 0.35), 24)
	_boite("beton", xf.translated_local(Vector3(0, 0.35, 0)), Vector3(1.6, 1.2, 1.6), Color(0.92, 0.9, 0.85))
	_cylindre("beton", xf.origin + Vector3(0, 1.55, 0), 0.55, 7.5, Color(0.95, 0.94, 0.9), 4, 0.15, PI / 4.0)
	_collision(xf, Vector3(3.0, 9.0, 3.0))
	reperes["place"] = Vector3(rp.x, h, rp.y)

	# Station-service à l'entrée nord du boulevard
	var pn := _point_a(bvd, 40.0)
	var tn := (_point_a(bvd, 41.0) - pn).normalized()
	var ns := Vector2(tn.y, -tn.x)
	if ns.x < 0.0:
		ns = -ns
	var cs := pn + ns * 18.0
	if _terrain_ok(cs, -ns, 16.0, 16.0):
		var x := _place(cs, -ns, 18.0, 18.0)
		_boite("beton", x.translated_local(Vector3(0, -0.15, 0)), Vector3(18, 0.3, 18), Color(0.8, 0.8, 0.78))
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				_boite("mur", x.translated_local(Vector3(sx * 5.0, 0, sz * 3.0 - 3.0)), Vector3(0.4, 4.8, 0.4), Color(0.92, 0.92, 0.9))
		_boite("mur", x.translated_local(Vector3(0, 4.8, -3.0)), Vector3(13, 0.7, 9), Color(0.1, 0.45, 0.3))
		_boite("ampoule", x.translated_local(Vector3(0, 4.75, -3.0)), Vector3(12, 0.05, 8))
		for sx in [-2.0, 2.0]:
			_boite("metal", x.translated_local(Vector3(sx, 0.15, -3.0)), Vector3(0.7, 1.7, 0.5), Color(0.85, 0.15, 0.12))
		_batiment(_monde_local(x, Vector3(0, 0, 5.5)), -ns, 8.0, 5.0, {"peinture": Color(0.92, 0.92, 0.9), "boutique": true, "enseigne": "TALANKÉ PÉTROLE · BOUTIQUE", "toit": "plat", "volets": VOLETS[1]})
		_collision(x.translated_local(Vector3(0, 0, -3.0)), Vector3(10, 0.2, 6))
		reperes["station"] = x.origin

	# Marché central : rangées d'étals couverts entre le boulevard et l'avenue
	var cm := _emplacement(rp + Vector2(48, -26), Vector2(0, 1), 34.0, 26.0)
	if cm != Vector2.INF:
		var x := _place(cm, Vector2(0, 1), 34.0, 26.0)
		_boite("beton", x.translated_local(Vector3(0, -0.6, 0)), Vector3(34, 0.6, 26), Color(0.75, 0.72, 0.68))
		for rang in 4:
			for i in 6:
				var px := -14.0 + i * 5.6
				var pz := -9.0 + rang * 6.0
				var t := x.translated_local(Vector3(px, 0, pz))
				_boite("bois", t, Vector3(4.2, 0.9, 1.6), Color(0.55, 0.42, 0.3))
				for s in [-1.0, 1.0]:
					for q in [-1.0, 1.0]:
						_boite("bois", t.translated_local(Vector3(s * 2.0, 0, q * 0.9)), Vector3(0.1, 2.5, 0.1), Color(0.5, 0.38, 0.28))
				var bache: Color = [Color(0.2, 0.35, 0.75), Color(0.85, 0.3, 0.15), Color(0.95, 0.75, 0.15), Color(0.2, 0.6, 0.35), Color.WHITE][rng.randi() % 5]
				var mat := "tole" if bache == Color.WHITE else "metal"
				var p := func(a, b, cc): return t * Vector3(a, b, cc)
				_quad(mat, p.call(-2.3, 2.6, -1.2), p.call(2.3, 2.6, -1.2), p.call(2.3, 2.3, 1.2), p.call(-2.3, 2.3, 1.2), bache)
				_quad(mat, p.call(-2.3, 2.6, -1.2), p.call(-2.3, 2.3, 1.2), p.call(2.3, 2.3, 1.2), p.call(2.3, 2.6, -1.2), bache * 0.6)
				# marchandises : tas de légumes, sacs, bassines
				for k in 5:
					var cc: Color = [Color(0.85, 0.2, 0.1), Color(0.95, 0.6, 0.1), Color(0.3, 0.6, 0.2), Color(0.8, 0.75, 0.6), Color(0.55, 0.3, 0.15)][rng.randi() % 5]
					_boite("mur", t.translated_local(Vector3(-1.6 + k * 0.8, 0.9, rng.randf_range(-0.3, 0.3))), Vector3(0.55, 0.22, 0.45), cc)
		reperes["marche"] = x.origin
		reperes["marche_xf"] = x

	# Gendarmerie sur l'avenue, drapeau national
	var av: PackedVector2Array = reperes["avenue"]
	var pg := _point_a(av, 95.0)
	var cg := _emplacement(pg + Vector2(0, -16), Vector2(0, 1), 18.0, 12.0)
	if cg != Vector2.INF:
		_prendre(cg, Vector2(0, 1), 18.0, 12.0, 1.0)
		_batiment(cg, Vector2(0, 1), 18.0, 11.0, {"etages": 2, "peinture": Color(0.95, 0.88, 0.62), "toit": "plat", "volets": VOLETS[0], "boutique": true, "enseigne": "GENDARMERIE NATIONALE"})
		var bm := _sol(cg + Vector2(-11, 8))
		_cylindre("metal", Vector3(cg.x - 11, bm, cg.y + 8), 0.06, 9.0, Color(0.8, 0.8, 0.8), 6)
		_drapeau(Vector3(cg.x - 11, bm + 7.6, cg.y + 8), "drapeau_wanzala")
		reperes["gendarmerie"] = Vector3(cg.x, bm, cg.y)

	# Mosquée (minaret) et église (clocher)
	var cmo := _emplacement(centre + Vector2(-70, -40), Vector2(0, 1), 17.0, 17.0)
	if cmo != Vector2.INF:
		var x := _place(cmo, Vector2(0, 1), 17.0, 17.0)
		_boite("mur", x, Vector3(15, 6.0, 15), Color(0.96, 0.96, 0.93))
		_boite("mur", x.translated_local(Vector3(0, 6.0, 0)), Vector3(15.4, 0.5, 15.4), Color(0.2, 0.55, 0.35))
		_cylindre("mur", x * Vector3(0, 6.5, 0), 3.6, 2.6, Color(0.2, 0.55, 0.35), 16, 0.4)
		for i in 5:
			_boite("sombre", x.translated_local(Vector3(-6 + i * 3.0, 0, -7.55)), Vector3(1.3, 3.2, 0.06))
		var pm := x * Vector3(6.2, 0, -6.2)
		_cylindre("mur", pm, 1.3, 19.0, Color(0.96, 0.96, 0.93), 12, 1.0)
		_cylindre("mur", pm + Vector3(0, 15.5, 0), 1.7, 0.4, Color(0.2, 0.55, 0.35), 12)
		_cylindre("mur", pm + Vector3(0, 19.0, 0), 1.05, 2.0, Color(0.2, 0.55, 0.35), 12, 0.1)
		_collision(x, Vector3(15, 6.5, 15))
		_collision(Transform3D(Basis(), pm), Vector3(2.4, 19, 2.4))
		reperes["mosquee"] = x.origin
	var ceg := _emplacement(centre + Vector2(120, 70), Vector2(0, 1), 14.0, 26.0)
	if ceg != Vector2.INF:
		var x := _place(ceg, Vector2(0, 1), 14.0, 26.0)
		_boite("mur", x, Vector3(12, 7.5, 24), Color(0.97, 0.95, 0.9))
		_toit_tole(x.translated_local(Vector3(0, 7.5, 0)).rotated_local(Vector3.UP, PI / 2.0), 24, 12, false, Color(0.7, 0.25, 0.2), Color(0.97, 0.95, 0.9), "mur")
		for i in 6:
			for s in [-1.0, 1.0]:
				_boite("vitre_nuit" if i % 2 == 0 else "vitre", x.translated_local(Vector3(s * 6.04, 2.5, -9 + i * 3.6)).rotated_local(Vector3.UP, PI / 2.0), Vector3(1.0, 3.2, 0.05))
		var cl := x.translated_local(Vector3(0, 0, -14.5))
		_boite("mur", cl, Vector3(4.2, 17.0, 4.2), Color(0.97, 0.95, 0.9))
		_boite("sombre", cl.translated_local(Vector3(0, 12.5, -2.12)), Vector3(1.4, 2.2, 0.05))
		_cylindre("tole", cl * Vector3(0, 17.0, 0), 3.0, 3.5, Color(0.7, 0.25, 0.2), 4, 0.05, PI / 4.0)
		_boite("metal", cl.translated_local(Vector3(0, 20.3, 0)), Vector3(0.12, 2.0, 0.12), Color(0.9, 0.9, 0.85))
		_boite("metal", cl.translated_local(Vector3(0, 21.3, 0)), Vector3(1.0, 0.12, 0.12), Color(0.9, 0.9, 0.85))
		_boite("bois", cl.translated_local(Vector3(0, 0, -2.13)), Vector3(1.8, 3.2, 0.06), Color(0.45, 0.28, 0.15))
		_collision(x, Vector3(12, 7.5, 24))
		_collision(cl, Vector3(4.2, 17, 4.2))
		reperes["eglise"] = x.origin

	# Maquis « Chez Mama Rokia », côté mer du boulevard : terrasse, chaises, guirlande
	var pq := _point_a(bvd, 205.0)
	var tq := (_point_a(bvd, 206.0) - pq).normalized()
	var nq := Vector2(-tq.y, tq.x)
	if nq.x > 0.0:
		nq = -nq
	var cq := pq + nq * 14.0
	var xq := _place(cq, -nq, 14.0, 10.0)
	_boite("beton", xq.translated_local(Vector3(0, -0.4, 0)), Vector3(14, 0.4, 10), Color(0.7, 0.68, 0.64))
	_batiment(_monde_local(xq, Vector3(0, 0, 3.5)), -nq, 7.0, 3.5, {"peinture": Color(0.95, 0.75, 0.2), "boutique": true, "enseigne": "MAQUIS CHEZ MAMA ROKIA", "toit": "un_pan", "volets": VOLETS[4]})
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_boite("bois", xq.translated_local(Vector3(sx * 6.3, 0, sz * 3.6 - 1.0)), Vector3(0.14, 2.8, 0.14), Color(0.5, 0.36, 0.25))
	var pz := func(a, b, c): return xq * Vector3(a, b, c)
	_quad("tole", pz.call(-6.8, 2.9, -5.0), pz.call(6.8, 2.9, -5.0), pz.call(6.8, 3.2, 2.0), pz.call(-6.8, 3.2, 2.0), Color(0.8, 0.8, 0.8))
	_quad("tole", pz.call(-6.8, 2.9, -5.0), pz.call(-6.8, 3.2, 2.0), pz.call(6.8, 3.2, 2.0), pz.call(6.8, 2.9, -5.0), Color(0.45, 0.45, 0.45))
	for i in 6: # tables et chaises en plastique
		var tx := -4.5 + (i % 3) * 4.5
		var tz := -3.6 + (i / 3) * 3.0
		var t := xq.translated_local(Vector3(tx, 0, tz))
		_boite("metal", t, Vector3(0.9, 0.72, 0.9), Color(0.95, 0.95, 0.95))
		for k in 4:
			var a := k * PI * 0.5 + rng.randf_range(-0.3, 0.3)
			_objet("plastic_monobloc_chair_01", t.translated_local(Vector3(cos(a) * 0.85, 0, sin(a) * 0.85)).rotated_local(Vector3.UP, -a - PI * 0.5))
		_objet("plastic_crate_01", t.translated_local(Vector3(0.2, 0.72, 0.1)), 1.0)
	for i in 14: # guirlande d'ampoules
		_boite("ampoule", xq.translated_local(Vector3(-6.5 + i * 1.0, 2.75 - 0.15 * sin(i / 13.0 * PI), -5.0)), Vector3(0.1, 0.12, 0.1))
	var lm := OmniLight3D.new()
	lm.light_color = Color(1.0, 0.75, 0.45)
	lm.omni_range = 11.0
	lm.position = xq * Vector3(0, 2.5, -2.0)
	add_child(lm)
	lampes.append(lm)
	_collision(xq.translated_local(Vector3(0, 0, 3.5)), Vector3(7, 3, 3.5))
	reperes["maquis"] = xq.origin

	# Maison de la famille de Faris : concession modeste dans une ruelle du sud
	var cf := _emplacement(centre + Vector2(-60, 120), Vector2(0, -1), 14.0, 18.0)
	if cf != Vector2.INF:
		_prendre(cf, Vector2(0, -1), 14.0, 18.0, 0.5)
		_batiment(cf + Vector2(0, 3.0), Vector2(0, -1), 10.0, 8.0, {"peinture": Color(0.6, 0.74, 0.82), "volets": VOLETS[0], "toit": "deux_pans"})
		_enceinte(cf, Vector2(0, -1), 14.0, 18.0, Color(0.6, 0.74, 0.82))
		arbres.append(cf + Vector2(4.5, -5.0))
		reperes["maison_faris"] = Vector3(cf.x, _sol(cf), cf.y)

	# Barrages du Cobra : sacs de sable, fûts, pneus, barrière, drapeau
	_barrage(_point_a(bvd, 12.0), (_point_a(bvd, 13.0) - _point_a(bvd, 12.0)).normalized(), 7.0)
	_barrage(_point_a(av, av.size() * 12.0 - 30.0), (_point_a(av, 200.0) - _point_a(av, 190.0)).normalized(), 6.5)


func _monde_local(xf: Transform3D, v: Vector3) -> Vector2:
	var p := xf * v
	return Vector2(p.x, p.z)


func _drapeau(p: Vector3, mat: String) -> void:
	var q := QuadMesh.new()
	q.size = Vector2(1.8, 1.2)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = mats[mat]
	mi.position = p + Vector3(0.9, 0, 0)
	add_child(mi)


func _barrage(p: Vector2, t: Vector2, demi: float) -> void:
	var n := Vector2(-t.y, t.x)
	for s in [-1.0, 1.0]:
		var c: Vector2 = p + n * s * (demi + 0.6)
		var xf := _repere(c, t, _sol(c))
		for i in 3: # murets de sacs de sable
			for k in 4 - i:
				_boite("tole", xf.translated_local(Vector3(-0.9 + k * 0.6 + i * 0.3, i * 0.28, 0)), Vector3(0.58, 0.28, 0.4), Color(0.75, 0.68, 0.5))
		_collision(xf, Vector3(2.4, 0.9, 0.6))
	var x0 := _repere(p, t, _sol(p))
	for k in 3: # fûts et pneus
		_cylindre("tole", x0 * Vector3(-demi + 1.5 + k * 0.7, 0, 2.0), 0.3, 0.9, Color(0.3, 0.45, 0.7), 10)
	for k in 3:
		_cylindre("sombre", x0 * Vector3(demi - 1.5, k * 0.22, 2.2), 0.38, 0.2, Color.WHITE, 12)
	_boite("metal", x0.translated_local(Vector3(-demi + 0.5, 0, 0)), Vector3(0.2, 1.1, 0.2), Color(0.8, 0.1, 0.1))
	_boite("metal", x0.translated_local(Vector3(0, 1.0, 0)), Vector3(demi * 2.0, 0.1, 0.1), Color(0.9, 0.9, 0.85))
	for i in 5:
		_boite("metal", x0.translated_local(Vector3(-demi + 1.2 + i * 2.6, 1.0, -0.005)), Vector3(1.2, 0.105, 0.105), Color(0.85, 0.1, 0.1))
	var pm := x0 * Vector3(demi + 2.0, 0, 1.0)
	_cylindre("metal", pm, 0.05, 5.5, Color(0.5, 0.5, 0.5), 6)
	_drapeau(pm + Vector3(0, 4.9, 0), "drapeau_cobra")
	if not reperes.has("barrages"):
		reperes["barrages"] = []
	reperes["barrages"].append(Vector3(p.x, _sol(p), p.y))
	if not reperes.has("barrages_axe"):
		reperes["barrages_axe"] = []
	reperes["barrages_axe"].append([t, demi])   # direction de la route et demi-largeur, pour poster les gardes


# =====================================================================
# Réverbères (allumés le soir et la nuit)
# =====================================================================
func _reverberes() -> void:
	for idx in 2:
		var r: Dictionary = rues[idx]
		var pts: PackedVector2Array = r["pts"]
		var total := 0.0
		for i in pts.size() - 1:
			total += pts[i].distance_to(pts[i + 1])
		var l := 8.0
		var k := 0
		while l < total - 4.0:
			var p := _point_a(pts, l)
			var t := (_point_a(pts, l + 1.0) - p).normalized()
			var n := Vector2(-t.y, t.x)
			var cote := 1.0 if (idx == 0 and n.x > 0.0) or (idx == 1 and k % 2 == 0) else -1.0
			if idx == 0 and n.x < 0.0:
				cote = -1.0
			var q: Vector2 = p + n * cote * (r["l"] * 0.5 + 0.6)
			if not _dans_autre_rue(q, r, 0.3):
				_reverbere(q, -n * cote)
			l += 26.0 if idx == 0 else 30.0
			k += 1


func _reverbere(p: Vector2, vers_route: Vector2) -> void:
	var h := _sol(p) + 0.25
	var base := Vector3(p.x, h, p.y)
	_cylindre("metal", base, 0.1, 0.5, Color(0.3, 0.3, 0.3), 8)
	_cylindre("metal", base, 0.07, 7.2, Color(0.42, 0.44, 0.45), 8, 0.05)
	var xf := _repere(p + vers_route * 0.8, Vector2(-vers_route.y, vers_route.x), h + 7.1)
	_boite("metal", xf, Vector3(1.6, 0.08, 0.08), Color(0.42, 0.44, 0.45))
	var tete := Vector3(p.x, h, p.y) + Vector3(vers_route.x, 0, vers_route.y) * 1.5 + Vector3(0, 6.95, 0)
	_boite("metal", Transform3D(xf.basis, tete), Vector3(0.6, 0.18, 0.3), Color(0.3, 0.3, 0.32))
	_boite("ampoule", Transform3D(xf.basis, tete + Vector3(0, -0.04, 0)), Vector3(0.5, 0.05, 0.24))
	var lum := OmniLight3D.new()
	lum.light_color = Color(1.0, 0.72, 0.42) # sodium, comme les lampadaires de bord de mer
	lum.omni_range = 24.0
	lum.omni_attenuation = 0.9
	lum.position = tete + Vector3(0, -0.4, 0)
	lum.visible = false
	add_child(lum)
	lampes.append(lum)


## Objet tiré des modèles Poly Haven (props/*.glb), posé au sol ou à la hauteur donnée.
func _objet(nom: String, xf: Transform3D, echelle := 1.0) -> void:
	if not objets.has(nom):
		objets[nom] = []
	objets[nom].append(xf.scaled_local(Vector3.ONE * echelle))


func _xf_sol(p: Vector2, angle: float, dy := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, angle), Vector3(p.x, _sol(p) + dy, p.y))


## Chaises, casiers, bidons, bouteilles de gaz, pneus, groupes électrogènes, sacs de ciment, poubelles.
func _mobilier() -> void:
	for b in boutiques:
		var devant: Vector2 = b[0]
		var avant: Vector2 = b[1]
		var w: float = b[2]
		var nom: String = b[3]
		var base: float = b[4]
		var r := Vector2(-avant.y, avant.x)
		var dy := base - _sol(devant + avant * 1.5)
		# deux ou trois chaises sous l'auvent
		for k in rng.randi_range(1, 3):
			var p := devant + avant * rng.randf_range(0.8, 1.8) + r * rng.randf_range(-w * 0.4, w * 0.4)
			_objet("plastic_monobloc_chair_01", _xf_sol(p, rng.randf() * TAU, 0.0))
		if rng.randf() < 0.6: # casiers de boissons empilés
			var p := devant + avant * 0.5 + r * (w * 0.35 * (1.0 if rng.randf() < 0.5 else -1.0))
			for h in rng.randi_range(1, 4):
				_objet("plastic_crate_01", _xf_sol(p, rng.randf_range(-0.1, 0.1) + atan2(avant.x, avant.y), h * 0.26))
		if nom.begins_with("ALIMENTATION") or nom.begins_with("DÉPÔT") or rng.randf() < 0.15:
			for k in rng.randi_range(2, 4):
				_objet("propane_tank", _xf_sol(devant + avant * 0.6 + r * (-w * 0.3 + k * 0.4), rng.randf() * TAU))
		if nom.begins_with("ATELIER") or nom.begins_with("QUINCAILLERIE"):
			for k in 5:
				var pt := devant + avant * 1.2 + r * (w * 0.3)
				_objet("old_tyre", Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, PI * 0.5), Vector3(pt.x, _sol(pt) + 0.08 + k * 0.17, pt.y)))
		if rng.randf() < 0.18: # groupe électrogène contre les délestages
			_objet("portable_generator", _xf_sol(devant + avant * 0.7 - r * (w * 0.45), atan2(avant.x, avant.y)))
		if rng.randf() < 0.25: # vendeur de carburant en bidons
			for k in rng.randi_range(3, 6):
				_objet("plastic_jerrycan", _xf_sol(devant + avant * 1.4 + r * (-0.6 + k * 0.32), rng.randf_range(-0.3, 0.3)))
	for c in chantiers:
		var centre_c: Vector2 = c[0]
		var avant: Vector2 = c[1]
		var p: Vector2 = centre_c + avant * (c[3] * 0.5 + 1.3)
		if bati.has(_cle(p)):
			continue
		for k in rng.randi_range(3, 8):
			_objet("cement_bag", _xf_sol(p + Vector2(k % 3, 0) * 0.5, rng.randf_range(-0.2, 0.2), (k / 3) * 0.17))
		if rng.randf() < 0.5:
			_objet("barrel_01", _xf_sol(p + avant * 1.0, 0.0))
	# poubelles le long de l'avenue et du boulevard
	for idx in 2:
		var pts: PackedVector2Array = rues[idx]["pts"]
		for k in range(2, pts.size() - 2, 5):
			var t := (pts[k + 1] - pts[k]).normalized()
			var n := Vector2(-t.y, t.x) * (1.0 if k % 2 == 0 else -1.0)
			var q: Vector2 = pts[k] + n * (rues[idx]["l"] * 0.5 + 1.8)
			if not bati.has(_cle(q)) and not _dans_autre_rue(q, rues[idx], 0.2) and _sol(q) > 1.5:
				_objet("metal_trash_can", _xf_sol(q, atan2(t.x, t.y) + PI * 0.5, 0.27), 0.55)
	# voitures bâchées à l'abandon dans quelques cours
	for k in 6:
		var c := centre + Vector2(rng.randf_range(-260, 200), rng.randf_range(-120, 180))
		var ang := rng.randf() * TAU
		var av := Vector2(sin(ang), cos(ang))
		if _rect_libre(c, av, 2.2, 4.8, 0.6) and _terrain_ok(c, av, 2.2, 4.8):
			_prendre(c, av, 2.2, 4.8, 0.3)
			_objet("covered_car", _xf_sol(c, ang))
	_poser_objets()


func _poser_objets() -> void:
	for nom in objets:
		var scene: PackedScene = load("res://props/%s.glb" % nom)
		if scene == null:
			continue
		var modele := scene.instantiate()
		add_child(modele) # temporaire, pour connaître les transformations des maillages
		var maillages := modele.find_children("*", "MeshInstance3D", true, false)
		var bas := INF
		for mi in maillages:
			var aabb: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			bas = minf(bas, aabb.position.y)
		var liste: Array = objets[nom]
		for mi in maillages:
			var m := mi as MeshInstance3D
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = m.mesh
			mm.instance_count = liste.size()
			var local := Transform3D(Basis(), Vector3(0, -bas, 0)) * m.global_transform
			for i in liste.size():
				mm.set_instance_transform(i, (liste[i] as Transform3D) * local)
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "Objets_" + nom
			mmi.multimesh = mm
			add_child(mmi)
		modele.queue_free()


## Poteaux en bois et fils électriques qui pendent le long des ruelles.
func _ligne_electrique(r: Dictionary) -> void:
	var pts: PackedVector2Array = r["pts"]
	var total := 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	var l := rng.randf_range(4.0, 12.0)
	var tetes: Array = []
	while l < total:
		var p := _point_a(pts, l)
		var t := (_point_a(pts, l + 1.0) - p).normalized()
		var q: Vector2 = p + Vector2(-t.y, t.x) * (r["l"] * 0.5 + 0.9)
		if not _dans_autre_rue(q, r, 0.4) and _sol(q) > 1.5:
			var h := _sol(q) - 0.3
			var penche := Vector3(rng.randf_range(-0.03, 0.03), 0, rng.randf_range(-0.03, 0.03))
			_cylindre("bois", Vector3(q.x, h, q.y), 0.13, 8.8, Color(0.42, 0.33, 0.24), 7, 0.1)
			var xf := _repere(q, Vector2(-t.y, t.x), h + 8.1)
			_boite("bois", xf, Vector3(1.6, 0.12, 0.12), Color(0.38, 0.3, 0.22))
			var haut := Vector3(q.x, h + 8.2, q.y) + penche
			tetes.append([haut, xf.basis.x.normalized()])
		else:
			tetes.append(null)
		l += rng.randf_range(32.0, 40.0)
	for i in tetes.size() - 1:
		if tetes[i] == null or tetes[i + 1] == null:
			continue
		for k in 3: # trois fils, avec la flèche (le « ventre ») des câbles
			var a: Vector3 = tetes[i][0] + tetes[i][1] * (-0.7 + k * 0.7)
			var b: Vector3 = tetes[i + 1][0] + tetes[i + 1][1] * (-0.7 + k * 0.7)
			var prec := a
			for s in range(1, 9):
				var u := s / 8.0
				var q := a.lerp(b, u) - Vector3(0, 0.9 * 4.0 * u * (1.0 - u), 0)
				var mid := (prec + q) * 0.5
				var d := q - prec
				var xf := Transform3D(Basis.looking_at(d.normalized(), Vector3.UP), mid).rotated_local(Vector3.RIGHT, PI / 2.0)
				_boite("sombre", xf.translated_local(Vector3(0, -d.length() * 0.5, 0)), Vector3(0.025, d.length(), 0.025))
				prec = q


## f : 0 = plein jour, 1 = nuit noire (appelé par les ambiances pendant les fondus).
func regler_nuit(f: float) -> void:
	for l in lampes:
		(l as OmniLight3D).visible = f > 0.05
		(l as OmniLight3D).light_energy = 9.0 * f
	(mats["ampoule"] as StandardMaterial3D).emission_energy_multiplier = 0.15 + 4.0 * f
	(mats["vitre_nuit"] as StandardMaterial3D).emission_energy_multiplier = 2.2 * f


# =====================================================================
# Arbres et cocotiers de la ville
# =====================================================================
func _vegetation(veg: Vegetation) -> void:
	if veg == null:
		return
	# cocotiers le long de la plage, côté mer du boulevard
	var bvd: PackedVector2Array = reperes["boulevard"]
	var total := 0.0
	for i in bvd.size() - 1:
		total += bvd[i].distance_to(bvd[i + 1])
	var l := 10.0
	var pts := []
	while l < total:
		var p := _point_a(bvd, l)
		var t := (_point_a(bvd, l + 1.0) - p).normalized()
		var n := Vector2(-t.y, t.x)
		if n.x > 0.0:
			n = -n
		var q := p + n * rng.randf_range(10.0, 16.0)
		if _sol(q) > 0.8 and not occupe.has(_cle(q)):
			pts.append(q)
		l += rng.randf_range(12.0, 20.0)
	var maillage: ArrayMesh = veg._maillage_palmier(rng, 14)
	for q in pts:
		var mi := MeshInstance3D.new()
		mi.mesh = maillage
		var s := rng.randf_range(0.9, 1.2)
		mi.transform = Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(q.x, _sol(q) - 0.3, q.y))
		mi.visibility_range_end = DISTANCE_VUE
		add_child(mi)
	# grands arbres d'ombre (manguiers, nérés) dans les cours
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/arbres/arbres.json"))
	var mesh := veg._maillage_imposteur(meta["island_tree_01"])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = arbres.size()
	for i in arbres.size():
		var c: Vector2 = arbres[i]
		var s := rng.randf_range(1.6, 2.4)
		var xa := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(c.x, _sol(c) - 0.2, c.y))
		var ca := Color(rng.randf_range(0.85, 1.0), rng.randf_range(0.9, 1.0), rng.randf_range(0.85, 1.0))
		mm.set_instance_transform(i, xa)
		mm.set_instance_color(i, ca)
		if veg.proche:
			veg.proche.ajouter_arbre("island_tree_01", xa, ca)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "ArbresVille"
	mmi.multimesh = mm
	add_child(mmi)

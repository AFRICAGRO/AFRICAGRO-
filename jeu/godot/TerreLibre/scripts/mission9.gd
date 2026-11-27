## Mission 9 — « Le Chenal » (voir jeu/missions/09-LE-CHENAL.md).
## Après Tikané : Joël capte un message codé du Cobra, un chargement part ce soir vers la baie du Sud.
## - La mangrove de la baie du Sud (créée ici sur le relief) : îlots de vase, palétuviers sur leurs
##   racines-échasses, chenaux étroits, clapotis, grenouilles et moustiques.
## - Ama attend dans la pirogue, moteur coupé : on suit la barge à la perche, à distance (25 à 60 m).
##   Trop près : les contrebandiers allument le projecteur ; trop loin : la barge disparaît.
## - La marée monte : le banc de vase du raccourci se couvre, l'arche de racines de l'ouest se ferme.
## - L'appareil photo du téléphone (K, clic pour photographier) : le marquage des sacs, le visage de
##   l'acheteur, le numéro du navire qui attend au large.
## - La cabane sur pilotis : écouter sous le plancher, puis voler le registre (discrétion) ou attaquer
##   (combat sur pilotis, le registre peut tomber à l'eau).
class_name Mission9
extends Node3D

enum Phase { INDISPONIBLE, DISPONIBLE, ATTENTE, FILATURE, CABANE, TERMINEE }
const DIST_MIN := 25.0
const DIST_MAX := 60.0
const VITESSE_BARGE := 1.9
const MAREE_DUREE := 420.0
const PLANCHER := 2.6

# --- plan de la mangrove (coordonnées du monde, en mètres) ---
const ROUTE := [Vector2(700, 2390), Vector2(640, 2320), Vector2(560, 2265), Vector2(520, 2320), Vector2(430, 2345),
	Vector2(330, 2330), Vector2(250, 2300), Vector2(180, 2262), Vector2(110, 2228), Vector2(62, 2196)]
const RACCOURCI := [Vector2(560, 2265), Vector2(470, 2262), Vector2(400, 2285), Vector2(330, 2330)]
const CRIQUE_RDV := [Vector2(560, 2265), Vector2(520, 2225), Vector2(478, 2200)]
const CRIQUE_OUEST := [Vector2(110, 2228), Vector2(50, 2250), Vector2(-10, 2228), Vector2(-20, 2195), Vector2(20, 2172)]
const ZONES := [Rect2(-250, 2150, 500, 195), Rect2(250, 2255, 190, 95), Rect2(430, 2150, 260, 175)]
const CABANE := Vector2(36, 2180)
const BANC := Vector2(470, 2262)
const ARCHE := Vector2(-15, 2212)
const NAVIRE := Vector2(260, 2640)
const PAUSES := [3, 6]          # points de la route où la barge s'arrête pour écouter

var phase := Phase.INDISPONIBLE
var main: Node
var joueur: Joueur
var m4: Mission4
var terrain: Terrain
var pirogue: PirogueJoueur
var ama: Node3D
var barge: Node3D
var projecteur: SpotLight3D
var moteur: AudioStreamPlayer3D
var sacs: Node3D
var route: PackedVector2Array
var l_route := 0.0           # abscisse de la barge le long de la route (m)
var t_pause := 0.0
var pauses_faites: Array = []
var soupcon := 0.0
var t_perdu := 0.0
var vue_une_fois := false     # la barge est passée devant la cachette : la filature commence vraiment
var maree := 0.0
var t_maree := 0.0
var banc: MeshInstance3D
var arche: Node3D
var annonce_banc := false
var annonce_arche := false
var navire: Node3D
var numero: Label3D
var cabane: Node3D
var registre: MeshInstance3D
var registre_a_l_eau := false
var t_registre := 0.0
var registre_pris := false
var gardes: Array = []
var acheteur: Pnj
var vedette: Node3D
var t_cabane := 0.0
var ecoute := 0
var t_ecoute := 0.0
var ecoute_finie := false
var acheteur_parti := false
var combat := false
var photos := {"sacs": false, "acheteur": false, "navire": false}
var viseur: Control
var etiquette_viseur: Label
var jauge: ProgressBar
var etiquette_jauge: Label
var t_reprise := 0.0
var t_hud := 0.0
var amb_son: AudioStreamPlayer3D

const DIALOGUE := [
	["ACHETEUR", "Le Patron des Docks veut le double le mois prochain. Il y a un client à la capitale qui pose des questions."],
	["CONTREBANDIER", "Le Commandant dit que c'est déjà le maximum. Il y a ce type, le fils de Samuel, qui fout le bazar sur l'île."],
	["ACHETEUR", "Alors réglez votre problème. Le ministère n'aime pas les problèmes."],
]


# ---------------------------------------------------------------------
# Plan : avant la construction du terrain, on creuse les chenaux et on pose les îlots de vase.
# ---------------------------------------------------------------------
static func preparer_plan() -> Dictionary:
	var d := Terrain.lire_donnees()
	var pf: Array = []
	var chenaux := [ROUTE, RACCOURCI, CRIQUE_RDV, CRIQUE_OUEST]
	# îlots : la vase affleure (+0,3 m), seulement là où il y avait de l'eau peu profonde
	for z in ZONES:
		var r := z as Rect2
		var x := r.position.x
		while x <= r.end.x:
			var y := r.position.y
			while y <= r.end.y:
				var q := Vector2(x, y)
				var h := Terrain.hauteur_brute(d, q.x, q.y)
				# bords déchiquetés et quelques mares : pas d'îlots au cordeau
				var irreg := _bord_zone(q) + _bruit(q) * 22.0
				if h < 0.8 and h > -4.5 and _dist_chenaux(q, chenaux) > 18.0 and irreg > 10.0 and _bruit(q * 1.7) > -0.85:
					pf.append({"centre": q, "rayon": 8.0, "h": 0.3})
				y += 16.0
			x += 16.0
	# chenaux : 1,6 m d'eau au milieu, creusés après les îlots
	for c in chenaux:
		var pts := c as Array
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var nb := maxi(1, int(a.distance_to(b) / 8.0))
			for k in nb + 1:
				var q := a.lerp(b, float(k) / nb)
				if Terrain.hauteur_brute(d, q.x, q.y) > -1.6:
					pf.append({"centre": q, "rayon": 9.0, "h": -1.6})
	# sous la cabane : un fond de vase où plantent les pilotis
	pf.append({"centre": CABANE, "rayon": 9.0, "h": -0.9})
	return {"plateformes": pf}


static func _dist_chenaux(q: Vector2, chenaux: Array) -> float:
	var best := INF
	for c in chenaux:
		var pts := c as Array
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var ab := b - a
			var t := clampf((q - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
			best = minf(best, q.distance_to(a + ab * t))
	return best


## Distance au bord de la mangrove (le plus grand des rectangles qui contiennent le point).
static func _bord_zone(q: Vector2) -> float:
	var best := -INF
	for z in ZONES:
		var r := z as Rect2
		best = maxf(best, minf(minf(q.x - r.position.x, r.end.x - q.x), minf(q.y - r.position.y, r.end.y - q.y)))
	return best


## Bruit doux et déterministe (même résultat à chaque lancement), entre -1,5 et 1,5 environ.
static func _bruit(q: Vector2) -> float:
	return sin(q.x * 0.031 + 1.3) * cos(q.y * 0.027 - 0.4) + 0.5 * sin((q.x + q.y) * 0.053) + 0.3 * cos((q.x - q.y) * 0.091)


# ---------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------
func construire(p_main: Node) -> void:
	main = p_main
	joueur = main.joueur
	m4 = main.get_node("Mission4")
	terrain = main.terrain
	var mat := terrain.materiau() as ShaderMaterial
	if mat:
		mat.set_shader_parameter("zone_vase", Vector4(-250, 2150, 690, 2350))
	route = _reechantillonner(ROUTE, 3.0)
	_paletuviers()
	_banc_et_arche()
	_cabane()
	_navire()
	_barge()
	_pirogue_rdv()
	_interface()
	amb_son = AudioStreamPlayer3D.new()
	var s: AudioStreamWAV = load("res://sons/mangrove.wav")
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_end = int(s.get_length() * s.mix_rate)
	amb_son.stream = s
	amb_son.unit_size = 60.0
	amb_son.max_distance = 420.0
	amb_son.volume_db = -4.0
	add_child(amb_son)
	amb_son.global_position = Vector3(300, 3, 2260)
	amb_son.play()
	joueur.tombe.connect(_tombe)
	joueur.a_tire.connect(func(p: Vector3) -> void:
		if phase == Phase.CABANE:
			bruit_de_tir(p, true))
	# la marée bloque ou ouvre des passages pour toutes les pirogues de l'île
	for n in main.get_children():
		if n is PirogueJoueur:
			(n as PirogueJoueur).obstacles.append(_bloque)


func _reechantillonner(pts: Array, pas: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var nb := maxi(1, int(a.distance_to(b) / pas))
		for k in nb:
			out.append(a.lerp(b, float(k) / nb))
	out.append(pts[pts.size() - 1])
	# lissage (Chaikin) pour des courbes de chenal naturelles
	for _passe in 2:
		var lisse := PackedVector2Array([out[0]])
		for i in out.size() - 1:
			lisse.append(out[i].lerp(out[i + 1], 0.25))
			lisse.append(out[i].lerp(out[i + 1], 0.75))
		lisse.append(out[out.size() - 1])
		out = lisse
	return out


func _point_route(l: float) -> Vector2:
	var reste := l
	for i in route.size() - 1:
		var seg := route[i].distance_to(route[i + 1])
		if reste <= seg:
			return route[i].lerp(route[i + 1], reste / maxf(seg, 0.001))
		reste -= seg
	return route[route.size() - 1]


func _longueur_route() -> float:
	var l := 0.0
	for i in route.size() - 1:
		l += route[i].distance_to(route[i + 1])
	return l


## Palétuviers : racines-échasses arquées, tronc grêle, houppier sombre. Trois modèles, posés par
## morceaux de 160 m (chaque morceau a sa portée de visibilité, pour les petites cartes graphiques).
func _paletuviers() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	var modeles: Array = []
	for k in 3:
		modeles.append(_maillage_paletuvier(rng))
	var chenaux := [ROUTE, RACCOURCI, CRIQUE_RDV, CRIQUE_OUEST]
	var morceaux := {}
	for z in ZONES:
		var r := z as Rect2
		var x := r.position.x
		while x <= r.end.x:
			var y := r.position.y
			while y <= r.end.y:
				var q := Vector2(x + rng.randf_range(-4, 4), y + rng.randf_range(-4, 4))
				var h := terrain.hauteur(q.x, q.y)
				var dc := _dist_chenaux(q, chenaux)
				# sur la vase, ou en lisière des chenaux, racines dans l'eau
				if h > -0.9 and h < 1.4 and dc > 11.0 and q.distance_to(CABANE) > 14.0 and _bord_zone(q) + _bruit(q) * 22.0 > 4.0:
					var cle := Vector2i(int(floor(q.x / 160.0)), int(floor(q.y / 160.0)))
					if not morceaux.has(cle):
						morceaux[cle] = [[], [], []]
					var s := rng.randf_range(0.8, 1.25)
					var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.15), s)),
							Vector3(q.x, minf(h, 0.3) - 0.1, q.y))
					(morceaux[cle][rng.randi() % 3] as Array).append(xf)
				y += 9.0
			x += 9.0
	var nb := 0
	for cle in morceaux:
		for k in 3:
			var liste: Array = morceaux[cle][k]
			if liste.is_empty():
				continue
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = modeles[k]
			mm.instance_count = liste.size()
			for i in liste.size():
				mm.set_instance_transform(i, liste[i])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.visibility_range_end = 520.0
			mmi.visibility_range_end_margin = 40.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			add_child(mmi)
			nb += liste.size()
	print("Mangrove : %d palétuviers" % nb)


func _maillage_paletuvier(rng: RandomNumberGenerator) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ecorce := Color(0.34, 0.29, 0.24)
	var haut := rng.randf_range(4.0, 5.5)
	var penche := Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3))
	_tube(st, [Vector3(0, 1.3, 0), Vector3(0, haut * 0.6, 0) + penche * 0.5, Vector3(0, haut, 0) + penche], 0.11, 0.07, ecorce)
	# racines-échasses : arcs du tronc jusqu'à la vase, tout autour
	var nr := rng.randi_range(7, 10)
	for i in nr:
		var a := TAU * i / nr + rng.randf_range(-0.25, 0.25)
		var dir := Vector3(cos(a), 0, sin(a))
		var depart := Vector3(0, rng.randf_range(1.2, 2.0), 0) + dir * 0.06
		var rayon := rng.randf_range(1.1, 1.9)
		var pts: Array = []
		for k in 6:
			var t := k / 5.0
			# arc : sort du tronc presque à l'horizontale, plonge vers la vase
			var p := depart + dir * rayon * sin(t * PI * 0.5) + Vector3(0, -depart.y * (1.0 - cos(t * PI * 0.5)) - 0.15 * t, 0)
			pts.append(p)
		_tube(st, pts, 0.045, 0.03, ecorce * rng.randf_range(0.85, 1.1))
	# branches et houppier : quelques masses de feuillage vert sombre et luisant
	for i in rng.randi_range(4, 6):
		var a := rng.randf() * TAU
		var c := Vector3(0, haut, 0) + penche + Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.6, 1.8) + Vector3(0, rng.randf_range(-0.6, 0.7), 0)
		_tube(st, [Vector3(0, haut * 0.8, 0) + penche * 0.8, c], 0.05, 0.03, ecorce)
		var vert := Color(0.13, 0.27, 0.12) * rng.randf_range(0.8, 1.2)
		_boule(st, c, Vector3(rng.randf_range(1.7, 2.5), rng.randf_range(0.8, 1.2), rng.randf_range(1.7, 2.5)), vert)
	st.generate_normals()
	var mesh := st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.75
	mesh.surface_set_material(0, m)
	return mesh


func _tube(st: SurfaceTool, pts: Array, r0: float, r1: float, couleur: Color) -> void:
	var cotes := 5
	var anneaux: Array = []
	for i in pts.size():
		var p: Vector3 = pts[i]
		var av: Vector3 = (pts[mini(i + 1, pts.size() - 1)] as Vector3) - (pts[maxi(i - 1, 0)] as Vector3)
		av = av.normalized() if av.length() > 0.001 else Vector3.UP
		var x := av.cross(Vector3.UP if absf(av.y) < 0.95 else Vector3.RIGHT).normalized()
		var y := av.cross(x).normalized()
		var r := lerpf(r0, r1, float(i) / maxf(1.0, pts.size() - 1.0))
		var anneau: Array = []
		for k in cotes:
			var a := TAU * k / cotes
			anneau.append(p + (x * cos(a) + y * sin(a)) * r)
		anneaux.append(anneau)
	st.set_color(couleur)
	for i in anneaux.size() - 1:
		for k in cotes:
			var a: Vector3 = anneaux[i][k]
			var b: Vector3 = anneaux[i][(k + 1) % cotes]
			var c: Vector3 = anneaux[i + 1][(k + 1) % cotes]
			var e: Vector3 = anneaux[i + 1][k]
			st.add_vertex(a)
			st.add_vertex(e)
			st.add_vertex(c)
			st.add_vertex(a)
			st.add_vertex(c)
			st.add_vertex(b)


func _boule(st: SurfaceTool, c: Vector3, r: Vector3, couleur: Color) -> void:
	var anneaux := 4
	var cotes := 7
	st.set_color(couleur)
	var pts: Array = []
	for i in anneaux + 1:
		var phi := PI * float(i) / anneaux
		var ligne: Array = []
		for k in cotes:
			var th := TAU * k / cotes
			var bosse := 1.0 + 0.12 * sin(th * 3.0 + phi * 2.0)
			ligne.append(c + Vector3(sin(phi) * cos(th) * r.x, cos(phi) * r.y, sin(phi) * sin(th) * r.z) * bosse)
		pts.append(ligne)
	for i in anneaux:
		for k in cotes:
			var a: Vector3 = pts[i][k]
			var b: Vector3 = pts[i][(k + 1) % cotes]
			var e: Vector3 = pts[i + 1][k]
			var f: Vector3 = pts[i + 1][(k + 1) % cotes]
			st.add_vertex(a)
			st.add_vertex(b)
			st.add_vertex(f)
			st.add_vertex(a)
			st.add_vertex(f)
			st.add_vertex(e)


func _boite(taille: Vector3, xf: Transform3D, couleur: Color, parent: Node3D = null, rugosite := 0.85) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = taille
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = couleur
	m.roughness = rugosite
	mi.material_override = m
	(parent if parent else self).add_child(mi)
	mi.transform = xf
	return mi


func _solide(taille: Vector3, xf: Transform3D, parent: Node3D) -> void:
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = taille
	cs.shape = bs
	sb.add_child(cs)
	parent.add_child(sb)
	sb.transform = xf


## Le banc de vase du raccourci (la marée le couvre) et l'arche de racines de la crique de l'ouest
## (la marée la ferme).
func _banc_et_arche() -> void:
	banc = MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 11.0
	cy.bottom_radius = 13.0
	cy.height = 0.6
	cy.radial_segments = 20
	banc.mesh = cy
	var vase := StandardMaterial3D.new()
	vase.albedo_color = Color(0.22, 0.18, 0.13)
	vase.roughness = 0.35        # vase mouillée, luisante
	banc.material_override = vase
	add_child(banc)
	banc.global_position = Vector3(BANC.x, 0.05, BANC.y)
	arche = Node3D.new()
	add_child(arche)
	arche.global_position = Vector3(ARCHE.x, 0.0, ARCHE.y)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	for i in 9:
		var x0 := rng.randf_range(-6, 6)
		var pts: Array = []
		for k in 7:
			var t := k / 6.0
			pts.append(Vector3(x0 + rng.randf_range(-0.3, 0.3), 1.45 * sin(t * PI), -9.0 + 18.0 * t))
		_tube(st, pts, 0.09, 0.07, Color(0.3, 0.25, 0.2))
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.8
	mi.material_override = m
	arche.add_child(mi)
	var dir := (CRIQUE_OUEST[2] as Vector2) - (CRIQUE_OUEST[1] as Vector2)
	arche.rotation.y = atan2(dir.x, dir.y) + PI * 0.5


func _bloque(q: Vector2) -> bool:
	if q.distance_to(BANC) < 12.0 and maree < 0.55:
		return true
	if q.distance_to(ARCHE) < 8.0 and maree > 0.72:
		return true
	return false


func _cabane() -> void:
	cabane = Node3D.new()
	add_child(cabane)
	var vers_chenal := (ROUTE[ROUTE.size() - 1] as Vector2) - CABANE
	cabane.global_transform = Transform3D(Basis(Vector3.UP, atan2(vers_chenal.x, vers_chenal.y)), Vector3(CABANE.x, 0.0, CABANE.y))
	var bois := Color(0.42, 0.34, 0.26)
	var gris := Color(0.5, 0.47, 0.42)
	# pilotis : 3 x 3 troncs plantés dans la vase
	for i in 3:
		for k in 3:
			_boite(Vector3(0.22, PLANCHER + 1.6, 0.22), Transform3D(Basis(), Vector3(-3.4 + i * 3.4, PLANCHER * 0.5 - 0.8, -2.6 + k * 2.6)), gris, cabane)
	# plancher (on y marche ; on s'y cache dessous) et terrasse côté chenal
	_boite(Vector3(8.0, 0.16, 6.2), Transform3D(Basis(), Vector3(0, PLANCHER, 0)), bois, cabane)
	_solide(Vector3(8.0, 0.16, 6.2), Transform3D(Basis(), Vector3(0, PLANCHER, 0)), cabane)
	_boite(Vector3(8.0, 0.14, 2.6), Transform3D(Basis(), Vector3(0, PLANCHER, 4.4)), bois * 0.9, cabane)
	_solide(Vector3(8.0, 0.14, 2.6), Transform3D(Basis(), Vector3(0, PLANCHER, 4.4)), cabane)
	# murs de planches (une porte côté terrasse), toit de tôle rouillée
	for s in [-1.0, 1.0]:
		_boite(Vector3(0.08, 2.3, 6.2), Transform3D(Basis(), Vector3(s * 3.96, PLANCHER + 1.2, 0)), bois * 0.95, cabane)
		_solide(Vector3(0.08, 2.3, 6.2), Transform3D(Basis(), Vector3(s * 3.96, PLANCHER + 1.2, 0)), cabane)
	_boite(Vector3(8.0, 2.3, 0.08), Transform3D(Basis(), Vector3(0, PLANCHER + 1.2, -3.06)), bois * 0.95, cabane)
	_solide(Vector3(8.0, 2.3, 0.08), Transform3D(Basis(), Vector3(0, PLANCHER + 1.2, -3.06)), cabane)
	for s in [-1.0, 1.0]:
		_boite(Vector3(2.9, 2.3, 0.08), Transform3D(Basis(), Vector3(s * 2.55, PLANCHER + 1.2, 3.06)), bois * 0.9, cabane)
		_solide(Vector3(2.9, 2.3, 0.08), Transform3D(Basis(), Vector3(s * 2.55, PLANCHER + 1.2, 3.06)), cabane)
	_boite(Vector3(9.0, 0.06, 9.4), Transform3D(Basis(Vector3.RIGHT, 0.12), Vector3(0, PLANCHER + 2.65, 1.0)), Color(0.48, 0.3, 0.2), cabane, 0.6)
	# rampe de planches de la vase jusqu'à la terrasse (côté ouest)
	var rampe := Transform3D(Basis(Vector3.FORWARD, -0.42), Vector3(-6.4, PLANCHER * 0.5 - 0.1, 4.4))
	_boite(Vector3(6.3, 0.1, 1.2), rampe, bois * 0.85, cabane)
	_solide(Vector3(6.3, 0.12, 1.2), rampe, cabane)
	# table, chaise, lampe tempête et le registre
	_boite(Vector3(1.4, 0.06, 0.8), Transform3D(Basis(), Vector3(1.6, PLANCHER + 0.82, -1.6)), bois * 1.1, cabane)
	for dx in [-0.6, 0.6]:
		for dz in [-0.3, 0.3]:
			_boite(Vector3(0.06, 0.8, 0.06), Transform3D(Basis(), Vector3(1.6 + dx, PLANCHER + 0.42, -1.6 + dz)), bois, cabane)
	registre = _boite(Vector3(0.24, 0.05, 0.32), Transform3D(Basis(Vector3.UP, 0.3), Vector3(1.4, PLANCHER + 0.88, -1.55)), Color(0.32, 0.12, 0.08), cabane, 0.6)
	var lampe := OmniLight3D.new()
	lampe.light_color = Color(1.0, 0.66, 0.32)
	lampe.light_energy = 1.6
	lampe.omni_range = 9.0
	lampe.position = Vector3(1.9, PLANCHER + 1.1, -1.7)
	cabane.add_child(lampe)
	_boite(Vector3(0.12, 0.2, 0.12), Transform3D(Basis(), Vector3(1.9, PLANCHER + 0.95, -1.7)), Color(1.0, 0.8, 0.4), cabane)
	# lampe tempête pendue au bord du toit, au-dessus de la terrasse
	var lampe2 := OmniLight3D.new()
	lampe2.light_color = Color(1.0, 0.68, 0.34)
	lampe2.light_energy = 1.8
	lampe2.omni_range = 10.0
	lampe2.position = Vector3(0.3, PLANCHER + 2.1, 3.6)
	cabane.add_child(lampe2)
	_boite(Vector3(0.14, 0.22, 0.14), Transform3D(Basis(), Vector3(0.3, PLANCHER + 2.0, 3.6)), Color(1.0, 0.8, 0.4), cabane)
	# sacs déjà déchargés sur la terrasse
	for i in 5:
		_boite(Vector3(0.8, 0.35, 0.5), Transform3D(Basis(Vector3.UP, randf_range(-0.2, 0.2)), Vector3(-2.5 + (i % 3) * 0.85, PLANCHER + 0.25 + floorf(i / 3.0) * 0.35, 4.6)), Color(0.78, 0.72, 0.58), cabane)


func _navire() -> void:
	# caboteur au mouillage, feux de position ; son numéro sur la coque
	navire = Node3D.new()
	add_child(navire)
	navire.global_transform = Transform3D(Basis(Vector3.UP, 0.4), Vector3(NAVIRE.x, 0.0, NAVIRE.y))
	_boite(Vector3(9.0, 4.2, 38.0), Transform3D(Basis(), Vector3(0, 0.6, 0)), Color(0.16, 0.22, 0.24), navire, 0.6)
	_boite(Vector3(9.1, 0.5, 38.1), Transform3D(Basis(), Vector3(0, 2.6, 0)), Color(0.55, 0.12, 0.08), navire, 0.6)
	_boite(Vector3(7.0, 4.5, 8.0), Transform3D(Basis(), Vector3(0, 5.0, -12.0)), Color(0.85, 0.85, 0.8), navire, 0.6)
	_boite(Vector3(0.4, 9.0, 0.4), Transform3D(Basis(), Vector3(0, 7.0, 8.0)), Color(0.4, 0.4, 0.4), navire)
	for i in 3:
		_boite(Vector3(2.4, 2.4, 6.0), Transform3D(Basis(), Vector3(0, 4.0, 4.0 + i * 6.4)), [Color(0.6, 0.2, 0.15), Color(0.2, 0.35, 0.5), Color(0.55, 0.5, 0.2)][i], navire)
	numero = Label3D.new()
	numero.text = "LGV 2047\nLAGUNAVILLE"
	numero.font_size = 160
	numero.pixel_size = 0.01
	numero.modulate = Color(0.92, 0.92, 0.88)
	numero.outline_size = 0
	numero.transform = Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-4.6, 1.2, 12.0))
	navire.add_child(numero)
	for p in [Vector3(0, 9.0, 8.0), Vector3(0, 7.5, -12.0), Vector3(0, 3.5, 19.0)]:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.92, 0.7)
		l.light_energy = 2.0
		l.omni_range = 16.0
		l.position = p
		navire.add_child(l)


func _barge() -> void:
	barge = Node3D.new()
	add_child(barge)
	var coque := Color(0.2, 0.17, 0.14)
	_boite(Vector3(2.6, 0.9, 10.0), Transform3D(Basis(), Vector3(0, 0.15, 0)), coque, barge)
	_boite(Vector3(2.7, 0.12, 10.1), Transform3D(Basis(), Vector3(0, 0.62, 0)), Color(0.45, 0.38, 0.28), barge)
	_boite(Vector3(0.45, 1.0, 0.5), Transform3D(Basis(), Vector3(0, 0.55, -5.2)), Color(0.12, 0.12, 0.12), barge, 0.4)   # moteur hors-bord
	sacs = Node3D.new()
	barge.add_child(sacs)
	sacs.position = Vector3(0, 0.75, 1.2)
	for i in 12:
		@warning_ignore("integer_division")
		var etage := i / 6
		_boite(Vector3(0.95, 0.38, 0.6), Transform3D(Basis(Vector3.UP, randf_range(-0.15, 0.15)),
				Vector3(-0.5 + (i % 2) * 1.0, 0.2 + etage * 0.38, -1.6 + floorf((i % 6) / 2.0) * 0.75)), Color(0.8, 0.74, 0.6), sacs)
	var marque := Label3D.new()
	marque.text = "S.P.L.\nLAGUNAVILLE\n50 KG"
	marque.font_size = 40
	marque.pixel_size = 0.004
	marque.modulate = Color(0.12, 0.18, 0.4)
	marque.outline_size = 0
	marque.transform = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(1.0, 0.25, -0.5))
	sacs.add_child(marque)
	var vq: Node = main.get_node_or_null("VieQuotidienne")
	if vq:
		var pilote: Node3D = vq._perso("homme3", "Assis", Vector3.ZERO, PI)
		pilote.reparent(barge)
		pilote.position = Vector3(0, 0.62, -4.2)
		pilote.rotation = Vector3(0, PI, 0)
		var guetteur: Node3D = vq._perso("villageois", "Repos", Vector3.ZERO, 0.0)
		guetteur.reparent(barge)
		guetteur.position = Vector3(0.4, 0.66, 3.6)
		guetteur.rotation = Vector3(0, PI, 0)   # il regarde vers l'arrière, vers le sillage
	var lanterne := OmniLight3D.new()
	lanterne.light_color = Color(1.0, 0.7, 0.35)
	lanterne.light_energy = 1.2
	lanterne.omni_range = 10.0
	lanterne.position = Vector3(0, 1.6, -3.4)
	barge.add_child(lanterne)
	projecteur = SpotLight3D.new()
	projecteur.light_color = Color(0.95, 0.97, 1.0)
	projecteur.light_energy = 0.0
	projecteur.spot_range = 70.0
	projecteur.spot_angle = 14.0
	projecteur.shadow_enabled = false
	projecteur.position = Vector3(0, 2.2, 3.8)
	barge.add_child(projecteur)
	moteur = AudioStreamPlayer3D.new()
	moteur.stream = load("res://sons/moto.wav")
	moteur.pitch_scale = 0.55
	moteur.unit_size = 10.0
	moteur.max_distance = 160.0
	moteur.volume_db = -8.0
	barge.add_child(moteur)
	barge.visible = false


func _pirogue_rdv() -> void:
	var vq: VieQuotidienne = main.get_node("VieQuotidienne")
	pirogue = PirogueJoueur.new()
	pirogue.name = "PirogueAma"
	main.add_child(pirogue)
	var p: Vector2 = CRIQUE_RDV[CRIQUE_RDV.size() - 1]
	var dir: Vector2 = (CRIQUE_RDV[1] as Vector2) - p
	pirogue.preparer(joueur, terrain, terrain.lits, vq._pirogue_maillage(), p, atan2(dir.x, dir.y))
	pirogue.obstacles.append(_bloque)
	# Ama, assise à l'avant de la pirogue
	ama = vq._perso("femme", "Assis", Vector3.ZERO, 0.0)
	ama.reparent(pirogue.assiette)
	ama.position = Vector3(0, 0.08, 1.7)
	ama.rotation = Vector3.ZERO


func _interface() -> void:
	var calque := CanvasLayer.new()
	calque.layer = 6
	add_child(calque)
	# viseur de l'appareil photo
	viseur = Control.new()
	viseur.set_anchors_preset(Control.PRESET_FULL_RECT)
	viseur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viseur.visible = false
	calque.add_child(viseur)
	for c in [[Vector2(0.18, 0.18), Vector2(1, 1)], [Vector2(0.82, 0.18), Vector2(-1, 1)], [Vector2(0.18, 0.82), Vector2(1, -1)], [Vector2(0.82, 0.82), Vector2(-1, -1)]]:
		for horiz in [true, false]:
			var r := ColorRect.new()
			r.color = Color(1, 1, 1, 0.85)
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			r.anchor_left = c[0].x
			r.anchor_right = c[0].x
			r.anchor_top = c[0].y
			r.anchor_bottom = c[0].y
			var sz := Vector2(46, 3) if horiz else Vector2(3, 46)
			r.offset_left = 0.0 if c[1].x > 0 else -sz.x
			r.offset_right = r.offset_left + sz.x
			r.offset_top = 0.0 if c[1].y > 0 else -sz.y
			r.offset_bottom = r.offset_top + sz.y
			viseur.add_child(r)
	etiquette_viseur = Label.new()
	etiquette_viseur.add_theme_font_size_override("font_size", 17)
	etiquette_viseur.add_theme_color_override("font_outline_color", Color.BLACK)
	etiquette_viseur.add_theme_constant_override("outline_size", 5)
	etiquette_viseur.anchor_left = 0.18
	etiquette_viseur.anchor_top = 0.84
	etiquette_viseur.anchor_right = 0.82
	etiquette_viseur.anchor_bottom = 0.9
	etiquette_viseur.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	viseur.add_child(etiquette_viseur)
	# jauge de filature : la bonne distance au milieu
	jauge = ProgressBar.new()
	jauge.min_value = 0.0
	jauge.max_value = 100.0
	jauge.show_percentage = false
	jauge.custom_minimum_size = Vector2(300, 10)
	jauge.anchor_left = 0.5
	jauge.anchor_right = 0.5
	jauge.anchor_top = 1.0
	jauge.anchor_bottom = 1.0
	jauge.offset_left = -150
	jauge.offset_right = 150
	jauge.offset_top = -112
	jauge.offset_bottom = -102
	jauge.visible = false
	calque.add_child(jauge)
	etiquette_jauge = Label.new()
	etiquette_jauge.add_theme_font_size_override("font_size", 15)
	etiquette_jauge.add_theme_color_override("font_outline_color", Color.BLACK)
	etiquette_jauge.add_theme_constant_override("outline_size", 5)
	etiquette_jauge.anchor_left = 0.5
	etiquette_jauge.anchor_right = 0.5
	etiquette_jauge.anchor_top = 1.0
	etiquette_jauge.anchor_bottom = 1.0
	etiquette_jauge.offset_left = -250
	etiquette_jauge.offset_right = 250
	etiquette_jauge.offset_top = -136
	etiquette_jauge.offset_bottom = -114
	etiquette_jauge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiquette_jauge.visible = false
	calque.add_child(etiquette_jauge)


func etat_texte() -> String:
	return ["à venir", "disponible", "dans la mangrove", "la filature", "la cabane", "le registre est à nous"][phase]


# ---------------------------------------------------------------------
# Déroulement
# ---------------------------------------------------------------------
func _process(delta: float) -> void:
	if joueur == null:
		return
	match phase:
		Phase.INDISPONIBLE:
			var m8: Node = main.get_node_or_null("Mission8")
			if m8 and m8.phase == Mission8.Phase.TERMINEE:
				_message_code()
		Phase.DISPONIBLE:
			if pirogue and pirogue.monte:
				_commencer()
		Phase.ATTENTE:
			t_cabane += delta
			if t_cabane > 18.0:
				_depart_barge()
		Phase.FILATURE:
			_filature(delta)
		Phase.CABANE:
			_scene_cabane(delta)
	if phase in [Phase.ATTENTE, Phase.FILATURE, Phase.CABANE]:
		_maree(delta)
		_photo_viseur()
		t_hud -= delta
		if t_hud <= 0.0:
			t_hud = 0.5
			_mettre_objectif()
	if registre_a_l_eau:
		_registre_flotte(delta)
	if t_reprise > 0.0:
		t_reprise -= delta
		if t_reprise <= 0.0:
			_reprendre()


func _message_code() -> void:
	phase = Phase.DISPONIBLE
	var tel: Node = main.get_node_or_null("Telephone")
	if tel:
		tel.notifier("Radio Racines : Joël a capté un message codé du Cobra")
	m4._annoncer("JOËL (radio) — « Message codé du Cobra : \"Les sacs dorment ce soir chez le pêcheur.\" Le pêcheur, c'est la cabane de la baie du Sud. Un chargement part ce soir. »", 8.0)
	m4._objectif("Mission 9 — Le Chenal : rejoignez Ama dans la mangrove de la baie du Sud, au bout de la crique est (E pour embarquer).")
	var ca: Node = main.get_node_or_null("Carte")
	if ca:
		var p: Vector2 = CRIQUE_RDV[CRIQUE_RDV.size() - 1]
		ca.poser_balise(Vector3(p.x, 0.0, p.y))


func _commencer() -> void:
	phase = Phase.ATTENTE
	t_cabane = 0.0
	joueur.mission = self
	var amb: Ambiances = main.ambiances
	var garde := 0
	while amb.index != 0 and garde < 8:   # crépuscule doré sur la mangrove
		amb.suivante()
		garde += 1
	m4._annoncer("Mission 9 — Le Chenal", 4.0)
	@warning_ignore("missing_await")
	_dire("AMA", "À la rame. Tout doucement. Ici, l'eau parle plus fort que nous. … Elle arrive par l'est. On la laisse passer, puis on la suit.", 1.5)
	@warning_ignore("missing_await")
	_dire("AMA", "Et sors ton téléphone (K) : il nous faut des photos. Les sacs, l'acheteur, et le bateau qui attend au large.", 10.0)


func _dire(qui: String, texte: String, delai: float) -> void:
	await get_tree().create_timer(delai).timeout
	m4._annoncer("%s — %s" % [qui, texte], 7.0)


func _mettre_objectif() -> void:
	var ph := "Photos : %s sacs · %s acheteur · %s navire" % ["✓" if photos["sacs"] else "○", "✓" if photos["acheteur"] else "○", "✓" if photos["navire"] else "○"]
	match phase:
		Phase.ATTENTE:
			m4._objectif("Attendez la barge, cachés dans la crique.\n" + ph)
		Phase.FILATURE:
			m4._objectif("Suivez la barge sans vous faire voir (%d–%d m). K : appareil photo.\n%s" % [int(DIST_MIN), int(DIST_MAX), ph])
		Phase.CABANE:
			var t := "La cabane sur pilotis. "
			if not ecoute_finie:
				t += "Glissez-vous sous le plancher pour écouter. "
			t += "Prenez le registre sur la table (F)."
			m4._objectif(t + "\n" + ph)


func _depart_barge() -> void:
	phase = Phase.FILATURE
	l_route = 0.0
	barge.visible = true
	moteur.play()
	var amb: Ambiances = main.ambiances
	var garde := 0
	while amb.index != 3 and garde < 8:   # la nuit tombe sur la baie
		amb.suivante()
		garde += 1
	jauge.visible = true
	etiquette_jauge.visible = true
	m4._annoncer("Un moteur, au large. La barge entre dans la mangrove, lourde, chargée de sacs.", 4.0)


func _filature(delta: float) -> void:
	var longueur := _longueur_route()
	# la barge avance, sauf pendant ses pauses d'écoute
	var idx_route := _index_waypoint(l_route)
	if t_pause > 0.0:
		t_pause -= delta
		moteur.stream_paused = true
		if joueur.vitesse_affichee > 0.6 and _distance_barge() < 50.0:
			soupcon += delta * 0.9
	else:
		moteur.stream_paused = false
		l_route = minf(longueur, l_route + VITESSE_BARGE * delta)
		if idx_route in PAUSES and not pauses_faites.has(idx_route):
			pauses_faites.append(idx_route)
			t_pause = 12.0
			m4._annoncer("Le moteur se tait. La barge dérive… ils écoutent.\nAMA (souffle) — « Ne bouge plus. »", 4.0)
	_placer_barge(delta)
	# distance, soupçon, projecteur
	var d := _distance_barge()
	if d < DIST_MIN:
		soupcon += delta * (0.25 + (DIST_MIN - d) / DIST_MIN * 0.9)
	elif d < 40.0 and joueur.vitesse_affichee > 3.0:
		soupcon += delta * 0.25          # la perche frappe l'eau trop fort
	else:
		soupcon = maxf(0.0, soupcon - delta * 0.12)
	soupcon = minf(soupcon, 1.6)
	if d < 90.0:
		vue_une_fois = true
	_projecteur(delta, d)
	if d > 90.0 and vue_une_fois:
		t_perdu += delta
		if t_perdu > 22.0:
			_echec("La barge a disparu dans les chenaux.")
			return
	else:
		t_perdu = 0.0
	jauge.value = clampf(100.0 - absf(d - (DIST_MIN + DIST_MAX) * 0.5) * 2.0, 0.0, 100.0)
	if d < DIST_MIN:
		etiquette_jauge.text = "Trop près (%d m)" % int(d)
		etiquette_jauge.add_theme_color_override("font_color", Color(1.0, 0.5, 0.35))
	elif d > DIST_MAX:
		etiquette_jauge.text = "Trop loin (%d m)" % int(d) + ("  — on la perd !" if d > 90.0 else "")
		etiquette_jauge.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
	else:
		etiquette_jauge.text = "Bonne distance (%d m)" % int(d)
		etiquette_jauge.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))
	if l_route >= longueur - 0.5:
		_arrivee_cabane()


func _index_waypoint(l: float) -> int:
	# index du point de ROUTE (non lissée) le plus proche de la barge
	var p := _point_route(l)
	var best := 0
	var dmin := INF
	for i in ROUTE.size():
		var dd := p.distance_to(ROUTE[i])
		if dd < dmin:
			dmin = dd
			best = i
	return best if dmin < 12.0 else -1


func _placer_barge(delta: float) -> void:
	var p := _point_route(l_route)
	var devant := _point_route(l_route + 4.0)
	var dir := devant - p
	var cap := atan2(dir.x, dir.y) if dir.length() > 0.01 else barge.rotation.y
	var t := Time.get_ticks_msec() * 0.001
	barge.global_position = Vector3(p.x, 0.02 * sin(t * 1.4) - 0.1, p.y)
	barge.rotation = Vector3(0.01 * sin(t * 0.9), lerp_angle(barge.rotation.y, cap, 1.0 - exp(-2.0 * delta)), 0.012 * sin(t * 1.1))


func _distance_barge() -> float:
	return _plat(joueur.global_position).distance_to(_plat(barge.global_position))


func _projecteur(delta: float, d: float) -> void:
	if soupcon > 0.5:
		if projecteur.light_energy < 0.1:
			m4._annoncer("Le projecteur s'allume et balaie le chenal derrière la barge !\nAMA — « Recule. Dans les racines. Vite. »", 3.5)
		projecteur.light_energy = move_toward(projecteur.light_energy, 9.0, delta * 20.0)
		# le faisceau balaie le sillage de gauche à droite
		var a := sin(Time.get_ticks_msec() * 0.0011) * 0.75
		# la barge avance vers son +Z local ; le projecteur (axe -Z) éclaire donc le sillage, derrière elle
		projecteur.basis = Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, -0.12)
		var dir := -projecteur.global_transform.basis.z
		var vers := joueur.global_position + Vector3(0, 1.0, 0) - projecteur.global_position
		if d < 55.0 and dir.angle_to(vers) < deg_to_rad(9.0):
			var q := PhysicsRayQueryParameters3D.create(projecteur.global_position, joueur.global_position + Vector3(0, 1.0, 0), 1)
			if get_world_3d().direct_space_state.intersect_ray(q).is_empty():
				_echec("Le faisceau vous a trouvés. Des cris, le moteur qui rugit : la barge s'enfuit.")
	else:
		projecteur.light_energy = move_toward(projecteur.light_energy, 0.0, delta * 6.0)
		if soupcon <= 0.0 and projecteur.light_energy <= 0.0:
			projecteur.basis = Basis()


func _echec(texte: String) -> void:
	m4._annoncer(texte + "\nOn reprend un peu plus tôt.", 5.0)
	# la barge revient deux points en arrière ; la pirogue se place loin derrière elle
	var i := maxi(0, _index_proche(l_route) - 2)
	l_route = maxf(_abscisse(ROUTE[i]), 50.0)     # toujours de quoi placer la pirogue derrière
	soupcon = 0.0
	t_perdu = 0.0
	t_pause = 0.0
	projecteur.light_energy = 0.0
	var arriere := maxf(0.0, l_route - 45.0)
	var q := _point_route(arriere)
	var q2 := _point_route(arriere + 3.0)
	if pirogue:
		pirogue.vitesse = 0.0
		pirogue.cap = atan2(q2.x - q.x, q2.y - q.y)
		pirogue.global_position = Vector3(q.x, -0.2, q.y)
	_placer_barge(1.0)


func _index_proche(l: float) -> int:
	var p := _point_route(l)
	var best := 0
	var dmin := INF
	for i in ROUTE.size():
		var dd := p.distance_to(ROUTE[i])
		if dd < dmin and _abscisse(ROUTE[i]) <= l + 1.0:
			dmin = dd
			best = i
	return best


func _abscisse(cible: Vector2) -> float:
	var l := 0.0
	var best := 0.0
	var dmin := INF
	for i in route.size():
		if i > 0:
			l += route[i - 1].distance_to(route[i])
		var dd := route[i].distance_to(cible)
		if dd < dmin:
			dmin = dd
			best = l
	return best


func _maree(delta: float) -> void:
	t_maree += delta
	maree = clampf(t_maree / MAREE_DUREE, 0.0, 1.0)
	banc.global_position.y = 0.35 - maree * 0.95
	arche.global_position.y = -maree * 1.1
	if maree > 0.55 and not annonce_banc:
		annonce_banc = true
		m4._annoncer("AMA — « La marée monte. Le banc de vase de l'est est couvert : le raccourci derrière la pointe est ouvert. »", 5.0)
	if maree > 0.72 and not annonce_arche:
		annonce_arche = true
		m4._annoncer("AMA — « L'arche de racines de la crique de l'ouest touche l'eau. Ce passage-là est fermé. »", 4.5)


# ---------------------------------------------------------------------
# Appareil photo
# ---------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if not (phase in [Phase.ATTENTE, Phase.FILATURE, Phase.CABANE]):
		return
	if event.is_action_pressed("photo"):
		joueur.photo = not joueur.photo
		viseur.visible = joueur.photo
	elif joueur.photo and event.is_action_pressed("tirer"):
		_declencher()


func _cibles() -> Array:
	var c: Array = []
	if barge.visible:
		c.append(["sacs", "le marquage des sacs", sacs.global_position + Vector3(0, 0.4, 0), 45.0])
	if acheteur and is_instance_valid(acheteur):
		c.append(["acheteur", "le visage de l'acheteur", acheteur.global_position + Vector3(0, 1.65, 0), 35.0])
	c.append(["navire", "le numéro du navire", numero.global_position, 520.0])
	return c


func _photo_viseur() -> void:
	if not joueur.photo:
		return
	var cam := joueur.camera
	var dir := -cam.global_transform.basis.z
	var t := "Cadrez une cible, puis clic gauche."
	for c in _cibles():
		var vers: Vector3 = (c[2] as Vector3) - cam.global_position
		if vers.length() < c[3] and dir.angle_to(vers) < deg_to_rad(7.0):
			t = ("Déjà photographié : " if photos[c[0]] else "Dans le cadre : ") + str(c[1])
	etiquette_viseur.text = t


func _declencher() -> void:
	var cam := joueur.camera
	var dir := -cam.global_transform.basis.z
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.6)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	viseur.add_child(flash)
	get_tree().create_timer(0.08).timeout.connect(flash.queue_free)
	for c in _cibles():
		var cible: Vector3 = c[2]
		var vers := cible - cam.global_position
		if vers.length() > c[3] or dir.angle_to(vers) > deg_to_rad(7.0):
			continue
		var q := PhysicsRayQueryParameters3D.create(cam.global_position, cible, 1)
		q.exclude = [joueur.get_rid()]
		var r := get_world_3d().direct_space_state.intersect_ray(q)
		if not r.is_empty() and (r["position"] as Vector3).distance_to(cible) > 1.5:
			continue
		if photos[c[0]]:
			continue
		photos[c[0]] = true
		var tel: Node = main.get_node_or_null("Telephone")
		var textes := {
			"sacs": ["Photo : les sacs de la barge", "Sacs de 50 kg tamponnés « S.P.L. — Lagunaville » : la Société portuaire de Lagunaville reçoit le manioc et le cacao volés de Talanké."],
			"acheteur": ["Photo : l'acheteur de Lagunaville", "Un homme en costume clair qui compte l'argent du Cobra dans la cabane de la baie du Sud. Son visage, net."],
			"navire": ["Photo : le navire LGV 2047", "Caboteur immatriculé LGV 2047 à Lagunaville, au mouillage au large de la baie du Sud : il charge la marchandise du Cobra."],
		}
		if tel:
			tel.ajouter_preuve(textes[c[0]][0], textes[c[0]][1])
		var nom := str(c[1])
		m4._annoncer("Clic. %s ✓" % (nom.left(1).to_upper() + nom.substr(1)), 2.5)
		return
	m4._annoncer("Clic. Rien d'utile sur la photo.", 1.5)


# ---------------------------------------------------------------------
# La cabane
# ---------------------------------------------------------------------
func _arrivee_cabane() -> void:
	phase = Phase.CABANE
	t_cabane = 0.0
	moteur.stop()
	jauge.visible = false
	etiquette_jauge.visible = false
	projecteur.light_energy = 0.0
	var vq: Node = main.get_node_or_null("VieQuotidienne")
	var base := cabane.global_transform
	var modeles := ["homme2", "villageois", "homme3"]
	var places := [Vector3(-1.5, PLANCHER + 0.1, -0.5), Vector3(2.4, PLANCHER + 0.1, 4.6), Vector3(-2.8, PLANCHER + 0.1, 4.2)]
	for i in places.size():
		var g := Pnj.new()
		add_child(g)
		g.global_position = base * (places[i] as Vector3)
		g.preparer("milicien", self, joueur, [Color(0.9, 0.5, 0.35), Color(0.5, 0.6, 0.8), Color(0.7, 0.7, 0.5)][i], "", modeles[i])
		g.portee_vue = 14.0
		g.points_patrouille = [g.global_position]
		g.refuges = [g.global_position]
		g.alerte.connect(func(_q: Vector3) -> void: _alerte())
		g.rendu.connect(func(_n: Pnj) -> void: m4._annoncer("Le contrebandier se rend : F pour le ligoter.", 2.5))
		gardes.append(g)
	acheteur = Pnj.new()
	add_child(acheteur)
	acheteur.global_position = base * Vector3(0.6, PLANCHER + 0.1, 4.0)   # sur la terrasse, sous la lampe
	acheteur.preparer("civil", self, joueur, Color(1.5, 1.45, 1.3), "", "homme2")   # costume clair
	acheteur.refuges = [acheteur.global_position]
	# costume de lin clair, uni : veste et pantalon du même beige
	for mi in acheteur.corps.find_children("*", "MeshInstance3D", true, false):
		var mm := mi as MeshInstance3D
		for k in mm.mesh.get_surface_count():
			var mat := mm.mesh.surface_get_material(k)
			if mat and (mat.resource_name == "Chemise" or mat.resource_name == "Pantalon"):
				var lin := StandardMaterial3D.new()
				lin.albedo_color = Color(0.86, 0.8, 0.68)
				lin.roughness = 0.9
				mm.set_surface_override_material(k, lin)
	# sa vedette, amarrée à la terrasse
	if vq:
		vedette = Node3D.new()
		add_child(vedette)
		var coque := MeshInstance3D.new()
		coque.mesh = vq._pirogue_maillage()
		var blanc := StandardMaterial3D.new()
		blanc.albedo_color = Color(0.9, 0.9, 0.88)
		blanc.roughness = 0.4
		coque.material_override = blanc
		vedette.add_child(coque)
		vedette.global_transform = Transform3D(base.basis * Basis(Vector3.UP, PI * 0.5), base * Vector3(3.0, -0.2, 7.5))
	barge.global_position = base * Vector3(-1.0, -0.1, 7.8)
	m4._annoncer("La barge accoste sous la cabane. Une lampe tempête, des voix. Un homme en costume clair attend, une liasse de billets à la main.", 5.0)
	var ca: Node = main.get_node_or_null("Carte")
	if ca:
		ca.poser_balise(Vector3(CABANE.x, 0.0, CABANE.y))


func _scene_cabane(delta: float) -> void:
	t_cabane += delta
	var jp := joueur.global_position
	var sous := _plat(jp).distance_to(CABANE) < 7.0 and jp.y < PLANCHER - 0.6
	# la conversation : on ne l'entend que sous le plancher
	if not combat and not ecoute_finie and sous:
		t_ecoute += delta
		var etape := int(t_ecoute / 7.0)
		if etape >= ecoute and etape < DIALOGUE.size():
			m4._annoncer("%s — « %s »" % DIALOGUE[etape], 6.5)
			ecoute = etape + 1
		elif etape >= DIALOGUE.size():
			_fin_ecoute(true)
	elif not combat and not ecoute_finie and t_cabane > 150.0 and t_ecoute <= 0.0:
		_fin_ecoute(false)      # personne n'est venu écouter : l'acheteur finit par partir
	# l'acheteur rejoint sa vedette, qui file vers le navire
	if acheteur_parti and vedette and is_instance_valid(vedette):
		var cible := Vector3(NAVIRE.x, -0.2, NAVIRE.y)
		var dir := cible - vedette.global_position
		dir.y = 0.0
		if dir.length() < 30.0:
			vedette.queue_free()
			vedette = null
		else:
			vedette.global_position += dir.normalized() * 9.0 * delta
			vedette.rotation.y = atan2(dir.x, dir.z)


func _fin_ecoute(entendu: bool) -> void:
	ecoute_finie = true
	if entendu:
		var tel: Node = main.get_node_or_null("Telephone")
		if tel:
			tel.ajouter_preuve("Conversation sous la cabane", "L'acheteur de Lagunaville : « Le Patron des Docks veut le double le mois prochain […] Le ministère n'aime pas les problèmes. » Le Cobra veut se débarrasser du fils de Samuel.")
		m4._annoncer("Le fils de Samuel… Faris serre les dents. Au-dessus, des pas : l'acheteur s'en va.", 4.5)
	_depart_acheteur()


func _depart_acheteur() -> void:
	if acheteur_parti:
		return
	acheteur_parti = true
	if acheteur and is_instance_valid(acheteur):
		acheteur.queue_free()
		acheteur = null
	m4._annoncer("La vedette de l'acheteur démarre et file vers le navire au large. Les contrebandiers comptent les billets. Le registre est resté sur la table.", 5.0)


func _alerte() -> void:
	if not combat:
		combat = true
		_depart_acheteur()
	for g in gardes:
		if (g as Pnj).est_actif():
			(g as Pnj)._passer_combat()


func interagir() -> void:
	var jp := joueur.global_position
	if phase != Phase.CABANE:
		m4.interagir()
		return
	if registre_a_l_eau and jp.distance_to(registre.global_position) < 2.8:
		_prendre_registre()
		return
	if not registre_pris and not registre_a_l_eau and jp.distance_to(registre.global_position) < 1.9:
		_prendre_registre()
		return
	for g in gardes:
		var p := g as Pnj
		if p.global_position.distance_to(jp) < 2.0 and (p.etat == Pnj.Etat.RENDU or (p.est_actif() and p.dos_au_joueur())):
			p.ligoter()
			m4._annoncer("Contrebandier ligoté.", 2.0)
			return


func bruit_de_tir(p: Vector3, _joueur_tire := false) -> void:
	for g in gardes:
		(g as Pnj).entendre(p, 70.0)
	_alerte()
	# combat sur pilotis : la cabane tremble, le registre peut glisser dans l'eau
	if not registre_pris and not registre_a_l_eau and _plat(p).distance_to(CABANE) < 25.0 and randf() < 0.35:
		registre_a_l_eau = true
		t_registre = 45.0
		var pos := registre.global_position
		registre.reparent(self)
		registre.global_position = Vector3(pos.x, 0.03, pos.z) + Vector3(randf_range(-2, 2), 0, 4.0)
		m4._annoncer("Une rafale fait trembler les pilotis : le registre glisse de la table et tombe à l'eau ! Repêchez-le avant qu'il coule (F).", 5.0)


func _registre_flotte(delta: float) -> void:
	t_registre -= delta
	registre.global_position += Vector3(0.15, 0, 0.08) * delta    # il dérive avec la marée
	registre.global_position.y = 0.03 - (0.0 if t_registre > 8.0 else (8.0 - t_registre) * 0.02)
	if t_registre <= 0.0:
		registre_a_l_eau = false
		registre.visible = false
		m4._annoncer("Le registre a coulé dans la vase. Il ne reste que les photos… (on reprend à la cabane)", 5.0)
		# seconde chance : un double du registre dans le coffre de la barge
		registre.visible = true
		registre.reparent(barge)
		registre.position = Vector3(0.6, 0.75, -3.8)
		m4._objectif("AMA — « Ils tiennent toujours un double. Fouille la barge, près du moteur (F). »")


func _prendre_registre() -> void:
	registre_pris = true
	registre_a_l_eau = false
	registre.visible = false
	phase = Phase.TERMINEE
	joueur.photo = false
	viseur.visible = false
	m4._annoncer("Le registre est à vous. Ama rapproche la pirogue : « Monte. On file. »", 4.0)
	@warning_ignore("missing_await")
	_epilogue()


func _epilogue() -> void:
	await get_tree().create_timer(5.0).timeout
	m4._annoncer("À la lampe frontale, Faris feuillette le registre : des dates, des tonnes, et à chaque page la même signature, « H.S. », sous un tampon : Société portuaire de Lagunaville.", 8.0)
	await get_tree().create_timer(8.5).timeout
	m4._annoncer("AMA — « H.S. … Henri Sabaro. Le Patron des Docks. Tout le monde le connaît sur la côte. »\nFARIS — « Mon père avait écrit ces initiales dans son carnet. Il savait. »", 9.0)
	var tel: Node = main.get_node_or_null("Telephone")
	if tel:
		tel.ajouter_preuve("Le registre du trafic", "Registre des contrebandiers de la baie du Sud : dates, quantités, signature « H.S. » (Henri Sabaro, le Patron des Docks) et tampon de la Société portuaire de Lagunaville. Le Cobra → le Syndicat des Docks → (?) un ministère.")
		tel.notifier("Tableau des preuves : une flèche relie le Cobra au Syndicat des Docks… puis des pointillés vers « un ministère ».")
	var nb := 0
	for k in photos:
		if photos[k]:
			nb += 1
	m4.confiance = clampi(m4.confiance + 3 + nb, 0, 100)
	if nb < 3:
		@warning_ignore("missing_await")
		_dire("AMA", "Il nous manque des photos (%d sur 3). Le registre parlera quand même, mais moins fort." % nb, 9.5)
	joueur.mission = m4
	m4._objectif("Prochain objectif : le registre parle d'un avion de contrebande sur la piste du nord (mission 10, « L'Avion »).")


## Après un chargement de partie : la mission est déjà faite.
func restaurer_terminee() -> void:
	phase = Phase.TERMINEE
	registre_pris = true
	m4._objectif("Prochain objectif : le registre parle d'un avion de contrebande sur la piste du nord (mission 10, « L'Avion »).")


# ---------------------------------------------------------------------
# Chute de Faris : on reprend au bord de la mangrove, près de la cabane
# ---------------------------------------------------------------------
func _tombe() -> void:
	if phase != Phase.CABANE and phase != Phase.FILATURE:
		return
	m4.t_reprise = 0.0
	t_reprise = 3.5


func _reprendre() -> void:
	for g in gardes:
		var p := g as Pnj
		if p.etat == Pnj.Etat.COMBAT or p.etat == Pnj.Etat.SUSPICION:
			p.etat = Pnj.Etat.CALME
			p.soupcon = 0.0
			p.pv = maxf(p.pv, 60.0)
	combat = false
	var q: Vector2 = CRIQUE_OUEST[1]
	joueur.ressusciter(Vector3(q.x, terrain.hauteur(q.x, q.y) + 0.6, q.y))
	m4._annoncer("Ama vous a repêché et caché dans les racines… Reprise.", 3.0)


# ---------- ce que les Pnj demandent ----------
func choisir_couvert(n: Pnj) -> Vector3:
	return n.global_position


func blessure() -> void:
	m4.blessure()


func _plat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)

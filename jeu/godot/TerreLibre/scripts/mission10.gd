## Mission 10 — « L'Avion » (voir jeu/missions/10-L-AVION.md).
## Après le registre : l'avion de contrebande fait le plein sur la piste de terre du nord, à l'aube.
## - Le garage : Kwame a gonflé la moto de Moto-Moto (près de 140 km/h) ; on peut tirer en roulant.
## - L'approche, au choix : la route à toute vitesse (l'alarme sonne tout de suite), les dunes à pied
##   pour saboter le réservoir (F sous l'aile gauche), ou la plage par la mer.
## - Le décollage : l'avion roule, deux pick-up de la milice l'escortent en tirant. Viser le train
##   d'atterrissage ou un moteur ; jamais le cockpit (le pilote est un témoin).
## - S'il décolle avec le réservoir saboté, il fait demi-tour et se pose en catastrophe sur la plage ;
##   sinon on recommence le décollage.
## - Le pilote, Marc Ndoro : l'interrogatoire, le nom du ministre, puis le choix (le confier aux
##   Racines ou le laisser fuir).
class_name Mission10
extends Node3D

enum Phase { INDISPONIBLE, DISPONIBLE, APPROCHE, DECOLLAGE, VOL, PILOTE, TERMINEE }
const PISTE_A := Vector2(-1050, -1042)
const PISTE_B := Vector2(-350, -1020)
const LARGEUR := 24.0
const PLAGE_A := Vector2(-560, -1168)
const PLAGE_B := Vector2(-830, -1170)
const ACCEL := 1.05            # m/s² : un bimoteur chargé sur la terre battue
const V_ROTATION := 33.0       # m/s : il quitte le sol
const PV_TRAIN := 5
const PV_MOTEUR := 6

var phase := Phase.INDISPONIBLE
var main: Node
var joueur: Joueur
var m4: Mission4
var terrain: Terrain
var moto: MotoJoueur
var kwame: Node3D
var moto_moto: Node3D
var garage_fait := false
var GARAGE := Vector2.ZERO        # le garage en plein air de Kwame, sur la place de Port-Néré
var avion: Node3D
var helices: Array = []
var parties := {}               # nom -> AnimatableBody3D
var pv := {"train": PV_TRAIN, "moteur_g": PV_MOTEUR, "moteur_d": PV_MOTEUR}
var tirs_cockpit := 0
var sabote := false
var t_sabotage := -1.0
var s_avion := 0.0             # abscisse de l'avion le long de la piste (m)
var v_avion := 0.0
var ecart := 0.0               # écart latéral (quand il quitte la piste)
var lacet_avion := 0.0
var t_vol := 0.0
var trajectoire: Curve3D
var crash_cote := 1.0
var crash := false
var fumee_moteur: CPUParticles3D
var poussiere: CPUParticles3D
var pickups: Array = []         # {noeud, corps, pv, offset, tireur, t_tir, son, mort}
var gardes: Array = []
var t_alarme := -1.0
var t_approche := 0.0
var son_avion: AudioStreamPlayer3D
var sirene: AudioStreamPlayer3D
var ndoro: Pnj
var interroge := false
var choix := ""
var choix_ui: PanelContainer
var t_reprise := 0.0
var t_hud := 0.0
var t_relance := -1.0


# ---------------------------------------------------------------------
# Plan : la piste de terre aplanie et la plage de l'atterrissage forcé
# ---------------------------------------------------------------------
static func preparer_plan() -> Dictionary:
	var d := Terrain.lire_donnees()
	var pf: Array = []
	var ha := Terrain.hauteur_brute(d, PISTE_A.x, PISTE_A.y)
	var hb := Terrain.hauteur_brute(d, PISTE_B.x, PISTE_B.y)
	var nb := int(PISTE_A.distance_to(PISTE_B) / 14.0)
	for k in nb + 1:
		var t := float(k) / nb
		var q := PISTE_A.lerp(PISTE_B, t)
		pf.append({"centre": q, "rayon": 18.0, "h": lerpf(ha, hb, t)})
	var np := int(PLAGE_A.distance_to(PLAGE_B) / 14.0)
	for k in np + 1:
		pf.append({"centre": PLAGE_A.lerp(PLAGE_B, float(k) / np), "rayon": 16.0, "h": 1.5})
	return {"plateformes": pf, "ha": ha, "hb": hb}


# ---------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------
func construire(p_main: Node, veg: Vegetation = null) -> void:
	main = p_main
	joueur = main.joueur
	m4 = main.get_node("Mission4")
	terrain = main.terrain
	var place: Vector3 = main.ville.reperes["place"]
	GARAGE = Vector2(place.x, place.z) + Vector2(6.0, -5.0)
	_piste()
	_hangar()
	_avion()
	_interface()
	# pas d'arbre sur la piste ni sur la ligne de l'atterrissage forcé
	var degage := func(q: Vector2) -> bool:
		return _dist_segment(q, PISTE_A, PISTE_B) < LARGEUR * 0.5 + 10.0 or _dist_segment(q, PLAGE_A, PLAGE_B) < 22.0
	if veg:
		veg.degager(degage)
	var proche: Node = main.get_node_or_null("VegetationProche")
	if proche:
		proche.degager(degage)
	joueur.impact.connect(_impact)
	joueur.tombe.connect(_tombe)
	joueur.a_tire.connect(func(p: Vector3) -> void:
		if phase == Phase.APPROCHE and _plat(p).distance_to(_milieu()) < 450.0:
			_alarme("Un coup de feu sur la piste !")
		for g in gardes:
			(g as Pnj).entendre(p, 90.0))


static func _dist_segment(q: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((q - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return q.distance_to(a + ab * t)


func _milieu() -> Vector2:
	return PISTE_A.lerp(PISTE_B, 0.5)


func _point_piste(s: float, lateral := 0.0) -> Vector3:
	var dir := (PISTE_B - PISTE_A).normalized()
	var q := PISTE_A + dir * s + Vector2(-dir.y, dir.x) * lateral
	return Vector3(q.x, terrain.hauteur(q.x, q.y), q.y)


func _cap_piste() -> float:
	var dir := PISTE_B - PISTE_A
	return atan2(dir.x, dir.y)


func _boite(taille: Vector3, xf: Transform3D, couleur: Color, parent: Node3D = null, rugosite := 0.85, metal := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = taille
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = couleur
	m.roughness = rugosite
	m.metallic = metal
	mi.material_override = m
	(parent if parent else self).add_child(mi)
	mi.transform = xf
	return mi


func _cylindre(r0: float, r1: float, h: float, xf: Transform3D, couleur: Color, parent: Node3D, rugosite := 0.5, metal := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r0
	cm.bottom_radius = r1
	cm.height = h
	cm.radial_segments = 16
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = couleur
	m.roughness = rugosite
	m.metallic = metal
	mi.material_override = m
	parent.add_child(mi)
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


## La piste : un ruban de latérite damée qui suit le sol aplani, ornières, bornes peintes, manche à air.
func _piste() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dir := (PISTE_B - PISTE_A).normalized()
	var n := Vector2(-dir.y, dir.x)
	var l := PISTE_A.distance_to(PISTE_B)
	var pas := 6.0
	var nb := int(l / pas)
	for k in nb:
		var s0 := k * pas
		var s1 := (k + 1) * pas
		for j in 4:
			var u0 := -LARGEUR * 0.5 + LARGEUR * j / 4.0
			var u1 := -LARGEUR * 0.5 + LARGEUR * (j + 1) / 4.0
			var pts: Array = []
			for c in [[s0, u0], [s0, u1], [s1, u1], [s1, u0]]:
				var q: Vector2 = PISTE_A + dir * float(c[0]) + n * float(c[1])
				pts.append(Vector3(q.x, terrain.hauteur(q.x, q.y) + 0.06, q.y))
			# ornières : les deux bandes centrales un peu plus sombres
			var teinte := Color(0.58, 0.36, 0.22) * (0.88 if j == 1 or j == 2 else 1.0)
			st.set_color(teinte)
			st.set_uv(Vector2(float(c_uv(u0)), s0 / 8.0))
			st.add_vertex(pts[0])
			st.add_vertex(pts[2])
			st.add_vertex(pts[1])
			st.add_vertex(pts[0])
			st.add_vertex(pts[3])
			st.add_vertex(pts[2])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.97
	var tex: Texture2D = load("res://data/textures/laterite_diff.jpg") if ResourceLoader.exists("res://data/textures/laterite_diff.jpg") else null
	if tex:
		m.albedo_texture = tex
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(0.25, 0.25, 0.25)
	mi.material_override = m
	add_child(mi)
	# bornes (vieux pneus peints en blanc) tous les 50 m de chaque côté
	var s := 0.0
	while s <= l:
		for cote in [-1.0, 1.0]:
			var p := _point_piste(s, cote * (LARGEUR * 0.5 + 1.0))
			_cylindre(0.45, 0.45, 0.28, Transform3D(Basis(), p + Vector3(0, 0.14, 0)), Color(0.92, 0.92, 0.88), self, 0.9)
		s += 50.0
	# manche à air sur son mât, au milieu de la piste
	var mat := _point_piste(l * 0.45, -LARGEUR * 0.5 - 8.0)
	_cylindre(0.05, 0.06, 6.0, Transform3D(Basis(), mat + Vector3(0, 3.0, 0)), Color(0.75, 0.75, 0.75), self, 0.4, 0.6)
	var manche := _cylindre(0.12, 0.35, 2.2, Transform3D(Basis(Vector3.FORWARD, PI * 0.5).rotated(Vector3.UP, -0.6), mat + Vector3(-1.1, 5.8, 0)), Color(1.0, 0.45, 0.1), self, 0.8)
	manche.name = "MancheAir"


static func c_uv(u: float) -> float:
	return u / 8.0


func _hangar() -> void:
	# hangar de tôle ondulée à l'est de la piste, côté mer ; citerne, caisses, groupe de pompage
	var cap := _cap_piste()
	var base := _point_piste(560.0, -LARGEUR * 0.5 - 22.0)
	var h := Node3D.new()
	add_child(h)
	h.global_transform = Transform3D(Basis(Vector3.UP, cap), base)
	var tole := Color(0.6, 0.6, 0.58)
	_boite(Vector3(0.12, 6.0, 20.0), Transform3D(Basis(), Vector3(-9.0, 3.0, 0)), tole, h, 0.5, 0.5)
	_boite(Vector3(0.12, 6.0, 20.0), Transform3D(Basis(), Vector3(9.0, 3.0, 0)), tole, h, 0.5, 0.5)
	_boite(Vector3(18.0, 6.0, 0.12), Transform3D(Basis(), Vector3(0, 3.0, -10.0)), tole * 0.9, h, 0.5, 0.5)
	for cote in [-1.0, 1.0]:
		_boite(Vector3(10.0, 0.08, 20.6), Transform3D(Basis(Vector3.FORWARD, cote * 0.32), Vector3(cote * 4.6, 7.5, 0)), Color(0.55, 0.38, 0.28), h, 0.6, 0.3)
		_solide(Vector3(0.3, 6.0, 20.0), Transform3D(Basis(), Vector3(cote * 9.0, 3.0, 0)), h)
	_solide(Vector3(18.0, 6.0, 0.3), Transform3D(Basis(), Vector3(0, 3.0, -10.0)), h)
	var e := Label3D.new()
	e.text = "TALANKÉ AVIATION SERVICES"
	e.font_size = 64
	e.pixel_size = 0.012
	e.modulate = Color(0.25, 0.25, 0.3)
	e.outline_size = 0
	e.position = Vector3(0, 5.2, 10.05)
	h.add_child(e)
	# citerne de carburant sur remorque
	_cylindre(1.1, 1.1, 6.0, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(12.0, 1.7, 14.0)), Color(0.85, 0.85, 0.8), h, 0.4, 0.4)
	_boite(Vector3(2.4, 0.5, 6.6), Transform3D(Basis(), Vector3(12.0, 0.55, 14.0)), Color(0.2, 0.2, 0.2), h)
	_solide(Vector3(2.4, 2.8, 6.6), Transform3D(Basis(), Vector3(12.0, 1.4, 14.0)), h)
	# caisses de la contrebande
	for i in 8:
		_boite(Vector3(1.2, 0.8, 0.9), Transform3D(Basis(Vector3.UP, randf_range(-0.2, 0.2)),
				Vector3(-4.0 + (i % 4) * 1.4, 0.4 + floorf(i / 4.0) * 0.8, 6.0)), Color(0.55, 0.45, 0.3), h)
	_solide(Vector3(6.0, 1.6, 1.2), Transform3D(Basis(), Vector3(-1.9, 0.8, 6.0)), h)


## Le bimoteur : fuselage blanc à bande bleue, aile haute, deux moteurs, train tricycle.
## Chaque partie qu'on peut viser a son propre corps physique (le tir de Faris dit laquelle il touche).
func _avion() -> void:
	avion = Node3D.new()
	add_child(avion)
	var blanc := Color(0.92, 0.92, 0.9)
	var bleu := Color(0.12, 0.25, 0.55)
	var vitre := Color(0.08, 0.1, 0.14)
	var gris := Color(0.35, 0.35, 0.36)
	var axe := Basis(Vector3.RIGHT, PI * 0.5)   # cylindres couchés dans l'axe de l'avion (+Z vers l'avant)
	_cylindre(0.85, 0.85, 7.0, Transform3D(axe, Vector3(0, 1.7, 0.5)), blanc, avion, 0.35)
	_cylindre(0.25, 0.85, 2.4, Transform3D(axe, Vector3(0, 1.65, 5.2)), blanc, avion, 0.35)        # nez
	_cylindre(0.85, 0.2, 4.6, Transform3D(axe, Vector3(0, 1.9, -5.3)), blanc, avion, 0.35)         # cône de queue
	_boite(Vector3(1.72, 0.25, 9.0), Transform3D(Basis(), Vector3(0, 1.45, 0)), bleu, avion, 0.4)  # bande
	_boite(Vector3(1.5, 0.45, 1.0), Transform3D(Basis(Vector3.RIGHT, -0.35), Vector3(0, 2.35, 3.7)), vitre, avion, 0.1)   # pare-brise
	for i in 4:
		for s in [-1.0, 1.0]:
			_boite(Vector3(0.05, 0.35, 0.45), Transform3D(Basis(), Vector3(s * 0.84, 2.0, 2.2 - i * 0.9)), vitre, avion, 0.1)
	_boite(Vector3(16.0, 0.2, 1.7), Transform3D(Basis(), Vector3(0, 2.6, 1.0)), blanc, avion, 0.35)        # aile haute
	_boite(Vector3(0.12, 2.2, 1.6), Transform3D(Basis(Vector3.RIGHT, 0.25), Vector3(0, 3.0, -7.0)), blanc, avion, 0.35)   # dérive
	_boite(Vector3(5.0, 0.12, 1.1), Transform3D(Basis(), Vector3(0, 2.2, -7.3)), blanc, avion, 0.35)       # stabilisateur
	var immat := Label3D.new()
	immat.text = "WZ-AKT"
	immat.font_size = 96
	immat.pixel_size = 0.008
	immat.modulate = bleu
	immat.outline_size = 0
	immat.transform = Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-0.87, 1.95, -3.2))
	avion.add_child(immat)
	# moteurs et hélices
	for nom in ["moteur_g", "moteur_d"]:
		var x := -3.2 if nom == "moteur_g" else 3.2
		_cylindre(0.42, 0.38, 2.8, Transform3D(axe, Vector3(x, 2.25, 1.6)), blanc, avion, 0.35)
		_cylindre(0.18, 0.3, 0.4, Transform3D(axe, Vector3(x, 2.25, 3.15)), gris, avion, 0.3, 0.6)
		var helice := Node3D.new()
		avion.add_child(helice)
		helice.position = Vector3(x, 2.25, 3.3)
		for k in 3:
			_boite(Vector3(0.14, 1.1, 0.04), Transform3D(Basis(Vector3.BACK, TAU * k / 3.0), Vector3(0, 0, 0)).translated_local(Vector3(0, 0.55, 0)), Color(0.15, 0.15, 0.15), helice, 0.4, 0.3)
		helices.append(helice)
		_partie(nom, Vector3(1.0, 1.0, 3.0), Vector3(x, 2.25, 1.6))
	# train d'atterrissage tricycle
	for p in [Vector3(0, 0.38, 4.4), Vector3(-3.2, 0.42, 1.0), Vector3(3.2, 0.42, 1.0)]:
		_boite(Vector3(0.1, 1.6 if p.x != 0.0 else 1.1, 0.1), Transform3D(Basis(), p + Vector3(0, 0.6 if p.x != 0.0 else 0.45, 0)), gris, avion, 0.4, 0.6)
		_cylindre(0.36, 0.36, 0.22, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), p), Color(0.08, 0.08, 0.08), avion, 0.9)
	_partie("train", Vector3(7.2, 1.0, 0.8), Vector3(0, 0.5, 1.0))
	_partie("train", Vector3(0.8, 1.0, 0.8), Vector3(0, 0.5, 4.4), "train_avant")
	# boîtes qui ne se recouvrent pas : la balle dit sans ambiguïté ce qu'elle touche
	_partie("cockpit", Vector3(1.7, 1.4, 2.7), Vector3(0, 2.0, 4.25))
	_partie("fuselage", Vector3(1.7, 1.5, 9.4), Vector3(0, 1.75, -1.8))
	_partie("aile", Vector3(16.0, 0.3, 1.7), Vector3(0, 2.6, 1.0))
	son_avion = AudioStreamPlayer3D.new()
	var s: AudioStreamWAV = load("res://sons/avion.wav")
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_end = int(s.get_length() * s.mix_rate)
	son_avion.stream = s
	son_avion.unit_size = 22.0
	son_avion.max_distance = 900.0
	son_avion.volume_db = 2.0
	avion.add_child(son_avion)
	fumee_moteur = CPUParticles3D.new()
	fumee_moteur.amount = 60
	fumee_moteur.lifetime = 3.0
	fumee_moteur.emitting = false
	fumee_moteur.local_coords = false
	fumee_moteur.direction = Vector3(0, 1, -1)
	fumee_moteur.spread = 20.0
	fumee_moteur.initial_velocity_min = 1.0
	fumee_moteur.initial_velocity_max = 2.5
	fumee_moteur.scale_amount_min = 0.8
	fumee_moteur.scale_amount_max = 2.2
	var qm := QuadMesh.new()
	qm.size = Vector2(1.2, 1.2)
	var mf := StandardMaterial3D.new()
	mf.albedo_color = Color(0.08, 0.08, 0.08, 0.55)
	mf.albedo_texture = load("res://data/textures/fumee_douce.png")   # volutes douces (outils/texture_fumee.py)
	mf.vertex_color_use_as_albedo = false
	mf.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mf.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mf.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.material = mf
	fumee_moteur.mesh = qm
	avion.add_child(fumee_moteur)
	poussiere = fumee_moteur.duplicate() as CPUParticles3D
	var mp := mf.duplicate() as StandardMaterial3D
	mp.albedo_color = Color(0.62, 0.44, 0.3, 0.45)
	var qp := QuadMesh.new()
	qp.size = Vector2(2.6, 2.6)
	qp.material = mp
	poussiere.mesh = qp
	poussiere.amount = 90
	poussiere.direction = Vector3(0, 0.6, -1)
	poussiere.initial_velocity_max = 5.0
	avion.add_child(poussiere)
	poussiere.position = Vector3(0, 0.3, -1.0)
	avion.visible = false
	_placer_avion_depart()


func _partie(nom: String, taille: Vector3, centre: Vector3, nom_noeud := "") -> void:
	var b := AnimatableBody3D.new()
	b.sync_to_physics = false
	b.collision_layer = 1
	b.collision_mask = 0
	b.set_meta("partie_avion", nom)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = taille
	cs.shape = bs
	b.add_child(cs)
	avion.add_child(b)
	b.position = centre
	parties[nom_noeud if nom_noeud != "" else nom] = b


func _placer_avion_depart() -> void:
	s_avion = 40.0
	v_avion = 0.0
	ecart = 0.0
	lacet_avion = 0.0
	crash = false
	t_vol = 0.0
	_poser_avion(0.0)


func _poser_avion(tangage: float) -> void:
	var p := _point_piste(s_avion, ecart)
	avion.global_transform = Transform3D(Basis(Vector3.UP, _cap_piste() + lacet_avion) * Basis(Vector3.RIGHT, -tangage), p)


func _interface() -> void:
	var calque := CanvasLayer.new()
	calque.layer = 6
	add_child(calque)
	choix_ui = PanelContainer.new()
	var fond := StyleBoxFlat.new()
	fond.bg_color = Color(0.06, 0.06, 0.07, 0.94)
	fond.border_color = Color(0.9, 0.6, 0.2)
	fond.set_border_width_all(2)
	fond.set_corner_radius_all(6)
	fond.set_content_margin_all(18)
	choix_ui.add_theme_stylebox_override("panel", fond)
	choix_ui.set_anchors_preset(Control.PRESET_CENTER)
	choix_ui.position = Vector2(-330, -170)
	choix_ui.custom_minimum_size = Vector2(660, 0)
	choix_ui.visible = false
	calque.add_child(choix_ui)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	choix_ui.add_child(col)
	var t := Label.new()
	t.text = "MARC NDORO, pilote. Que faire de lui ?"
	t.add_theme_font_size_override("font_size", 19)
	t.add_theme_color_override("font_color", Color(1.0, 0.8, 0.45))
	col.add_child(t)
	for c in [["Le confier aux Racines", "Il deviendra un témoin pour la justice. Il faudra le protéger : ceux qu'il accuse voudront le faire taire.", "racines"],
			["Le laisser fuir en pirogue", "Il disparaît. Mais avant de partir, il vous glisse une clé de casier, à Lagunaville.", "fuite"]]:
		var b := Button.new()
		b.text = "%s — %s" % [c[0], c[1]]
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(620, 0)
		b.pressed.connect(_choisir.bind(c[2]))
		col.add_child(b)


func etat_texte() -> String:
	return ["à venir", "disponible", "l'approche", "le décollage", "l'avion en l'air", "le pilote", "l'avion est cloué au sol"][phase]


# ---------------------------------------------------------------------
# Déroulement
# ---------------------------------------------------------------------
func _process(delta: float) -> void:
	if joueur == null:
		return
	var jp := joueur.global_position
	match phase:
		Phase.INDISPONIBLE:
			var m9: Node = main.get_node_or_null("Mission9")
			if m9 and m9.phase == Mission9.Phase.TERMINEE:
				_message()
		Phase.DISPONIBLE:
			if _plat(jp).distance_to(GARAGE) < 260.0 and kwame == null:
				_preparer_garage()
			if not garage_fait and kwame and _plat(jp).distance_to(GARAGE) < 6.0:
				_scene_garage()
		Phase.APPROCHE:
			_approche(delta)
		Phase.DECOLLAGE:
			_roulage(delta)
		Phase.VOL:
			_vol(delta)
	if phase == Phase.DECOLLAGE or phase == Phase.VOL:
		_pickups(delta)
	for hl in helices:
		var vit := 0.0 if avion == null or not avion.visible else (40.0 if phase in [Phase.APPROCHE, Phase.DECOLLAGE, Phase.VOL] else 0.0)
		if crash:
			vit = 0.0
		(hl as Node3D).rotate_object_local(Vector3.BACK, vit * delta)
	if phase in [Phase.APPROCHE, Phase.DECOLLAGE, Phase.VOL]:
		t_hud -= delta
		if t_hud <= 0.0:
			t_hud = 0.5
			_mettre_objectif()
	if t_relance > 0.0:
		t_relance -= delta
		if t_relance <= 0.0:
			_relancer_decollage()
	if t_reprise > 0.0:
		t_reprise -= delta
		if t_reprise <= 0.0:
			_reprendre()


func _message() -> void:
	phase = Phase.DISPONIBLE
	var tel: Node = main.get_node_or_null("Telephone")
	if tel:
		tel.notifier("Kwame : « Viens au garage, sortie nord de Port-Néré. J'ai un jouet pour toi. »")
	m4._annoncer("Le registre est formel : un avion part de la piste du nord à chaque aube, chargé de caisses pour Lagunaville.\nKWAME (radio) — « Viens au garage, à la sortie nord de Port-Néré. J'ai un jouet pour toi. »", 8.0)
	m4._objectif("Mission 10 — L'Avion : rejoignez Kwame à son garage, à la sortie nord de Port-Néré.")
	var ca: Node = main.get_node_or_null("Carte")
	if ca:
		ca.poser_balise(Vector3(GARAGE.x, 0.0, GARAGE.y))


func _preparer_garage() -> void:
	var vq: Node = main.get_node_or_null("VieQuotidienne")
	if vq == null:
		return
	var h := terrain.hauteur(GARAGE.x, GARAGE.y)
	kwame = vq._perso("kwame", "Reparer", Vector3(GARAGE.x + 1.2, h, GARAGE.y), -PI * 0.5)
	moto_moto = vq._perso("homme2", "Repos", Vector3(GARAGE.x - 1.5, h, GARAGE.y + 1.6), PI * 0.8)
	# la moto de Moto-Moto, gonflée : jaune et noire, comme tous les motos-taxis de l'île
	moto = MotoJoueur.new()
	moto.name = "MotoMotoMoto"
	main.add_child(moto)
	moto.preparer(joueur, Vector3(GARAGE.x, h + 0.4, GARAGE.y - 1.0), _cap_piste())
	moto._peindre(moto.modele, Color(0.95, 0.75, 0.05))
	moto.vmax_bonus = 2.0          # ~38 m/s poussée : « elle faisait du 140 »
	moto.accel_bonus = 1.8
	moto.tir_embarque = true
	# établi, pneus, bidons : le garage en plein air
	_boite(Vector3(2.4, 0.9, 0.8), Transform3D(Basis(Vector3.UP, 0.2), Vector3(GARAGE.x + 2.6, h + 0.45, GARAGE.y - 1.8)), Color(0.4, 0.3, 0.2))
	for i in 3:
		_cylindre(0.33, 0.33, 0.18, Transform3D(Basis(), Vector3(GARAGE.x - 3.0, h + 0.09 + i * 0.18, GARAGE.y - 2.0)), Color(0.07, 0.07, 0.07), self, 0.9)


func _scene_garage() -> void:
	garage_fait = true
	phase = Phase.APPROCHE
	t_approche = 0.0
	joueur.mission = self
	var amb: Ambiances = main.ambiances
	var garde := 0
	while amb.index != 4 and garde < 8:   # l'aube, le vent de mer
		amb.suivante()
		garde += 1
	m4._annoncer("Mission 10 — L'Avion", 3.5)
	@warning_ignore("missing_await")
	_dire("MOTO-MOTO", "Si tu l'abîmes, tu me la rembourses. En kauris, pas en promesses.", 1.5)
	@warning_ignore("missing_await")
	_dire("KWAME", "Elle fait du 140. Enfin, elle faisait du 140 avant que je la répare. Maintenant, je ne sais pas. Personne n'a osé essayer. (Clic droit pour viser en roulant.)", 8.0)
	@warning_ignore("missing_await")
	_dire("AMA (radio)", "Trois façons d'arriver : la route, à fond ; les dunes, à pied, pour leur percer le réservoir ; ou la plage derrière le hangar.", 16.0)
	@warning_ignore("missing_await")
	_dire("JOËL (radio)", "Et pas le cockpit ! Le pilote, il nous le faut vivant. Visez les roues ou un moteur.", 24.0)
	_installer_piste()


func _dire(qui: String, texte: String, delai: float) -> void:
	await get_tree().create_timer(delai).timeout
	m4._annoncer("%s — %s" % [qui, texte], 7.0)


func _installer_piste() -> void:
	avion.visible = true
	_placer_avion_depart()
	son_avion.play()
	son_avion.pitch_scale = 0.6        # moteurs au ralenti pendant le plein
	sirene = AudioStreamPlayer3D.new()
	var s: AudioStreamWAV = load("res://sons/sirene.wav")
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_end = int(s.get_length() * s.mix_rate)
	sirene.stream = s
	sirene.unit_size = 30.0
	sirene.max_distance = 700.0
	add_child(sirene)
	sirene.global_position = _point_piste(560.0, -LARGEUR * 0.5 - 22.0) + Vector3(0, 8, 0)
	# gardes de la piste : autour de l'avion, de la citerne et du hangar
	var postes := [[60.0, 9.0], [30.0, -10.0], [70.0, -14.0], [540.0, -30.0], [575.0, -40.0], [300.0, 16.0]]
	var modeles := ["homme2", "villageois", "homme3"]
	for i in postes.size():
		var p := _point_piste(postes[i][0], postes[i][1])
		var g := Pnj.new()
		add_child(g)
		g.global_position = p + Vector3(0, 0.4, 0)
		g.preparer("milicien", self, joueur, Color(1, 1, 1), "res://data/textures/camouflage.jpg", modeles[i % 3])
		var q := _point_piste(postes[i][0] + 14.0, postes[i][1])
		g.points_patrouille = [p, q]
		g.portee_vue = 34.0
		g.refuges = [p]
		g.alerte.connect(func(_q: Vector3) -> void: _alarme("Un garde vous a vu !"))
		g.rendu.connect(func(_n: Pnj) -> void: m4._annoncer("Le garde se rend : F pour le ligoter.", 2.5))
		gardes.append(g)
	# deux pick-up de la milice garés près du hangar
	for i in 2:
		var noeud: Node3D = (load("res://vehicules/pickup.glb") as PackedScene).instantiate()
		add_child(noeud)
		var corps := AnimatableBody3D.new()
		corps.sync_to_physics = false
		corps.collision_layer = 1
		corps.collision_mask = 0
		corps.set_meta("pickup", i)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(2.0, 1.8, 5.0)
		cs.shape = bs
		cs.position.y = 0.9
		corps.add_child(cs)
		noeud.add_child(corps)
		var vq: Node = main.get_node_or_null("VieQuotidienne")
		var tireur: Node3D = null
		if vq:
			tireur = vq._perso("villageois", "Repos", Vector3.ZERO, 0.0)
			vq._camoufler(tireur)
			tireur.reparent(noeud)
			tireur.position = Vector3(0, 1.0, -1.6)
			tireur.rotation = Vector3.ZERO
		var son := AudioStreamPlayer3D.new()
		son.stream = load("res://sons/tir.wav")
		son.unit_size = 14.0
		son.max_distance = 300.0
		noeud.add_child(son)
		var pk := {"noeud": noeud, "corps": corps, "pv": 14, "offset": -9.0 if i == 0 else 9.0, "s": 520.0 + i * 30.0,
				"v": 0.0, "tireur": tireur, "t_tir": 2.0 + i, "son": son, "mort": false}
		pickups.append(pk)
		_poser_pickup(pk)
	var ca: Node = main.get_node_or_null("Carte")
	if ca:
		ca.poser_balise(_point_piste(40.0))


func _poser_pickup(pk: Dictionary) -> void:
	var p := _point_piste(pk["s"], pk["offset"])
	(pk["noeud"] as Node3D).global_transform = Transform3D(Basis(Vector3.UP, _cap_piste()), p + Vector3(0, 0.05, 0))


func _mettre_objectif() -> void:
	match phase:
		Phase.APPROCHE:
			var t := "L'avion fait le plein au bout ouest de la piste. Approchez : route, dunes ou plage."
			t += "\nSaboter le réservoir : F sous l'aile gauche (3 s). " + ("✓ Réservoir percé" if sabote else "")
			m4._objectif(t)
		Phase.DECOLLAGE:
			var etat := "Train : %s · Moteur gauche : %s · Moteur droit : %s" % [_jauge(pv["train"], PV_TRAIN), _jauge(pv["moteur_g"], PV_MOTEUR), _jauge(pv["moteur_d"], PV_MOTEUR)]
			m4._objectif("L'avion décolle ! Rattrapez-le à moto et visez le train ou un moteur (clic droit, clic gauche). Pas le cockpit !\n" + etat + ("   — réservoir percé" if sabote else ""))
		Phase.VOL:
			m4._objectif("L'avion est en l'air…" + (" Le réservoir percé le trahit : il fait demi-tour vers la plage !" if sabote else ""))


func _jauge(v: int, vmax: int) -> String:
	# chiffres simples : la police du jeu n'a pas les carrés pleins et vides
	return "%d/%d" % [v, vmax] if v > 0 else "HORS D'USAGE"


func _approche(delta: float) -> void:
	var jp := joueur.global_position
	var d := _plat(jp).distance_to(_plat(avion.global_position))
	if d < 300.0:
		t_approche += delta
	# arriver à moto plein gaz : on l'entend de loin
	if joueur.a_cheval == moto and moto.vitesse > 14.0 and d < 160.0:
		_alarme("Le moteur de la moto hurle sur la route : la sirène se déclenche !")
		return
	if t_approche > 150.0:
		_alarme("Le plein est fini. Les moteurs montent en régime : l'avion va partir.")
		return
	# sabotage du réservoir, sous l'aile gauche
	var vanne := avion.global_transform * Vector3(-2.2, 1.8, 1.0)
	if t_sabotage >= 0.0:
		if jp.distance_to(vanne) > 2.6:
			t_sabotage = -1.0
			m4._annoncer("Sabotage interrompu.", 1.5)
		else:
			t_sabotage -= delta
			if t_sabotage <= 0.0:
				t_sabotage = -1.0
				sabote = true
				m4._annoncer("Un filet de kérosène coule dans le sable, sans un bruit. Le réservoir ne tiendra pas un vol entier.", 4.5)


func _alarme(raison: String) -> void:
	if phase != Phase.APPROCHE:
		return
	phase = Phase.DECOLLAGE
	m4._annoncer(raison + "\nL'avion commence à rouler !", 4.0)
	if sirene:
		sirene.play()
	for g in gardes:
		if (g as Pnj).est_actif():
			(g as Pnj)._passer_combat()
	v_avion = 0.0
	for pk in pickups:
		pk["s"] = s_avion + 30.0 + (0.0 if pk["offset"] < 0.0 else 20.0)
		pk["v"] = 0.0
		_poser_pickup(pk)


func _roulage(delta: float) -> void:
	if not avion.visible:
		return            # l'avion est parti ou le témoin est mort : on attend la reprise
	var moteurs := int(pv["moteur_g"] > 0) + int(pv["moteur_d"] > 0)
	son_avion.pitch_scale = lerpf(son_avion.pitch_scale, 0.75 + 0.35 * clampf(v_avion / V_ROTATION, 0.0, 1.0) * moteurs * 0.5, delta)
	if not crash:
		var acc := ACCEL * moteurs * 0.5
		v_avion += acc * delta
		s_avion += v_avion * delta
		# une roue crevée ou un moteur mort : l'avion part en travers
		if pv["train"] <= 0 or moteurs < 2:
			crash = true
			crash_cote = -1.0 if pv["moteur_g"] <= 0 else 1.0
			m4._annoncer("L'avion embarde ! Il quitte la piste dans un nuage de poussière…", 3.5)
			if sirene:
				sirene.stop()
		elif v_avion >= V_ROTATION:
			_decoller()
			return
		poussiere.emitting = v_avion > 6.0
		_poser_avion(0.0)
	else:
		# sortie de piste : il ralentit, pivote, s'enfonce dans les buissons
		v_avion = maxf(0.0, v_avion - 7.0 * delta)
		s_avion += v_avion * delta
		ecart += crash_cote * v_avion * delta * 0.45
		lacet_avion = lerpf(lacet_avion, crash_cote * 0.7, delta * 0.8)
		poussiere.emitting = v_avion > 2.0
		_poser_avion(0.0)
		avion.rotate_object_local(Vector3.BACK, crash_cote * 0.08 * clampf(v_avion / 10.0, 0.0, 1.0))
		if v_avion <= 0.0:
			_pilote()
	if s_avion > PISTE_A.distance_to(PISTE_B) - 10.0 and not crash:
		_decoller()


func _decoller() -> void:
	phase = Phase.VOL
	poussiere.emitting = false
	if sirene:
		sirene.stop()
	t_vol = 0.0
	# trajectoire : montée vers l'est, virage au-dessus de la mer, puis (réservoir percé)
	# retour le long de la côte et atterrissage forcé sur la plage
	var debut := avion.global_position
	var dir := Vector3((PISTE_B - PISTE_A).normalized().x, 0, (PISTE_B - PISTE_A).normalized().y)
	trajectoire = Curve3D.new()
	trajectoire.add_point(debut)
	trajectoire.add_point(debut + dir * 260.0 + Vector3(0, 45, 0))
	trajectoire.add_point(debut + dir * 520.0 + Vector3(0, 80, -160))
	trajectoire.add_point(Vector3(-300, 90, -1380))
	if sabote:
		trajectoire.add_point(Vector3(-480, 60, -1260))
		trajectoire.add_point(Vector3(PLAGE_A.x + 120, 25, PLAGE_A.y - 20))
		trajectoire.add_point(Vector3(PLAGE_A.x, 3.0, PLAGE_A.y))
		trajectoire.add_point(Vector3(PLAGE_A.lerp(PLAGE_B, 0.6).x, 1.6, PLAGE_A.lerp(PLAGE_B, 0.6).y))
		m4._annoncer("Il décolle… JOËL (radio) — « Il perd du carburant ! Il ne tiendra pas jusqu'au continent ! »", 4.5)
	else:
		trajectoire.add_point(Vector3(400, 160, -1900))
		m4._annoncer("L'avion s'arrache de la piste et file vers le continent…", 4.0)


func _vol(delta: float) -> void:
	t_vol += delta
	var longueur := trajectoire.get_baked_length()
	var v := 34.0 if not sabote or t_vol < 18.0 else 26.0
	var d := clampf(t_vol * v, 0.0, longueur)
	var p := trajectoire.sample_baked(d)
	var p2 := trajectoire.sample_baked(minf(d + 4.0, longueur))
	var dir := p2 - p
	if dir.length() > 0.01:
		avion.global_transform = Transform3D(Basis.looking_at(-dir.normalized(), Vector3.UP), p)
	if sabote and t_vol > 16.0:
		fumee_moteur.position = Vector3(-3.2, 2.25, 0.5)
		fumee_moteur.emitting = true
		son_avion.pitch_scale = 0.7 + 0.15 * sin(t_vol * 7.0)   # le moteur tousse
	if d >= longueur - 0.5:
		if sabote:
			crash = true
			poussiere.emitting = true
			m4._annoncer("Le bimoteur rebondit sur le sable, laboure la plage et s'immobilise au bord de l'eau.", 4.5)
			get_tree().create_timer(2.0).timeout.connect(func() -> void: poussiere.emitting = false)
			_pilote()
		else:
			m4._annoncer("L'avion a disparu à l'horizon. Avec les caisses, et avec le pilote.\nOn reprend au début du décollage.", 5.0)
			phase = Phase.DECOLLAGE
			avion.visible = false
			t_relance = 5.5


func _relancer_decollage() -> void:
	avion.visible = true
	fumee_moteur.emitting = false
	_placer_avion_depart()
	pv = {"train": PV_TRAIN, "moteur_g": PV_MOTEUR, "moteur_d": PV_MOTEUR}
	tirs_cockpit = 0
	phase = Phase.APPROCHE
	# Faris sur la moto, juste derrière l'avion
	if moto:
		if joueur.a_cheval == null:
			joueur.global_position = moto.global_position
			moto.monter()
		var p := _point_piste(s_avion - 50.0, 6.0)
		moto.global_position = p + Vector3(0, 0.5, 0)
		moto.cap = _cap_piste()
		moto.vitesse = 0.0
	_alarme("Encore une fois.")


# ---------- pick-up d'escorte ----------
func _pickups(delta: float) -> void:
	for pk in pickups:
		if pk["mort"]:
			continue
		var noeud: Node3D = pk["noeud"]
		if phase == Phase.DECOLLAGE and not crash:
			# ils roulent à hauteur de l'avion, un peu en arrière
			var cible := s_avion - 15.0
			var vcible := v_avion + clampf((cible - float(pk["s"])) * 0.5, -6.0, 8.0)
			pk["v"] = move_toward(pk["v"], clampf(vcible, 0.0, 30.0), 6.0 * delta)
		else:
			pk["v"] = move_toward(pk["v"], 0.0, 8.0 * delta)
		pk["s"] = float(pk["s"]) + float(pk["v"]) * delta
		_poser_pickup(pk)
		# le tireur de la plateforme arrière
		pk["t_tir"] = float(pk["t_tir"]) - delta
		var jp := joueur.global_position + Vector3(0, 1.0, 0)
		var depart := noeud.global_position + Vector3(0, 2.2, 0)
		if pk["t_tir"] <= 0.0 and depart.distance_to(jp) < 70.0 and not joueur.mort:
			pk["t_tir"] = randf_range(1.2, 2.0)
			(pk["son"] as AudioStreamPlayer3D).play()
			var q := PhysicsRayQueryParameters3D.create(depart, jp, 1)
			q.exclude = [(pk["corps"] as AnimatableBody3D).get_rid()]
			if get_world_3d().direct_space_state.intersect_ray(q).is_empty():
				var vit := joueur.vitesse_affichee
				var chance := clampf(0.5 - vit * 0.012 - depart.distance_to(jp) * 0.004, 0.08, 0.5)
				if randf() < chance:
					joueur.blesser(7.0)


# ---------- ce que la balle de Faris a touché ----------
func _impact(collider: Object, _p: Vector3) -> void:
	if collider == null or not (collider as Node).has_meta("partie_avion") and not (collider as Node).has_meta("pickup"):
		return
	if (collider as Node).has_meta("pickup"):
		var pk: Dictionary = pickups[int((collider as Node).get_meta("pickup"))]
		if pk["mort"]:
			return
		pk["pv"] = int(pk["pv"]) - 1
		if int(pk["pv"]) <= 0:
			pk["mort"] = true
			pk["v"] = 0.0
			var f := fumee_moteur.duplicate() as CPUParticles3D
			(pk["noeud"] as Node3D).add_child(f)
			f.position = Vector3(0, 1.2, 1.8)
			f.emitting = true
			if pk["tireur"]:
				(pk["tireur"] as Node3D).visible = false    # le tireur saute et s'enfuit dans les buissons
			m4._annoncer("Le pick-up crache de la fumée et s'arrête. Le tireur saute et s'enfuit.", 2.5)
		return
	if phase != Phase.DECOLLAGE or crash:
		return
	var nom := str((collider as Node).get_meta("partie_avion"))
	match nom:
		"cockpit":
			tirs_cockpit += 1
			if tirs_cockpit >= 3:
				m4._annoncer("Le pare-brise éclate. L'avion s'arrête… et le pilote ne bouge plus.\nLe témoin est mort. MISSION MANQUÉE — on reprend le décollage.", 6.0)
				avion.visible = false
				t_relance = 6.5
				crash = true
			else:
				m4._annoncer("JOËL (radio) — « PAS LE COCKPIT ! »", 2.0)
		"train", "moteur_g", "moteur_d":
			pv[nom] = maxi(0, int(pv[nom]) - 1)
			if int(pv[nom]) == 0:
				match nom:
					"train":
						m4._annoncer("Le pneu du train principal éclate !", 2.0)
					_:
						m4._annoncer("Le moteur prend feu et s'arrête !", 2.0)
						fumee_moteur.position = Vector3(-3.2 if nom == "moteur_g" else 3.2, 2.25, 0.5)
						fumee_moteur.emitting = true


# ---------------------------------------------------------------------
# Le pilote
# ---------------------------------------------------------------------
func _pilote() -> void:
	if phase == Phase.PILOTE:
		return
	phase = Phase.PILOTE
	son_avion.stop()
	for pk in pickups:
		pk["v"] = 0.0
	var porte := avion.global_transform * Vector3(-4.2, 0.0, 2.5)   # à l'écart du fuselage, bien visible
	porte.y = terrain.hauteur(porte.x, porte.z)
	ndoro = Pnj.new()
	add_child(ndoro)
	ndoro.global_position = porte + Vector3(0, 0.3, 0)
	ndoro.preparer("civil", self, joueur, Color(0.75, 0.68, 0.55), "", "homme3")   # chemise couverte de poussière
	ndoro.refuges = [porte]
	ndoro.etat = Pnj.Etat.DESARME
	ndoro.anim.play("Rendu", 0.5)
	m4._annoncer("Le pilote sort à quatre pattes, couvert de poussière, les mains en l'air. (F pour l'interroger)", 5.0)
	m4._objectif("Interrogez le pilote (F).")
	var ca: Node = main.get_node_or_null("Carte")
	if ca:
		ca.poser_balise(porte)


func interagir() -> void:
	var jp := joueur.global_position
	if phase == Phase.PILOTE and ndoro and not interroge and jp.distance_to(ndoro.global_position) < 3.5:
		interroge = true
		@warning_ignore("missing_await")
		_interrogatoire()
		return
	if phase == Phase.APPROCHE and not sabote and t_sabotage < 0.0:
		var vanne := avion.global_transform * Vector3(-2.2, 1.8, 1.0)
		if jp.distance_to(vanne) < 2.6:
			for g in gardes:
				var p := g as Pnj
				if p.est_actif() and p.global_position.distance_to(jp) < 12.0 and not p.dos_au_joueur():
					m4._annoncer("Un garde vous verrait. Attendez qu'il tourne le dos.", 2.5)
					return
			t_sabotage = 3.0
			m4._annoncer("Faris dévisse le bouchon de vidange du réservoir… (restez sous l'aile)", 3.0)
			return
	for g in gardes:
		var p := g as Pnj
		if p.global_position.distance_to(jp) < 2.0 and (p.etat == Pnj.Etat.RENDU or (p.est_actif() and p.dos_au_joueur())):
			p.ligoter()
			m4._annoncer("Garde ligoté.", 2.0)
			return


func _interrogatoire() -> void:
	var lignes := [
		["NDORO", "Je ne suis qu'un pilote ! On me paie pour voler, pas pour poser des questions !"],
		["FARIS", "Alors je vais poser les questions. Les caisses vont où ?"],
		["NDORO", "Lagunaville. Au Patron des Docks. Et après… après je ne sais pas."],
		["NDORO", "(Faris le fixe.) … Après, une partie de l'argent part à la capitale. Au ministère de l'Agriculture. Le ministre Augustin Okoro touche sa part sur chaque vol. Tout le monde le sait, personne ne le dit."],
	]
	for l in lignes:
		m4._annoncer("%s — « %s »" % l, 6.5)
		await get_tree().create_timer(6.8).timeout
	choix_ui.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _choisir(c: String) -> void:
	choix = c
	choix_ui.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var tel: Node = main.get_node_or_null("Telephone")
	if c == "racines":
		main.set_meta("temoin_ndoro", true)
		m4._annoncer("Ama emmène Ndoro vers Akwéri, sous bonne garde. « Ceux que tu accuses voudront te faire taire. Nous, non. »", 6.0)
		if tel:
			tel.ajouter_preuve("Témoin : Marc Ndoro", "Le pilote de l'avion de contrebande accepte de témoigner : les caisses vont au Patron des Docks à Lagunaville, et le ministre de l'Agriculture, Augustin Okoro, touche sa part sur chaque vol.")
	else:
		main.set_meta("cle_casier", true)
		m4._annoncer("Ndoro pousse une pirogue à l'eau. Avant de partir, il glisse une petite clé dans la main de Faris : « Casier 214, gare maritime de Lagunaville. Je n'ai jamais été là. »", 7.0)
		if tel:
			tel.ajouter_preuve("Une clé de casier", "Casier 214, gare maritime de Lagunaville. Donnée par le pilote Marc Ndoro avant de disparaître. Il affirme que le ministre de l'Agriculture, Augustin Okoro, touche sa part sur chaque vol.")
	await get_tree().create_timer(7.0).timeout
	phase = Phase.TERMINEE
	joueur.mission = m4
	if tel:
		tel.notifier("Tableau des preuves : Cobra → Syndicat des Docks → ministre de l'Agriculture.")
	m4.confiance = clampi(m4.confiance + 5, 0, 100)
	m4._annoncer("FARIS (seul, devant le tableau des preuves) — « Ce n'est pas une milice. C'est un système. »", 7.0)
	m4._objectif("Prochain objectif : préparer l'assaut du camp du Cobra (mission 11, « Le Serpent »).")


## Après un chargement de partie : la mission est déjà faite.
func restaurer_terminee(p_choix: String) -> void:
	choix = p_choix
	phase = Phase.TERMINEE
	interroge = true
	m4._objectif("Prochain objectif : préparer l'assaut du camp du Cobra (mission 11, « Le Serpent »).")


# ---------------------------------------------------------------------
# Chute de Faris : on reprend au hangar, la moto à côté
# ---------------------------------------------------------------------
func _tombe() -> void:
	if not (phase in [Phase.APPROCHE, Phase.DECOLLAGE, Phase.VOL]):
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
	var ici := _point_piste(maxf(0.0, s_avion - 70.0), 10.0)
	joueur.ressusciter(ici + Vector3(0, 0.6, 0))
	if moto:
		moto.global_position = ici + Vector3(2.0, 0.6, 0)
		moto.cap = _cap_piste()
		moto.vitesse = 0.0
	if phase == Phase.DECOLLAGE and not crash:
		# on recommence le décollage proprement
		avion.visible = false
		t_relance = 1.0
	m4._annoncer("Moto-Moto vous a ramassé sur le bord de la piste… Reprise.", 3.0)


# ---------- ce que les Pnj demandent ----------
func choisir_couvert(n: Pnj) -> Vector3:
	return n.global_position


func bruit_de_tir(p: Vector3, _joueur_tire := false) -> void:
	for g in gardes:
		(g as Pnj).entendre(p, 90.0)


func blessure() -> void:
	m4.blessure()


func _plat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)

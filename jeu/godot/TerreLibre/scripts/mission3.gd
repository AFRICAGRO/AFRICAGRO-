## Mission 3 — « Le Pêcheur » (jeu/missions/03-LE-PECHEUR.md). Aucun tir pour Faris ; personne n'est blessé.
## Akwéri au petit matin : Esther, Ama qui refuse de parler → le racket : le hors-bord de la milice,
## « la taxe du Cobra », les filets du vieux Mensah tranchés ; Ama part en trombe avec la caisse du village
## → la poursuite en pirogue à moteur le long de la côte ouest : deux champs de récifs (les pirogues passent,
## le hors-bord racle et ralentit), la vague qui se brise (le hors-bord se retourne à moitié et cale) ;
## rattrapé trois fois, Faris tombe à l'eau et reprend au dernier passage réussi → la crique sous les
## falaises : Ama rejoint les Racines → retour à Akwéri (mission 4).
class_name Mission3
extends Recit

enum Phase { INDISPONIBLE, VILLAGE, RACKET, EMBARQUER, POURSUITE, CRIQUE, TERMINEE }
const V_HB := 10.4              # hors-bord en eau libre : plus rapide que la pirogue…
const V_HB_RECIF := 3.0         # … mais plus lourd : il racle les récifs
const LONG_RECIF := 110.0

var phase := Phase.INDISPONIBLE
var village: VillageAkweri
var c2 := Vector2.ZERO
var mer2 := Vector2(-1, 0)
var plage2 := Vector2(0, -1)
var bord := Vector2.ZERO
var sable := Vector2.ZERO
var entree := Vector3.ZERO
# le chemin de la poursuite, le long de la côte (abscisse curviligne s)
var chemin := PackedVector2Array()
var cumul := PackedFloat32Array()
var longueur := 0.0
var recifs: Array = []          # [s0, s1]
var rochers: Array = []         # [Vector2, rayon]
var s_vague := 0.0
var crique := Vector2.ZERO
# acteurs
var esther: Node3D
var mensah: Node3D
var ama: Node3D
var ama_pir: Node3D
var hb: Node3D
var hb_gardes: Array = []
var pir: PirogueJoueur
var filet: MeshInstance3D
var vague: MeshInstance3D
var rochers_mm: Node3D
# poursuite
var s_a := 0.0
var lat_a := 0.0
var s_h := 0.0
var lat_h := 0.0
var s_p := 0.0
var i_p := 0
var s_reprise := 0.0
var touches := 0
var t_recup := 0.0
var t_tir := 2.0
var tirs_annonces := false
var racle_annonce := {}
var vague_lancee := false
var vague_passee := false
var chavire := 0.0              # 0 : en course ; > 0 : retourné (temps écoulé)
var hb_dehors := false
var esther_vue := false
var ama_parle := false
var t_loin := 0.0
var son_hb: AudioStreamPlayer3D
var son_tir: AudioStreamPlayer3D
var eclair: OmniLight3D


func construire(p_main: Node) -> void:
	preparer_recit(p_main)
	village = main.get_node("Akweri")
	c2 = village.centre
	mer2 = village.mer
	plage2 = village.plage
	var q := c2 - mer2 * 20.0
	for i in 300:
		if terrain.hauteur(q.x, q.y) < -0.4:
			break
		q += mer2
	bord = q
	# le sable sec : à partir du bord de l'eau, vers la terre, jusqu'à 35 cm au-dessus de la mer
	var r := bord
	for i in 120:
		if terrain.hauteur(r.x, r.y) > 0.35:
			break
		r -= mer2
	sable = r
	entree = _au_sol(Vector3(c2.x, 0, c2.y) - Vector3(mer2.x, 0, mer2.y) * 55.0)
	_tracer_chemin()


func est_terminee() -> bool:
	return phase == Phase.TERMINEE


## Chargement d'une partie où cette mission n'a pas encore commencé.
func annuler() -> void:
	if phase == Phase.INDISPONIBLE:
		return
	terminer()
	phase = Phase.INDISPONIBLE


func etat_texte() -> String:
	return ["à venir", "Akwéri", "le racket", "la pirogue", "la poursuite", "la crique", "terminée"][phase]


# ---------------------------------------------------------------------
# Le chemin de la poursuite : en eau de 4 m, à quelques dizaines de mètres de la côte
# ---------------------------------------------------------------------
func _eau(p: Vector2, prof: float) -> Vector2:
	var q := p
	for i in 400:
		if terrain.hauteur(q.x, q.y) < prof:
			return q
		q += mer2
	return q


func _tracer_chemin() -> void:
	var pts: Array = [_eau(bord + mer2 * 6.0 - plage2 * 4.0, -0.9)]
	for k in range(1, 35):
		var l := c2 + plage2 * (k * 28.0)
		pts.append(_eau(l - mer2 * 30.0, -3.6) + mer2 * 10.0)
	for _passe in 2:
		var lisse := pts.duplicate()
		for i in range(1, pts.size() - 1):
			lisse[i] = (pts[i - 1] + (pts[i] as Vector2) * 2.0 + pts[i + 1]) * 0.25
		pts = lisse
	# la crique : on entre vers la côte jusqu'à 1,2 m de fond
	var fin: Vector2 = pts[pts.size() - 1]
	var c := fin
	for i in 200:
		if terrain.hauteur(c.x, c.y) > -1.4:
			break
		c -= mer2
	crique = c + mer2 * 3.0
	pts.append(crique)
	chemin = PackedVector2Array(pts)
	cumul = PackedFloat32Array([0.0])
	for i in range(1, chemin.size()):
		cumul.append(cumul[i - 1] + chemin[i - 1].distance_to(chemin[i]))
	longueur = cumul[cumul.size() - 1]
	recifs = [[longueur * 0.2, longueur * 0.2 + LONG_RECIF], [longueur * 0.5, longueur * 0.5 + LONG_RECIF]]
	s_vague = longueur * 0.82


func _pt(s: float) -> Vector2:
	s = clampf(s, 0.0, longueur)
	for i in range(1, cumul.size()):
		if s <= cumul[i]:
			var u := (s - cumul[i - 1]) / maxf(0.01, cumul[i] - cumul[i - 1])
			return chemin[i - 1].lerp(chemin[i], u)
	return chemin[chemin.size() - 1]


func _tan(s: float) -> Vector2:
	var t := _pt(s + 2.0) - _pt(s - 2.0)
	return t.normalized() if t.length() > 0.01 else plage2


## Normale au chemin, tournée vers le large.
func _nor(s: float) -> Vector2:
	var t := _tan(s)
	var n := Vector2(-t.y, t.x)
	return n if n.dot(mer2) > 0.0 else -n


## Axe du passage dans un champ de récifs (décalage latéral qui serpente).
func _axe(s: float) -> float:
	for r in recifs:
		if s >= r[0] and s <= r[1]:
			return 7.0 * sin((s - float(r[0])) / 18.0)
	return 0.0


func _dans_recif(s: float) -> bool:
	for r in recifs:
		if s >= r[0] and s <= r[1]:
			return true
	return false


func _monde(s: float, lat: float, dy := 0.0) -> Vector3:
	var p := _pt(s) + _nor(s) * lat
	return Vector3(p.x, dy, p.y)


## Projection de la pirogue de Faris sur le chemin (recherche autour du dernier segment).
func _projeter(p: Vector2) -> Array:
	var meilleur := INF
	var res := [s_p, 0.0]
	for i in range(maxi(1, i_p - 3), mini(chemin.size(), i_p + 4)):
		var a := chemin[i - 1]
		var ab := chemin[i] - a
		var u := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var q := a + ab * u
		var d := p.distance_to(q)
		if d < meilleur:
			meilleur = d
			i_p = i
			var s := cumul[i - 1] + ab.length() * u
			res = [s, (p - q).dot(_nor(s))]
	return res


# ---------------------------------------------------------------------
# Décor de la côte : récifs, vague, crique
# ---------------------------------------------------------------------
func _installer_cote() -> void:
	rochers.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 303
	var xfs: Array = []
	for r in recifs:
		var s: float = r[0]
		while s <= r[1]:
			var n := -34.0
			while n <= 50.0:
				var lat := n + rng.randf_range(-2.5, 2.5)
				if absf(lat - _axe(s)) > 4.6 and rng.randf() < 0.85:
					var p := _pt(s) + _nor(s) * lat + _tan(s) * rng.randf_range(-2.0, 2.0)
					if terrain.hauteur(p.x, p.y) < -0.3:
						var rayon := rng.randf_range(1.0, 2.4)
						rochers.append([p, rayon])
						xfs.append([p, rayon, rng.randf_range(0.25, 2.2), rng.randf() * TAU])
				n += 7.0
			s += 6.5
	# la crique : de hautes roches sombres de part et d'autre, comme une porte dans la falaise
	var t := _tan(longueur - 1.0)
	for k in 14:
		var cote := -1.0 if k % 2 == 0 else 1.0
		var p := crique + Vector2(-t.y, t.x) * cote * (11.0 + rng.randf_range(0, 3)) - mer2 * floorf(k / 2.0) * 3.0 + t * rng.randf_range(-3, 3)
		xfs.append([p, rng.randf_range(2.5, 4.0), rng.randf_range(5.0, 11.0), rng.randf() * TAU])
	rochers_mm = Node3D.new()
	add_child(rochers_mm)
	decor.append(rochers_mm)
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 8
	sm.rings = 4
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.15, 0.14)       # basalte sombre, comme la côte volcanique
	mat.roughness = 1.0
	sm.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = sm
	mm.instance_count = xfs.size()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 0.04
	cm.radial_segments = 10
	var mecume := StandardMaterial3D.new()
	mecume.albedo_color = Color(0.95, 0.97, 1.0, 0.32)
	mecume.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mecume.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.material = mecume
	var me := MultiMesh.new()
	me.transform_format = MultiMesh.TRANSFORM_3D
	me.mesh = cm
	me.instance_count = xfs.size()
	for i in xfs.size():
		var x: Array = xfs[i]
		var p: Vector2 = x[0]
		var r: float = x[1]
		var h: float = x[2]
		var b := Basis(Vector3.UP, x[3]) * Basis(Vector3(1, 0, 0), rng.randf_range(-0.25, 0.25)).scaled(Vector3(r, h, r * 0.75))
		mm.set_instance_transform(i, Transform3D(b, Vector3(p.x, h * 0.3 - 0.15, p.y)))
		me.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(r * 1.2, 1, r * 1.2)), Vector3(p.x, 0.04, p.y)))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	rochers_mm.add_child(mi)
	var mie := MultiMeshInstance3D.new()
	mie.multimesh = me
	mie.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rochers_mm.add_child(mie)
	# la vague (cachée jusqu'au moment venu) : un rouleau d'eau translucide couronné d'écume
	vague = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.7
	cyl.bottom_radius = 1.7
	cyl.height = 110.0
	cyl.radial_segments = 14
	vague.mesh = cyl
	var mv := StandardMaterial3D.new()
	mv.albedo_color = Color(0.3, 0.62, 0.64, 0.9)
	mv.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mv.roughness = 0.08
	mv.rim_enabled = true
	mv.rim = 0.6
	vague.material_override = mv
	vague.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(vague)
	decor.append(vague)
	var crete := MeshInstance3D.new()
	var bc := BoxMesh.new()
	bc.size = Vector3(1.3, 108.0, 0.5)
	crete.mesh = bc
	var mc := StandardMaterial3D.new()
	mc.albedo_color = Color(0.97, 0.98, 1.0, 0.9)
	mc.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	crete.material_override = mc
	vague.add_child(crete)
	var tv := _tan(s_vague)
	var pv := _pt(s_vague)
	# l'axe du rouleau (Y du cylindre) couché perpendiculairement au chemin
	var axe := Vector3(-tv.y, 0, tv.x)
	var avance := Vector3(tv.x, 0, tv.y)
	# aplatie et étirée dans le sens de la marche : une houle qui se dresse, pas un tuyau
	vague.global_transform = Transform3D(Basis(avance * 2.6, axe, avance.cross(axe) * 0.75), Vector3(pv.x, -1.9, pv.y))
	# dans ce repère, -Z local est le haut du monde : l'écume couronne la crête
	crete.transform = Transform3D(Basis(), Vector3(0.25, 0.0, -1.8))
	vague.visible = false


func _bloque(p: Vector2) -> bool:
	for r in rochers:
		if p.distance_squared_to(r[0]) < pow(float(r[1]) + 0.5, 2.0):
			return true
	return false


# ---------------------------------------------------------------------
# Akwéri au petit matin
# ---------------------------------------------------------------------
func commencer() -> void:
	gen += 1
	_effacer_decor()
	_effacer_pirogue()
	phase = Phase.VILLAGE
	joueur.mission = self
	esther_vue = false
	ama_parle = false
	touches = 0
	vague_lancee = false
	vague_passee = false
	chavire = 0.0
	hb_dehors = false
	racle_annonce.clear()
	_ambiance(4)
	joueur.visible = true
	joueur.ressusciter(entree + Vector3(0, 0.6, 0))
	m4.reprise_prologue = entree + Vector3(0, 0.6, 0)
	joueur.lacet = atan2(-mer2.x, -mer2.y)
	_installer_cote()
	_installer_village()
	_objectif("Descendez au village d'Akwéri et trouvez Ama sur la plage.")
	_balise(ama.global_position)
	_entree_en_fondu()
	@warning_ignore("missing_await")
	_dire("", "Akwéri, au petit matin. Les pirogues peintes rentrent de la pêche, les femmes fument le poisson, les enfants courent sur le sable.", 6.0)


func _sur_sable(avant: float, cote: float) -> Vector3:
	var p := sable + mer2 * avant + plage2 * cote
	return _au_sol(Vector3(p.x, 0, p.y))


func _installer_village() -> void:
	esther = _perso("femme2", "Repos", _sur_sable(-7.0, -14.0), 0.0)
	_tourner_vers(esther, _sur_sable(0.0, -10.0))
	regards.append([esther, 10.0])
	mensah = _perso("pecheur", "Reparer", _sur_sable(-2.5, -8.0), 0.0)
	_tourner_vers(mensah, _sur_sable(4.0, -8.0))
	# le filet de Mensah, étalé sur le sable
	filet = MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(3.0, 2.0)
	filet.mesh = qm
	var mf := StandardMaterial3D.new()
	mf.albedo_texture = vq._texture_filet()
	mf.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mf.cull_mode = BaseMaterial3D.CULL_DISABLED
	mf.uv1_scale = Vector3(6, 4, 1)
	filet.material_override = mf
	add_child(filet)
	decor.append(filet)
	filet.global_transform = Transform3D(Basis(Vector3(1, 0, 0), -PI * 0.5), _sur_sable(-0.8, -9.5) + Vector3(0, 0.03, 0))
	# la pirogue bleue d'Ama, dans l'eau, et Ama debout à côté
	ama_pir = Node3D.new()
	add_child(ama_pir)
	decor.append(ama_pir)
	var coque := MeshInstance3D.new()
	coque.mesh = vq._pirogue_maillage()
	ama_pir.add_child(coque)
	_boite(Vector3(0.7, 0.35, 0.5), Transform3D(Basis(), Vector3(0, 0.35, 0.6)), Color(0.42, 0.62, 0.75), ama_pir)   # la caisse de poisson du village
	(ama_pir.get_child(1) as Node3D).position = Vector3(0, 0.35, 0.6)
	_moteur(ama_pir)
	_poser(ama_pir, chemin[0], _tan(0.0))
	ama = _perso("femme", "Repos", _sur_sable(0.0, -4.0), 0.0)
	_tourner_vers(ama, ama_pir.global_position)
	_inviter(ama, "parler à Ama", _parler_ama)
	# la pirogue du fils de Mensah, à côté
	var pp := _eau(bord - plage2 * 11.0 + mer2 * 4.0, -0.8) + mer2 * 2.0
	pir = PirogueJoueur.new()
	pir.name = "PirogueMensah"
	main.add_child(pir)
	pir.moteur = true
	pir.preparer(joueur, terrain, [], vq._pirogue_maillage(), pp, atan2(plage2.x, plage2.y))
	pir.obstacles = [_bloque]
	_moteur(pir.assiette)
	pir.set_process_unhandled_input(false)       # pas avant que Mensah la lui donne


func _moteur(parent: Node3D) -> void:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.28, 0.75, 0.32)
	m.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.12, 0.13)
	m.material_override = mat
	parent.add_child(m)
	m.position = Vector3(0, 0.25, -3.05)


func _poser(n: Node3D, p: Vector2, dir: Vector2, y := 0.0) -> void:
	n.global_position = Vector3(p.x, y - 0.2, p.y)
	n.rotation.y = atan2(dir.x, dir.y)


func _effacer_pirogue() -> void:
	if pir and is_instance_valid(pir):
		if pir.monte:
			pir.verrou = false
			pir.descendre()
		pir.queue_free()
	pir = null


func _process(delta: float) -> void:
	if joueur == null or phase == Phase.INDISPONIBLE or phase == Phase.TERMINEE:
		return
	_process_recit(delta)
	var jp := joueur.global_position
	match phase:
		Phase.VILLAGE:
			if not esther_vue and jp.distance_to(esther.global_position) < 12.0:
				esther_vue = true
				@warning_ignore("missing_await")
				_scene([["ESTHER", "Faris ? Le petit de Samuel ? Comme tu as grandi…"],
						["ESTHER", "Ama ? Là-bas, à sa pirogue. La bleue. Mais je te préviens : elle mord."]])
		Phase.EMBARQUER:
			_course(delta, false)
			if pir.monte:
				@warning_ignore("missing_await")
				_partir()
		Phase.POURSUITE:
			_course(delta, true)
	if hb and chavire > 0.0:
		chavire += delta
		hb.rotation.z = lerpf(hb.rotation.z, 1.25, minf(1.0, delta * 1.5))


func _parler_ama() -> void:
	if ama_parle or en_scene:
		return
	ama_parle = true
	invites.clear()
	_cinematique(true)
	_tourner_vers(ama, jp3())
	joueur.corps.rotation.y = atan2(ama.global_position.x - jp3().x, ama.global_position.z - jp3().z)
	_plan_dialogue(jp3(), ama.global_position)
	if not await _scene([
		["AMA", "Ton père posait trop de questions. Regarde où ça l'a mené. Rentre chez toi, l'étranger."],
		["FARIS", "Il avait ta photo dans ses affaires. Pourquoi ?"],
		["AMA", "(Elle se fige.) … Pas ici."],
	]):
		return
	@warning_ignore("missing_await")
	_racket()


func jp3() -> Vector3:
	return joueur.global_position


# ---------------------------------------------------------------------
# Le racket
# ---------------------------------------------------------------------
func _hors_bord() -> void:
	hb = Node3D.new()
	add_child(hb)
	decor.append(hb)
	var blanc := Color(0.9, 0.9, 0.88)
	_boite(Vector3(2.2, 0.75, 6.0), Transform3D(Basis(), Vector3(0, 0.1, 0)), blanc, hb)
	_boite(Vector3(2.22, 0.14, 6.02), Transform3D(Basis(), Vector3(0, 0.25, 0)), Color(0.12, 0.42, 0.18), hb)
	_boite(Vector3(1.4, 0.6, 1.3), Transform3D(Basis(Vector3(1, 0, 0), 0.25), Vector3(0, 0.55, 2.7)), blanc, hb)   # proue
	_boite(Vector3(0.4, 0.9, 0.45), Transform3D(Basis(), Vector3(0, 0.45, -3.2)), Color(0.1, 0.1, 0.1), hb)        # moteur
	_boite(Vector3(1.4, 0.5, 0.06), Transform3D(Basis(Vector3(1, 0, 0), -0.4), Vector3(0, 0.95, 0.9)), Color(0.4, 0.5, 0.6), hb)   # pare-brise
	hb_gardes.clear()
	for k in 2:
		var g := vq._perso(["homme2", "villageois"][k], "Assis" if k == 0 else "Repos", Vector3.ZERO, 0.0)
		g.reparent(hb)
		g.position = Vector3(0.3, 0.2, -1.6) if k == 0 else Vector3(-0.2, 0.45, 0.6)
		g.rotation = Vector3.ZERO
		vq._camoufler(g)
		_foulard(g)
		hb_gardes.append(g)
	var s: AudioStreamWAV = load("res://sons/moto.wav")
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_end = int(s.get_length() * s.mix_rate)
	son_hb = AudioStreamPlayer3D.new()
	son_hb.stream = s
	son_hb.pitch_scale = 0.62
	son_hb.unit_size = 8.0
	son_hb.max_distance = 160.0
	son_hb.volume_db = -6.0
	hb.add_child(son_hb)
	son_hb.play()
	son_tir = AudioStreamPlayer3D.new()
	son_tir.stream = load("res://sons/tir.wav")
	son_tir.unit_size = 10.0
	son_tir.max_distance = 250.0
	hb.add_child(son_tir)
	eclair = OmniLight3D.new()
	eclair.light_color = Color(1.0, 0.8, 0.4)
	eclair.omni_range = 7.0
	eclair.light_energy = 0.0
	hb.add_child(eclair)
	eclair.position = Vector3(-0.2, 2.2, 0.9)


func _racket() -> void:
	phase = Phase.RACKET
	_hors_bord()
	var arrivee := bord + mer2 * 20.0 - plage2 * 6.0
	var depart := arrivee + mer2 * 230.0
	_poser(hb, depart, -mer2, 0.4)
	_plan(_sur_sable(-6.0, -1.0) + Vector3(0, 2.4, 0), Vector3(arrivee.x, 1.0, arrivee.y), 0.0)
	cam_suit = hb
	var t0 := Time.get_ticks_msec()
	var t := 0.0
	while t < 9.0:
		if not await _attendre(0.0):
			return
		t = (Time.get_ticks_msec() - t0) / 1000.0
		var u := 1.0 - pow(1.0 - minf(t / 9.0, 1.0), 2.0)
		_poser(hb, depart.lerp(arrivee, u), -mer2, 0.4)
	cam_suit = null
	_plan(_sur_sable(-5.0, -14.0) + Vector3(0, 2.0, 0), Vector3(arrivee.x, 1.2, arrivee.y), 1.5)
	if not await _scene([
		["", "Un hors-bord de la milice entre dans la baie."],
		["MILICIEN", "La taxe du Cobra ! Un tiers de la pêche, chaque pirogue. Le Commandant a faim, ce matin."],
		["VIEUX MENSAH", "La mer a été mauvaise… Je n'ai pas assez, je te jure que je n'ai pas assez."],
	]):
		return
	# un milicien saute dans l'eau, tranche les filets au couteau
	var g: Node3D = hb_gardes[1]
	g.reparent(self)
	g.global_position = _sur_sable(-0.5, -8.6)
	_tourner_vers(g, filet.global_position)
	_jouer(g, "Accroupi")
	_plan(_sur_sable(-5.0, -5.0) + Vector3(0, 1.8, 0), filet.global_position + Vector3(0, 0.4, 0), 1.0)
	if not await _dire("", "Le milicien tranche les filets du vieux Mensah au couteau.", 4.0):
		return
	filet.scale = Vector3(0.5, 1, 1)
	(filet.mesh as QuadMesh).size = Vector2(3.0, 2.0)
	filet.rotation.y = 0.5
	g.reparent(hb)
	g.position = Vector3(-0.2, 0.45, 0.6)
	g.rotation = Vector3.ZERO
	_jouer(g, "Repos")
	# Ama saute dans sa pirogue et part en trombe vers le large avec la caisse du village
	_plan(_sur_sable(-6.0, -12.0) + Vector3(0, 2.2, 0), ama_pir.global_position + Vector3(0, 0.6, 0), 1.2)
	ama.reparent(ama_pir)
	ama.position = Vector3(0, 0.1, -2.0)
	ama.rotation = Vector3.ZERO
	_jouer(ama, "Assis")
	s_a = 0.0
	lat_a = 0.0
	if not await _dire("", "Ama saute dans sa pirogue et part en trombe vers le large, avec la caisse de poisson du village.", 4.5):
		return
	s_h = 0.0
	lat_h = 12.0
	if not await _dire("MILICIEN", "La voleuse ! Rattrape-la !", 2.5):
		return
	_tourner_vers(mensah, jp3())
	_jouer(mensah, "Repos")
	_plan(jp3() + (mensah.global_position - jp3()).cross(Vector3.UP).normalized() * 3.0 + Vector3(0, 1.7, 0), mensah.global_position + Vector3(0, 1.4, 0), 1.0)
	if not await _dire("VIEUX MENSAH", "Ils vont la tuer ! Prends la pirogue de mon fils, elle est à toi !", 4.0):
		return
	_cinematique(false)
	phase = Phase.EMBARQUER
	pir.set_process_unhandled_input(true)
	_objectif("Montez dans la pirogue à moteur (E) et suivez Ama.\nZ : gaz · Maj : plein gaz · Q / D : tourner · relâcher Z : couper les gaz et glisser en silence.")
	_balise(pir.global_position)


# ---------------------------------------------------------------------
# La poursuite
# ---------------------------------------------------------------------
func _partir() -> void:
	phase = Phase.POURSUITE
	pir.verrou = true
	# le hors-bord est parti derrière Ama : Faris doit d'abord le rattraper
	s_a = maxf(s_a, 55.0)
	s_h = maxf(s_h, 32.0)
	s_reprise = 0.0
	touches = 0
	t_loin = 0.0
	_objectif("Suivez Ama le long de la côte. Passez entre les récifs, là où le hors-bord ne passe pas.\nRattrapé trois fois, vous tombez à l'eau.")
	_balise(Vector3(crique.x, 0, crique.y))
	@warning_ignore("missing_await")
	_dire("AMA", "Suis-moi entre les rochers ! Là où ils ne passent pas !", 4.0)


func _course(delta: float, active: bool) -> void:
	var pp := _plat(pir.global_position)
	if active:
		var pr := _projeter(pp)
		s_p = pr[0]
		var lat_p: float = pr[1]
		# Ama reste devant, à une trentaine de mètres
		var gap := s_a - s_p
		var v_a := clampf(7.6 + (30.0 - gap) * 0.25, 2.5, 10.5)
		if _dans_recif(s_a):
			v_a = minf(v_a, 7.0)
		if s_a > longueur - 4.0:
			v_a = 0.0
		s_a = minf(longueur - 2.0, s_a + v_a * delta)
		lat_a = move_toward(lat_a, _axe(s_a), 4.0 * delta)
		_hb_avancer(delta, lat_p)
		_points_de_passage()
		# trop loin au large : Ama crie
		t_loin = t_loin + delta if absf(lat_p) > 75.0 else 0.0
		if t_loin > 4.0:
			t_loin = -6.0
			@warning_ignore("missing_await")
			_dire("AMA", "Reviens près de la côte ! Reste avec moi !", 3.0)
		if s_p > longueur - 26.0 and pp.distance_to(crique) < 24.0:
			@warning_ignore("missing_await")
			_crique()
	else:
		# avant le départ de Faris : Ama attend au large, le hors-bord tourne autour d'elle
		s_a = move_toward(s_a, 55.0, 7.0 * delta)
		lat_a = move_toward(lat_a, 0.0, 3.0 * delta)
		s_h = move_toward(s_h, 32.0, 7.5 * delta)
		lat_h = 10.0 * sin(Time.get_ticks_msec() / 1500.0)
		_tirs(delta)
	if ama_pir:
		var pa := _pt(s_a) + _nor(s_a) * lat_a
		_poser(ama_pir, pa, _tan(s_a), 0.05 * sin(Time.get_ticks_msec() / 400.0))
	if hb and chavire == 0.0 and not hb_dehors:
		var ph := _pt(s_h) + _nor(s_h) * lat_h
		_poser(hb, ph, _tan(s_h), 0.4 + 0.06 * sin(Time.get_ticks_msec() / 300.0))
	if eclair:
		eclair.light_energy = maxf(0.0, eclair.light_energy - delta * 40.0)


func _hb_avancer(delta: float, lat_p: float) -> void:
	if chavire > 0.0:
		return
	var vise_faris := s_p > s_h + 3.0
	var v := V_HB
	if _dans_recif(s_h):
		v = V_HB_RECIF
		var cle := 0 if s_h < recifs[1][0] else 1
		if not racle_annonce.has(cle):
			racle_annonce[cle] = true
			@warning_ignore("missing_await")
			_dire("", "Le hors-bord racle les rochers ! Les miliciens jurent, la coque gronde sur le récif.", 3.5)
	elif vise_faris and s_p - s_h > 80.0:
		v = 12.5                            # il ne lâche pas : il remonte à pleins gaz
	elif vise_faris:
		# plus rapide, mais lourd : il ne gagne que peu à peu, ce qui laisse le temps de l'esquiver
		v = minf(V_HB, maxf(absf(pir.vitesse), 4.0) + clampf((s_p - s_h) * 0.12, 0.5, 3.0))
	if t_recup > 0.0:
		t_recup -= delta
		v = 3.0
	if not vise_faris:
		v = minf(v, maxf(0.0, (s_a - 14.0 - s_h) / maxf(delta, 0.001)))
	if vague_passee and s_h < s_vague:
		v = maxf(v, 9.0)
	s_h += v * delta
	var cible := lat_p if vise_faris else lat_a
	if _dans_recif(s_h):
		cible = clampf(cible, _axe(s_h) - 3.0, _axe(s_h) + 3.0)
	lat_h = move_toward(lat_h, cible, 3.2 * delta)
	_tirs(delta)
	# la vague : le hors-bord, trop lourd, se retourne à moitié et cale
	if vague_lancee and s_h >= s_vague - 2.0:
		chavire = 0.01
		if son_hb:
			son_hb.stop()
		@warning_ignore("missing_await")
		_dire("", "Le hors-bord prend la vague de plein fouet, se retourne à moitié et cale. Les miliciens, trempés, hurlent depuis leur coque.", 5.5)
		return
	# il rattrape Faris
	if vise_faris and s_p - s_h < 5.5 and absf(lat_p - lat_h) < 3.4 and t_recup <= 0.0:
		touches += 1
		t_recup = 3.0
		pir.vitesse *= 0.25
		m4.rouge.color.a = 0.35
		if touches >= 3:
			@warning_ignore("missing_await")
			_chute("Le hors-bord percute la pirogue de plein fouet. Faris passe par-dessus bord.")
		else:
			@warning_ignore("missing_await")
			_dire("", "Le hors-bord heurte la pirogue ! (%d sur 3)" % touches, 2.5)


func _tirs(delta: float) -> void:
	t_tir -= delta
	if t_tir > 0.0 or chavire > 0.0 or son_tir == null:
		return
	t_tir = randf_range(2.5, 4.5)
	son_tir.play()
	eclair.light_energy = 6.0
	if not tirs_annonces and phase == Phase.POURSUITE:
		tirs_annonces = true
		@warning_ignore("missing_await")
		_dire("", "Les miliciens tirent en l'air pour l'effrayer. Personne n'est touché : ils veulent la caisse, pas un mort sur la plage.", 5.0)


func _points_de_passage() -> void:
	for r in recifs:
		if s_p > float(r[1]) + 4.0 and s_reprise < float(r[1]):
			s_reprise = float(r[1]) + 4.0
			touches = 0
			@warning_ignore("missing_await")
			_dire("AMA", "Bien ! Encore ! Ne lâche pas les gaz !", 2.5)
	if not vague_lancee and s_p > s_vague - 75.0:
		vague_lancee = true
		vague.visible = true
		var tw := create_tween()
		tw.tween_property(vague, "position:y", -0.6, 5.0)
		@warning_ignore("missing_await")
		_dire("AMA", "Une vague se lève ! Fonce droit dessus ! Surtout, ne tourne pas !", 4.0)
	if vague_lancee and not vague_passee and s_p > s_vague:
		var ang := absf(angle_difference(pir.cap, atan2(_tan(s_vague).x, _tan(s_vague).y)))
		if ang > 0.9:
			@warning_ignore("missing_await")
			_chute("La vague prend la pirogue de travers. Faris est jeté à l'eau.")
			return
		vague_passee = true
		s_reprise = s_vague + 6.0
		touches = 0
		pir.vitesse *= 0.6
		@warning_ignore("missing_await")
		_dire("", "La pirogue passe la crête dans une gerbe d'écume !", 3.0)


func _chute(texte: String) -> void:
	if en_scene:
		return
	_cinematique(true)
	pir.verrou = false
	pir.descendre()
	_plan(jp3() + Vector3(4, 3, 4), jp3())
	if not await _dire("", texte, 3.0):
		return
	if not await _fondu(true, 0.8):
		return
	# reprise au dernier passage réussi
	var s := s_reprise
	_poser(pir, _pt(s) + _nor(s) * _axe(s), _tan(s))
	pir.global_position.y = -0.22
	pir.cap = atan2(_tan(s).x, _tan(s).y)
	pir.vitesse = 0.0
	joueur.ressusciter(pir.global_position + Vector3(0, 0.5, 0))
	pir.monter()
	pir.verrou = true
	s_p = s
	i_p = 1
	var pr := _projeter(_pt(s))
	s_p = pr[0]
	s_a = s + 30.0
	if not vague_passee:
		vague_lancee = s > s_vague - 75.0 and vague_lancee
		if not vague_lancee:
			vague.visible = false
			vague.position.y = -1.9
	if chavire == 0.0:
		s_h = maxf(0.0, s - 50.0)
		lat_h = 0.0
		t_recup = 2.0
	touches = 0
	_cinematique(false)
	if not await _fondu(false, 0.8):
		return
	@warning_ignore("missing_await")
	_dire("", "Reprise", 1.5)


# ---------------------------------------------------------------------
# La crique
# ---------------------------------------------------------------------
func _crique() -> void:
	phase = Phase.CRIQUE
	_cinematique(true)
	pir.vitesse = 0.0
	pir.set_process(false)
	_poser(ama_pir, crique + _nor(longueur) * 2.6, _tan(longueur))
	_poser(pir, crique - _nor(longueur) * 1.2 - _tan(longueur) * 3.0, _tan(longueur))
	pir.global_position.y = -0.22
	joueur.global_position = pir.global_position + Vector3(0, 0.3, 0)
	var t := _tan(longueur)
	var cible := Vector3(crique.x, 0.9, crique.y)
	# depuis le large, vers les falaises : les deux pirogues côte à côte dans la crique
	_plan(cible + Vector3(mer2.x, 0, mer2.y) * 10.0 - Vector3(t.x, 0, t.y) * 4.0 + Vector3(0, 2.2, 0), cible)
	if not await _scene([
		["", "Les deux pirogues se glissent dans une petite crique, sous les falaises."],
		["AMA", "(Essoufflée, elle rit malgré elle.) Tu rames comme un touriste."],
		["FARIS", "Le touriste vient de te sauver la caisse."],
		["AMA", "… Ton père m'a aidée à chercher mon frère, Yaw. Ils l'ont emmené au camp il y a six mois."],
		["AMA", "Samuel avait vu des bateaux charger la nuit à l'entrepôt du port. Pas du poisson. Des sacs. Et des enfants."],
		["FARIS", "Il faut que je voie cet entrepôt."],
		["AMA", "Tu ne verras rien du tout tout seul. (Elle lui tend la main.) Sur l'eau, c'est moi qui commande."],
		["", "Ama rejoint les Racines. Elle sera votre première alliée."],
	]):
		return
	main.set_meta("ama_racines", true)
	if not await _fondu(true, 1.5):
		return
	if not await _afficher_carton("Le soir même", "Retour à Akwéri : la milice veut se venger", 3.5):
		return
	terminer()
	_ambiance(0)
	m4.lancer(true)
	_entree_en_fondu(1.8)


func terminer() -> void:
	gen += 1
	phase = Phase.TERMINEE
	_effacer_pirogue()
	_effacer_decor()
	hb = null
	ama_pir = null
	vague = null
	rochers.clear()
	if en_scene:
		_cinematique(false)
	voile.color.a = 0.0

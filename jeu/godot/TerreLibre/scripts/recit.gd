## Outils communs aux missions du prologue (1 « Le Retour », 2 « La Veillée », 3 « Le Pêcheur ») :
## sous-titres en bas de l'écran (F pour passer), cinématiques à bandes noires, fondus, choix chronométrés,
## personnages de décor (marche, regard), invites « F : parler ».
## Chaque (re)départ d'une mission change `gen` : une scène en cours s'arrête net (chargement de partie).
class_name Recit
extends Node3D

const COULEUR_NOM := Color(1.0, 0.8, 0.42)

var main: Node
var joueur: Joueur
var m4: Mission4
var vq: VieQuotidienne
var terrain: Terrain
var ville: VillePortNere
var gen := 0
var en_scene := false
var passer := false
var saute := false              # la dernière attente a été écourtée par F
var st_jeton := 0               # le dernier sous-titre affiché (un plus ancien ne l'efface pas)
var decor: Array = []           # nœuds de la mission, effacés à la fin ou au redémarrage
var marcheurs: Array = []       # {n, pts, i, v, boucle, pause, t, anim_arret}
var regards: Array = []         # [noeud, distance] : se tournent vers Faris quand il passe
var invites: Array = []         # {n, texte, action: Callable, rayon}
var etiquette: Label3D
# interface
var calque: CanvasLayer
var bande_h: ColorRect
var bande_b: ColorRect
var cadre_st: PanelContainer
var st_nom: Label
var st_texte: Label
var voile: ColorRect
var carton: Label
var carton_sous: Label
var panneau: PanelContainer
var choix_titre: Label
var choix_boutons: VBoxContainer
var choix_temps: ProgressBar
var choix_rendu := -1
# caméra de cinématique
var cam: Camera3D
var cam_cible := Vector3.ZERO
var cam_suit: Node3D             # si défini, la caméra regarde ce nœud
var cam_ancre: Node3D            # si défini, la caméra se déplace avec ce nœud (le bac en mer)
var cam_local := Vector3.ZERO
var cam_tw: Tween


func preparer_recit(p_main: Node) -> void:
	main = p_main
	joueur = main.joueur
	m4 = main.get_node("Mission4")
	vq = main.get_node("VieQuotidienne")
	terrain = main.terrain
	ville = main.ville
	for a in [["choix1", KEY_1], ["choix2", KEY_2], ["choix3", KEY_3]]:
		if not InputMap.has_action(a[0]):
			InputMap.add_action(a[0])
			var ev := InputEventKey.new()
			ev.physical_keycode = a[1]
			InputMap.action_add_event(a[0], ev)
	_interface_recit()
	etiquette = Label3D.new()
	etiquette.font_size = 40
	etiquette.pixel_size = 0.004
	etiquette.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	etiquette.no_depth_test = true
	etiquette.outline_size = 8
	etiquette.visible = false
	add_child(etiquette)


# ---------------------------------------------------------------------
# Interface : bandes, sous-titres, voile, carton-titre, panneau de choix
# ---------------------------------------------------------------------
func _interface_recit() -> void:
	calque = CanvasLayer.new()
	calque.layer = 9
	add_child(calque)
	bande_h = ColorRect.new()
	bande_h.color = Color(0, 0, 0)
	bande_h.anchor_right = 1.0
	bande_h.offset_bottom = 0.0
	bande_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	calque.add_child(bande_h)
	bande_b = ColorRect.new()
	bande_b.color = Color(0, 0, 0)
	bande_b.anchor_top = 1.0
	bande_b.anchor_right = 1.0
	bande_b.anchor_bottom = 1.0
	bande_b.offset_top = 0.0
	bande_b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	calque.add_child(bande_b)
	voile = ColorRect.new()
	voile.color = Color(0, 0, 0, 0)
	voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	calque.add_child(voile)
	# sous-titres : nom du personnage en couleur, réplique en dessous
	cadre_st = PanelContainer.new()
	cadre_st.anchor_left = 0.5
	cadre_st.anchor_right = 0.5
	cadre_st.anchor_top = 1.0
	cadre_st.anchor_bottom = 1.0
	cadre_st.offset_left = -470
	cadre_st.offset_right = 470
	cadre_st.offset_top = -190
	cadre_st.offset_bottom = -96
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.55)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 8
	sb.content_margin_bottom = 10
	cadre_st.add_theme_stylebox_override("panel", sb)
	cadre_st.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	cadre_st.add_child(col)
	st_nom = Label.new()
	st_nom.add_theme_font_size_override("font_size", 17)
	st_nom.add_theme_color_override("font_color", COULEUR_NOM)
	col.add_child(st_nom)
	st_texte = Label.new()
	st_texte.add_theme_font_size_override("font_size", 21)
	st_texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	st_texte.custom_minimum_size = Vector2(900, 0)
	col.add_child(st_texte)
	cadre_st.visible = false
	calque.add_child(cadre_st)
	# carton-titre (écran noir)
	carton = Label.new()
	carton.set_anchors_preset(Control.PRESET_FULL_RECT)
	carton.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	carton.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	carton.add_theme_font_size_override("font_size", 64)
	carton.add_theme_color_override("font_color", Color(0.93, 0.72, 0.28))
	carton.modulate.a = 0.0
	calque.add_child(carton)
	carton_sous = Label.new()
	carton_sous.set_anchors_preset(Control.PRESET_FULL_RECT)
	carton_sous.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	carton_sous.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	carton_sous.offset_top = 120
	carton_sous.add_theme_font_size_override("font_size", 22)
	carton_sous.add_theme_color_override("font_color", Color(0.85, 0.85, 0.82))
	carton_sous.modulate.a = 0.0
	calque.add_child(carton_sous)
	# panneau de choix
	panneau = PanelContainer.new()
	panneau.set_anchors_preset(Control.PRESET_CENTER)
	panneau.offset_left = -300
	panneau.offset_right = 300
	panneau.offset_top = -40
	panneau.offset_bottom = 160
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panneau.add_child(v)
	choix_titre = Label.new()
	choix_titre.add_theme_font_size_override("font_size", 19)
	choix_titre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	choix_titre.custom_minimum_size = Vector2(560, 0)
	v.add_child(choix_titre)
	choix_boutons = VBoxContainer.new()
	choix_boutons.add_theme_constant_override("separation", 8)
	v.add_child(choix_boutons)
	choix_temps = ProgressBar.new()
	choix_temps.custom_minimum_size = Vector2(0, 8)
	choix_temps.show_percentage = false
	v.add_child(choix_temps)
	panneau.visible = false
	calque.add_child(panneau)


# ---------------------------------------------------------------------
# Attentes et dialogues (interrompus par un redémarrage : renvoient false)
# ---------------------------------------------------------------------
func _attendre(s: float, passable := false) -> bool:
	var g := gen
	var fin := Time.get_ticks_msec() + int(s * 1000.0)
	passer = false
	saute = false
	while true:                                 # au moins une image, même pour une attente nulle
		await get_tree().process_frame
		if g != gen or not is_inside_tree():
			return false
		if passable and passer:
			saute = true
			break
		if Time.get_ticks_msec() >= fin:
			break
	passer = false
	return g == gen


## Une réplique : « NOM » et son texte en sous-titre. Durée selon la longueur ; F pour passer.
func _dire(qui: String, texte: String, duree := -1.0) -> bool:
	st_jeton += 1
	var mon_jeton := st_jeton
	st_nom.text = qui
	st_nom.visible = qui != ""
	st_texte.text = texte
	cadre_st.visible = true
	var d := duree if duree > 0.0 else clampf(2.2 + texte.length() * 0.052, 3.0, 11.0)
	var ok: bool = await _attendre(d, true)
	if st_jeton == mon_jeton:
		cadre_st.visible = false
	return ok


func _scene(lignes: Array) -> bool:
	for l in lignes:
		if not await _dire(str(l[0]), str(l[1]), float(l[2]) if l.size() > 2 else -1.0):
			return false
	return true


## Choix chronométré : renvoie l'indice choisi, `defaut` si le temps est écoulé, -1 si interrompu.
func _choisir(titre: String, options: Array, delai: float, defaut: int) -> int:
	var g := gen
	choix_titre.text = titre
	for c in choix_boutons.get_children():
		c.queue_free()
	choix_rendu = -1
	for i in options.size():
		var b := Button.new()
		b.text = "%d — %s" % [i + 1, options[i]]
		b.custom_minimum_size = Vector2(0, 40)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func() -> void: choix_rendu = i)
		choix_boutons.add_child(b)
	panneau.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var t := 0.0
	choix_temps.max_value = delai
	while choix_rendu < 0 and t < delai:
		await get_tree().process_frame
		if g != gen:
			panneau.visible = false
			return -1
		t += get_process_delta_time()
		choix_temps.value = delai - t
		for k in mini(3, options.size()):
			if Input.is_action_just_pressed("choix%d" % (k + 1)):
				choix_rendu = k
	panneau.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	return choix_rendu if choix_rendu >= 0 else defaut


func _fondu(noir: bool, duree := 1.2) -> bool:
	var g := gen
	var tw := create_tween()
	tw.tween_property(voile, "color:a", 1.0 if noir else 0.0, duree)
	await tw.finished
	return g == gen


## Début d'une mission qui en suit une autre : on sort du noir.
func _entree_en_fondu(duree := 1.6) -> void:
	voile.color.a = 1.0
	var tw := create_tween()
	tw.tween_property(voile, "color:a", 0.0, duree)


func _afficher_carton(titre: String, sous: String, duree: float) -> bool:
	carton.text = titre
	carton_sous.text = sous
	var tw := create_tween().set_parallel(true)
	tw.tween_property(carton, "modulate:a", 1.0, 1.2)
	tw.tween_property(carton_sous, "modulate:a", 1.0, 1.8)
	var ok: bool = await _attendre(duree, true)
	tw.kill()                                   # si l'on passe avant la fin de l'apparition
	var tw2 := create_tween().set_parallel(true)
	tw2.tween_property(carton, "modulate:a", 0.0, 0.8)
	tw2.tween_property(carton_sous, "modulate:a", 0.0, 0.8)
	await tw2.finished
	return ok


# ---------------------------------------------------------------------
# Cinématiques
# ---------------------------------------------------------------------
func _cinematique(oui: bool) -> void:
	en_scene = oui
	var ca: Node = main.get_node_or_null("Carte")
	if ca and ca.get("mini_carte"):
		(ca.get("mini_carte") as CanvasItem).visible = not oui
	if ca and ca.get("colonne"):
		# la colonne lumineuse de la balise n'a rien à faire dans une scène
		(ca.get("colonne") as Node3D).visible = not oui and ca.get("balise") != Vector3.INF
	var tw := create_tween().set_parallel(true)
	tw.tween_property(bande_h, "offset_bottom", 64.0 if oui else 0.0, 0.6)
	tw.tween_property(bande_b, "offset_top", -64.0 if oui else 0.0, 0.6)
	if oui:
		m4.t_annonce = minf(m4.t_annonce, 0.4)     # pas d'aide à l'écran pendant une scène
		joueur.velocity = Vector3.ZERO
		joueur.set_physics_process(false)
		joueur.anim.play("Repos", 0.3)
		if cam == null:
			cam = Camera3D.new()
			cam.far = 4000.0
			cam.fov = 55.0
			add_child(cam)
	else:
		joueur.set_physics_process(true)
		if cam:
			cam.queue_free()
			cam = null
		cam_suit = null
		cam_ancre = null
		joueur.camera.make_current()
		cadre_st.visible = false


## Place la caméra de scène ; un mur ou une maison entre elle et la cible la fait avancer devant l'obstacle.
func _plan(pos: Vector3, cible: Vector3, duree := 0.0) -> void:
	if cam == null:
		return
	cam.make_current()
	if cam_tw:
		cam_tw.kill()
	cam_ancre = null
	var q := PhysicsRayQueryParameters3D.create(cible, pos)
	q.exclude = [joueur.get_rid()]
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if not r.is_empty():
		var touche: Vector3 = r["position"]
		pos = touche + (cible - touche).normalized() * 0.4
	var hs := terrain.hauteur(pos.x, pos.z) + 0.4
	if pos.y < hs:
		pos.y = hs
	if duree <= 0.0:
		cam.global_position = pos
		cam_cible = cible
		cam.look_at(cible)
		return
	cam_tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	cam_tw.tween_property(cam, "global_position", pos, duree)
	cam_tw.tween_property(self, "cam_cible", cible, duree)


func _degage(de: Vector3, vers: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(de, vers)
	q.exclude = [joueur.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Plan de dialogue entre deux personnages : de profil d'un côté ou de l'autre, sinon par-dessus
## l'épaule de l'un ou de l'autre — le premier point de vue que rien ne masque.
func _plan_dialogue(a: Vector3, b: Vector3, recul := 3.6) -> void:
	var milieu := (a + b) * 0.5 + Vector3(0, 1.35, 0)
	var ab := b - a
	ab.y = 0.0
	if ab.length() < 0.1:
		ab = Vector3(0, 0, 1)
	ab = ab.normalized()
	var lat := ab.cross(Vector3.UP).normalized()
	var candidats := [milieu + lat * recul + Vector3(0, 0.3, 0), milieu - lat * recul + Vector3(0, 0.3, 0),
			a - ab * 2.2 + lat * 0.9 + Vector3(0, 1.75, 0), b + ab * 2.2 - lat * 0.9 + Vector3(0, 1.75, 0),
			milieu + lat * recul * 0.55 + Vector3(0, 1.2, 0), milieu - lat * recul * 0.55 + Vector3(0, 1.2, 0)]
	for c in candidats:
		if _degage(milieu, c):
			_plan(c, milieu)
			return
	_plan(milieu + Vector3(0, 6.0, 0) + lat * 1.5, milieu)


## Caméra embarquée : elle suit `ancre` (position exprimée dans le repère de l'ancre).
func _plan_embarque(ancre: Node3D, local: Vector3, cible: Vector3, duree := 0.0) -> void:
	if cam == null:
		return
	cam.make_current()
	if cam_tw:
		cam_tw.kill()
	cam_ancre = ancre
	if duree <= 0.0:
		cam_local = local
		cam_cible = cible
		cam.global_position = ancre.global_transform * local
		cam.look_at(cible)
		return
	cam_tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	cam_tw.tween_property(self, "cam_local", local, duree)
	cam_tw.tween_property(self, "cam_cible", cible, duree)


func _ambiance(i: int) -> void:
	var amb: Ambiances = main.ambiances
	var garde := 0
	while amb.index != i and garde < 8:
		amb.suivante()
		garde += 1


# ---------------------------------------------------------------------
# Décor : boîtes, personnages, marcheurs
# ---------------------------------------------------------------------
func _au_sol(p: Vector3, dy := 0.0) -> Vector3:
	return Vector3(p.x, terrain.hauteur(p.x, p.z) + dy, p.z)


func _boite(taille: Vector3, xf: Transform3D, couleur: Color, parent: Node3D = null, solide := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = taille
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = couleur
	m.roughness = 0.9
	mi.material_override = m
	var par: Node3D = parent if parent else self
	par.add_child(mi)
	mi.global_transform = xf
	if parent == null:
		decor.append(mi)
	if solide:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = taille
		cs.shape = bs
		sb.add_child(cs)
		mi.add_child(sb)
	return mi


func _perso(modele: String, anim: String, pos: Vector3, angle: float) -> Node3D:
	var p := vq._perso(modele, anim, pos, angle)
	p.reparent(self)
	decor.append(p)
	return p


func _jouer(p: Node3D, anim: String, fondu := 0.3) -> void:
	var ap: AnimationPlayer = p.find_child("AnimationPlayer", true, false)
	if ap and ap.current_animation != anim:
		ap.get_animation(anim).loop_mode = Animation.LOOP_LINEAR
		ap.play(anim, fondu)


func _tourner_vers(p: Node3D, cible: Vector3) -> void:
	p.rotation.y = atan2(cible.x - p.global_position.x, cible.z - p.global_position.z)


## Foulard vert du Cobra, noué au cou (accroché à l'os du cou : il suit les gestes).
func _foulard(p: Node3D) -> void:
	var sq: Skeleton3D = p.find_child("Skeleton3D", true, false)
	if sq == null:
		return
	var att := BoneAttachment3D.new()
	att.bone_name = "mixamorig_Neck"
	sq.add_child(att)
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.06
	tm.outer_radius = 0.1
	mi.mesh = tm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.12, 0.42, 0.18)
	mi.material_override = m
	att.add_child(mi)
	mi.position = Vector3(0, 0.02, 0.01)


## Coiffe posée sur la tête (béret, calotte, chapeau de paille), accrochée à l'os de la tête.
func _coiffe(p: Node3D, couleur: Color, rayon: float, hauteur: float, rayon_haut := -1.0) -> void:
	var sq: Skeleton3D = p.find_child("Skeleton3D", true, false)
	if sq == null:
		return
	var att := BoneAttachment3D.new()
	att.bone_name = "mixamorig_Head"
	sq.add_child(att)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = rayon
	cm.top_radius = rayon if rayon_haut < 0.0 else rayon_haut
	cm.height = hauteur
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = couleur
	m.roughness = 0.85
	mi.material_override = m
	att.add_child(mi)
	mi.position = Vector3(0, 0.17, 0.0)


func _milicien_decor(pos: Vector3, angle: float, modele := "homme2") -> Node3D:
	var p := _perso(modele, "Repos", pos, angle)
	vq._camoufler(p)
	_foulard(p)
	return p


## Pick-up de la milice (décor) : cabine, benne, roues, bande verte du Cobra.
func _pickup(xf: Transform3D, parent: Node3D = null) -> Node3D:
	var n := Node3D.new()
	var par: Node3D = parent if parent else self
	par.add_child(n)
	n.global_transform = xf
	if parent == null:
		decor.append(n)
	var blanc := Color(0.86, 0.85, 0.8)
	_boite(Vector3(1.9, 0.7, 5.0), xf.translated_local(Vector3(0, 0.75, 0)), blanc, n, true)
	_boite(Vector3(1.8, 0.8, 1.9), xf.translated_local(Vector3(0, 1.45, 0.9)), blanc, n)
	_boite(Vector3(1.6, 0.5, 0.05), xf.translated_local(Vector3(0, 1.55, 1.86)), Color(0.15, 0.2, 0.25), n)
	_boite(Vector3(1.92, 0.12, 5.02), xf.translated_local(Vector3(0, 0.95, 0)), Color(0.12, 0.42, 0.18), n)
	for sx in [-1.0, 1.0]:
		for sz in [-1.6, 1.6]:
			var r := MeshInstance3D.new()
			var cy := CylinderMesh.new()
			cy.top_radius = 0.38
			cy.bottom_radius = 0.38
			cy.height = 0.3
			r.mesh = cy
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.08, 0.08, 0.08)
			r.material_override = m
			n.add_child(r)
			r.global_transform = Transform3D(xf.basis * Basis(Vector3(0, 0, 1), PI * 0.5), xf * Vector3(sx * 0.95, 0.38, sz))
	return n


## Marcheur : suit des points (aller-retour si boucle), s'arrête `pause` s à chaque bout.
func _marcheur(n: Node3D, pts: Array, v: float, boucle := true, pause := 0.0, anim := "Marche") -> Dictionary:
	var m := {"n": n, "pts": pts, "i": 0, "sens": 1, "v": v, "boucle": boucle, "pause": pause, "t": 0.0, "anim": anim, "fini": false}
	marcheurs.append(m)
	_jouer(n, anim)
	return m


func _marcher(delta: float) -> void:
	for m in marcheurs:
		if m["fini"]:
			continue
		var n: Node3D = m["n"]
		if not is_instance_valid(n):
			m["fini"] = true
			continue
		if m["t"] > 0.0:
			m["t"] -= delta
			if m["t"] <= 0.0:
				_jouer(n, m["anim"])
			continue
		var pts: Array = m["pts"]
		var cible: Vector3 = pts[m["i"]]
		var v := cible - n.global_position
		v.y = 0.0
		var pas: float = m["v"] * delta
		if v.length() <= pas + 0.05:
			n.global_position = _au_sol(cible)
			var suivant: int = m["i"] + m["sens"]
			if suivant >= pts.size() or suivant < 0:
				if not m["boucle"]:
					m["fini"] = true
					_jouer(n, "Repos")
					continue
				m["sens"] = -m["sens"]
				suivant = m["i"] + m["sens"]
				if m["pause"] > 0.0:
					m["t"] = m["pause"]
					_jouer(n, "Repos")
			m["i"] = clampi(suivant, 0, pts.size() - 1)
			continue
		var d := v.normalized()
		n.global_position = _au_sol(n.global_position + d * pas)
		n.rotation.y = lerp_angle(n.rotation.y, atan2(d.x, d.z), minf(1.0, delta * 8.0))


func _inviter(n: Node3D, texte: String, action: Callable, rayon := 3.0) -> Dictionary:
	var e := {"n": n, "texte": texte, "action": action, "rayon": rayon}
	invites.append(e)
	return e


func _retirer_invite(e: Dictionary) -> void:
	invites.erase(e)


func _invite_proche() -> Dictionary:
	var meilleur := {}
	var dmin := INF
	for e in invites:
		var n: Node3D = e["n"]
		if not is_instance_valid(n):
			continue
		var d := n.global_position.distance_to(joueur.global_position)
		if d < float(e["rayon"]) and d < dmin:
			dmin = d
			meilleur = e
	return meilleur


func _process_recit(delta: float) -> void:
	_marcher(delta)
	for r in regards:
		var n: Node3D = r[0]
		if is_instance_valid(n) and n.global_position.distance_to(joueur.global_position) < float(r[1]):
			var a := atan2(joueur.global_position.x - n.global_position.x, joueur.global_position.z - n.global_position.z)
			n.rotation.y = lerp_angle(n.rotation.y, a, minf(1.0, delta * 3.0))
	var e := {} if en_scene else _invite_proche()
	if e.is_empty():
		etiquette.visible = false
	else:
		etiquette.text = "F : " + str(e["texte"])
		etiquette.global_position = (e["n"] as Node3D).global_position + Vector3(0, 2.15, 0)
		etiquette.visible = true
	if cam and cam_ancre and is_instance_valid(cam_ancre):
		cam.global_position = cam_ancre.global_transform * cam_local
	if cam and cam_suit and is_instance_valid(cam_suit):
		cam_cible = cam_cible.lerp(cam_suit.global_position + Vector3(0, 1.4, 0), 1.0 - exp(-4.0 * delta))
	if cam and cam.global_position.distance_to(cam_cible) > 0.1:
		cam.look_at(cam_cible)


## F : passer une réplique pendant une scène, sinon parler / ramasser.
func interagir() -> void:
	if en_scene:
		passer = true
		return
	var e := _invite_proche()
	if not e.is_empty():
		(e["action"] as Callable).call()


func _effacer_decor() -> void:
	for n in decor:
		if is_instance_valid(n):
			(n as Node).queue_free()
	decor.clear()
	marcheurs.clear()
	regards.clear()
	invites.clear()
	etiquette.visible = false


# appelés par Faris et les PNJ : rien à faire dans le prologue (pas de combat)
func blessure() -> void:
	pass


func bruit_de_tir(_p: Vector3, _joueur_tire := false) -> void:
	pass


func choisir_couvert(n: Node3D) -> Vector3:
	return n.global_position


func _objectif(t: String) -> void:
	m4._objectif(t)


func _balise(p: Vector3) -> void:
	var ca: Node = main.get_node_or_null("Carte")
	if ca:
		ca.poser_balise(p)


func _plat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)

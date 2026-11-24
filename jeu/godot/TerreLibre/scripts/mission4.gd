## Mission 4 « Première Étincelle » (jeu/missions/04-PREMIERE-ETINCELLE.md), version jouable.
## Étapes : prise non létale du milicien isolé (Faris récupère son fusil) → vague 1 sur la plage →
## vague 2 (renforts venus du haut du village) → vague 3 (Dossou derrière les pirogues) →
## choix pour Dossou → Akwéri libéré (drapeau des Racines, « Zaladou ! », jauge de confiance).
class_name Mission4
extends Node

enum Phase { ARME, VAGUE1, VAGUE2, VAGUE3, CHOIX, LIBERE }

var village: VillageAkweri
var joueur: Joueur
var phase := Phase.ARME
var pnjs: Array = []         # tous les PNJ
var vagues := {}             # numéro -> liste de miliciens
var civils: Array = []
var isole: Pnj
var dossou: Pnj
var confiance := 50
var tues := 0
var epargnes := 0
var t_suivante := -1.0
var t_reprise := -1.0
var choix_fait := false

# interface
var objectif: Label
var annonce: Label
var t_annonce := 0.0
var infos: Label
var munitions: Label
var reticule: Label
var vie: ColorRect
var vie_fond: ColorRect
var rouge: ColorRect
var panneau_choix: PanelContainer
var jauge: ProgressBar
var bloc_jauge: VBoxContainer


func demarrer(p_village: VillageAkweri, p_joueur: Joueur) -> void:
	village = p_village
	joueur = p_joueur
	joueur.mission = self
	joueur.a_tire.connect(func(p): bruit_de_tir(p, true))
	joueur.tombe.connect(_joueur_tombe)
	_actions()
	_interface()
	_naviguer()
	_placer_civils()
	# le milicien isolé patrouille entre deux fumoirs
	var a := village._monde3(-12, -9)
	var b := village._monde3(-12, 22)
	isole = _milicien("milicien", a, Color(0.42, 0.45, 0.3))
	isole.points_patrouille = [a, b]
	vagues[1] = [isole]
	for p in village.reperes["vague1"]:
		var m := _milicien("milicien", p, Color(0.42, 0.45, 0.3))
		m._regarder(village._monde3(5, 0), 1.0)
		vagues[1].append(m)
	_objectif("Approchez sans être vu le milicien isolé près des fumoirs (C : s'accroupir), puis F dans son dos pour le maîtriser.")
	_annoncer("Akwéri — la milice brûle les pirogues", 5.0)


func _actions() -> void:
	var touches := {"accroupir": KEY_C, "recharger": KEY_R, "interagir": KEY_F, "choix1": KEY_1, "choix2": KEY_2}
	for a in touches:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
			var ev := InputEventKey.new()
			ev.physical_keycode = touches[a]
			InputMap.action_add_event(a, ev)
	for a in [["viser", MOUSE_BUTTON_RIGHT], ["tirer", MOUSE_BUTTON_LEFT]]:
		if not InputMap.has_action(a[0]):
			InputMap.add_action(a[0])
			var ev := InputEventMouseButton.new()
			ev.button_index = a[1]
			InputMap.action_add_event(a[0], ev)


# ---------- navigation : maillage calculé au lancement autour du village ----------
func _naviguer() -> void:
	var nm := NavigationMesh.new()
	nm.cell_size = 0.3
	nm.cell_height = 0.2
	nm.agent_radius = 0.6
	nm.agent_height = 1.8
	nm.agent_max_climb = 0.4
	nm.agent_max_slope = 38.0
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	var c := village._monde3(-25, 0)
	nm.filter_baking_aabb = AABB(c - Vector3(130, 40, 130), Vector3(260, 120, 260))
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, source, get_parent())
	NavigationServer3D.bake_from_source_geometry_data(nm, source)
	NavigationServer3D.map_set_cell_size(get_viewport().world_3d.navigation_map, 0.3)
	NavigationServer3D.map_set_cell_height(get_viewport().world_3d.navigation_map, 0.2)
	var region := NavigationRegion3D.new()
	region.navigation_mesh = nm
	add_child(region)


# ---------- personnages ----------
func _pnj(role: String, p: Vector3, teinte: Color, texture := "", modele := "faris") -> Pnj:
	var n := Pnj.new()
	add_child(n)
	n.global_position = p + Vector3(0, 0.2, 0)
	n.preparer(role, self, joueur, teinte, texture, modele)
	n.refuges = village.reperes["refuges"]
	pnjs.append(n)
	n.neutralise.connect(_neutralise)
	n.rendu.connect(_rendu)
	n.alerte.connect(_alerte.bind(n))
	return n


var _n_miliciens := 0
func _milicien(role: String, p: Vector3, teinte: Color) -> Pnj:
	_n_miliciens += 1
	var modele := "villageois" if role == "dossou" or _n_miliciens % 2 == 0 else "faris"
	return _pnj(role, p, teinte, "res://data/textures/camouflage.jpg", modele)


func _placer_civils() -> void:
	# habitants d'Akwéri : femmes, anciens, pêcheurs ; teintes légères pour varier les tenues
	var modeles := ["femme", "villageois", "ancien", "femme_agee", "femme", "villageois"]
	var teintes := [Color(1, 1, 1), Color(1, 0.85, 0.8), Color(0.85, 1, 0.9), Color(1, 1, 0.85), Color(0.85, 0.9, 1)]
	var i := 0
	for p in village.reperes["civils"]:
		var c := _pnj("civil", p, teintes[(i / 6) % teintes.size() + (i % 2)], "", modeles[i % modeles.size()])
		c._regarder(village._monde3(20, 0), 1.0)
		civils.append(c)
		i += 1


# ---------- événements ----------
func bruit_de_tir(p: Vector3, joueur_tire := false) -> void:
	for n in pnjs:
		n.entendre(p, 70.0 if joueur_tire else 45.0)
	if joueur_tire and phase == Phase.VAGUE1:
		for m in vagues[1]:
			m.entendre(p, 200.0)


func _alerte(_p: Vector3, qui: Pnj) -> void:
	for num in vagues:
		if qui in vagues[num]:
			for m in vagues[num]:
				if m.est_actif():
					m._passer_combat()
	if not joueur.a_une_arme:
		_annoncer("Repéré ! Sans arme, fuyez et réessayez discrètement.", 4.0)


func _rendu(n: Pnj) -> void:
	if n == dossou:
		_annoncer("Dossou est blessé et lâche son arme.", 3.0)
	else:
		_annoncer("Un milicien se rend : F pour le ligoter (épargné).", 3.0)
	_verifier_vague()


func _neutralise(n: Pnj, comment: String) -> void:
	if comment == "ligote":
		epargnes += 1
	else:
		tues += 1
		if comment == "mort_rendu":
			confiance -= 5
			_annoncer("Il s'était rendu… Le village l'a vu.", 3.0)
	if n == isole and phase == Phase.ARME:
		joueur.donner_arme()
		phase = Phase.VAGUE1
		_annoncer("Faris récupère le fusil. « J'ai fait mon service. Je pensais ne plus jamais en toucher une. »", 6.0)
		_objectif("Libérez la plage : 4 miliciens. Clic droit : viser · clic gauche : tirer · R : recharger · C : s'accroupir. Ne touchez pas les villageois.")
	if n == dossou and comment != "ligote" and phase == Phase.VAGUE3:
		pass
	_verifier_vague()


func _verifier_vague() -> void:
	var num := -1
	match phase:
		Phase.VAGUE1: num = 1
		Phase.VAGUE2: num = 2
		Phase.VAGUE3: num = 3
	if num < 0 or not vagues.has(num):
		return
	for m in vagues[num]:
		if m.est_actif():
			return
	if num == 3:
		if dossou.etat == Pnj.Etat.RENDU:
			_proposer_choix()
		else:
			_liberer()
	else:
		t_suivante = 4.0


func _lancer_vague(num: int) -> void:
	vagues[num] = []
	if num == 2:
		phase = Phase.VAGUE2
		for p in village.reperes["vague2"]:
			var m := _milicien("milicien", p, Color(0.42, 0.45, 0.3))
			m._passer_combat()
			vagues[2].append(m)
		_annoncer("Renforts du Cobra en haut du village !", 4.0)
		_objectif("Vague 2 : contournez par les ruelles entre les cases et neutralisez les renforts.")
	elif num == 3:
		phase = Phase.VAGUE3
		var pts: Array = village.reperes["vague3"]
		dossou = _milicien("dossou", pts[0], Color(0.3, 0.3, 0.28))
		dossou._passer_combat()
		vagues[3].append(dossou)
		for k in range(1, pts.size()):
			var m := _milicien("milicien", pts[k], Color(0.42, 0.45, 0.3))
			m._passer_combat()
			vagues[3].append(m)
		_annoncer("Le lieutenant Dossou s'est retranché derrière les pirogues.", 4.0)
		_objectif("Vague 3 : avancez d'abri en abri jusqu'à Dossou. Le désarmer plutôt que le tuer compte pour la fin « Justice ».")


func _proposer_choix() -> void:
	phase = Phase.CHOIX
	_objectif("Dossou, blessé, est à votre merci. Faris n'abat pas un homme désarmé.")
	panneau_choix.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _choisir(prisonnier: bool) -> void:
	if choix_fait:
		return
	choix_fait = true
	panneau_choix.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if prisonnier:
		dossou.ligoter()
		_annoncer("Dossou est fait prisonnier : il sera enfermé dans la cave de l'église.", 4.0)
	else:
		epargnes += 1
		confiance -= 3
		dossou.etat = Pnj.Etat.FUITE
		dossou.anim.play("Marche")
		dossou._aller(village._monde3(-110, 40))
		_annoncer("Dossou s'enfuit en boitant. Certains trouvent Faris trop clément.", 4.0)
	await get_tree().create_timer(3.0).timeout
	_liberer()


func _liberer() -> void:
	phase = Phase.LIBERE
	village.liberer()
	confiance = clampi(confiance + 10, 0, 100)
	for c in civils:
		c.etat = Pnj.Etat.CALME
		c.anim.play("Repos", 0.5)
	_annoncer("AKWÉRI LIBÉRÉ\n« Zaladou ! Zaladou ! »", 8.0)
	_objectif("Prochain objectif : récupérer les semences de la coopérative à l'entrepôt du port (mission 5).")
	bloc_jauge.visible = true


func _joueur_tombe() -> void:
	_annoncer("Faris est tombé…", 3.0)
	t_reprise = 3.5


func _reprendre() -> void:
	# la vague en cours recommence ; les ennemis déjà neutralisés le restent
	var num := 1
	match phase:
		Phase.VAGUE2: num = 2
		Phase.VAGUE3: num = 3
	if vagues.has(num):
		for m in vagues[num]:
			if m.est_actif():
				m.etat = Pnj.Etat.CALME
				m.soupcon = 0.0
				m.pv = maxf(m.pv, 60.0)
	joueur.ressusciter(village.reperes["refuges"][2] + Vector3(0, 0.5, 0))
	_annoncer("Reprise", 1.5)


## F : prise non létale dans le dos d'un milicien, ou ligoter un milicien qui s'est rendu.
func interagir() -> void:
	var meilleur: Pnj = null
	var dmin := 2.0
	for n in pnjs:
		if n.role == "civil":
			continue
		var d: float = n.global_position.distance_to(joueur.global_position)
		if d >= dmin:
			continue
		if n.etat == Pnj.Etat.RENDU or (n.est_actif() and n.dos_au_joueur()):
			meilleur = n
			dmin = d
	if meilleur:
		meilleur.ligoter()
		if meilleur != isole:
			_annoncer("Milicien ligoté.", 2.0)


func blessure() -> void:
	rouge.color.a = 0.35


## Point de couvert pour un milicien : derrière un obstacle, par rapport au joueur.
func choisir_couvert(n: Pnj) -> Vector3:
	var best := n.global_position
	var score_min := INF
	for c in village.couverts:
		var pos: Vector3 = c[0]
		var r: float = c[1]
		var oppose := pos - joueur.global_position
		oppose.y = 0
		if oppose.length() < 6.0:
			continue
		var p := pos + oppose.normalized() * (r + 0.9)
		var score := p.distance_to(n.global_position) + randf_range(0, 6)
		if p.distance_to(n.global_position) > 30.0:
			continue
		if score < score_min:
			score_min = score
			best = p
	return best


# ---------- interface ----------
func _label(taille: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	return l


func _interface() -> void:
	var calque := CanvasLayer.new()
	add_child(calque)
	rouge = ColorRect.new()
	rouge.color = Color(0.6, 0, 0, 0)
	rouge.set_anchors_preset(Control.PRESET_FULL_RECT)
	rouge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	calque.add_child(rouge)
	objectif = _label(17)
	objectif.position = Vector2(20, 52)
	objectif.custom_minimum_size = Vector2(620, 0)
	objectif.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objectif.add_theme_color_override("font_color", Color(1, 0.86, 0.55))
	calque.add_child(objectif)
	annonce = _label(30)
	annonce.set_anchors_preset(Control.PRESET_CENTER_TOP)
	annonce.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	annonce.position = Vector2(-450, 120)
	annonce.custom_minimum_size = Vector2(900, 0)
	annonce.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	calque.add_child(annonce)
	reticule = _label(28)
	reticule.set_anchors_preset(Control.PRESET_CENTER)
	reticule.position = Vector2(-9, -22)
	calque.add_child(reticule)
	infos = _label(16)
	infos.anchor_left = 1.0
	infos.anchor_right = 1.0
	infos.position = Vector2(-300, 16)
	calque.add_child(infos)
	munitions = _label(26)
	munitions.anchor_left = 1.0
	munitions.anchor_right = 1.0
	munitions.anchor_top = 1.0
	munitions.anchor_bottom = 1.0
	munitions.position = Vector2(-170, -84)
	calque.add_child(munitions)
	vie_fond = ColorRect.new()
	vie_fond.color = Color(0, 0, 0, 0.5)
	vie_fond.anchor_top = 1.0
	vie_fond.anchor_bottom = 1.0
	vie_fond.position = Vector2(20, -66)
	vie_fond.size = Vector2(220, 12)
	calque.add_child(vie_fond)
	vie = ColorRect.new()
	vie.color = Color(0.85, 0.2, 0.15)
	vie.size = Vector2(220, 12)
	vie_fond.add_child(vie)
	# jauge de confiance (apparaît à la libération)
	bloc_jauge = VBoxContainer.new()
	bloc_jauge.anchor_left = 1.0
	bloc_jauge.anchor_right = 1.0
	bloc_jauge.position = Vector2(-300, 70)
	bloc_jauge.custom_minimum_size = Vector2(270, 0)
	bloc_jauge.visible = false
	var tj := _label(16)
	tj.text = "Confiance de l'île"
	bloc_jauge.add_child(tj)
	jauge = ProgressBar.new()
	jauge.custom_minimum_size = Vector2(270, 18)
	jauge.show_percentage = true
	bloc_jauge.add_child(jauge)
	calque.add_child(bloc_jauge)
	# choix pour Dossou
	panneau_choix = PanelContainer.new()
	panneau_choix.set_anchors_preset(Control.PRESET_CENTER)
	panneau_choix.position = Vector2(-260, -90)
	panneau_choix.custom_minimum_size = Vector2(520, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	var titre := _label(20)
	titre.text = "Dossou : « Vas-y. Le Commandant m'aurait tué de toute façon. »\nQue fait Faris ?"
	titre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(titre)
	for c in [["1 — Le laisser partir", false], ["2 — Le faire prisonnier", true]]:
		var b := Button.new()
		b.text = c[0]
		b.custom_minimum_size = Vector2(0, 44)
		b.pressed.connect(_choisir.bind(c[1]))
		v.add_child(b)
	panneau_choix.add_child(v)
	panneau_choix.visible = false
	calque.add_child(panneau_choix)


func _objectif(t: String) -> void:
	objectif.text = "▶ " + t


func _annoncer(t: String, duree: float) -> void:
	annonce.text = t
	t_annonce = duree


func _process(delta: float) -> void:
	if t_annonce > 0.0:
		t_annonce -= delta
		annonce.modulate.a = clampf(t_annonce, 0.0, 1.0)
	rouge.color.a = maxf(0.0, rouge.color.a - delta * 0.8)
	if t_suivante > 0.0:
		t_suivante -= delta
		if t_suivante <= 0.0:
			_lancer_vague(2 if phase == Phase.VAGUE1 else 3)
	if t_reprise > 0.0:
		t_reprise -= delta
		if t_reprise <= 0.0:
			_reprendre()
	if phase == Phase.CHOIX:
		if Input.is_action_just_pressed("choix1"):
			_choisir(false)
		elif Input.is_action_just_pressed("choix2"):
			_choisir(true)
	vie.size.x = 220.0 * joueur.pv / 100.0
	if joueur.a_une_arme:
		munitions.text = ("%d / %d" % [joueur.munitions, joueur.reserve]) + ("  rechargement…" if joueur.t_recharge > 0.0 else "")
		reticule.text = "✕" if joueur.cible_civile else "+"
		reticule.add_theme_color_override("font_color", Color(1, 1, 1) if not joueur.cible_civile else Color(1, 0.4, 0.3))
	else:
		munitions.text = ""
		reticule.text = ""
	infos.text = "Épargnés : %d   Tués : %d" % [epargnes, tues]
	jauge.value = confiance

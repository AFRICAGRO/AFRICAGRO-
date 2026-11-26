## Mission 7 — « La Voix de l'Île » (voir jeu/missions/07-LA-VOIX-DE-L-ILE.md).
## Après Bomé : monter au sommet du mont Talanké, prendre l'antenne-relais et créer Radio Racines.
## - Le lac de cratère dans la brume de l'aube, son sanctuaire de pierres (offrande, F) et le rocher
##   du point de vue (toute l'île apparaît).
## - La face nord : escalade (Espace contre la paroi claire, ZQSD pour grimper, jauge d'endurance,
##   corniches où l'on reprend son souffle ; lâcher prise = retour à la dernière corniche, jamais la mort).
## - Le poste du sommet : 5 gardes, l'antenne (une balle perdue dessus = mission manquée, on reprend),
##   et Joël, l'opérateur radio de 20 ans, sans arme.
## - Le premier message de Radio Racines : l'espoir, la vérité ou le défi. Puis le zala-beat dans tout le port.
class_name Mission7
extends Node3D

enum Phase { INDISPONIBLE, DISPONIBLE, LAC, FALAISE, SOMMET, MESSAGE, TERMINEE }
const ENDURANCE := 100.0

var phase := Phase.INDISPONIBLE
var main: Node
var joueur: Joueur
var m4: Mission4
var terrain: Terrain
var plan: Dictionary
var lac := Vector3.ZERO
var niveau_lac := 0.0
var sanctuaire := Vector3.ZERO
var offrande := false
var point_vue := Vector3.ZERO
var vue_faite := false
var sommet := Vector3.ZERO
var paroi_base := Vector3.ZERO
var paroi_normale := Vector3.ZERO      # vers l'extérieur (le grimpeur fait face à -normale)
var paroi_haut := 0.0
var corniches: Array = []              # hauteurs (m) des corniches
var grimpe := false
var endurance := ENDURANCE
var reprise := Vector3.ZERO
var pos_paroi := Vector2.ZERO          # (latéral, hauteur) sur la paroi
var gardes: Array = []
var joel: Node3D
var antenne: StaticBody3D
var jauge: ProgressBar
var choix_ui: Control
var cam_vue: Camera3D
var t_vue := 0.0
var emetteurs: Array = []


## Avant la construction du terrain : la cuvette du lac de cratère et le replat du sommet.
static func preparer_plan(lieu_lac: Vector2, lieu_mont: Vector2) -> Dictionary:
	var d := Terrain.lire_donnees()
	var h := func(x: float, z: float) -> float: return Terrain.hauteur_brute(d, x, z)
	# sommet : le point le plus haut à moins de 400 m du repère
	var s := lieu_mont
	var hs := -INF
	for i in range(-40, 41):
		for j in range(-40, 41):
			var q := lieu_mont + Vector2(i, j) * 10.0
			var hq: float = h.call(q.x, q.y)
			if hq > hs:
				hs = hq
				s = q
	# lac : l'endroit le plus « en cuvette » (anneau le plus régulier et le plus haut) près du repère
	var best := lieu_lac
	var score := INF
	for i in range(-12, 13):
		for j in range(-12, 13):
			var q := lieu_lac + Vector2(i, j) * 20.0
			var anneau: Array = []
			for k in 16:
				var a := TAU * k / 16.0
				anneau.append(h.call(q.x + cos(a) * 52.0, q.y + sin(a) * 52.0))
			var mn: float = anneau.min()
			var mx: float = anneau.max()
			var sc: float = (mx - mn) - 0.15 * mn
			if sc < score and mn > 20.0:
				score = sc
				best = q
	var bord := INF
	for k in 24:
		var a := TAU * k / 24.0
		bord = minf(bord, h.call(best.x + cos(a) * 50.0, best.y + sin(a) * 50.0))
	var niveau := bord - 1.6
	return {
		"lac": best, "niveau": niveau, "sommet": s, "h_sommet": hs,
		"plateformes": [
			{"centre": best, "rayon": 30.0, "h": niveau - 4.5},
			{"centre": s, "rayon": 17.0, "h": hs - 1.0},
		],
	}


func construire(p_main: Node, p_plan: Dictionary, veg: Vegetation = null) -> void:
	main = p_main
	plan = p_plan
	joueur = main.joueur
	m4 = main.get_node("Mission4")
	terrain = main.terrain
	var l: Vector2 = plan["lac"]
	niveau_lac = plan["niveau"]
	lac = Vector3(l.x, niveau_lac, l.y)
	var s: Vector2 = plan["sommet"]
	sommet = Vector3(s.x, terrain.hauteur(s.x, s.y), s.y)
	_lac()
	_sanctuaire_et_vue()
	_paroi()
	_poste()
	_interface()
	if veg:
		# rive du lac, pied et haut de la paroi, replat du sommet : dégagés des arbres
		var zones := [[Vector2(lac.x, lac.z), 62.0], [Vector2(paroi_base.x, paroi_base.z), 16.0],
				[Vector2(sommet.x, sommet.z), 26.0]]
		veg.degager(func(q: Vector2) -> bool:
			for z in zones:
				if q.distance_to(z[0]) < z[1]:
					return true
			return false)
	joueur.impact.connect(_impact)
	joueur.a_tire.connect(func(p: Vector3) -> void:
		if phase == Phase.SOMMET:
			for g in gardes:
				(g as Pnj).entendre(p, 80.0))


# ---------------------------------------------------------------------
# Lieux
# ---------------------------------------------------------------------
func _lac() -> void:
	var eau := MeshInstance3D.new()
	var disque := CylinderMesh.new()
	disque.top_radius = 46.0
	disque.bottom_radius = 46.0
	disque.height = 0.05
	disque.radial_segments = 48
	eau.mesh = disque
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/riviere.gdshader")
	eau.material_override = m
	add_child(eau)
	eau.global_position = lac
	# brume de l'aube posée sur l'eau
	var brume := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(14, 6)
	var mb := StandardMaterial3D.new()
	mb.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mb.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mb.albedo_texture = load("res://data/textures/fumee.png")
	mb.vertex_color_use_as_albedo = true
	mb.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = mb
	brume.mesh = q
	brume.amount = 40
	brume.lifetime = 14.0
	brume.preprocess = 14.0
	brume.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	brume.emission_box_extents = Vector3(40, 0.5, 40)
	brume.direction = Vector3(1, 0.05, 0.3)
	brume.spread = 40.0
	brume.initial_velocity_min = 0.2
	brume.initial_velocity_max = 0.6
	brume.gravity = Vector3.ZERO
	var g := Gradient.new()
	g.set_color(0, Color(0.92, 0.94, 0.96, 0.0))
	g.add_point(0.4, Color(0.92, 0.94, 0.96, 0.32))
	g.set_color(2, Color(0.92, 0.94, 0.96, 0.0))
	brume.color_ramp = g
	brume.name = "Brume"
	add_child(brume)
	brume.global_position = lac + Vector3(0, 1.5, 0)


func _pierre(p: Vector3, r: float, h: float, teinte: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = r * 0.7
	cy.bottom_radius = r
	cy.height = h
	cy.radial_segments = 7
	cy.rings = 1
	mi.mesh = cy
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://data/textures/roche_diff.jpg")
	m.normal_enabled = true
	m.normal_texture = load("res://data/textures/roche_nor.jpg")
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * 0.5
	m.albedo_color = teinte
	mi.material_override = m
	add_child(mi)
	mi.global_position = p + Vector3(0, h * 0.5 - 0.15, 0)
	mi.rotation = Vector3(randf_range(-0.12, 0.12), randf() * TAU, randf_range(-0.12, 0.12))
	return mi


func _sanctuaire_et_vue() -> void:
	# sanctuaire : cercle de pierres dressées au bord de l'eau, une pierre plate au centre
	# au bord de l'eau, sur la rive (pas dans le lac)
	var c := Vector2(lac.x, lac.z) + Vector2(56, 0)
	for k in 24:
		var a := TAU * k / 24.0
		var q := Vector2(lac.x, lac.z) + Vector2(cos(a), sin(a)) * 54.0
		var hq := terrain.hauteur(q.x, q.y)
		if hq > niveau_lac + 0.6 and hq < niveau_lac + 4.0:
			c = q
			break
	for k in 9:
		var a := TAU * k / 9.0
		var q := c + Vector2(cos(a), sin(a)) * 3.2
		_pierre(Vector3(q.x, terrain.hauteur(q.x, q.y), q.y), 0.35, randf_range(1.1, 1.7), Color(0.75, 0.72, 0.68))
	sanctuaire = Vector3(c.x, terrain.hauteur(c.x, c.y), c.y)
	_pierre(sanctuaire, 0.8, 0.5, Color(0.6, 0.58, 0.55))
	# point de vue : le plus haut du bord du cratère
	var best := Vector2(lac.x, lac.z)
	var hb := -INF
	for k in 24:
		var a := TAU * k / 24.0
		var q := Vector2(lac.x, lac.z) + Vector2(cos(a), sin(a)) * 64.0
		var hq := terrain.hauteur(q.x, q.y)
		if hq > hb:
			hb = hq
			best = q
	point_vue = Vector3(best.x, hb, best.y)
	_pierre(point_vue, 2.2, 1.4, Color(0.7, 0.68, 0.64))


func _paroi() -> void:
	# face nord : on cherche, au nord du sommet, l'endroit où le terrain est 20 à 26 m plus bas
	var nord := Vector2(0, -1)
	var meilleur := 0.0
	var dist := 30.0
	for dd in range(18, 130, 2):
		var q := Vector2(sommet.x, sommet.z) + nord * float(dd)
		var chute := sommet.y - terrain.hauteur(q.x, q.y)
		if chute >= 22.0:
			dist = float(dd)
			meilleur = chute
			break
	var pied := Vector2(sommet.x, sommet.z) + nord * dist
	var h_pied := terrain.hauteur(pied.x, pied.y)
	paroi_normale = Vector3(nord.x, 0, nord.y)
	# le haut de la paroi rejoint le terrain juste derrière elle (on débouche sur la pente du sommet)
	var dessus := pied - nord * 6.0
	paroi_haut = maxf(12.0, terrain.hauteur(dessus.x, dessus.y) + 0.6 - h_pied)
	paroi_base = Vector3(pied.x, h_pied, pied.y)
	var cote := Vector3(-paroi_normale.z, 0, paroi_normale.x)
	var sombre := StandardMaterial3D.new()
	sombre.albedo_texture = load("res://data/textures/roche_diff.jpg")
	sombre.normal_enabled = true
	sombre.normal_texture = load("res://data/textures/roche_nor.jpg")
	sombre.uv1_triplanar = true
	sombre.uv1_scale = Vector3.ONE * 0.18
	sombre.albedo_color = Color(0.45, 0.42, 0.4)
	var clair: StandardMaterial3D = sombre.duplicate()
	clair.albedo_color = Color(0.85, 0.82, 0.76)   # la roche plus claire où sont les prises
	var base := Basis(cote, Vector3.UP, paroi_normale)
	# la paroi : un grand bloc qui s'appuie contre la montagne, la voie claire au milieu
	for k in [-1, 0, 1]:
		var mi := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = Vector3(7.0 if k == 0 else 9.0, paroi_haut, 6.0)
		mi.mesh = bx
		mi.material_override = clair if k == 0 else sombre
		add_child(mi)
		mi.global_transform = Transform3D(base, paroi_base + cote * float(k) * 8.0 - paroi_normale * 3.0 + Vector3(0, paroi_haut * 0.5, 0))
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var forme := BoxShape3D.new()
		forme.size = bx.size
		cs.shape = forme
		sb.add_child(cs)
		mi.add_child(sb)
	# corniches où l'on reprend son souffle, et une vieille échelle de chantier rouillée
	corniches = [0.0, paroi_haut * 0.36, paroi_haut * 0.7]
	for hc in corniches.slice(1):
		var mi := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = Vector3(4.0, 0.3, 0.9)
		mi.mesh = bx
		mi.material_override = clair
		add_child(mi)
		mi.global_transform = Transform3D(base, paroi_base + paroi_normale * 0.4 + Vector3(0, hc, 0))
	var rouille := StandardMaterial3D.new()
	rouille.albedo_texture = load("res://data/textures/rusty_corrugated_iron_diff.jpg")
	rouille.uv1_triplanar = true
	for s_ in [-1.0, 1.0]:
		var mt := MeshInstance3D.new()
		var cy := CylinderMesh.new()
		cy.top_radius = 0.03
		cy.bottom_radius = 0.03
		cy.height = 5.0
		mt.mesh = cy
		mt.material_override = rouille
		add_child(mt)
		mt.global_position = paroi_base + paroi_normale * 0.15 + cote * (2.6 + s_ * 0.25) + Vector3(0, corniches[1] + 2.5, 0)
	# des prises plus claires semées sur la voie
	for i in 40:
		var mi := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = Vector3(randf_range(0.2, 0.4), randf_range(0.1, 0.18), 0.16)
		mi.mesh = bx
		mi.material_override = clair
		add_child(mi)
		mi.global_transform = Transform3D(base, paroi_base + cote * randf_range(-3.0, 3.0) + paroi_normale * 0.05 + Vector3(0, randf_range(0.6, paroi_haut - 0.5), 0))
	reprise = paroi_base + paroi_normale * 1.5


func _poste() -> void:
	# l'antenne-relais : pylône en treillis de 28 m
	antenne = StaticBody3D.new()
	add_child(antenne)
	antenne.global_position = sommet + Vector3(4, 0, 4)
	antenne.set_meta("antenne", true)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.72, 0.72, 0.7)
	metal.metallic = 0.6
	metal.roughness = 0.45
	var rouge := StandardMaterial3D.new()
	rouge.albedo_color = Color(0.85, 0.15, 0.1)
	var hp := 28.0
	for k in 4:
		var a := PI * 0.5 * k + PI * 0.25
		var pied := Vector3(cos(a), 0, sin(a)) * 1.2
		var tete := Vector3(cos(a), 0, sin(a)) * 0.35 + Vector3(0, hp, 0)
		var mi := MeshInstance3D.new()
		var cy := CylinderMesh.new()
		cy.top_radius = 0.05
		cy.bottom_radius = 0.07
		cy.height = pied.distance_to(tete)
		mi.mesh = cy
		mi.material_override = metal
		antenne.add_child(mi)
		var axe := (tete - pied).normalized()
		var bx := axe.cross(Vector3.FORWARD).normalized()
		mi.transform = Transform3D(Basis(bx, axe, bx.cross(axe)), (pied + tete) * 0.5)
	for e in 14:
		var y := 1.0 + e * 1.9
		var r := lerpf(1.2, 0.35, y / hp)
		var mi := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = r * 1.35 - 0.03
		tm.outer_radius = r * 1.35
		tm.rings = 4
		tm.ring_segments = 4
		mi.mesh = tm
		mi.material_override = rouge if e % 3 == 0 else metal
		antenne.add_child(mi)
		mi.position = Vector3(0, y, 0)
		mi.rotation.y = PI * 0.25
	for k in 3:  # paraboles et panneaux d'antennes
		var mi := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = Vector3(0.4, 1.4, 0.12)
		mi.mesh = bx
		mi.material_override = metal
		antenne.add_child(mi)
		var a := TAU * k / 3.0
		mi.position = Vector3(cos(a) * 0.55, hp - 2.5, sin(a) * 0.55)
		mi.rotation.y = -a
	var cs := CollisionShape3D.new()
	var forme := CylinderShape3D.new()
	forme.radius = 1.0
	forme.height = hp
	cs.shape = forme
	cs.position.y = hp * 0.5
	antenne.add_child(cs)
	var feu := OmniLight3D.new()
	feu.light_color = Color(1, 0.1, 0.05)
	feu.light_energy = 2.0
	feu.omni_range = 6.0
	feu.position.y = hp + 0.3
	antenne.add_child(feu)
	# local technique en parpaings, toit de tôle
	var mur := StandardMaterial3D.new()
	mur.albedo_texture = load("res://data/textures/concrete_block_wall_diff.jpg")
	mur.uv1_triplanar = true
	mur.uv1_scale = Vector3.ONE * 0.4
	var local := sommet + Vector3(-5, 0, 1)
	for c in [[Vector3(0, 1.4, -2), Vector3(5, 2.8, 0.2)], [Vector3(-2.5, 1.4, 0), Vector3(0.2, 2.8, 4)],
			[Vector3(2.5, 1.4, 0), Vector3(0.2, 2.8, 4)], [Vector3(-1.6, 1.4, 2), Vector3(1.8, 2.8, 0.2)],
			[Vector3(1.6, 1.4, 2), Vector3(1.8, 2.8, 0.2)], [Vector3(0, 2.9, 0), Vector3(5.4, 0.12, 4.4)]]:
		var mi := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = c[1]
		mi.mesh = bx
		mi.material_override = mur
		add_child(mi)
		mi.global_position = local + c[0]
		var sb := StaticBody3D.new()
		var cs2 := CollisionShape3D.new()
		var f2 := BoxShape3D.new()
		f2.size = c[1]
		cs2.shape = f2
		sb.add_child(cs2)
		mi.add_child(sb)
	var radio := MeshInstance3D.new()
	var rb := BoxMesh.new()
	rb.size = Vector3(1.2, 0.9, 0.6)
	radio.mesh = rb
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.2, 0.22, 0.2)
	radio.material_override = rm
	add_child(radio)
	radio.global_position = local + Vector3(0, 0.45, -1.4)
	# Joël, l'opérateur radio, assis devant son poste
	var vq: Node = main.get_node_or_null("VieQuotidienne")
	if vq:
		joel = vq._perso("garcon", "Assis", local + Vector3(0, 0.05, -0.6), PI)


func _interface() -> void:
	var calque := CanvasLayer.new()
	calque.layer = 6
	add_child(calque)
	jauge = ProgressBar.new()
	jauge.max_value = ENDURANCE
	jauge.show_percentage = false
	jauge.custom_minimum_size = Vector2(260, 14)
	jauge.anchor_left = 0.5
	jauge.anchor_right = 0.5
	jauge.anchor_top = 1.0
	jauge.anchor_bottom = 1.0
	jauge.offset_left = -130
	jauge.offset_right = 130
	jauge.offset_top = -90
	jauge.offset_bottom = -76
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.95, 0.75, 0.2)
	jauge.add_theme_stylebox_override("fill", sb)
	jauge.visible = false
	calque.add_child(jauge)
	choix_ui = PanelContainer.new()
	var fond := StyleBoxFlat.new()
	fond.bg_color = Color(0.06, 0.06, 0.07, 0.94)
	fond.border_color = Color(0.9, 0.6, 0.2)
	fond.set_border_width_all(2)
	fond.set_corner_radius_all(6)
	fond.set_content_margin_all(18)
	choix_ui.add_theme_stylebox_override("panel", fond)
	choix_ui.set_anchors_preset(Control.PRESET_CENTER)
	choix_ui.position = Vector2(-330, -200)
	choix_ui.custom_minimum_size = Vector2(660, 0)
	choix_ui.visible = false
	calque.add_child(choix_ui)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	choix_ui.add_child(col)
	var t := Label.new()
	t.text = "RADIO RACINES — premier message. Faris s'approche du micro."
	t.add_theme_font_size_override("font_size", 19)
	t.add_theme_color_override("font_color", Color(1.0, 0.8, 0.45))
	col.add_child(t)
	for c in [["L'espoir", "« Akwéri et Bomé sont libres. Leurs enfants mangent leur propre poisson et leur propre manioc. Vous pouvez l'être aussi. »", "espoir"],
			["La vérité", "Faris lit à l'antenne les noms des 37 familles dépossédées, tirés du carnet de son père.", "verite"],
			["Le défi", "« Commandant Mamba, tu écoutes ? Ton serpent a perdu deux villages. Il en reste cinq. »", "defi"]]:
		var b := Button.new()
		b.text = "%s — %s" % [c[0], c[1]]
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(620, 0)
		b.pressed.connect(_message.bind(c[2]))
		col.add_child(b)


func etat_texte() -> String:
	return ["à venir", "disponible", "le lac", "la face nord", "le sommet", "le message", "Radio Racines émet"][phase]


# ---------------------------------------------------------------------
# Déroulement
# ---------------------------------------------------------------------
func _balise(p: Vector3) -> void:
	var ca: Node = main.get_node_or_null("Carte")
	if ca:
		ca.poser_balise(p)


func _process(delta: float) -> void:
	if joueur == null:
		return
	var jp := joueur.global_position
	match phase:
		Phase.INDISPONIBLE:
			var m6: Node = main.get_node_or_null("Mission6")
			if m6 and m6.phase == Mission6.Phase.TERMINEE:
				phase = Phase.DISPONIBLE
				_balise(lac)
		Phase.DISPONIBLE:
			if jp.distance_to(lac) < 150.0:
				_commencer()
		Phase.LAC:
			if not vue_faite and jp.distance_to(point_vue) < 5.0:
				_point_de_vue()
			if jp.distance_to(paroi_base) < 25.0:
				phase = Phase.FALAISE
				m4._objectif("Face nord : grimpez par la roche claire (Espace contre la paroi, ZQSD, gardez de l'endurance ; reprenez votre souffle sur les corniches).")
		Phase.FALAISE, Phase.SOMMET:
			if phase == Phase.FALAISE and jp.y > paroi_base.y + paroi_haut - 2.0 and Vector2(jp.x - sommet.x, jp.z - sommet.z).length() < 70.0:
				_au_sommet()
			if phase == Phase.SOMMET:
				var actifs := 0
				for g in gardes:
					if (g as Pnj).est_actif():
						actifs += 1
				if actifs == 0:
					_joel()
	if t_vue > 0.0:
		t_vue -= delta
		cam_vue.global_position = point_vue + Vector3(cos(t_vue * 0.18) * 90.0, 70.0, sin(t_vue * 0.18) * 90.0)
		cam_vue.look_at(point_vue + Vector3(0, -40, 0))
		if t_vue <= 0.0:
			cam_vue.queue_free()
			(joueur.camera as Camera3D).make_current()
	if grimpe:
		_grimper(delta)


func _commencer() -> void:
	phase = Phase.LAC
	joueur.mission = self
	var amb: Ambiances = main.ambiances
	var garde := 0
	while amb.index != 4 and garde < 6:   # l'aube, brume sur le lac
		amb.suivante()
		garde += 1
	m4._annoncer("Mission 7 — La Voix de l'Île", 4.0)
	m4._objectif("Montez au lac du cratère, puis gagnez la face nord du mont Talanké. (Facultatif : offrande au sanctuaire, F ; le rocher du point de vue.)")
	_balise(paroi_base)
	_dire("KWAME (radio)", "Le chemin du sommet est gardé. Il y a la face nord. Les chèvres y montent. Les gardes, non. … Toi, je ne sais pas.", 2.0)


func _dire(qui: String, texte: String, delai: float) -> void:
	await get_tree().create_timer(delai).timeout
	m4._annoncer("%s — %s" % [qui, texte], 6.0)


func _point_de_vue() -> void:
	vue_faite = true
	cam_vue = Camera3D.new()
	cam_vue.far = 6000.0
	add_child(cam_vue)
	cam_vue.make_current()
	t_vue = 7.0
	var b: Node = get_node_or_null("Brume")
	if b:
		(b as CPUParticles3D).emitting = false
	m4._annoncer("La brume se lève : toute l'île apparaît — Port-Néré, Akwéri, Bomé, Tikané, et le camp du Cobra au sud.", 6.0)


func interagir() -> void:
	var jp := joueur.global_position
	if not offrande and jp.distance_to(sanctuaire) < 3.0:
		offrande = true
		m4.confiance = clampi(m4.confiance + 2, 0, 100)
		m4._annoncer("Vous déposez une offrande de cola sur la pierre. Les anciens l'apprendront. (Confiance +2)", 4.0)
		return
	if phase == Phase.SOMMET:
		for g in gardes:
			var p := g as Pnj
			if p.global_position.distance_to(jp) < 2.0 and (p.etat == Pnj.Etat.RENDU or (p.est_actif() and p.dos_au_joueur())):
				p.ligoter()
				m4._annoncer("Garde ligoté.", 2.0)
				return
	m4.interagir()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("sauter") or joueur.a_cheval:
		return
	if grimpe:
		return
	if phase != Phase.FALAISE and phase != Phase.SOMMET:
		return
	# contre la voie claire de la face nord ?
	var rel := joueur.global_position - paroi_base
	var cote := Vector3(-paroi_normale.z, 0, paroi_normale.x)
	var lat := rel.dot(cote)
	var dev := rel.dot(paroi_normale)
	if absf(lat) < 3.4 and dev < 1.6 and dev > -0.5 and rel.y < paroi_haut - 1.0:
		grimpe = true
		pos_paroi = Vector2(lat, maxf(rel.y, 0.3))
		joueur.set_physics_process(false)
		joueur.velocity = Vector3.ZERO
		jauge.visible = true
		var ap: AnimationPlayer = joueur.corps.find_child("AnimationPlayer", true, false)
		if ap:
			ap.play("Reparer")
		get_viewport().set_input_as_handled()


func _grimper(delta: float) -> void:
	var entree := Input.get_vector("gauche", "droite", "reculer", "avancer")
	var cote := Vector3(-paroi_normale.z, 0, paroi_normale.x)
	var bouge := entree.length() > 0.1
	pos_paroi.x = clampf(pos_paroi.x - entree.x * 0.9 * delta, -3.2, 3.2)
	pos_paroi.y += entree.y * 1.1 * delta
	endurance -= delta * (7.5 if bouge else 2.5)
	# corniche : on reprend son souffle, c'est le nouveau point de reprise
	for hc in corniches:
		if absf(pos_paroi.y - hc) < 0.4 and hc > 0.0:
			endurance = minf(ENDURANCE, endurance + delta * 30.0)
			reprise = paroi_base + paroi_normale * 1.0 + Vector3(0, hc + 0.3, 0)
	jauge.value = endurance
	var p := paroi_base + cote * pos_paroi.x + paroi_normale * 0.45 + Vector3(0, pos_paroi.y, 0)
	joueur.global_position = p
	joueur.corps.rotation.y = atan2(-paroi_normale.x, -paroi_normale.z)
	if pos_paroi.y < 0.2:
		_lacher(paroi_base + paroi_normale * 1.2, false)
	elif pos_paroi.y >= paroi_haut - 0.4:
		# en haut : on se hisse sur le replat
		var dessus := paroi_base - paroi_normale * 6.5
		_lacher(Vector3(dessus.x, maxf(terrain.hauteur(dessus.x, dessus.z), paroi_base.y + paroi_haut) + 0.6, dessus.z), false)
		m4._annoncer("Vous vous hissez au-dessus de la face nord.", 2.5)
	elif endurance <= 0.0:
		_lacher(reprise, true)


func _lacher(ou: Vector3, chute: bool) -> void:
	grimpe = false
	joueur.global_position = ou
	joueur.set_physics_process(true)
	jauge.visible = false
	if chute:
		endurance = ENDURANCE
		m4._annoncer("Les doigts lâchent… Faris se rattrape sur la dernière corniche.", 3.0)
	else:
		endurance = ENDURANCE


func _au_sommet() -> void:
	phase = Phase.SOMMET
	m4._objectif("Le poste du sommet : 5 gardes. Neutralisez-les (en silence si possible). Pas une balle sur l'antenne !")
	_balise(antenne.global_position)
	var amb: Ambiances = main.ambiances
	if amb.index != 1:
		var garde := 0
		while amb.index != 1 and garde < 6:   # grand soleil au sommet
			amb.suivante()
			garde += 1
	_placer_gardes()


func _placer_gardes() -> void:
	for g in gardes:
		if is_instance_valid(g):
			g.queue_free()
	gardes.clear()
	var modeles := ["homme2", "villageois", "homme3"]
	var rondes := [[Vector3(10, 0, -6), Vector3(-10, 0, -6)], [Vector3(-12, 0, 6), Vector3(12, 0, 8)],
			[Vector3(8, 0, 12), Vector3(8, 0, -2)], [Vector3(-3, 0, 4), Vector3(-3, 0, 4.1)], [Vector3(0, 0, 14), Vector3(-9, 0, 14)]]
	for i in rondes.size():
		var pts: Array = []
		for q in rondes[i]:
			var w: Vector3 = sommet + q
			pts.append(Vector3(w.x, terrain.hauteur(w.x, w.z), w.z))
		var g := Pnj.new()
		add_child(g)
		g.global_position = pts[0] + Vector3(0, 0.3, 0)
		g.preparer("milicien", self, joueur, Color(1, 1, 1), "res://data/textures/camouflage.jpg", modeles[i % 3])
		g.points_patrouille = pts
		g.portee_vue = 30.0
		g.rendu.connect(func(_n: Pnj) -> void: m4._annoncer("Le garde se rend : F pour le ligoter.", 2.5))
		g.alerte.connect(func(_q: Vector3) -> void:
			for h in gardes:
				if (h as Pnj).est_actif():
					(h as Pnj)._passer_combat())
		gardes.append(g)


# ---------- ce que les Pnj demandent ----------
func choisir_couvert(n: Pnj) -> Vector3:
	return n.global_position


func bruit_de_tir(p: Vector3, _joueur_tire := false) -> void:
	for g in gardes:
		(g as Pnj).entendre(p, 80.0)


func blessure() -> void:
	m4.blessure()


func _impact(collider: Object, _p: Vector3) -> void:
	if phase != Phase.SOMMET or collider == null or not (collider as Node).has_meta("antenne"):
		return
	m4._annoncer("Une balle a touché l'antenne : l'émetteur grésille et meurt.\nMISSION MANQUÉE — on reprend au pied de la face nord.", 6.0)
	phase = Phase.FALAISE
	joueur.global_position = paroi_base + paroi_normale * 2.0 + Vector3(0, 0.5, 0)
	for g in gardes:
		if is_instance_valid(g):
			g.queue_free()
	gardes.clear()


func _joel() -> void:
	phase = Phase.MESSAGE
	if joel:
		var ap: AnimationPlayer = joel.find_child("AnimationPlayer", true, false)
		ap.play("Rendu")
	m4._annoncer("JOËL — « Je ne suis pas milicien ! Je fais juste la radio ! Ils m'ont dit que sinon ma mère… »", 5.0)
	_dire("FARIS", "« Tu sais faire marcher tout ça ? » — JOËL : « … Oui. » — FARIS : « Alors tu travailles pour l'île, maintenant. »", 5.5)
	await get_tree().create_timer(11.5).timeout
	choix_ui.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _message(ton: String) -> void:
	choix_ui.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	phase = Phase.TERMINEE
	joueur.mission = m4
	var tel: Node = main.get_node_or_null("Telephone")
	match ton:
		"espoir":
			m4.confiance = clampi(m4.confiance + 6, 0, 100)
			m4._annoncer("Le message d'espoir traverse l'île. Les villages hésitants écoutent. (Confiance +6)", 5.0)
		"verite":
			m4.confiance = clampi(m4.confiance + 3, 0, 100)
			if tel:
				tel.ajouter_preuve("Les 37 familles de Bomé", "Les noms des familles dépossédées, lus à l'antenne depuis le carnet de Samuel. Une preuve publique : toute l'île les a entendus.")
			m4._annoncer("Les noms résonnent dans toute l'île. Le Cobra durcit la répression. (Confiance +3)", 5.0)
			_durcir_patrouilles(1.35)
		"defi":
			m4.confiance = clampi(m4.confiance + 2, 0, 100)
			m4._annoncer("Le défi fait rire tout le port. Le moral des Racines monte… et Mamba envoie plus de patrouilles.", 5.0)
			_durcir_patrouilles(1.2)
	if tel:
		tel.radio_racines = true
		tel.ton_radio = ton
		tel.allumer_radio(true)
	_musique_au_port()
	_dire("AMA (radio, en riant)", "Tout le port danse. Même les gardes du quai tapent du pied.", 6.0)
	m4._objectif("Prochain objectif : un message arrive de Tikané — des otages (mission 8).")


func _durcir_patrouilles(k: float) -> void:
	var pa: Node = main.get_node_or_null("Patrouilles")
	if pa == null:
		return
	pa.set_meta("vue_bonus", k)
	for pk in pa.pickups:
		pk["v"] = pk.get("v", 7.0) * k


func _musique_au_port() -> void:
	# la musique sort des fenêtres de Port-Néré
	var ville: VillePortNere = main.ville
	var s: AudioStreamWAV = load("res://sons/radio_racines.wav")
	for nom in ["maquis", "marche", "place"]:
		if not ville.reperes.has(nom):
			continue
		var p: Vector3 = ville.reperes[nom]
		var e := AudioStreamPlayer3D.new()
		e.stream = s
		e.unit_size = 6.0
		e.max_distance = 70.0
		e.volume_db = -6.0
		main.add_child(e)
		e.global_position = p + Vector3(0, 2.0, 0)
		e.play(randf() * 10.0)
		emetteurs.append(e)


func restaurer_terminee(ton: String) -> void:
	phase = Phase.TERMINEE
	_musique_au_port()
	m4._objectif("Prochain objectif : un message arrive de Tikané — des otages (mission 8).")

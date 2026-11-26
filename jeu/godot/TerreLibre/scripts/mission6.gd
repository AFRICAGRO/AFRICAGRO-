## Mission 6 — « Champs de Cendre » (voir jeu/missions/06-CHAMPS-DE-CENDRE.md).
## Après la mission 5 : libérer Bomé. Détruire par le feu les 3 parcelles illicites que le Cobra
## impose aux familles, sans brûler le village, puis fonder la première coopérative.
## - Observer : lire le vent à la manche à air. L'harmattan descend de la colline vers le village.
## - Le feu (F dans une parcelle) : il court vite DANS le sens du vent (feu de front, violent) et remonte
##   lentement CONTRE le vent (feu de recul, faible). Un feu de front qui atteint le bord côté village saute
##   dans les herbes sèches et file vers la maison la plus proche. Bonne technique : allumer chaque parcelle
##   par son bord côté village (le feu remonte contre le vent), ou creuser d'abord un coupe-feu (F au repère,
##   avec les cultivateurs).
## - Un feu d'herbes ou une maison en feu s'éteint à plusieurs : F près des flammes (seaux d'eau).
##   Une maison perdue coûte cher en confiance.
## - La riposte : dès le premier feu, contremaîtres et gardes des miradors attaquent, et la patrouille
##   la plus proche arrive. La fumée cache Faris.
## - La coopérative : choix des cultures, des familles affectées et de la part gardée par le village.
##   Les revenus (en zalas, ZLM) arrivent ensuite régulièrement.
class_name Mission6
extends Node3D

enum Phase { INDISPONIBLE, DISPONIBLE, OBSERVER, FEU, COOPERATIVE, TERMINEE }
const CASE := 4.0
const NX := 10                 # 40 m
const NY := 7                  # 26 m (+2)
const DUREE_FEU := 10.0
const FAMILLES := 37
const SEMAINE := 60.0          # une semaine de la coopérative = une minute de jeu

var phase := Phase.INDISPONIBLE
var main: Node
var joueur: Joueur
var m4: Mission4
var m5: Node
var bome: VillageBome
var terrain: Terrain
var vent := Vector2.ZERO
var parcelles: Array = []      # {c, dir, n, etat[], t[], front[], plants mm, inst_case[], bord_village (Vector2i dir), brulee}
var feux: Dictionary = {}      # Vector3i(k,i,j) -> CPUParticles3D
var herbes: Array = []         # feux d'herbes qui s'échappent : {pos, cible (maison), noeud, eteint}
var maisons_feu: Dictionary = {}   # indice de maison -> {t, noeud, eau}
var maisons_perdues := 0
var coupe_feu := false
var t_coupe := -1.0
var repere_coupe := Vector3.ZERO
var cultivateurs: Array = []
var gardes: Array = []
var allume := false
var t_tick := 0.0
var mat_flamme: StandardMaterial3D
var mat_fumee: StandardMaterial3D
var argent := 0
var revenu := 0
var t_revenu := 0.0
var choix: Dictionary = {}
var etiquette: Label
var panneau: Control


func construire(p_main: Node) -> void:
	main = p_main
	joueur = main.joueur
	m4 = main.get_node("Mission4")
	m5 = main.get_node_or_null("Mission5")
	bome = main.bome
	terrain = main.terrain
	vent = bome.vent
	mat_flamme = StandardMaterial3D.new()
	mat_flamme.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_flamme.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat_flamme.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_flamme.albedo_texture = load("res://data/textures/fumee.png")
	mat_flamme.vertex_color_use_as_albedo = true
	mat_flamme.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat_fumee = mat_flamme.duplicate()
	mat_fumee.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	var pc: Array = bome.reperes.get("parcelles", [])
	var axes: Array = bome.reperes.get("parcelles_axe", [])
	var mms: Array = bome.reperes.get("parcelles_mm", [])
	var village: Vector3 = bome.reperes["place"]
	var somme := Vector2.ZERO
	for k in pc.size():
		var c3: Vector3 = pc[k]
		var c := Vector2(c3.x, c3.z)
		var dir := Vector2(cos(axes[k]), sin(axes[k]))
		var n := Vector2(-dir.y, dir.x)
		# bord côté village : celui dont la normale extérieure regarde le plus vers la place
		var vers := (Vector2(village.x, village.z) - c).normalized()
		var bord := Vector2i(0, 1) if n.dot(vers) > 0.0 else Vector2i(0, -1)
		if absf(dir.dot(vers)) > absf(n.dot(vers)):
			bord = Vector2i(1, 0) if dir.dot(vers) > 0.0 else Vector2i(-1, 0)
		var p := {"c": c, "dir": dir, "n": n, "bord": bord, "brulee": false, "mm": mms[k] if k < mms.size() else null,
				"etat": [], "t": [], "front": [], "inst": []}   # tableaux (références) : modifiés sur place
		for _i in NX * NY:
			p["etat"].append(0)
			p["t"].append(0.0)
			p["front"].append(0)
		# chaque plant appartient à une case de 4 m
		var mm: MultiMeshInstance3D = p["mm"]
		var inst: Array = []
		for i in NX * NY:
			inst.append([])
		if mm:
			for i in mm.multimesh.instance_count:
				var o := mm.position + mm.multimesh.get_instance_transform(i).origin
				var ij := _case(p, Vector2(o.x, o.z))
				if ij.x >= 0:
					(inst[ij.y * NX + ij.x] as Array).append(i)
		p["inst"] = inst
		# sol calciné : une plaque de cendre par case, invisible tant que la case n'a pas brûlé
		var cendre := MultiMesh.new()
		cendre.transform_format = MultiMesh.TRANSFORM_3D
		var plaque := PlaneMesh.new()
		plaque.size = Vector2(CASE * 1.4, CASE * 1.4)
		var mc := StandardMaterial3D.new()
		mc.albedo_color = Color(0.06, 0.055, 0.05)
		mc.roughness = 1.0
		plaque.material = mc
		cendre.mesh = plaque
		cendre.instance_count = NX * NY
		for i in NX * NY:
			cendre.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
		var mci := MultiMeshInstance3D.new()
		mci.multimesh = cendre
		add_child(mci)
		p["cendre"] = cendre
		parcelles.append(p)
		somme += c + Vector2(bord.x, bord.y).x * dir * 20.0 + float(bord.y) * n * 13.0
	if parcelles.size() > 0:
		var milieu := somme / parcelles.size()
		var vv := (Vector2(village.x, village.z) - milieu).normalized()
		var q := milieu + vv * 14.0
		repere_coupe = Vector3(q.x, terrain.hauteur(q.x, q.y), q.y)
	_interface()
	joueur.a_tire.connect(func(q: Vector3) -> void:
		if phase == Phase.FEU or phase == Phase.OBSERVER:
			bruit_de_tir(q, true))


func _case(p: Dictionary, q: Vector2) -> Vector2i:
	var d: Vector2 = q - p["c"]
	var u := d.dot(p["dir"]) + NX * CASE * 0.5
	var v := d.dot(p["n"]) + NY * CASE * 0.5
	var i := int(floor(u / CASE))
	var j := int(floor(v / CASE))
	if i < 0 or j < 0 or i >= NX or j >= NY:
		return Vector2i(-1, -1)
	return Vector2i(i, j)


func _centre(p: Dictionary, i: int, j: int) -> Vector3:
	var q: Vector2 = p["c"] + p["dir"] * ((i + 0.5) * CASE - NX * CASE * 0.5) + p["n"] * ((j + 0.5) * CASE - NY * CASE * 0.5)
	return Vector3(q.x, terrain.hauteur(q.x, q.y), q.y)


func _au_bord_village(p: Dictionary, i: int, j: int) -> bool:
	var b: Vector2i = p["bord"]
	return (b.x == 1 and i == NX - 1) or (b.x == -1 and i == 0) or (b.y == 1 and j == NY - 1) or (b.y == -1 and j == 0)


# ---------------------------------------------------------------------
# Interface : argent de la résistance, coopérative
# ---------------------------------------------------------------------
func _interface() -> void:
	var calque := CanvasLayer.new()
	calque.layer = 6
	add_child(calque)
	etiquette = Label.new()
	etiquette.add_theme_font_size_override("font_size", 17)
	etiquette.add_theme_constant_override("outline_size", 6)
	etiquette.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	etiquette.add_theme_color_override("font_color", Color(0.6, 0.95, 0.55))
	etiquette.anchor_left = 1.0
	etiquette.anchor_right = 1.0
	etiquette.offset_left = -320
	etiquette.offset_right = -20
	etiquette.offset_top = 74
	etiquette.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	calque.add_child(etiquette)
	panneau = PanelContainer.new()
	panneau.set_anchors_preset(Control.PRESET_CENTER)
	panneau.custom_minimum_size = Vector2(640, 0)
	panneau.position = Vector2(-320, -250)
	var fond := StyleBoxFlat.new()
	fond.bg_color = Color(0.09, 0.07, 0.05, 0.94)
	fond.border_color = Color(0.8, 0.55, 0.2)
	fond.set_border_width_all(2)
	fond.set_corner_radius_all(6)
	fond.set_content_margin_all(18)
	panneau.add_theme_stylebox_override("panel", fond)
	panneau.visible = false
	calque.add_child(panneau)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panneau.add_child(col)
	var titre := Label.new()
	titre.text = "COOPÉRATIVE DE BOMÉ — réunion sous l'arbre à palabres"
	titre.add_theme_font_size_override("font_size", 20)
	titre.add_theme_color_override("font_color", Color(1.0, 0.8, 0.45))
	col.add_child(titre)
	var baya := Label.new()
	baya.text = "BAYA EFUA — « Ton père a fondé cette coopérative avec onze familles et trois sacs de graines. Toi, tu en as trente-sept. »"
	baya.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	baya.add_theme_color_override("font_color", Color(0.92, 0.9, 0.85))
	col.add_child(baya)
	var culture := OptionButton.new()
	culture.name = "Culture"
	for t in ["Manioc — récolte rapide, petits revenus", "Maïs — équilibré", "Cacao — lent, gros revenus"]:
		culture.add_item(t)
	culture.select(1)
	col.add_child(_ligne("Culture principale", culture))
	var familles := HSlider.new()
	familles.name = "Familles"
	familles.min_value = 8
	familles.max_value = FAMILLES
	familles.step = 1
	familles.value = 25
	familles.custom_minimum_size = Vector2(300, 0)
	col.add_child(_ligne("Familles aux champs", familles))
	var part := HSlider.new()
	part.name = "Part"
	part.min_value = 0
	part.max_value = 50
	part.step = 5
	part.value = 20
	part.custom_minimum_size = Vector2(300, 0)
	col.add_child(_ligne("Part gardée par le village", part))
	var bilan := Label.new()
	bilan.name = "Bilan"
	bilan.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bilan.add_theme_color_override("font_color", Color(0.75, 0.95, 0.7))
	col.add_child(bilan)
	var ok := Button.new()
	ok.text = "Fonder la coopérative"
	ok.pressed.connect(_fonder)
	col.add_child(ok)
	for c in [culture, familles, part]:
		if c is OptionButton:
			(c as OptionButton).item_selected.connect(func(_i: int) -> void: _bilan())
		else:
			(c as HSlider).value_changed.connect(func(_v: float) -> void: _bilan())


func _ligne(nom: String, ctrl: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = nom
	l.custom_minimum_size = Vector2(230, 0)
	l.add_theme_color_override("font_color", Color(0.9, 0.88, 0.82))
	h.add_child(l)
	h.add_child(ctrl)
	var v := Label.new()
	v.name = "Valeur"
	v.custom_minimum_size = Vector2(60, 0)
	h.add_child(v)
	return h


## Rendement par famille et par semaine (ZLM), délai avant la première récolte (semaines).
const CULTURES := [
	{"nom": "manioc", "delai": 6, "zlm": 40},
	{"nom": "maïs", "delai": 12, "zlm": 65},
	{"nom": "cacao", "delai": 26, "zlm": 120},
]


func _valeurs() -> Dictionary:
	var culture := (panneau.find_child("Culture", true, false) as OptionButton).selected
	var familles := int((panneau.find_child("Familles", true, false) as HSlider).value)
	var part := int((panneau.find_child("Part", true, false) as HSlider).value)
	var c: Dictionary = CULTURES[culture]
	var brut: int = familles * c["zlm"]
	return {"culture": culture, "familles": familles, "part": part, "delai": c["delai"],
			"revenu": int(brut * (100 - part) / 100.0), "village": int(brut * part / 100.0),
			"defenseurs": FAMILLES - familles, "confiance": 4 + part / 5}


func _bilan() -> void:
	var v := _valeurs()
	(panneau.find_child("Familles", true, false).get_parent().get_node("Valeur") as Label).text = str(v["familles"])
	(panneau.find_child("Part", true, false).get_parent().get_node("Valeur") as Label).text = "%d %%" % v["part"]
	(panneau.find_child("Bilan", true, false) as Label).text = \
		"Première récolte dans %d semaines · %d ZLM par semaine pour la résistance · %d ZLM pour les familles\n%d hommes et femmes restent pour défendre Bomé · confiance de l'île : +%d" % \
		[v["delai"], v["revenu"], v["village"], v["defenseurs"], v["confiance"]]


func _fonder() -> void:
	choix = _valeurs()
	panneau.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	revenu = choix["revenu"]
	# une « semaine » de la coopérative = une minute de jeu ; rien avant la première récolte
	t_revenu = -float(choix["delai"]) * SEMAINE
	m4.confiance = clampi(m4.confiance + int(choix["confiance"]) - maisons_perdues * 15, 0, 100)
	phase = Phase.TERMINEE
	_drapeau()
	m4._annoncer("BOMÉ EST LIBRE — la première coopérative est fondée.\nBaya Efua vous remet le sceau de la coopérative, celui de votre père Samuel.", 7.0)
	m4._objectif("Prochain objectif : la résistance a besoin d'une voix — l'antenne du mont Talanké (mission 7).")
	joueur.mission = m4


func _drapeau() -> void:
	# le drapeau des Racines est hissé sur le grenier à semences
	var g: Vector3 = bome.reperes["grenier"]
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://data/textures/drapeau_racines.jpg")
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mat_mat := StandardMaterial3D.new()
	mat_mat.albedo_color = Color(0.5, 0.42, 0.32)
	var mat_mi := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 0.04
	cy.bottom_radius = 0.05
	cy.height = 4.0
	mat_mi.mesh = cy
	mat_mi.material_override = mat_mat
	add_child(mat_mi)
	mat_mi.global_position = g + Vector3(0, 5.5, 0)
	var dr := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(1.5, 1.0)
	dr.mesh = qm
	dr.material_override = mat
	add_child(dr)
	var v3 := Vector3(vent.x, 0, vent.y).normalized()
	dr.global_transform = Transform3D(Basis.looking_at(Vector3(-v3.z, 0, v3.x), Vector3.UP), g + Vector3(0, 7.0, 0) + v3 * 0.78)


# ---------------------------------------------------------------------
# Déroulement
# ---------------------------------------------------------------------
func demarrer() -> void:
	phase = Phase.OBSERVER
	joueur.mission = self
	# après-midi venteux de saison sèche
	var amb: Ambiances = main.ambiances
	var garde := 0
	while amb.index != 1 and garde < 6:
		amb.suivante()
		garde += 1
	_placer_gardes()
	_placer_cultivateurs()
	m4._annoncer("Mission 6 — Champs de Cendre", 4.0)
	m4._objectif("Observez Bomé : allez lire le vent à la manche à air, au-dessus du village.")
	var ca: Node = main.get_node_or_null("Carte")
	if ca:
		ca.poser_balise(bome.reperes["manche_a_air"])
	_dire("BAYA EFUA", "Ils font travailler nos familles sur nos propres terres, sous les fusils. Si le feu touche une seule maison, ils diront que c'est toi le criminel. Et ils auront raison.", 1.0)


func _dire(qui: String, texte: String, delai: float) -> void:
	await get_tree().create_timer(delai).timeout
	m4._annoncer("%s — %s" % [qui, texte], 6.5)


func _placer_gardes() -> void:
	var modeles := ["homme2", "villageois", "homme3"]
	var places: Array = []
	for t in bome.reperes.get("tours", []):
		places.append([t, null])
	for k in parcelles.size():
		var p: Dictionary = parcelles[k]
		var b: Vector2i = p["bord"]
		# contremaître : va et vient le long du bord côté village de sa parcelle
		var a := _centre(p, 0 if b.x != 1 else NX - 1, 0 if b.y != 1 else NY - 1)
		var z := _centre(p, NX - 1 if b.x != -1 else 0, NY - 1 if b.y != -1 else 0)
		places.append([a, z])
	for i in places.size():
		var g := Pnj.new()
		add_child(g)
		var p0: Vector3 = places[i][0]
		g.global_position = p0 + Vector3(1.5, 0.4, 0)
		g.preparer("milicien", self, joueur, Color(1, 1, 1), "res://data/textures/camouflage.jpg", modeles[i % 3])
		if places[i][1] != null:
			g.points_patrouille = [p0, places[i][1]]
		g.alerte.connect(func(_q: Vector3) -> void: _riposte())
		g.rendu.connect(func(_n: Pnj) -> void: m4._annoncer("Le contremaître se rend : F pour le ligoter.", 2.5))
		gardes.append(g)


func _placer_cultivateurs() -> void:
	# des familles binent sous la surveillance des contremaîtres
	var vq: Node = main.get_node_or_null("VieQuotidienne")
	if vq == null:
		return
	var modeles := ["cultivateur", "femme", "villageois", "femme2", "cultivateur", "homme3"]
	var k := 0
	for p in parcelles:
		for m in 2:
			var c := _centre(p, 2 + m * 5, 2 + m * 2)
			var perso: Node3D = vq._perso(modeles[k % modeles.size()], "Biner", c, randf() * TAU)
			cultivateurs.append(perso)
			k += 1


func _cultivateurs_s_ecartent() -> void:
	var place: Vector3 = bome.reperes["place"]
	for perso in cultivateurs:
		var n := perso as Node3D
		if not is_instance_valid(n):
			continue
		var ap: AnimationPlayer = n.find_child("AnimationPlayer", true, false)
		ap.play("Course")
		var cible := place + Vector3(randf_range(-12, 12), 0, randf_range(-12, 12))
		var vers := cible - n.global_position
		n.rotation.y = atan2(vers.x, vers.z)
		var tw := create_tween()
		tw.tween_property(n, "global_position", Vector3(cible.x, terrain.hauteur(cible.x, cible.z), cible.z), vers.length() / 4.5)
		tw.tween_callback(func() -> void: ap.play("Repos"))
	cultivateurs.clear()


func _riposte() -> void:
	for g in gardes:
		if (g as Pnj).est_actif():
			(g as Pnj)._passer_combat()
	var pa: Node = main.get_node_or_null("Patrouilles")
	if pa and not gardes.is_empty():
		pa._alerte_generale((gardes[0] as Node3D).global_position)


# ---------- ce que les Pnj demandent ----------
func choisir_couvert(n: Pnj) -> Vector3:
	return n.global_position


func bruit_de_tir(p: Vector3, _joueur_tire := false) -> void:
	for g in gardes:
		(g as Pnj).entendre(p, 90.0)


func blessure() -> void:
	m4.blessure()


# ---------- F ----------
func interagir() -> void:
	var jp := joueur.global_position
	if phase == Phase.FEU or phase == Phase.OBSERVER:
		# maîtriser d'abord
		for g in gardes:
			var p := g as Pnj
			if p.global_position.distance_to(jp) < 2.0 and (p.etat == Pnj.Etat.RENDU or (p.est_actif() and p.dos_au_joueur())):
				p.ligoter()
				m4._annoncer("Contremaître ligoté.", 2.0)
				return
		# éteindre : feu d'herbes ou maison
		for h in herbes:
			if not h["eteint"] and (h["pos"] as Vector3).distance_to(jp) < 6.0:
				h["eau"] = h.get("eau", 0) + 1
				m4._annoncer("Seaux d'eau, branches : le feu d'herbes recule… (%d/3)" % h["eau"], 1.5)
				if h["eau"] >= 3:
					_eteindre_herbes(h)
				return
		for i in maisons_feu:
			var mf: Dictionary = maisons_feu[i]
			var pos: Vector3 = bome.reperes["maisons"][i]
			if pos.distance_to(jp) < 9.0:
				mf["t"] = maxf(0.0, mf["t"] - 9.0)
				mf["aide"] = true
				m4._annoncer("Avec les voisins, vous jetez l'eau sur le toit…", 1.5)
				return
	if phase == Phase.FEU:
		# coupe-feu
		if not coupe_feu and t_coupe < 0.0 and jp.distance_to(repere_coupe) < 6.0:
			_creuser_coupe_feu()
			return
		# allumer une parcelle
		for k in parcelles.size():
			var p: Dictionary = parcelles[k]
			var ij := _case(p, Vector2(jp.x, jp.z))
			if ij.x < 0:
				# tout près du bord, on allume la case la plus proche
				var best := Vector2i(-1, -1)
				var dmin := 3.5
				for i in NX:
					for j in NY:
						var d := _centre(p, i, j).distance_to(jp)
						if d < dmin:
							dmin = d
							best = Vector2i(i, j)
				ij = best
			if ij.x >= 0 and p["etat"][ij.y * NX + ij.x] == 0:
				# on allume une ligne de feu tout le long du bord le plus proche (comme les cultivateurs avec
				# une torche) ; au milieu de la parcelle, un simple foyer
				var cases := _ligne_de_feu(ij)
				for c in cases:
					if p["etat"][c.y * NX + c.x] == 0:
						_allumer(k, c.x, c.y, false)
				m4._annoncer("Vous allumez une ligne de feu le long du bord de la parcelle." if cases.size() > 1 else "Vous mettez le feu à la parcelle.", 2.0)
				if not allume:
					allume = true
					_cultivateurs_s_ecartent()
					_riposte()
				return
	m4.interagir()


func _ligne_de_feu(ij: Vector2i) -> Array:
	var res: Array = []
	if ij.x == 0 or ij.x == NX - 1:
		for j in NY:
			res.append(Vector2i(ij.x, j))
	elif ij.y == 0 or ij.y == NY - 1:
		for i in NX:
			res.append(Vector2i(i, ij.y))
	else:
		res.append(ij)
	return res


func _creuser_coupe_feu() -> void:
	t_coupe = 15.0
	m4._annoncer("Les cultivateurs prennent leurs houes : un coupe-feu entre les parcelles et le village (15 s).", 3.0)
	var vq: Node = main.get_node_or_null("VieQuotidienne")
	if vq:
		for i in 3:
			var q := repere_coupe + Vector3(i * 2.2 - 2.2, 0, 1.0)
			vq._perso(["cultivateur", "homme3", "villageois"][i], "Biner", Vector3(q.x, terrain.hauteur(q.x, q.z), q.z), randf() * TAU)


func _coupe_feu_fini() -> void:
	coupe_feu = true
	m4._annoncer("Coupe-feu creusé : la terre nue arrêtera les flammes avant le village.", 3.0)
	var terre := StandardMaterial3D.new()
	terre.albedo_texture = load("res://data/textures/laterite_diff.jpg")
	terre.uv1_triplanar = true
	terre.uv1_scale = Vector3.ONE * 0.4
	for p in parcelles:
		var b: Vector2i = p["bord"]
		var axe: Vector2 = p["dir"] if b.x != 0 else p["n"]
		var long_: float = (NY if b.x != 0 else NX) * CASE
		var sortie: Vector2 = (p["dir"] * float(b.x) * (NX * CASE * 0.5 + 3.0)) + (p["n"] * float(b.y) * (NY * CASE * 0.5 + 3.0))
		var le_long: Vector2 = p["n"] if b.x != 0 else p["dir"]
		for s in 10:
			var q: Vector2 = p["c"] + sortie + le_long * (s / 9.0 - 0.5) * long_
			var mi := MeshInstance3D.new()
			var bx := BoxMesh.new()
			bx.size = Vector3(long_ / 9.0 + 0.6, 0.06, 3.0)
			mi.mesh = bx
			mi.material_override = terre
			add_child(mi)
			mi.global_transform = Transform3D(Basis.looking_at(Vector3(axe.x, 0, axe.y), Vector3.UP), Vector3(q.x, terrain.hauteur(q.x, q.y) + 0.03, q.y))


# ---------------------------------------------------------------------
# Le feu
# ---------------------------------------------------------------------
func _allumer(k: int, i: int, j: int, front: bool) -> void:
	var p: Dictionary = parcelles[k]
	var idx := j * NX + i
	p["etat"][idx] = 1
	p["t"][idx] = DUREE_FEU * randf_range(0.8, 1.2)
	p["front"][idx] = 1 if front else 0
	var c := _centre(p, i, j)
	feux[Vector3i(k, i, j)] = _flammes(c, 1.0 if front else 0.55)
	# les plants rougeoient
	var mm: MultiMeshInstance3D = p["mm"]
	if mm:
		for n in (p["inst"][idx] as Array):
			mm.multimesh.set_instance_color(n, Color(1.4, 0.55, 0.2))


func _flammes(c: Vector3, force: float) -> Node3D:
	var n := Node3D.new()
	add_child(n)
	n.global_position = c
	var fl := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.3, 2.8) * force
	q.material = mat_flamme
	fl.mesh = q
	fl.amount = int(16 * force) + 4
	fl.lifetime = 1.1
	fl.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	fl.emission_box_extents = Vector3(1.8, 0.3, 1.8)
	fl.direction = Vector3(vent.x * 0.5, 1, vent.y * 0.5)
	fl.spread = 15.0
	fl.initial_velocity_min = 1.8
	fl.initial_velocity_max = 3.8 * force
	fl.scale_amount_min = 0.6
	fl.scale_amount_max = 1.4
	fl.gravity = Vector3(vent.x * 1.5, 1.0, vent.y * 1.5)
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.9, 0.55, 0.95))
	grad.add_point(0.35, Color(1.0, 0.5, 0.1, 0.8))
	grad.set_color(2, Color(0.5, 0.08, 0.02, 0.0))
	fl.color_ramp = grad
	n.add_child(fl)
	var fu := CPUParticles3D.new()
	var q2 := QuadMesh.new()
	q2.size = Vector2(4.0, 4.0)
	q2.material = mat_fumee
	fu.mesh = q2
	fu.amount = 6
	fu.lifetime = 6.0
	fu.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fu.emission_sphere_radius = 1.5
	fu.direction = Vector3(0, 1, 0)
	fu.initial_velocity_min = 1.0
	fu.initial_velocity_max = 2.0
	fu.gravity = Vector3(vent.x * 2.5, 0.8, vent.y * 2.5)
	fu.scale_amount_min = 1.0
	fu.scale_amount_max = 2.5
	var g2 := Gradient.new()
	g2.set_color(0, Color(0.25, 0.23, 0.22, 0.55))
	g2.set_color(1, Color(0.4, 0.38, 0.36, 0.0))
	fu.color_ramp = g2
	fu.position.y = 2.0
	n.add_child(fu)
	var lum := OmniLight3D.new()
	lum.light_color = Color(1.0, 0.55, 0.2)
	lum.light_energy = 1.4 * force
	lum.omni_range = 9.0
	lum.position.y = 1.5
	n.add_child(lum)
	return n


func _tick_feu() -> void:
	var v3 := vent.normalized()
	for k in parcelles.size():
		var p: Dictionary = parcelles[k]
		var etat: Array = p["etat"]
		var t: Array = p["t"]
		var front: Array = p["front"]
		var a_allumer: Array = []
		var brule := 0
		for j in NY:
			for i in NX:
				var idx := j * NX + i
				if etat[idx] == 2:
					brule += 1
				if etat[idx] != 1:
					continue
				t[idx] -= 0.5
				# propagation vers les 8 voisines selon le vent
				for dj in range(-1, 2):
					for di in range(-1, 2):
						if di == 0 and dj == 0:
							continue
						var ni := i + di
						var nj := j + dj
						if ni < 0 or nj < 0 or ni >= NX or nj >= NY or etat[nj * NX + ni] != 0:
							continue
						var d: Vector2 = (p["dir"] * float(di) + p["n"] * float(dj)).normalized()
						var alignement := d.dot(v3)
						var proba := 0.015 + 0.2 * maxf(0.0, alignement) + 0.03 * (1.0 - absf(alignement))
						if randf() < proba:
							a_allumer.append([ni, nj, alignement > 0.35])
				# un feu de front qui atteint le bord côté village saute dans les herbes sèches
				if front[idx] == 1 and _au_bord_village(p, i, j) and not coupe_feu and not p.get("echappe", false) and randf() < 0.25:
					p["echappe"] = true
					_herbes_en_feu(_centre(p, i, j))
				if t[idx] <= 0.0:
					etat[idx] = 2
					_eteindre_case(k, i, j)
		for a in a_allumer:
			if etat[a[1] * NX + a[0]] == 0:
				_allumer(k, a[0], a[1], a[2])
		if not p["brulee"] and brule >= int(NX * NY * 0.8):
			p["brulee"] = true
			# le reste se consume
			for idx in NX * NY:
				if etat[idx] == 0:
					etat[idx] = 2
					_eteindre_case(k, idx % NX, idx / NX)
			m4._annoncer("Une parcelle du Cobra est réduite en cendres.", 2.5)


func _eteindre_case(k: int, i: int, j: int) -> void:
	var cle := Vector3i(k, i, j)
	if feux.has(cle):
		(feux[cle] as Node).queue_free()
		feux.erase(cle)
	var p: Dictionary = parcelles[k]
	# la terre noircie, posée sur la pente
	var c := _centre(p, i, j)
	var gx := terrain.hauteur(c.x + 2.0, c.z) - terrain.hauteur(c.x - 2.0, c.z)
	var gz := terrain.hauteur(c.x, c.z + 2.0) - terrain.hauteur(c.x, c.z - 2.0)
	var nor := Vector3(-gx / 4.0, 1.0, -gz / 4.0).normalized()
	var bx := nor.cross(Vector3.FORWARD).normalized()
	var b := Basis(bx, nor, bx.cross(nor))
	(p["cendre"] as MultiMesh).set_instance_transform(j * NX + i, Transform3D(b, c + nor * 0.035))
	var mm: MultiMeshInstance3D = p["mm"]
	if mm == null:
		return
	for n in (p["inst"][j * NX + i] as Array):
		var xf := mm.multimesh.get_instance_transform(n)
		mm.multimesh.set_instance_transform(n, Transform3D(xf.basis.scaled(Vector3(0.5, 0.25, 0.5)), xf.origin))
		mm.multimesh.set_instance_color(n, Color(0.07, 0.06, 0.055))


func _herbes_en_feu(depart: Vector3) -> void:
	for h in herbes:
		if not h["eteint"] and (h["pos"] as Vector3).distance_to(depart) < 15.0:
			return
	# il file vers la maison la plus proche
	var maisons: Array = bome.reperes["maisons"]
	var cible := -1
	var dmin := INF
	for i in maisons.size():
		var d := (maisons[i] as Vector3).distance_to(depart)
		if d < dmin and not maisons_feu.has(i):
			dmin = d
			cible = i
	if cible < 0:
		return
	var h := {"pos": depart, "cible": cible, "noeud": _flammes(depart, 0.8), "eteint": false, "eau": 0}
	herbes.append(h)
	m4._annoncer("Le feu saute dans les herbes sèches et descend vers une maison ! Éteignez-le (F, à plusieurs).", 4.0)


func _eteindre_herbes(h: Dictionary) -> void:
	h["eteint"] = true
	(h["noeud"] as Node).queue_free()
	m4._annoncer("Feu d'herbes éteint.", 2.0)


func _tick_herbes(delta: float) -> void:
	for h in herbes:
		if h["eteint"]:
			continue
		var cible: Vector3 = bome.reperes["maisons"][h["cible"]]
		var pos: Vector3 = h["pos"]
		var vers := cible - pos
		vers.y = 0
		if vers.length() < 6.0:
			_eteindre_herbes(h)
			_maison_en_feu(h["cible"])
			continue
		pos += vers.normalized() * 1.6 * delta
		pos.y = terrain.hauteur(pos.x, pos.z)
		h["pos"] = pos
		(h["noeud"] as Node3D).global_position = pos


func _maison_en_feu(i: int) -> void:
	var pos: Vector3 = bome.reperes["maisons"][i]
	maisons_feu[i] = {"t": 40.0, "noeud": _flammes(pos + Vector3(0, 3.0, 0), 1.6), "aide": false}
	m4._annoncer("Une maison brûle ! Courez éteindre le toit (F) avant qu'il ne soit trop tard.", 4.0)


func _tick_maisons(delta: float) -> void:
	for i in maisons_feu.keys():
		var mf: Dictionary = maisons_feu[i]
		if mf.get("fini", false):
			continue
		# les voisins aident dès que Faris a commencé : les seaux passent de main en main
		mf["t"] += delta * (-0.6 if mf["aide"] else 1.0)
		if mf["t"] <= 0.0:
			mf["fini"] = true
			(mf["noeud"] as Node).queue_free()
			m4._annoncer("Le feu de la maison est éteint. Les voisins s'en souviendront.", 3.0)
		elif mf["t"] >= 80.0:
			mf["fini"] = true
			(mf["noeud"] as Node).queue_free()
			maisons_perdues += 1
			m4.confiance = clampi(m4.confiance - 15, 0, 100)
			m4._annoncer("Une maison de Bomé a brûlé.\nBAYA EFUA — « Voilà ce qu'ils diront de toi, maintenant. »", 6.0)


func _process(delta: float) -> void:
	if joueur == null:
		return
	if revenu > 0:
		t_revenu += delta
		if t_revenu >= SEMAINE:
			t_revenu = 0.0
			argent += revenu
			m4._annoncer("Coopérative de Bomé : +%d ZLM pour la résistance." % revenu, 3.0)
	if revenu > 0 and t_revenu < 0.0:
		etiquette.text = "Racines : %d ZLM · 1re récolte dans %d sem." % [argent, int(ceil(-t_revenu / SEMAINE))]
	else:
		etiquette.text = ("Racines : %d ZLM" % argent) if revenu > 0 or argent > 0 else ""
	match phase:
		Phase.INDISPONIBLE:
			if m5 and m5.phase == Mission5.Phase.TERMINEE:
				phase = Phase.DISPONIBLE
				var ca: Node = main.get_node_or_null("Carte")
				if ca:
					ca.poser_balise(bome.reperes["place"])
		Phase.DISPONIBLE:
			if joueur.global_position.distance_to(bome.reperes["place"]) < 170.0:
				demarrer()
		Phase.OBSERVER:
			var mv: Vector3 = bome.reperes["manche_a_air"]
			if joueur.global_position.distance_to(mv) < 25.0:
				phase = Phase.FEU
				_dire("BAYA EFUA (radio)", "Tu vois la manche à air ? Le vent descend vers nos maisons. Allume chaque parcelle par le bord qui regarde le village : le feu remontera contre le vent, doucement. Ou fais d'abord creuser un coupe-feu par les cultivateurs.", 0.2)
				m4._objectif("Brûlez les 3 parcelles du Cobra (F dans une parcelle) sans brûler le village. Coupe-feu : F au repère, au-dessus des maisons.")
				var ca: Node = main.get_node_or_null("Carte")
				if ca:
					ca.poser_balise(repere_coupe)
		Phase.FEU:
			_en_feu(delta)


func _en_feu(delta: float) -> void:
	t_tick += delta
	if t_tick >= 0.5:
		t_tick -= 0.5
		_tick_feu()
	_tick_herbes(delta)
	_tick_maisons(delta)
	if t_coupe > 0.0:
		t_coupe -= delta
		if t_coupe <= 0.0:
			_coupe_feu_fini()
	# la fumée cache Faris
	var jp := joueur.global_position
	var dans_fumee := false
	for c in feux:
		if (feux[c] as Node3D).global_position.distance_to(jp) < 14.0:
			dans_fumee = true
			break
	for g in gardes:
		(g as Pnj).portee_vue = 10.0 if dans_fumee else 38.0
	# victoire : parcelles brûlées, Cobra chassé, plus de feu dans le village
	var toutes := true
	for p in parcelles:
		toutes = toutes and p["brulee"]
	var actifs := 0
	for g in gardes:
		if (g as Pnj).est_actif():
			actifs += 1
	var incendie := false
	for h in herbes:
		incendie = incendie or not h["eteint"]
	for i in maisons_feu:
		incendie = incendie or not maisons_feu[i].get("fini", false)
	if toutes and actifs == 0 and not incendie:
		phase = Phase.COOPERATIVE
		for c in feux.keys():
			(feux[c] as Node).queue_free()
		feux.clear()
		m4._annoncer("Les miliciens ont fui Bomé. Les familles se rassemblent sous l'arbre à palabres.", 4.0)
		await get_tree().create_timer(3.0).timeout
		m4._annoncer("", 0.0)
		panneau.visible = true
		_bilan()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif toutes and actifs > 0 and not m4.objectif.text.contains("contremaîtres"):
		m4._objectif("Les parcelles sont en cendres : chassez les derniers contremaîtres du Cobra (%d)." % actifs)

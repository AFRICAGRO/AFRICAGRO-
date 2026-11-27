## Mission 11 — « Le Serpent » (voir jeu/missions/11-LE-SERPENT.md). La fin de l'acte 1 sur l'île.
## - La table de planification, dans l'arrière-salle du maquis de Mama Rokia : l'approche, le rôle
##   d'Ama, de Kwame, de la Dr Nadia, et l'appel de Radio Racines. Le nombre de villageois volontaires
##   dépend de la jauge de confiance.
## - Le camp du Cobra : une ancienne mission catholique fortifiée sur une terrasse au-dessus de la mer
##   (chapelle, clocher, dortoirs, cour, cellules), prise de nuit, dans l'ordre qu'on veut :
##   la cour et les dortoirs, les cellules (Yaw et les prisonniers), le clocher puis la chapelle.
## - Les choix passés pèsent : Dossou (relâché : il fait défection ; prisonnier : il a été libéré par
##   le Cobra et se bat contre Faris), les garçons de Tikané, la confiance.
## - Le Commandant Mamba : sa canne cache une lame. Puis le choix : l'arrêter ou l'éliminer.
## L'édifice religieux est respecté par les Racines : la profanation par la milice se voit (caisses de
## munitions sur les bancs, peinture sur les murs), mais on n'y fait aucun dégât gratuit.
class_name Mission11
extends Node3D

enum Phase { INDISPONIBLE, DISPONIBLE, TABLE, ASSAUT, MAMBA, CHOIX, TERMINEE }
const CENTRE := Vector2(775, 1540)      # le camp, sur la terrasse au-dessus de la plage
const PLAGE := Vector2(868, 1575)

var phase := Phase.INDISPONIBLE
var main: Node
var joueur: Joueur
var m4: Mission4
var terrain: Terrain
var sol := 0.0                 # hauteur de la terrasse aplanie
var camp: Node3D
var plan := {"approche": "mixte", "ama": "plage", "kwame": "generateur", "nadia": "soins", "radio": "secret"}
var cour: Array = []
var gardes_cellules: Array = []
var tireur_clocher: Pnj
var gardes_corps: Array = []
var mamba: Pnj
var dossou: Pnj
var dossou_fait := false
var allies: Array = []
var prisonniers: Array = []
var yaw: Pnj
var cellules_ouvertes := false
var t_crochetage := -1.0
var porte_chapelle: StaticBody3D
var grille_cellules: StaticBody3D
var yaw_dans_chapelle := false
var chapelle_ouverte := false
var coffre_ouvert := false
var projecteurs: Array = []
var pickup: Node3D
var pickup_tireur: Node3D
var pickup_pv := 3
var t_pickup := 2.5
var pickup_piege := false
var tirs_ama := 0
var t_ama := 10.0
var t_allies := 0.0
var discours_fait := false
var choix := ""
var t_reprise := 0.0
var t_hud := 0.0
var depart := Vector3.ZERO
var table_ui: PanelContainer
var choix_ui: PanelContainer
var resume_table: Label
var voile: ColorRect


# ---------------------------------------------------------------------
# Plan : la terrasse du camp aplanie
# ---------------------------------------------------------------------
static func preparer_plan() -> Dictionary:
	var d := Terrain.lire_donnees()
	var h := Terrain.hauteur_brute(d, CENTRE.x, CENTRE.y)
	return {"plateformes": [{"centre": CENTRE, "rayon": 62.0, "h": h}], "sol": h}


func _l(x: float, z: float, y := 0.0) -> Vector3:
	return Vector3(CENTRE.x + x, sol + y, CENTRE.y + z)


func construire(p_main: Node, p_sol: float) -> void:
	main = p_main
	joueur = main.joueur
	m4 = main.get_node("Mission4")
	terrain = main.terrain
	sol = p_sol
	_camp()
	_interface()
	joueur.tombe.connect(_tombe)
	joueur.impact.connect(_impact)
	joueur.a_tire.connect(func(p: Vector3) -> void:
		if phase == Phase.ASSAUT or phase == Phase.MAMBA:
			bruit_de_tir(p))


# ---------------------------------------------------------------------
# Le camp : ancienne mission catholique fortifiée
# ---------------------------------------------------------------------
func _boite(taille: Vector3, centre: Vector3, couleur: Color, solide := true, rugosite := 0.9, rot_y := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = taille
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = couleur
	m.roughness = rugosite
	mi.material_override = m
	camp.add_child(mi)
	mi.global_transform = Transform3D(Basis(Vector3.UP, rot_y), centre)
	if solide:
		var sb := StaticBody3D.new()
		sb.collision_layer = 1
		sb.collision_mask = 0
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = taille
		cs.shape = bs
		sb.add_child(cs)
		camp.add_child(sb)
		sb.global_transform = mi.global_transform
	return mi


func _texte(t: String, p: Vector3, rot_y: float, couleur: Color, taille := 64, pix := 0.01) -> void:
	var l := Label3D.new()
	l.text = t
	l.font_size = taille
	l.pixel_size = pix
	l.modulate = couleur
	l.outline_size = 0
	camp.add_child(l)
	l.global_transform = Transform3D(Basis(Vector3.UP, rot_y), p)


func _camp() -> void:
	camp = Node3D.new()
	add_child(camp)
	var chaux := Color(0.86, 0.8, 0.68)       # murs chaulés, jaunis par les années
	var brique := Color(0.62, 0.36, 0.24)
	var tole := Color(0.5, 0.42, 0.36)
	var sac := Color(0.62, 0.55, 0.4)
	# enceinte : 90 x 80 m, porte à l'ouest (côté piste), brèche à l'est (côté falaise)
	for z0 in [[-40.0, -4.0], [4.0, 40.0]]:
		var l: float = z0[1] - z0[0]
		_boite(Vector3(0.8, 3.2, l), _l(-45, (z0[0] + z0[1]) * 0.5, 1.6), chaux * 0.92)
	for z0 in [[-40.0, 22.0], [27.0, 40.0]]:
		var l: float = z0[1] - z0[0]
		_boite(Vector3(0.8, 3.2, l), _l(45, (z0[0] + z0[1]) * 0.5, 1.6), chaux * 0.92)
	_boite(Vector3(90.8, 3.2, 0.8), _l(0, -40, 1.6), chaux * 0.92)
	_boite(Vector3(90.8, 3.2, 0.8), _l(0, 40, 1.6), chaux * 0.92)
	# tôles et barbelés ajoutés par la milice sur le mur
	for x in range(-44, 46, 6):
		_boite(Vector3(5.6, 0.9, 0.06), _l(x, -40.45, 3.6), tole, false, 0.6)
		_boite(Vector3(5.6, 0.9, 0.06), _l(x, 40.45, 3.6), tole, false, 0.6)
	# la porte : deux piliers, un portail de tôle ouvert, des sacs de sable
	_boite(Vector3(1.4, 4.2, 1.4), _l(-45, -4.7, 2.1), brique)
	_boite(Vector3(1.4, 4.2, 1.4), _l(-45, 4.7, 2.1), brique)
	_boite(Vector3(0.1, 2.8, 4.0), _l(-44, -6.6, 1.4), tole, false, 0.6, 1.2)
	for i in 5:
		_boite(Vector3(1.0, 0.45, 0.6), _l(-38, -7.0 + i * 1.0, 0.25 + (i % 2) * 0.0), sac)
		_boite(Vector3(1.0, 0.45, 0.6), _l(-38, -7.0 + i * 1.0, 0.7), sac)
	# dortoirs (anciennes salles de classe de la mission) : murs chaulés, toit de tôle
	for d in [Vector3(-12, 0, -30), Vector3(-16, 0, 29)]:
		var lg := 26.0 if d.z < 0.0 else 20.0
		_boite(Vector3(lg, 3.4, 8.0), _l(d.x, d.z, 1.7), chaux)
		_boite(Vector3(lg + 1.0, 0.1, 9.0), _l(d.x, d.z, 3.6), tole, false, 0.6)
		for k in int(lg / 4.0):
			_boite(Vector3(1.0, 1.2, 0.05), _l(d.x - lg * 0.5 + 2.0 + k * 4.0, d.z + (4.03 if d.z < 0.0 else -4.03), 1.9), Color(0.12, 0.1, 0.08), false)
	# cellules : bloc bas au sud-est, creux, trois portes à barreaux vers la cour
	_boite(Vector3(16.0, 2.8, 0.4), _l(26, 33.8, 1.4), chaux * 0.8)
	_boite(Vector3(0.4, 2.8, 6.0), _l(18, 31, 1.4), chaux * 0.8)
	_boite(Vector3(0.4, 2.8, 6.0), _l(34, 31, 1.4), chaux * 0.8)
	_boite(Vector3(16.4, 0.2, 6.4), _l(26, 31, 2.9), tole, false, 0.6)
	for k in 4:
		_boite(Vector3(1.8, 2.8, 0.3), _l(18.9 + k * 4.75, 28.1, 1.4), chaux * 0.8, false)
	for k in 3:
		for b in 6:
			_boite(Vector3(0.05, 2.1, 0.05), _l(20.2 + k * 4.75 + b * 0.36, 28.05, 1.05), Color(0.2, 0.2, 0.22), false, 0.4)
	grille_cellules = StaticBody3D.new()
	var cg := CollisionShape3D.new()
	var bg := BoxShape3D.new()
	bg.size = Vector3(16.0, 2.8, 0.3)
	cg.shape = bg
	grille_cellules.add_child(cg)
	camp.add_child(grille_cellules)
	grille_cellules.global_position = _l(26, 28.1, 1.4)
	# la chapelle : nef de 24 m, façade à l'ouest, croix de bois au pignon
	var cx := 28.0
	_boite(Vector3(24.0, 0.3, 12.0), _l(cx, -8, 0.15), Color(0.5, 0.45, 0.4), true)          # dallage
	_boite(Vector3(24.0, 6.0, 0.6), _l(cx, -14, 3.0), chaux)
	_boite(Vector3(24.0, 6.0, 0.6), _l(cx, -2, 3.0), chaux)
	_boite(Vector3(0.6, 6.0, 12.6), _l(cx + 12, -8, 3.0), chaux)
	_boite(Vector3(0.6, 6.0, 4.6), _l(cx - 12, -12.0, 3.0), chaux)                          # façade, porte au milieu
	_boite(Vector3(0.6, 6.0, 4.6), _l(cx - 12, -4.0, 3.0), chaux)
	_boite(Vector3(0.6, 2.2, 3.4), _l(cx - 12, -8.0, 4.9), chaux)
	for s in [-1.0, 1.0]:
		_boite(Vector3(25.0, 0.12, 7.4), _l(cx, -8 + s * 3.2, 7.3), brique * 0.8, false, 0.8).rotation.x = s * 0.5
	# pignons triangulaires aux deux bouts de la nef
	for gx in [cx - 12.0, cx + 12.0]:
		var pg := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(12.6, 3.1, 0.6)
		pg.mesh = pm
		var mp := StandardMaterial3D.new()
		mp.albedo_color = chaux
		mp.roughness = 0.9
		pg.material_override = mp
		camp.add_child(pg)
		pg.global_transform = Transform3D(Basis(Vector3.UP, PI * 0.5), _l(gx, -8, 7.55))
	_boite(Vector3(0.18, 2.2, 0.18), _l(cx - 12.5, -8, 9.9), Color(0.4, 0.28, 0.18), false)   # croix
	_boite(Vector3(0.18, 0.18, 1.2), _l(cx - 12.5, -8, 10.4), Color(0.4, 0.28, 0.18), false)
	_texte("FRONT\nDU COBRA", _l(cx - 12.35, -12.0, 3.2), -PI * 0.5, Color(0.72, 0.1, 0.08), 128, 0.012)   # peinture de la milice
	# porte de la chapelle : fermée tant que le tireur du clocher tient la cour
	porte_chapelle = StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.3, 3.0, 3.4)
	cs.shape = bs
	porte_chapelle.add_child(cs)
	camp.add_child(porte_chapelle)
	porte_chapelle.global_position = _l(cx - 12, -8, 1.5)
	var vantail := MeshInstance3D.new()
	var bv := BoxMesh.new()
	bv.size = Vector3(0.15, 3.0, 3.4)
	vantail.mesh = bv
	var mv := StandardMaterial3D.new()
	mv.albedo_color = Color(0.35, 0.22, 0.14)
	vantail.material_override = mv
	porte_chapelle.add_child(vantail)
	# intérieur : bancs (des caisses de munitions dessus), autel, banc du prêtre, le coffre
	for k in 6:
		for s in [-1.0, 1.0]:
			_boite(Vector3(0.5, 0.5, 4.0), _l(cx - 8 + k * 2.2, -8 + s * 3.0, 0.55), Color(0.4, 0.28, 0.18), false)
		if k % 2 == 0:
			_boite(Vector3(0.6, 0.35, 0.8), _l(cx - 8 + k * 2.2, -5.4, 0.98), Color(0.3, 0.34, 0.22), false)
	_boite(Vector3(1.4, 1.0, 3.0), _l(cx + 10, -8, 0.8), Color(0.75, 0.72, 0.66))              # autel
	_boite(Vector3(0.7, 0.5, 2.0), _l(cx + 7.5, -12.2, 0.55), Color(0.4, 0.28, 0.18), false)   # banc du prêtre
	_boite(Vector3(0.9, 0.8, 0.7), _l(cx + 10.5, -3.4, 0.7), Color(0.25, 0.27, 0.3), true, 0.4)  # coffre de Mamba
	var lampe := OmniLight3D.new()
	lampe.light_color = Color(1.0, 0.65, 0.35)
	lampe.light_energy = 1.4
	lampe.omni_range = 14.0
	camp.add_child(lampe)
	lampe.global_position = _l(cx + 6, -8, 3.5)
	# le clocher, accolé à la façade : le tireur d'élite y tient la cour
	_boite(Vector3(4.0, 15.0, 4.0), _l(cx - 10, -17, 7.5), chaux * 0.95)
	_boite(Vector3(4.6, 0.3, 4.6), _l(cx - 10, -17, 15.15), brique)
	for s in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		_boite(Vector3(0.4, 2.6, 0.4), _l(cx - 10 + s.x * 2.1, -17 + s.y * 2.1, 16.6), chaux * 0.95, false)
	_boite(Vector3(5.0, 0.3, 5.0), _l(cx - 10, -17, 18.0), brique * 0.8, false)
	_boite(Vector3(1.0, 1.0, 1.0), _l(cx - 10, -17, 17.0), Color(0.42, 0.36, 0.2), false, 0.3)   # la cloche
	# groupe électrogène et projecteurs aux angles
	_boite(Vector3(2.4, 1.6, 1.4), _l(-30, 10, 0.8), Color(0.28, 0.36, 0.3), true, 0.5)
	for c in [Vector2(-42, -37), Vector2(42, -37), Vector2(-42, 37), Vector2(42, 37)]:
		_boite(Vector3(0.25, 7.0, 0.25), _l(c.x, c.y, 3.5), Color(0.3, 0.3, 0.3), false)
		var sp := SpotLight3D.new()
		sp.light_color = Color(1.0, 0.96, 0.85)
		sp.light_energy = 0.0
		sp.spot_range = 70.0
		sp.spot_angle = 38.0
		camp.add_child(sp)
		sp.global_position = _l(c.x, c.y, 7.0)
		sp.look_at(_l(0, 0, 0))
		projecteurs.append(sp)
	# le pick-up armé de Mamba, dans la cour
	pickup = (load("res://vehicules/pickup.glb") as PackedScene).instantiate()
	camp.add_child(pickup)
	pickup.global_transform = Transform3D(Basis(Vector3.UP, PI * 0.5), _l(-26, -8, 0.05))
	var corps_pk := StaticBody3D.new()
	var cs2 := CollisionShape3D.new()
	var bs2 := BoxShape3D.new()
	bs2.size = Vector3(2.0, 1.8, 5.0)
	cs2.shape = bs2
	cs2.position.y = 0.9
	corps_pk.add_child(cs2)
	pickup.add_child(corps_pk)
	var cible_t := StaticBody3D.new()
	cible_t.set_meta("tireur_pickup", true)
	var cs3 := CollisionShape3D.new()
	var bs3 := BoxShape3D.new()
	bs3.size = Vector3(0.7, 1.0, 0.7)
	cs3.shape = bs3
	cible_t.add_child(cs3)
	pickup.add_child(cible_t)
	cible_t.position = Vector3(0, 2.4, -1.6)


func _interface() -> void:
	var calque := CanvasLayer.new()
	calque.layer = 7
	add_child(calque)
	voile = ColorRect.new()
	voile.color = Color(0, 0, 0, 0)
	voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	calque.add_child(voile)
	table_ui = _panneau(calque, Vector2(760, 0))
	var col := table_ui.get_child(0) as VBoxContainer
	var titre := Label.new()
	titre.text = "LA TABLE DE PLANIFICATION — arrière-salle du maquis de Mama Rokia\nUne carte du camp du Cobra est étalée sous la lampe."
	titre.add_theme_font_size_override("font_size", 18)
	titre.add_theme_color_override("font_color", Color(1.0, 0.82, 0.5))
	col.add_child(titre)
	var decisions := [
		["approche", "Approche principale", [["discrete", "Discrète : par la mer et la falaise, la brèche du mur est"], ["frontale", "Frontale : par la porte, avec les villageois"], ["mixte", "Mixte : la porte avec les villageois, Ama par la mer"]]],
		["ama", "Rôle d'Ama", [["debarquer", "Débarquer des combattants par la mer"], ["plage", "Tenir la plage avec son fusil (tir de soutien)"], ["evasion", "Faire évader les prisonniers"]]],
		["kwame", "Rôle de Kwame", [["generateur", "Couper le groupe électrogène (projecteurs éteints)"], ["pickup", "Piéger le pick-up armé de Mamba"], ["radio", "Rester à la radio avec Joël (renseignements)"]]],
		["nadia", "Rôle de la Dr Nadia", [["soins", "Poste de soins près du camp (Faris guérit plus vite)"], ["prisonniers", "Accompagner les prisonniers libérés"]]],
		["radio", "Radio Racines", [["secret", "Garder le secret"], ["soulevement", "Appeler les villages à se soulever (plus de combattants, plus de risques pour eux)"]]],
	]
	for d in decisions:
		var ligne := HBoxContainer.new()
		var nom := Label.new()
		nom.text = d[1]
		nom.custom_minimum_size = Vector2(190, 0)
		ligne.add_child(nom)
		var ob := OptionButton.new()
		ob.custom_minimum_size = Vector2(530, 0)
		for k in (d[2] as Array).size():
			ob.add_item(d[2][k][1], k)
			if d[2][k][0] == plan[d[0]]:
				ob.select(k)
		ob.item_selected.connect(func(i: int) -> void:
			plan[d[0]] = d[2][i][0]
			_maj_resume())
		ligne.add_child(ob)
		col.add_child(ligne)
	resume_table = Label.new()
	resume_table.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resume_table.custom_minimum_size = Vector2(720, 0)
	resume_table.add_theme_color_override("font_color", Color(0.75, 0.95, 0.8))
	col.add_child(resume_table)
	var go := Button.new()
	go.text = "Lancer l'assaut, cette nuit"
	go.pressed.connect(_lancer)
	col.add_child(go)
	choix_ui = _panneau(calque, Vector2(680, 0))
	var c2 := choix_ui.get_child(0) as VBoxContainer
	var t := Label.new()
	t.text = "Mamba est à genoux. Dehors, l'aube se lève."
	t.add_theme_font_size_override("font_size", 19)
	t.add_theme_color_override("font_color", Color(1.0, 0.8, 0.45))
	c2.add_child(t)
	for c in [["L'arrêter", "Il sera jugé par un tribunal du peuple « quand le pays sera libre ». Il pourra témoigner contre le régime… et tentera de s'évader.", "arreter"],
			["L'éliminer", "Les villageois l'acclameront. La Dr Nadia quittera la chapelle sans un mot.", "eliminer"]]:
		var b := Button.new()
		b.text = "%s — %s" % [c[0], c[1]]
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(640, 0)
		b.pressed.connect(_choisir.bind(c[2]))
		c2.add_child(b)


func _panneau(calque: CanvasLayer, taille: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	var fond := StyleBoxFlat.new()
	fond.bg_color = Color(0.07, 0.06, 0.05, 0.95)
	fond.border_color = Color(0.85, 0.6, 0.3)
	fond.set_border_width_all(2)
	fond.set_corner_radius_all(6)
	fond.set_content_margin_all(18)
	p.add_theme_stylebox_override("panel", fond)
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.position = Vector2(-taille.x * 0.5, -110)   # sous la ligne de dialogue, qui reste lisible
	p.custom_minimum_size = taille
	p.visible = false
	calque.add_child(p)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 9)
	p.add_child(col)
	return p


func _volontaires() -> int:
	if plan["approche"] == "discrete":
		return 0
	var n := clampi(int(m4.confiance / 12.0), 2, 8)
	if plan["radio"] == "soulevement":
		n += 4
	return n


func _maj_resume() -> void:
	var t := "Villageois volontaires : %d (confiance %d)." % [_volontaires(), m4.confiance]
	if plan["ama"] == "debarquer":
		t += " Ama débarquera 3 combattants sur la plage."
	if plan["radio"] == "soulevement":
		t += " Radio Racines appellera les villages : ils viendront, mais certains le paieront."
	var sd := _sort_dossou()
	if sd == "relache":
		t += "\nJOËL — « Dossou, celui que tu as laissé partir à Akwéri, est au camp. Il paraît qu'il doute. »"
	elif sd == "prisonnier":
		t += "\nJOËL — « Le Cobra a fait libérer Dossou de la cave d'Akwéri. Il voudra sa revanche. »"
	if main.has_meta("garcons_au_camp"):
		t += "\nAMA — « Les quatre garçons de Tikané sont dans les cellules. Ils ont réussi à faire passer un message : ils nous ouvriront de l'intérieur. »"
	resume_table.text = t


func _sort_dossou() -> String:
	if m4.sort_dossou != "":
		return m4.sort_dossou
	if m4.dossou and m4.dossou.etat == Pnj.Etat.LIGOTE:
		return "prisonnier"
	return "relache"


func etat_texte() -> String:
	return ["à venir", "disponible", "la planification", "l'assaut", "le Commandant", "le choix", "le Front du Cobra est tombé"][phase]


# ---------------------------------------------------------------------
# Déroulement
# ---------------------------------------------------------------------
func _process(delta: float) -> void:
	if joueur == null:
		return
	match phase:
		Phase.INDISPONIBLE:
			var m10: Node = main.get_node_or_null("Mission10")
			if m10 and m10.phase == Mission10.Phase.TERMINEE:
				_appel()
		Phase.DISPONIBLE:
			var mq: Vector3 = main.ville.reperes["maquis"]
			if joueur.global_position.distance_to(mq) < 5.0:
				_table()
		Phase.ASSAUT, Phase.MAMBA:
			_assaut(delta)
	if t_reprise > 0.0:
		t_reprise -= delta
		if t_reprise <= 0.0:
			_reprendre()


func _appel() -> void:
	phase = Phase.DISPONIBLE
	var tel: Node = main.get_node_or_null("Telephone")
	if tel:
		tel.notifier("Ama : « Ce soir, chez Mama Rokia. L'arrière-salle. On prépare le camp. »")
	m4._annoncer("AMA (radio) — « Ce soir, chez Mama Rokia. L'arrière-salle. On a tout ce qu'il faut. Il est temps d'aller chercher le serpent dans son trou. »", 7.0)
	m4._objectif("Mission 11 — Le Serpent : retrouvez les Racines dans l'arrière-salle du maquis de Mama Rokia, à Port-Néré.")
	var ca: Node = main.get_node_or_null("Carte")
	if ca:
		ca.poser_balise(main.ville.reperes["maquis"])


func _table() -> void:
	phase = Phase.TABLE
	_maj_resume()
	table_ui.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	m4._annoncer("Kwame a déroulé la carte. Joël a branché la radio. La Dr Nadia a apporté sa trousse. Mama Rokia ferme la porte.", 5.0)


func _lancer() -> void:
	table_ui.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var tw := create_tween()
	tw.tween_property(voile, "color:a", 1.0, 0.8)
	tw.tween_callback(_installer)
	tw.tween_interval(1.2)
	tw.tween_property(voile, "color:a", 0.0, 1.2)


func _installer() -> void:
	phase = Phase.ASSAUT
	joueur.mission = self
	var amb: Ambiances = main.ambiances
	var garde := 0
	while amb.index != 3 and garde < 8:
		amb.suivante()
		garde += 1
	_ennemis()
	_prisonniers()
	# point de départ selon l'approche
	if plan["approche"] == "discrete":
		depart = Vector3(PLAGE.x, terrain.hauteur(PLAGE.x, PLAGE.y) + 0.6, PLAGE.y)
	else:
		depart = _l(-95, 0, 0.6)
		depart.y = terrain.hauteur(depart.x, depart.z) + 0.6
	joueur.ressusciter(depart)
	joueur.donner_arme()
	joueur.reserve = maxi(joueur.reserve, 120)
	# alliés
	var n := _volontaires()
	for i in n:
		var a := _pnj("allie", depart + Vector3(-2.0 - (i % 4) * 1.6, 0, -3.0 + floorf(i / 4.0) * 1.8), ["villageois", "homme2", "homme3"][i % 3], Color(randf_range(0.7, 1.2), randf_range(0.7, 1.1), randf_range(0.6, 1.0)))
		allies.append(a)
	if plan["ama"] == "debarquer":
		for i in 3:
			var p := Vector3(PLAGE.x - 6.0, 0, PLAGE.y + i * 2.0)
			p.y = terrain.hauteur(p.x, p.z) + 0.4
			allies.append(_pnj("allie", p, "homme2", Color(0.9, 0.9, 1.0)))
	# Kwame
	match plan["kwame"]:
		"generateur":
			m4._annoncer("KWAME (radio) — « Le groupe électrogène tousse… et se tait. À vous, l'obscurité. »", 5.0)
			for g in cour + gardes_cellules:
				(g as Pnj).portee_vue *= 0.6
		"pickup":
			pickup_piege = true
		_:
			for sp in projecteurs:
				(sp as SpotLight3D).light_energy = 6.0
	if plan["kwame"] == "pickup":
		for sp in projecteurs:
			(sp as SpotLight3D).light_energy = 6.0
	if plan["nadia"] == "soins":
		joueur.set_meta("soins_nadia", true)
	if plan["approche"] != "discrete":
		m4._annoncer("Mission 11 — Le Serpent\nLa porte du camp, de nuit. Derrière Faris, les villageois serrent leurs fusils de chasse.", 6.0)
	else:
		m4._annoncer("Mission 11 — Le Serpent\nLa pirogue d'Ama glisse sur la plage. Au-dessus, la falaise, et la brèche du mur est.", 6.0)
	var ca: Node = main.get_node_or_null("Carte")
	if ca:
		ca.poser_balise(_l(0, 0))


func _pnj(role: String, p: Vector3, modele: String, teinte: Color, texture := "") -> Pnj:
	var n := Pnj.new()
	add_child(n)
	n.global_position = p + Vector3(0, 0.3, 0)
	n.preparer(role, self, joueur, teinte, texture, modele)
	n.refuges = [p]
	n.points_patrouille = [p]
	n.neutralise.connect(_neutralise)
	return n


func _ennemis() -> void:
	var camo := "res://data/textures/camouflage.jpg"
	var modeles := ["homme2", "villageois", "homme3", "faris"]
	# la cour et les dortoirs : 16 miliciens
	var postes := [Vector2(-36, -2), Vector2(-36, 6), Vector2(-28, -18), Vector2(-20, -22), Vector2(-4, -22), Vector2(6, -24),
		Vector2(-30, 18), Vector2(-20, 20), Vector2(-6, 18), Vector2(4, 22), Vector2(-12, -4), Vector2(-2, 4), Vector2(8, -2),
		Vector2(10, 10), Vector2(-24, 2), Vector2(0, -12)]
	for i in postes.size():
		var q: Vector2 = postes[i]
		var g := _pnj("milicien", _l(q.x, q.y), modeles[i % 4], Color(1, 1, 1), camo)
		g.points_patrouille = [_l(q.x, q.y), _l(q.x + (6.0 if i % 2 == 0 else -6.0), q.y + (4.0 if i % 3 == 0 else -3.0))]
		g.portee_vue = 32.0
		g.alerte.connect(_alerte_cour)
		g.rendu.connect(func(_n: Pnj) -> void: m4._annoncer("Le milicien se rend : F pour le ligoter.", 2.5))
		cour.append(g)
	# les cellules : 3 gardes
	for q in [Vector2(20, 24), Vector2(30, 23), Vector2(36, 26)]:
		var g := _pnj("milicien", _l(q.x, q.y), "homme2", Color(1, 1, 1), camo)
		g.portee_vue = 26.0
		g.alerte.connect(_alerte_cour)
		gardes_cellules.append(g)
	# le tireur d'élite du clocher
	tireur_clocher = _pnj("milicien", _l(18, -17, 15.4), "homme3", Color(0.8, 0.8, 0.8), camo)
	tireur_clocher.portee_vue = 75.0
	tireur_clocher.pv = 60.0
	# la chapelle : Mamba et ses deux gardes du corps
	for q in [Vector2(32, -11), Vector2(32, -5)]:
		var g := _pnj("milicien", _l(q.x, q.y, 0.3), "homme3", Color(0.4, 0.4, 0.42))
		g.pv = 160.0
		g.portee_vue = 18.0
		gardes_corps.append(g)
	mamba = _pnj("mamba", _l(35.5, -12.2, 0.4), "ancien", Color(0.45, 0.5, 0.32))    # veste militaire olive
	mamba.pv = 240.0
	mamba.portee_vue = 14.0
	if mamba.arme:
		mamba.arme.queue_free()
		mamba.arme = null
	mamba.etat = Pnj.Etat.DESARME        # assis, immobile, jusqu'à son discours
	mamba.anim.play("Assis", 0.3)
	# Dossou, selon ce que Faris a fait de lui à Akwéri
	var sd := _sort_dossou()
	if sd == "prisonnier":
		dossou = _pnj("dossou", _l(-8, 6), "villageois", Color(0.3, 0.3, 0.28), camo)
		dossou.pv = 140.0
		dossou.portee_vue = 34.0
		dossou.alerte.connect(_alerte_cour)
		dossou.rendu.connect(func(_n: Pnj) -> void: m4._annoncer("Dossou tombe à genoux. « Encore toi… » F pour le ligoter : Faris peut encore l'épargner.", 4.0))


func _prisonniers() -> void:
	# Yaw, le frère d'Ama, et d'autres prisonniers ; les jeunes recrues du camp sont enfermées avec eux
	var modeles := ["faris", "homme2", "femme", "ancien", "garcon", "garcon"]
	if main.has_meta("garcons_au_camp"):
		modeles.append_array(["garcon", "garcon"])
	for i in modeles.size():
		var p := _l(19.5 + (i % 3) * 5.5, 31.0 + floorf(i / 3.0) * 0.8)
		var o := _pnj("civil", p, modeles[i], Color(0.8, 0.75, 0.68))
		o.etat = Pnj.Etat.CACHE
		prisonniers.append(o)
	yaw = prisonniers[0]


func _alerte_cour(_q: Vector3) -> void:
	for g in cour + gardes_cellules:
		var p := g as Pnj
		if p.est_actif() and p.global_position.distance_to(_q) < 45.0:
			p._passer_combat()
	if dossou and dossou.est_actif():
		dossou._passer_combat()
	if pickup_piege:
		pickup_piege = false
		_explosion_pickup()


func _explosion_pickup() -> void:
	pickup_pv = 0
	var feu := CPUParticles3D.new()
	feu.amount = 70
	feu.lifetime = 2.5
	feu.direction = Vector3.UP
	feu.spread = 25.0
	feu.initial_velocity_min = 2.0
	feu.initial_velocity_max = 5.0
	feu.scale_amount_min = 1.0
	feu.scale_amount_max = 2.5
	var q := QuadMesh.new()
	q.size = Vector2(1.4, 1.4)
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://data/textures/fumee_douce.png")
	m.albedo_color = Color(0.15, 0.13, 0.12, 0.7)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	q.material = m
	feu.mesh = q
	pickup.add_child(feu)
	feu.position = Vector3(0, 1.5, 0)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.5, 0.2)
	l.light_energy = 4.0
	l.omni_range = 14.0
	pickup.add_child(l)
	l.position = Vector3(0, 2.0, 0)
	var s := AudioStreamPlayer3D.new()
	s.stream = load("res://sons/tonnerre.wav")
	s.unit_size = 30.0
	pickup.add_child(s)
	s.play()
	m4._annoncer("KWAME (radio) — « Boum. » Le pick-up de Mamba s'embrase au milieu de la cour.", 4.0)


func _mettre_objectif() -> void:
	var nc := _actifs(cour)
	var ng := _actifs(gardes_cellules)
	var t := ""
	t += "La cour et les dortoirs : %s\n" % ("prise ✓" if nc == 0 else "%d miliciens" % nc if plan["kwame"] == "radio" else "tenue par la milice")
	t += "Les cellules : %s\n" % ("ouvertes ✓" if cellules_ouvertes else ("F à la porte pour crocheter" if ng == 0 else "gardées"))
	t += "Le clocher : %s · La chapelle : %s" % ["le tireur est tombé ✓" if not tireur_clocher.est_actif() else "un tireur d'élite", "ouverte" if chapelle_ouverte else "fermée"]
	if phase == Phase.MAMBA:
		t = "Le Commandant Mamba. Désarmez-le."
	m4._objectif(t)


func _actifs(liste: Array) -> int:
	var n := 0
	for g in liste:
		if (g as Pnj).est_actif():
			n += 1
	return n


func _assaut(delta: float) -> void:
	t_hud -= delta
	if t_hud <= 0.0:
		t_hud = 0.5
		_mettre_objectif()
	_allies_combat(delta)
	_pickup_tir(delta)
	_ama_soutien(delta)
	_dossou_suite()
	# les cellules
	if t_crochetage >= 0.0:
		if joueur.global_position.distance_to(_l(26, 27.0)) > 6.0:
			t_crochetage = -1.0
		else:
			t_crochetage -= delta
			if t_crochetage <= 0.0:
				t_crochetage = -1.0
				_ouvrir_cellules()
	if not cellules_ouvertes and _actifs(gardes_cellules) == 0:
		if main.has_meta("garcons_au_camp") and joueur.global_position.distance_to(_l(26, 27)) < 20.0:
			m4._annoncer("Un cliquetis : de l'intérieur, les garçons de Tikané ont crocheté la serrure avec un fil de fer. « Faris ! On savait que tu viendrais ! »", 5.0)
			_ouvrir_cellules()
		elif plan["ama"] == "evasion" and _actifs(cour) <= 4:
			m4._annoncer("AMA (radio) — « Je suis aux cellules ! J'ouvre ! »", 3.0)
			_ouvrir_cellules()
	# les prisonniers libérés gagnent la brèche puis la plage
	if cellules_ouvertes:
		for o in prisonniers:
			var p := o as Pnj
			if p == yaw and yaw_dans_chapelle:
				continue
			# sortir de la cellule vers la cour, longer le mur jusqu'à la brèche, descendre à la plage
			var vers := Vector3(PLAGE.x, p.global_position.y, PLAGE.y) - p.global_position
			if p.global_position.x < CENTRE.x + 44.0:
				vers = _l(46, 24.5) - p.global_position
				if p.global_position.z > CENTRE.y + 26.5:
					vers = Vector3(p.global_position.x, 0, CENTRE.y + 25.0) - Vector3(p.global_position.x, 0, p.global_position.z)
			vers.y = 0.0
			if vers.length() > 2.0:
				var v := vers.normalized() * 3.4
				p.velocity.x = v.x
				p.velocity.z = v.z
				p._regarder(p.global_position + v, delta * 6.0)
			else:
				p.velocity.x = 0.0
				p.velocity.z = 0.0
	# la chapelle s'ouvre quand le tireur du clocher est tombé
	if not chapelle_ouverte and not tireur_clocher.est_actif():
		chapelle_ouverte = true
		porte_chapelle.queue_free()
		m4._annoncer("Le tireur du clocher ne tire plus. La porte de la chapelle cède sous l'épaule de Faris.", 4.0)
	# Mamba : il parle quand Faris entre dans la nef
	if chapelle_ouverte and not discours_fait and joueur.global_position.distance_to(_l(30, -8)) < 12.0:
		discours_fait = true
		phase = Phase.MAMBA
		@warning_ignore("missing_await")
		_discours()
	if phase == Phase.MAMBA and mamba.etat == Pnj.Etat.RENDU and choix == "":
		@warning_ignore("missing_await")
		_avant_choix()


func _ouvrir_cellules() -> void:
	if cellules_ouvertes:
		return
	cellules_ouvertes = true
	if grille_cellules:
		grille_cellules.queue_free()
	for o in prisonniers:
		(o as Pnj).etat = Pnj.Etat.CALME
	m4._annoncer("YAW — « Ama ?… Ama est là ? » Les prisonniers se glissent vers la brèche du mur, puis la plage." + (" La Dr Nadia les attend en bas." if plan["nadia"] == "prisonniers" else ""), 5.0)
	var tel: Node = main.get_node_or_null("Telephone")
	if tel:
		tel.notifier("Yaw est libre.")


func _dossou_suite() -> void:
	if dossou_fait:
		return
	var sd := _sort_dossou()
	var total := cour.size()
	var reste := _actifs(cour)
	if sd == "relache" and reste < total * 0.6 and reste > 0:
		# il fait défection au milieu du combat
		dossou_fait = true
		dossou = _pnj("allie", _l(-16, -26), "villageois", Color(0.3, 0.3, 0.28))
		allies.append(dossou)
		var rendus := 0
		for g in cour:
			var p := g as Pnj
			if p.est_actif() and randf() < 0.45:
				p._se_rendre()
				rendus += 1
		m4._annoncer("DOSSOU (il sort d'un dortoir, les mains vides) — « Assez ! Posez vos armes ! Le Commandant ne mourra pas pour vous ! » %d miliciens se rendent." % rendus, 6.0)
		m4.confiance = clampi(m4.confiance + 3, 0, 100)
	elif sd == "prisonnier" and dossou and not dossou.est_actif():
		dossou_fait = true
		if dossou.etat == Pnj.Etat.LIGOTE or dossou.etat == Pnj.Etat.RENDU:
			m4._annoncer("Faris laisse Dossou en vie, une seconde fois. Dossou ne dit rien. Mais il ne relève pas les yeux.", 4.0)


func _allies_combat(delta: float) -> void:
	t_allies -= delta
	var jp := joueur.global_position
	for i in allies.size():
		var a := allies[i] as Pnj
		if a.etat != Pnj.Etat.CALME:
			continue
		# ils suivent Faris, en éventail derrière lui
		var place := jp + Vector3(cos(i * 1.3) * (4.0 + i * 0.6), 0, sin(i * 1.3) * (4.0 + i * 0.6))
		var vers := place - a.global_position
		vers.y = 0.0
		if vers.length() > 2.5:
			var v := vers.normalized() * (4.2 if vers.length() > 8.0 else 2.2)
			a.velocity.x = v.x
			a.velocity.z = v.z
			a._regarder(a.global_position + v, delta * 6.0)
		else:
			a.velocity.x = 0.0
			a.velocity.z = 0.0
	if t_allies > 0.0:
		return
	t_allies = 1.0
	for a in allies:
		var al := a as Pnj
		var cible := _ennemi_visible(al.global_position + Vector3(0, 1.45, 0), 42.0)
		if cible == null or randf() > 0.55:
			continue
		al._regarder(cible.global_position, 1.0)
		if al.arme:
			al.arme.tirer_effets()
		if randf() < 0.3:
			cible.touche(34.0, false)


func _ennemi_visible(depuis: Vector3, portee: float) -> Pnj:
	var best: Pnj = null
	var dmin := portee
	for g in cour + gardes_cellules + gardes_corps + ([dossou] if dossou and dossou.role == "dossou" else []) + [tireur_clocher]:
		var p := g as Pnj
		if not p.est_actif() or p.etat != Pnj.Etat.COMBAT:
			continue
		var d := depuis.distance_to(p.global_position)
		if d > dmin:
			continue
		var q := PhysicsRayQueryParameters3D.create(depuis, p.global_position + Vector3(0, 1.2, 0), 1)
		if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			continue
		dmin = d
		best = p
	return best


func _pickup_tir(delta: float) -> void:
	if pickup_pv <= 0 or _actifs(cour) == 0:
		return
	var alerte := false
	for g in cour:
		if (g as Pnj).etat == Pnj.Etat.COMBAT:
			alerte = true
			break
	if not alerte:
		return
	t_pickup -= delta
	var depart_tir := pickup.global_position + Vector3(0, 2.6, 0)
	var jp := joueur.global_position + Vector3(0, 1.1, 0)
	if t_pickup <= 0.0 and depart_tir.distance_to(jp) < 60.0 and not joueur.mort:
		t_pickup = randf_range(0.9, 1.6)
		var q := PhysicsRayQueryParameters3D.create(depart_tir, jp, 1)
		if get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			if randf() < clampf(0.45 - depart_tir.distance_to(jp) * 0.005 - joueur.vitesse_affichee * 0.01, 0.1, 0.45):
				joueur.blesser(8.0)
				m4.blessure()


func _ama_soutien(delta: float) -> void:
	if plan["ama"] != "plage" or tirs_ama >= 6:
		return
	t_ama -= delta
	if t_ama > 0.0:
		return
	t_ama = randf_range(9.0, 14.0)
	var cible := _ennemi_visible(_l(60, 20, 2.0), 140.0)
	if cible == null:
		for g in cour:
			if (g as Pnj).est_actif() and (g as Pnj).etat == Pnj.Etat.COMBAT:
				cible = g
				break
	if cible:
		tirs_ama += 1
		cible.touche(80.0, false)
		m4._annoncer("Un claquement sec, depuis la plage : Ama." if tirs_ama == 1 else "Ama tire encore.", 2.0)


func _impact(collider: Object, _p: Vector3) -> void:
	if collider and (collider as Node).has_meta("tireur_pickup") and pickup_pv > 0:
		pickup_pv -= 1
		if pickup_pv <= 0:
			m4._annoncer("Le mitrailleur du pick-up s'effondre derrière son arme.", 2.5)


func _discours() -> void:
	mamba.anim.play("Repos", 0.5)
	m4._annoncer("MAMBA (assis sur le banc du prêtre, sa canne à la main) — « Tu sais ce que ton père m'a dit, la dernière fois ? \"La terre n'oublie pas qui la travaille.\" »", 7.0)
	for g in gardes_corps:
		(g as Pnj)._passer_combat()
	await get_tree().create_timer(7.2).timeout
	m4._annoncer("MAMBA (il rit) — « La terre n'a pas de mémoire, Faris. Les hommes, si. Et les hommes retiennent qui gagne. »", 6.0)
	await get_tree().create_timer(4.0).timeout
	mamba.etat = Pnj.Etat.CALME
	mamba._passer_combat()
	m4._annoncer("Mamba se lève. Sa canne s'ouvre : une lame. (Approchez-vous, frappez-le jusqu'à ce qu'il lâche prise.)", 4.0)


func _avant_choix() -> void:
	choix = "en_attente"
	phase = Phase.CHOIX
	var amb: Ambiances = main.ambiances
	var garde := 0
	while amb.index != 4 and garde < 8:
		amb.suivante()
		garde += 1
	m4._annoncer("La lame tombe sur les dalles. Mamba est à genoux. Dehors, l'aube se lève. Ama, la Dr Nadia et les villageois entrent dans la chapelle.", 6.0)
	# Yaw entre avec sa sœur ; la Dr Nadia les suit
	yaw_dans_chapelle = true
	yaw.etat = Pnj.Etat.CALME
	yaw.velocity = Vector3.ZERO
	yaw.global_position = _l(24.5, -6.3, 0.4)
	yaw._regarder(mamba.global_position, 1.0)
	var vq: Node = main.get_node_or_null("VieQuotidienne")
	if vq:
		var vers := mamba.global_position - _l(24, -7)
		var angle := atan2(vers.x, vers.z)
		vq._perso("femme", "Repos", _l(24.0, -7.0, 0.3), angle)                       # Ama, contre son frère
		var nadia: Node3D = vq._perso("femme2", "Repos", _l(23.2, -10.0, 0.3), angle)   # la Dr Nadia
		for mi in nadia.find_children("*", "MeshInstance3D", true, false):
			var mm := mi as MeshInstance3D
			for k in mm.mesh.get_surface_count():
				var mat := mm.mesh.surface_get_material(k)
				if mat and mat.resource_name == "Chemise":
					var blouse := StandardMaterial3D.new()
					blouse.albedo_color = Color(0.92, 0.92, 0.9)
					mm.set_surface_override_material(k, blouse)
	await get_tree().create_timer(6.0).timeout
	m4._annoncer("MAMBA — « Vas-y. Tue-moi. Ils te suivront plus facilement. »", 5.5)
	await get_tree().create_timer(5.5).timeout
	m4._annoncer("DR NADIA — « Si tu fais ça, il aura gagné. »", 4.5)
	await get_tree().create_timer(4.5).timeout
	m4._annoncer("AMA (qui serre son frère Yaw contre elle) — « Il a volé six mois de la vie de Yaw. Décide. »", 5.0)
	await get_tree().create_timer(4.0).timeout
	choix_ui.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _choisir(c: String) -> void:
	choix = c
	choix_ui.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var tel: Node = main.get_node_or_null("Telephone")
	var tyran: int = main.get_meta("nouveau_tyran", 0)
	if c == "arreter":
		mamba.ligoter()
		main.set_meta("mamba", "arrete")
		m4.confiance = clampi(m4.confiance + 4, 0, 100)
		m4._annoncer("Faris attache lui-même les poignets de Mamba.\nRADIO RACINES — « Le Commandant Mamba est arrêté. Il sera jugé par un tribunal du peuple, quand le pays sera libre. »", 9.0)
	else:
		main.set_meta("mamba", "mort")
		main.set_meta("nouveau_tyran", tyran + 20)
		mamba.touche(1000.0, true)
		m4.confiance = clampi(m4.confiance + 2, 0, 100)
		m4._annoncer("Un seul coup de feu, sous la voûte. Les villageois acclament Faris.\nLa Dr Nadia quitte la chapelle sans un mot.", 9.0)
	if plan["radio"] == "soulevement":
		@warning_ignore("missing_await")
		_dire("JOËL (radio)", "Les villages se sont levés… Bomé a perdu deux hommes sur la route du camp. On a gagné. On a payé.", 10.0)
	await get_tree().create_timer(9.5).timeout
	_fin(tel)


func _dire(qui: String, texte: String, delai: float) -> void:
	await get_tree().create_timer(delai).timeout
	m4._annoncer("%s — %s" % [qui, texte], 7.0)


func _fin(tel: Node) -> void:
	phase = Phase.TERMINEE
	joueur.mission = m4
	if tel:
		if coffre_ouvert:
			tel.notifier("Le Front du Cobra est tombé.")
		else:
			tel.ajouter_preuve("Les contrats de Talanké Agro-Export", "Retrouvés par les villageois dans le coffre de la chapelle : contrats d'exportation exclusive des récoltes de Talanké, signés par le ministère de l'Agriculture.")
			tel.notifier("Le Front du Cobra est tombé. Les villageois ont ouvert le coffre de Mamba.")
	m4._annoncer("Le drapeau du Cobra descend du clocher. La cloche sonne, pour la première fois depuis des années.", 7.0)
	m4._objectif("Prochain objectif : retourner à Port-Néré (mission 12, « L'Aube »).")


## Après un chargement de partie : la mission est déjà faite.
func restaurer_terminee(p_choix: String) -> void:
	choix = p_choix
	phase = Phase.TERMINEE
	m4._objectif("Prochain objectif : retourner à Port-Néré (mission 12, « L'Aube »).")


# ---------------------------------------------------------------------
# F : ligoter, crocheter les cellules, ouvrir le coffre
# ---------------------------------------------------------------------
func interagir() -> void:
	if phase != Phase.ASSAUT and phase != Phase.MAMBA:
		m4.interagir()
		return
	var jp := joueur.global_position
	if chapelle_ouverte and not coffre_ouvert and jp.distance_to(_l(38.5, -3.4)) < 2.2:
		coffre_ouvert = true
		var tel: Node = main.get_node_or_null("Telephone")
		if tel:
			tel.ajouter_preuve("Les contrats de Talanké Agro-Export", "Coffre de Mamba, chapelle du camp : contrats d'exportation exclusive des récoltes de Talanké, signés par le ministère de l'Agriculture. La preuve majeure de l'acte 1.")
		m4._annoncer("Dans le coffre : des liasses de billets, et une chemise cartonnée. « Talanké Agro-Export — contrat d'exclusivité ». Le tampon du ministère de l'Agriculture.", 6.0)
		return
	if not cellules_ouvertes and jp.distance_to(_l(26, 27.0)) < 5.0:
		if _actifs(gardes_cellules) > 0:
			m4._annoncer("Les gardes des cellules vous verraient. Occupez-vous d'eux d'abord.", 2.5)
		else:
			t_crochetage = 3.0
			m4._annoncer("Faris force le cadenas de la première cellule…", 3.0)
		return
	for g in cour + gardes_cellules + gardes_corps + ([dossou] if dossou else []) + [tireur_clocher]:
		var p := g as Pnj
		if p.role == "allie":
			continue
		if p.global_position.distance_to(jp) < 2.0 and (p.etat == Pnj.Etat.RENDU or (p.est_actif() and p.dos_au_joueur())):
			p.ligoter()
			m4._annoncer("Ligoté.", 1.5)
			return


func _neutralise(n: Pnj, comment: String) -> void:
	if n == mamba and comment == "mort_rendu" and choix in ["", "en_attente"]:
		# Faris a tiré sur un homme à genoux : c'est un choix, aussi
		choix_ui.visible = false
		main.set_meta("mamba", "mort")
		main.set_meta("nouveau_tyran", int(main.get_meta("nouveau_tyran", 0)) + 25)
		choix = "eliminer"
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		m4._annoncer("Faris a tiré sur un homme à genoux. La Dr Nadia quitte la chapelle sans un mot.", 7.0)
		get_tree().create_timer(7.5).timeout.connect(func() -> void: _fin(main.get_node_or_null("Telephone")))
		return
	if comment in ["mort", "mort_rendu"]:
		m4.tues += 1
	elif comment in ["ligote", "rendu"]:
		m4.epargnes += 1


# ---------------------------------------------------------------------
# Chute de Faris : la Dr Nadia (ou les villageois) le ramènent au point de départ
# ---------------------------------------------------------------------
func _tombe() -> void:
	if phase != Phase.ASSAUT and phase != Phase.MAMBA:
		return
	m4.t_reprise = 0.0
	t_reprise = 3.5


func _reprendre() -> void:
	for g in cour + gardes_cellules + gardes_corps:
		var p := g as Pnj
		if p.etat == Pnj.Etat.COMBAT:
			p.etat = Pnj.Etat.SUSPICION
			p.soupcon = 0.5
	if mamba.etat == Pnj.Etat.COMBAT:
		mamba.pv = maxf(mamba.pv, 120.0)
	joueur.ressusciter(depart)
	m4._annoncer(("La Dr Nadia vous a recousu au poste de soins." if plan["nadia"] == "soins" else "Les villageois vous ont tiré à l'abri.") + " Reprise.", 3.0)


# ---------- ce que les Pnj demandent ----------
func choisir_couvert(n: Pnj) -> Vector3:
	return n.global_position


func bruit_de_tir(p: Vector3, _joueur_tire := false) -> void:
	for g in cour + gardes_cellules + [tireur_clocher]:
		(g as Pnj).entendre(p, 70.0)
	if dossou and dossou.role == "dossou":
		dossou.entendre(p, 70.0)


func blessure() -> void:
	m4.blessure()

## Mission 8 — « Nuit à Tikané » (voir jeu/missions/08-NUIT-A-TIKANE.md).
## Après Radio Racines : un appel chuchoté de la Dr Nadia. Tikané est occupé, les familles sont
## enfermées dans la maison du chef, les garçons partent pour le camp à l'aube.
## - Nuit d'orage : la pluie couvre les pas, mais chaque éclair révèle tout (les gardes voient loin).
## - Fusil à fléchettes de Kwame (V) : endort un milicien adulte, sans bruit. 12 fléchettes.
## - 7 gardes adultes ; 6 jeunes recrues enrôlées de force. RÈGLE ABSOLUE : les jeunes ne sont jamais
##   des cibles. Le réticule se bloque sur eux, aucune arme ne les blesse, ils ne tirent jamais.
##   On les désarme (F dans leur dos), ou la Dr Nadia leur parle s'ils ont vu Faris.
## - La prison : crocheter le cadenas (F, 3 s) quand les gardes de la porte ne voient plus rien.
## - L'escorte : les familles suivent Faris jusqu'aux pirogues d'Ama. H : suivre / attendre / se cacher / courir.
## - Le choix de l'aube : poursuivre le pick-up des renforts, ou protéger les familles. Aucun n'est gratuit.
class_name Mission8
extends Node3D

enum Phase { INDISPONIBLE, DISPONIBLE, VILLAGE, ESCORTE, AUBE, TERMINEE }
enum Ordre { SUIVRE, ATTENDRE, CACHER, COURIR }
const FLECHETTES := 12
const VUE_NUIT := 20.0
const VUE_RECRUE := 15.0
const ECLAIR_VUE := 2.3
const ORDRES := ["SUIVEZ-MOI", "ATTENDEZ ICI", "CACHEZ-VOUS", "COUREZ !"]

var phase := Phase.INDISPONIBLE
var main: Node
var joueur: Joueur
var m4: Mission4
var tik: VillageTikane
var gardes: Array = []
var recrues: Array = []
var suiveurs: Array = []        # familles (et jeunes désarmés) qui suivent Faris
var sauves: Array = []
var nadia: Pnj
var nadia_rencontree := false
var ama: Node3D
var porte_ouverte := false
var t_crochetage := -1.0
var ordre := Ordre.SUIVRE
var miettes: Array = []         # le chemin de Faris, que les familles suivent pas à pas
var tues := 0
var endormis := 0
var ligotes := 0
var desarmes := 0
var choix := ""
var t_eclair := 0.0
var t_prochain := 8.0
var premier_eclair := true
var t_vu := 0.0
var t_reprise := 0.0
var t_hud := 0.0
var flash: DirectionalLight3D
var tonnerre: AudioStreamPlayer
var calque: CanvasLayer
var etiquette_ordre: Label
var choix_ui: PanelContainer
var porte_noire: MeshInstance3D


func construire(p_main: Node) -> void:
	main = p_main
	joueur = main.joueur
	m4 = main.get_node("Mission4")
	tik = main.tikane
	flash = DirectionalLight3D.new()
	flash.light_color = Color(0.78, 0.84, 1.0)
	flash.light_energy = 0.0
	flash.rotation_degrees = Vector3(-62, 30, 0)
	flash.shadow_enabled = false
	add_child(flash)
	tonnerre = AudioStreamPlayer.new()
	tonnerre.stream = load("res://sons/tonnerre.wav")
	tonnerre.volume_db = -2.0
	add_child(tonnerre)
	_interface()
	joueur.tombe.connect(_tombe)
	joueur.a_tire.connect(func(p: Vector3) -> void:
		if phase == Phase.VILLAGE or phase == Phase.ESCORTE:
			bruit_de_tir(p))


func _interface() -> void:
	calque = CanvasLayer.new()
	calque.layer = 6
	add_child(calque)
	etiquette_ordre = Label.new()
	etiquette_ordre.add_theme_font_size_override("font_size", 18)
	etiquette_ordre.add_theme_color_override("font_color", Color(0.75, 0.95, 0.85))
	etiquette_ordre.add_theme_color_override("font_outline_color", Color.BLACK)
	etiquette_ordre.add_theme_constant_override("outline_size", 5)
	etiquette_ordre.anchor_left = 0.5
	etiquette_ordre.anchor_right = 0.5
	etiquette_ordre.anchor_top = 1.0
	etiquette_ordre.anchor_bottom = 1.0
	etiquette_ordre.offset_left = -260
	etiquette_ordre.offset_right = 260
	etiquette_ordre.offset_top = -120
	etiquette_ordre.offset_bottom = -96
	etiquette_ordre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiquette_ordre.visible = false
	calque.add_child(etiquette_ordre)
	choix_ui = PanelContainer.new()
	var fond := StyleBoxFlat.new()
	fond.bg_color = Color(0.06, 0.06, 0.07, 0.94)
	fond.border_color = Color(0.85, 0.6, 0.3)
	fond.set_border_width_all(2)
	fond.set_corner_radius_all(6)
	fond.set_content_margin_all(18)
	choix_ui.add_theme_stylebox_override("panel", fond)
	choix_ui.set_anchors_preset(Control.PRESET_CENTER)
	choix_ui.position = Vector2(-340, -210)
	choix_ui.custom_minimum_size = Vector2(680, 0)
	choix_ui.visible = false
	calque.add_child(choix_ui)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	choix_ui.add_child(col)
	var t := Label.new()
	t.text = "L'AUBE SUR TIKANÉ\nLes familles sont sur la rive. Mais des phares percent la pluie : un pick-up de renforts file vers le sud, quatre jeunes recrues à l'arrière, emmenées vers le camp du Cobra."
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(640, 0)
	t.add_theme_font_size_override("font_size", 18)
	t.add_theme_color_override("font_color", Color(1.0, 0.82, 0.5))
	col.add_child(t)
	for c in [["Poursuivre le pick-up", "Faris arrête le véhicule sur la piste et libère les quatre garçons. Mais pendant ce temps, les renforts reprennent le haut du village.", "poursuivre"],
			["Protéger les familles", "Faris reste avec les familles jusqu'à ce que les pirogues soient loin. Les quatre garçons arriveront au camp.", "proteger"]]:
		var b := Button.new()
		b.text = "%s — %s" % [c[0], c[1]]
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(640, 0)
		b.pressed.connect(_choisir.bind(c[2]))
		col.add_child(b)
	var n := Label.new()
	n.text = "Il n'y a pas de bonne réponse : seulement le prix de chaque choix."
	n.add_theme_font_size_override("font_size", 14)
	n.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	col.add_child(n)


func etat_texte() -> String:
	return ["à venir", "disponible", "le village", "l'escorte", "l'aube", "Tikané est libre"][phase]


# ---------------------------------------------------------------------
# Déroulement
# ---------------------------------------------------------------------
func _process(delta: float) -> void:
	if joueur == null:
		return
	var jp := joueur.global_position
	match phase:
		Phase.INDISPONIBLE:
			var m7: Node = main.get_node_or_null("Mission7")
			if m7 and m7.phase == Mission7.Phase.TERMINEE:
				_appel()
		Phase.DISPONIBLE:
			if _plat(jp).distance_to(_plat(tik.reperes["place"])) < 260.0:
				_commencer()
		Phase.VILLAGE:
			_crochetage(delta)
			if nadia_rencontree:
				_noter_miette()
				_suivre(nadia, 1, delta, false)
		Phase.ESCORTE:
			_escorte(delta)
	if phase == Phase.VILLAGE or phase == Phase.ESCORTE:
		_orage(delta)
		_perception()
		t_hud -= delta
		if t_hud <= 0.0:
			t_hud = 0.5
			_mettre_objectif()
	if t_reprise > 0.0:
		t_reprise -= delta
		if t_reprise <= 0.0:
			_reprendre()


func _appel() -> void:
	phase = Phase.DISPONIBLE
	var tel: Node = main.get_node_or_null("Telephone")
	if tel:
		tel.notifier("Radio Racines : un appel chuchoté depuis Tikané")
	m4._annoncer("VOIX DE FEMME (radio, chuchotée) — « Ici Tikané… Ils ont pris le village. Ils gardent les familles dans la maison du chef. Ils emmènent les garçons au camp demain à l'aube… S'il vous plaît… »", 9.0)
	m4._objectif("Mission 8 — Nuit à Tikané : rejoignez Tikané, sur la côte est (T sur la carte). Allez-y de nuit.")
	var ca: Node = main.get_node_or_null("Carte")
	if ca:
		ca.poser_balise(tik.reperes["case_sante"])


func _commencer() -> void:
	phase = Phase.VILLAGE
	joueur.mission = self
	var amb: Ambiances = main.ambiances
	var garde := 0
	while amb.index != 5 and garde < 8:   # nuit d'orage
		amb.suivante()
		garde += 1
	joueur.donner_arme()
	joueur.flechettes = maxi(joueur.flechettes, FLECHETTES)
	joueur.mode_flechettes = true
	for g in tik.get_meta("gardes_decor", []):
		if is_instance_valid(g):
			(g as Node).queue_free()
	_placer_gardes()
	_placer_nadia()
	_placer_ama()
	m4._annoncer("Mission 8 — Nuit à Tikané", 4.0)
	@warning_ignore("missing_await")
	_dire("KWAME (radio)", "Je t'ai glissé un fusil à fléchettes. Douze. Ils dormiront comme des bébés. Des bébés armés, mais des bébés. (V pour changer d'arme)", 2.0)
	@warning_ignore("missing_await")
	_dire("AMA (radio)", "Je suis en bas, à la crique, avec les pirogues. Amène-les-moi. Et ne te fais pas voir sous les éclairs.", 10.0)


func _dire(qui: String, texte: String, delai: float) -> void:
	await get_tree().create_timer(delai).timeout
	m4._annoncer("%s — %s" % [qui, texte], 7.0)


func _mettre_objectif() -> void:
	if phase == Phase.VILLAGE:
		var actifs := 0
		for g in gardes:
			if (g as Pnj).est_actif():
				actifs += 1
		var t := "Gardes adultes : %d / 7 neutralisés · Jeunes désarmés : %d / %d" % [7 - actifs, desarmes, recrues.size()]
		if not nadia_rencontree:
			t += "\nLa case de santé, à l'entrée du village : quelqu'un s'y cache (F)."
		t += "\nOuvrez la maison du chef (F devant la porte, quand ses gardes ne voient plus rien)."
		m4._objectif(t)
	elif phase == Phase.ESCORTE:
		var restants := suiveurs.size()
		m4._objectif("Guidez les familles jusqu'aux pirogues d'Ama, à la crique (%d à l'abri, %d en route). H : donner un ordre." % [sauves.size(), restants])


# ---------------------------------------------------------------------
# Les habitants du village
# ---------------------------------------------------------------------
func _placer_gardes() -> void:
	var postes: Array = tik.reperes["gardes"]
	var modeles := ["homme2", "villageois", "homme3"]
	for i in postes.size():
		var p: Vector3 = postes[i]
		var pts: Array = [p]
		if i >= 2:    # les deux gardes de la porte ne bougent pas ; les autres font une petite ronde
			var a := float(i) * 1.7
			var q := p + Vector3(cos(a), 0, sin(a)) * 9.0
			q.y = tik._sol(Vector2(q.x, q.z))
			pts.append(q)
		var g := _pnj("milicien", p, modeles[i % 3], Color(1, 1, 1), "res://data/textures/camouflage.jpg")
		g.points_patrouille = pts
		g.portee_vue = VUE_NUIT
		g.set_meta("vue", VUE_NUIT)
		g.rendu.connect(func(_n: Pnj) -> void: m4._annoncer("Le garde se rend : F pour le ligoter.", 2.5))
		g.alerte.connect(_alerte)
		gardes.append(g)
	for p in tik.reperes["recrues"]:
		# des garçons de Tikané et d'ailleurs, dans des treillis trop grands pour eux
		var r := _pnj("recrue", p, "garcon", Color(0.55, 0.6, 0.45), "res://data/textures/camouflage.jpg")
		r.portee_vue = VUE_RECRUE
		r.set_meta("vue", VUE_RECRUE)
		r.alerte.connect(_alerte)
		recrues.append(r)


func _pnj(role: String, p: Vector3, modele: String, teinte: Color, texture := "") -> Pnj:
	var n := Pnj.new()
	add_child(n)
	n.global_position = p + Vector3(0, 0.3, 0)
	n.preparer(role, self, joueur, teinte, texture, modele)
	n.refuges = [p]
	n.neutralise.connect(_neutralise)
	return n


func _placer_nadia() -> void:
	var cs: Vector3 = tik.reperes["case_sante"]
	var place: Vector3 = tik.reperes["place"]
	var devant := (_plat(place) - _plat(cs)).normalized()
	var p2 := _plat(cs) + devant * 3.4 + devant.orthogonal() * 1.2
	var p := Vector3(p2.x, tik._sol(p2), p2.y)
	nadia = _pnj("civil", p, "femme2", Color(1.6, 1.6, 1.55))   # blouse blanche de soignante
	nadia._regarder(cs, 1.0)
	nadia.etat = Pnj.Etat.CACHE
	# le blessé qu'elle soigne, assis contre le mur
	var vq: Node = main.get_node_or_null("VieQuotidienne")
	if vq:
		var q2 := _plat(cs) + devant * 2.8 - devant.orthogonal() * 0.6
		vq._perso("homme3", "Assis", Vector3(q2.x, tik._sol(q2), q2.y), atan2(devant.x, devant.y))


func _placer_ama() -> void:
	var e: Vector3 = tik.reperes["embarcadere"]
	var vq: Node = main.get_node_or_null("VieQuotidienne")
	if vq:
		var porte: Vector3 = tik.reperes["porte_prison"]
		var d := _plat(porte) - _plat(e)
		ama = vq._perso("femme", "Repos", e + Vector3(0, 0.05, 0), atan2(d.x, d.y))


func _neutralise(n: Pnj, comment: String) -> void:
	match comment:
		"mort", "mort_rendu":
			tues += 1
			if tues == 1 and nadia_rencontree:
				@warning_ignore("missing_await")
				_dire("DR NADIA (à voix basse)", "Un homme est mort. Je le recoudrai pas, celui-là. Souviens-toi de ce que je t'ai dit.", 1.0)
		"endormi":
			endormis += 1
			m4._annoncer("Le garde s'effondre, endormi jusqu'au matin.", 2.0)
		"ligote":
			ligotes += 1
		"desarme":
			desarmes += 1
			if porte_ouverte and not suiveurs.has(n):
				_rejoindre(n)


func _alerte(origine: Vector3) -> void:
	for g in gardes:
		var p := g as Pnj
		if p.est_actif() and p.global_position.distance_to(origine) < 45.0:
			p._passer_combat()
	for r in recrues:
		var p := r as Pnj
		if p.est_actif() and p.global_position.distance_to(origine) < 25.0:
			p._passer_combat()


# ---------------------------------------------------------------------
# F : parler, désarmer, ligoter, crocheter
# ---------------------------------------------------------------------
func interagir() -> void:
	var jp := joueur.global_position
	if phase != Phase.VILLAGE and phase != Phase.ESCORTE:
		m4.interagir()
		return
	if not nadia_rencontree and jp.distance_to(nadia.global_position) < 2.5:
		_rencontre_nadia()
		return
	# un jeune : on le désarme, on ne le frappe jamais
	var r := _plus_proche(recrues, 5.0)
	if r:
		_desarmer(r)
		return
	# un milicien adulte : prise dans le dos, ou ligoter celui qui s'est rendu
	for g in gardes:
		var p := g as Pnj
		if p.global_position.distance_to(jp) < 2.0 and (p.etat == Pnj.Etat.RENDU or (p.est_actif() and p.dos_au_joueur())):
			p.ligoter()
			m4._annoncer("Garde ligoté.", 2.0)
			return
	if phase == Phase.VILLAGE and not porte_ouverte and jp.distance_to(tik.reperes["porte_prison"]) < 2.6:
		for g in gardes.slice(0, 2):
			if (g as Pnj).est_actif():
				m4._annoncer("Les gardes de la porte vous verraient. Endormez-les ou prenez-les à revers d'abord.", 3.0)
				return
		t_crochetage = 3.0
		m4._annoncer("Faris crochète le cadenas… (restez près de la porte)", 3.0)


func _plus_proche(liste: Array, rayon: float) -> Pnj:
	var best: Pnj = null
	var dmin := rayon
	for x in liste:
		var p := x as Pnj
		if p.role != "recrue":
			continue
		var d := p.global_position.distance_to(joueur.global_position)
		if d < dmin:
			dmin = d
			best = p
	return best


func _desarmer(r: Pnj) -> void:
	var d := r.global_position.distance_to(joueur.global_position)
	var gardes_actifs := 0
	for g in gardes:
		if (g as Pnj).est_actif():
			gardes_actifs += 1
	if r.etat != Pnj.Etat.COMBAT and d < 2.2 and r.dos_au_joueur():
		r.desarmer()
		m4._annoncer("Faris pose une main sur l'épaule du garçon et prend le fusil. « C'est fini. Personne ne te fera de mal. »", 4.5)
	elif nadia_rencontree and nadia.global_position.distance_to(r.global_position) < 14.0:
		r.desarmer()
		m4._annoncer("La Dr Nadia s'avance, les mains ouvertes, et parle au garçon dans sa langue. Il hésite… puis pose son arme et s'assoit en pleurant.", 5.0)
	elif gardes_actifs == 0:
		r.desarmer()
		m4._annoncer("Plus aucun chef pour crier. Faris baisse son arme ; le garçon lâche la sienne.", 4.0)
	elif r.etat == Pnj.Etat.COMBAT:
		m4._annoncer("Il a trop peur pour écouter. Revenez avec la Dr Nadia, ou occupez-vous d'abord des gardes adultes.", 3.5)
	else:
		m4._annoncer("Approchez-vous dans son dos, sans qu'il vous voie.", 2.5)


func _rencontre_nadia() -> void:
	nadia_rencontree = true
	nadia.etat = Pnj.Etat.CALME
	m4._annoncer("DR NADIA — « Les gardes adultes sont sept. Mais il y a aussi les jeunes. Des garçons de Tikané et d'ailleurs, enrôlés de force. Ils ont des armes. Ils ont peur. Si tu leur tires dessus, je te soignerai, puis je ne te reparlerai plus jamais. »", 10.0)
	@warning_ignore("missing_await")
	_dire("DR NADIA", "Je viens avec toi. S'ils te voient, laisse-moi leur parler. (Elle vous suit, discrète.)", 10.5)


func _crochetage(delta: float) -> void:
	if t_crochetage < 0.0:
		return
	if joueur.global_position.distance_to(tik.reperes["porte_prison"]) > 3.0:
		t_crochetage = -1.0
		m4._annoncer("Crochetage interrompu.", 1.5)
		return
	t_crochetage -= delta
	if t_crochetage <= 0.0:
		t_crochetage = -1.0
		_ouvrir_prison()


func _ouvrir_prison() -> void:
	porte_ouverte = true
	phase = Phase.ESCORTE
	# la porte s'ouvre sur le noir de la pièce
	var xf: Transform3D = tik.reperes["porte_xf"]
	porte_noire = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.62, 2.2, 0.03)
	porte_noire.mesh = bm
	var noir := StandardMaterial3D.new()
	noir.albedo_color = Color(0.02, 0.02, 0.02)
	porte_noire.material_override = noir
	add_child(porte_noire)
	porte_noire.global_transform = Transform3D(xf.basis, xf * Vector3(0, 1.1, -0.13))
	var battant := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(0.8, 2.2, 0.07)
	battant.mesh = bb
	var bois := StandardMaterial3D.new()
	bois.albedo_color = Color(0.42, 0.3, 0.2)
	battant.material_override = bois
	add_child(battant)
	var bb_basis := xf.basis * Basis(Vector3.UP, deg_to_rad(-105))
	battant.global_transform = Transform3D(bb_basis, xf * Vector3(-0.8, 1.1, -0.15) + bb_basis * Vector3(-0.4, 0, 0))
	# trois familles : parents, anciens, enfants
	var porte: Vector3 = tik.reperes["porte_prison"]
	var dehors := (_plat(porte) - _plat(xf.origin)).normalized()
	var modeles := ["femme", "garcon", "homme3", "ancien", "fille", "femme_agee", "homme2", "garcon"]
	for i in modeles.size():
		var q2 := _plat(porte) + dehors * float(i % 3) * 0.9 + dehors.orthogonal() * (float(i % 3) - 1.0) * 0.8 - dehors * float(i) * 0.15
		var o := _pnj("civil", Vector3(q2.x, tik._sol(q2), q2.y), modeles[i], Color(randf_range(0.7, 1.2), randf_range(0.7, 1.1), randf_range(0.6, 1.0)))
		_rejoindre(o)
	for r in recrues:
		if (r as Pnj).etat == Pnj.Etat.DESARME:
			_rejoindre(r)
	if nadia_rencontree:
		_rejoindre(nadia)
	miettes.clear()
	miettes.append(joueur.global_position)
	for x in suiveurs:
		(x as Pnj).set_meta("miette", 0)
	etiquette_ordre.visible = true
	ordre = Ordre.SUIVRE
	_afficher_ordre()
	m4._annoncer("La porte cède. Dans le noir, des visages : des mères, des anciens, des enfants qui se cachent les yeux. « Doucement. On rentre chez nous. »", 6.0)
	var ca: Node = main.get_node_or_null("Carte")
	if ca:
		ca.poser_balise(tik.reperes["embarcadere"])


# ---------------------------------------------------------------------
# Escorte
# ---------------------------------------------------------------------
func _rejoindre(p: Pnj) -> void:
	if suiveurs.has(p) or sauves.has(p):
		return
	p.etat = Pnj.Etat.CALME
	suiveurs.append(p)


func _unhandled_input(event: InputEvent) -> void:
	if phase != Phase.ESCORTE or not event.is_action_pressed("ordre"):
		return
	ordre = ((int(ordre) + 1) % 4) as Ordre
	_afficher_ordre()


func _afficher_ordre() -> void:
	etiquette_ordre.text = "Familles : %s   (H : ordre suivant)" % ORDRES[ordre]


func _noter_miette() -> void:
	var jp := joueur.global_position
	if miettes.is_empty() or jp.distance_to(miettes[miettes.size() - 1]) > 1.2:
		miettes.append(jp)


## Un suiveur remonte les pas de Faris, miette après miette, et s'arrête à quelques mètres de lui :
## le groupe se resserre quand Faris s'arrête, s'étire quand il marche.
func _suivre(p: Pnj, rang: int, delta: float, course: bool) -> void:
	if miettes.is_empty():
		return
	var jp := joueur.global_position
	var idx: int = clampi(int(p.get_meta("miette", 0)), 0, miettes.size() - 1)
	var ecart := 1.8 + float(rang) * 0.45
	# filet de sécurité : quelqu'un a glissé sous le sol (collision manquée) → on le remonte
	var sol := main.terrain.hauteur(p.global_position.x, p.global_position.z) as float
	if p.global_position.y < sol - 2.5:
		p.global_position.y = sol + 0.5
		p.velocity.y = 0.0
	var vers_faris := jp - p.global_position
	vers_faris.y = 0.0
	if vers_faris.length() > 35.0:
		# retardataire coincé loin derrière, hors de vue : il rattrape le groupe
		var k := maxi(0, miettes.size() - 4)
		p.global_position = miettes[k] + Vector3(0, 0.3, 0)
		p.set_meta("miette", k)
		return
	if joueur.accroupi and joueur.vitesse_affichee < 0.2 and vers_faris.length() < ecart + 3.0:
		p.etat = Pnj.Etat.CACHE    # Faris s'accroupit : le groupe aussi
		return
	p.etat = Pnj.Etat.CALME
	if vers_faris.length() < ecart:
		p.velocity.x = 0.0
		p.velocity.z = 0.0
		return
	var cible: Vector3 = miettes[idx]
	var d := cible - p.global_position
	d.y = 0.0
	while d.length() < 0.9 and idx < miettes.size() - 1:
		idx += 1
		cible = miettes[idx]
		d = cible - p.global_position
		d.y = 0.0
	p.set_meta("miette", idx)
	# trois de front : petit décalage latéral selon le rang
	if idx > 0:
		var av: Vector3 = miettes[idx] - miettes[idx - 1]
		av.y = 0.0
		if av.length() > 0.01:
			d += Vector3(-av.z, 0.0, av.x).normalized() * (float(rang % 3) - 1.0) * 0.7
	var v := 4.6 if course or vers_faris.length() > ecart + 8.0 else 2.0
	var vel := d.normalized() * v if d.length() > 0.05 else Vector3.ZERO
	# coincé contre un talus ou un muret : au bout d'1,5 s sans avancer, il descend à la main
	# jusqu'au point suivant du chemin de Faris
	var prec: Vector3 = p.get_meta("pos_prec", p.global_position)
	var bloque: float = p.get_meta("t_bloque", 0.0)
	if vel.length() > 0.0 and _plat(p.global_position).distance_to(_plat(prec)) < 0.25 * delta * v:
		bloque += delta
	else:
		bloque = 0.0
	if bloque > 1.5:
		bloque = 0.0
		idx = mini(idx + 2, miettes.size() - 1)
		p.global_position = miettes[idx] + Vector3(0, 0.4, 0)
		p.set_meta("miette", idx)
	p.set_meta("t_bloque", bloque)
	p.set_meta("pos_prec", p.global_position)
	p.velocity.x = vel.x
	p.velocity.z = vel.z
	if vel.length() > 0.0:
		p._regarder(p.global_position + vel, minf(1.0, delta * 8.0))


func _escorte(delta: float) -> void:
	_noter_miette()
	var embarc: Vector3 = tik.reperes["embarcadere"]
	var arrives: Array = []
	for i in suiveurs.size():
		var p := suiveurs[i] as Pnj
		if _plat(p.global_position).distance_to(_plat(embarc)) < 15.0:   # sur la berge, près des pirogues
			arrives.append(p)
		elif ordre == Ordre.CACHER:
			p.etat = Pnj.Etat.CACHE
		elif ordre == Ordre.ATTENDRE:
			p.etat = Pnj.Etat.CALME
			p.velocity.x = 0.0
			p.velocity.z = 0.0
		else:
			_suivre(p, i, delta, ordre == Ordre.COURIR)
	for p in arrives:
		_mettre_a_l_abri(p)
	if suiveurs.is_empty() and sauves.size() > 0:
		@warning_ignore("missing_await")
		_aube()


func _mettre_a_l_abri(p: Pnj) -> void:
	suiveurs.erase(p)
	sauves.append(p)
	p.etat = Pnj.Etat.DESARME     # immobile, ne suit plus
	p.velocity = Vector3.ZERO
	p.anim.play("Assis" if p.anim.has_animation("Assis") else "Repos", 0.6)
	if sauves.size() == 1:
		@warning_ignore("missing_await")
		_dire("AMA", "Par ici ! Montez, montez… Les petits d'abord.", 0.2)


# ---------------------------------------------------------------------
# L'orage et ce que voient les gardes
# ---------------------------------------------------------------------
func _orage(delta: float) -> void:
	t_prochain -= delta
	if t_prochain <= 0.0:
		t_prochain = randf_range(9.0, 20.0)
		t_eclair = 0.42
		var delai := randf_range(0.3, 2.2)
		get_tree().create_timer(delai).timeout.connect(func() -> void: tonnerre.play())
		if premier_eclair:
			premier_eclair = false
			m4._annoncer("Un éclair : tout le village apparaît, en blanc. Pendant l'éclair, les gardes voient loin — restez à couvert.", 4.0)
	if t_eclair > 0.0:
		t_eclair -= delta
		# deux ou trois scintillements, comme un vrai éclair
		var k := t_eclair / 0.42
		flash.light_energy = 4.5 * absf(sin(k * PI * 2.5)) * k
	else:
		flash.light_energy = 0.0
	var eclair := t_eclair > 0.0
	for x in gardes + recrues:
		var p := x as Pnj
		if p.est_actif():
			var base: float = p.get_meta("vue", VUE_NUIT)
			p.portee_vue = base * (ECLAIR_VUE if eclair else 1.0)


func _perception() -> void:
	if phase != Phase.ESCORTE or ordre == Ordre.CACHER:
		return
	t_vu -= get_process_delta_time()
	var eclair := t_eclair > 0.0
	for g in gardes:
		var p := g as Pnj
		if p.etat != Pnj.Etat.CALME and p.etat != Pnj.Etat.SUSPICION:
			continue
		for s in suiveurs:
			var o := s as Pnj
			var d := p.global_position.distance_to(o.global_position)
			var portee := (14.0 if ordre != Ordre.ATTENDRE else 9.0) * (ECLAIR_VUE if eclair else 1.0)
			if d > portee:
				continue
			var dir := o.global_position - p.global_position
			dir.y = 0.0
			if p.regard.dot(dir.normalized()) < 0.3:
				continue
			p._passer_combat()
			if t_vu <= 0.0:
				t_vu = 6.0
				m4._annoncer("Un garde a vu les familles ! « Hé ! Ils s'échappent ! »", 3.0)
			break


# ---------------------------------------------------------------------
# L'aube et le choix
# ---------------------------------------------------------------------
func _aube() -> void:
	phase = Phase.AUBE
	etiquette_ordre.visible = false
	flash.light_energy = 0.0
	var amb: Ambiances = main.ambiances
	var garde := 0
	while amb.index != 4 and garde < 8:
		amb.suivante()
		garde += 1
	m4._annoncer("Les pirogues glissent sur la crique. La pluie s'arrête. Le ciel pâlit sur Tikané.", 5.0)
	await get_tree().create_timer(5.5).timeout
	choix_ui.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _choisir(c: String) -> void:
	choix = c
	choix_ui.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var tel: Node = main.get_node_or_null("Telephone")
	if c == "poursuivre":
		m4._annoncer("Faris coupe à travers la forêt et barre la piste. Le pick-up s'arrête. À l'arrière, quatre garçons qui n'osent pas descendre — puis qui courent vers la rivière.\nMais pendant ce temps, les renforts ont repris le haut de Tikané : deux familles sont reprises. Il faudra revenir.", 9.0)
		main.set_meta("tikane_a_reprendre", true)
		m4.confiance = clampi(m4.confiance + 3, 0, 100)
	else:
		m4._annoncer("Faris reste sur la rive jusqu'à ce que la dernière pirogue disparaisse dans la mangrove. Toutes les familles sont sauvées.\nLe pick-up s'éloigne vers le sud. Faris retient le visage des quatre garçons. Il les retrouvera.", 9.0)
		main.set_meta("garcons_au_camp", true)
		m4.confiance = clampi(m4.confiance + 5, 0, 100)
	await get_tree().create_timer(9.5).timeout
	_epilogue(tel)


func _epilogue(tel: Node) -> void:
	phase = Phase.TERMINEE
	joueur.mission = m4
	joueur.mode_flechettes = false
	if tues == 0:
		m4._annoncer("DR NADIA — « Pas un mort cette nuit. Je recouds tout le monde. Même les tiens. Même les leurs. » — FARIS — « Alors reste. Et empêche-moi de le devenir. »", 9.0)
	else:
		m4._annoncer("DR NADIA — « Je recouds tout le monde. Même les tiens. Même les leurs. Mais je n'irai pas plus loin avec toi si tu deviens comme eux. » — FARIS — « Alors reste. Et empêche-moi de le devenir. »", 9.0)
	joueur.set_meta("soins_nadia", true)
	if tel:
		tel.ajouter_preuve("Le travail forcé de Tikané", "Témoignages des familles de Tikané : villageois enfermés dans la maison du chef, garçons enrôlés de force par le Front du Cobra et envoyés au camp du sud. Recueillis à l'aube par la Dr Nadia.")
		tel.notifier("La Dr Nadia rejoint les Racines : vos blessures guérissent plus vite.")
	m4._objectif("Prochain objectif : suivre les chargements de la nuit (mission 9, « Le Chenal »).")


## Après un chargement de partie : la mission est déjà faite.
func restaurer_terminee(p_choix: String) -> void:
	choix = p_choix
	phase = Phase.TERMINEE
	nadia_rencontree = true
	joueur.set_meta("soins_nadia", true)
	m4._objectif("Prochain objectif : suivre les chargements de la nuit (mission 9, « Le Chenal »).")


# ---------------------------------------------------------------------
# Chute de Faris : on reprend à la case de santé, le village garde son état
# ---------------------------------------------------------------------
func _tombe() -> void:
	if phase != Phase.VILLAGE and phase != Phase.ESCORTE:
		return
	m4.t_reprise = 0.0
	t_reprise = 3.5


func _reprendre() -> void:
	for x in gardes + recrues:
		var p := x as Pnj
		if p.etat == Pnj.Etat.COMBAT or p.etat == Pnj.Etat.SUSPICION:
			p.etat = Pnj.Etat.CALME
			p.soupcon = 0.0
			p.pv = maxf(p.pv, 60.0)
	var cs: Vector3 = tik.reperes["case_sante"]
	var place: Vector3 = tik.reperes["place"]
	var devant := (_plat(place) - _plat(cs)).normalized()
	var p2 := _plat(cs) + devant * 5.0
	joueur.ressusciter(Vector3(p2.x, tik._sol(p2) + 0.5, p2.y))
	miettes.clear()
	for x in suiveurs + [nadia]:
		if x:
			(x as Pnj).set_meta("miette", 0)
	if phase == Phase.ESCORTE:
		ordre = Ordre.ATTENDRE
		_afficher_ordre()
	m4._annoncer("La Dr Nadia vous a traîné jusqu'à la case de santé… Reprise.", 3.0)


# ---------- ce que les Pnj demandent ----------
func choisir_couvert(n: Pnj) -> Vector3:
	var loin := n.global_position - joueur.global_position
	loin.y = 0.0
	if loin.length() < 0.1:
		return n.global_position
	return n.global_position + loin.normalized() * 2.5


func bruit_de_tir(p: Vector3, _joueur_tire := false) -> void:
	for x in gardes + recrues:
		(x as Pnj).entendre(p, 70.0)


func blessure() -> void:
	m4.blessure()


func _plat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)

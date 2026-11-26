## Mission 5 — « Les Graines » (voir jeu/missions/05-LES-GRAINES.md).
## Après la libération d'Akwéri : reprendre au Cobra les 12 sacs de semences de la coopérative de Bomé,
## gardés dans son entrepôt sur pilotis du quai de Port-Néré. Mission d'infiltration : on peut réussir
## sans tirer une seule balle.
## - Entrées : la porte côté quai, ou la trappe du plancher depuis l'eau (Ama attend dessous en pirogue).
## - Outil de Kwame (F au groupe électrogène) : 2 minutes de noir, les gardes allument leurs lampes torches.
## - X : lancer un caillou là où l'on regarde ; le garde le plus proche va voir.
## - F dans le dos : maîtriser ; F sur un garde ligoté : le traîner ; F près des caisses : l'y cacher.
##   Un garde qui découvre un camarade ligoté à découvert donne l'alerte.
## - F à la porte de la chambre froide : crocheter (rester immobile 3 s). F aux sacs : en prendre un ;
##   F à la trappe : le descendre à Ama. Dans le bureau, le registre des chargements : une preuve.
## - Alerte : on peut encore fuir avec les sacs déjà descendus (réussite partielle).
class_name Mission5
extends Node3D

enum Phase { INDISPONIBLE, DISPONIBLE, EN_COURS, TERMINEE }
const SACS := 12
const NOIR := 120.0
const LONG := 24.0     # entrepôt : 24 m le long du quai
const PROF := 16.0     # 16 m de profondeur, dont la moitié au-dessus de l'eau

var phase := Phase.INDISPONIBLE
var main: Node
var joueur: Joueur
var m4: Mission4
var terrain: Terrain
var base := Transform3D()      # repère de l'entrepôt : X le long du quai, +Z vers la mer
var plancher := 1.5
var gardes: Array = []
var lampes: Array = []
var neons: Array = []
var noir := 0.0
var sacs_livres := 0
var sacs_restants := SACS
var porte_sac: MeshInstance3D
var porte_corps: Pnj
var chambre_ouverte := false
var porte_froide: Node3D
var crochetage := -1.0
var preuve := false
var alarme := false
var t_loin := 0.0
var cachettes: Array = []      # Vector3 : derrière les piles de caisses
var tas_sacs: Array = []       # MeshInstance3D des sacs encore dans la chambre froide
var mat_toile: StandardMaterial3D
var pluie_son: AudioStreamPlayer3D


# ---------------------------------------------------------------------
# Construction de l'entrepôt
# ---------------------------------------------------------------------
func construire(p_main: Node, quai: Vector2, veg: Vegetation) -> void:
	main = p_main
	joueur = main.joueur
	terrain = main.terrain
	m4 = main.get_node("Mission4")
	var site := _site(quai)
	if site.is_empty():
		push_warning("Mission 5 : pas de rivage libre près du quai")
		return
	var o: Vector2 = site[0]
	var mer: Vector2 = site[1]
	var x := Vector2(mer.y, -mer.x)
	var h_max := 0.0
	for i in 9:
		for k in 5:
			var p := o + x * (i / 8.0 - 0.5) * LONG - mer * (k / 4.0) * (PROF * 0.5)
			h_max = maxf(h_max, terrain.hauteur(p.x, p.y))
	plancher = maxf(1.6, h_max + 0.3)
	base = Transform3D(Basis(Vector3(x.x, 0, x.y), Vector3.UP, Vector3(mer.x, 0, mer.y)), Vector3(o.x, 0, o.y))
	veg.degager(func(q: Vector2) -> bool: return q.distance_to(o) < 22.0)
	_batiment()
	_interieur()
	_ama()
	_quai()
	joueur.a_tire.connect(func(p: Vector3) -> void: bruit_de_tir(p, true))
	pluie_son = AudioStreamPlayer3D.new()
	pluie_son.stream = load("res://sons/pluie.wav")
	(pluie_son.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	(pluie_son.stream as AudioStreamWAV).loop_end = int(pluie_son.stream.get_length() * (pluie_son.stream as AudioStreamWAV).mix_rate)
	pluie_son.position = _l(0, plancher + 4.0, 0)
	pluie_son.unit_size = 6.0
	pluie_son.max_distance = 40.0
	pluie_son.volume_db = -14.0
	add_child(pluie_son)


## Rivage près du quai : pente douce côté terre, eau profonde côté mer, rien de construit à moins de 22 m.
func _site(quai: Vector2) -> Array:
	var meilleur: Array = []
	var score_min := INF
	for k in 72:
		var a := TAU * k / 72.0
		var dir := Vector2(sin(a), cos(a))
		var prec := terrain.hauteur(quai.x, quai.y)
		var r := 10.0
		while r < 420.0:
			var p := quai + dir * r
			var h := terrain.hauteur(p.x, p.y)
			if prec >= 0.8 and h < 0.8:
				# normale au rivage : vers où le sol descend
				var gx := terrain.hauteur(p.x + 6, p.y) - terrain.hauteur(p.x - 6, p.y)
				var gz := terrain.hauteur(p.x, p.y + 6) - terrain.hauteur(p.x, p.y - 6)
				var mer := -Vector2(gx, gz).normalized()
				if mer.length() < 0.5:
					break
				var terre := p - mer * 9.0
				var large := p + mer * 9.0
				var ok := terrain.hauteur(terre.x, terre.y) < 3.2 and terrain.hauteur(large.x, large.y) < -0.8
				var cote := Vector2(mer.y, -mer.x)
				for s_ in [-1.0, 1.0]:
					var bout: Vector2 = p + cote * s_ * 12.0 - mer * 4.0
					if terrain.hauteur(bout.x, bout.y) > 3.5:
						ok = false
				if ok and _libre(p):
					var score := r
					if score < score_min:
						score_min = score
						meilleur = [p, mer]
				break
			prec = h
			r += 3.0
	return meilleur


func _libre(p: Vector2) -> bool:
	for v in [main.ville]:
		for k in (v as VillePortNere).occupe:
			if Vector2(k.x * 2.0 + 1.0, k.y * 2.0 + 1.0).distance_to(p) < 20.0:
				return false
	return true


func _l(x: float, y: float, z: float) -> Vector3:
	return base * Vector3(x, 0, z) + Vector3(0, y, 0)


func _boite(taille: Vector3, centre: Vector3, mat: Material, solide := true, parent: Node3D = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = taille
	mi.mesh = bx
	mi.material_override = mat
	parent.add_child(mi)
	mi.global_transform = Transform3D(base.basis, centre)
	if solide:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var forme := BoxShape3D.new()
		forme.size = taille
		cs.shape = forme
		sb.add_child(cs)
		mi.add_child(sb)
	return mi


func _mat(tex: String, uv: float, teinte := Color.WHITE, rugosite := 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://data/textures/%s_diff.jpg" % tex)
	m.normal_enabled = true
	m.normal_texture = load("res://data/textures/%s_nor.jpg" % tex)
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * uv
	m.albedo_color = teinte
	m.roughness = rugosite
	return m


func _batiment() -> void:
	var tole := _mat("rusty_corrugated_iron", 0.25)
	var planches := _mat("weathered_brown_planks", 0.35)
	var bois := _mat("weathered_plank_siding", 0.4, Color(0.7, 0.65, 0.6))
	var hx := LONG * 0.5
	var hz := PROF * 0.5
	var hm := 5.2      # hauteur des murs
	# plancher sur pilotis
	_boite(Vector3(LONG, 0.3, PROF), _l(0, plancher - 0.15, 0), planches)
	var pilier := CylinderMesh.new()
	pilier.top_radius = 0.16
	pilier.bottom_radius = 0.2
	pilier.height = plancher + 3.0
	for i in 7:
		for k in 5:
			var p := _l(-hx + 1.0 + i * (LONG - 2.0) / 6.0, 0, -hz + 1.0 + k * (PROF - 2.0) / 4.0)
			var sol := terrain.hauteur(p.x, p.z)
			if sol > plancher - 0.5:
				continue
			var mi := MeshInstance3D.new()
			mi.mesh = pilier
			mi.material_override = bois
			add_child(mi)
			mi.global_position = Vector3(p.x, plancher - 0.3 - pilier.height * 0.5, p.z)
	# murs de tôle (porte côté quai, à gauche ; trappe et ponton côté mer)
	_boite(Vector3(0.12, hm, PROF), _l(-hx, plancher + hm * 0.5, 0), tole)
	_boite(Vector3(0.12, hm, PROF), _l(hx, plancher + hm * 0.5, 0), tole)
	_boite(Vector3(LONG, hm, 0.12), _l(0, plancher + hm * 0.5, hz), tole)
	# façade côté quai avec la grande porte (3,4 m) à x = -6
	_boite(Vector3(hx - 7.7, hm, 0.12), _l(-hx + (hx - 7.7) * 0.5, plancher + hm * 0.5, -hz), tole)
	_boite(Vector3(hx + 4.3, hm, 0.12), _l(-4.3 + (hx + 4.3) * 0.5, plancher + hm * 0.5, -hz), tole)
	_boite(Vector3(3.4, hm - 3.2, 0.12), _l(-6.0, plancher + 3.2 + (hm - 3.2) * 0.5, -hz), tole)
	# toit à deux pans : faîtage au milieu, débord de 0,9 m ; pignons triangulaires en tôle
	var faite := plancher + hm + 1.4
	var egout := plancher + hm - 0.1
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hxd := hx + 0.5
	for s_ in [-1.0, 1.0]:
		var a := _l(-hxd, faite, 0)
		var b := _l(hxd, faite, 0)
		var c := _l(hxd, egout, s_ * (hz + 0.9))
		var d := _l(-hxd, egout, s_ * (hz + 0.9))
		for v in ([a, b, c, a, c, d] if s_ < 0 else [a, c, b, a, d, c]):
			st.set_uv(Vector2(v.x * 0.25, v.z * 0.25))
			st.add_vertex(v)
	for s_ in [-1.0, 1.0]:
		var a := _l(s_ * hx, plancher + hm, -hz)
		var b := _l(s_ * hx, plancher + hm, hz)
		var c := _l(s_ * hx, faite, 0)
		for v in [a, b, c, a, c, b]:
			st.set_uv(Vector2(v.z * 0.25, v.y * 0.25))
			st.add_vertex(v)
	st.generate_normals()
	var toit := MeshInstance3D.new()
	toit.mesh = st.commit()
	var tole2: StandardMaterial3D = tole.duplicate()
	tole2.cull_mode = BaseMaterial3D.CULL_DISABLED
	toit.material_override = tole2
	add_child(toit)
	# marche devant la porte (le quai est un peu plus bas que le plancher)
	var devant := _l(-6.0, 0, -hz - 1.0)
	var h_devant := terrain.hauteur(devant.x, devant.z)
	if plancher - h_devant > 0.25:
		_boite(Vector3(3.4, plancher - h_devant, 2.0), Vector3(devant.x, h_devant + (plancher - h_devant) * 0.5 - 0.05, devant.z), planches)
	# panneau peint au-dessus de la porte
	var lab := Label3D.new()
	lab.text = "ENTREPÔT N° 3 — FRONT DU COBRA\nACCÈS INTERDIT"
	lab.font_size = 56
	lab.pixel_size = 0.006
	lab.modulate = Color(0.9, 0.85, 0.75)
	lab.outline_size = 8
	add_child(lab)
	lab.global_transform = Transform3D(base.basis.rotated(Vector3.UP, PI), _l(-6.0, plancher + 3.8, -hz - 0.1))
	# groupe électrogène derrière le bâtiment, côté quai
	var groupe := _boite(Vector3(1.6, 1.1, 0.9), _l(hx + 1.6, terrain.hauteur(_l(hx + 1.6, 0, -hz + 2).x, _l(hx + 1.6, 0, -hz + 2).z) + 0.55, -hz + 2.0), _mat("concrete_block_wall", 0.5, Color(0.25, 0.4, 0.3), 0.5))
	groupe.name = "Groupe"
	groupe.transparency = 1.0          # la boîte ne sert qu'au repère ; on voit le vrai groupe électrogène
	var modele_groupe: Node3D = (load("res://props/portable_generator.glb") as PackedScene).instantiate()
	groupe.add_child(modele_groupe)
	modele_groupe.position = Vector3(0, -0.55, 0)
	modele_groupe.scale = Vector3.ONE * 1.7
	var son_groupe := AudioStreamPlayer3D.new()
	son_groupe.stream = load("res://sons/moto.wav")
	(son_groupe.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	(son_groupe.stream as AudioStreamWAV).loop_end = int(son_groupe.stream.get_length() * (son_groupe.stream as AudioStreamWAV).mix_rate)
	son_groupe.pitch_scale = 0.42
	son_groupe.volume_db = -10.0
	son_groupe.unit_size = 4.0
	son_groupe.max_distance = 45.0
	son_groupe.name = "Son"
	groupe.add_child(son_groupe)
	son_groupe.autoplay = true


func _interieur() -> void:
	var caisse := _mat("weathered_plank_siding", 0.5, Color(0.8, 0.72, 0.6))
	var cloison := _mat("weathered_brown_planks", 0.4, Color(0.75, 0.7, 0.65))
	var hx := LONG * 0.5
	var hz := PROF * 0.5
	# piles de caisses : couvert et cachettes
	for c in [Vector2(-2.0, -3.0), Vector2(2.5, -3.0), Vector2(-2.0, 1.5), Vector2(2.5, 1.5), Vector2(-9.0, -3.5), Vector2(7.0, 4.5)]:
		var hauteur := 1.2 if int(c.x) % 2 == 0 else 2.4
		_boite(Vector3(2.4, hauteur, 1.6), _l(c.x, plancher + hauteur * 0.5, c.y), caisse)
		cachettes.append(_l(c.x, plancher, c.y + 1.4))
		cachettes.append(_l(c.x, plancher, c.y - 1.4))
	# bureau (coin x 6..12, z -8..-3) : cloison avec ouverture, table, registre
	_boite(Vector3(0.1, 3.0, 3.6), _l(6.0, plancher + 1.5, -hz + 1.8), cloison)
	_boite(Vector3(6.0, 3.0, 0.1), _l(hx - 3.0 + 0.0, plancher + 1.5, -3.0), cloison)
	_boite(Vector3(1.6, 0.8, 0.8), _l(9.5, plancher + 0.4, -6.4), caisse)
	var registre := _boite(Vector3(0.36, 0.05, 0.26), _l(9.5, plancher + 0.83, -6.4), _mat("wood_peeling_paint_weathered", 2.0, Color(0.3, 0.1, 0.08)), false)
	registre.name = "Registre"
	# chambre froide (coin x -12..-5, z 3..8) : murs isolés blancs, porte verrouillée
	var froid := _mat("concrete_pavement", 0.6, Color(0.85, 0.88, 0.9), 0.6)
	_boite(Vector3(0.15, 3.0, 5.0), _l(-5.0, plancher + 1.5, hz - 2.5), froid)
	_boite(Vector3(2.8, 3.0, 0.15), _l(-hx + 1.4, plancher + 1.5, 3.0), froid)
	_boite(Vector3(2.8, 3.0, 0.15), _l(-6.4, plancher + 1.5, 3.0), froid)
	_boite(Vector3(7.0, 0.15, 5.0), _l(-hx + 3.5, plancher + 3.0, hz - 2.5), froid, false)
	porte_froide = _boite(Vector3(1.4, 2.3, 0.12), _l(-8.5, plancher + 1.15, 3.0), _mat("rusty_corrugated_iron", 0.6, Color(0.7, 0.75, 0.8), 0.4))
	porte_froide.name = "PorteFroide"
	# sacs de jute : 12 sacs de semences (manioc, maïs, cacao)
	mat_toile = StandardMaterial3D.new()
	mat_toile.albedo_texture = load("res://data/textures/roseaux_diff.jpg")
	mat_toile.uv1_triplanar = true
	mat_toile.uv1_scale = Vector3.ONE * 3.0
	mat_toile.albedo_color = Color(0.78, 0.66, 0.46)
	mat_toile.roughness = 0.95
	for i in SACS:
		var sac := MeshInstance3D.new()
		sac.mesh = _maillage_sac()
		sac.material_override = mat_toile
		add_child(sac)
		var col := i % 4
		@warning_ignore("integer_division")
		var rang := i / 4
		sac.global_transform = Transform3D(base.basis.rotated(Vector3.UP, randf_range(-0.2, 0.2)), _l(-11.0 + col * 0.95, plancher + 0.22 + rang * 0.42, 6.6 - (rang % 2) * 0.2))
		tas_sacs.append(sac)
	# trappe dans le plancher, près de la chambre froide (dessous : Ama et sa pirogue)
	var trappe := _boite(Vector3(1.2, 0.04, 1.2), _l(-3.0, plancher + 0.02, 6.2), _mat("weathered_brown_planks", 1.0, Color(0.45, 0.35, 0.28)), false)
	trappe.name = "Trappe"
	# éclairage : quatre lampes et leurs néons, alimentés par le groupe électrogène
	var neon := StandardMaterial3D.new()
	neon.emission_enabled = true
	neon.emission = Color(0.85, 0.95, 1.0)
	neon.emission_energy_multiplier = 3.0
	neon.albedo_color = Color(0.9, 0.95, 1.0)
	for c in [Vector2(-7, -3), Vector2(4, -3), Vector2(-4, 4), Vector2(6, 3)]:
		var l := OmniLight3D.new()
		l.light_color = Color(0.85, 0.93, 1.0)
		l.light_energy = 2.2
		l.omni_range = 11.0
		l.shadow_enabled = false
		add_child(l)
		l.global_position = _l(c.x, plancher + 4.3, c.y)
		lampes.append(l)
		var tube := _boite(Vector3(1.2, 0.05, 0.08), _l(c.x, plancher + 4.45, c.y), neon, false)
		neons.append(tube)


func _maillage_sac() -> Mesh:
	var c := CapsuleMesh.new()
	c.radius = 0.24
	c.height = 0.86
	c.radial_segments = 10
	c.rings = 4
	return c


var deguise := false
var arme_cachee := false
var poissons := Vector3.ZERO
var caisse_poisson: MeshInstance3D


func _quai() -> void:
	var vq: Node = main.get_node_or_null("VieQuotidienne")
	var k := _l(-16.0, 0, -PROF * 0.5 - 15.5)
	k.y = terrain.hauteur(k.x, k.z)
	if vq:
		# Kwame « Tournevis » bricole une moto sur le quai : il fera diversion à la fin
		var moto: Node3D = (load("res://vehicules/moto.glb") as PackedScene).instantiate()
		add_child(moto)
		moto.global_transform = Transform3D(base.basis.rotated(Vector3.UP, 0.4), k + base.basis.x * 1.2)
		vq._perso("kwame", "Reparer", k, atan2(base.basis.x.x, base.basis.x.z))
	# caisses de poisson des dockers, près de la porte
	poissons = _l(-19.0, 0, -PROF * 0.5 - 14.0)   # sur le quai, près de Kwame, hors de vue des gardes
	poissons.y = terrain.hauteur(poissons.x, poissons.z)
	var bleu := StandardMaterial3D.new()
	bleu.albedo_color = Color(0.15, 0.35, 0.6)
	bleu.roughness = 0.6
	for i in 5:
		var mi := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = Vector3(0.6, 0.32, 0.42)
		mi.mesh = bx
		mi.material_override = bleu
		add_child(mi)
		@warning_ignore("integer_division")
		mi.global_transform = Transform3D(base.basis.rotated(Vector3.UP, randf_range(-0.3, 0.3)), poissons + Vector3((i % 3) * 0.65 - 0.65, 0.16 + (i / 3) * 0.33, 0))
	var lab := Label3D.new()
	lab.text = "Caisses de poisson (F : se faire passer pour un docker)"
	lab.font_size = 36
	lab.pixel_size = 0.004
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.no_depth_test = true
	lab.name = "AidePoisson"
	add_child(lab)
	lab.global_position = poissons + Vector3(0, 1.4, 0)


func _deguiser() -> void:
	deguise = true
	joueur.charge = true
	caisse_poisson = MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(0.6, 0.32, 0.42)
	caisse_poisson.mesh = bx
	var bleu := StandardMaterial3D.new()
	bleu.albedo_color = Color(0.15, 0.35, 0.6)
	caisse_poisson.material_override = bleu
	joueur.add_child(caisse_poisson)
	caisse_poisson.position = Vector3(0.1, 1.75, 0)
	# le fusil reste chez Kwame : un docker n'est pas armé
	if joueur.a_une_arme:
		arme_cachee = true
		joueur.a_une_arme = false
		if joueur.arme:
			joueur.arme.visible = false
	m4._annoncer("Une caisse de poisson sur la tête, le fusil caché chez Kwame : vous êtes un docker. Entrez par la grande porte, sans courir ni traîner près des gardes. Posez la caisse (F près des caisses de l'entrepôt).", 6.0)


func _fin_deguisement(raison: String) -> void:
	if not deguise:
		return
	deguise = false
	joueur.charge = porte_sac != null
	if caisse_poisson:
		caisse_poisson.queue_free()
		caisse_poisson = null
	if arme_cachee:
		arme_cachee = false
		joueur.a_une_arme = true
		if joueur.arme:
			joueur.arme.visible = true
	m4._annoncer(raison, 3.0)


func _ama() -> void:
	# Ama attend sous la trappe, assise dans sa pirogue
	var vq := main.get_node_or_null("VieQuotidienne")
	var p := _l(-3.0, 0, 6.2)
	if vq:
		var pir := MeshInstance3D.new()
		pir.mesh = vq._pirogue_maillage()
		add_child(pir)
		pir.global_transform = Transform3D(base.basis.rotated(Vector3.UP, PI * 0.5), Vector3(p.x, -0.22, p.z))
	var ama: Node3D = (load("res://personnages/femme2.glb") as PackedScene).instantiate()
	Apparence.ameliorer(ama)
	add_child(ama)
	ama.global_transform = Transform3D(base.basis.rotated(Vector3.UP, PI * 0.5), Vector3(p.x, -0.05, p.z) + base.basis.x * 1.2)
	var ap: AnimationPlayer = ama.find_child("AnimationPlayer", true, false)
	ap.play("Repos")


# ---------------------------------------------------------------------
# Déroulement
# ---------------------------------------------------------------------
func porte() -> Vector3:
	return _l(-6.0, plancher, -PROF * 0.5 - 1.5)


func _trappe() -> Vector3:
	return _l(-3.0, plancher, 6.2)


func _dedans(p: Vector3) -> bool:
	var q := base.affine_inverse() * Vector3(p.x, 0, p.z)
	return absf(q.x) < LONG * 0.5 and absf(q.z) < PROF * 0.5 and p.y > plancher - 0.6


func disponible() -> void:
	if phase != Phase.INDISPONIBLE:
		return
	phase = Phase.DISPONIBLE
	var ca: Node = main.get_node_or_null("Carte")
	if ca:
		ca.poser_balise(porte())


func demarrer() -> void:
	phase = Phase.EN_COURS
	joueur.mission = self
	_placer_gardes()
	# la mission se joue de nuit, comme prévu par Ama et Kwame
	var amb: Ambiances = main.ambiances
	var garde := 0
	while amb.index != 3 and garde < 6:
		amb.suivante()
		garde += 1
	m4._annoncer("Mission 5 — Les Graines", 4.0)
	m4._objectif("Reprendre les 12 sacs de semences de la coopérative (chambre froide de l'entrepôt). Sans être vu : C pour s'accroupir, X pour lancer un caillou, F au groupe électrogène pour couper la lumière.")
	@warning_ignore("missing_await")
	_radio("AMA", "Je suis sous les pilotis, sous la trappe. Passe par l'eau, ou par la porte si tu es fou.", 0.5)
	@warning_ignore("missing_await")
	_radio("KWAME", "Le groupe électrogène est derrière. Coupe-le : deux minutes de noir. Pas plus. C'est moi qui l'ai réparé…", 7.0)


func _radio(qui: String, texte: String, delai: float) -> void:
	await get_tree().create_timer(delai).timeout
	m4._annoncer("%s (radio) — %s" % [qui, texte], 5.5)


func _placer_gardes() -> void:
	for g in gardes:
		if is_instance_valid(g):
			g.queue_free()
	gardes.clear()
	var rondes := [
		[Vector2(-6, -11), Vector2(10, -11)],                          # dehors, devant la façade
		[Vector2(13.5, -6), Vector2(13.5, 6)],                          # dehors, le long du flanc
		[Vector2(-10, -1), Vector2(9, -1)],                              # allée centrale
		[Vector2(-4, 5.5), Vector2(4, 5.5), Vector2(4, -0.5)],          # côté mer
		[Vector2(8.5, -5), Vector2(8.5, -5.1)],                          # bureau (assis)
		[Vector2(-1, -6.5), Vector2(-10.5, -6.5)],                       # côté porte
	]
	var modeles := ["homme2", "villageois", "homme3"]
	for i in rondes.size():
		var pts: Array = []
		for q in rondes[i]:
			var dehors := absf(q.x) > LONG * 0.5 or absf(q.y) > PROF * 0.5
			var p := _l(q.x, 0, q.y)
			p.y = terrain.hauteur(p.x, p.z) if dehors else plancher
			pts.append(p)
		var g := Pnj.new()
		add_child(g)
		g.global_position = pts[0] + Vector3(0, 0.3, 0)
		g.preparer("milicien", self, joueur, Color(1, 1, 1), "res://data/textures/camouflage.jpg", modeles[i % 3])
		g.points_patrouille = pts
		g.zone_interdite = true
		g.alerte.connect(func(_p: Vector3) -> void: _donner_alarme("Un garde vous a vu !"))
		g.rendu.connect(func(_n: Pnj) -> void: m4._annoncer("Le garde se rend : F pour le ligoter.", 2.5))
		# lampe torche, allumée seulement dans le noir
		var torche := SpotLight3D.new()
		torche.spot_range = 14.0
		torche.spot_angle = 24.0
		torche.light_energy = 2.5
		torche.light_color = Color(1.0, 0.95, 0.8)
		torche.position = Vector3(0.2, 1.35, 0.3)
		torche.rotation = Vector3(-0.15, PI, 0)
		torche.visible = false
		torche.name = "Torche"
		g.corps.add_child(torche)
		gardes.append(g)


func _donner_alarme(raison: String) -> void:
	if alarme:
		return
	alarme = true
	for g in gardes:
		if (g as Pnj).est_actif():
			(g as Pnj)._passer_combat()
	m4._annoncer("ALARME — %s Fuyez avec ce qui est déjà descendu." % raison, 5.0)
	m4._objectif("Alarme : fuyez (éloignez-vous de l'entrepôt). %d sac(s) déjà sauvé(s)." % sacs_livres)


# ---------- ce que les Pnj demandent à leur mission ----------
func choisir_couvert(n: Pnj) -> Vector3:
	var best := n.global_position
	var dmin := 18.0
	for c in cachettes:
		var oppose: Vector3 = (c as Vector3) - joueur.global_position
		oppose.y = 0
		if oppose.length() < 3.0:
			continue
		var d := (c as Vector3).distance_to(n.global_position)
		if d < dmin:
			dmin = d
			best = c
	return best


func bruit_de_tir(p: Vector3, _joueur_tire := false) -> void:
	if phase != Phase.EN_COURS:
		return
	for g in gardes:
		(g as Pnj).entendre(p, 80.0)
	if p.distance_to(porte()) < 60.0:
		_donner_alarme("Coup de feu !")


func blessure() -> void:
	m4.blessure()


# ---------- interactions (F) ----------
func interagir() -> void:
	if phase != Phase.EN_COURS:
		m4.interagir()
		return
	var jp := joueur.global_position
	if porte_corps:
		_poser_corps()
		return
	if not deguise and not porte_sac and jp.distance_to(poissons) < 2.5 and not alarme:
		_deguiser()
		return
	if deguise and _dedans(jp):
		for c in cachettes:
			if jp.distance_to(c) < 2.5:
				_fin_deguisement("Vous posez la caisse de poisson contre les autres. Désormais, si on vous voit, vous êtes un intrus.")
				return
	if porte_sac:
		if jp.distance_to(_trappe()) < 2.2:
			_livrer_sac()
		else:
			m4._annoncer("Portez le sac jusqu'à la trappe, près de la chambre froide.", 2.0)
		return
	# maîtriser un garde de dos, ou ligoter un garde qui se rend
	var meilleur: Pnj = null
	var dmin := 2.0
	for g in gardes:
		var p := g as Pnj
		var d := p.global_position.distance_to(jp)
		if d < dmin and (p.etat == Pnj.Etat.RENDU or (p.est_actif() and p.dos_au_joueur())):
			meilleur = p
			dmin = d
	if meilleur:
		meilleur.ligoter()
		m4._annoncer("Garde maîtrisé en silence. F pour le traîner à l'abri des regards.", 2.5)
		return
	# traîner un garde ligoté
	for g in gardes:
		var p := g as Pnj
		if p.etat == Pnj.Etat.LIGOTE and p.global_position.distance_to(jp) < 1.8:
			porte_corps = p
			joueur.charge = true
			m4._annoncer("Vous traînez le garde : F derrière une pile de caisses pour l'y cacher.", 2.5)
			return
	# couper le groupe électrogène
	var groupe: Node3D = get_node("Groupe")
	if jp.distance_to(groupe.global_position) < 2.6 and noir <= 0.0:
		_couper_courant()
		return
	# chambre froide
	if not chambre_ouverte and jp.distance_to(porte_froide.global_position) < 2.0:
		crochetage = 0.0
		m4._annoncer("Crochetage… restez immobile.", 3.0)
		return
	if chambre_ouverte and sacs_restants > 0 and jp.distance_to(_l(-9.6, plancher, 6.5)) < 2.6:
		_prendre_sac()
		return
	# registre des chargements
	var registre: Node3D = get_node("Registre")
	if not preuve and jp.distance_to(registre.global_position) < 2.0:
		preuve = true
		var tel: Node = main.get_node_or_null("Telephone")
		if tel:
			tel.ajouter_preuve("Registre de l'entrepôt n° 3", "Chargements nocturnes vers Lagunaville, déclarés « marchandises agricoles ». Signatures du Front du Cobra et du Syndicat des Docks.")
		m4._annoncer("PREUVE — Registre des chargements nocturnes vers Lagunaville : « marchandises agricoles ». Le Cobra et le Syndicat des Docks sont liés.", 6.0)
		return
	# monter par la trappe depuis l'eau (ou redescendre)
	var t := _trappe()
	var plat := Vector2(jp.x - t.x, jp.z - t.z).length()
	if plat < 2.5 and jp.y < plancher - 0.8:
		joueur.global_position = t + base.basis.x * 1.2 + Vector3(0, 0.3, 0)
		joueur.velocity = Vector3.ZERO
		m4._annoncer("Vous vous hissez par la trappe.", 2.0)
		return
	if plat < 1.6 and jp.y > plancher - 0.5:
		joueur.global_position = Vector3(t.x, -1.0, t.z) + base.basis.x * 2.0
		m4._annoncer("Vous vous laissez glisser dans l'eau.", 2.0)
		return
	m4.interagir()


func _couper_courant() -> void:
	noir = NOIR
	_lumiere(false)
	(get_node("Groupe/Son") as AudioStreamPlayer3D).stop()
	m4._annoncer("Courant coupé : deux minutes de noir. Les gardes allument leurs torches.", 3.5)


func _lumiere(allume: bool) -> void:
	for l in lampes:
		(l as OmniLight3D).visible = allume
	for n in neons:
		((n as MeshInstance3D).material_override as StandardMaterial3D).emission_enabled = allume
	for g in gardes:
		var t: Node3D = (g as Pnj).corps.get_node_or_null("Torche")
		if t:
			t.visible = not allume and (g as Pnj).est_actif()


func _prendre_sac() -> void:
	sacs_restants -= 1
	var s: MeshInstance3D = tas_sacs.pop_back()
	s.queue_free()
	porte_sac = MeshInstance3D.new()
	porte_sac.mesh = _maillage_sac()
	porte_sac.material_override = mat_toile
	joueur.add_child(porte_sac)
	porte_sac.position = Vector3(0.15, 1.55, 0.05)
	porte_sac.rotation = Vector3(0, 0, PI * 0.5)
	joueur.charge = true
	m4._annoncer("Sac de semences sur l'épaule : jusqu'à la trappe (F).", 2.0)


func _livrer_sac() -> void:
	porte_sac.queue_free()
	porte_sac = null
	joueur.charge = false
	sacs_livres += 1
	m4._annoncer("AMA — Reçu. %d / %d." % [sacs_livres, SACS], 2.0)
	if sacs_livres >= SACS:
		_reussite(true)
	else:
		m4._objectif("Sacs descendus à Ama : %d / %d." % [sacs_livres, SACS])


func _poser_corps() -> void:
	var cache := false
	for c in cachettes:
		if joueur.global_position.distance_to(c) < 2.2:
			cache = true
	porte_corps.global_position = joueur.global_position - _devant() * 0.9
	if cache:
		porte_corps.etat = Pnj.Etat.CACHE
		porte_corps.visible = false
		m4._annoncer("Garde caché derrière les caisses.", 2.0)
	else:
		m4._annoncer("Garde posé à découvert : s'il est vu, l'alerte sera donnée.", 2.5)
	porte_corps = null
	joueur.charge = porte_sac != null


func _devant() -> Vector3:
	return Vector3(-sin(joueur.lacet), 0, -cos(joueur.lacet))


func _reussite(complete: bool) -> void:
	phase = Phase.TERMINEE
	joueur.mission = m4
	joueur.charge = false
	if complete:
		@warning_ignore("missing_await")
		_radio("KWAME", "J'ai fait péter le pot d'échappement de ma moto sur le quai. C'était un accident ! Enfin non, c'était exprès, mais j'ai eu peur quand même !", 0.5)
		m4._annoncer("MISSION RÉUSSIE — les 12 sacs de semences sont sauvés.\nKwame « Tournevis » rejoint les Racines.", 7.0)
	else:
		m4._annoncer("RÉUSSITE PARTIELLE — %d sac(s) sauvé(s) sur 12 : la coopérative démarrera plus lentement." % sacs_livres, 7.0)
	m4.confiance = clampi(m4.confiance + (8 if complete else 3), 0, 100)
	m4._objectif("Prochain objectif : apporter les semences à Bomé (mission 6).")


func _process(delta: float) -> void:
	if joueur == null or m4 == null:
		return
	match phase:
		Phase.INDISPONIBLE:
			if m4.phase == Mission4.Phase.LIBERE:
				disponible()
		Phase.DISPONIBLE:
			if joueur.global_position.distance_to(porte()) < 130.0:
				demarrer()
		Phase.EN_COURS:
			_en_cours(delta)


func _en_cours(delta: float) -> void:
	var jp := joueur.global_position
	# vue des gardes : réduite dans le noir (la nuit dehors, dans l'entrepôt quand le courant est coupé)
	var nuit: bool = (main.ambiances as Ambiances).LISTE[(main.ambiances as Ambiances).index]["nuit"] > 0.5
	var faris_dedans := _dedans(jp)
	var ql := base.affine_inverse() * Vector3(jp.x, 0, jp.z)
	var zone_privee := (ql.x > 6.0 and ql.z < -3.0) or (ql.x < -5.0 and ql.z > 3.0)
	var louche := joueur.accroupi or joueur.vitesse_affichee > 3.0 or zone_privee
	if deguise and alarme:
		_fin_deguisement("Le déguisement ne trompe plus personne.")
	for g in gardes:
		var p := g as Pnj
		var colle := p.global_position.distance_to(jp) < 2.5
		p.zone_interdite = faris_dedans and (not deguise or louche or colle)
		p.tolere = deguise and not louche and not colle
		var dedans := _dedans(p.global_position)
		var vue := 26.0
		if dedans and noir > 0.0:
			vue = 7.0
		elif not dedans and nuit:
			vue = 12.0
		p.portee_vue = vue
	# lumière : le groupe redémarre tout seul
	if noir > 0.0:
		noir -= delta
		if noir <= 0.0:
			_lumiere(true)
			(get_node("Groupe/Son") as AudioStreamPlayer3D).play()
			m4._annoncer("Le groupe électrogène redémarre : la lumière revient.", 3.0)
	# crochetage : rester immobile 3 secondes devant la porte
	if crochetage >= 0.0:
		if jp.distance_to(porte_froide.global_position) > 2.2 or Vector2(joueur.velocity.x, joueur.velocity.z).length() > 0.5:
			crochetage = -1.0
			m4._annoncer("Crochetage interrompu.", 1.5)
		else:
			crochetage += delta
			if crochetage >= 3.0:
				crochetage = -1.0
				chambre_ouverte = true
				porte_froide.visible = false
				for c in porte_froide.get_children():
					c.queue_free()
				m4._annoncer("Serrure crochetée : la chambre froide est ouverte. F aux sacs.", 3.0)
	# garde traîné
	if porte_corps:
		porte_corps.global_position = jp - _devant() * 0.9 + Vector3(0, 0.05, 0)
	# un garde actif qui découvre un camarade ligoté à découvert donne l'alerte
	if not alarme:
		for g in gardes:
			var p := g as Pnj
			if not p.est_actif():
				continue
			for h in gardes:
				var q := h as Pnj
				if q == p or q == porte_corps or q.etat != Pnj.Etat.LIGOTE:
					continue
				var d := p.global_position.distance_to(q.global_position)
				if d < minf(9.0, p.portee_vue) and p.regard.dot((q.global_position - p.global_position).normalized()) > 0.3:
					_donner_alarme("Un garde a trouvé son camarade ligoté !")
					break
	# fuite après l'alarme
	if alarme:
		var loin := jp.distance_to(porte()) > 90.0
		t_loin = t_loin + delta if loin else 0.0
		if t_loin > 3.0:
			if sacs_livres > 0:
				_reussite(false)
			else:
				m4._annoncer("Les semences restent aux mains du Cobra. Revenez quand l'alerte sera retombée.", 5.0)
				_reprendre_plus_tard()


func _reprendre_plus_tard() -> void:
	phase = Phase.DISPONIBLE
	alarme = false
	t_loin = 0.0
	joueur.mission = m4
	if porte_sac:
		porte_sac.queue_free()
		porte_sac = null
		sacs_restants += 1
		var s := MeshInstance3D.new()
		s.mesh = _maillage_sac()
		s.material_override = mat_toile
		add_child(s)
		s.global_position = _l(-9.6, plancher + 0.25, 6.5)
		tas_sacs.append(s)
	joueur.charge = false
	for g in gardes:
		if is_instance_valid(g):
			g.queue_free()
	gardes.clear()
	if noir > 0.0:
		noir = 0.0
		_lumiere(true)


func _unhandled_input(event: InputEvent) -> void:
	if phase != Phase.EN_COURS or not event.is_action_pressed("lancer") or joueur.mort or joueur.a_cheval:
		return
	# caillou lancé là où l'on regarde (au plus 18 m) : le garde le plus proche du point de chute va voir
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var de := cam.global_position
	var vers := de - cam.global_transform.basis.z * 18.0
	var q := PhysicsRayQueryParameters3D.create(de, vers, 1)
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	var chute: Vector3 = r["position"] if not r.is_empty() else vers
	var son := AudioStreamPlayer3D.new()
	son.stream = load("res://sons/impact.wav")
	son.unit_size = 3.0
	add_child(son)
	son.global_position = chute
	son.play()
	son.finished.connect(son.queue_free)
	var proche: Pnj = null
	var dmin := 14.0
	for g in gardes:
		var p := g as Pnj
		var d := p.global_position.distance_to(chute)
		if p.etat == Pnj.Etat.CALME and d < dmin:
			dmin = d
			proche = p
	if proche:
		proche.intriguer(chute, 14.0)

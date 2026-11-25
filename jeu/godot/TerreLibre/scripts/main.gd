## Scène principale : assemble l'île, la mer, la lumière, la végétation, Faris et l'interface.
extends Node3D

const LIEUX := [
	["Port-Néré", 225, 235], ["Quai et entrepôts", 170, 268], ["Piste d'atterrissage", 262, 215],
	["Phare de la Pointe", 326, 232], ["Plantations", 212, 322], ["Bomé", 228, 372], ["Akwéri", 168, 392],
	["Lac du cratère", 290, 356], ["Mont Talanké", 347, 442], ["Tikané", 405, 470],
	["Camp du Cobra", 452, 540], ["Baie du Sud", 380, 628],
]

var terrain: Terrain
var joueur: Joueur
var ambiances: Ambiances
var pluie: CPUParticles3D
var etiquette: Label
var aide: Label
var lieu_actuel := ""
var ville: VillePortNere
var bome: VillageBome


func centre_bome() -> Vector2:
	return carte_vers_monde(228, 372) + Vector2(-170, 110)


## Coordonnées de la carte de référence (image de 700 px) vers le monde (mètres).
static func carte_vers_monde(px: float, py: float) -> Vector2:
	return Vector2((px / 700.0 - 0.5) * Terrain.TAILLE, (py / 700.0 - 0.5) * Terrain.TAILLE)


func _ready() -> void:
	_actions_clavier()
	terrain = Terrain.new()
	terrain.name = "Terrain"
	# Akwéri : position du blockout (jeu/prototype/blockout_akweri.py, pixel 484 × 1129 de la heightmap)
	var akweri := Vector2((484.0 / 2016.0 - 0.5) * Terrain.TAILLE, (1129.0 / 2016.0 - 0.5) * Terrain.TAILLE)
	terrain.aplanissements = [{"centre": akweri, "avant_min": -80.0, "avant_max": 6.0, "cote": 58.0, "marge": 32.0, "base": 1.3, "pente": 0.15}]
	# Port-Néré : relief adouci sous la ville
	var port_nere := carte_vers_monde(225, 235)
	terrain.lissages = [{"centre": port_nere + Vector2(-20, 20), "rayon": 340.0, "passes": 3}]
	# Bomé : village en terrasses sur la colline (plan préparé avant le terrain)
	var plan_bome := VillageBome.preparer_plan(centre_bome())
	terrain.plateformes = plan_bome["plateformes"]
	add_child(terrain)
	_mer()
	var env := _environnement()
	var soleil := _soleil()
	var proche := VegetationProche.new()
	proche.name = "VegetationProche"
	var veg := Vegetation.new()
	veg.proche = proche
	veg.name = "Vegetation"
	add_child(veg)
	proche.preparer(terrain, null, _zones_construites())
	veg.construire(terrain, _zones_construites())
	add_child(proche)
	var village := VillageAkweri.new()
	village.name = "Akweri"
	add_child(village)
	var mer: Vector2 = terrain.aplanissements[0]["mer"]
	village.construire(terrain, akweri, mer, veg)
	ville = VillePortNere.new()
	ville.name = "PortNere"
	add_child(ville)
	ville.construire(terrain, port_nere, veg)
	proche.villes.append(ville)
	bome = VillageBome.new()
	bome.name = "Bome"
	add_child(bome)
	bome.construire_bome(terrain, plan_bome, veg, proche)
	proche.villes.append(bome)
	joueur = Joueur.new()
	joueur.name = "Faris"
	add_child(joueur)
	# départ de la mission 4, sur les hauteurs d'Akwéri
	var d3: Vector3 = village.reperes["depart"][0]
	joueur.global_position = d3 + Vector3(0, 0.5, 0)
	joueur.lacet = atan2(-mer.x, -mer.y)
	pluie = _pluie()
	ambiances = Ambiances.new()
	ambiances.name = "Ambiances"
	add_child(ambiances)
	ambiances.mer_mat = ($Mer as MeshInstance3D).mesh.material
	var circulation := Circulation.new()
	circulation.name = "Circulation"
	add_child(circulation)
	circulation.construire(ville, joueur)
	proche.joueur = joueur
	var oiseaux := Oiseaux.new()
	oiseaux.name = "Mouettes"
	add_child(oiseaux)
	oiseaux.preparer(terrain, joueur)
	ambiances.eclairages.append(oiseaux)
	var vie := VieQuotidienne.new()
	vie.name = "VieQuotidienne"
	add_child(vie)
	vie.port_nere(ville)
	var son := AmbianceSonore.new()
	son.name = "AmbianceSonore"
	add_child(son)
	ambiances.eclairages.append(son)
	ambiances.eclairages.append(ville)
	ambiances.eclairages.append(circulation)
	ambiances.preparer(soleil, env, terrain.materiau(), pluie)
	var mission := Mission4.new()
	mission.name = "Mission4"
	add_child(mission)
	mission.demarrer(village, joueur)
	(get_node("VieQuotidienne") as VieQuotidienne).akweri(village, mission)
	(get_node("VieQuotidienne") as VieQuotidienne).bome(bome)
	(get_node("AmbianceSonore") as AmbianceSonore).bome = bome
	(get_node("AmbianceSonore") as AmbianceSonore).preparer(terrain, joueur, ville, ambiances, get_node("VegetationProche"), get_node("Mouettes"))
	_interface()


func _actions_clavier() -> void:
	# touches physiques : fonctionne en AZERTY (Z Q S D) comme en QWERTY (W A S D)
	var touches := {
		"avancer": [KEY_W, KEY_UP], "reculer": [KEY_S, KEY_DOWN], "gauche": [KEY_A, KEY_LEFT],
		"droite": [KEY_D, KEY_RIGHT], "courir": [KEY_SHIFT], "sauter": [KEY_SPACE], "ambiance": [KEY_N],
		"aller_port_nere": [KEY_P], "aller_bome": [KEY_B],
	}
	for action in touches:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in touches[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)


## Zones laissées libres pour les bâtiments : Port-Néré, villages, camp, piste d'atterrissage.
func _zones_construites() -> Array:
	var zones := []
	for z in [[225, 235, 260.0], [170, 268, 90.0], [405, 470, 90.0], [452, 540, 110.0], [326, 232, 50.0], [290, 356, 185.0]]:
		var c := carte_vers_monde(z[0], z[1])
		zones.append(Vector3(c.x, c.y, z[2]))
	var ap: Dictionary = terrain.aplanissements[0]
	var ca: Vector2 = ap["centre"] + (ap["mer"] as Vector2) * -32.0
	zones.append(Vector3(ca.x, ca.y, 78.0))
	var cb := centre_bome()
	zones.append(Vector3(cb.x, cb.y, 125.0))  # village de Bomé et ses champs
	for i in 12:
		var c := carte_vers_monde(lerpf(198, 326, i / 11.0), lerpf(214, 218, i / 11.0))
		zones.append(Vector3(c.x, c.y, 45.0))
	return zones


func _terre_ferme(p: Vector2) -> Vector2:
	if terrain.hauteur(p.x, p.y) > 2.0 and terrain.pente(p.x, p.y) < 0.3:
		return p
	for r in range(8, 600, 8):
		for i in 24:
			var a := i * TAU / 24.0
			var q := p + Vector2(cos(a), sin(a)) * r
			if terrain.hauteur(q.x, q.y) > 2.0 and terrain.pente(q.x, q.y) < 0.3:
				return q
	return p


func _mer() -> void:
	var plan := PlaneMesh.new()
	plan.size = Vector2(16000, 16000)
	plan.subdivide_width = 160
	plan.subdivide_depth = 160
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/water.gdshader")
	plan.material = mat
	var mer := MeshInstance3D.new()
	mer.name = "Mer"
	mer.mesh = plan
	mer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mer)
	# profondeur réelle pour la couleur de l'eau et l'écume
	var img := Image.create_from_data(Terrain.N, Terrain.N, false, Image.FORMAT_RF, terrain.hauteurs.to_byte_array())
	mat.set_shader_parameter("hauteurs", ImageTexture.create_from_image(img))
	mat.set_shader_parameter("taille", Terrain.TAILLE)
	mat.set_shader_parameter("relief_actif", true)
	var lac := MeshInstance3D.new()
	lac.name = "Lac"
	var disque := CylinderMesh.new()
	disque.top_radius = 175.0
	disque.bottom_radius = 175.0
	disque.height = 0.2
	disque.radial_segments = 48
	var mlac := StandardMaterial3D.new()
	mlac.albedo_color = Color(0.2, 0.38, 0.38)
	mlac.roughness = 0.1
	disque.material = mlac
	lac.mesh = disque
	var c := carte_vers_monde(290, 356)
	lac.position = Vector3(c.x, terrain.hauteur(c.x, c.y) + 0.4, c.y)
	add_child(lac)


func _environnement() -> Environment:
	var ciel := ProceduralSkyMaterial.new()
	ciel.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = ciel
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.fog_enabled = true
	env.fog_sky_affect = 0.2
	env.glow_enabled = true
	env.glow_intensity = 0.4
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	return env


func _soleil() -> DirectionalLight3D:
	var s := DirectionalLight3D.new()
	s.name = "Soleil"
	s.shadow_enabled = true
	s.directional_shadow_max_distance = 220.0
	s.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	s.directional_shadow_split_1 = 0.12  # première tranche serrée : ombres nettes près du joueur
	s.shadow_blur = 1.5  # bords d’ombre adoucis (ombre des bras sur les vêtements)
	add_child(s)
	return s


func _pluie() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Pluie"
	p.amount = 1500
	p.lifetime = 1.2
	p.emitting = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(30, 1, 30)
	p.direction = Vector3(0.15, -1, 0)
	p.spread = 3.0
	p.initial_velocity_min = 22.0
	p.initial_velocity_max = 26.0
	p.gravity = Vector3.ZERO
	var goutte := BoxMesh.new()
	goutte.size = Vector3(0.02, 0.7, 0.02)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.82, 0.88, 0.9, 0.45)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	goutte.material = m
	p.mesh = goutte
	add_child(p)
	return p


func _interface() -> void:
	var calque := CanvasLayer.new()
	add_child(calque)
	etiquette = Label.new()
	etiquette.position = Vector2(20, 16)
	etiquette.add_theme_font_size_override("font_size", 20)
	etiquette.add_theme_constant_override("outline_size", 6)
	etiquette.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	calque.add_child(etiquette)
	aide = Label.new()
	aide.text = "ZQSD : marcher · Maj : courir · C : s'accroupir · F : maîtriser / ligoter · clic droit : viser · clic gauche : tirer · R : recharger · N : ambiance · P : Port-Néré · B : Bomé · Échap : souris"
	aide.add_theme_font_size_override("font_size", 15)
	aide.add_theme_constant_override("outline_size", 5)
	aide.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	aide.anchor_top = 1.0
	aide.anchor_bottom = 1.0
	aide.offset_top = -38
	aide.offset_left = 20
	calque.add_child(aide)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("aller_bome") and bome and bome.reperes.has("place"):
		var pb: Vector3 = bome.reperes["place"]
		joueur.global_position = pb + Vector3(0, 1.0, 14)
		joueur.velocity = Vector3.ZERO
	if Input.is_action_just_pressed("aller_port_nere") and ville.reperes.has("place"):
		# déplacement rapide vers la place de l'Indépendance (en attendant les véhicules)
		var pl: Vector3 = ville.reperes["place"]
		joueur.global_position = pl + Vector3(14, 1.0, -8)
		joueur.velocity = Vector3.ZERO
	var p := joueur.global_position
	pluie.global_position = p + Vector3(0, 18, 0)
	var proche := "Île de Talanké"
	var dmin := 260.0
	for l in LIEUX:
		var c := carte_vers_monde(l[1], l[2])
		var d := Vector2(p.x, p.z).distance_to(c)
		if d < dmin:
			dmin = d
			proche = l[0]
	var mode := "nage" if joueur.nage else ("course" if joueur.vitesse_affichee > 3.0 else "à pied")
	etiquette.text = "WANZALA : FREEDOM · %s · %s · %s · %d km/h · %d i/s" % [proche, ambiances.nom(), mode, roundi(joueur.vitesse_affichee * 3.6), Engine.get_frames_per_second()]

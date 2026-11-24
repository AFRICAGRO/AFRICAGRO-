## Scène principale : assemble l'île, la mer, la lumière, la végétation, Faris et l'interface.
extends Node3D

const LIEUX := [
	["Port-Néré", 225, 235], ["Quai et entrepôts", 170, 268], ["Piste d'atterrissage", 262, 215],
	["Phare de la Pointe", 326, 232], ["Plantations", 212, 322], ["Bomé", 228, 372], ["Akwéri", 182, 420],
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


## Coordonnées de la carte de référence (image de 700 px) vers le monde (mètres).
static func carte_vers_monde(px: float, py: float) -> Vector2:
	return Vector2((px / 700.0 - 0.5) * Terrain.TAILLE, (py / 700.0 - 0.5) * Terrain.TAILLE)


func _ready() -> void:
	_actions_clavier()
	terrain = Terrain.new()
	terrain.name = "Terrain"
	add_child(terrain)
	_mer()
	var env := _environnement()
	var soleil := _soleil()
	var veg := Vegetation.new()
	veg.name = "Vegetation"
	add_child(veg)
	veg.construire(terrain, _zones_construites())
	joueur = Joueur.new()
	joueur.name = "Faris"
	add_child(joueur)
	var depart := _terre_ferme(carte_vers_monde(225, 235))
	joueur.global_position = Vector3(depart.x, terrain.hauteur(depart.x, depart.y) + 0.5, depart.y)
	pluie = _pluie()
	ambiances = Ambiances.new()
	ambiances.name = "Ambiances"
	add_child(ambiances)
	ambiances.mer_mat = ($Mer as MeshInstance3D).mesh.material
	ambiances.preparer(soleil, env, terrain.materiau(), pluie)
	_interface()


func _actions_clavier() -> void:
	# touches physiques : fonctionne en AZERTY (Z Q S D) comme en QWERTY (W A S D)
	var touches := {
		"avancer": [KEY_W, KEY_UP], "reculer": [KEY_S, KEY_DOWN], "gauche": [KEY_A, KEY_LEFT],
		"droite": [KEY_D, KEY_RIGHT], "courir": [KEY_SHIFT], "sauter": [KEY_SPACE], "ambiance": [KEY_N],
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
	for z in [[225, 235, 260.0], [170, 268, 90.0], [182, 420, 130.0], [228, 372, 110.0], [405, 470, 90.0], [452, 540, 110.0], [326, 232, 50.0], [290, 356, 185.0]]:
		var c := carte_vers_monde(z[0], z[1])
		zones.append(Vector3(c.x, c.y, z[2]))
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
	aide.text = "Cliquer : contrôler la caméra · ZQSD/WASD : marcher · Maj : courir · Espace : sauter · N : changer d'ambiance · Échap : libérer la souris"
	aide.add_theme_font_size_override("font_size", 15)
	aide.add_theme_constant_override("outline_size", 5)
	aide.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	aide.anchor_top = 1.0
	aide.anchor_bottom = 1.0
	aide.offset_top = -38
	aide.offset_left = 20
	calque.add_child(aide)


func _process(_delta: float) -> void:
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

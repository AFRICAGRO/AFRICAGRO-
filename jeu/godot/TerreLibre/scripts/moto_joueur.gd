## La moto de Faris (moto-taxi de type « Bajaj »/« Haojue », très courante dans la région).
## E tout près pour enfourcher ou descendre. En selle : Z pour accélérer, S pour freiner puis reculer
## lentement, Q / D (ou la souris) pour tourner ; Maj pour pousser le moteur.
## La moto penche dans les virages, se cabre légèrement à l'accélération, suit les pentes, monte les trottoirs
## bas ; le moteur change de régime avec la vitesse. Le phare s'allume la nuit.
class_name MotoJoueur
extends CharacterBody3D

const VMAX := 15.0          # m/s (54 km/h) : une 125 cm³ chargée sur des routes en latérite
const VMAX_POUSSE := 19.0   # Maj : moteur poussé (68 km/h)
const ACCEL := 4.2
const FREIN := 9.0
const RECUL := 1.6
const PORTEE := 2.2

var joueur: Node3D
var modele: Node3D
var assiette: Node3D       # pivot de l'inclinaison (virages) et du tangage (pente, accélération)
var roues: Array = []
var pilote: Node3D
var monte := false
var vitesse := 0.0
var cap := 0.0
var penche := 0.0
var cabre := 0.0
var gravite: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var moteur: AudioStreamPlayer3D
var phare: SpotLight3D
var aide: Label3D
var vmax_bonus := 1.0       # la moto gonflée par Kwame (mission 10)
var accel_bonus := 1.0
var tir_embarque := false   # Faris peut viser (clic droit) et tirer en roulant


func preparer(p_joueur: Node3D, pos: Vector3, angle: float) -> void:
	joueur = p_joueur
	global_position = pos
	cap = angle
	rotation.y = cap


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.6
	floor_max_angle = deg_to_rad(40)
	var forme := CollisionShape3D.new()
	var cp := CapsuleShape3D.new()
	cp.radius = 0.3
	cp.height = 1.9
	forme.shape = cp
	forme.rotation.x = PI * 0.5        # capsule couchée dans l'axe de la moto
	forme.position.y = 0.42
	add_child(forme)
	assiette = Node3D.new()
	add_child(assiette)
	modele = (load("res://vehicules/moto.glb") as PackedScene).instantiate()
	assiette.add_child(modele)
	_peindre(modele, Color(0.55, 0.04, 0.04))
	for n in modele.find_children("Roue_*", "", true, false):
		roues.append(n)
	for m in modele.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var s: AudioStreamWAV = load("res://sons/moto.wav")
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_end = int(s.get_length() * s.mix_rate)
	moteur = AudioStreamPlayer3D.new()
	moteur.stream = s
	moteur.unit_size = 7.0
	moteur.max_distance = 90.0
	add_child(moteur)
	phare = SpotLight3D.new()
	phare.position = Vector3(0, 1.0, 0.9)
	phare.rotation = Vector3(deg_to_rad(-8), PI, 0)
	phare.spot_range = 30.0
	phare.spot_angle = 32.0
	phare.light_energy = 3.0
	phare.light_color = Color(1.0, 0.94, 0.8)
	phare.visible = false
	assiette.add_child(phare)
	aide = Label3D.new()
	aide.text = "E : enfourcher la moto"
	aide.font_size = 40
	aide.pixel_size = 0.004
	aide.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	aide.position.y = 1.7
	aide.visible = false
	aide.no_depth_test = true
	add_child(aide)


func _peindre(noeud: Node, couleur: Color) -> void:
	# la carrosserie prend la couleur de la moto de Faris
	for mi in noeud.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		for k in mesh.get_surface_count():
			var mat := mesh.surface_get_material(k) as StandardMaterial3D
			if mat and mat.resource_name == "Carrosserie":
				var m2 := mat.duplicate() as StandardMaterial3D
				m2.albedo_color = couleur
				m2.metallic = 0.35
				m2.roughness = 0.38
				(mi as MeshInstance3D).set_surface_override_material(k, m2)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("vehicule") or joueur == null:
		return
	if monte:
		descendre()
	elif joueur.get("a_cheval") == null and not joueur.get("mort") \
			and joueur.global_position.distance_to(global_position) < PORTEE:
		monter()


func monter() -> void:
	monte = true
	aide.visible = false
	joueur.set("a_cheval", self)
	(joueur.get("corps") as Node3D).visible = false
	(joueur as CollisionObject3D).collision_layer = 0
	(joueur as CollisionObject3D).collision_mask = 0
	var nuit := false
	if joueur.has_meta("nuit"):
		nuit = joueur.get_meta("nuit")
	pilote = (load("res://personnages/%s.glb" % ("faris_cheche" if nuit else "faris")) as PackedScene).instantiate()
	Apparence.ameliorer(pilote)
	assiette.add_child(pilote)
	pilote.position = Vector3(0, 0.2, -0.18)   # même assise que les motos-taxis de la ville
	var ap: AnimationPlayer = pilote.find_child("AnimationPlayer", true, false)
	ap.play("Moto")
	moteur.play()


func descendre() -> void:
	monte = false
	if pilote:
		pilote.queue_free()
		pilote = null
	vitesse = 0.0
	var sol := global_position + global_transform.basis.x * 1.0
	joueur.global_position = sol + Vector3(0, 0.3, 0)
	joueur.set("a_cheval", null)
	(joueur.get("corps") as Node3D).visible = true
	(joueur as CollisionObject3D).collision_layer = 2
	(joueur as CollisionObject3D).collision_mask = 1 | 4
	moteur.stop()


func _physics_process(delta: float) -> void:
	var cible := 0.0
	var virage := 0.0
	var gaz := 0.0
	if monte:
		var entree := Input.get_vector("gauche", "droite", "avancer", "reculer")
		gaz = -entree.y
		virage = -entree.x
		var vmax := (VMAX_POUSSE if Input.is_action_pressed("courir") else VMAX) * vmax_bonus
		if gaz > 0.2:
			cible = vmax
		elif gaz < -0.2:
			cible = -RECUL if vitesse < 0.5 else 0.0
		# on suit aussi la caméra quand on roule tout droit (souris), comme le cheval
		var vise_moto := tir_embarque and Input.is_action_pressed("viser")
		if absf(entree.x) < 0.2 and vitesse > 2.0 and gaz > 0.2 and not vise_moto:
			var lacet: float = joueur.get("lacet")
			virage = clampf(wrapf(lacet + PI - cap, -PI, PI) * 1.2, -1.0, 1.0)
	var acc := ACCEL * accel_bonus if absf(cible) > absf(vitesse) else (FREIN if gaz < -0.2 else 1.8)
	vitesse = move_toward(vitesse, cible, acc * delta)
	# braquage : serré à basse vitesse, large à grande vitesse ; pas de rotation à l'arrêt
	var taux := lerpf(2.4, 0.9, clampf(absf(vitesse) / (VMAX_POUSSE * vmax_bonus), 0.0, 1.0)) * clampf(absf(vitesse) / 1.5, 0.0, 1.0)
	cap += virage * taux * delta * signf(vitesse if vitesse != 0.0 else 1.0)
	rotation.y = cap
	var avant := Vector3(sin(cap), 0, cos(cap))
	velocity.x = avant.x * vitesse
	velocity.z = avant.z * vitesse
	if not is_on_floor():
		velocity.y -= gravite * delta
	else:
		velocity.y = -0.5
	move_and_slide()
	if is_on_wall() and absf(vitesse) > 0.3:
		var haut := global_transform.translated(Vector3(0, 0.3, 0))
		if not test_move(haut, avant * signf(vitesse) * 0.25):
			global_position += Vector3(0, 0.3, 0) + avant * signf(vitesse) * 0.1   # trottoir bas
		elif get_real_velocity().length() < absf(vitesse) * 0.3:
			vitesse *= 0.3   # vrai obstacle : la moto cale
	_assiette(delta, virage, gaz)
	for r in roues:
		(r as Node3D).rotate_object_local(Vector3.RIGHT, vitesse * delta / 0.3)
	moteur.pitch_scale = 0.7 + 0.75 * clampf(absf(vitesse) / VMAX_POUSSE, 0.0, 1.0) + 0.12 * maxf(gaz, 0.0)
	moteur.volume_db = -8.0 + 5.0 * maxf(gaz, 0.0)
	if joueur:
		var nuit := false
		if joueur.has_meta("nuit"):
			nuit = joueur.get_meta("nuit")
		phare.visible = monte and nuit
	if monte:
		joueur.global_position = global_position
		joueur.set("vitesse_affichee", absf(vitesse))
	elif joueur:
		aide.visible = joueur.get("a_cheval") == null and joueur.global_position.distance_to(global_position) < PORTEE


func _assiette(delta: float, virage: float, gaz: float) -> void:
	# inclinaison : un deux-roues penche vers l'intérieur du virage, d'autant plus qu'il va vite
	var vise_penche := -virage * clampf(absf(vitesse) / 10.0, 0.0, 1.0) * 0.38
	penche = lerpf(penche, vise_penche, 1.0 - exp(-5.0 * delta))
	# tangage : la pente du terrain sous les roues, plus un léger cabrage à l'accélération
	var vise_cabre := 0.0
	var terrain_n := get_floor_normal() if is_on_floor() else Vector3.UP
	var avant := Vector3(sin(cap), 0, cos(cap))
	vise_cabre = -asin(clampf(terrain_n.dot(avant), -0.6, 0.6))
	vise_cabre -= 0.04 * maxf(gaz, 0.0) * clampf(1.0 - absf(vitesse) / VMAX, 0.0, 1.0)
	cabre = lerpf(cabre, vise_cabre, 1.0 - exp(-6.0 * delta))
	assiette.basis = Basis.from_euler(Vector3(cabre, 0, penche))

## Faris : déplacement à la troisième personne (marche, course, saut, nage, accroupi)
## et combat (viser, tirer, recharger, prise non létale, ligoter).
## Modèle : personnages/faris.glb (MakeHuman CC0, vêtements et animations faits pour le projet).
class_name Joueur
extends CharacterBody3D

signal a_tire(position: Vector3)
signal tombe()

const MARCHE := 2.0
const COURSE := 6.0
const ACCROUPI := 1.4
const NAGE := 2.2
const SAUT := 4.6
const NIVEAU_MER := 0.0
const CHARGEUR := 30
const DEGATS := 34.0

var gravite: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var nage := false
var accroupi := false
var vise := false
var mort := false
var vitesse_affichee := 0.0
var pv := 100.0
var t_soin := 0.0

var a_une_arme := false
var munitions := CHARGEUR
var reserve := 90
var t_tir := 0.0
var t_recharge := 0.0
var cible_civile := false # le réticule passe sur un civil : tir interdit

var pivot: Node3D
var bras: SpringArm3D
var camera: Camera3D
var corps: Node3D
var anim: AnimationPlayer
var anim_haut: AnimationPlayer
var arme: Arme
var son_recharge: AudioStreamPlayer
var lacet := PI # orientation de la caméra
var tangage := -0.28
var mission: Node
var a_cheval: Node = null   # le cheval sur lequel Faris est en selle (cheval.gd le conduit)


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	floor_snap_length = 0.6
	floor_max_angle = deg_to_rad(50)
	_construire_corps()
	pivot = Node3D.new()
	pivot.position.y = 1.55
	add_child(pivot)
	pivot.top_level = true
	bras = SpringArm3D.new()
	bras.spring_length = 5.0
	bras.margin = 0.3
	bras.collision_mask = 1
	bras.add_excluded_object(get_rid())
	pivot.add_child(bras)
	camera = Camera3D.new()
	camera.fov = 62.0
	camera.far = 6000.0
	bras.add_child(camera)
	camera.current = true
	son_recharge = AudioStreamPlayer.new()
	son_recharge.stream = load("res://sons/recharge.wav")
	add_child(son_recharge)


func _construire_corps() -> void:
	corps = (load("res://personnages/faris.glb") as PackedScene).instantiate()
	Apparence.ameliorer(corps)
	add_child(corps)
	anim = corps.find_child("AnimationPlayer", true, false)
	for nom in ["Repos", "Marche", "Course", "Nage", "Accroupi", "AccroupiMarche", "Visee"]:
		if anim.has_animation(nom):
			anim.get_animation(nom).loop_mode = Animation.LOOP_LINEAR
	# second lecteur : le haut du corps vise pendant que les jambes marchent
	anim_haut = AnimationPlayer.new()
	anim.get_parent().add_child(anim_haut)
	anim_haut.root_node = anim.root_node
	anim_haut.add_animation_library("", anim.get_animation_library(""))
	for m in corps.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	anim.play("Repos")


func donner_arme() -> void:
	if a_une_arme:
		return
	a_une_arme = true
	arme = Arme.new()
	add_child(arme)
	arme.tenir(corps)


func _choisir_animation() -> void:
	var nom := "Repos"
	var vitesse_anim := 1.0
	if mort:
		nom = "Mort"
	elif nage:
		nom = "Nage"
	elif not is_on_floor() and velocity.y > -6.0 and absf(velocity.y) > 0.5:
		nom = "Saut"
	elif accroupi:
		nom = "AccroupiMarche" if vitesse_affichee > 0.25 else "Accroupi"
		vitesse_anim = maxf(1.0, vitesse_affichee / 1.2)
	elif vitesse_affichee > 3.6:
		nom = "Course"
		vitesse_anim = vitesse_affichee / 5.8
	elif vitesse_affichee > 0.25:
		nom = "Marche"
		vitesse_anim = vitesse_affichee / 1.8
	if anim.current_animation != nom:
		anim.play(nom, 0.25)
	anim.speed_scale = clampf(vitesse_anim, 0.5, 1.6)
	var haut := a_une_arme and (vise or t_tir > -0.6) and not nage and not mort
	if haut and anim_haut.current_animation != "Visee":
		anim_haut.play("Visee", 0.15)
	elif not haut and anim_haut.is_playing():
		anim_haut.stop()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens := 0.0018 if vise else 0.003
		lacet -= event.relative.x * sens
		tangage = clampf(tangage - event.relative.y * sens * 0.85, -1.2, 0.6)
	elif event.is_action_pressed("accroupir"):
		accroupi = not accroupi
	elif event.is_action_pressed("recharger"):
		_recharger()
	elif event.is_action_pressed("interagir") and mission and not mort:
		mission.interagir()


func _recharger() -> void:
	if not a_une_arme or munitions == CHARGEUR or reserve <= 0 or t_recharge > 0.0:
		return
	t_recharge = 2.0
	son_recharge.play()


func blesser(d: float) -> void:
	if mort:
		return
	pv -= d
	t_soin = 5.0
	if mission:
		mission.blessure()
	if pv <= 0.0:
		pv = 0.0
		mort = true
		velocity = Vector3.ZERO
		tombe.emit()


func ressusciter(p: Vector3) -> void:
	mort = false
	pv = 100.0
	accroupi = false
	global_position = p
	velocity = Vector3.ZERO
	if a_une_arme:
		munitions = CHARGEUR
		reserve = maxi(reserve, 60)


func _physics_process(delta: float) -> void:
	if a_cheval:
		velocity = Vector3.ZERO
		return
	if mort:
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= gravite * delta
		move_and_slide()
		_choisir_animation()
		return
	vise = a_une_arme and Input.is_action_pressed("viser") and not nage
	var entree := Input.get_vector("gauche", "droite", "avancer", "reculer")
	var dir := (Basis(Vector3.UP, lacet) * Vector3(entree.x, 0, entree.y)).normalized()
	nage = global_position.y < NIVEAU_MER - 1.25
	if nage:
		accroupi = false
	var v := NAGE
	if not nage:
		if accroupi:
			v = ACCROUPI
		elif vise:
			v = MARCHE * 1.1
		else:
			v = COURSE if Input.is_action_pressed("courir") else MARCHE
	var cible := dir * v
	var acc := 10.0 if is_on_floor() or nage else 3.0
	velocity.x = move_toward(velocity.x, cible.x, acc * v * delta)
	velocity.z = move_toward(velocity.z, cible.z, acc * v * delta)
	if nage:
		velocity.y = lerpf(velocity.y, (NIVEAU_MER - 1.15 - global_position.y) * 3.0, 0.2)
	elif not is_on_floor():
		velocity.y -= gravite * delta
	elif Input.is_action_just_pressed("sauter") and not accroupi:
		velocity.y = SAUT
	move_and_slide()
	vitesse_affichee = Vector2(velocity.x, velocity.z).length()
	# orientation du corps : vers la caméra quand on vise ou tire, sinon vers la marche
	if vise or (a_une_arme and t_tir > -0.6):
		corps.rotation.y = lerp_angle(corps.rotation.y, lacet + PI, 18.0 * delta)
	elif dir.length() > 0.1:
		corps.rotation.y = lerp_angle(corps.rotation.y, atan2(dir.x, dir.z), 12.0 * delta)
	# soins lents hors du feu
	t_soin -= delta
	if t_soin <= 0.0 and pv < 100.0:
		pv = minf(100.0, pv + 8.0 * delta)
	_combat(delta)
	_choisir_animation()
	corps.position.y = -0.35 if nage else 0.0


func _combat(delta: float) -> void:
	t_tir -= delta
	if t_recharge > 0.0:
		t_recharge -= delta
		if t_recharge <= 0.0:
			var besoin := CHARGEUR - munitions
			var pris := mini(besoin, reserve)
			munitions += pris
			reserve -= pris
	if not a_une_arme:
		return
	# que vise le réticule ?
	var origine := camera.global_position
	var dir := -camera.global_transform.basis.z
	var q := PhysicsRayQueryParameters3D.create(origine, origine + dir * 250.0, 1 | 4)
	q.exclude = [get_rid()]
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	cible_civile = not r.is_empty() and r["collider"] is Pnj and (r["collider"] as Pnj).role == "civil"
	if Input.is_action_pressed("tirer") and t_tir <= 0.0 and t_recharge <= 0.0 and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if munitions <= 0:
			_recharger()
			return
		t_tir = 0.11
		munitions -= 1
		arme.tirer_effets()
		a_tire.emit(global_position)
		# recul de la caméra
		tangage += 0.006
		lacet += randf_range(-0.003, 0.003)
		if cible_civile:
			return # tir dévié : on ne touche jamais un villageois
		var ecart := 0.004 if vise else 0.02
		ecart += 0.01 if vitesse_affichee > 2.5 else 0.0
		var d2 := (dir + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * ecart).normalized()
		var q2 := PhysicsRayQueryParameters3D.create(origine, origine + d2 * 250.0, 1 | 4)
		q2.exclude = [get_rid()]
		var r2 := get_world_3d().direct_space_state.intersect_ray(q2)
		if r2.is_empty():
			return
		if r2["collider"] is Pnj:
			var p: Pnj = r2["collider"]
			var tete: bool = (r2["position"] as Vector3).y > p.global_position.y + 1.5
			p.touche(DEGATS * (2.5 if tete else 1.0), true)
		else:
			Arme.impact(get_tree().current_scene, r2["position"], r2["normal"])
	if munitions <= 0 and reserve > 0 and t_recharge <= 0.0:
		_recharger()


func _process(delta: float) -> void:
	var hauteur := 1.15 if accroupi else 1.55
	if a_cheval:
		hauteur = 2.55
	var epaule := Basis(Vector3.UP, lacet) * Vector3(0.55 if vise else 0.0, 0, 0)
	pivot.global_position = pivot.global_position.lerp(global_position + Vector3(0, hauteur, 0) + epaule, 1.0 - exp(-14.0 * delta))
	pivot.rotation = Vector3(tangage, lacet, 0)
	var longueur := 1.7 if vise else (5.2 if vitesse_affichee > 4.0 else 3.9)
	if a_cheval:
		longueur = 6.8 if vitesse_affichee > 5.0 else 5.6
	bras.spring_length = lerpf(bras.spring_length, longueur, 8.0 * delta if vise else 2.0 * delta)
	camera.fov = lerpf(camera.fov, 50.0 if vise else 62.0, 8.0 * delta)

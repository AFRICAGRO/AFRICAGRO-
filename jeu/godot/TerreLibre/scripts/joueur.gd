## Faris : déplacement à la troisième personne (marche, course, saut, nage).
## Modèle : personnages/faris.glb (MakeHuman CC0, vêtements et animations faits pour le projet).
class_name Joueur
extends CharacterBody3D

const MARCHE := 2.0
const COURSE := 6.0
const NAGE := 2.2
const SAUT := 4.6
const NIVEAU_MER := 0.0

var gravite: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var nage := false
var vitesse_affichee := 0.0

var pivot: Node3D
var bras: SpringArm3D
var camera: Camera3D
var corps: Node3D
var anim: AnimationPlayer
var lacet := PI # orientation de la caméra
var tangage := -0.28


func _ready() -> void:
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
	bras.add_excluded_object(get_rid())
	pivot.add_child(bras)
	camera = Camera3D.new()
	camera.fov = 62.0
	camera.far = 6000.0
	bras.add_child(camera)
	camera.current = true


func _construire_corps() -> void:
	# Faris : modèle humain MakeHuman (CC0), squelette compatible Mixamo, 5 animations
	corps = (load("res://personnages/faris.glb") as PackedScene).instantiate()
	add_child(corps)
	anim = corps.find_child("AnimationPlayer", true, false)
	for nom in ["Repos", "Marche", "Course", "Nage"]:
		if anim.has_animation(nom):
			anim.get_animation(nom).loop_mode = Animation.LOOP_LINEAR
	for m in corps.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	anim.play("Repos")


func _choisir_animation() -> void:
	var nom := "Repos"
	var vitesse_anim := 1.0
	if nage:
		nom = "Nage"
	elif not is_on_floor() and velocity.y > -6.0 and absf(velocity.y) > 0.5:
		nom = "Saut"
	elif vitesse_affichee > 3.6:
		nom = "Course"
		vitesse_anim = vitesse_affichee / 5.8
	elif vitesse_affichee > 0.25:
		nom = "Marche"
		vitesse_anim = vitesse_affichee / 1.8
	if anim.current_animation != nom:
		anim.play(nom, 0.25)
	anim.speed_scale = clampf(vitesse_anim, 0.5, 1.6)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		lacet -= event.relative.x * 0.003
		tangage = clampf(tangage - event.relative.y * 0.0025, -1.2, 0.45)


func _physics_process(delta: float) -> void:
	var entree := Input.get_vector("gauche", "droite", "avancer", "reculer")
	var dir := (Basis(Vector3.UP, lacet) * Vector3(entree.x, 0, entree.y)).normalized()
	nage = global_position.y < NIVEAU_MER - 1.25
	var v := NAGE if nage else (COURSE if Input.is_action_pressed("courir") else MARCHE)
	var cible := dir * v
	var acc := 10.0 if is_on_floor() or nage else 3.0
	velocity.x = move_toward(velocity.x, cible.x, acc * v * delta)
	velocity.z = move_toward(velocity.z, cible.z, acc * v * delta)
	if nage:
		velocity.y = lerpf(velocity.y, (NIVEAU_MER - 1.15 - global_position.y) * 3.0, 0.2)
	elif not is_on_floor():
		velocity.y -= gravite * delta
	elif Input.is_action_just_pressed("sauter"):
		velocity.y = SAUT
	move_and_slide()
	vitesse_affichee = Vector2(velocity.x, velocity.z).length()
	if dir.length() > 0.1:
		var angle := atan2(dir.x, dir.z)
		corps.rotation.y = lerp_angle(corps.rotation.y, angle, 12.0 * delta)
	_choisir_animation()
	corps.position.y = -0.35 if nage else 0.0


func _process(delta: float) -> void:
	pivot.global_position = pivot.global_position.lerp(global_position + Vector3(0, 1.55, 0), 1.0 - exp(-14.0 * delta))
	pivot.rotation = Vector3(tangage, lacet, 0)
	bras.spring_length = lerpf(bras.spring_length, 5.2 if vitesse_affichee > 4.0 else 3.9, 2.0 * delta)

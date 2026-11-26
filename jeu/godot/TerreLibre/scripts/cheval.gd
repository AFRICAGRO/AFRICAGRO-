## Le cheval de Faris : on monte et on descend avec G quand on est tout près.
## En selle : Z (ou W) pour avancer, le cheval passe du pas au trot en prenant de l'élan ;
## Maj pour galoper ; S pour ralentir et s'arrêter ; on dirige avec la caméra (souris) et Q / D.
## Les animations (Repos, Pas, Trot, Galop) et le bruit des sabots suivent la vitesse réelle.
class_name Cheval
extends CharacterBody3D

const PAS := 1.7        # m/s à vitesse d'animation 1
const TROT := 4.2
const GALOP := 9.5
const ACCEL := 1.6      # m/s² : un cheval prend de l'élan progressivement
const FREIN := 3.5
const PORTEE := 2.6     # distance pour monter

var joueur: Node3D
var modele: Node3D
var ap: AnimationPlayer
var cavalier: Node3D
var monte := false
var vitesse := 0.0
var cap := 0.0
var gravite: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var sabots: AudioStreamPlayer3D
var sons := {}
var allure := "Repos"
var aide: Label3D


func preparer(p_joueur: Node3D, pos: Vector3, angle: float) -> void:
	joueur = p_joueur
	global_position = pos
	cap = angle
	rotation.y = cap


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.8
	floor_max_angle = deg_to_rad(45)
	# pieds : petite capsule pour suivre le sol ; corps : boîte contre les murs
	var pieds := CollisionShape3D.new()
	var cp := CapsuleShape3D.new()
	cp.radius = 0.35
	cp.height = 1.3
	pieds.shape = cp
	pieds.position.y = 0.65
	add_child(pieds)
	var tronc := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(0.7, 0.8, 2.0)
	tronc.shape = bx
	tronc.position = Vector3(0, 1.25, 0.1)
	add_child(tronc)
	modele = (load("res://personnages/cheval.glb") as PackedScene).instantiate()
	add_child(modele)
	ap = modele.find_child("AnimationPlayer", true, false)
	for a in ["Repos", "Pas", "Trot", "Galop"]:
		ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	ap.play("Repos")
	for m in modele.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for a in ["Pas", "Trot", "Galop"]:
		var s: AudioStreamWAV = load("res://sons/sabots_%s.wav" % a.to_lower())
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_end = int(s.get_length() * s.mix_rate)
		sons[a] = s
	sabots = AudioStreamPlayer3D.new()
	sabots.unit_size = 6.0
	sabots.max_distance = 70.0
	add_child(sabots)
	aide = Label3D.new()
	aide.text = "G : monter à cheval"
	aide.font_size = 40
	aide.pixel_size = 0.004
	aide.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	aide.position.y = 2.4
	aide.visible = false
	aide.no_depth_test = true
	add_child(aide)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("cheval") or joueur == null:
		return
	if monte:
		descendre()
	elif joueur.global_position.distance_to(global_position) < PORTEE and not joueur.get("mort"):
		monter()


func monter() -> void:
	monte = true
	aide.visible = false
	joueur.set("a_cheval", self)
	(joueur.get("corps") as Node3D).visible = false
	joueur.process_mode = Node.PROCESS_MODE_INHERIT
	(joueur as CollisionObject3D).collision_layer = 0
	(joueur as CollisionObject3D).collision_mask = 0
	# le cavalier : Faris (en chèche la nuit) assis sur la selle, il suit les mouvements du dos
	var nuit := false
	if joueur.has_meta("nuit"):
		nuit = joueur.get_meta("nuit")
	cavalier = (load("res://personnages/%s.glb" % ("faris_cheche" if nuit else "faris")) as PackedScene).instantiate()
	Apparence.ameliorer(cavalier)
	var sq: Skeleton3D = modele.find_child("Skeleton3D", true, false)
	var dos := BoneAttachment3D.new()
	dos.bone_name = "Corps"
	sq.add_child(dos)
	dos.add_child(cavalier)
	var cap_ap: AnimationPlayer = cavalier.find_child("AnimationPlayer", true, false)
	cap_ap.play("Cavalier")
	cap_ap.advance(0.0)
	# on assoit le cavalier : d'abord tourné comme le cheval, puis ses hanches (pose en selle) sur le siège
	await get_tree().process_frame
	cavalier.global_rotation = Vector3(0, global_rotation.y, 0)
	await get_tree().process_frame
	var sqc: Skeleton3D = cavalier.find_child("Skeleton3D", true, false)
	var hanches := sqc.find_bone("mixamorig_Hips")
	var h_loc: Vector3 = (sqc.global_transform * sqc.get_bone_global_pose(hanches)).origin
	var siege := global_transform * Vector3(0, 1.56, 0.16)
	cavalier.global_position += siege - h_loc


func descendre() -> void:
	monte = false
	if cavalier:
		cavalier.get_parent().queue_free()
		cavalier = null
	var cote := global_transform.basis.x
	var sol := global_position + cote * 1.3
	joueur.global_position = sol + Vector3(0, 0.3, 0)
	joueur.set("a_cheval", null)
	(joueur.get("corps") as Node3D).visible = true
	(joueur as CollisionObject3D).collision_layer = 2
	(joueur as CollisionObject3D).collision_mask = 1 | 4
	vitesse = 0.0


func _physics_process(delta: float) -> void:
	var cible := 0.0
	if monte:
		var entree := Input.get_vector("gauche", "droite", "avancer", "reculer")
		var lacet: float = joueur.get("lacet")
		var dir := Basis(Vector3.UP, lacet) * Vector3(entree.x, 0, entree.y)
		if entree.y < -0.2 or absf(entree.x) > 0.2:
			cible = GALOP if Input.is_action_pressed("courir") else TROT
			if entree.y > -0.2:
				cible = PAS   # on tourne sur place au pas
			var voulu := atan2(dir.x, dir.z)
			var vire := lerpf(2.6, 1.1, clampf(vitesse / GALOP, 0.0, 1.0))
			cap += clampf(wrapf(voulu - cap, -PI, PI), -vire * delta, vire * delta)
		if entree.y > 0.4:
			cible = 0.0
	vitesse = move_toward(vitesse, cible, (ACCEL if cible > vitesse else FREIN) * delta)
	rotation.y = cap
	var avant := Vector3(sin(cap), 0, cos(cap))
	velocity.x = avant.x * vitesse
	velocity.z = avant.z * vitesse
	if not is_on_floor():
		velocity.y -= gravite * delta
	else:
		velocity.y = -0.5
	move_and_slide()
	if is_on_wall() and vitesse > 0.3:
		# bordure de trottoir ou marche : si la voie est libre 45 cm plus haut, le cheval l'enjambe
		var haut := global_transform.translated(Vector3(0, 0.45, 0))
		if not test_move(haut, avant * 0.25):
			global_position += Vector3(0, 0.45, 0) + avant * 0.1
		elif get_real_velocity().length() < vitesse * 0.3:
			vitesse *= 0.5   # vrai mur : le cheval s'arrête
	_allure()
	if monte:
		joueur.global_position = global_position
		joueur.set("vitesse_affichee", vitesse)
	elif joueur:
		aide.visible = joueur.global_position.distance_to(global_position) < PORTEE


func _allure() -> void:
	var a := "Repos"
	var echelle := 1.0
	if vitesse > 0.25:
		if vitesse < 2.6:
			a = "Pas"
			echelle = vitesse / PAS
		elif vitesse < 6.2:
			a = "Trot"
			echelle = vitesse / TROT
		else:
			a = "Galop"
			echelle = vitesse / GALOP
	echelle = clampf(echelle, 0.4, 1.4)
	if a != allure:
		allure = a
		ap.play(a, 0.3)
		if sons.has(a):
			sabots.stream = sons[a]
			sabots.play()
		else:
			sabots.stop()
	ap.speed_scale = echelle
	sabots.pitch_scale = echelle
	sabots.volume_db = -4.0 + 4.0 * clampf(vitesse / GALOP, 0.0, 1.0)

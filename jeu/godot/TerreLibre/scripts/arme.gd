## Fusil générique (aucun modèle réel reproduit) : maillage construit en code,
## tenu entre la main droite (poignée) et la main gauche (garde-main) du squelette.
## Gère aussi l'éclair de bouche, le son du tir et les impacts.
class_name Arme
extends Node3D

var squelette: Skeleton3D
var os_droite := -1
var os_gauche := -1
var bout: Node3D            # bout du canon
var eclair: OmniLight3D
var flash: MeshInstance3D
var son: AudioStreamPlayer3D
var t_eclair := 0.0


static func _metal() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.09, 0.09, 0.1)
	m.metallic = 0.7
	m.roughness = 0.45
	return m


static func _bois() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://data/textures/weathered_brown_planks_diff.jpg")
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(4, 4, 4)
	m.albedo_color = Color(0.75, 0.5, 0.35)
	m.roughness = 0.7
	return m


func _boite(t: Vector3, p: Vector3, m: Material, rx := 0.0) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = t
	mi.mesh = b
	mi.material_override = m
	mi.position = p
	mi.rotation.x = rx
	add_child(mi)


func _ready() -> void:
	# repère : l'arme pointe vers -Z, poignée à l'origine
	var metal := _metal()
	var bois := _bois()
	_boite(Vector3(0.05, 0.09, 0.42), Vector3(0, 0.03, -0.12), metal)           # boîte de culasse
	var canon := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.012
	c.bottom_radius = 0.012
	c.height = 0.42
	c.radial_segments = 8
	canon.mesh = c
	canon.material_override = metal
	canon.rotation.x = PI * 0.5
	canon.position = Vector3(0, 0.05, -0.53)
	add_child(canon)
	_boite(Vector3(0.055, 0.06, 0.26), Vector3(0, 0.025, -0.42), bois)          # garde-main
	_boite(Vector3(0.035, 0.2, 0.07), Vector3(0, -0.1, -0.2), metal, 0.35)      # chargeur
	_boite(Vector3(0.03, 0.11, 0.05), Vector3(0, -0.06, 0.02), bois, -0.3)      # poignée
	_boite(Vector3(0.045, 0.09, 0.28), Vector3(0, -0.005, 0.2), bois, 0.12)     # crosse
	_boite(Vector3(0.01, 0.03, 0.01), Vector3(0, 0.1, -0.68), metal)            # guidon
	bout = Node3D.new()
	bout.position = Vector3(0, 0.05, -0.76)
	add_child(bout)
	eclair = OmniLight3D.new()
	eclair.light_color = Color(1.0, 0.75, 0.4)
	eclair.omni_range = 6.0
	eclair.light_energy = 0.0
	bout.add_child(eclair)
	flash = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.28, 0.28)
	var mf := StandardMaterial3D.new()
	mf.albedo_texture = load("res://data/textures/fumee.png")
	mf.albedo_color = Color(1.0, 0.8, 0.35)
	mf.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mf.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mf.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mf.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	q.material = mf
	flash.mesh = q
	flash.visible = false
	bout.add_child(flash)
	son = AudioStreamPlayer3D.new()
	son.stream = load("res://sons/tir.wav")
	son.unit_size = 18.0
	son.max_polyphony = 4
	bout.add_child(son)


## Relie l'arme aux mains d'un personnage (modèle faris.glb).
func tenir(perso: Node3D) -> void:
	squelette = perso.find_child("Skeleton3D", true, false)
	if squelette:
		# Godot remplace « : » par « _ » dans les noms d'os importés
		for prefixe in ["mixamorig_", "mixamorig:"]:
			if os_droite < 0:
				os_droite = squelette.find_bone(prefixe + "RightHand")
				os_gauche = squelette.find_bone(prefixe + "LeftHand")


func _process(delta: float) -> void:
	if squelette and os_droite >= 0:
		var d := squelette.global_transform * squelette.get_bone_global_pose(os_droite).origin
		var g := squelette.global_transform * squelette.get_bone_global_pose(os_gauche).origin
		var dir := g - d
		if dir.length() > 0.12:
			global_position = d
			look_at(d + dir.normalized(), Vector3.UP)
		else: # mains rapprochées (repos) : arme tenue le long du corps
			var h := squelette.global_transform.basis
			global_position = d
			look_at(d + h * Vector3(0, -0.6, 1.0).normalized(), h * Vector3(0, 0, 1))
	if t_eclair > 0.0:
		t_eclair -= delta
		if t_eclair <= 0.0:
			eclair.light_energy = 0.0
			flash.visible = false


func tirer_effets() -> void:
	eclair.light_energy = 3.0
	flash.visible = true
	flash.rotation.z = randf() * TAU
	t_eclair = 0.05
	son.pitch_scale = randf_range(0.92, 1.08)
	son.play()


## Petit nuage de poussière et son d'impact à un point touché.
static func impact(parent: Node, point: Vector3, normale: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 10
	p.lifetime = 0.6
	p.explosiveness = 0.95
	p.direction = normale
	p.spread = 35.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.5
	p.gravity = Vector3(0, -6, 0)
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.12
	var b := BoxMesh.new()
	b.size = Vector3.ONE
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.6, 0.5, 0.38)
	b.material = m
	p.mesh = b
	parent.add_child(p)
	p.global_position = point
	var s := AudioStreamPlayer3D.new()
	s.stream = load("res://sons/impact.wav")
	s.unit_size = 6.0
	parent.add_child(s)
	s.global_position = point
	s.play()
	var t := parent.get_tree().create_timer(1.2)
	t.timeout.connect(func():
		p.queue_free()
		s.queue_free())

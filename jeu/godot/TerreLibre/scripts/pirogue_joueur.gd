## Pirogue monoxyle que Faris mène à la perche, debout à l'arrière, comme les pêcheurs de la lagune.
## E tout près (depuis la berge ou à la nage) pour embarquer ou débarquer.
## À bord : Z pour pousser, S pour freiner / reculer, Q / D pour tourner ; Maj pour pousser plus fort.
## La pirogue glisse sur son erre, tangue sur la houle, ne passe pas là où l'eau est trop basse
## (on s'échoue sur le sable) ni dans les chutes de la rivière ; elle remonte la rivière de Tikané
## tant que le courant le permet.
class_name PirogueJoueur
extends Node3D

const NIVEAU_MER := 0.0
const VMAX := 2.3            # m/s : une pirogue à la perche avance au pas rapide
const VMAX_FORT := 3.3
const POUSSEE := 0.9
const ERRE := 0.35           # la pirogue garde son élan : elle ralentit doucement
const VIRAGE := 0.75         # rad/s
const TIRANT := 0.32         # profondeur d'eau minimale
const PORTEE := 4.0

var joueur: Node3D
var terrain: Node
var rivieres: Array = []     # lits navigables : {pts, niveaux, largeur}
var coque: MeshInstance3D
var assiette: Node3D
var piroguier: Node3D
var perche: MeshInstance3D
var main_d: Node3D
var main_g: Node3D
var ap: AnimationPlayer
var monte := false
var vitesse := 0.0
var cap := 0.0
var t := 0.0
var clapot: AudioStreamPlayer3D
var aide: Label3D
## Passages que la marée ouvre ou ferme (mission 9) : chaque Callable(Vector2) -> bool dit « bloqué ».
var obstacles: Array = []
## Pirogue à moteur hors-bord (mission 3) : Faris assis à l'arrière, la main sur la barre du moteur.
## Z : gaz · relâcher Z : couper les gaz et glisser en silence · Q / D : tourner · Maj : plein gaz.
var moteur := false
var verrou := false          # poursuite en cours : on ne débarque pas en pleine mer
var son_moteur: AudioStreamPlayer3D
const VMAX_MOTEUR := 8.2
const VMAX_MOTEUR_FORT := 9.6
const POUSSEE_MOTEUR := 2.8
const VIRAGE_MOTEUR := 0.95


func preparer(p_joueur: Node3D, p_terrain: Node, p_rivieres: Array, maillage: Mesh, pos: Vector2, angle: float) -> void:
	joueur = p_joueur
	terrain = p_terrain
	rivieres = p_rivieres
	cap = angle
	assiette = Node3D.new()
	add_child(assiette)
	coque = MeshInstance3D.new()
	coque.mesh = maillage
	assiette.add_child(coque)
	global_position = Vector3(pos.x, niveau_eau(pos) - 0.22, pos.y)
	rotation.y = cap
	var s: AudioStreamWAV = load("res://sons/riviere.wav")
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_end = int(s.get_length() * s.mix_rate)
	clapot = AudioStreamPlayer3D.new()
	clapot.stream = s
	clapot.unit_size = 3.0
	clapot.max_distance = 30.0
	clapot.volume_db = -30.0
	add_child(clapot)
	aide = Label3D.new()
	aide.text = "E : embarquer"
	aide.font_size = 40
	aide.pixel_size = 0.004
	aide.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	aide.position.y = 1.4
	aide.visible = false
	aide.no_depth_test = true
	add_child(aide)


## Hauteur de l'eau : la mer partout, ou la surface de la rivière dans son lit.
func niveau_eau(p: Vector2) -> float:
	for lit in rivieres:
		var pts: PackedVector2Array = lit["pts"]
		var niv: PackedFloat32Array = lit["niveaux"]
		var demi: float = lit["largeur"] * 0.5
		for i in pts.size() - 1:
			var ab := pts[i + 1] - pts[i]
			var u := clampf((p - pts[i]).dot(ab) / ab.length_squared(), 0.0, 1.0)
			if p.distance_to(pts[i] + ab * u) < demi:
				return maxf(NIVEAU_MER, lerpf(niv[i], niv[i + 1], u))
	return NIVEAU_MER


func _navigable(de: Vector2, vers: Vector2) -> bool:
	for o in obstacles:
		if (o as Callable).call(vers):
			return false                               # banc de vase, racines à fleur d'eau
	var n := niveau_eau(vers)
	if n - terrain.hauteur(vers.x, vers.y) < TIRANT:
		return false                                   # haut-fond, plage, berge
	return absf(n - niveau_eau(de)) < 0.35             # pas de chute d'eau à franchir


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("vehicule") or joueur == null:
		return
	if monte and verrou:
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
	piroguier = (load("res://personnages/%s.glb" % ("faris_cheche" if nuit else "faris")) as PackedScene).instantiate()
	Apparence.ameliorer(piroguier)
	assiette.add_child(piroguier)
	piroguier.position = Vector3(0, 0.12, -1.9)    # debout à l'arrière
	ap = piroguier.find_child("AnimationPlayer", true, false)
	if moteur:
		# assis à l'arrière, devant le moteur ; pas de perche
		piroguier.position = Vector3(0, -0.12, -2.0)
		ap.get_animation("Assis").loop_mode = Animation.LOOP_LINEAR
		ap.play("Assis")
		if son_moteur == null:
			var sm: AudioStreamWAV = load("res://sons/moto.wav")
			sm.loop_mode = AudioStreamWAV.LOOP_FORWARD
			sm.loop_end = int(sm.get_length() * sm.mix_rate)
			son_moteur = AudioStreamPlayer3D.new()
			son_moteur.stream = sm
			son_moteur.unit_size = 6.0
			son_moteur.max_distance = 90.0
			son_moteur.volume_db = -12.0
			son_moteur.pitch_scale = 0.5
			add_child(son_moteur)
		son_moteur.play()
		clapot.play()
		return
	ap.get_animation("Perche").loop_mode = Animation.LOOP_LINEAR
	ap.play("Perche")
	ap.speed_scale = 0.0
	var sq: Skeleton3D = piroguier.find_child("Skeleton3D", true, false)
	main_d = BoneAttachment3D.new()
	(main_d as BoneAttachment3D).bone_name = "mixamorig_RightHand"
	sq.add_child(main_d)
	main_g = BoneAttachment3D.new()
	(main_g as BoneAttachment3D).bone_name = "mixamorig_LeftHand"
	sq.add_child(main_g)
	perche = MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 0.022
	cy.bottom_radius = 0.028
	cy.height = 1.0
	cy.radial_segments = 6
	perche.mesh = cy
	var mb := StandardMaterial3D.new()
	mb.albedo_color = Color(0.62, 0.5, 0.33)
	mb.roughness = 0.85
	perche.material_override = mb
	perche.top_level = true
	add_child(perche)
	clapot.play()


func descendre() -> void:
	monte = false
	if piroguier:
		piroguier.queue_free()
		piroguier = null
	if perche:
		perche.queue_free()
		perche = null
	clapot.stop()
	if son_moteur:
		son_moteur.stop()
	# on débarque du côté de la terre la plus proche (sinon dans l'eau, à la nage)
	var meilleur := global_position + global_transform.basis.x * 1.2
	var haut := -INF
	for k in 8:
		var a := TAU * k / 8.0
		var q := global_position + Vector3(cos(a), 0, sin(a)) * 2.0
		var h: float = terrain.hauteur(q.x, q.z)
		if h > haut:
			haut = h
			meilleur = Vector3(q.x, maxf(h, global_position.y), q.z)
	joueur.global_position = meilleur + Vector3(0, 0.4, 0)
	joueur.set("a_cheval", null)
	(joueur.get("corps") as Node3D).visible = true
	(joueur as CollisionObject3D).collision_layer = 2
	(joueur as CollisionObject3D).collision_mask = 1 | 4


func _process(delta: float) -> void:
	t += delta
	var cible := 0.0
	var virage := 0.0
	if monte:
		var entree := Input.get_vector("gauche", "droite", "avancer", "reculer")
		virage = -entree.x
		if moteur:
			if entree.y < -0.2:
				cible = VMAX_MOTEUR_FORT if Input.is_action_pressed("courir") else VMAX_MOTEUR
			elif entree.y > 0.2:
				cible = -1.5
		elif entree.y < -0.2:
			cible = VMAX_FORT if Input.is_action_pressed("courir") else VMAX
		elif entree.y > 0.2:
			cible = -0.8
		elif absf(entree.x) > 0.2:
			cible = maxf(vitesse, 0.6)                 # on pousse de côté pour pivoter
	var acc := (POUSSEE_MOTEUR if moteur else POUSSEE) if cible != 0.0 else ERRE
	vitesse = move_toward(vitesse, cible, acc * delta)
	if moteur:
		# le moteur fait tourner même à petite vitesse ; virage plus serré à mi-régime
		cap += virage * VIRAGE_MOTEUR * delta * clampf(0.45 + absf(vitesse) / VMAX_MOTEUR, 0.0, 1.1)
	else:
		cap += virage * VIRAGE * delta * clampf(0.35 + absf(vitesse) / VMAX, 0.0, 1.2)
	rotation.y = cap
	var avant := Vector2(sin(cap), cos(cap))
	var ici := Vector2(global_position.x, global_position.z)
	var pas := avant * vitesse * delta
	# la proue (à 3,2 m) et la poupe ne doivent pas toucher le fond
	var bout := ici + avant * 3.2 * signf(vitesse if vitesse != 0.0 else 1.0)
	if vitesse != 0.0 and not _navigable(ici, bout + pas):
		vitesse = 0.0                                  # échoué : on recule ou on tourne
	else:
		ici += pas
	var n := niveau_eau(ici)
	# houle : la pirogue monte, descend, roule et tangue ; plus calme sur la rivière
	var houle := 1.0 if n <= NIVEAU_MER + 0.05 else 0.3
	global_position = Vector3(ici.x, lerpf(global_position.y, n - 0.22 + 0.05 * houle * sin(t * 1.3), 1.0 - exp(-4.0 * delta)), ici.y)
	assiette.basis = Basis.from_euler(Vector3(0.025 * houle * sin(t * 0.9 + 1.0), 0, 0.04 * houle * sin(t * 1.1)
			- virage * 0.03 * clampf(vitesse / VMAX, 0.0, 1.0)))
	if monte and moteur:
		if son_moteur:
			son_moteur.pitch_scale = 0.45 + 0.55 * clampf(absf(cible) / VMAX_MOTEUR_FORT, 0.0, 1.0) + 0.1 * clampf(absf(vitesse) / VMAX_MOTEUR, 0.0, 1.0)
			son_moteur.volume_db = -22.0 if cible == 0.0 else -10.0
		clapot.volume_db = -24.0 + 10.0 * clampf(absf(vitesse) / VMAX_MOTEUR_FORT, 0.0, 1.0)
		joueur.global_position = global_position + Vector3(0, 0.3, 0)
		joueur.set("vitesse_affichee", absf(vitesse))
	elif monte:
		# le geste de perche suit l'effort : immobile quand on se laisse glisser
		ap.speed_scale = clampf(absf(cible) / VMAX, 0.0, 1.2) if cible != 0.0 else 0.0
		clapot.volume_db = -26.0 + 10.0 * clampf(absf(vitesse) / VMAX_FORT, 0.0, 1.0)
		_perche()
		joueur.global_position = global_position + Vector3(0, 0.3, 0)
		joueur.set("vitesse_affichee", absf(vitesse))
	elif joueur:
		aide.visible = joueur.get("a_cheval") == null and joueur.global_position.distance_to(global_position) < PORTEE


func _perche() -> void:
	# la perche passe par les deux mains et descend vers le fond, côté gauche
	var d := main_d.global_position
	var g := main_g.global_position
	var axe := g - d
	if axe.length() < 0.05:
		return
	axe = axe.normalized()
	var haut := d - axe * 0.6
	var bas := g + axe * 2.8
	var ay := (haut - bas).normalized()
	var ax := ay.cross(Vector3.FORWARD if absf(ay.z) < 0.9 else Vector3.RIGHT).normalized()
	perche.global_transform = Transform3D(Basis(ax, ay * haut.distance_to(bas), ax.cross(ay)), (haut + bas) * 0.5)

## Personnages non joueurs de la mission 4 : miliciens du Cobra, Dossou, villageois.
## Miliciens : Patrouille → Suspicion → Combat → Rendu (sous 25 PV) → Ligoté ou Mort.
## Villageois : rassemblés, puis fuient vers un refuge dès que ça tire, et s'y cachent.
class_name Pnj
extends CharacterBody3D

signal neutralise(pnj: Pnj, comment: String) # "ligote", "mort"
signal rendu(pnj: Pnj)
signal alerte(position: Vector3)

enum Etat { CALME, SUSPICION, COMBAT, RENDU, LIGOTE, MORT, FUITE, CACHE, ENDORMI, DESARME }

var role := "milicien"   # "milicien", "dossou", "civil", "recrue" (mineur enrôlé de force : jamais une cible),
                         # "allie" (villageois armé des Racines, mission 11), "mamba" (le Commandant : canne-épée)
var t_coup := 0.0
var etat := Etat.CALME
var pv := 100.0
var mission: Node
var joueur: Joueur
var corps: Node3D
var anim: AnimationPlayer
var anim_haut: AnimationPlayer
var arme: Arme
var agent: NavigationAgent3D
var gravite := 9.8
var points_patrouille: Array = []
var i_patrouille := 0
var attente := 0.0
var soupcon := 0.0
var t_tir := 0.0
var rafale := 0
var t_couvert := 0.0
var cible_nav := Vector3.ZERO
var refuges: Array = []
var vitesse := 0.0
var regard := Vector3.FORWARD
## Perception réglée par la mission : portée de vue (m) — réduite dans le noir — et zone interdite
## (dans l'entrepôt du Cobra, un homme vu sans arme est quand même suspect).
var portee_vue := 38.0
var zone_interdite := false
var tolere := false        # Faris passe pour un docker : sa présence n'éveille pas la méfiance
## Bruit suspect (objet lancé) : le garde va voir, regarde autour de lui, puis reprend sa ronde.
var enquete := Vector3.INF
var t_enquete := 0.0


func preparer(p_role: String, p_mission: Node, p_joueur: Joueur, teinte_chemise: Color, texture_chemise: String = "", modele := "faris") -> void:
	role = p_role
	mission = p_mission
	joueur = p_joueur
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.33
	cap.height = 1.78
	cs.shape = cap
	cs.position.y = 0.89
	add_child(cs)
	# corps : faris, villageois, ancien, femme, femme_agee (personnages/*.glb, même squelette et animations)
	corps = (load("res://personnages/%s.glb" % modele) as PackedScene).instantiate()
	Apparence.ameliorer(corps)
	add_child(corps)
	anim = corps.find_child("AnimationPlayer", true, false)
	for nom in ["Repos", "Marche", "Course", "Accroupi", "AccroupiMarche", "Rendu", "Ligote", "Visee"]:
		anim.get_animation(nom).loop_mode = Animation.LOOP_LINEAR
	anim_haut = AnimationPlayer.new()
	anim.get_parent().add_child(anim_haut)
	anim_haut.root_node = anim.root_node
	anim_haut.add_animation_library("", anim.get_animation_library(""))
	# tenue : chemise teintée (ou autre motif), pantalon foncé pour la milice
	for mesh_inst in corps.find_children("*", "MeshInstance3D", true, false):
		for s in mesh_inst.mesh.get_surface_count():
			if mesh_inst.mesh.surface_get_material(s) == null:
				continue
			var nom: String = mesh_inst.mesh.surface_get_material(s).resource_name
			if nom == "Chemise":
				var m: StandardMaterial3D = mesh_inst.mesh.surface_get_material(s).duplicate()
				if texture_chemise != "":
					m.albedo_texture = load(texture_chemise)
				m.albedo_color = m.albedo_color * teinte_chemise
				mesh_inst.set_surface_override_material(s, m)
			elif nom == "Pantalon" and role != "civil":
				var mp: StandardMaterial3D = mesh_inst.mesh.surface_get_material(s).duplicate()
				mp.albedo_color = Color(0.25, 0.27, 0.2)
				mesh_inst.set_surface_override_material(s, mp)
	var sc := randf_range(0.96, 1.03) * (1.05 if role == "dossou" else 1.0)
	corps.scale = Vector3(sc, sc, sc)
	agent = NavigationAgent3D.new()
	agent.radius = 0.4
	agent.path_desired_distance = 0.8
	agent.target_desired_distance = 1.0
	add_child(agent)
	if role != "civil":
		arme = Arme.new()
		add_child(arme)
		arme.tenir(corps)
		pv = 160.0 if role == "dossou" else 100.0
	anim.play("Repos")
	anim.seek(randf() * 3.0)


# ---------- dégâts ----------
func touche(degats: float, _par_joueur: bool) -> void:
	# règle absolue : un civil ou un jeune enrôlé de force n'est jamais blessé
	if etat in [Etat.MORT, Etat.LIGOTE, Etat.ENDORMI] or role in ["civil", "recrue", "allie"]:
		return
	if etat == Etat.RENDU:
		pv = 0.0
		_mourir(true)
		return
	pv -= degats
	if etat != Etat.COMBAT:
		_passer_combat()
	if pv <= 0.0:
		_mourir(false)
	elif pv <= 25.0:
		_se_rendre()


func _se_rendre() -> void:
	etat = Etat.RENDU
	velocity = Vector3.ZERO
	anim_haut.stop()
	anim.play("Rendu", 0.3)
	if arme:
		arme.queue_free()
		arme = null
	rendu.emit(self)


func _mourir(alors_rendu: bool) -> void:
	etat = Etat.MORT
	velocity = Vector3.ZERO
	anim_haut.stop()
	anim.play("Mort", 0.25)
	collision_layer = 0
	if arme:
		arme.queue_free()
		arme = null
	neutralise.emit(self, "mort_rendu" if alors_rendu else "mort")


func ligoter() -> void:
	etat = Etat.LIGOTE
	velocity = Vector3.ZERO
	anim_haut.stop()
	anim.play("Ligote", 0.4)
	collision_layer = 0
	if arme:
		arme.queue_free()
		arme = null
	neutralise.emit(self, "ligote")


## Fléchette anesthésiante (mission 8) : le milicien s'effondre et dort jusqu'au matin.
func endormir() -> void:
	if not est_actif() and etat != Etat.RENDU:
		return
	if role == "civil" or role == "recrue":
		return
	etat = Etat.ENDORMI
	velocity = Vector3.ZERO
	anim_haut.stop()
	anim.play("Mort", 0.6)
	collision_layer = 0
	if arme:
		arme.queue_free()
		arme = null
	neutralise.emit(self, "endormi")


## Jeune recrue désarmée sans violence : elle pose son arme et s'assoit ; elle redevient un civil.
func desarmer() -> void:
	if role != "recrue":
		return
	etat = Etat.DESARME
	role = "civil"
	velocity = Vector3.ZERO
	soupcon = 0.0
	anim_haut.stop()
	anim.play("Assis" if anim.has_animation("Assis") else "Accroupi", 0.5)
	if arme:
		arme.queue_free()
		arme = null
	neutralise.emit(self, "desarme")


func est_actif() -> bool:
	return etat in [Etat.CALME, Etat.SUSPICION, Etat.COMBAT]


## Le joueur est-il dans le dos de ce PNJ (pour une prise non létale) ?
func dos_au_joueur() -> bool:
	var vers_joueur := (joueur.global_position - global_position)
	vers_joueur.y = 0
	return regard.dot(vers_joueur.normalized()) < -0.2


func _passer_combat() -> void:
	if role == "civil" or role == "allie":
		return
	if etat in [Etat.CALME, Etat.SUSPICION]:
		etat = Etat.COMBAT
		t_couvert = 0.0
		alerte.emit(global_position)


## Bruit discret (caillou lancé) : un garde calme va voir ce que c'est, sans donner l'alerte.
func intriguer(origine: Vector3, portee: float) -> void:
	if role == "civil" or etat != Etat.CALME or global_position.distance_to(origine) > portee:
		return
	enquete = origine
	t_enquete = 5.0
	attente = 0.0


func entendre(origine: Vector3, portee: float) -> void:
	if global_position.distance_to(origine) > portee:
		return
	if role == "civil":
		if etat == Etat.CALME:
			_fuir()
	elif role == "allie":
		return
	elif etat in [Etat.CALME, Etat.SUSPICION]:
		_passer_combat()


func _fuir() -> void:
	etat = Etat.FUITE
	var best: Vector3 = refuges[0]
	for r in refuges:
		if global_position.distance_to(r) < global_position.distance_to(best):
			best = r
	_aller(best + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3)))


func _aller(p: Vector3) -> void:
	cible_nav = p
	agent.target_position = p


# ---------- perception ----------
func _voit_joueur() -> bool:
	var tete := global_position + Vector3(0, 1.6, 0)
	var cible := joueur.global_position + Vector3(0, 1.2 if joueur.accroupi else 1.5, 0)
	var d := tete.distance_to(cible)
	if d > (portee_vue if not joueur.accroupi else portee_vue * 0.6):
		return false
	var dir := (cible - tete).normalized()
	var plat := Vector3(dir.x, 0, dir.z).normalized()
	if etat != Etat.COMBAT and regard.dot(plat) < 0.35:
		return false
	var q := PhysicsRayQueryParameters3D.create(tete, cible, 1 | 2)
	q.exclude = [get_rid()]
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	return r.is_empty() or r["collider"] == joueur


# ---------- comportement ----------
func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravite * delta
	else:
		velocity.y = 0.0
	match etat:
		Etat.CALME, Etat.SUSPICION:
			_calme(delta)
		Etat.COMBAT:
			_combat(delta)
		Etat.FUITE:
			_deplacer(4.8, delta)
			if agent.is_navigation_finished() or global_position.distance_to(cible_nav) < 1.6:
				etat = Etat.CACHE
		_:
			velocity.x = 0.0
			velocity.z = 0.0
	move_and_slide()
	_animer()


func _calme(delta: float) -> void:
	if role == "civil" or role == "allie" or joueur == null:
		return
	var voit := _voit_joueur()
	if voit and joueur.a_une_arme:
		var d := global_position.distance_to(joueur.global_position)
		var vite := 1.6 if not joueur.accroupi else 0.6
		# dans le noir (portée de vue réduite), on met plus de temps à reconnaître une arme
		soupcon += delta * vite * clampf(30.0 / maxf(d, 3.0), 0.5, 4.0) * clampf(portee_vue / 38.0, 0.25, 1.0)
		etat = Etat.SUSPICION
		_regarder(joueur.global_position, delta * 2.0)
	elif voit and zone_interdite:
		var d := global_position.distance_to(joueur.global_position)
		soupcon += delta * (0.55 if not joueur.accroupi else 0.22) * clampf(16.0 / maxf(d, 2.0), 0.4, 3.0)
		etat = Etat.SUSPICION
		_regarder(joueur.global_position, delta * 2.0)
	elif voit and not tolere and not joueur.accroupi and global_position.distance_to(joueur.global_position) < 9.0:
		soupcon += delta * 0.8
		etat = Etat.SUSPICION
		_regarder(joueur.global_position, delta * 2.0)
	else:
		soupcon = maxf(0.0, soupcon - delta * 0.3)
		if soupcon <= 0.0:
			etat = Etat.CALME
	if soupcon >= 1.0:
		_passer_combat()
		return
	if etat == Etat.CALME and enquete != Vector3.INF:
		if global_position.distance_to(enquete) > 1.5 and t_enquete > 4.9:
			_aller(enquete)
			_deplacer(1.9, delta)
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			t_enquete -= delta
			regard = regard.rotated(Vector3.UP, delta * 0.9 * signf(sin(t_enquete * 1.3)))
			corps.rotation.y = atan2(regard.x, regard.z)
			if t_enquete <= 0.0:
				enquete = Vector3.INF
		return
	if etat == Etat.CALME and points_patrouille.size() > 1:
		if attente > 0.0:
			attente -= delta
			velocity.x = 0.0
			velocity.z = 0.0
		else:
			var p: Vector3 = points_patrouille[i_patrouille]
			if global_position.distance_to(p) < 1.2:
				i_patrouille = (i_patrouille + 1) % points_patrouille.size()
				attente = randf_range(2.0, 4.5)
			else:
				_aller(p)
				_deplacer(1.5, delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0


func _combat(delta: float) -> void:
	if role == "mamba":
		# le Commandant ne tire pas : sa canne cache une lame. Il marche droit sur Faris.
		var vers := joueur.global_position - global_position
		vers.y = 0.0
		_regarder(joueur.global_position, delta * 4.0)
		t_coup -= delta
		if vers.length() > 1.8:
			var v := vers.normalized() * (3.6 if vers.length() > 6.0 else 2.2)
			velocity.x = v.x
			velocity.z = v.z
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			if t_coup <= 0.0 and not joueur.mort:
				t_coup = 1.1
				joueur.blesser(13.0)
				mission.blessure()
		return
	if role == "recrue":
		# un garçon terrifié : il crie, braque son arme en tremblant, mais ne tire jamais
		velocity.x = 0.0
		velocity.z = 0.0
		_regarder(joueur.global_position, delta * 3.0)
		return
	if joueur.mort:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	t_couvert -= delta
	if t_couvert <= 0.0:
		var c: Vector3 = mission.choisir_couvert(self)
		_aller(c)
		t_couvert = randf_range(6.0, 9.0)
	var arrive := global_position.distance_to(cible_nav) < 1.2 or (not agent.get_current_navigation_path().is_empty() and agent.is_navigation_finished())
	if not arrive:
		_deplacer(4.2, delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	_regarder(joueur.global_position, delta * 6.0)
	# tir par rafales de 3
	t_tir -= delta
	if t_tir <= 0.0 and _voit_joueur():
		_tirer()
		rafale += 1
		if rafale >= 3:
			rafale = 0
			t_tir = randf_range(1.2, 2.2)
		else:
			t_tir = 0.13


func _tirer() -> void:
	if arme == null:
		return
	arme.tirer_effets()
	mission.bruit_de_tir(global_position)
	var depart := global_position + Vector3(0, 1.45, 0)
	var cible := joueur.global_position + Vector3(0, 0.9 if joueur.accroupi else 1.2, 0)
	var d := depart.distance_to(cible)
	# précision : moins bonne de loin, si le joueur bouge ou est accroupi
	var ecart := 0.02 + d * 0.004 + (0.03 if joueur.vitesse_affichee > 3.0 else 0.0) + (0.02 if joueur.accroupi else 0.0)
	var dir := (cible - depart).normalized()
	dir = (dir + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * ecart).normalized()
	var q := PhysicsRayQueryParameters3D.create(depart, depart + dir * 120.0, 1 | 2 | 4)
	q.exclude = [get_rid()]
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		return
	if r["collider"] == joueur or (joueur.a_cheval != null and r["collider"] == joueur.a_cheval):
		joueur.blesser(9.0)   # sur une monture, la balle qui touche la moto ou le cheval atteint Faris
	else:
		Arme.impact(get_tree().current_scene, r["position"], r["normal"])


func _deplacer(v: float, _delta: float) -> void:
	if agent.get_current_navigation_path().is_empty():
		# pas de maillage de navigation ici (barrages, pistes) : on va droit vers le but
		var vers := cible_nav - global_position
		vers.y = 0
		if vers.length() < 0.8:
			velocity.x = 0.0
			velocity.z = 0.0
			return
		vers = vers.normalized()
		velocity.x = vers.x * v
		velocity.z = vers.z * v
		if etat != Etat.COMBAT:
			_regarder(global_position + vers, 0.25)
		return
	if agent.is_navigation_finished():
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var suivant := agent.get_next_path_position()
	var dir := suivant - global_position
	dir.y = 0
	if dir.length() < 0.05:
		return
	dir = dir.normalized()
	velocity.x = dir.x * v
	velocity.z = dir.z * v
	if etat != Etat.COMBAT:
		_regarder(global_position + dir, 0.25)


func _regarder(p: Vector3, poids: float) -> void:
	var d := p - global_position
	d.y = 0
	if d.length() < 0.1:
		return
	# interpolation d'angle (un slerp entre deux directions opposées produit un axe dégénéré)
	var a := lerp_angle(atan2(regard.x, regard.z), atan2(d.x, d.z), clampf(poids, 0.0, 1.0))
	regard = Vector3(sin(a), 0.0, cos(a))
	corps.rotation.y = a


func _animer() -> void:
	var v := Vector2(velocity.x, velocity.z).length()
	var nom := "Repos"
	match etat:
		Etat.RENDU:
			return
		Etat.LIGOTE, Etat.MORT, Etat.ENDORMI, Etat.DESARME:
			return
		Etat.CACHE:
			nom = "Accroupi"
		_:
			if v > 3.0:
				nom = "Course"
			elif v > 0.3:
				nom = "Marche"
	if anim.current_animation != nom:
		anim.play(nom, 0.25)
	if etat == Etat.COMBAT and arme:
		if anim_haut.current_animation != "Visee":
			anim_haut.play("Visee", 0.2)
	elif anim_haut.is_playing():
		anim_haut.stop()

## Patrouilles du Cobra : pick-up armés qui font la navette sur les pistes entre Port-Néré et les villages.
## - En patrouille : ils roulent au pas de route sur une piste, font demi-tour au bout, phares allumés la nuit.
## - Alerte (barrage forcé, coups de feu entendus, Faris armé repéré près d'eux) : poursuite. Le pick-up
##   suit la piste jusqu'au point le plus proche de Faris, puis coupe à travers la brousse vers lui.
## - À une quinzaine de mètres il pile : les deux miliciens de la benne sautent à terre et combattent
##   (vrais Pnj : couvert, rafales, reddition, ligotage avec F). Le pick-up reste sur place.
## - Si Faris s'éloigne beaucoup avant d'être rattrapé, la patrouille abandonne et reprend sa ronde.
class_name Patrouilles
extends Node3D

const V_RONDE := 7.0
const V_POURSUITE := 13.0
const DIST_ARRET := 15.0
const VUE := 32.0               # distance à laquelle les miliciens de la benne repèrent un homme armé
const ABANDON := 450.0

var terrain: Terrain
var joueur: Joueur
var controles: Controles
var pickups: Array = []         # {noeud, trace, l, sens, v, etat, passagers, roues, moteur, phare, t_abandon}
var nuit := false


## Port-Néré libérée (mission 12) : plus aucun pick-up de la milice sur les routes.
func liberer() -> void:
	for pk in pickups:
		for p in pk["passagers"]:
			if is_instance_valid(p):
				(p as Node).queue_free()
		if is_instance_valid(pk["noeud"]):
			(pk["noeud"] as Node).queue_free()
	pickups.clear()
	set_process(false)


func construire(t: Terrain, p_joueur: Joueur, p_controles: Controles, traces: Array) -> void:
	terrain = t
	joueur = p_joueur
	controles = p_controles
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in traces.size():
		var trace: PackedVector2Array = traces[i]
		if trace.size() < 20:
			continue
		var pk := _pickup(rng)
		pk["trace"] = trace
		pk["l"] = rng.randf_range(0.2, 0.8) * _longueur(trace)
		pk["sens"] = 1.0 if i % 2 == 0 else -1.0
		pickups.append(pk)
	controles.alerte_barrage.connect(_alerte_generale)
	joueur.a_tire.connect(func(p: Vector3) -> void:
		for pk in pickups:
			if pk["etat"] == "ronde" and (pk["noeud"] as Node3D).global_position.distance_to(p) < 160.0:
				_poursuivre(pk))


func _pickup(rng: RandomNumberGenerator) -> Dictionary:
	var noeud: Node3D = (load("res://vehicules/pickup.glb") as PackedScene).instantiate()
	add_child(noeud)
	# peinture kaki délavée des véhicules du Cobra
	for mi in noeud.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for k in m.mesh.get_surface_count():
			var mat := m.mesh.surface_get_material(k)
			if mat and mat.resource_name == "Carrosserie":
				var m2: StandardMaterial3D = (mat as StandardMaterial3D).duplicate()
				m2.albedo_color = Color(0.3, 0.33, 0.2)
				m2.roughness = 0.7
				m.set_surface_override_material(k, m2)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var roues: Array = []
	for n in noeud.find_children("Roue_*", "", true, false):
		roues.append(n)
	# deux miliciens debout dans la benne (décor tant qu'ils n'ont pas sauté à terre)
	var passagers: Array = []
	for k in 2:
		var p: Node3D = (load("res://personnages/%s.glb" % ["villageois", "homme2"][k]) as PackedScene).instantiate()
		Apparence.ameliorer(p)
		noeud.add_child(p)
		p.position = Vector3(-0.4 + k * 0.8, 0.95, -1.4)
		p.rotation.y = PI * 0.5 * (1.0 if k == 0 else -1.0)
		var ap: AnimationPlayer = p.find_child("AnimationPlayer", true, false)
		ap.play("Repos")
		ap.seek(rng.randf() * 2.0)
		_camoufler(p)
		passagers.append(p)
	var s: AudioStreamWAV = load("res://sons/moto.wav")
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_end = int(s.get_length() * s.mix_rate)
	var moteur := AudioStreamPlayer3D.new()
	moteur.stream = s
	moteur.unit_size = 9.0
	moteur.max_distance = 140.0
	moteur.volume_db = -8.0
	moteur.pitch_scale = 0.55
	noeud.add_child(moteur)
	moteur.play(rng.randf())
	var phare := SpotLight3D.new()
	phare.position = Vector3(0, 0.9, 2.7)
	phare.rotation = Vector3(deg_to_rad(-10), PI, 0)
	phare.spot_range = 32.0
	phare.light_energy = 3.0
	phare.light_color = Color(1.0, 0.95, 0.85)
	phare.visible = false
	noeud.add_child(phare)
	return {"noeud": noeud, "l": 0.0, "sens": 1.0, "v": V_RONDE, "etat": "ronde", "passagers": passagers,
			"roues": roues, "moteur": moteur, "phare": phare, "t_abandon": 0.0, "cap": 0.0}


func _camoufler(perso: Node3D) -> void:
	var camo: Texture2D = load("res://data/textures/camouflage.jpg")
	for mi in perso.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for k in m.mesh.get_surface_count():
			var mat := m.mesh.surface_get_material(k)
			if mat and mat.resource_name == "Chemise":
				var m2: StandardMaterial3D = (mat as StandardMaterial3D).duplicate()
				m2.albedo_texture = camo
				m2.albedo_color = Color(0.8, 0.85, 0.75)
				m.set_surface_override_material(k, m2)
	var arme := Arme.new()
	perso.add_child(arme)
	arme.tenir(perso)


# ---------------------------------------------------------------------
# Géométrie des pistes
# ---------------------------------------------------------------------
func _longueur(trace: PackedVector2Array) -> float:
	return (trace.size() - 1) * 3.0     # les pistes sont rééchantillonnées tous les 3 m


func _point(trace: PackedVector2Array, l: float) -> Vector2:
	var f := clampf(l / 3.0, 0.0, trace.size() - 1.001)
	var i := int(f)
	return trace[i].lerp(trace[i + 1], f - i)


func _abscisse_proche(trace: PackedVector2Array, p: Vector2) -> float:
	var best := 0
	var dmin := INF
	for i in range(0, trace.size(), 2):
		var d := trace[i].distance_squared_to(p)
		if d < dmin:
			dmin = d
			best = i
	return best * 3.0


# ---------------------------------------------------------------------
# Alertes
# ---------------------------------------------------------------------
func _alerte_generale(p: Vector3) -> void:
	# un barrage a donné l'alerte par radio : la patrouille la plus proche fonce
	var meilleur: Dictionary = {}
	var dmin := INF
	for pk in pickups:
		if pk["etat"] != "ronde":
			continue
		var d := (pk["noeud"] as Node3D).global_position.distance_to(p)
		if d < dmin:
			dmin = d
			meilleur = pk
	if not meilleur.is_empty() and dmin < 3500.0:
		_poursuivre(meilleur)
		controles._annoncer("Radio du Cobra : une patrouille arrive !", 3.0)


func _poursuivre(pk: Dictionary) -> void:
	pk["etat"] = "poursuite"
	pk["t_abandon"] = 0.0
	pk["hors_piste"] = false


func _debarquer(pk: Dictionary) -> void:
	pk["etat"] = "arrete"
	var noeud: Node3D = pk["noeud"]
	controles.couverts.append([noeud.global_position, 2.6])   # le pick-up sert de couvert
	var modeles := ["villageois", "homme2"]
	for k in (pk["passagers"] as Array).size():
		var deco: Node3D = pk["passagers"][k]
		deco.queue_free()
		var g := Pnj.new()
		controles.add_child(g)
		var cote := noeud.global_transform.basis.x * (2.0 if k == 0 else -2.0)
		var pos := noeud.global_position + cote - noeud.global_transform.basis.z * 1.5
		g.global_position = Vector3(pos.x, terrain.hauteur(pos.x, pos.z) + 0.3, pos.z)
		g.preparer("milicien", controles, joueur, Color(1, 1, 1), "res://data/textures/camouflage.jpg", modeles[k])
		g.rendu.connect(controles._rendu)
		controles.tous.append(g)
		g._passer_combat()
	pk["passagers"] = []
	(pk["moteur"] as AudioStreamPlayer3D).stop()


# ---------------------------------------------------------------------
# Conduite
# ---------------------------------------------------------------------
func regler_nuit(f: float) -> void:
	nuit = f > 0.5
	for pk in pickups:
		(pk["phare"] as SpotLight3D).visible = nuit and pk["etat"] != "arrete"


func _process(delta: float) -> void:
	if joueur == null:
		return
	var jp := Vector2(joueur.global_position.x, joueur.global_position.z)
	for pk in pickups:
		if pk["etat"] == "arrete":
			continue
		var noeud: Node3D = pk["noeud"]
		var trace: PackedVector2Array = pk["trace"]
		var ici := Vector2(noeud.global_position.x, noeud.global_position.z)
		var d_joueur := ici.distance_to(jp)
		var cible: Vector2
		var vise := V_RONDE
		if pk["etat"] == "ronde":
			# repère un homme armé tout près, ou le voit forcer le passage
			if d_joueur < VUE and joueur.a_une_arme and not joueur.mort:
				_poursuivre(pk)
			pk["l"] = pk["l"] + pk["sens"] * V_RONDE * delta
			if pk["l"] <= 0.0 or pk["l"] >= _longueur(trace):
				pk["sens"] = -pk["sens"]                       # demi-tour au bout de la piste
				pk["l"] = clampf(pk["l"], 0.0, _longueur(trace))
			cible = _point(trace, pk["l"] + pk["sens"] * 4.0)
			ici = _point(trace, pk["l"])
		else:
			vise = V_POURSUITE
			if joueur.mort:
				pk["etat"] = "ronde"
				continue
			if d_joueur < DIST_ARRET:
				_debarquer(pk)
				continue
			if d_joueur > ABANDON:
				pk["t_abandon"] += delta
				if pk["t_abandon"] > 25.0:
					pk["etat"] = "ronde"                       # trop loin : retour à la ronde
					pk["l"] = _abscisse_proche(trace, ici)
					pk.erase("rejoindre")
					continue
			var l_vise := _abscisse_proche(trace, jp)
			if d_joueur < 90.0 or (not pk.has("rejoindre") and absf(l_vise - pk["l"]) < 15.0):
				# tout près, ou au point de la piste le plus proche de lui : coupe à travers la brousse
				pk["hors_piste"] = true
				cible = jp
				var dir := cible - ici
				ici += dir.normalized() * minf(dir.length(), vise * delta)
			elif pk.get("hors_piste", false):
				# il s'est éloigné : on rejoint d'abord la piste
				if not pk.has("rejoindre"):
					pk["rejoindre"] = _abscisse_proche(trace, ici)
				var q := _point(trace, pk["rejoindre"])
				cible = q
				var dir := q - ici
				ici += dir.normalized() * minf(dir.length(), vise * delta)
				if ici.distance_to(q) < 2.0:
					pk["l"] = pk["rejoindre"]
					pk.erase("rejoindre")
					pk["hors_piste"] = false
			else:
				# sur la piste, vers le point le plus proche de Faris
				var l_cible := l_vise
				var sens := signf(l_cible - pk["l"])
				pk["l"] = move_toward(pk["l"], l_cible, vise * delta)
				ici = _point(trace, pk["l"])
				cible = _point(trace, pk["l"] + (sens if sens != 0.0 else 1.0) * 4.0)
		_poser(pk, ici, cible, vise, delta)


func _poser(pk: Dictionary, ici: Vector2, cible: Vector2, v: float, delta: float) -> void:
	var noeud: Node3D = pk["noeud"]
	var dir := cible - ici
	if dir.length() > 0.2:
		var voulu := atan2(dir.x, dir.y)
		pk["cap"] = lerp_angle(pk["cap"], voulu, 1.0 - exp(-4.0 * delta))
	var cap: float = pk["cap"]
	var avant := Vector2(sin(cap), cos(cap))
	var hc := terrain.hauteur(ici.x, ici.y)
	var hf := terrain.hauteur(ici.x + avant.x * 1.6, ici.y + avant.y * 1.6)
	var hb := terrain.hauteur(ici.x - avant.x * 1.6, ici.y - avant.y * 1.6)
	var tangage := atan2(hf - hb, 3.2)
	noeud.global_transform = Transform3D(Basis.from_euler(Vector3(-tangage, cap, 0)), Vector3(ici.x, hc + 0.12, ici.y))
	for r in pk["roues"]:
		(r as Node3D).rotate_object_local(Vector3.RIGHT, v * delta / 0.4)
	(pk["moteur"] as AudioStreamPlayer3D).pitch_scale = 0.5 + 0.35 * v / V_POURSUITE
	(pk["phare"] as SpotLight3D).visible = nuit

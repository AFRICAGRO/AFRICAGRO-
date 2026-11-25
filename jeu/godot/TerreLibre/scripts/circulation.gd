## Vie de Port-Néré : passants, motos-taxis, voitures, taxis, pick-up de patrouille du Cobra, voitures garées.
## Tout suit les rues tracées par VillePortNere (pas de physique : peu coûteux pour un PC modeste).
## Les passants et véhicules ne s'animent que lorsque Faris est en ville ; les passants trop loin
## réapparaissent près de lui.
class_name Circulation
extends Node3D

const NB_PASSANTS := 22
const NB_MOTOS := 7
const NB_VOITURES := 4
const RAYON_VILLE := 520.0
const ADULTES := ["homme3", "homme2", "villageois", "ancien", "femme", "femme2", "femme_agee", "pecheur"]
const ENFANTS := ["garcon", "fille"]
const HOMMES := ["homme2", "villageois", "homme3", "faris"]

var ville: VillePortNere
var terrain: Terrain
var joueur: Node3D
var rng := RandomNumberGenerator.new()
var longueurs: Array = []
var vehicules: Array = []
var passants: Array = []
var phares: Array = []      # matériaux de phares (allumés la nuit)
var spots: Array = []
var actif := true
var mat_carrosserie := {}


func construire(p_ville: VillePortNere, p_joueur: Node3D) -> void:
	ville = p_ville
	terrain = ville.terrain
	joueur = p_joueur
	rng.seed = 77
	for r in ville.rues:
		var pts: PackedVector2Array = r["pts"]
		var cum := PackedFloat32Array([0.0])
		for i in pts.size() - 1:
			cum.append(cum[i] + pts[i].distance_to(pts[i + 1]))
		longueurs.append(cum)
	_garer()
	for i in NB_MOTOS:
		_vehicule("moto", rng.randi_range(0, ville.rues.size() - 1))
	for i in NB_VOITURES:
		_vehicule("taxi" if i % 2 == 0 else "berline", rng.randi_range(0, 1))
	_vehicule("pickup", 0, true)
	for i in NB_PASSANTS:
		_passant()


# ---------------------------------------------------------------------
# Géométrie des rues
# ---------------------------------------------------------------------
func _point(ri: int, l: float) -> Array:
	var pts: PackedVector2Array = ville.rues[ri]["pts"]
	var cum: PackedFloat32Array = longueurs[ri]
	l = clampf(l, 0.0, cum[cum.size() - 1])
	var i := 0
	while i < pts.size() - 2 and cum[i + 1] < l:
		i += 1
	var s := cum[i + 1] - cum[i]
	var t := (pts[i + 1] - pts[i]) / maxf(s, 0.001)
	return [pts[i].lerp(pts[i + 1], (l - cum[i]) / maxf(s, 0.001)), t]


func _total(ri: int) -> float:
	var cum: PackedFloat32Array = longueurs[ri]
	return cum[cum.size() - 1]


## Rue voisine au bout de la rue courante : [indice, abscisse, sens] ou [] s'il n'y en a pas.
func _rue_suivante(ri: int, p: Vector2, vehicule: bool) -> Array:
	var choix: Array = []
	for k in ville.rues.size():
		if k == ri:
			continue
		if vehicule and ville.rues[k]["type"] == "laterite" and ville.rues[ri]["type"] == "asphalte" and rng.randf() < 0.3:
			continue
		var pts: PackedVector2Array = ville.rues[k]["pts"]
		var cum: PackedFloat32Array = longueurs[k]
		for i in pts.size() - 1:
			var ab := pts[i + 1] - pts[i]
			var t := clampf((p - pts[i]).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
			if p.distance_to(pts[i] + ab * t) < (ville.rues[k]["l"] * 0.5 + 6.0):
				var l := cum[i] + ab.length() * t
				var sens := 1.0 if l < _total(k) * 0.5 else -1.0
				if _total(k) > 30.0:
					choix.append([k, l, sens])
				break
	if choix.is_empty():
		return []
	return choix[rng.randi() % choix.size()]


# ---------------------------------------------------------------------
# Véhicules
# ---------------------------------------------------------------------
func _peindre(noeud: Node, couleur: Color) -> void:
	var cle := couleur.to_html()
	for mi in noeud.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for k in m.mesh.get_surface_count():
			var mat := m.mesh.surface_get_material(k)
			if mat == null:
				continue
			if mat.resource_name == "Carrosserie":
				if not mat_carrosserie.has(cle):
					var m2: StandardMaterial3D = (mat as StandardMaterial3D).duplicate()
					m2.albedo_color = couleur
					m2.metallic = 0.35
					m2.roughness = 0.38
					mat_carrosserie[cle] = m2
				m.set_surface_override_material(k, mat_carrosserie[cle])
			elif mat.resource_name == "Phare" and not phares.has(mat):
				phares.append(mat)


func _vehicule(type: String, ri: int, patrouille := false, gare := false, xf := Transform3D()) -> Dictionary:
	var noeud: Node3D = (load("res://vehicules/%s.glb" % type) as PackedScene).instantiate()
	add_child(noeud)
	var couleurs := {
		"taxi": [Color(0.95, 0.72, 0.05)],
		"berline": [Color(0.85, 0.85, 0.83), Color(0.12, 0.12, 0.13), Color(0.55, 0.06, 0.05), Color(0.14, 0.24, 0.45), Color(0.5, 0.52, 0.54)],
		"pickup": [Color(0.3, 0.33, 0.2)],
		"moto": [Color(0.7, 0.05, 0.05), Color(0.08, 0.15, 0.5), Color(0.05, 0.05, 0.05), Color(0.85, 0.85, 0.85)],
	}
	var liste: Array = couleurs[type]
	_peindre(noeud, liste[rng.randi() % liste.size()] * rng.randf_range(0.85, 1.0))
	var roues: Array = []
	for n in noeud.find_children("Roue_*", "", true, false):
		roues.append(n)
	var v := {"noeud": noeud, "roues": roues, "type": type, "ri": ri, "l": 0.0, "sens": 1.0,
			"v": 0.0, "vmax": 9.0, "gare": gare, "r": 0.31}
	if type == "moto":
		v["vmax"] = rng.randf_range(8.0, 11.0)
		v["r"] = 0.3
		var conducteur := _personnage(HOMMES[rng.randi() % HOMMES.size()], "Moto")
		noeud.add_child(conducteur)
		conducteur.position = Vector3(0, 0.2, -0.18)
		if rng.randf() < 0.45: # client du moto-taxi, assis derrière
			var client := _personnage(ADULTES[rng.randi() % ADULTES.size()], "Moto")
			noeud.add_child(client)
			client.position = Vector3(0, 0.26, -0.55)
	elif type == "pickup":
		v["vmax"] = 6.0
		v["r"] = 0.4
		for k in 2: # miliciens debout dans la benne
			var m := _personnage(["villageois", "homme2"][k], "Repos")
			noeud.add_child(m)
			m.position = Vector3(-0.4 + k * 0.8, 0.95, -1.4)
			m.rotation.y = PI * 0.5 * (1.0 if k == 0 else -1.0)
			_camoufler(m)
		var spot := SpotLight3D.new()
		spot.position = Vector3(0, 0.9, 2.7)
		spot.rotation.x = deg_to_rad(-12)
		spot.rotation.y = PI
		spot.spot_range = 28.0
		spot.light_color = Color(1.0, 0.95, 0.85)
		spot.visible = false
		noeud.add_child(spot)
		spots.append(spot)
	else:
		v["vmax"] = rng.randf_range(8.0, 10.5)
		var spot := SpotLight3D.new()
		spot.position = Vector3(0, 0.7, 2.4)
		spot.rotation.x = deg_to_rad(-10)
		spot.rotation.y = PI
		spot.spot_range = 26.0
		spot.light_color = Color(1.0, 0.95, 0.85)
		spot.visible = false
		noeud.add_child(spot)
		spots.append(spot)
	if not gare and type in ["moto", "taxi", "berline", "pickup"]:
		# bruit du moteur (spatialisé), sa hauteur suit la vitesse
		var s: AudioStreamWAV = load("res://sons/moto.wav")
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_end = int(s.get_length() * s.mix_rate)
		var moteur := AudioStreamPlayer3D.new()
		moteur.stream = s
		moteur.unit_size = 6.0 if type == "moto" else 8.0
		moteur.max_distance = 90.0
		moteur.volume_db = -6.0 if type == "moto" else -10.0
		moteur.pitch_scale = 1.0 if type == "moto" else 0.6
		noeud.add_child(moteur)
		moteur.play(rng.randf() * 1.5)
		v["moteur"] = moteur
		v["ton"] = moteur.pitch_scale
	if gare:
		noeud.transform = xf
	else:
		v["l"] = rng.randf_range(10.0, maxf(12.0, _total(ri) - 10.0))
		v["sens"] = 1.0 if rng.randf() < 0.5 else -1.0
		v["v"] = v["vmax"]
		vehicules.append(v)
	return v


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


func _personnage(modele: String, anim: String) -> Node3D:
	var p: Node3D = (load("res://personnages/%s.glb" % modele) as PackedScene).instantiate()
	Apparence.ameliorer(p)
	var ap: AnimationPlayer = p.find_child("AnimationPlayer", true, false)
	if ap:
		ap.play(anim)
		ap.seek(rng.randf() * 0.5)
	return p


func _garer() -> void:
	# voitures garées au bord des ruelles, devant les maisons
	var places := 0
	for essai in 400:
		if places >= 26:
			break
		var ri := rng.randi_range(0, ville.rues.size() - 1)
		var r: Dictionary = ville.rues[ri]
		var l := rng.randf_range(8.0, maxf(9.0, _total(ri) - 8.0))
		var pt: Array = _point(ri, l)
		var t: Vector2 = pt[1]
		var n := Vector2(-t.y, t.x) * (1.0 if rng.randf() < 0.5 else -1.0)
		var moto := rng.randf() < 0.3
		var c: Vector2 = pt[0] + n * (r["l"] * 0.5 + (0.6 if moto else 1.05))
		var libre := true
		for dl in [-2.4, -1.2, 0.0, 1.2, 2.4]:
			for dn in [-0.8, 0.0, 0.8]:
				var q: Vector2 = c + t * (dl * (0.4 if moto else 1.0)) + n * dn
				if ville.bati.has(ville._cle(q)) or ville._dans_autre_rue(q, r, 0.0):
					libre = false
		if not libre or terrain.hauteur(c.x, c.y) < 1.5:
			continue
		var ang := atan2(t.x, t.y) + (PI if rng.randf() < 0.5 else 0.0)
		var h := terrain.hauteur(c.x, c.y)
		var xf := Transform3D(Basis(Vector3.UP, ang), Vector3(c.x, h + 0.05, c.y))
		if moto:
			xf = xf.rotated_local(Vector3.FORWARD, deg_to_rad(9)) # sur sa béquille
		var type: String = "moto" if moto else ["berline", "berline", "taxi", "berline"][rng.randi() % 4]
		_vehicule(type, ri, false, true, xf)
		places += 1
	# pick-up du Cobra garé au premier barrage
	if ville.reperes.has("barrages"):
		var b: Vector3 = ville.reperes["barrages"][0]
		var bvd: PackedVector2Array = ville.reperes["boulevard"]
		var t := (bvd[2] - bvd[0]).normalized()
		var c := Vector2(b.x, b.z) + Vector2(-t.y, t.x) * 9.0 + t * 6.0
		_vehicule("pickup", 0, false, true, Transform3D(Basis(Vector3.UP, atan2(t.x, t.y) + 0.4), Vector3(c.x, terrain.hauteur(c.x, c.y) + 0.05, c.y)))


func _avancer(v: Dictionary, delta: float) -> void:
	var ri: int = v["ri"]
	var r: Dictionary = ville.rues[ri]
	var pt: Array = _point(ri, v["l"])
	var p: Vector2 = pt[0]
	var t: Vector2 = pt[1] * v["sens"]
	# freinage : Faris ou un autre véhicule devant
	var cible: float = v["vmax"]
	var devant := p + t * 3.0
	var jp := Vector2(joueur.global_position.x, joueur.global_position.z)
	if jp.distance_to(devant) < 4.5:
		cible = 0.0
	for o in vehicules:
		if o == v:
			continue
		var op: Vector2 = Vector2((o["noeud"] as Node3D).position.x, (o["noeud"] as Node3D).position.z)
		var d := op - p
		if d.length() < 9.0 and d.normalized().dot(t) > 0.8:
			cible = minf(cible, maxf(0.0, (d.length() - 5.0) * 1.2))
	v["v"] = move_toward(v["v"], cible, delta * (6.0 if cible < v["v"] else 2.5))
	v["l"] += v["v"] * v["sens"] * delta
	if v["l"] > _total(ri) - 2.0 or v["l"] < 2.0:
		var suite := _rue_suivante(ri, p, true)
		if suite.is_empty():
			v["sens"] = -v["sens"]
			v["l"] = clampf(v["l"], 2.1, _total(ri) - 2.1)
		else:
			v["ri"] = suite[0]
			v["l"] = suite[1]
			v["sens"] = suite[2]
		return
	# voie de droite
	var demi: float = r["l"] * 0.5
	var lat := demi * (0.45 if v["type"] != "moto" else 0.62)
	var n := Vector2(-t.y, t.x)
	var q := p + n * lat
	var hq := terrain.hauteur(q.x, q.y) + (0.13 if r["type"] == "asphalte" else 0.08)
	var hf := terrain.hauteur(q.x + t.x * 1.5, q.y + t.y * 1.5)
	var hb := terrain.hauteur(q.x - t.x * 1.5, q.y - t.y * 1.5)
	var noeud: Node3D = v["noeud"]
	var cible_pos := Vector3(q.x, hq, q.y)
	var fwd := Vector3(t.x, (hf - hb) / 3.0, t.y).normalized()
	var b := Basis.looking_at(-fwd, Vector3.UP)
	# virage en douceur
	noeud.transform = Transform3D(noeud.transform.basis.orthonormalized().slerp(b, minf(1.0, delta * 6.0)) if noeud.position.distance_to(cible_pos) < 6.0 else b, cible_pos)
	if v["type"] == "moto":
		var inclinaison := (noeud.transform.basis.z.cross(b.z)).y
		noeud.rotate_object_local(Vector3.FORWARD, clampf(inclinaison * 6.0, -0.35, 0.35))
	if v.has("moteur"):
		(v["moteur"] as AudioStreamPlayer3D).pitch_scale = v["ton"] * (0.75 + 0.5 * v["v"] / v["vmax"])
	for roue in v["roues"]:
		(roue as Node3D).rotate_object_local(Vector3.RIGHT, v["v"] * delta / v["r"])


# ---------------------------------------------------------------------
# Passants
# ---------------------------------------------------------------------
func _passant() -> void:
	var enfant := rng.randf() < 0.14
	var modele: String = ENFANTS[rng.randi() % 2] if enfant else ADULTES[rng.randi() % ADULTES.size()]
	var p := _personnage(modele, "Marche")
	add_child(p)
	var s := {"noeud": p, "anim": p.find_child("AnimationPlayer", true, false), "ri": 0, "l": 0.0, "sens": 1.0,
			"v": rng.randf_range(1.0, 1.45) * (0.85 if modele == "femme_agee" or modele == "ancien" else 1.0),
			"arret": 0.0, "cote": 1.0 if rng.randf() < 0.5 else -1.0}
	if modele.begins_with("femme") and rng.randf() < 0.45:
		_bassine(p)
	passants.append(s)
	_replacer(s, true)


## Bassine posée sur la tête (marchandes) : suit l'os de la tête.
func _bassine(p: Node3D) -> void:
	var sq: Skeleton3D = p.find_child("Skeleton3D", true, false)
	if sq == null:
		return
	var os := "mixamorig_HeadTop_End"
	if sq.find_bone(os) < 0:
		os = "mixamorig_Head"
	var att := BoneAttachment3D.new()
	att.bone_name = os
	sq.add_child(att)
	var b := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.3
	c.bottom_radius = 0.2
	c.height = 0.13
	b.mesh = c
	var m := StandardMaterial3D.new()
	m.albedo_color = [Color(0.75, 0.76, 0.78), Color(0.85, 0.2, 0.15), Color(0.15, 0.35, 0.75)][rng.randi() % 3]
	m.metallic = 0.6 if m.albedo_color.r > 0.7 and m.albedo_color.b > 0.7 else 0.0
	m.roughness = 0.4
	b.material_override = m
	b.position = Vector3(0, 0.08 if os.ends_with("End") else 0.24, 0)
	att.add_child(b)
	var fruits := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.22
	sp.height = 0.16
	fruits.mesh = sp
	var mf := StandardMaterial3D.new()
	mf.albedo_color = [Color(0.95, 0.6, 0.1), Color(0.3, 0.55, 0.15), Color(0.8, 0.15, 0.1)][rng.randi() % 3]
	fruits.material_override = mf
	fruits.position = b.position + Vector3(0, 0.07, 0)
	att.add_child(fruits)


func _replacer(s: Dictionary, partout: bool) -> void:
	# nouvelle position sur une rue, près de Faris si possible (sinon n'importe où en ville)
	var jp := Vector2(joueur.global_position.x, joueur.global_position.z)
	for essai in 30:
		var ri := rng.randi_range(0, ville.rues.size() - 1)
		var l := rng.randf_range(3.0, maxf(4.0, _total(ri) - 3.0))
		var p: Vector2 = _point(ri, l)[0]
		var d := p.distance_to(jp)
		if partout or (d > 35.0 and d < 140.0):
			s["ri"] = ri
			s["l"] = l
			s["sens"] = 1.0 if rng.randf() < 0.5 else -1.0
			s["arret"] = rng.randf_range(4.0, 25.0) if rng.randf() < 0.3 else 0.0
			return


func _marcher(s: Dictionary, delta: float) -> void:
	var ri: int = s["ri"]
	var r: Dictionary = ville.rues[ri]
	var noeud: Node3D = s["noeud"]
	var ap: AnimationPlayer = s["anim"]
	if s["arret"] > 0.0:
		# discute ou attend devant une boutique
		s["arret"] -= delta
		if ap.current_animation != "Repos":
			ap.play("Repos", 0.4)
		if s["arret"] <= 0.0:
			ap.play("Marche", 0.4)
		return
	s["l"] += s["v"] * s["sens"] * delta
	if s["l"] > _total(ri) - 1.0 or s["l"] < 1.0:
		var p0: Vector2 = _point(ri, s["l"])[0]
		var suite := _rue_suivante(ri, p0, false)
		if suite.is_empty() or rng.randf() < 0.3:
			s["sens"] = -s["sens"]
			s["l"] = clampf(s["l"], 1.1, _total(ri) - 1.1)
		else:
			s["ri"] = suite[0]
			s["l"] = suite[1]
			s["sens"] = suite[2]
		return
	var pt: Array = _point(ri, s["l"])
	var t: Vector2 = pt[1] * s["sens"]
	var n := Vector2(-t.y, t.x)
	var asphalte: bool = r["type"] == "asphalte"
	var lat: float = (r["l"] * 0.5 + 1.1) if asphalte else (r["l"] * 0.5 - 0.55)
	var q: Vector2 = pt[0] + n * lat * s["cote"]
	var h := terrain.hauteur(q.x, q.y) + (0.27 if asphalte else 0.08)
	noeud.position = Vector3(q.x, h, q.y)
	var ang := atan2(t.x, t.y)
	noeud.rotation.y = lerp_angle(noeud.rotation.y, ang, minf(1.0, delta * 5.0))
	if rng.randf() < delta * 0.02:
		s["arret"] = rng.randf_range(3.0, 15.0)


# ---------------------------------------------------------------------
func _process(delta: float) -> void:
	if joueur == null:
		return
	var jp := Vector2(joueur.global_position.x, joueur.global_position.z)
	var en_ville := jp.distance_to(ville.centre) < RAYON_VILLE
	if en_ville != actif:
		actif = en_ville
		for v in vehicules:
			(v["noeud"] as Node3D).visible = actif
		for s in passants:
			(s["noeud"] as Node3D).visible = actif
			var ap: AnimationPlayer = s["anim"]
			ap.active = actif
	if not actif:
		return
	delta = minf(delta, 0.1)
	for v in vehicules:
		_avancer(v, delta)
	for s in passants:
		var noeud: Node3D = s["noeud"]
		var d := Vector2(noeud.position.x, noeud.position.z).distance_to(jp)
		if d > 190.0:
			_replacer(s, false)
		_marcher(s, delta)
		# loin de Faris : on cache et on fige l'animation (économie)
		var proche := d < 120.0
		if noeud.visible != proche:
			noeud.visible = proche
			(s["anim"] as AnimationPlayer).active = proche


## Phares allumés le soir et la nuit.
func regler_nuit(f: float) -> void:
	for m in phares:
		(m as StandardMaterial3D).emission_energy_multiplier = 0.3 + 3.0 * f
	for sp in spots:
		(sp as SpotLight3D).visible = f > 0.3
		(sp as SpotLight3D).light_energy = 4.0 * f

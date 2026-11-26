## Foule à trois niveaux, comme dans les grands mondes ouverts, mais à la mesure d'un petit PC :
## - de près (moins de 30 m) : de vrais personnages animés, pris dans une réserve limitée (MAX_PROCHES) ;
## - de 30 à 260 m : des silhouettes photographiées (data/foule/atlas.png), une seule passe de dessin
##   pour toute la foule, avec les 8 angles de vue et le cycle de marche (shaders/foule.gdshader) ;
## - au-delà : rien à dessiner, la rumeur sonore de la ville suffit.
## Les passants suivent les rues et les sentiers ; d'autres restent sur place (marché, place, cours) et
## discutent par deux ou trois. La nuit, le couvre-feu vide les rues (part réglable par zone).
class_name Foule
extends Node3D

const MODELES := ["homme2", "homme3", "villageois", "ancien", "femme", "femme2", "femme_agee", "pecheur",
	"garcon", "fille", "cultivateur"]
const R_ENTREE := 28.0     # en deçà : vrai personnage
const R_SORTIE := 34.0     # au-delà : retour à la silhouette
const MAX_PROCHES := 18
const ANIMS_BOUCLE := ["Marche", "Repos"]

var terrain: Terrain
var rng := RandomNumberGenerator.new()
var agents: Array = []
var zones := {}            # nom -> {"actif": bool, "nuit": part visible la nuit}
var chemins: Array = []    # {"pts": PackedVector2Array, "cumul": PackedFloat32Array}
var mm: MultiMesh
var buffer := PackedFloat32Array()
var libres := {}           # modèle -> personnages complets disponibles
var nb_proches := 0
var nuit := 0.0
var _minuteur := 0.0


func preparer(t: Terrain) -> void:
	terrain = t
	rng.seed = 2026


func zone(nom: String, actif: bool, part_nuit: float) -> void:
	zones[nom] = {"actif": actif, "nuit": part_nuit}


func activer(nom: String, oui := true) -> void:
	if zones.has(nom):
		zones[nom]["actif"] = oui


## Passants qui vont et viennent le long de chemins (rues, sentiers).
## decalage : écart au milieu du chemin (trottoirs) ; écart_min : on reste hors de la chaussée.
func marcheurs(nom: String, lignes: Array, nb: int, modeles: Array, decalage_max: float, ecart_min := 0.0, plancher := NAN) -> void:
	var debut := chemins.size()
	var total := 0.0
	for l in lignes:
		var pts: PackedVector2Array = l
		if pts.size() < 2:
			continue
		var cumul := PackedFloat32Array([0.0])
		for i in pts.size() - 1:
			cumul.append(cumul[i] + pts[i].distance_to(pts[i + 1]))
		chemins.append({"pts": pts, "cumul": cumul})
		total += cumul[cumul.size() - 1]
	if total <= 0.0:
		return
	for k in nb:
		# chemin tiré au sort en proportion de sa longueur
		var x := rng.randf() * total
		var ci := debut
		while ci < chemins.size() - 1 and x > chemins[ci]["cumul"][chemins[ci]["cumul"].size() - 1]:
			x -= chemins[ci]["cumul"][chemins[ci]["cumul"].size() - 1]
			ci += 1
		var long: float = chemins[ci]["cumul"][chemins[ci]["cumul"].size() - 1]
		var cote := 1.0 if rng.randf() < 0.5 else -1.0
		var dec := cote * lerpf(ecart_min, decalage_max, rng.randf()) if decalage_max > ecart_min else 0.0
		_nouvel_agent(nom, modeles[rng.randi() % modeles.size()], {
			"marche": true, "c": ci, "s": rng.randf() * long, "long": long, "sens": cote,
			"v": rng.randf_range(0.95, 1.45), "dec": dec, "i": 0, "pause": 0.0})
		if not is_nan(plancher):
			agents[agents.size() - 1]["plancher"] = plancher
			agents[agents.size() - 1]["pos"] = Vector3(0, plancher, 0)


## Personnes qui restent sur place : [Vector2 position, angle du regard].
func immobiles(nom: String, points: Array, modeles: Array, plancher := NAN) -> void:
	for p in points:
		var a := {"marche": false, "p": p[0], "cap": p[1]}
		if not is_nan(plancher):
			a["plancher"] = plancher
		_nouvel_agent(nom, modeles[rng.randi() % modeles.size()], a)


## Petits groupes qui discutent autour d'un point (2 ou 3 personnes face à face).
func groupes(nom: String, centres: Array, modeles: Array, libre: Callable) -> void:
	for c in centres:
		var n := 2 + rng.randi() % 2
		var a0 := rng.randf() * TAU
		for k in n:
			var a := a0 + TAU * k / n
			var p: Vector2 = c + Vector2(cos(a), sin(a)) * 0.8
			if libre.is_valid() and not libre.call(p):
				continue
			_nouvel_agent(nom, modeles[rng.randi() % modeles.size()], {"marche": false, "p": p, "cap": atan2(c.x - p.x, c.y - p.y)})


func _nouvel_agent(nom: String, modele: String, a: Dictionary) -> void:
	a["zone"] = nom
	a["m"] = MODELES.find(modele)
	a["modele"] = modele
	a["phase"] = rng.randf()
	a["seuil"] = rng.randf()
	a["proche"] = null
	a["pos"] = Vector3.ZERO
	if not a["marche"]:
		var p: Vector2 = a["p"]
		a["pos"] = Vector3(p.x, a["plancher"] if a.has("plancher") else terrain.hauteur(p.x, p.y), p.y)
	else:
		a["cap"] = 0.0
	agents.append(a)


## À appeler une fois toutes les zones remplies.
func finaliser() -> void:
	var q := QuadMesh.new()
	q.size = Vector2(1.05, 2.1)
	q.center_offset = Vector3(0, 1.05, 0)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/foule.gdshader")
	mat.set_shader_parameter("atlas", load("res://data/foule/atlas.png"))
	q.material = mat
	mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = q
	mm.instance_count = agents.size()
	buffer.resize(agents.size() * 16)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Silhouettes"
	mmi.multimesh = mm
	mmi.custom_aabb = AABB(Vector3(-4000, -100, -4000), Vector3(8000, 600, 8000))
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	print("Foule : %d habitants (%s)" % [agents.size(), ", ".join(zones.keys())])


func regler_nuit(f: float) -> void:
	nuit = f


func _visible(a: Dictionary) -> bool:
	var z: Dictionary = zones[a["zone"]]
	if not z["actif"]:
		return false
	return a["seuil"] < lerpf(1.0, z["nuit"], nuit)


func _process(delta: float) -> void:
	if mm == null:
		return
	var cam := get_viewport().get_camera_3d()
	var ici := cam.global_position if cam else Vector3.ZERO
	for idx in agents.size():
		var a: Dictionary = agents[idx]
		var vis := _visible(a)
		var marche := false
		if vis and a["marche"]:
			marche = _avancer(a, delta)
		var b := idx * 16
		var p: Vector3 = a["pos"]
		buffer[b] = 1.0; buffer[b + 1] = 0.0; buffer[b + 2] = 0.0; buffer[b + 3] = p.x
		buffer[b + 4] = 0.0; buffer[b + 5] = 1.0; buffer[b + 6] = 0.0; buffer[b + 7] = p.y
		buffer[b + 8] = 0.0; buffer[b + 9] = 0.0; buffer[b + 10] = 1.0; buffer[b + 11] = p.z
		buffer[b + 12] = a["m"]
		buffer[b + 13] = a["cap"]
		buffer[b + 14] = a["phase"]
		var etat := 1.0 if marche else 0.0
		if not vis or a["proche"] != null:
			etat = -1.0
		buffer[b + 15] = etat
		var pr: Node3D = a["proche"]
		if pr:
			pr.global_position = _sur_le_sol(p)
			pr.rotation.y = a["cap"]
			var ap: AnimationPlayer = pr.get_meta("ap")
			var voulu := "Marche" if marche else "Repos"
			if ap.current_animation != voulu:
				ap.play(voulu, 0.25)
			if not vis:
				_rendre(a)
	mm.buffer = buffer
	_minuteur -= delta
	if _minuteur <= 0.0:
		_minuteur = 0.25
		_echanger(ici)


## Fait avancer un passant ; renvoie vrai s'il marche (faux pendant une pause au bout du chemin).
func _avancer(a: Dictionary, delta: float) -> bool:
	if a["pause"] > 0.0:
		a["pause"] -= delta
		return false
	var ch: Dictionary = chemins[a["c"]]
	var pts: PackedVector2Array = ch["pts"]
	var cumul: PackedFloat32Array = ch["cumul"]
	var s: float = a["s"] + a["v"] * a["sens"] * delta
	if s < 0.0 or s > a["long"]:
		s = clampf(s, 0.0, a["long"])
		a["sens"] = -a["sens"]
		a["pause"] = rng.randf_range(1.5, 7.0)
	a["s"] = s
	var i: int = a["i"]
	while i < pts.size() - 2 and s > cumul[i + 1]:
		i += 1
	while i > 0 and s < cumul[i]:
		i -= 1
	a["i"] = i
	var seg := pts[i + 1] - pts[i]
	var l := maxf(0.001, cumul[i + 1] - cumul[i])
	var dir := seg / l
	var q: Vector2 = pts[i] + dir * (s - cumul[i]) + dir.orthogonal() * a["dec"]
	a["pos"] = Vector3(q.x, a["plancher"] if a.has("plancher") else terrain.hauteur(q.x, q.y), q.y)
	var sens_v: Vector2 = dir * a["sens"]
	a["cap"] = atan2(sens_v.x, sens_v.y)
	return true


## Échange silhouettes et vrais personnages autour de la caméra.
func _echanger(ici: Vector3) -> void:
	var candidats: Array = []
	for a in agents:
		var d := ici.distance_to(a["pos"])
		if a["proche"] != null:
			if d > R_SORTIE:
				_rendre(a)
		elif d < R_ENTREE and _visible(a):
			candidats.append([d, a])
	candidats.sort_custom(func(x, y): return x[0] < y[0])
	for c in candidats:
		if nb_proches >= MAX_PROCHES:
			break
		_prendre_perso(c[1])


func _prendre_perso(a: Dictionary) -> void:
	var nom: String = a["modele"]
	var liste: Array = libres.get(nom, [])
	var p: Node3D
	if liste.is_empty():
		p = (load("res://personnages/%s.glb" % nom) as PackedScene).instantiate()
		Apparence.ameliorer(p)
		add_child(p)
		var ap: AnimationPlayer = p.find_child("AnimationPlayer", true, false)
		for an in ANIMS_BOUCLE:
			ap.get_animation(an).loop_mode = Animation.LOOP_LINEAR
		p.set_meta("ap", ap)
	else:
		p = liste.pop_back()
		p.visible = true
	var ap2: AnimationPlayer = p.get_meta("ap")
	ap2.play("Marche" if a["marche"] and a["pause"] <= 0.0 else "Repos")
	ap2.seek(a["phase"] * ap2.current_animation_length, true)
	p.global_position = _sur_le_sol(a["pos"])
	p.rotation.y = a["cap"]
	a["proche"] = p
	nb_proches += 1


## Les personnages proches se posent sur la chaussée ou le trottoir (plus hauts que le relief),
## pour que leurs pieds ne s'y enfoncent pas.
func _sur_le_sol(p: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.5, 0), p - Vector3(0, 0.3, 0), 1)
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		return p
	return Vector3(p.x, maxf(p.y, (r["position"] as Vector3).y), p.z)


func _rendre(a: Dictionary) -> void:
	var p: Node3D = a["proche"]
	p.visible = false
	var nom: String = a["modele"]
	if not libres.has(nom):
		libres[nom] = []
	libres[nom].append(p)
	a["proche"] = null
	nb_proches -= 1


# =====================================================================
# Peuplement des lieux
# =====================================================================
const CITADINS := ["homme2", "homme3", "villageois", "femme", "femme2", "homme2", "femme", "femme2",
	"ancien", "femme_agee", "garcon", "fille", "pecheur"]
const VILLAGEOIS := ["villageois", "femme", "femme2", "femme_agee", "ancien", "cultivateur", "cultivateur",
	"homme3", "garcon", "fille", "femme"]
const PECHEURS := ["pecheur", "pecheur", "villageois", "femme", "femme2", "femme_agee", "garcon", "fille", "homme3"]


func _autour(c: Vector2, rayon: float, n: int, libre: Callable) -> Array:
	var res: Array = []
	for essai in n * 6:
		if res.size() >= n:
			break
		var a := rng.randf() * TAU
		var p := c + Vector2(cos(a), sin(a)) * sqrt(rng.randf()) * rayon
		if libre.call(p) and terrain.hauteur(p.x, p.y) > 0.6:
			res.append(p)
	return res


## Port-Néré : ≈ 2 000 habitants ; en journée, 250 à 300 dehors. Couvre-feu du Cobra la nuit.
func peupler_port_nere(v: VillePortNere) -> void:
	zone("port_nere", true, 0.06)
	var libre := func(p: Vector2) -> bool: return not v.bati.has(v._cle(p))
	var asph: Array = []
	var terre: Array = []
	for r in v.rues:
		if r["type"] == "asphalte":
			asph.append(r["pts"])
		else:
			terre.append(r["pts"])
	# trottoirs des grandes rues, milieu des ruelles en terre
	marcheurs("port_nere", asph, 110, CITADINS, 6.5, 4.6)
	marcheurs("port_nere", terre, 70, CITADINS, 1.6, 0.0)
	var r: Dictionary = v.reperes
	# marché central : une marchande derrière chaque étal, des clients dans les allées
	if r.has("marche_xf"):
		var x: Transform3D = r["marche_xf"]
		var sol: float = x.origin.y - 0.3
		var vendeuses := ["femme", "femme2", "femme_agee", "femme", "femme2", "homme3"]
		var cap0 := atan2(x.basis.z.x, x.basis.z.z)
		var etals: Array = []
		for rang in 4:
			for i in 6:
				if rng.randf() < 0.85:
					var q3 := x * Vector3(-14.0 + i * 5.6 + rng.randf_range(-1.0, 1.0), 0, -9.0 + rang * 6.0 + 1.35)
					etals.append([Vector2(q3.x, q3.z), cap0 + PI])
		immobiles("port_nere", etals, vendeuses, sol)
		var allees: Array = []
		for z in [-12.0, -6.0, 0.0, 6.0, 12.0]:
			var a3 := x * Vector3(-16.5, 0, z - 1.4)
			var b3 := x * Vector3(16.5, 0, z - 1.4)
			allees.append(PackedVector2Array([Vector2(a3.x, a3.z), Vector2(b3.x, b3.z)]))
		marcheurs("port_nere", allees, 34, CITADINS, 0.6, 0.0, sol)
	var lieux := [["marche", 22.0, 6], ["place", 18.0, 7], ["maquis", 9.0, 4], ["station", 10.0, 2],
		["eglise", 14.0, 4], ["mosquee", 14.0, 4], ["gendarmerie", 10.0, 1]]
	for l in lieux:
		if r.has(l[0]):
			var p3: Vector3 = r[l[0]]
			groupes("port_nere", _autour(Vector2(p3.x, p3.z), l[1], l[2], libre), CITADINS, libre)
	# clients devant les boutiques
	var pris := 0
	for b in v.boutiques:
		if rng.randf() < 0.35 and pris < 40:
			var devant: Vector2 = b[0]
			var avant: Vector2 = b[1]
			var p := devant + avant * rng.randf_range(0.8, 1.6) + avant.orthogonal() * rng.randf_range(-1.0, 1.0)
			if libre.call(p):
				immobiles("port_nere", [[p, atan2(-avant.x, -avant.y) + rng.randf_range(-0.4, 0.4)]], CITADINS)
				pris += 1


## Bomé : ≈ 130 habitants ; une soixantaine dehors, aux champs, dans les cours, sur les sentiers.
func peupler_bome(v: VillageBome) -> void:
	zone("bome", true, 0.12)
	var libre := func(p: Vector2) -> bool: return not v.bati.has(v._cle(p))
	var sentiers: Array = []
	for r in v.rues:
		sentiers.append(r["pts"])
	marcheurs("bome", sentiers, 22, VILLAGEOIS, 0.5, 0.0)
	for m in v.reperes["maisons"]:
		var p3: Vector3 = m
		var c := Vector2(p3.x, p3.z)
		var vers: Vector3 = v.reperes["place"] - p3
		var cour := c + Vector2(vers.x, vers.z).normalized() * 6.0
		if rng.randf() < 0.6:
			groupes("bome", [cour], VILLAGEOIS, libre)
		else:
			immobiles("bome", [[cour, rng.randf() * TAU]], VILLAGEOIS)
	var pl: Vector3 = v.reperes["place"]
	groupes("bome", _autour(Vector2(pl.x, pl.z), 14.0, 3, libre), VILLAGEOIS, libre)
	for ch in v.reperes["champs"]:
		var p: Vector2 = ch
		immobiles("bome", [[p + Vector2(rng.randf_range(-10, 10), rng.randf_range(-8, 8)), rng.randf() * TAU]], VILLAGEOIS)


## Akwéri : village de pêcheurs ; il ne revit qu'une fois libéré (mission 4).
func peupler_akweri(v: Node3D) -> void:
	zone("akweri", false, 0.25)
	var m := func(avant: float, cote: float) -> Vector2: return v.centre + v.mer * avant + v.plage * cote
	var lignes: Array = []
	for avant in [-35.0, -15.0, 2.0]:
		lignes.append(PackedVector2Array([m.call(avant, -55.0), m.call(avant, 0.0), m.call(avant, 55.0)]))
	for cote in [-18.0, 6.0, 30.0]:
		lignes.append(PackedVector2Array([m.call(-55.0, cote), m.call(-25.0, cote + 3.0), m.call(4.0, cote)]))
	marcheurs("akweri", lignes, 18, PECHEURS, 0.8, 0.0)
	var vide := Callable()
	var pts: Array = []
	for k in range(-2, 3):
		pts.append(m.call(-3.5, k * 14.0 + 5.0 + rng.randf_range(-2, 2)))   # devant les fumoirs
	for k in range(-4, 5, 2):
		pts.append(m.call(5.0, k * 9.0 + 2.0))                               # près des pirogues
	groupes("akweri", pts, PECHEURS, vide)
	groupes("akweri", [m.call(-15.0, 0.0), m.call(-35.0, -10.0)], PECHEURS, vide)

## Mission 2 — « La Veillée » (jeu/missions/02-LA-VEILLEE.md). Nuit, couvre-feu, pas de combat ni de mort.
## Le couvre-feu (furtivité : patrouilles à lampe torche, jauge « vu », C pour s'accroupir ; repéré, Faris
## est ramené au début du quartier) → la maison du père, fouillée par la milice, Baya Efua dans le noir
## → les souvenirs (lumière dorée, voix de Samuel) → la boîte en fer sous la pierre plate du manguier :
## le carnet, le relevé bancaire, la photo, la clé USB → le tableau des preuves → « Trouver Ama ».
class_name Mission2
extends Recit

enum Phase { INDISPONIBLE, COUVRE_FEU, MAISON, CACHETTE, DECISION, TERMINEE }
const PORTEE := 17.0
const PORTEE_ACCROUPI := 8.5
const ANGLE := 0.72             # demi-angle du faisceau (rad)
## Les documents de Samuel (prologue) : comptés à part des preuves contre le réseau dans le bilan de l'acte 1.
const DOCUMENTS := ["Page du carnet de Samuel", "Le carnet de Samuel", "Un relevé bancaire", "Une photo", "Une clé USB"]

var phase := Phase.INDISPONIBLE
var m12: Mission12
var depart := Vector3.ZERO
var maison := Vector3.ZERO      # centre de la concession
var arbre := Vector3.ZERO       # le manguier de la cour
var poste := Vector3.INF        # la grande route : poste éclairé de la milice
var patrouilles: Array = []     # {n, pts, l, sens, v, pause, lampe, vu}
var vu := 0.0
var t_sifflet := 0.0
var reprises := 0
var souvenirs := {}
var baya: Node3D
var pierre: Node3D
var jauge: ProgressBar
var bloc_jauge: Control
var tableau: Control
var lueur: ColorRect


func construire(p_main: Node) -> void:
	preparer_recit(p_main)
	m12 = main.get_node("Mission12")
	depart = _au_sol(m12.lieu_cimetiere * Vector3(0, 0, 15.0))
	maison = ville.reperes.get("maison_faris", ville.reperes["place"])
	arbre = _au_sol(maison + Vector3(4.5, 0, -5.0))
	_interface_m2()


func est_terminee() -> bool:
	return phase == Phase.TERMINEE


## Chargement d'une partie où cette mission n'a pas encore commencé.
func annuler() -> void:
	if phase == Phase.INDISPONIBLE:
		return
	terminer()
	phase = Phase.INDISPONIBLE


func etat_texte() -> String:
	return ["à venir", "le couvre-feu", "la maison du père", "la cachette", "la décision", "terminée"][phase]


func _interface_m2() -> void:
	bloc_jauge = VBoxContainer.new()
	bloc_jauge.anchor_left = 1.0
	bloc_jauge.anchor_right = 1.0
	bloc_jauge.offset_left = -250
	bloc_jauge.offset_right = -20
	bloc_jauge.offset_top = 100
	var t := Label.new()
	t.text = "Vu"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 15)
	bloc_jauge.add_child(t)
	jauge = ProgressBar.new()
	jauge.custom_minimum_size = Vector2(220, 12)
	jauge.show_percentage = false
	jauge.max_value = 1.0
	var plein := StyleBoxFlat.new()
	plein.bg_color = Color(0.95, 0.85, 0.3)
	jauge.add_theme_stylebox_override("fill", plein)
	bloc_jauge.add_child(jauge)
	bloc_jauge.visible = false
	calque.add_child(bloc_jauge)
	# lumière dorée des souvenirs
	lueur = ColorRect.new()
	lueur.color = Color(1.0, 0.78, 0.35, 0.0)
	lueur.set_anchors_preset(Control.PRESET_FULL_RECT)
	lueur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	calque.add_child(lueur)
	calque.move_child(lueur, 0)


# ---------------------------------------------------------------------
# Le couvre-feu
# ---------------------------------------------------------------------
func commencer() -> void:
	gen += 1
	_effacer_decor()
	_effacer_patrouilles()
	phase = Phase.COUVRE_FEU
	joueur.mission = self
	souvenirs.clear()
	reprises = 0
	vu = 0.0
	_ambiance(3)
	joueur.visible = true
	joueur.ressusciter(depart + Vector3(0, 0.6, 0))
	m4.reprise_prologue = depart + Vector3(0, 0.6, 0)
	joueur.lacet = atan2(depart.x - maison.x, depart.z - maison.z)
	var co: Node = main.get_node_or_null("Controles")
	if co:
		co.set("prologue", self)
	_installer_patrouilles()
	_installer_maison()
	bloc_jauge.visible = true
	_objectif("Rejoignez la maison de votre père sans passer par la grande route.\nC : s'accroupir (on voit moins loin un homme accroupi) · évitez le faisceau des lampes.")
	_balise(maison)
	_entree_en_fondu()
	@warning_ignore("missing_await")
	_dire("RADIO D'ÉTAT", "Pour votre sécurité, aucun déplacement après 20 heures. Tout contrevenant sera considéré comme un bandit.", 6.0)


func _effacer_patrouilles() -> void:
	for p in patrouilles:
		if is_instance_valid(p["n"]):
			(p["n"] as Node).queue_free()
	patrouilles.clear()


## Point d'une rue le plus proche ; renvoie [rue, abscisse].
func _rue_proche(q: Vector2) -> Array:
	var meilleur := INF
	var res := []
	for rue in ville.rues:
		var pts: PackedVector2Array = rue["pts"]
		var l := 0.0
		for i in pts.size() - 1:
			var ab := pts[i + 1] - pts[i]
			var u := clampf((q - pts[i]).dot(ab) / ab.length_squared(), 0.0, 1.0)
			var d := q.distance_to(pts[i] + ab * u)
			if d < meilleur:
				meilleur = d
				res = [pts, l + ab.length() * u, d]
			l += ab.length()
	return res


func _sur_rue(pts: PackedVector2Array, l: float) -> Vector3:
	var reste := l
	for i in pts.size() - 1:
		var seg := pts[i].distance_to(pts[i + 1])
		if reste <= seg:
			var q := pts[i].lerp(pts[i + 1], reste / seg)
			return _au_sol(Vector3(q.x, 0, q.y))
		reste -= seg
	var f := pts[pts.size() - 1]
	return _au_sol(Vector3(f.x, 0, f.y))


func _longueur(pts: PackedVector2Array) -> float:
	var l := 0.0
	for i in pts.size() - 1:
		l += pts[i].distance_to(pts[i + 1])
	return l


func _installer_patrouilles() -> void:
	var a := _plat(depart)
	var b := _plat(maison)
	var fractions := [0.28, 0.5, 0.72]
	if str(main.get_meta("m1_barrage", "")) == "provoquer":
		fractions = [0.2, 0.36, 0.5, 0.64, 0.8]      # la milice surveille désormais Faris
	for k in fractions.size():
		var q := a.lerp(b, fractions[k])
		var r := _rue_proche(q)
		if r.is_empty() or float(r[2]) > 60.0:
			continue
		var pts: PackedVector2Array = r[0]
		var lt := _longueur(pts)
		var l0 := clampf(float(r[1]) - 24.0, 0.0, lt)
		var l1 := clampf(float(r[1]) + 24.0, 0.0, lt)
		if l1 - l0 < 10.0:
			continue
		var n := vq._perso(["homme2", "villageois", "homme3"][k % 3], "Marche", _sur_rue(pts, l0), 0.0)
		n.reparent(self)
		vq._camoufler(n)
		_foulard(n)
		var lampe := SpotLight3D.new()
		lampe.light_color = Color(1.0, 0.95, 0.8)
		lampe.light_energy = 4.0
		lampe.spot_range = PORTEE + 3.0
		lampe.spot_angle = 26.0
		lampe.shadow_enabled = false
		n.add_child(lampe)
		lampe.position = Vector3(0.25, 1.3, 0.3)
		lampe.rotation = Vector3(-0.18, PI, 0)     # vers l'avant du personnage (+Z)
		patrouilles.append({"n": n, "pts": pts, "l0": l0, "l1": l1, "l": l0 + (l1 - l0) * float(k % 2), "sens": 1.0 if k % 2 == 0 else -1.0,
				"v": 1.25, "pause": 0.0, "regard": 0.0})
	# la grande route : la rue principale la plus proche du milieu, tenue par un poste éclairé
	var milieu := a.lerp(b, 0.5)
	var meilleur := INF
	for nom in ["boulevard", "avenue"]:
		if not ville.reperes.has(nom):
			continue
		var pts: PackedVector2Array = ville.reperes[nom]
		for i in pts.size() - 1:
			var ab := pts[i + 1] - pts[i]
			var u := clampf((milieu - pts[i]).dot(ab) / ab.length_squared(), 0.0, 1.0)
			var p := pts[i] + ab * u
			var d := p.distance_to(milieu)
			if d < meilleur:
				meilleur = d
				poste = _au_sol(Vector3(p.x, 0, p.y))
	if meilleur > 160.0:
		poste = Vector3.INF
		return
	var xp := Transform3D(Basis(), poste)
	_pickup(xp.translated(Vector3(3.0, 0, 0)))
	for k in 2:
		var g := _milicien_decor(poste + Vector3(-1.2 + k * 2.4, 0, 1.5), 0.0, ["homme3", "homme2"][k])
		regards.append([g, 30.0])
	var projo := OmniLight3D.new()
	projo.light_color = Color(1.0, 0.92, 0.75)
	projo.light_energy = 3.0
	projo.omni_range = 22.0
	add_child(projo)
	decor.append(projo)
	projo.global_position = poste + Vector3(0, 4.0, 0)


func _process(delta: float) -> void:
	if joueur == null or phase == Phase.INDISPONIBLE or phase == Phase.TERMINEE:
		return
	_process_recit(delta)
	if phase == Phase.COUVRE_FEU and not en_scene:
		_patrouiller(delta)
		_detecter(delta)
		if _plat(joueur.global_position).distance_to(_plat(maison)) < 8.5:
			@warning_ignore("missing_await")
			_arrivee()


func _patrouiller(delta: float) -> void:
	for p in patrouilles:
		var n: Node3D = p["n"]
		if p["pause"] > 0.0:
			p["pause"] -= delta
			# il balaie la rue de sa lampe avant de repartir
			n.rotation.y += sin(p["pause"] * 1.6) * delta * 0.9
			if p["pause"] <= 0.0:
				_jouer(n, "Marche")
			continue
		var l: float = p["l"] + p["sens"] * p["v"] * delta
		if l >= p["l1"] or l <= p["l0"]:
			l = clampf(l, p["l0"], p["l1"])
			p["sens"] = -p["sens"]
			p["pause"] = 2.5
			_jouer(n, "Repos")
		p["l"] = l
		var ici := _sur_rue(p["pts"], l)
		var devant := _sur_rue(p["pts"], clampf(l + p["sens"] * 1.0, p["l0"], p["l1"]))
		n.global_position = ici
		var d := devant - ici
		if d.length() > 0.05:
			n.rotation.y = lerp_angle(n.rotation.y, atan2(d.x, d.z), minf(1.0, delta * 5.0))


func _voit(n: Node3D) -> float:
	var oeil := n.global_position + Vector3(0, 1.6, 0)
	var cible := joueur.global_position + Vector3(0, 0.6 if joueur.accroupi else 1.1, 0)
	var v := cible - oeil
	var d := v.length()
	if d < 2.2:
		return 3.0                       # on le bouscule presque
	var portee := PORTEE_ACCROUPI if joueur.accroupi else PORTEE
	if joueur.vitesse_affichee > 4.5:
		portee *= 1.25                   # qui court se fait remarquer
	if d > portee:
		return 0.0
	var avant := Vector3(sin(n.rotation.y), 0, cos(n.rotation.y))
	var plat := Vector3(v.x, 0, v.z).normalized()
	if avant.dot(plat) < cos(ANGLE):
		return 0.0
	var q := PhysicsRayQueryParameters3D.create(oeil, cible)
	q.exclude = [joueur.get_rid()]
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if not r.is_empty():
		return 0.0                       # un mur, une maison : il ne voit rien
	return 1.6 * (1.0 - d / portee) + 0.5


func _detecter(delta: float) -> void:
	var gain := 0.0
	var proche := INF
	for p in patrouilles:
		var n: Node3D = p["n"]
		gain = maxf(gain, _voit(n))
		proche = minf(proche, n.global_position.distance_to(joueur.global_position))
	if poste != Vector3.INF and _plat(joueur.global_position).distance_to(_plat(poste)) < 16.0:
		gain = 4.0                       # la grande route, éclairée comme en plein jour
	if gain > 0.0:
		vu = minf(1.0, vu + gain * delta)
	else:
		vu = maxf(0.0, vu - 0.35 * delta)
	jauge.value = vu
	(jauge.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = Color(0.95, 0.85, 0.3).lerp(Color(0.95, 0.2, 0.15), vu)
	# Petit Prince, s'il a été bien traité, siffle pour prévenir d'une patrouille
	t_sifflet -= delta
	if main.has_meta("prince_ami") and proche < 24.0 and vu == 0.0 and t_sifflet <= 0.0:
		t_sifflet = 30.0
		@warning_ignore("missing_await")
		_dire("", "Un sifflement bref, quelque part dans les jardins : Petit Prince prévient qu'une patrouille approche.", 4.0)
	if vu >= 1.0:
		@warning_ignore("missing_await")
		_repere()


## Appelé aussi par les barrages de la milice (couvre-feu) pendant le prologue.
func repere_barrage() -> void:
	if phase == Phase.COUVRE_FEU and not en_scene:
		@warning_ignore("missing_await")
		_repere()


func _repere() -> void:
	_cinematique(true)
	reprises += 1
	vu = 0.0
	jauge.value = 0.0
	var proche: Node3D = null
	var dmin := INF
	for p in patrouilles:
		var d := (p["n"] as Node3D).global_position.distance_to(joueur.global_position)
		if d < dmin:
			dmin = d
			proche = p["n"]
	if proche and dmin < 30.0:
		proche.global_position = _au_sol(joueur.global_position + (proche.global_position - joueur.global_position).normalized() * 1.8)
		_tourner_vers(proche, joueur.global_position)
		joueur.corps.rotation.y = atan2(proche.global_position.x - joueur.global_position.x, proche.global_position.z - joueur.global_position.z)
		_plan_dialogue(joueur.global_position, proche.global_position)
	else:
		_plan(joueur.global_position + Vector3(2.5, 2.0, 2.5), joueur.global_position + Vector3(0, 1.2, 0))
	if not await _scene([
		["MILICIEN", ["Le fils de l'étranger se promène encore ? Couvre-feu, c'est pour les chiens aussi.",
				"Encore toi ? Retourne d'où tu viens. La prochaine fois, on ne sera pas aussi gentils.",
				"Hé ! On t'a dit : personne dehors après 20 heures !"][(reprises - 1) % 3]],
		["", "Ils le bousculent et le ramènent au bas du quartier."],
	]):
		return
	if not await _fondu(true, 0.8):
		return
	joueur.ressusciter(depart + Vector3(0, 0.6, 0))
	for p in patrouilles:
		p["l"] = p["l0"]
		p["sens"] = 1.0
		p["pause"] = 1.0
	_cinematique(false)
	if not await _fondu(false, 0.8):
		return


# ---------------------------------------------------------------------
# La maison du père
# ---------------------------------------------------------------------
func _installer_maison() -> void:
	# la cour retournée par la milice : table renversée, chaises, papiers, cadres arrachés
	var c := maison
	_boite(Vector3(1.4, 0.06, 0.8), Transform3D(Basis(Vector3(1, 0, 0), 1.45), _au_sol(c + Vector3(-2.5, 0, -4.0), 0.4)), Color(0.45, 0.32, 0.2))
	for k in 3:
		_boite(Vector3(0.45, 0.45, 0.45), Transform3D(Basis(Vector3(0, 0, 1), 1.4 * k), _au_sol(c + Vector3(-1.0 + k * 1.3, 0, -6.0 + k * 0.7), 0.22)), Color(0.5, 0.36, 0.22))
	var rng := RandomNumberGenerator.new()
	rng.seed = 202
	for i in 14:
		_boite(Vector3(0.21, 0.004, 0.29), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), _au_sol(c + Vector3(rng.randf_range(-5, 5), 0, rng.randf_range(-7.5, -1.5)), 0.01)), Color(0.92, 0.9, 0.84))
	for i in 3:
		_boite(Vector3(0.3, 0.02, 0.4), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), _au_sol(c + Vector3(rng.randf_range(-4, 3), 0, rng.randf_range(-6, -2)), 0.015)), Color(0.35, 0.25, 0.15))
	# le lit de Faris enfant, sorti dans la cour et retourné
	var lit := _boite(Vector3(0.9, 0.35, 1.9), Transform3D(Basis(), _au_sol(c + Vector3(-4.2, 0, -2.6), 0.2)), Color(0.42, 0.3, 0.18))
	_inviter(lit, "regarder le lit", _souvenir.bind("lit"), 2.6)
	# le dessin du manguier, à la craie, sur la façade
	var dessin := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.9, 0.9)
	dessin.mesh = qm
	var md := StandardMaterial3D.new()
	md.albedo_texture = _dessin_manguier()
	md.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	dessin.material_override = md
	add_child(dessin)
	decor.append(dessin)
	dessin.global_transform = Transform3D(Basis(Vector3.UP, PI), _au_sol(c + Vector3(-2.6, 0, -1.08), 0.9))
	_inviter(dessin, "regarder le dessin", _souvenir.bind("dessin"), 2.8)
	# la pierre plate au pied du manguier
	pierre = _boite(Vector3(0.7, 0.1, 0.55), Transform3D(Basis(Vector3.UP, 0.4), _au_sol(arbre + Vector3(-0.9, 0, -0.6), 0.04)), Color(0.5, 0.48, 0.44))
	# Baya Efua, assise dans le noir, une lampe à pétrole à ses pieds
	var pb := _au_sol(c + Vector3(1.6, 0, -2.4))
	_boite(Vector3(0.45, 0.45, 0.45), Transform3D(Basis(), pb + Vector3(0, 0.22, 0)), Color(0.5, 0.36, 0.22))
	baya = _perso("baya", "Assis", pb + Vector3(0, 0.05, 0), PI)
	vq._canne(baya)
	var lampe := OmniLight3D.new()
	lampe.light_color = Color(1.0, 0.68, 0.35)
	lampe.light_energy = 1.4
	lampe.omni_range = 6.0
	add_child(lampe)
	decor.append(lampe)
	lampe.global_position = pb + Vector3(0.5, 0.3, -0.6)
	_boite(Vector3(0.12, 0.22, 0.12), Transform3D(Basis(), pb + Vector3(0.5, 0.11, -0.6)), Color(0.9, 0.7, 0.35))


func _dessin_manguier() -> ImageTexture:
	var im := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	im.fill(Color(0, 0, 0, 0))
	var craie := Color(0.95, 0.95, 0.9, 1.0)
	for y in range(64, 120):          # le tronc
		for x in range(58, 70):
			if (x + y) % 3 != 0:
				im.set_pixel(x, y, craie)
	for k in 7:                        # le feuillage : des boucles à la craie
		var cx := 64 + int(cos(k * 0.9) * 26.0)
		var cy := 44 + int(sin(k * 0.9) * 16.0)
		for a in 60:
			var t := TAU * a / 60.0
			var px := cx + int(cos(t) * 16.0)
			var py := cy + int(sin(t) * 14.0)
			for e in 2:
				if px + e < 128 and py >= 0 and py < 128:
					im.set_pixel(px + e, py, craie)
	for k in 5:                        # des mangues
		var mx := 40 + k * 12
		var my := 50 + (k % 2) * 10
		for dx in range(-2, 3):
			for dy in range(-3, 4):
				im.set_pixel(mx + dx, my + dy, Color(0.98, 0.7, 0.2, 1.0))
	return ImageTexture.create_from_image(im)


func _arrivee() -> void:
	phase = Phase.MAISON
	bloc_jauge.visible = false
	var co: Node = main.get_node_or_null("Controles")
	if co:
		co.set("prologue", null)
	_cinematique(true)
	var c := maison
	_plan(c + Vector3(3.5, 2.2, -8.5), baya.global_position + Vector3(0, 1.0, 0))
	if not await _scene([
		["", "La cour a été fouillée : tiroirs renversés, photos arrachées, papiers piétinés. Baya Efua attend dans le noir, assise sur une chaise."],
		["BAYA EFUA", "Ils sont venus le lendemain de sa mort. Ils cherchaient ses carnets."],
		["FARIS", "Ils les ont trouvés ?"],
		["BAYA EFUA", "Ton père n'était pas un idiot. (Elle tapote sa canne sur le sol.) Tu te souviens où tu cachais tes billes, quand tu étais petit ?"],
	]):
		return
	_cinematique(false)
	phase = Phase.CACHETTE
	if main.has_meta("indice_billes"):
		_objectif("« Les billes sont toujours au même endroit. Sous la pierre plate. » Cherchez dans la cour.")
		_inviter(pierre, "soulever la pierre plate", _ouvrir_cachette, 2.4)
	else:
		_objectif("Retrouvez votre cachette d'enfance : les souvenirs vous guideront (le dessin sur le mur, le lit, puis le jardin).")
	_balise(arbre)


func _souvenir(quoi: String) -> void:
	if souvenirs.has(quoi) or en_scene:
		return
	souvenirs[quoi] = true
	var tw := create_tween()
	tw.tween_property(lueur, "color:a", 0.28, 0.6)
	var texte: String = {
		"dessin": "Tu dessines toujours ce manguier, toi. Un jour, tu grimperas jusqu'en haut. Et tu verras toute l'île.",
		"lit": "Encore tes billes sous le lit ? Non… Tu les caches ailleurs, maintenant. Là où pousse ce qui nourrit.",
	}[quoi]
	await _dire("SAMUEL (souvenir)", texte, 6.0)
	var tw2 := create_tween()
	tw2.tween_property(lueur, "color:a", 0.0, 1.0)
	if souvenirs.size() >= 2 and not main.has_meta("indice_billes"):
		_objectif("Le manguier, au fond de la cour : la pierre plate à son pied.")
		_inviter(pierre, "soulever la pierre plate", _ouvrir_cachette, 2.4)


# ---------------------------------------------------------------------
# La cachette, le tableau des preuves, la décision
# ---------------------------------------------------------------------
func _ouvrir_cachette() -> void:
	if phase != Phase.CACHETTE or en_scene:
		return
	phase = Phase.DECISION
	invites.clear()
	pierre.global_position += Vector3(0.5, 0, 0.3)
	pierre.rotation.z = 0.6
	_boite(Vector3(0.35, 0.14, 0.25), Transform3D(Basis(), _au_sol(arbre + Vector3(-0.9, 0, -0.6), 0.02)), Color(0.4, 0.42, 0.45))
	_cinematique(true)
	var pierre_pos := _au_sol(arbre + Vector3(-0.9, 0, -0.6))
	joueur.global_position = _au_sol(pierre_pos + Vector3(-0.9, 0, -0.5), 0.6)
	joueur.corps.rotation.y = atan2(0.9, 0.5)
	joueur.anim.play("Accroupi", 0.2)
	# de face, le manguier derrière la pierre et Faris accroupi à gauche (le tronc n'a pas de collision)
	var vue := pierre_pos + Vector3(0.3, 1.7, -2.5)
	if not _degage(pierre_pos + Vector3(0, 0.4, 0), vue):
		vue = pierre_pos + Vector3(-0.2, 2.4, -1.4)
	_plan(vue, pierre_pos + Vector3(-0.3, 0.3, 0))
	if not await _dire("", "Sous la pierre plate, au pied du manguier : une boîte en fer. Dedans, les billes de Faris enfant. Et, en dessous, ce que son père y a caché.", 6.0):
		return
	var tel: Node = main.get_node_or_null("Telephone")
	if tel:
		tel.ajouter_preuve("Le carnet de Samuel", "Les noms de 37 familles de Bomé dont les terres ont été « achetées » de force par une société inconnue : Talanké Agro-Export.")
		tel.ajouter_preuve("Un relevé bancaire", "Des virements de Talanké Agro-Export vers un compte à Port-Wanzala, au nom d'un ministère.")
		tel.ajouter_preuve("Une photo", "Samuel et une jeune femme, sur le port, quelques jours avant sa mort.")
		tel.ajouter_preuve("Une clé USB", "Illisible pour l'instant. Protégée par un mot de passe.")
	_afficher_tableau(true)
	if not await _attendre(7.0, true):
		return
	_afficher_tableau(false)
	_plan(maison + Vector3(3.0, 1.8, -5.5), baya.global_position + Vector3(0, 1.0, 0), 1.5)
	if not await _scene([
		["BAYA EFUA", "Ton père voulait aller jusqu'au bout. Jusqu'à la capitale, s'il le fallait."],
		["FARIS", "Et ça l'a tué."],
		["BAYA EFUA", "Oui. (Un silence.) Mais la terre n'oublie pas qui la travaille."],
		["FARIS", "(Doucement.) La terre n'oublie pas qui la travaille."],
		["FARIS", "Cette jeune femme, sur la photo avec mon père. Qui est-ce ?"],
		["BAYA EFUA", "Ama, la fille du pêcheur Mensah, à Akwéri. Son frère a été emmené par le Cobra. Si quelqu'un sait ce que ton père a vu au port, c'est elle."],
	]):
		return
	if not await _fondu(true, 1.5):
		return
	_cinematique(false)
	if not await _afficher_carton("Le lendemain, à l'aube", "Akwéri, le village des pêcheurs", 3.5):
		return
	terminer()
	var m3: Node = main.get_node_or_null("Mission3")
	if m3:
		m3.commencer()


## Le tableau des preuves : un liège où Faris épingle les indices et tend des fils entre les noms.
func _afficher_tableau(oui: bool) -> void:
	if tableau:
		tableau.queue_free()
		tableau = null
	if not oui:
		return
	tableau = Control.new()
	tableau.set_anchors_preset(Control.PRESET_CENTER)
	tableau.offset_left = -430
	tableau.offset_right = 430
	tableau.offset_top = -250
	tableau.offset_bottom = 230
	calque.add_child(tableau)
	var liege := ColorRect.new()
	liege.color = Color(0.62, 0.45, 0.28)
	liege.set_anchors_preset(Control.PRESET_FULL_RECT)
	tableau.add_child(liege)
	var cadre := ReferenceRect.new()
	cadre.border_color = Color(0.35, 0.22, 0.12)
	cadre.border_width = 8.0
	cadre.editor_only = false
	cadre.set_anchors_preset(Control.PRESET_FULL_RECT)
	tableau.add_child(cadre)
	var fiches := {
		"carnet": [Vector2(40, 60), "LE CARNET DE SAMUEL\n37 familles de Bomé\nterres « achetées » de force"],
		"societe": [Vector2(330, 40), "TALANKÉ AGRO-EXPORT\nsociété inconnue"],
		"releve": [Vector2(610, 60), "RELEVÉ BANCAIRE\nvirements vers\nPort-Wanzala"],
		"ministere": [Vector2(600, 250), "UN MINISTÈRE ?\ncompte au nom\nd'un ministère"],
		"photo": [Vector2(60, 270), "PHOTO\nSamuel et une jeune femme\nsur le port"],
		"usb": [Vector2(330, 300), "CLÉ USB\nillisible pour l'instant"],
	}
	var fils := [["carnet", "societe"], ["societe", "releve"], ["releve", "ministere"], ["photo", "carnet"]]
	for f in fils:
		var l := Line2D.new()
		l.default_color = Color(0.8, 0.1, 0.1)
		l.width = 3.0
		var a: Vector2 = fiches[f[0]][0]
		var b: Vector2 = fiches[f[1]][0]
		l.points = PackedVector2Array([a + Vector2(100, 40), b + Vector2(100, 40)])
		tableau.add_child(l)
	for k in fiches:
		var fiche := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.96, 0.94, 0.86) if k != "photo" else Color(0.85, 0.85, 0.82)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
		fiche.add_theme_stylebox_override("panel", sb)
		fiche.position = fiches[k][0]
		fiche.custom_minimum_size = Vector2(200, 80)
		var t := Label.new()
		t.text = fiches[k][1]
		t.add_theme_font_size_override("font_size", 15)
		t.add_theme_color_override("font_color", Color(0.15, 0.12, 0.1))
		fiche.add_child(t)
		tableau.add_child(fiche)
		var punaise := ColorRect.new()
		punaise.color = Color(0.85, 0.15, 0.12)
		punaise.size = Vector2(10, 10)
		punaise.position = fiches[k][0] + Vector2(95, -4)
		tableau.add_child(punaise)
	var titre := Label.new()
	titre.text = "TABLEAU DES PREUVES — il grandira jusqu'au président (Tab → Preuves)   ·   F : continuer"
	titre.position = Vector2(20, 440)
	titre.add_theme_font_size_override("font_size", 15)
	titre.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	tableau.add_child(titre)


func terminer() -> void:
	gen += 1
	phase = Phase.TERMINEE
	_effacer_decor()
	_effacer_patrouilles()
	_afficher_tableau(false)
	bloc_jauge.visible = false
	lueur.color.a = 0.0
	var co: Node = main.get_node_or_null("Controles")
	if co:
		co.set("prologue", null)
	if en_scene:
		_cinematique(false)
	voile.color.a = 0.0

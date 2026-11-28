## Mission 1 — « Le Retour » (jeu/missions/01-LE-RETOUR.md). Pas de combat : Faris est seul, sans arme.
## Le bac (cinématique) → le quai, la milice qui fouille les sacs et emporte le poisson → les rues de
## Port-Néré : Petit Prince (tutoriel du téléphone), Mama Rokia au maquis, la vendeuse du marché,
## la fresque effacée et la page du carnet (facultatif) → le barrage de Dossou (choix en 8 secondes)
## → le cimetière au coucher du soleil : le Père Joseph et l'Imam Salif côte à côte, Baya Efua,
## l'inscription « Zala ka wan, wan ka zala », Mamba aperçu au loin, Ama → titre du jeu.
class_name Mission1
extends Recit

enum Phase { INDISPONIBLE, BAC, VILLE, CIMETIERE, BARRAGE, TOMBE, FIN, TERMINEE }

var phase := Phase.INDISPONIBLE
var m12: Mission12
var mer3 := Vector3(0, 0, 1)       # du quai vers le large
var quai := Vector3.ZERO
var t_bac := -1.0
var depart_bac := Vector3.ZERO
var faris_bac: Node3D
var passeur: Node3D
var prince: Node3D
var prince_etat := 0               # 0 attend, 1 suit Faris, 2 parti
var rokia: Node3D
var rokia_vue := false
var rokia_parle := false
var barrage := Vector3.INF
var barrage_dir := Vector3(0, 0, 1)
var gardes: Array = []             # [noeud, position au barrage]
var dossou: Node3D
var foule: Array = []
var convoi: Array = []             # pick-up du convoi de Mamba
var t_convoi := -1.0
var convoi_debut := 0               # horloge réelle : le convoi reste calé sur les répliques
var route_convoi := Vector3.ZERO
var dir_convoi := Vector3(1, 0, 0)
var mamba: Node3D
var choix := ""                    # "taire", "calme" ou "provoquer"
var page_prise := false


func construire(p_main: Node) -> void:
	preparer_recit(p_main)
	m12 = main.get_node("Mission12")
	mer3 = m12.lieu_bac.basis.z
	# le quai : du bac vers la terre, jusqu'au sol sec
	var q := m12.lieu_bac.origin
	for i in 200:
		if terrain.hauteur(q.x, q.z) > 0.5:
			break
		q -= mer3
	quai = _au_sol(q - mer3 * 2.5)
	_trouver_barrage()
	_choisir_route_convoi()


func est_terminee() -> bool:
	return phase == Phase.TERMINEE


## Chargement d'une partie où cette mission n'a pas encore commencé.
func annuler() -> void:
	if phase == Phase.INDISPONIBLE:
		return
	terminer()
	phase = Phase.INDISPONIBLE


func etat_texte() -> String:
	return ["à venir", "le bac", "Port-Néré", "le cimetière", "le barrage", "l'enterrement", "le titre", "terminée"][phase]


## Une place libre (hors des maisons et des rues prises) près d'un point.
func _libre(pres: Vector3, taille := 1.4) -> Vector3:
	var p2 := _plat(pres)
	for r in range(0, 40, 2):
		for k in 12:
			var c := p2 + Vector2.from_angle(TAU * k / 12.0) * float(r)
			if ville._rect_libre(c, Vector2(0, 1), taille, taille, 0.2) and terrain.hauteur(c.x, c.y) > 0.4:
				return _au_sol(Vector3(c.x, 0, c.y))
	return _au_sol(pres)


func _trouver_barrage() -> void:
	var c := m12.lieu_cimetiere
	var entree := c * Vector3(0, 0, 10.0)
	var place: Vector3 = ville.reperes["place"]
	var d := (place - entree)
	d.y = 0.0
	d = d.normalized()
	for dist in [26.0, 32.0, 38.0, 46.0, 54.0, 64.0]:
		var p: Vector3 = entree + d * dist
		if ville._rect_libre(_plat(p), _plat(d), 7.0, 3.0, 0.3):
			barrage = _au_sol(p)
			barrage_dir = d
			return
	barrage = _au_sol(entree + d * 30.0)
	barrage_dir = d


# ---------------------------------------------------------------------
# Départ : la traversée en bac
# ---------------------------------------------------------------------
func commencer() -> void:
	gen += 1
	_effacer_decor()
	phase = Phase.BAC
	joueur.mission = self
	m4.reprise_prologue = quai + Vector3(0, 0.6, 0)
	prince_etat = 0
	rokia_vue = false
	rokia_parle = false
	page_prise = false
	choix = ""
	t_convoi = -1.0
	convoi.clear()
	foule.clear()
	gardes.clear()
	_ambiance(0)
	_installer_ville()
	@warning_ignore("missing_await")
	_traversee()


func _traversee() -> void:
	var bac: Node3D = m12.bac
	m12.passeur.visible = false
	depart_bac = m12.lieu_bac.origin + mer3 * 240.0
	bac.global_position = depart_bac
	t_bac = 0.0
	joueur.ressusciter(quai + Vector3(0, 0.6, 0))
	joueur.visible = false
	_cinematique(true)
	voile.color.a = 1.0
	var avant := -mer3
	faris_bac = _perso("faris", "Repos", bac.global_position + Vector3(0, 0.62, 0) + avant * 6.8, atan2(avant.x, avant.z))
	faris_bac.reparent(bac)
	var cote := m12.lieu_bac.basis.x
	passeur = _perso("ancien", "Repos", bac.global_position + Vector3(0, 0.62, 0) + avant * 6.2 + cote * 1.1, atan2(-cote.x, -cote.z))
	passeur.reparent(bac)
	_coiffe(passeur, Color(0.85, 0.72, 0.42), 0.32, 0.12, 0.15)
	# plan large : le bac rouillé sur la mer calme, l'île qui grandit à l'horizon
	_plan_embarque(bac, Vector3(-14.0, 6.0, 20.0), m12.lieu_bac.origin + Vector3(0, 25, 0))
	cam_suit = null
	if not await _fondu(false, 2.5):
		return
	if not await _attendre(4.0, true):
		return
	# plus près : Faris à l'avant, le passeur à côté de lui
	cam_suit = faris_bac
	_plan_embarque(bac, Vector3(-3.4, 1.9, -9.6), faris_bac.global_position + Vector3(0, 1.5, 0), 4.0)
	if not await _attendre(4.0, true):
		return
	if not await _scene([
		["", "Faris tient une enveloppe froissée : l'avis de décès de son père."],
		["PASSEUR", "Tu es le fils de Samuel. Je t'ai reconnu. Tu as ses épaules."],
		["FARIS", "Ça fait quatorze ans que je ne suis pas venu."],
		["PASSEUR", "L'île n'a pas oublié. Mais elle a changé, mon fils."],
		["PASSEUR", "(Il baisse la voix.) Au quai, tu baisses les yeux. Tu ne parles pas aux hommes au foulard vert. Tu payes ce qu'ils demandent."],
		["FARIS", "Quels hommes ?"],
		["PASSEUR", "Tu verras bien assez tôt."],
	]):
		return
	# le quai approche : deux miliciens adossés à leur pick-up
	cam_suit = null
	var pk: Vector3 = quai
	if gardes.size() > 0:
		pk = (gardes[0][0] as Node3D).global_position
	_plan_embarque(bac, Vector3(0.8, 2.0, -5.0), pk + Vector3(0, 1.0, 0), 3.0)
	while t_bac >= 0.0 and t_bac < 30.0:
		if not await _attendre(0.2, true):
			return
		if saute:
			break
	if not await _fondu(true, 1.0):
		return
	t_bac = -1.0
	bac.global_transform = m12.lieu_bac
	faris_bac.queue_free()
	passeur.queue_free()
	m12.passeur.visible = true
	joueur.visible = true
	joueur.ressusciter(quai + Vector3(0, 0.6, 0))
	joueur.lacet = atan2(mer3.x, mer3.z)
	_cinematique(false)
	phase = Phase.VILLE
	_objectif("Traversez Port-Néré : Mama Rokia vous attend à son maquis, près de la place.")
	_balise(ville.reperes["maquis"])
	if not await _fondu(false, 1.5):
		return
	m4._annoncer("Z Q S D (ou W A S D) : marcher · Maj : courir · souris : regarder\nF : parler · Tab : téléphone · M : carte", 9.0)


# ---------------------------------------------------------------------
# Décor de la ville : quai, Petit Prince, Mama Rokia, marché, fresque, barrage
# ---------------------------------------------------------------------
func _installer_ville() -> void:
	var cote := m12.lieu_bac.basis.x
	var terre := -mer3
	# le pick-up de la milice sur le quai, deux miliciens adossés
	var ppk := _libre(quai + cote * 9.0 + terre * 5.0, 5.5)
	var xpk := Transform3D(Basis(Vector3.UP, atan2(cote.x, cote.z)), ppk)
	_pickup(xpk)
	for k in 2:
		var g := _milicien_decor(xpk * Vector3(-1.5 - k * 0.2, 0, 1.0 - k * 2.2), atan2(-cote.x, -cote.z), ["homme2", "villageois"][k])
		regards.append([g, 18.0])
		gardes.append([g, g.global_position])
	# des caisses de poisson empilées dans la benne
	for i in 5:
		_boite(Vector3(0.6, 0.3, 0.4), xpk.translated_local(Vector3(-0.4 + (i % 2) * 0.7, 1.25 + floorf(i / 2.0) * 0.3, -1.6 + (i % 3) * 0.5)), Color(0.45, 0.6, 0.7))
	# un troisième fouille le sac d'un passager
	var pf := _libre(quai + cote * 3.0 + terre * 3.0)
	var fouille := _milicien_decor(pf, atan2(-cote.x, -cote.z), "homme3")
	_jouer(fouille, "Accroupi")
	_boite(Vector3(0.5, 0.3, 0.35), Transform3D(Basis(), pf + (-cote) * 0.6 + Vector3(0, 0.15, 0)), Color(0.4, 0.25, 0.15))
	var passager := _perso("homme3", "Repos", pf - cote * 1.5, atan2(cote.x, cote.z))
	regards.append([passager, 2.0])
	# les pêcheurs déchargent sans un mot : leur poisson part dans le pick-up
	var pir := _libre(quai - cote * 8.0 + mer3 * 1.0, 1.0)
	var mi := MeshInstance3D.new()
	mi.mesh = vq._pirogue_maillage()
	add_child(mi)
	decor.append(mi)
	mi.global_position = Vector3(pir.x, maxf(terrain.hauteur(pir.x, pir.z), -0.2), pir.z)
	mi.rotation.y = atan2(mer3.x, mer3.z)
	for k in 2:
		var pe := _perso(["pecheur", "villageois"][k], "Marche", pir + cote * (0.8 + k), 0.0)
		_boite(Vector3(0.55, 0.28, 0.38), Transform3D(Basis(), pe.global_position + Vector3(0, 1.05, 0.3)), Color(0.45, 0.6, 0.7), pe)
		_marcheur(pe, [pe.global_position, xpk * Vector3(1.4, 0, -2.6 + k)], 1.1, true, 1.5)
	# Petit Prince, à mi-chemin entre le quai et la place
	var place: Vector3 = ville.reperes["place"]
	prince = _perso("garcon", "Repos", _libre(quai.lerp(place, 0.45)), 0.0)
	_tourner_vers(prince, quai)
	# Mama Rokia derrière son comptoir
	var maquis: Vector3 = ville.reperes["maquis"]
	rokia = _perso("femme_agee", "Repos", _libre(maquis + Vector3(0, 0, -3.0)), 0.0)
	_tourner_vers(rokia, place)
	_inviter(rokia, "parler à Mama Rokia", _parler_rokia)
	# le marché à moitié fermé : étals vides, une vendeuse qui ne veut pas parler
	var marche: Vector3 = ville.reperes["marche"]
	var pv := _libre(marche + Vector3(4, 0, 4), 2.5)
	_boite(Vector3(2.0, 0.85, 0.8), Transform3D(Basis(), pv + Vector3(0, 0.42, 0)), Color(0.55, 0.42, 0.3))
	var vendeuse := _perso("femme2", "Repos", pv + Vector3(0, 0, -1.0), 0.0)
	_tourner_vers(vendeuse, place)
	_inviter(vendeuse, "parler à la vendeuse", _parler_vendeuse)
	# la page du carnet, glissée entre le mur de la fresque et l'affiche du Cobra
	var f := m12.lieu_fresque
	var page := _boite(Vector3(0.22, 0.02, 0.3), f.translated_local(Vector3(0.9, 0.05, 0.8)), Color(0.93, 0.9, 0.8))
	_inviter(page, "ramasser la page", _prendre_page.bind(page), 2.2)
	_inviter(m12.mur_fresque, "regarder la fresque", _regarder_fresque, 4.0)
	# le barrage sur la route du cimetière : pneus, deux barils, une corde tendue, Dossou et deux miliciens
	if barrage != Vector3.INF:
		var xb := Transform3D(Basis(Vector3.UP, atan2(barrage_dir.x, barrage_dir.z)), barrage)
		for i in 4:
			var pn := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.22
			tm.outer_radius = 0.42
			pn.mesh = tm
			var mp := StandardMaterial3D.new()
			mp.albedo_color = Color(0.07, 0.07, 0.07)
			pn.material_override = mp
			add_child(pn)
			decor.append(pn)
			pn.global_transform = xb.translated_local(Vector3(-3.2 + (i % 2) * 0.1, 0.12 + floorf(i / 2.0) * 0.22, 0.0))
		for s in [-1.0, 1.0]:
			var ba := MeshInstance3D.new()
			var cy := CylinderMesh.new()
			cy.top_radius = 0.3
			cy.bottom_radius = 0.3
			cy.height = 0.9
			ba.mesh = cy
			var mb := StandardMaterial3D.new()
			mb.albedo_color = Color(0.2, 0.3, 0.55) if s < 0 else Color(0.5, 0.25, 0.12)
			ba.material_override = mb
			add_child(ba)
			decor.append(ba)
			ba.global_transform = xb.translated_local(Vector3(s * 2.6, 0.45, 0.0))
		_boite(Vector3(5.0, 0.03, 0.03), xb.translated_local(Vector3(0, 0.8, 0)), Color(0.75, 0.68, 0.5))
		dossou = _perso("villageois", "Repos", xb * Vector3(1.2, 0, 1.2), atan2(barrage_dir.x, barrage_dir.z))
		vq._camoufler(dossou)
		_coiffe(dossou, Color(0.7, 0.08, 0.08), 0.13, 0.07, 0.12)    # béret rouge
		gardes.append([dossou, dossou.global_position])
		for k in 2:
			var g := _milicien_decor(xb * Vector3(-1.5 + k * 3.4, 0, 0.9), atan2(barrage_dir.x, barrage_dir.z), ["homme2", "homme3"][k])
			regards.append([g, 14.0])
			gardes.append([g, g.global_position])
		regards.append([dossou, 16.0])


func _parler_vendeuse() -> void:
	@warning_ignore("missing_await")
	_dire("VENDEUSE", "Je n'ai rien. Rien à vendre aujourd'hui. (Elle ne quitte pas la rue des yeux.)")


func _regarder_fresque() -> void:
	@warning_ignore("missing_await")
	_dire("", "La fresque de la coopérative, délavée par le soleil. Parmi les fondateurs, un homme aux épaules larges, la houe levée : Samuel. L'affiche du Cobra est collée sur son visage.")


func _prendre_page(page: Node3D) -> void:
	if page_prise:
		return
	page_prise = true
	page.visible = false
	for e in invites.duplicate():
		if e["n"] == page:
			_retirer_invite(e)
	main.set_meta("indice_billes", true)
	var tel: Node = main.get_node_or_null("Telephone")
	if tel:
		tel.ajouter_preuve("Page du carnet de Samuel", "Glissée derrière l'affiche du Cobra, sur la fresque de la coopérative. De l'écriture de Samuel : « Les billes sont toujours au même endroit. Sous la pierre plate. — S. »")
	@warning_ignore("missing_await")
	_dire("", "Une page arrachée, de l'écriture de son père : « Les billes sont toujours au même endroit. Sous la pierre plate. — S. »")


# ---------------------------------------------------------------------
# Les rencontres
# ---------------------------------------------------------------------
func _process(delta: float) -> void:
	if joueur == null or phase == Phase.INDISPONIBLE or phase == Phase.TERMINEE:
		return
	_process_recit(delta)
	if t_bac >= 0.0:
		t_bac += delta
		var u := clampf(t_bac / 32.0, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - u, 2.2)
		m12.bac.global_position = depart_bac.lerp(m12.lieu_bac.origin, e) + Vector3(0, 0.05 * sin(t_bac * 1.2), 0)
	if t_convoi >= 0.0:
		_convoi()
	var jp := joueur.global_position
	match phase:
		Phase.VILLE:
			if prince_etat == 0 and prince and jp.distance_to(prince.global_position) < 13.0:
				prince_etat = 1
				@warning_ignore("missing_await")
				_parler_prince()
			if not rokia_vue and rokia and jp.distance_to(rokia.global_position) < 16.0:
				rokia_vue = true
				@warning_ignore("missing_await")
				_dire("MAMA ROKIA", "Faris ! Le fils de Samuel ! Viens, viens, approche !", 3.5)
		Phase.CIMETIERE:
			if jp.distance_to(barrage) < 10.0 or jp.distance_to(m12.lieu_cimetiere.origin) < 30.0:
				@warning_ignore("missing_await")
				_scene_barrage()
		Phase.BARRAGE:
			if jp.distance_to(m12.tombe) < 4.5:
				@warning_ignore("missing_await")
				_scene_tombe()
	if prince_etat == 1 and prince and not en_scene:
		var v := jp - prince.global_position
		v.y = 0.0
		if v.length() > 2.6:
			_jouer(prince, "Course" if v.length() > 6.0 else "Marche")
			prince.global_position = _au_sol(prince.global_position + v.normalized() * minf(v.length() - 2.5, (5.5 if v.length() > 6.0 else 1.6) * delta))
			prince.rotation.y = lerp_angle(prince.rotation.y, atan2(v.x, v.z), minf(1.0, delta * 8.0))
		else:
			_jouer(prince, "Repos")
			prince.rotation.y = lerp_angle(prince.rotation.y, atan2(v.x, v.z), minf(1.0, delta * 4.0))


func _parler_prince() -> void:
	if not await _dire("PETIT PRINCE", "Nawé ! C'est toi le fils du vieux Samuel ? Tu as un téléphone de l'étranger ? Montre !"):
		return
	_objectif("Montrez à Petit Prince la photo de votre père : ouvrez le téléphone (Tab).")
	var tel: Telephone = main.get_node_or_null("Telephone")
	var t := 0.0
	var montre := false
	while t < 45.0:
		if not await _attendre(0.2):
			return
		t += 0.2
		if tel and tel.ouvert:
			montre = true
			break
	if montre:
		if not await _dire("", "Faris montre l'écran : une photo de son père qui rit, sur le port, la casquette de travers."):
			return
		while tel and tel.ouvert:
			if not await _attendre(0.2):
				return
		if not await _scene([
			["PETIT PRINCE", "(Il devient sérieux.) Il était gentil, lui. Il me donnait des mangues."],
			["PETIT PRINCE", "Si tu as besoin de quelqu'un qui connaît toutes les ruelles… Je suis le prince de Port-Néré, moi."],
		]):
			return
		main.set_meta("prince_ami", true)
	else:
		if not await _dire("PETIT PRINCE", "Bon. Une autre fois, Nawé."):
			return
	prince_etat = 2
	if phase == Phase.VILLE and not rokia_parle:
		_objectif("Traversez Port-Néré : Mama Rokia vous attend à son maquis, près de la place.")
	var loin := _libre(prince.global_position + (prince.global_position - joueur.global_position).normalized() * 35.0)
	_marcheur(prince, [loin], 5.0, false, 0.0, "Course")


func _parler_rokia() -> void:
	if rokia_parle or en_scene:
		return
	rokia_parle = true
	_retirer_invite(invites.filter(func(e: Dictionary) -> bool: return e["n"] == rokia)[0])
	_cinematique(true)
	_tourner_vers(rokia, joueur.global_position)
	joueur.corps.rotation.y = atan2(rokia.global_position.x - joueur.global_position.x, rokia.global_position.z - joueur.global_position.z)
	_plan_dialogue(joueur.global_position, rokia.global_position)
	if not await _scene([
		["MAMA ROKIA", "Tu as ses yeux, tu sais. Assieds-toi. Bois. (Elle pose devant lui un verre de bissap.) Mange d'abord, pleure après."],
		["FARIS", "Comment est-il mort, Mama ?"],
		["MAMA ROKIA", "Ils disent qu'il est tombé de sa moto. Ton père conduisait comme une tortue."],
		["MAMA ROKIA", "(À voix basse, elle regarde la rue.) Il posait trop de questions sur les terres de Bomé."],
		["MAMA ROKIA", "On l'enterre au coucher du soleil, au cimetière de la colline, derrière l'église. Le Père Joseph et l'Imam Salif seront là. Tout le monde sera là."],
	]):
		return
	_cinematique(false)
	phase = Phase.CIMETIERE
	_objectif("Montez au cimetière de la colline, derrière l'église, pour l'enterrement de votre père.")
	_balise(m12.lieu_cimetiere.origin)


# ---------------------------------------------------------------------
# Le barrage : premier choix
# ---------------------------------------------------------------------
func _scene_barrage() -> void:
	phase = Phase.BARRAGE
	_cinematique(true)
	var jp := joueur.global_position
	var vers := barrage - jp
	vers.y = 0.0
	if vers.length() < 1.0:
		vers = barrage_dir
	vers = vers.normalized()
	var lat := vers.cross(Vector3.UP).normalized()
	# Dossou et ses deux hommes barrent le chemin
	var places := [jp + vers * 2.4, jp + vers * 2.0 + lat * 1.5, jp + vers * 1.9 - lat * 1.6]
	for k in mini(3, gardes.size() - 2):
		var g: Node3D = gardes[2 + k][0]
		g.global_position = _au_sol(places[k])
		_tourner_vers(g, jp)
	joueur.corps.rotation.y = atan2(vers.x, vers.z)
	var sac := _boite(Vector3(0.5, 0.25, 0.35), Transform3D(Basis(), _au_sol(jp + vers * 1.0 - lat * 0.6, 0.12)), Color(0.35, 0.22, 0.12))
	_plan_dialogue(jp, dossou.global_position, 4.2)
	if not await _scene([
		["MILICIEN", "Hé, l'étranger ! Papiers. Et le sac."],
		["", "Ils vident le sac de Faris par terre. Ils prennent son ordinateur portable et son argent."],
	]):
		return
	var pd := jp - vers * 1.6 + lat * 0.8 + Vector3(0, 1.75, 0)
	if _degage(dossou.global_position + Vector3(0, 1.5, 0), pd):
		_plan(pd, dossou.global_position + Vector3(0, 1.55, 0), 1.5)
	if not await _scene([
		["DOSSOU", "Faris… Le fils de Samuel. (Il ramasse l'avis de décès, le lit, le laisse tomber.)"],
		["DOSSOU", "Le Commandant savait que tu viendrais. Il te présente ses condoléances."],
	]):
		return
	var i := await _choisir("Que répond Faris ? (8 secondes)", ["Se taire", "Répondre calmement", "Provoquer"], 8.0, 0)
	if i < 0:
		return
	choix = ["taire", "calme", "provoquer"][i]
	main.set_meta("m1_barrage", choix)
	match choix:
		"taire":
			if not await _scene([
				["", "Faris ramasse ses affaires en silence. Les miliciens se moquent de lui."],
				["MILICIEN", "Va pleurer ton père, l'étranger. Et baisse les yeux, la prochaine fois."],
			]):
				return
		"calme":
			if not await _scene([
				["FARIS", "Dis à ton Commandant que je viens enterrer mon père. Rien d'autre."],
				["", "Dossou le fixe longtemps. Puis il ramasse l'ordinateur et le lui rend."],
				["DOSSOU", "Enterre-le, alors."],
			]):
				return
			main.set_meta("dossou_estime", true)
		"provoquer":
			if not await _dire("FARIS", "Mon père n'avait pas besoin des condoléances de ses assassins."):
				return
			# un milicien le frappe au ventre ; Dossou arrête son homme
			m4.rouge.color.a = 0.45
			joueur.anim.play("Accroupi", 0.1)
			if cam:
				var c0 := cam.global_position
				for k in 6:
					cam.global_position = c0 + Vector3(randf_range(-0.08, 0.08), randf_range(-0.06, 0.06), 0)
					if not await _attendre(0.05):
						return
				cam.global_position = c0
			if not await _scene([
				["", "Un milicien frappe Faris au ventre."],
				["DOSSOU", "Assez ! (Il retient son homme par le bras.) Le Commandant le veut entier. Pour l'instant."],
				["", "Derrière les volets, des habitants ont tout vu. Ce soir, tout Port-Néré parlera du fils de Samuel."],
			]):
				return
			m4.confiance = clampi(m4.confiance + 3, 0, 100)
	sac.queue_free()
	for g in gardes.slice(2):
		(g[0] as Node3D).global_position = g[1]
	_cinematique(false)
	_objectif("Rejoignez la tombe de votre père, au cimetière.")
	_balise(m12.tombe)
	_installer_enterrement()


# ---------------------------------------------------------------------
# Le cimetière au coucher du soleil
# ---------------------------------------------------------------------
func _installer_enterrement() -> void:
	var c := m12.lieu_cimetiere
	var vers_tombe := atan2(-c.basis.z.x, -c.basis.z.z)
	var vers_foule := atan2(c.basis.z.x, c.basis.z.z)
	# le Père Joseph et l'Imam Salif, côte à côte derrière la stèle
	var pj := _perso("ancien", "Repos", _au_sol(c * Vector3(0.75, 0, -8.6)), vers_foule)
	_boite(Vector3(0.12, 0.05, 0.03), Transform3D(Basis(), pj.global_position + Vector3(0, 1.47, 0)), Color(0.95, 0.95, 0.95), pj)   # col blanc
	var imam := _perso("villageois", "Repos", _au_sol(c * Vector3(-0.75, 0, -8.6)), vers_foule)
	_coiffe(imam, Color(0.95, 0.95, 0.92), 0.1, 0.08)       # calotte blanche
	foule.append_array([pj, imam])
	# Baya Efua au premier rang, assise, appuyée sur sa canne
	var pb := _au_sol(c * Vector3(-1.6, 0, -4.4))
	_boite(Vector3(0.45, 0.45, 0.45), Transform3D(Basis(), pb + Vector3(0, 0.22, 0)), Color(0.5, 0.36, 0.22))
	var baya := _perso("baya", "Assis", pb + Vector3(0, 0.05, 0), vers_tombe)
	vq._canne(baya)
	foule.append(baya)
	# cultivateurs de Bomé, pêcheurs, Mama Rokia
	var modeles := ["cultivateur", "pecheur", "femme", "femme_agee", "homme2", "femme2", "pecheur", "cultivateur", "homme3", "femme", "villageois", "fille"]
	var k := 0
	for rang in [[-4.5, [-6.0, -4.2, 2.6, 4.4, 6.2]], [-0.5, [-5.5, -3.5, -1.5, 0.5, 2.5, 4.5, 6.5]]]:
		for x in rang[1]:
			var p := _perso(modeles[k % modeles.size()], "Repos", _au_sol(c * Vector3(x, 0, rang[0])), vers_tombe)
			foule.append(p)
			k += 1


func _scene_tombe() -> void:
	phase = Phase.TOMBE
	var c := m12.lieu_cimetiere
	joueur.global_position = _au_sol(c * Vector3(0.2, 0, -4.6), 0.6)
	joueur.corps.rotation.y = atan2(-c.basis.z.x, -c.basis.z.z)
	_cinematique(true)
	var g := c.basis
	_plan(c * Vector3(5.5, 2.6, -1.5), c * Vector3(0, 1.2, -7.5))
	if not await _scene([
		["", "Le soleil se couche sur la colline. Des cultivateurs de Bomé, des pêcheurs, Mama Rokia. Le Père Joseph et l'Imam Salif se tiennent côte à côte."],
		["PÈRE JOSEPH", "Samuel était chrétien le dimanche…"],
		["IMAM SALIF", "…et il venait boire le thé à la mosquée le vendredi. (Rires discrets dans la foule.)"],
		["PÈRE JOSEPH", "Il était surtout un homme de la terre."],
	]):
		return
	# l'inscription
	_plan(m12.tombe + g.z * 1.2 + Vector3(0, 1.0, 0), m12.tombe - g.z * 1.05 + Vector3(0, 0.85, 0), 2.5)
	if not await _attendre(2.6):
		return
	if not await _dire("", "Zala ka wan, wan ka zala.\n(La terre est à tous, et tous sont à la terre.)", 6.0):
		return
	_plan(c * Vector3(-3.6, 1.7, -2.6), c * Vector3(-1.0, 1.2, -4.5), 1.5)
	if not await _scene([
		["BAYA EFUA", "(Sans le regarder.) Tu arrives tard, fils de Samuel."],
		["FARIS", "Je sais."],
		["BAYA EFUA", "Ton père t'attendait. Pas pour l'enterrer. Pour l'aider."],
		["BAYA EFUA", "(Elle se lève avec peine.) Ce soir, viens à la maison de ton père. Il a laissé quelque chose pour toi. Ne viens pas par la grande route."],
	]):
		return
	# Mamba, au loin, sur la route en contrebas
	_preparer_convoi()
	# par-dessus l'épaule de Faris, vers la route en contrebas (plus haut si un toit masque la vue)
	# sur la ligne de vue dégagée entre le cimetière et la route : rien ne masque le convoi
	# plan large en plongée depuis la colline, vers la rue en contrebas
	cam.fov = 28.0                       # téléobjectif : le convoi est au loin
	_plan(convoi_vue, route_convoi + Vector3(0, 1.0, 0), 2.0)
	t_convoi = 0.0
	convoi_debut = Time.get_ticks_msec()
	if not await _attendre(6.0):
		return
	if not await _dire("", "En contrebas, un convoi de pick-up s'arrête. Une silhouette massive descend : lunettes de soleil malgré la nuit qui tombe, une canne à pommeau d'argent. Le Commandant Mamba.", 8.0):
		return
	if not await _dire("", "Il ne s'approche pas. Il lève simplement sa canne, comme un salut.", 4.5):
		return
	var pa := _au_sol(c * Vector3(1.5, 0, -4.4))
	var ama := _perso("femme", "Repos", pa, atan2(route_convoi.x - pa.x, route_convoi.z - pa.z))
	_plan(c * Vector3(3.2, 1.7, -1.4), c * Vector3(0.9, 1.4, -4.5), 1.5)
	if not await _dire("AMA", "(Une jeune femme, à côté de Faris : il ne l'avait pas remarquée.) Il fait ça à chaque enterrement. Pour qu'on sache qui commande.", 6.5):
		return
	_marcheur(ama, [_au_sol(c * Vector3(9.0, 0, 14.0)), _au_sol(c * Vector3(14.0, 0, 30.0))], 1.3, false)
	if not await _dire("", "Elle s'éloigne avant qu'il ait pu répondre.", 3.0):
		return
	phase = Phase.FIN
	if not await _fondu(true, 2.0):
		return
	_cinematique(false)
	if not await _attendre(1.5):
		return
	if not await _dire("PASSEUR (voix)", "L'île n'a pas oublié, mon fils.", 4.5):
		return
	if not await _afficher_carton("WANZALA : FREEDOM", "Acte 1 — L'île de Talanké", 5.0):
		return
	terminer()
	var m2: Node = main.get_node_or_null("Mission2")
	if m2:
		m2.commencer()


## La route du convoi de Mamba : une rue en contrebas du cimetière, vue d'en haut (plan large en
## plongée depuis la colline : les toits ne la masquent pas). On retire les arbres sur la ligne de vue.
var convoi_vue := Vector3.ZERO


func _choisir_route_convoi() -> void:
	var c := m12.lieu_cimetiere.origin
	var candidats: Array = []
	for rue in ville.rues:
		var pts: PackedVector2Array = rue["pts"]
		for i in pts.size() - 1:
			var a := pts[i]
			var b := pts[i + 1]
			if a.distance_to(b) < 25.0:
				continue
			for u in [0.35, 0.5, 0.65]:
				var m: Vector2 = a.lerp(b, u)
				var d := m.distance_to(_plat(c))
				if d < 70.0 or d > 200.0 or terrain.hauteur(m.x, m.y) > c.y - 3.0:
					continue
				candidats.append([absf(d - 110.0), m, (b - a).normalized()])
	candidats.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
	var trouve := false
	for cd in candidats:
		var m: Vector2 = cd[1]
		var p := _au_sol(Vector3(m.x, 0, m.y))
		var vers := (p - c)
		vers.y = 0.0
		var oeil := c - vers.normalized() * 12.0 + Vector3(0, 24.0, 0)
		if _degage(oeil, p + Vector3(0, 1.2, 0)):
			route_convoi = p
			var ab: Vector2 = cd[2]
			dir_convoi = Vector3(ab.x, 0, ab.y)
			convoi_vue = oeil
			trouve = true
			break
	if not trouve:
		var dz := -m12.lieu_cimetiere.basis.z
		route_convoi = _au_sol(c + dz * 110.0)
		dir_convoi = m12.lieu_cimetiere.basis.x
		convoi_vue = c - dz * 12.0 + Vector3(0, 30.0, 0)
	var de := _plat(c)
	var vers2 := _plat(route_convoi)
	var couloir := func(q: Vector2) -> bool:
		var dv := vers2 - de
		var u := clampf((q - de).dot(dv) / dv.length_squared(), 0.0, 1.0)
		return q.distance_to(de + dv * u) < 6.0 + 8.0 * u
	var veg: Node = main.get_node_or_null("Vegetation")
	if veg and veg.has_method("degager"):
		veg.degager(couloir)
	var proche: Node = main.get_node_or_null("VegetationProche")
	if proche and proche.has_method("degager"):
		proche.degager(couloir)


func _preparer_convoi() -> void:
	var c := m12.lieu_cimetiere.origin
	for k in 2:
		var pk := _pickup(Transform3D(Basis(Vector3.UP, atan2(dir_convoi.x, dir_convoi.z)), route_convoi - dir_convoi * (60.0 + k * 9.0)))
		convoi.append(pk)
	var lat := dir_convoi.cross(Vector3.UP).normalized()
	mamba = _perso("ancien", "Repos", _au_sol(route_convoi + lat * 2.4), atan2(c.x - route_convoi.x, c.z - route_convoi.z))
	mamba.scale = Vector3.ONE * 1.15
	_coiffe(mamba, Color(0.05, 0.05, 0.05), 0.1, 0.035)
	vq._canne(mamba)
	mamba.visible = false


func _convoi() -> void:
	t_convoi = (Time.get_ticks_msec() - convoi_debut) / 1000.0
	# arrivée (0-7 s), arrêt (7-17 s, Mamba descend), départ
	for k in convoi.size():
		var pk: Node3D = convoi[k]
		var s: float
		if t_convoi < 7.0:
			s = lerpf(-60.0, 0.0, 1.0 - pow(1.0 - t_convoi / 7.0, 2.0))
		elif t_convoi < 17.0:
			s = 0.0
		else:
			s = 0.6 * pow(t_convoi - 17.0, 2.0)
		var p := route_convoi + dir_convoi * (s - k * 9.0)
		pk.global_position = _au_sol(p)
		pk.visible = absf(s - k * 9.0) < 70.0
	mamba.visible = t_convoi > 8.0 and t_convoi < 16.5
	if t_convoi > 40.0:
		t_convoi = -1.0


# ---------------------------------------------------------------------
# Fin et chargement
# ---------------------------------------------------------------------
func terminer() -> void:
	gen += 1
	phase = Phase.TERMINEE
	t_bac = -1.0
	t_convoi = -1.0
	_effacer_decor()
	convoi.clear()
	foule.clear()
	gardes.clear()
	if m12:
		m12.bac.global_transform = m12.lieu_bac
		m12.passeur.visible = true
	joueur.visible = true
	if en_scene:
		_cinematique(false)
	voile.color.a = 0.0

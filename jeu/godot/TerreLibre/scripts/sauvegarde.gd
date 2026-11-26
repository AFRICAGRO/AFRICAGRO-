## Sauvegarde et chargement de la partie (fichier user://sauvegarde.json).
## F5 : sauvegarder · F9 : reprendre la dernière sauvegarde. Sauvegarde automatique toutes les 3 minutes
## et dès qu'Akwéri est libéré.
## On garde : Faris (position, regard, santé, fusil et munitions), l'ambiance (heure, météo), la moto,
## le cheval et les pirogues, les barrages levés (et le sort de chaque garde), la libération d'Akwéri
## (miliciens tués ou épargnés, jauge de confiance), la balise de la carte.
## Une mission interrompue en cours de route reprend depuis son début.
class_name Sauvegarde
extends Node

const FICHIER := "user://sauvegarde.json"
const AUTO := 180.0

var main: Node
var t_auto := AUTO
var liberee_vue := false


func preparer(p_main: Node) -> void:
	main = p_main


func _annoncer(t: String) -> void:
	var m: Node = main.get_node_or_null("Mission4")
	if m and m.has_method("_annoncer"):
		m._annoncer(t, 2.5)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("sauver"):
		sauver()
		_annoncer("Partie sauvegardée.")
	elif event.is_action_pressed("charger"):
		if charger():
			_annoncer("Partie reprise.")
		else:
			_annoncer("Aucune sauvegarde.")


func _process(delta: float) -> void:
	var j: Joueur = main.joueur
	if j == null or j.mort:
		return
	t_auto -= delta
	var mission: Node = main.get_node_or_null("Mission4")
	var liberee: bool = mission != null and mission.phase == Mission4.Phase.LIBERE
	if t_auto <= 0.0 or (liberee and not liberee_vue):
		liberee_vue = liberee_vue or liberee
		t_auto = AUTO
		sauver()


# ---------------------------------------------------------------------
func _v3(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


func _lv3(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])


func sauver() -> void:
	var j: Joueur = main.joueur
	var d := {
		"version": 1,
		"joueur": {"pos": _v3(j.global_position), "lacet": j.lacet, "pv": j.pv, "arme": j.a_une_arme,
				"munitions": j.munitions, "reserve": j.reserve},
		"ambiance": (main.ambiances as Ambiances).index,
		"montures": {},
		"barrages": [],
	}
	for nom in ["MotoFaris", "Cheval", "Pirogue0", "Pirogue1"]:
		var n: Node3D = main.get_node_or_null(nom)
		if n:
			d["montures"][nom] = {"pos": _v3(n.global_position), "cap": n.get("cap")}
	var co: Node = main.get_node_or_null("Controles")
	if co:
		for poste in co.postes:
			var etats := []
			for g in poste["gardes"]:
				etats.append(int((g as Pnj).etat))
			d["barrages"].append({"leve": poste["leve"], "gardes": etats})
	var mission: Node = main.get_node_or_null("Mission4")
	if mission:
		var etats := []
		for p in mission.pnjs:
			etats.append(int((p as Pnj).etat))
		d["akweri"] = {"phase": int(mission.phase), "confiance": mission.confiance, "tues": mission.tues,
				"epargnes": mission.epargnes, "pnjs": etats}
	var m5: Node = main.get_node_or_null("Mission5")
	if m5:
		d["graines"] = {"phase": int(m5.phase), "livres": m5.sacs_livres, "preuve": m5.preuve}
	var m6: Node = main.get_node_or_null("Mission6")
	if m6:
		d["bome"] = {"phase": int(m6.phase), "choix": m6.choix, "argent": m6.argent, "revenu": m6.revenu,
				"maisons_perdues": m6.maisons_perdues, "t_revenu": m6.t_revenu}
	var m7: Node = main.get_node_or_null("Mission7")
	if m7:
		d["radio"] = {"phase": int(m7.phase), "offrande": m7.offrande}
	var tel: Node = main.get_node_or_null("Telephone")
	if tel:
		d["telephone"] = {"argent": tel.argent, "historique": tel.historique, "preuves": tel.preuves,
				"radio": tel.radio_racines, "ton": tel.ton_radio}
	var ca: Node = main.get_node_or_null("Carte")
	if ca and ca.balise != Vector3.INF:
		d["balise"] = _v3(ca.balise)
	var f := FileAccess.open(FICHIER, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d, "\t"))


func charger() -> bool:
	if not FileAccess.file_exists(FICHIER):
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(FICHIER))
	if typeof(d) != TYPE_DICTIONARY:
		return false
	var j: Joueur = main.joueur
	# d'abord descendre de toute monture
	if j.a_cheval and j.a_cheval.has_method("descendre"):
		j.a_cheval.descendre()
	# montures et embarcations
	for nom in d.get("montures", {}):
		var n: Node3D = main.get_node_or_null(nom)
		if n == null:
			continue
		var m: Dictionary = d["montures"][nom]
		n.global_position = _lv3(m["pos"])
		if m.get("cap") != null:
			n.set("cap", float(m["cap"]))
			n.rotation.y = float(m["cap"])
		if n is CharacterBody3D:
			(n as CharacterBody3D).velocity = Vector3.ZERO
		if n.get("vitesse") != null:
			n.set("vitesse", 0.0)
	# Faris
	var dj: Dictionary = d["joueur"]
	j.ressusciter(_lv3(dj["pos"]) + Vector3(0, 0.3, 0))
	j.lacet = float(dj["lacet"])
	j.pv = float(dj["pv"])
	if dj["arme"] and not j.a_une_arme:
		j.donner_arme()
	j.munitions = int(dj["munitions"])
	j.reserve = int(dj["reserve"])
	# ambiance
	var amb: Ambiances = main.ambiances
	var garde := 0
	while amb.index != int(d.get("ambiance", 0)) and garde < 10:
		amb.suivante()
		garde += 1
	# barrages : les gardes tués ou ligotés le restent ; un barrage levé reste levé
	var co: Node = main.get_node_or_null("Controles")
	if co:
		var db: Array = d.get("barrages", [])
		for i in mini(db.size(), co.postes.size()):
			var poste: Dictionary = co.postes[i]
			var etats: Array = db[i]["gardes"]
			for k in mini(etats.size(), poste["gardes"].size()):
				_appliquer_etat(poste["gardes"][k], int(etats[k]))
			poste["leve"] = bool(db[i]["leve"])
			poste["alerte"] = false
	# Akwéri : si le village avait été libéré, il l'est de nouveau
	var mission: Node = main.get_node_or_null("Mission4")
	if mission and d.has("akweri"):
		var da: Dictionary = d["akweri"]
		if int(da["phase"]) == Mission4.Phase.LIBERE and mission.phase != Mission4.Phase.LIBERE:
			var etats: Array = da["pnjs"]
			for k in mini(etats.size(), mission.pnjs.size()):
				_appliquer_etat(mission.pnjs[k], int(etats[k]))
			for p in mission.pnjs:   # miliciens des vagues pas encore apparues lors de la sauvegarde
				if (p as Pnj).role != "civil" and (p as Pnj).est_actif():
					_appliquer_etat(p, Pnj.Etat.LIGOTE)
			mission.choix_fait = true
			mission._liberer()
		mission.confiance = int(da["confiance"])
		mission.tues = int(da["tues"])
		mission.epargnes = int(da["epargnes"])
	var m5: Node = main.get_node_or_null("Mission5")
	if m5 and d.has("graines"):
		var dg: Dictionary = d["graines"]
		m5.preuve = bool(dg["preuve"])
		var livres := int(dg["livres"])
		while m5.sacs_livres < livres and m5.tas_sacs.size() > 0:
			(m5.tas_sacs.pop_back() as Node).queue_free()
			m5.sacs_livres += 1
			m5.sacs_restants -= 1
		if int(dg["phase"]) == Mission5.Phase.TERMINEE and m5.phase != Mission5.Phase.TERMINEE:
			m5.phase = Mission5.Phase.TERMINEE
			m5.m4._objectif("Prochain objectif : apporter les semences à Bomé (mission 6).")
		elif m5.phase == Mission5.Phase.EN_COURS:
			m5._reprendre_plus_tard()
	var m6: Node = main.get_node_or_null("Mission6")
	if m6 and d.has("bome"):
		var db6: Dictionary = d["bome"]
		m6.argent = int(db6["argent"])
		m6.revenu = int(db6["revenu"])
		m6.t_revenu = float(db6.get("t_revenu", 0.0))
		m6.maisons_perdues = int(db6["maisons_perdues"])
		if int(db6["phase"]) == Mission6.Phase.TERMINEE and m6.phase != Mission6.Phase.TERMINEE:
			m6.choix = db6["choix"]
			m6.phase = Mission6.Phase.TERMINEE
			for p6 in m6.parcelles:
				for idx in Mission6.NX * Mission6.NY:
					p6["etat"][idx] = 2
					@warning_ignore("integer_division")
					m6._eteindre_case(m6.parcelles.find(p6), idx % Mission6.NX, idx / Mission6.NX)
				p6["brulee"] = true
			m6._drapeau()
			m6.m4._objectif("Prochain objectif : la résistance a besoin d'une voix — l'antenne du mont Talanké (mission 7).")
	var m7: Node = main.get_node_or_null("Mission7")
	if m7 and d.has("radio"):
		m7.offrande = bool(d["radio"]["offrande"])
		if int(d["radio"]["phase"]) == Mission7.Phase.TERMINEE and m7.phase != Mission7.Phase.TERMINEE:
			m7.restaurer_terminee("")
	var tel: Node = main.get_node_or_null("Telephone")
	if tel and d.has("telephone"):
		var dt: Dictionary = d["telephone"]
		tel.argent = int(dt["argent"])
		tel.historique = dt["historique"]
		tel.preuves = dt["preuves"]
		tel.radio_racines = bool(dt["radio"])
		tel.ton_radio = str(dt.get("ton", ""))
	var ca: Node = main.get_node_or_null("Carte")
	if ca:
		if d.has("balise"):
			ca.poser_balise(_lv3(d["balise"]))
		else:
			ca.balise = Vector3.INF
			ca.colonne.visible = false
	liberee_vue = mission != null and mission.phase == Mission4.Phase.LIBERE
	return true


## Remet un Pnj dans l'état sauvegardé sans déclencher d'événement (pas d'annonce, pas de vague suivante).
func _appliquer_etat(p: Pnj, etat: int) -> void:
	if p.etat == etat or not p.est_actif():
		return
	p.set_block_signals(true)
	if etat == Pnj.Etat.LIGOTE:
		p.ligoter()
	elif etat == Pnj.Etat.MORT:
		p._mourir(false)
	p.set_block_signals(false)

## Barrages du Cobra à Port-Néré, tenus par de vrais miliciens (Pnj).
## Règles, comme aux vrais postes de contrôle :
## - on passe au pas : les gardes regardent, laissent passer un homme sans arme ;
## - arme visible : ils se méfient puis ouvrent le feu (règle commune des Pnj) ;
## - forcer le barrage à moto ou au galop : alerte immédiate, ils tirent ;
## - la nuit, couvre-feu : qui s'approche est sommé de faire demi-tour, puis pris pour cible.
## Un milicien qui se rend peut être ligoté (F). Un barrage vidé de ses gardes est levé.
class_name Controles
extends Node

signal alerte_barrage(position: Vector3)   # entendu par radio par les patrouilles

const RAYON_ANNONCE := 26.0
const RAYON_FORCE := 12.0
const VITESSE_FORCE := 7.0      # m/s : au-delà, on force le barrage
const RAYON_COUVRE_FEU := 15.0
const SOMMATION := 3.0          # secondes avant le tir pendant le couvre-feu

var joueur: Joueur
var annonceur: Node             # la mission 4 affiche les messages (_annoncer)
var postes: Array = []          # {centre, gardes, alerte, prevenu, t_nuit, leve, t_loin}
var tous: Array = []
var couverts: Array = []        # [position, rayon] : murets de sacs de sable, pick-up arrêtés
var foule: Foule                # les passants fuient les coups de feu


## Port-Néré libérée (mission 12) : les miliciens des barrages sont partis, plus de couvre-feu.
func liberer() -> void:
	for poste in postes:
		for g in poste["gardes"]:
			if is_instance_valid(g):
				(g as Node).queue_free()
	postes.clear()
	tous.clear()
	set_process(false)


func construire(ville: VillePortNere, p_joueur: Joueur, p_annonceur: Node) -> void:
	joueur = p_joueur
	annonceur = p_annonceur
	if not ville.reperes.has("barrages") or not ville.reperes.has("barrages_axe"):
		return
	var modeles := ["homme2", "villageois", "homme3"]
	var k := 0
	for i in ville.reperes["barrages"].size():
		var c: Vector3 = ville.reperes["barrages"][i]
		var t: Vector2 = ville.reperes["barrages_axe"][i][0]
		var demi: float = ville.reperes["barrages_axe"][i][1]
		var n := Vector2(-t.y, t.x)
		var c2 := Vector2(c.x, c.z)
		# deux gardes contre les murets de sacs de sable, un troisième près de la barrière
		var places := [c2 + n * (demi - 0.4) - t * 1.0, c2 - n * (demi - 0.4) + t * 1.0, c2 + n * (demi - 1.6) + t * 1.4]
		for s_ in [-1.0, 1.0]:   # les deux murets de sacs de sable du barrage
			var mu: Vector2 = c2 + n * s_ * (demi + 0.6)
			couverts.append([Vector3(mu.x, c.y, mu.y), 1.3])
		var gardes: Array = []
		for q in places:
			var g := Pnj.new()
			add_child(g)
			var h: float = ville._sol(q)
			g.global_position = Vector3(q.x, h + 0.2, q.y)
			g.preparer("milicien", self, joueur, Color(1, 1, 1), "res://data/textures/camouflage.jpg", modeles[k % modeles.size()])
			k += 1
			g._regarder(Vector3(c2.x, h, c2.y), 1.0)   # tournés vers la route
			g.neutralise.connect(_neutralise.bind(i))
			g.rendu.connect(_rendu)
			g.alerte.connect(_alerte.bind(i))
			gardes.append(g)
			tous.append(g)
		postes.append({"centre": c, "gardes": gardes, "alerte": false, "prevenu": false, "t_nuit": 0.0,
				"leve": false, "t_loin": 0.0})
	joueur.a_tire.connect(func(p: Vector3) -> void: bruit_de_tir(p, true))
	joueur.tombe.connect(_joueur_tombe)


# ---------- ce que les Pnj demandent à leur « mission » ----------
## Couvert le plus proche (à moins de 25 m) : derrière un muret ou un pick-up, du côté opposé à Faris.
func choisir_couvert(n: Pnj) -> Vector3:
	var best := n.global_position
	var dmin := 25.0
	for c in couverts:
		var pos: Vector3 = c[0]
		var oppose := pos - joueur.global_position
		oppose.y = 0
		if oppose.length() < 4.0:
			continue
		var p := pos + oppose.normalized() * (float(c[1]) + 0.8)
		var d := p.distance_to(n.global_position) + randf_range(0.0, 3.0)
		if d < dmin:
			dmin = d
			best = p
	return best


func bruit_de_tir(p: Vector3, joueur_tire := false) -> void:
	for g in tous:
		(g as Pnj).entendre(p, 70.0 if joueur_tire else 45.0)
	if foule:
		foule.panique(p, 90.0)


func blessure() -> void:
	pass


# ---------- événements ----------
func _alerte(_p: Vector3, i: int) -> void:
	_tous_au_combat(i)


func _tous_au_combat(i: int) -> void:
	var poste: Dictionary = postes[i]
	if not poste["alerte"]:
		alerte_barrage.emit(poste["centre"])
	poste["alerte"] = true
	for g in poste["gardes"]:
		if (g as Pnj).est_actif():
			(g as Pnj)._passer_combat()


func _rendu(_n: Pnj) -> void:
	_annoncer("Un milicien du barrage se rend : F pour le ligoter (épargné).", 3.0)


func _neutralise(_n: Pnj, _comment: String, i: int) -> void:
	var poste: Dictionary = postes[i]
	for g in poste["gardes"]:
		if (g as Pnj).est_actif() or (g as Pnj).etat == Pnj.Etat.RENDU:
			return
	if not poste["leve"]:
		poste["leve"] = true
		_annoncer("Barrage levé : la route est libre.", 4.0)


func _joueur_tombe() -> void:
	# tombé en selle : Faris est d'abord descendu de sa monture (la mission 4 le relève ensuite)
	var monture: Node = joueur.a_cheval
	if monture and monture.has_method("descendre"):
		monture.descendre()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interagir") or joueur == null or joueur.mort or joueur.a_cheval:
		return
	var meilleur: Pnj = null
	var dmin := 2.0
	for g in tous:
		var p := g as Pnj
		var d := p.global_position.distance_to(joueur.global_position)
		if d < dmin and (p.etat == Pnj.Etat.RENDU or (p.est_actif() and p.dos_au_joueur())):
			meilleur = p
			dmin = d
	if meilleur:
		meilleur.ligoter()
		_annoncer("Milicien ligoté.", 2.0)


func _annoncer(t: String, duree: float) -> void:
	if annonceur and annonceur.has_method("_annoncer"):
		annonceur._annoncer(t, duree)


# ---------- règles du poste de contrôle ----------
func _process(delta: float) -> void:
	if joueur == null or joueur.mort:
		return
	var nuit := false
	if joueur.has_meta("nuit"):
		nuit = joueur.get_meta("nuit")
	var monture: Node = joueur.a_cheval
	var vite := monture != null and joueur.vitesse_affichee > VITESSE_FORCE
	for i in postes.size():
		var poste: Dictionary = postes[i]
		if poste["leve"]:
			continue
		var c: Vector3 = poste["centre"]
		var d := Vector2(joueur.global_position.x - c.x, joueur.global_position.z - c.z).length()
		if poste["alerte"]:
			# loin depuis un moment : les gardes se calment et reprennent leur poste
			poste["t_loin"] = poste["t_loin"] + delta if d > 90.0 else 0.0
			if poste["t_loin"] > 20.0:
				poste["alerte"] = false
				poste["prevenu"] = false
				for g in poste["gardes"]:
					var p := g as Pnj
					if p.etat == Pnj.Etat.COMBAT:
						p.etat = Pnj.Etat.CALME
						p.soupcon = 0.0
			continue
		if d > RAYON_ANNONCE + 10.0:
			poste["prevenu"] = false
			poste["t_nuit"] = 0.0
			continue
		if d < RAYON_FORCE and vite:
			_annoncer("Vous avez forcé le barrage du Cobra !", 3.0)
			_tous_au_combat(i)
			continue
		if nuit and d < RAYON_COUVRE_FEU:
			if poste["t_nuit"] == 0.0:
				_annoncer("« Couvre-feu ! Halte ! Demi-tour ! »", SOMMATION)
			poste["t_nuit"] += delta
			if poste["t_nuit"] > SOMMATION:
				_annoncer("Les miliciens ouvrent le feu.", 2.5)
				_tous_au_combat(i)
			continue
		if not nuit:
			poste["t_nuit"] = 0.0
		if d < RAYON_ANNONCE and not poste["prevenu"]:
			poste["prevenu"] = true
			if nuit:
				_annoncer("Barrage du Cobra — couvre-feu : ne vous approchez pas.", 3.5)
			elif monture:
				_annoncer("Barrage du Cobra : ralentissez et passez au pas.", 3.5)
			else:
				_annoncer("Barrage du Cobra : passez calmement, sans arme visible.", 3.5)


## Reçu des ambiances (0 = jour, 1 = nuit) : la nuit est aussi notée sur Faris pour ses montures (phare, chèche).
func regler_nuit(f: float) -> void:
	if joueur:
		joueur.set_meta("nuit", f > 0.5)

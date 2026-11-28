## Mission 12 — « L'Aube » (voir jeu/missions/12-L-AUBE.md). Épilogue de l'acte 1, sans combat.
## Port-Néré libérée : on se promène et l'on voit, de ses yeux, ce qui a changé.
## - Avant (dès le début du jeu) : la fresque de la coopérative est délavée, l'affiche du Front du Cobra
##   collée dessus ; barrages et couvre-feu.
## - Après : la fresque repeinte (Samuel au centre, Faris dessiné à la craie par un enfant), les miliciens
##   partis, des fanions, des lampadaires solaires (Kwame), Radio Racines au maquis, le marché plein,
##   les pêcheurs qui chantent, Petit Prince sur son vélo neuf, un match de foot sur la latérite.
## - Activités facultatives : danser au maquis, partager un repas avec Baya Efua, jouer au football,
##   écouter les villageois raconter « leur » libération, saluer Petit Prince, voir la fresque.
## - Le cimetière au coucher du soleil (Ama ; Mamba escorté ou Dossou aux pirogues, selon les choix).
## - Le bac de nuit, la voix inconnue à la radio, la carte de Wanzala et le bilan de l'acte 1.
class_name Mission12
extends Node3D

enum Phase { INDISPONIBLE, DISPONIBLE, FETE, CIMETIERE, NUIT, BAC, BILAN, TERMINEE }
const ACTIVITES := {
	"fresque": "Voir la fresque de la coopérative",
	"danse": "Danser à la fête du maquis",
	"repas": "Partager un repas avec Baya Efua",
	"foot": "Marquer un but sur le terrain de latérite",
	"histoires": "Écouter les villageois raconter « leur » libération",
	"prince": "Saluer Petit Prince sur son vélo neuf",
}

var phase := Phase.INDISPONIBLE
var main: Node
var joueur: Joueur
var m4: Mission4
var ville: VillePortNere
var vq: VieQuotidienne
var fait := {}
var t_fete := 0.0
var t_hud := 0.0
# lieux trouvés dans la ville (sans toucher une maison ni une rue)
var lieu_fresque := Transform3D()
var lieu_cimetiere := Transform3D()
var lieu_terrain := Transform3D()
var lieu_bac := Transform3D()
var tombe := Vector3.ZERO
var affiche: MeshInstance3D
var mur_fresque: MeshInstance3D
var fete: Node3D
var lampes: Array = []
var danseurs: Array = []
var conteurs: Array = []        # [noeud, lignes, index]
var baya: Node3D
var prince: Node3D
var t_prince := 0.0
var ballon: RigidBody3D
var gamins: Array = []
var buts := 0
var bac: Node3D
var passeur: Node3D
var t_bac := 0.0
var cam: Camera3D
var radio_maquis: AudioStreamPlayer3D
var calque: CanvasLayer
var ecran_fin: Control
var voile: ColorRect
var bilan := {}
var escorte: Array = []
var t_escorte := 0.0


func construire(p_main: Node) -> void:
	main = p_main
	joueur = main.joueur
	m4 = main.get_node("Mission4")
	ville = main.ville
	vq = main.get_node("VieQuotidienne")
	_trouver_lieux()
	_fresque()
	_cimetiere()
	_bac()
	_interface()


# ---------------------------------------------------------------------
# Où poser les choses : une place libre près d'un repère, à plat, hors de l'eau
# ---------------------------------------------------------------------
func _trouver(pres: Vector2, w: float, d: float, rmin: float, rmax: float, pente_max: float, vers: Vector2) -> Transform3D:
	var t := main.terrain as Terrain
	var r := rmin
	while r <= rmax:
		var n := maxi(8, int(TAU * r / 6.0))
		for k in n:
			var a := TAU * k / n
			var c := pres + Vector2(cos(a), sin(a)) * r
			var avant := (vers - c).normalized() if vers != Vector2.INF else Vector2(0, 1)
			if not ville._rect_libre(c, avant, w, d, 1.5):
				continue
			var droite := Vector2(-avant.y, avant.x)
			var hs: Array = []
			for coin in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1), Vector2.ZERO]:
				var q: Vector2 = c + droite * coin.x * w * 0.5 + avant * coin.y * d * 0.5
				hs.append(t.hauteur(q.x, q.y))
			if hs.min() < 1.2 or hs.max() - hs.min() > pente_max:
				continue
			ville._prendre(c, avant, w, d, 1.0)
			var h: float = hs[4]
			return Transform3D(Basis(Vector3.UP, atan2(avant.x, avant.y)), Vector3(c.x, h, c.y))
		r += 4.0
	push_warning("Mission 12 : pas de place libre près de %s" % str(pres))
	return Transform3D(Basis(), Vector3(pres.x, t.hauteur(pres.x, pres.y), pres.y))


func _trouver_lieux() -> void:
	var marche: Vector3 = ville.reperes["marche"]
	var place: Vector3 = ville.reperes["place"]
	var eglise: Vector3 = ville.reperes["eglise"]
	lieu_fresque = _trouver(Vector2(marche.x, marche.z), 11.0, 3.0, 10.0, 60.0, 1.2, Vector2(place.x, place.z))
	lieu_cimetiere = _trouver(Vector2(eglise.x, eglise.z), 26.0, 20.0, 20.0, 140.0, 3.0, Vector2(eglise.x, eglise.z))
	# le terrain de foot : un terrain vague en bordure de ville, près de la maison de Faris
	var maison: Vector3 = ville.reperes["maison_faris"]
	lieu_terrain = _trouver(Vector2(maison.x, maison.z), 24.0, 40.0, 25.0, 520.0, 3.5, Vector2(maison.x, maison.z))
	# le bac : on part de la place vers le large jusqu'à 2,5 m de fond
	var t := main.terrain as Terrain
	var mer := Vector2(-1, 0)
	var q := Vector2(place.x, place.z)
	for i in 200:
		var h := t.hauteur(q.x, q.y)
		if h < -2.5:
			break
		var meilleur := mer
		var hmin := INF
		for k in 16:
			var dir := Vector2.from_angle(TAU * k / 16.0)
			var hh := t.hauteur(q.x + dir.x * 6.0, q.y + dir.y * 6.0)
			if hh < hmin:
				hmin = hh
				meilleur = dir
		mer = meilleur
		q += mer * 3.0
	lieu_bac = Transform3D(Basis(Vector3.UP, atan2(mer.x, mer.y)), Vector3(q.x, 0.0, q.y))


func _boite(taille: Vector3, xf: Transform3D, couleur: Color, parent: Node3D, solide := false, rugosite := 0.9) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = taille
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = couleur
	m.roughness = rugosite
	mi.material_override = m
	parent.add_child(mi)
	mi.global_transform = xf
	if solide:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = taille
		cs.shape = bs
		sb.add_child(cs)
		parent.add_child(sb)
		sb.global_transform = xf
	return mi


func _quad(taille: Vector2, xf: Transform3D, tex: Texture2D, parent: Node3D, transparent := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = taille
	mi.mesh = qm
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.roughness = 0.85
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mi.material_override = m
	parent.add_child(mi)
	mi.global_transform = xf
	return mi


# ---------------------------------------------------------------------
# La fresque de la coopérative (avant : délavée, affiche du Cobra ; après : repeinte)
# ---------------------------------------------------------------------
func _fresque() -> void:
	var xf := lieu_fresque
	_boite(Vector3(10.6, 3.4, 0.4), xf.translated_local(Vector3(0, 1.7, 0)), Color(0.82, 0.76, 0.64), self, true)
	_boite(Vector3(10.9, 0.25, 0.6), xf.translated_local(Vector3(0, 3.5, 0)), Color(0.6, 0.35, 0.25), self)
	# la fresque, côté place (+Z local)
	var tex: Texture2D = load("res://data/textures/fresque_samuel.png")
	mur_fresque = _quad(Vector2(9.6, 3.0), xf.translated_local(Vector3(0, 1.75, 0.21)), tex, self)
	(mur_fresque.material_override as StandardMaterial3D).albedo_color = Color(0.55, 0.52, 0.5)   # délavée, écaillée
	affiche = _quad(Vector2(1.5, 2.1), xf.translated_local(Vector3(0.2, 1.7, 0.23)), load("res://data/textures/affiche_cobra.png"), self, true)
	var placard := Label3D.new()
	placard.text = "COOPÉRATIVE DE PORT-NÉRÉ"
	placard.font_size = 48
	placard.pixel_size = 0.008
	placard.modulate = Color(0.25, 0.2, 0.15)
	placard.outline_size = 0
	add_child(placard)
	placard.global_transform = xf.translated_local(Vector3(0, 3.36, 0.31))


# ---------------------------------------------------------------------
# Le cimetière, près de l'église : chrétiens et musulmans côte à côte, comme dans la vie
# ---------------------------------------------------------------------
func _cimetiere() -> void:
	var xf := lieu_cimetiere
	var t := main.terrain as Terrain
	var muret := Color(0.78, 0.74, 0.66)
	for s in [-1.0, 1.0]:
		_boite(Vector3(0.35, 0.9, 20.0), xf.translated_local(Vector3(s * 13.0, 0.45, 0)), muret, self, true)
	_boite(Vector3(26.3, 0.9, 0.35), xf.translated_local(Vector3(0, 0.45, -10.0)), muret, self, true)
	for s in [-1.0, 1.0]:
		_boite(Vector3(11.0, 0.9, 0.35), xf.translated_local(Vector3(s * 7.6, 0.45, 10.0)), muret, self, true)   # entrée au milieu
	var rng := RandomNumberGenerator.new()
	rng.seed = 1212
	for i in 4:
		for k in 7:
			if i == 0 and k == 3:
				continue          # la place de Samuel
			var p := xf.translated_local(Vector3(-9.0 + k * 3.0 + rng.randf_range(-0.3, 0.3), 0, -6.5 + i * 4.0))
			p.origin.y = t.hauteur(p.origin.x, p.origin.z)
			_boite(Vector3(0.9, 0.25, 2.0), p.translated_local(Vector3(0, 0.12, 0)), Color(0.55, 0.48, 0.4) * rng.randf_range(0.85, 1.1), self)
			if rng.randf() < 0.55:
				# croix de bois ou de ciment
				_boite(Vector3(0.1, 1.0, 0.1), p.translated_local(Vector3(0, 0.6, -0.9)), Color(0.85, 0.84, 0.8), self)
				_boite(Vector3(0.55, 0.1, 0.1), p.translated_local(Vector3(0, 0.82, -0.9)), Color(0.85, 0.84, 0.8), self)
			else:
				# stèle simple, tournée comme le veut la tradition musulmane
				_boite(Vector3(0.45, 0.6, 0.1), p.translated_local(Vector3(0, 0.4, -0.95)), Color(0.82, 0.8, 0.74), self)
				_boite(Vector3(0.3, 0.4, 0.1), p.translated_local(Vector3(0, 0.3, 0.95)), Color(0.82, 0.8, 0.74), self)
	# la tombe de Samuel : dalle de ciment, stèle gravée du proverbe, fleurs fraîches
	var ts := xf.translated_local(Vector3(0, 0, -6.5))
	ts.origin.y = t.hauteur(ts.origin.x, ts.origin.z)
	tombe = ts.origin
	_boite(Vector3(1.2, 0.35, 2.3), ts.translated_local(Vector3(0, 0.18, 0)), Color(0.75, 0.74, 0.7), self)
	_boite(Vector3(1.0, 1.1, 0.15), ts.translated_local(Vector3(0, 0.75, -1.1)), Color(0.8, 0.79, 0.75), self)
	var ins := Label3D.new()
	ins.text = "SAMUEL\nfondateur de\nla coopérative\n\nZala ka wan,\nwan ka zala."
	ins.font_size = 26
	ins.pixel_size = 0.0026
	ins.modulate = Color(0.2, 0.2, 0.22)
	ins.outline_size = 0
	add_child(ins)
	ins.global_transform = ts.translated_local(Vector3(0, 0.85, -1.02))
	for i in 5:
		_boite(Vector3(0.12, 0.12, 0.12), ts.translated_local(Vector3(-0.4 + i * 0.2, 0.42, 0.6)), [Color(0.9, 0.2, 0.2), Color(0.95, 0.8, 0.2), Color(0.95, 0.95, 0.9)][i % 3], self)


# ---------------------------------------------------------------------
# Le bac (amarré au quai, son passeur au chapeau de paille)
# ---------------------------------------------------------------------
func _bac() -> void:
	bac = Node3D.new()
	add_child(bac)
	bac.global_transform = lieu_bac
	var coque := Color(0.2, 0.32, 0.4)
	_boite(Vector3(7.0, 1.4, 18.0), Transform3D(lieu_bac.basis, lieu_bac * Vector3(0, -0.2, 0)), coque, bac)
	_boite(Vector3(7.1, 0.12, 18.1), Transform3D(lieu_bac.basis, lieu_bac * Vector3(0, 0.55, 0)), Color(0.5, 0.42, 0.3), bac)
	_boite(Vector3(3.0, 2.4, 3.2), Transform3D(lieu_bac.basis, lieu_bac * Vector3(0, 1.8, 5.0)), Color(0.92, 0.9, 0.85), bac)    # timonerie
	_boite(Vector3(3.4, 0.1, 3.6), Transform3D(lieu_bac.basis, lieu_bac * Vector3(0, 3.05, 5.0)), Color(0.7, 0.2, 0.15), bac)
	for s in [-1.0, 1.0]:
		_boite(Vector3(0.08, 0.9, 18.0), Transform3D(lieu_bac.basis, lieu_bac * Vector3(s * 3.5, 1.05, 0)), Color(0.85, 0.85, 0.8), bac)
	var nom := Label3D.new()
	nom.text = "BAC DE TALANKÉ"
	nom.font_size = 72
	nom.pixel_size = 0.01
	nom.modulate = Color(0.95, 0.95, 0.9)
	nom.outline_size = 0
	bac.add_child(nom)
	nom.global_transform = Transform3D(lieu_bac.basis * Basis(Vector3.UP, PI * 0.5), lieu_bac * Vector3(3.62, 0.15, 0))
	for f in [[Vector3(0, 2.2, 5.0), Color(1.0, 0.75, 0.45), 2.5, 9.0], [Vector3(0, 4.2, 5.0), Color(1, 1, 0.95), 1.6, 30.0],
			[Vector3(-3.6, 1.6, 6.0), Color(1, 0.15, 0.1), 1.2, 6.0], [Vector3(3.6, 1.6, 6.0), Color(0.1, 1, 0.3), 1.2, 6.0],
			[Vector3(0, 3.0, -3.0), Color(1.0, 0.85, 0.6), 2.2, 14.0]]:
		var l := OmniLight3D.new()
		l.light_color = f[1]
		l.light_energy = f[2]
		l.omni_range = f[3]
		bac.add_child(l)
		l.global_position = lieu_bac * (f[0] as Vector3)
	_boite(Vector3(0.15, 3.0, 0.15), Transform3D(lieu_bac.basis, lieu_bac * Vector3(0, 4.5, 5.0)), Color(0.8, 0.8, 0.8), bac)    # mât
	passeur = vq._perso("ancien", "Repos", lieu_bac * Vector3(2.2, 0.62, 3.0), atan2(lieu_bac.basis.z.x, lieu_bac.basis.z.z))   # à la barre, devant la timonerie
	passeur.reparent(bac)
	# le chapeau de paille du passeur
	var chap := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.16
	cm.bottom_radius = 0.34
	cm.height = 0.14
	chap.mesh = cm
	var mp := StandardMaterial3D.new()
	mp.albedo_color = Color(0.85, 0.72, 0.42)
	chap.material_override = mp
	passeur.add_child(chap)
	chap.position = Vector3(0, 1.74, 0)


func _interface() -> void:
	calque = CanvasLayer.new()
	calque.layer = 8
	add_child(calque)
	voile = ColorRect.new()
	voile.color = Color(0, 0, 0, 0)
	voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	calque.add_child(voile)
	ecran_fin = Control.new()
	ecran_fin.set_anchors_preset(Control.PRESET_FULL_RECT)
	ecran_fin.visible = false
	calque.add_child(ecran_fin)
	var fond := ColorRect.new()
	fond.color = Color(0.04, 0.05, 0.06, 1.0)
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	ecran_fin.add_child(fond)
	var carte := TextureRect.new()
	carte.texture = load("res://data/textures/fin_acte1.png")
	carte.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	carte.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	carte.anchor_right = 0.56
	carte.anchor_bottom = 1.0
	ecran_fin.add_child(carte)
	var col := VBoxContainer.new()
	col.anchor_left = 0.58
	col.anchor_right = 0.97
	col.anchor_top = 0.08
	col.anchor_bottom = 0.95
	col.add_theme_constant_override("separation", 10)
	ecran_fin.add_child(col)
	var titre := Label.new()
	titre.name = "Titre"
	titre.text = "FIN DE L'ACTE 1 — L'ÎLE"
	titre.add_theme_font_size_override("font_size", 34)
	titre.add_theme_color_override("font_color", Color(0.91, 0.7, 0.23))
	col.add_child(titre)
	var corps := Label.new()
	corps.name = "Bilan"
	corps.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	corps.add_theme_font_size_override("font_size", 18)
	col.add_child(corps)
	var suite := Button.new()
	suite.text = "Continuer à parcourir l'île"
	suite.pressed.connect(_continuer)
	col.add_child(suite)


func etat_texte() -> String:
	return ["à venir", "disponible", "la fête", "le cimetière", "la nuit", "le bac", "le bilan", "fin de l'acte 1"][phase]


# ---------------------------------------------------------------------
# Déroulement
# ---------------------------------------------------------------------
func _process(delta: float) -> void:
	if joueur == null:
		return
	var jp := joueur.global_position
	var place: Vector3 = ville.reperes["place"]
	match phase:
		Phase.INDISPONIBLE:
			var m11: Node = main.get_node_or_null("Mission11")
			if m11 and m11.phase == Mission11.Phase.TERMINEE:
				_annonce()
		Phase.DISPONIBLE:
			if _plat(jp).distance_to(_plat(place)) < 220.0:
				_liberer()
		Phase.FETE:
			t_fete += delta
			_vie(delta)
			if fait.size() >= 3 or t_fete > 420.0:
				_vers_cimetiere()
		Phase.CIMETIERE:
			_vie(delta)
			if jp.distance_to(tombe) < 4.0 and t_escorte == 0.0:
				@warning_ignore("missing_await")
				_scene_cimetiere()
		Phase.NUIT:
			_vie(delta)
			if jp.distance_to(lieu_bac.origin) < 14.0:
				@warning_ignore("missing_await")
				_scene_bac()
		Phase.BAC:
			_vie(delta)
			_bac_part(delta)
		Phase.TERMINEE:
			if fete:
				_vie(delta)        # la fête continue : lampadaires, foot, Petit Prince
	if phase in [Phase.FETE, Phase.CIMETIERE, Phase.NUIT]:
		t_hud -= delta
		if t_hud <= 0.0:
			t_hud = 0.5
			_mettre_objectif()
	if t_escorte > 0.0:
		_escorte(delta)


func _annonce() -> void:
	phase = Phase.DISPONIBLE
	var tel: Node = main.get_node_or_null("Telephone")
	if tel:
		tel.notifier("Mama Rokia : « Reviens à Port-Néré. Toute la ville t'attend. »")
	m4._objectif("Mission 12 — L'Aube : retournez à Port-Néré.")
	var ca: Node = main.get_node_or_null("Carte")
	if ca:
		ca.poser_balise(ville.reperes["place"])


func _liberer() -> void:
	phase = Phase.FETE
	joueur.mission = self
	var co: Node = main.get_node_or_null("Controles")
	if co and co.has_method("liberer"):
		co.liberer()
	var pa: Node = main.get_node_or_null("Patrouilles")
	if pa and pa.has_method("liberer"):
		pa.liberer()
	var amb: Ambiances = main.ambiances
	amb.ile_libre = true
	var garde := 0
	while amb.index != 1 and garde < 8:   # plein jour
		amb.suivante()
		garde += 1
	# la fresque repeinte : plus d'affiche, des couleurs neuves
	affiche.visible = false
	(mur_fresque.material_override as StandardMaterial3D).albedo_color = Color(1, 1, 1)
	_installer_fete()
	m4._annoncer("Mission 12 — L'Aube\nPort-Néré. Plus un milicien aux barrages. Des fanions entre les lampadaires, la musique de Radio Racines, des enfants partout.", 7.0)
	var ca: Node = main.get_node_or_null("Carte")
	if ca:
		ca.poser_balise(lieu_fresque.origin)


func _mettre_objectif() -> void:
	match phase:
		Phase.FETE:
			var t := "Promenez-vous dans Port-Néré libérée (%d activités sur 6, au moins 3) :\n" % fait.size()
			for k in ACTIVITES:
				t += ("✓ " if fait.has(k) else "○ ") + str(ACTIVITES[k]) + "\n"
			m4._objectif(t.strip_edges())
		Phase.CIMETIERE:
			m4._objectif("Au coucher du soleil, rejoignez la tombe de votre père, au cimetière près de l'église.")
		Phase.NUIT:
			m4._objectif("La nuit est tombée, éclairée. Le bac reprend son service : rejoignez-le au quai.")


func _cocher(k: String) -> void:
	if fait.has(k):
		return
	fait[k] = true
	m4.confiance = clampi(m4.confiance + 1, 0, 100)


# ---------------------------------------------------------------------
# La fête : fanions, lampadaires, marché plein, pêcheurs, foot, Petit Prince
# ---------------------------------------------------------------------
func _installer_fete() -> void:
	fete = Node3D.new()
	add_child(fete)
	var t := main.terrain as Terrain
	var place: Vector3 = ville.reperes["place"]
	var maquis: Vector3 = ville.reperes["maquis"]
	var marche: Vector3 = ville.reperes["marche"]
	# lampadaires solaires de Kwame, en anneau autour de la place et le long des rues vers le marché
	var poses: Array = []
	for k in 10:
		var a := TAU * k / 10.0
		poses.append(Vector2(place.x, place.z) + Vector2(cos(a), sin(a)) * 24.0)
	for k in 6:
		poses.append(Vector2(place.x, place.z).lerp(Vector2(marche.x, marche.z), (k + 1) / 7.0) + Vector2(3.5, 0))
	for k in 3:
		poses.append(Vector2(place.x, place.z).lerp(Vector2(maquis.x, maquis.z), (k + 1) / 4.0) + Vector2(0, 3.5))
	for q in poses:
		var c := q as Vector2
		if not ville._rect_libre(c, Vector2(0, 1), 0.6, 0.6, 0.2):
			continue
		var h := t.hauteur(c.x, c.y)
		_boite(Vector3(0.12, 4.6, 0.12), Transform3D(Basis(), Vector3(c.x, h + 2.3, c.y)), Color(0.35, 0.36, 0.38), fete)
		_boite(Vector3(0.9, 0.05, 0.6), Transform3D(Basis(Vector3.RIGHT, -0.4), Vector3(c.x, h + 4.75, c.y)), Color(0.1, 0.14, 0.3), fete, false, 0.2)   # panneau solaire
		_boite(Vector3(0.3, 0.12, 0.3), Transform3D(Basis(), Vector3(c.x, h + 4.5, c.y)), Color(0.95, 0.95, 0.9), fete)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.92, 0.78)
		l.light_energy = 0.0
		l.omni_range = 13.0
		fete.add_child(l)
		l.global_position = Vector3(c.x, h + 4.3, c.y)
		lampes.append([l, Vector3(c.x, h + 4.6, c.y)])
	# fanions aux couleurs des Racines entre les lampadaires de la place
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var couleurs := [Color(0.18, 0.42, 0.2), Color(0.91, 0.7, 0.23), Color(0.71, 0.33, 0.16)]
	var anneau := lampes.slice(0, mini(10, lampes.size()))
	for i in anneau.size():
		var a: Vector3 = anneau[i][1]
		var b: Vector3 = anneau[(i + 1) % anneau.size()][1]
		var nb := int(a.distance_to(b) / 0.7)
		for k in nb:
			var u := float(k) / nb
			var p := a.lerp(b, u) + Vector3(0, -0.9 * sin(u * PI), 0)
			var dir := (b - a).normalized()
			st.set_color(couleurs[k % 3])
			st.add_vertex(p)
			st.add_vertex(p + dir * 0.4)
			st.add_vertex(p + dir * 0.2 + Vector3(0, -0.45, 0))
	var fan := MeshInstance3D.new()
	fan.mesh = st.commit()
	var mf := StandardMaterial3D.new()
	mf.vertex_color_use_as_albedo = true
	mf.cull_mode = BaseMaterial3D.CULL_DISABLED
	fan.material_override = mf
	fete.add_child(fan)
	# Radio Racines au maquis, et les danseurs
	radio_maquis = AudioStreamPlayer3D.new()
	var musique: AudioStreamWAV = load("res://sons/radio_racines.wav")
	musique.loop_mode = AudioStreamWAV.LOOP_FORWARD
	musique.loop_end = int(musique.get_length() * musique.mix_rate)
	radio_maquis.stream = musique
	radio_maquis.unit_size = 14.0
	radio_maquis.max_distance = 140.0
	fete.add_child(radio_maquis)
	radio_maquis.global_position = maquis + Vector3(0, 2.0, 0)
	radio_maquis.play()
	var modeles := ["femme", "homme2", "fille", "villageois", "femme2", "garcon", "homme3", "femme_agee"]
	for i in 8:
		var a := TAU * i / 8.0
		var p := maquis + Vector3(cos(a) * 3.2, 0, sin(a) * 3.2) + Vector3(6, 0, 0)
		p.y = t.hauteur(p.x, p.z)
		var dn := vq._perso(modeles[i], "Repos", p, a + PI)
		dn.reparent(fete)
		danseurs.append([dn, p, randf() * TAU])
	# Baya Efua, attablée au maquis
	var pb := maquis + Vector3(-3.5, 0, 2.5)
	pb.y = t.hauteur(pb.x, pb.z)
	baya = vq._perso("baya", "Assis", pb, 0.5)
	vq._canne(baya)
	baya.reparent(fete)
	_boite(Vector3(1.2, 0.08, 0.8), Transform3D(Basis(), pb + Vector3(0.2, 0.75, 0.9)), Color(0.85, 0.85, 0.82), fete)
	for k in 3:
		_boite(Vector3(0.28, 0.06, 0.28), Transform3D(Basis(), pb + Vector3(-0.1 + k * 0.3, 0.82, 0.9)), [Color(0.95, 0.9, 0.7), Color(0.6, 0.3, 0.1), Color(0.9, 0.55, 0.2)][k], fete)
	# le marché plein : étals de manioc et de cacao de Bomé, poisson d'Akwéri
	for k in 6:
		var c := Vector2(marche.x, marche.z) + Vector2.from_angle(TAU * k / 6.0 + 0.3) * 13.0
		if not ville._rect_libre(c, Vector2(0, 1), 2.2, 1.4, 0.3):
			continue
		var h := t.hauteur(c.x, c.y)
		var o := Vector3(c.x, h, c.y)
		_boite(Vector3(2.0, 0.08, 1.2), Transform3D(Basis(), o + Vector3(0, 0.85, 0)), Color(0.55, 0.4, 0.25), fete)
		for dx in [-0.9, 0.9]:
			for dz in [-0.5, 0.5]:
				_boite(Vector3(0.07, 0.85, 0.07), Transform3D(Basis(), o + Vector3(dx, 0.42, dz)), Color(0.4, 0.3, 0.2), fete)
		var prod: Color = [Color(0.82, 0.7, 0.5), Color(0.85, 0.45, 0.12), Color(0.7, 0.72, 0.75)][k % 3]   # manioc, cacao, poisson
		for j in 6:
			_boite(Vector3(0.22, 0.14, 0.32), Transform3D(Basis(Vector3.UP, j * 0.7), o + Vector3(-0.6 + (j % 3) * 0.6, 0.95 + floorf(j / 3.0) * 0.12, -0.2 + floorf(j / 3.0) * 0.3)), prod, fete)
		var v := vq._perso(["femme", "femme2", "femme_agee"][k % 3], "Repos", o + Vector3(0, 0, -1.1), 0.0)
		v.reparent(fete)
	# les conteurs : chacun sa version de la libération, très exagérée
	var histoires := [
		["« Moi j'étais là ! Faris a sauté du clocher sur le pick-up de Mamba, en marche ! »", "« Bon… le pick-up était peut-être garé. Mais il a sauté ! »"],
		["« L'avion ? Il l'a fait tomber avec un caillou. Un seul caillou ! Je le jure sur la tête de ma belle-mère. »", "« Ma belle-mère est d'accord, d'ailleurs. Elle était là aussi. Enfin, presque. »"],
		["« À Tikané, il a traversé l'orage sans se mouiller. Les éclairs avaient peur de lui. »", "« Ce n'est pas moi qui le dis, c'est ma cousine. Elle était à Tikané. Enfin, elle connaît quelqu'un de Tikané. »"],
	]
	for i in histoires.size():
		var c := Vector2(place.x, place.z) + Vector2.from_angle(TAU * i / 3.0 + 1.0) * 10.0
		var o := Vector3(c.x, t.hauteur(c.x, c.y), c.y)
		var conteur := vq._perso(["ancien", "homme2", "femme"][i], "Repos", o, atan2(place.x - o.x, place.z - o.z))
		conteur.reparent(fete)
		conteurs.append([conteur, histoires[i], 0])
	# les pêcheurs déchargent au quai en chantant
	var quai := lieu_bac.origin + lieu_bac.basis.z * -16.0
	for k in 4:
		var p := quai + lieu_bac.basis.x * (-4.0 + k * 2.6)
		p.y = t.hauteur(p.x, p.z)
		if p.y < 0.3:
			continue
		var f := vq._perso(["villageois", "homme3", "homme2", "villageois"][k], "Reparer" if k % 2 == 0 else "Repos", p, randf() * TAU)
		f.reparent(fete)
		_boite(Vector3(0.6, 0.3, 0.4), Transform3D(Basis(), p + Vector3(0.6, 0.15, 0.3)), Color(0.55, 0.6, 0.65), fete)
	var chant := Label3D.new()
	chant.text = "« Hé lélé, la mer est à nous ! »"
	chant.font_size = 42
	chant.pixel_size = 0.01
	chant.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	chant.modulate = Color(1, 1, 0.9)
	fete.add_child(chant)
	chant.global_position = quai + Vector3(0, 3.4, 0)
	# Dossou, sans uniforme, qui répare les pirogues brûlées (s'il a été relâché à Akwéri)
	if m4.sort_dossou == "relache" or (m4.sort_dossou == "" and m4.dossou and m4.dossou.etat != Pnj.Etat.LIGOTE):
		var pd := quai + lieu_bac.basis.x * 9.0
		pd.y = maxf(t.hauteur(pd.x, pd.z), 0.4)
		var dossou := vq._perso("villageois", "Reparer", pd, 0.0)
		dossou.reparent(fete)
	# Petit Prince et son vélo neuf, qui livre pour la coopérative
	prince = Node3D.new()
	fete.add_child(prince)
	var gamin := vq._perso("garcon", "Moto", Vector3.ZERO, 0.0)
	gamin.reparent(prince)
	gamin.position = Vector3(0, 0.35, -0.1)
	gamin.rotation = Vector3.ZERO
	var noir := Color(0.08, 0.08, 0.08)
	for z in [-0.55, 0.55]:
		var roue := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.28
		tm.outer_radius = 0.34
		roue.mesh = tm
		var mr := StandardMaterial3D.new()
		mr.albedo_color = noir
		roue.material_override = mr
		prince.add_child(roue)
		roue.transform = Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, 0.34, z))
	_boite(Vector3(0.05, 0.05, 1.1), Transform3D(Basis(), Vector3.ZERO), Color(0.85, 0.15, 0.1), prince).position = Vector3(0, 0.62, 0)
	_boite(Vector3(0.35, 0.28, 0.3), Transform3D(Basis(), Vector3.ZERO), Color(0.55, 0.42, 0.25), prince).position = Vector3(0, 0.75, -0.55)   # caisse de livraison
	# le terrain de foot en latérite, ses buts, le ballon, les gamins
	var xf := lieu_terrain
	# la latérite épouse le sol : une grille qui suit le terrain, juste au-dessus
	var stt := SurfaceTool.new()
	stt.begin(Mesh.PRIMITIVE_TRIANGLES)
	stt.set_color(Color(0.64, 0.36, 0.22))
	var pas := 2.0
	for ix in 12:
		for iz in 20:
			var coins: Array = []
			for cc in [Vector2(ix, iz), Vector2(ix + 1, iz), Vector2(ix + 1, iz + 1), Vector2(ix, iz + 1)]:
				var lp := Vector3(-12.0 + cc.x * pas, 0, -20.0 + cc.y * pas)
				var gp := xf * lp
				gp.y = t.hauteur(gp.x, gp.z) + 0.14     # au-dessus du maillage du sol, sans scintillement
				coins.append(gp)
			for tri in [[0, 2, 1], [0, 3, 2]]:
				for v in tri:
					stt.add_vertex(coins[v])
	stt.generate_normals()
	var sol_foot := MeshInstance3D.new()
	sol_foot.mesh = stt.commit()
	var msf := StandardMaterial3D.new()
	msf.vertex_color_use_as_albedo = true
	msf.roughness = 0.97
	msf.cull_mode = BaseMaterial3D.CULL_DISABLED
	sol_foot.material_override = msf
	sol_foot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fete.add_child(sol_foot)
	for s in [-1.0, 1.0]:
		var bxf := xf.translated_local(Vector3(0, 0, s * 19.5))
		bxf.origin.y = t.hauteur(bxf.origin.x, bxf.origin.z)
		for x in [-1.8, 1.8]:
			_boite(Vector3(0.1, 2.0, 0.1), bxf.translated_local(Vector3(x, 1.0, 0)), Color(0.9, 0.9, 0.88), fete, true)
		_boite(Vector3(3.7, 0.1, 0.1), bxf.translated_local(Vector3(0, 2.0, 0)), Color(0.9, 0.9, 0.88), fete)
	ballon = RigidBody3D.new()
	ballon.mass = 0.43
	ballon.linear_damp = 0.6
	ballon.angular_damp = 0.8
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.55
	pm.friction = 0.6
	ballon.physics_material_override = pm
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.11
	cs.shape = sp
	ballon.add_child(cs)
	var bm := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.11
	sm.height = 0.22
	bm.mesh = sm
	var mb := StandardMaterial3D.new()
	mb.albedo_color = Color(0.95, 0.95, 0.95)
	bm.material_override = mb
	ballon.add_child(bm)
	fete.add_child(ballon)
	ballon.global_position = xf.origin + Vector3(0, 0.5, 0)
	for i in 4:
		var p := xf * Vector3(-6.0 + i * 4.0, 0, -4.0 + (i % 2) * 8.0)
		p.y = t.hauteur(p.x, p.z)
		var g := vq._perso(["garcon", "fille", "garcon", "garcon"][i], "Repos", p, 0.0)
		g.reparent(fete)
		gamins.append([g, i % 2])


func _vie(delta: float) -> void:
	var jp := joueur.global_position
	var temps := Time.get_ticks_msec() * 0.001
	# lampadaires : ils s'allument quand le jour baisse
	var amb: Ambiances = main.ambiances
	var nuit: float = amb.LISTE[amb.index]["nuit"]
	for l in lampes:
		(l[0] as OmniLight3D).light_energy = 2.2 * nuit
	# les danseurs se balancent sur le rythme de la radio (≈ 118 battements par minute)
	for d in danseurs:
		var n: Node3D = d[0]
		var p: Vector3 = d[1]
		var ph: float = d[2]
		n.global_position = p + Vector3(0, absf(sin(temps * 6.2 + ph)) * 0.08, 0)
		n.rotation.y += sin(temps * 1.3 + ph) * delta * 0.8
	# Petit Prince fait le tour de la place
	if prince:
		t_prince += delta
		var place: Vector3 = ville.reperes["place"]
		var a := t_prince * 0.16
		var p := place + Vector3(cos(a) * 17.0, 0, sin(a) * 17.0)
		p.y = (main.terrain as Terrain).hauteur(p.x, p.z)
		var p2 := place + Vector3(cos(a + 0.05) * 17.0, 0, sin(a + 0.05) * 17.0)
		prince.global_position = p
		prince.rotation.y = atan2(p2.x - p.x, p2.z - p.z)
		for r in prince.get_children():
			if r is MeshInstance3D and (r as MeshInstance3D).mesh is TorusMesh:
				(r as Node3D).rotate_object_local(Vector3.UP, delta * 9.0)
	# le match : deux gamins courent après le ballon et tirent vers le but adverse
	if ballon:
		var b := ballon.global_position
		var xf := lieu_terrain
		for g in gamins:
			var n: Node3D = g[0]
			var camp: int = g[1]
			var vers := b - n.global_position
			vers.y = 0.0
			var ap: AnimationPlayer = n.find_child("AnimationPlayer", true, false)
			if vers.length() > 0.7 and vers.length() < 30.0:
				var v := vers.normalized() * (3.2 if camp == 0 else 2.9)
				n.global_position += v * delta
				n.global_position.y = (main.terrain as Terrain).hauteur(n.global_position.x, n.global_position.z)
				n.rotation.y = atan2(v.x, v.z)
				if ap.current_animation != "Course":
					ap.play("Course")
			else:
				if ap.current_animation != "Repos":
					ap.play("Repos")
				if vers.length() <= 0.7:
					var but := xf * Vector3(0, 0, 19.5 if camp == 0 else -19.5)
					var tir := (but - b)
					tir.y = 0.0
					ballon.apply_central_impulse(tir.normalized() * 1.6 + Vector3(0, 0.4, 0))
		# un but ?
		var local := xf.affine_inverse() * b
		if absf(local.z) > 19.6 and absf(local.x) < 1.8 and local.y < 4.0:
			buts += 1
			var marque_joueur := jp.distance_to(b) < 9.0
			m4._annoncer("BUUUUT !" + (" Faris marque, les gamins hurlent de joie." if marque_joueur else " Les gamins dansent autour du terrain."), 3.0)
			if marque_joueur:
				_cocher("foot")
			ballon.linear_velocity = Vector3.ZERO
			ballon.global_position = xf.origin + Vector3(0, 0.6, 0)
		elif absf(local.x) > 14.0 or absf(local.z) > 23.0:
			ballon.linear_velocity = Vector3.ZERO
			ballon.global_position = xf.origin + Vector3(0, 0.6, 0)
	# la fresque se voit en passant
	if phase == Phase.FETE and not fait.has("fresque") and jp.distance_to(lieu_fresque.origin) < 9.0:
		_cocher("fresque")
		m4._annoncer("La fresque de la coopérative, repeinte. Samuel au centre, la houe levée vers le soleil. Et dans un coin, à la craie, un petit bonhomme : « FARIS ».", 7.0)


# ---------------------------------------------------------------------
# F : danser, manger, écouter, saluer
# ---------------------------------------------------------------------
func interagir() -> void:
	var jp := joueur.global_position
	if phase in [Phase.FETE, Phase.CIMETIERE, Phase.NUIT]:
		var maquis: Vector3 = ville.reperes["maquis"]
		if baya and jp.distance_to(baya.global_position) < 3.0:
			_cocher("repas")
			m4._annoncer("BAYA EFUA (elle pousse vers lui un bol d'attiéké et de poisson braisé) — « Mange. Ton père mangeait trop vite, lui aussi. » Un temps. « Il serait fier. Mais ne le lui dis pas, il deviendrait insupportable. »", 9.0)
			return
		if jp.distance_to(maquis + Vector3(6, 0, 0)) < 4.5:
			_cocher("danse")
			m4._annoncer("Faris se laisse entraîner au milieu des danseurs. Mama Rokia monte le son de Radio Racines. Il danse mal. Personne ne s'en soucie.", 6.0)
			return
		for c in conteurs:
			var n: Node3D = c[0]
			if jp.distance_to(n.global_position) < 3.0:
				var lignes: Array = c[1]
				m4._annoncer(str(lignes[int(c[2]) % lignes.size()]), 6.0)
				c[2] = int(c[2]) + 1
				var tous := true
				for d in conteurs:
					tous = tous and int(d[2]) > 0
				if tous:
					_cocher("histoires")
				return
		if prince and jp.distance_to(prince.global_position) < 4.0:
			_cocher("prince")
			m4._annoncer("PETIT PRINCE (il freine en dérapant) — « Nawé ! Tu as vu mon vélo ? La coopérative me paie pour les livraisons. Un jour, j'aurai une moto. Plus rapide que celle de Moto-Moto ! »", 7.0)
			return
		if phase == Phase.NUIT and jp.distance_to(lieu_bac.origin) < 14.0:
			return
	m4.interagir()


# ---------------------------------------------------------------------
# Le cimetière au coucher du soleil
# ---------------------------------------------------------------------
func _vers_cimetiere() -> void:
	phase = Phase.CIMETIERE
	var amb: Ambiances = main.ambiances
	var garde := 0
	while amb.index != 0 and garde < 8:   # heure dorée : le soleil descend
		amb.suivante()
		garde += 1
	m4._annoncer("Le soleil descend sur la mer. AMA (radio) — « Je t'attends là-haut, près de ton père. »", 5.0)
	var ca: Node = main.get_node_or_null("Carte")
	if ca:
		ca.poser_balise(tombe)


func _scene_cimetiere() -> void:
	t_escorte = 0.001
	var t := main.terrain as Terrain
	var pa := tombe + lieu_cimetiere.basis.x * 1.6
	pa.y = t.hauteur(pa.x, pa.z)
	var ama := vq._perso("femme", "Repos", pa, atan2(tombe.x - pa.x, tombe.z - pa.z))
	ama.reparent(self)
	# Mamba, s'il a été arrêté : escorté au loin vers une cellule de l'église
	if str(main.get_meta("mamba", "")) == "arrete":
		var eglise: Vector3 = ville.reperes["eglise"]
		var depart := eglise + (lieu_cimetiere.origin - eglise).normalized().rotated(Vector3.UP, 1.2) * 45.0
		for k in 3:
			var p := depart + Vector3(k * 1.2, 0, k * 0.8)
			p.y = t.hauteur(p.x, p.z)
			var e := vq._perso(["ancien", "villageois", "homme2"][k], "Marche", p, 0.0)
			e.reparent(self)
			escorte.append([e, eglise])
	t_escorte = 25.0
	var lignes := [
		["AMA", "Tu vas repartir ? À l'étranger ?"],
		["FARIS", "Mon père voulait aller jusqu'à la capitale. (Il sort le registre et les contrats.) Le chemin passe par Lagunaville."],
		["AMA", "Alors il te faut un bateau. (Un temps.) Et quelqu'un qui sait le conduire."],
	]
	if escorte.size() > 0:
		lignes.append(["", "Au loin, trois villageois armés escortent un homme aux poignets liés vers l'église. Mamba ne se retourne pas."])
	if m4.sort_dossou == "relache":
		lignes.append(["", "En bas, sur la plage, un homme sans uniforme recoud la coque d'une pirogue brûlée. Dossou."])
	for l in lignes:
		m4._annoncer(("%s — « %s »" % l) if l[0] != "" else str(l[1]), 6.5)
		await get_tree().create_timer(6.8).timeout
	phase = Phase.NUIT
	var amb: Ambiances = main.ambiances
	var garde := 0
	while amb.index != 3 and garde < 8:
		amb.suivante()
		garde += 1
	m4._annoncer("La nuit tombe. Pour la première fois depuis des mois, Port-Néré reste éclairée. Le bac attend au quai.", 6.0)
	var ca: Node = main.get_node_or_null("Carte")
	if ca:
		ca.poser_balise(lieu_bac.origin)


func _escorte(delta: float) -> void:
	t_escorte -= delta
	for e in escorte:
		var n: Node3D = e[0]
		var cible: Vector3 = e[1]
		var v := cible - n.global_position
		v.y = 0.0
		if v.length() > 3.0:
			n.global_position += v.normalized() * 1.3 * delta
			n.global_position.y = (main.terrain as Terrain).hauteur(n.global_position.x, n.global_position.z)
			n.rotation.y = atan2(v.x, v.z)
	if t_escorte <= 0.0:
		t_escorte = -1.0
		for e in escorte:
			(e[0] as Node3D).queue_free()
		escorte.clear()


# ---------------------------------------------------------------------
# Le bac, la voix inconnue, la carte et le bilan
# ---------------------------------------------------------------------
func _scene_bac() -> void:
	phase = Phase.BAC
	t_bac = 0.0
	joueur.visible = false
	joueur.set_physics_process(false)
	cam = Camera3D.new()
	cam.far = 4000.0
	add_child(cam)
	cam.global_position = bac.global_position + Vector3(9.0, 5.0, 16.0)
	cam.look_at(bac.global_position + Vector3(0, 1.5, 0))
	cam.make_current()
	m4._objectif("Le bac met le cap au nord, vers le continent.")
	m4._annoncer("Le bac reprend son service, pour la première fois depuis des mois. Le passeur est à la barre.", 6.0)
	await get_tree().create_timer(6.3).timeout
	m4._annoncer("PASSEUR — « L'île n'a pas oublié, mon fils. » (Il sourit.) « Maintenant, c'est le continent qui va apprendre à te connaître. »", 7.5)
	await get_tree().create_timer(8.0).timeout
	m4._annoncer("La radio de bord grésille. Une voix inconnue, calme, sur une fréquence cryptée :\n« Faris. Vous ne me connaissez pas. Mais j'ai lu les carnets de votre père, moi aussi. À Port-Wanzala, des gens attendent de savoir s'ils peuvent vous faire confiance. Rendez-vous à Lagunaville. »", 11.0)
	await get_tree().create_timer(11.5).timeout
	var tw := create_tween()
	tw.tween_property(voile, "color:a", 1.0, 1.5)
	await tw.finished
	_afficher_bilan()


func _bac_part(delta: float) -> void:
	t_bac += delta
	if t_bac < 4.0:
		return
	# le bac s'écarte du quai et met le cap au nord, vers le continent
	var v := minf((t_bac - 4.0) * 0.4, 4.0)
	bac.global_position += Vector3(0, 0, -1).rotated(Vector3.UP, 0.15) * v * delta
	bac.rotation.y = lerp_angle(bac.rotation.y, PI + 0.15, delta * 0.3)
	bac.position.y = 0.04 * sin(t_bac * 1.3)
	if cam:
		# la caméra suit le bac, de trois quarts arrière, avec Port-Néré éclairée derrière
		var cible := bac.global_position + Vector3(9.0, 5.0, 16.0)
		cam.global_position = cam.global_position.lerp(cible, 1.0 - exp(-0.6 * delta))
		cam.look_at(bac.global_position + Vector3(0, 1.5, 0))


func _afficher_bilan() -> void:
	phase = Phase.BILAN
	var tel: Node = main.get_node_or_null("Telephone")
	var villages := 2      # Akwéri (mission 4) et Port-Néré
	var m6: Node = main.get_node_or_null("Mission6")
	if m6 and m6.phase == Mission6.Phase.TERMINEE:
		villages += 1
	var m8: Node = main.get_node_or_null("Mission8")
	if m8 and m8.phase == Mission8.Phase.TERMINEE:
		villages += 1
	var total := m4.epargnes + m4.tues
	var etoiles := clampi(roundi(m4.confiance / 20.0), 0, 5)
	var nb_preuves := 0
	var nb_documents := 0
	if tel:
		for pr in tel.preuves:
			if str(pr[0]) in Mission2.DOCUMENTS:
				nb_documents += 1
			else:
				nb_preuves += 1
	var choix: Array = []
	var barrage := str(main.get_meta("m1_barrage", ""))
	if barrage != "":
		choix.append({"taire": "silence au barrage", "calme": "calme face à Dossou", "provoquer": "Dossou provoqué"}[barrage])
	choix.append("Dossou relâché" if m4.sort_dossou == "relache" else ("Dossou prisonnier" if m4.sort_dossou == "prisonnier" else "Dossou : —"))
	if main.has_meta("garcons_au_camp"):
		choix.append("familles de Tikané protégées")
	elif main.has_meta("tikane_a_reprendre"):
		choix.append("pick-up de Tikané poursuivi")
	if main.has_meta("temoin_ndoro"):
		choix.append("Ndoro témoin")
	elif main.has_meta("cle_casier"):
		choix.append("clé de casier de Ndoro")
	var mamba := str(main.get_meta("mamba", ""))
	if mamba != "":
		choix.append("Mamba arrêté" if mamba == "arrete" else "Mamba éliminé")
	bilan = {"villages": villages, "epargnes": m4.epargnes, "total": total, "confiance": m4.confiance,
			"preuves": nb_preuves, "choix": choix, "tyran": int(main.get_meta("nouveau_tyran", 0))}
	var t := ""
	t += "Villages libérés : %d / 4 (Akwéri, Bomé, Tikané, Port-Néré)\n" % villages
	t += "Ennemis épargnés : %d sur %d\n" % [m4.epargnes, total]
	t += "Civils protégés : aucun civil blessé\n"
	t += "Confiance de l'île : %s\n" % ("★".repeat(etoiles) + "☆".repeat(5 - etoiles))
	t += "Preuves réunies : %d / 9 (Cobra → Docks → ministère de l'Agriculture)\n" % mini(nb_preuves, 9)
	t += "Documents de Samuel retrouvés : %d / 5\n" % nb_documents
	t += "Choix majeurs : %s\n\n" % " · ".join(PackedStringArray(choix))
	t += "Ces valeurs se transmettent à l'acte 2 et pèseront sur la fin du jeu.\n\nACTE 2 — LAGUNAVILLE : en préparation."
	(ecran_fin.find_child("Bilan", true, false) as Label).text = t
	ecran_fin.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var tw := create_tween()
	tw.tween_property(voile, "color:a", 0.0, 1.0)
	main.set_meta("bilan_acte1", bilan)
	var sv: Node = main.get_node_or_null("Sauvegarde")
	if sv:
		phase = Phase.TERMINEE
		sv.sauver()


func _continuer() -> void:
	phase = Phase.TERMINEE
	ecran_fin.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# le bac revient à quai ; Faris reprend pied à Port-Néré, libre de parcourir l'île
	bac.global_transform = lieu_bac
	if cam:
		cam.queue_free()
		cam = null
	joueur.camera.make_current()
	joueur.visible = true
	joueur.set_physics_process(true)
	var place: Vector3 = ville.reperes["place"]
	joueur.ressusciter(place + Vector3(0, 0.6, 0))
	joueur.mission = m4
	m4._objectif("L'île est libre. Parcourez-la à votre guise. (Acte 2 : Lagunaville, en préparation.)")


## Après un chargement de partie : l'acte 1 est terminé, Port-Néré est libérée.
func restaurer_terminee(p_bilan: Dictionary) -> void:
	bilan = p_bilan
	main.set_meta("bilan_acte1", bilan)
	if phase == Phase.TERMINEE:
		return
	phase = Phase.TERMINEE
	(main.ambiances as Ambiances).ile_libre = true
	var co: Node = main.get_node_or_null("Controles")
	if co and co.has_method("liberer"):
		co.liberer()
	var pa: Node = main.get_node_or_null("Patrouilles")
	if pa and pa.has_method("liberer"):
		pa.liberer()
	affiche.visible = false
	(mur_fresque.material_override as StandardMaterial3D).albedo_color = Color(1, 1, 1)
	if fete == null:
		_installer_fete()
	m4._objectif("L'île est libre. Parcourez-la à votre guise. (Acte 2 : Lagunaville, en préparation.)")


func _plat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)

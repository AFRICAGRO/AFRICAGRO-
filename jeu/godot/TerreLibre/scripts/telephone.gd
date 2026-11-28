## Le téléphone de Faris (touche Tab).
## Applications : Missions (journal), Zala Money (solde, historique, achats), Preuves (ce que Faris a
## découvert contre le Cobra), Radio (Lagune FM, la voix du Cobra ; puis Radio Racines après la mission 7),
## Carte. Les notifications (revenus de la coopérative, preuves) s'affichent en haut à droite.
class_name Telephone
extends CanvasLayer

signal ouvert_change(ouvert: bool)

var main: Node
var joueur: Joueur
var argent := 0
var historique: Array = []      # [libellé, montant]
var preuves: Array = []         # [titre, texte]
var radio_racines := false
var ton_radio := ""
var ouvert := false
var ecran: Control
var contenu: VBoxContainer
var titre_app: Label
var notif: Label
var t_notif := 0.0
var musique: AudioStreamPlayer
var radio_allumee := false
var t_nouvelles := 0.0
var i_nouvelle := 0

const NOUVELLES_COBRA := [
	"Lagune FM — « Le Front du Cobra garantit l'ordre et le travail sur toute l'île. »",
	"Lagune FM — « Couvre-feu à 20 h. Tout contrevenant sera considéré comme un bandit. »",
	"Lagune FM — « Les prétendus « Racines » ne sont que des voleurs de poules. »",
]
const NOUVELLES_RACINES := [
	"Radio Racines — Akwéri pêche de nouveau pour ses propres enfants.",
	"Radio Racines — La coopérative de Bomé cherche des bras pour la récolte. Venez nombreux.",
	"Radio Racines — Message pour Tikané : tenez bon, on ne vous oublie pas.",
	"Radio Racines — Et maintenant, du zala-beat, pour tout le port !",
]


func preparer(p_main: Node) -> void:
	main = p_main
	joueur = main.joueur
	layer = 7
	notif = Label.new()
	notif.add_theme_font_size_override("font_size", 16)
	notif.add_theme_constant_override("outline_size", 6)
	notif.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	notif.add_theme_color_override("font_color", Color(0.75, 1.0, 0.7))
	notif.anchor_left = 1.0
	notif.anchor_right = 1.0
	notif.offset_left = -420
	notif.offset_right = -20
	notif.offset_top = 96
	notif.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	notif.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(notif)
	# le téléphone : coque sombre, écran
	ecran = PanelContainer.new()
	var coque := StyleBoxFlat.new()
	coque.bg_color = Color(0.07, 0.08, 0.1, 0.97)
	coque.border_color = Color(0.25, 0.27, 0.3)
	coque.set_border_width_all(6)
	coque.set_corner_radius_all(26)
	coque.set_content_margin_all(18)
	ecran.add_theme_stylebox_override("panel", coque)
	ecran.anchor_left = 1.0
	ecran.anchor_right = 1.0
	ecran.anchor_top = 0.5
	ecran.anchor_bottom = 0.5
	ecran.offset_left = -400
	ecran.offset_right = -40
	ecran.offset_top = -300
	ecran.offset_bottom = 300
	ecran.visible = false
	add_child(ecran)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	ecran.add_child(col)
	var barre := HBoxContainer.new()
	var marque := Label.new()
	marque.text = "Zalitel  ▂▄▆"
	marque.add_theme_font_size_override("font_size", 12)
	marque.add_theme_color_override("font_color", Color(0.7, 0.72, 0.75))
	marque.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barre.add_child(marque)
	var batt := Label.new()
	batt.text = "▮▮▮▯ 71 %"
	batt.add_theme_font_size_override("font_size", 12)
	batt.add_theme_color_override("font_color", Color(0.7, 0.72, 0.75))
	barre.add_child(batt)
	col.add_child(barre)
	titre_app = Label.new()
	titre_app.add_theme_font_size_override("font_size", 20)
	titre_app.add_theme_color_override("font_color", Color(1.0, 0.82, 0.45))
	col.add_child(titre_app)
	var defil := ScrollContainer.new()
	defil.size_flags_vertical = Control.SIZE_EXPAND_FILL
	defil.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(defil)
	contenu = VBoxContainer.new()
	contenu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contenu.add_theme_constant_override("separation", 8)
	defil.add_child(contenu)
	var accueil := Button.new()
	accueil.text = "Accueil"
	accueil.flat = true
	accueil.pressed.connect(_accueil)
	col.add_child(accueil)
	musique = AudioStreamPlayer.new()
	var s: AudioStreamWAV = load("res://sons/radio_racines.wav")
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_end = int(s.get_length() * s.mix_rate)
	musique.stream = s
	musique.volume_db = -9.0
	add_child(musique)


# ---------------------------------------------------------------------
# Économie, preuves, notifications (appelées par les missions)
# ---------------------------------------------------------------------
func crediter(montant: int, libelle: String) -> void:
	argent += montant
	historique.push_front([libelle, montant])
	notifier("Zala Money : %+d ZLM — %s" % [montant, libelle])


func debiter(montant: int, libelle: String) -> bool:
	if argent < montant:
		notifier("Zala Money : solde insuffisant (%d ZLM)." % argent)
		return false
	argent -= montant
	historique.push_front([libelle, -montant])
	return true


func ajouter_preuve(titre: String, texte: String) -> void:
	for p in preuves:
		if p[0] == titre:
			return
	preuves.append([titre, texte])
	notifier("Nouvelle preuve : %s (Tab → Preuves)" % titre)


func notifier(t: String) -> void:
	notif.text = "" + t
	t_notif = 5.0


# ---------------------------------------------------------------------
# Écrans
# ---------------------------------------------------------------------
func _vider() -> void:
	for c in contenu.get_children():
		c.queue_free()


func _texte(t: String, couleur := Color(0.9, 0.9, 0.88), taille := 15) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(300, 0)
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	contenu.add_child(l)
	return l


func _bouton(t: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(action)
	contenu.add_child(b)
	return b


func _accueil() -> void:
	_vider()
	titre_app.text = (main.ambiances as Ambiances).nom()
	_bouton("Missions", _missions)
	_bouton("Zala Money — %d ZLM" % argent, _zala)
	_bouton("Preuves (%d)" % preuves.size(), _preuves)
	_bouton("Radio", _radio)
	_bouton("Carte", func() -> void:
		basculer()
		var ca: Node = main.get_node_or_null("Carte")
		if ca:
			ca.ouverte = true
			ca.grande.visible = true
			ca.mini_carte.visible = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE)


func _missions() -> void:
	_vider()
	titre_app.text = "Missions"
	var m4: Node = main.get_node_or_null("Mission4")
	if m4:
		_texte(m4.objectif.text, Color(1.0, 0.85, 0.4))
	var liste := []
	for n in [["Mission1", "1 · Le Retour"], ["Mission2", "2 · La Veillée"], ["Mission3", "3 · Le Pêcheur"]]:
		var mp: Node = main.get_node_or_null(n[0])
		if mp:
			liste.append([n[1], mp.etat_texte()])
	if m4:
		liste.append(["4 · Première Étincelle", "Akwéri libéré" if m4.phase == Mission4.Phase.LIBERE else ("en cours" if m4.lancee else "à venir")])
	var m5: Node = main.get_node_or_null("Mission5")
	if m5:
		liste.append(["5 · Les Graines", ["à venir", "disponible", "en cours", "terminée — %d sacs sauvés" % m5.sacs_livres][m5.phase]])
	var m6: Node = main.get_node_or_null("Mission6")
	if m6:
		liste.append(["6 · Champs de Cendre", ["à venir", "disponible", "en cours", "en cours", "coopérative", "Bomé libéré"][m6.phase]])
	var m7: Node = main.get_node_or_null("Mission7")
	if m7:
		liste.append(["7 · La Voix de l'Île", m7.etat_texte()])
	var m8: Node = main.get_node_or_null("Mission8")
	if m8:
		liste.append(["8 · Nuit à Tikané", m8.etat_texte()])
	var m9: Node = main.get_node_or_null("Mission9")
	if m9:
		liste.append(["9 · Le Chenal", m9.etat_texte()])
	var m10: Node = main.get_node_or_null("Mission10")
	if m10:
		liste.append(["10 · L'Avion", m10.etat_texte()])
	var m11: Node = main.get_node_or_null("Mission11")
	if m11:
		liste.append(["11 · Le Serpent", m11.etat_texte()])
	var m12: Node = main.get_node_or_null("Mission12")
	if m12:
		liste.append(["12 · L'Aube", m12.etat_texte()])
	for l in liste:
		_texte("%s — %s" % l)


func _zala() -> void:
	_vider()
	titre_app.text = "Zala Money"
	_texte("Solde : %d ZLM" % argent, Color(0.7, 1.0, 0.65), 22)
	_texte("Acheter (livré par un gamin de Port-Néré, discrètement) :", Color(0.8, 0.8, 0.78), 13)
	_bouton("Munitions, 60 cartouches — 150 ZLM", func() -> void:
		if debiter(150, "Munitions"):
			joueur.reserve += 60
			notifier("Munitions reçues.")
		_zala())
	_bouton("Trousse de soins — 120 ZLM", func() -> void:
		if debiter(120, "Trousse de soins"):
			joueur.pv = 100.0
			notifier("Soigné.")
		_zala())
	_bouton("Don aux familles de Bomé — 500 ZLM", func() -> void:
		if debiter(500, "Don aux familles"):
			var m4: Node = main.get_node_or_null("Mission4")
			if m4:
				m4.confiance = clampi(m4.confiance + 3, 0, 100)
			notifier("Les familles de Bomé vous remercient. Confiance +3.")
		_zala())
	_texte("Historique :", Color(0.8, 0.8, 0.78), 13)
	if historique.is_empty():
		_texte("Aucune opération.", Color(0.6, 0.6, 0.6), 13)
	for h in historique.slice(0, 12):
		_texte("%+d ZLM  ·  %s" % [h[1], h[0]], Color(0.7, 1.0, 0.65) if h[1] > 0 else Color(1.0, 0.7, 0.6), 13)


func _preuves() -> void:
	_vider()
	titre_app.text = "Preuves"
	if preuves.is_empty():
		_texte("Rien encore. Ouvrez l'œil : registres, carnets, photos…", Color(0.6, 0.6, 0.6))
	for p in preuves:
		_texte(p[0], Color(1.0, 0.85, 0.5), 16)
		_texte(p[1], Color(0.85, 0.85, 0.82), 13)


func _radio() -> void:
	_vider()
	titre_app.text = "Radio"
	if radio_racines:
		_texte("Radio Racines — en direct du mont Talanké", Color(0.7, 1.0, 0.65), 16)
		_bouton("Couper" if radio_allumee else "Écouter (zala-beat, nouvelles des villages)", func() -> void:
			allumer_radio(not radio_allumee)
			_radio())
	else:
		_texte("Lagune FM — la voix du Cobra", Color(1.0, 0.6, 0.5), 16)
		for n in NOUVELLES_COBRA:
			_texte(n, Color(0.8, 0.78, 0.75), 13)
		_texte("Une autre voix manque à l'île… (mission 7)", Color(0.6, 0.6, 0.6), 13)


func allumer_radio(oui: bool) -> void:
	radio_allumee = oui and radio_racines
	if radio_allumee:
		musique.play()
		t_nouvelles = 8.0
	else:
		musique.stop()


func basculer() -> void:
	ouvert = not ouvert
	ecran.visible = ouvert
	if ouvert:
		_accueil()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	ouvert_change.emit(ouvert)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("telephone"):
		basculer()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if t_notif > 0.0:
		t_notif -= delta
		if t_notif <= 0.0:
			notif.text = ""
	# Radio Racines : les nouvelles passent entre les morceaux
	if radio_allumee:
		t_nouvelles -= delta
		if t_nouvelles <= 0.0:
			t_nouvelles = 25.0
			notifier(NOUVELLES_RACINES[i_nouvelle % NOUVELLES_RACINES.size()])
			i_nouvelle += 1

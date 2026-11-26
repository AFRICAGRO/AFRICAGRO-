## Carte de l'île (touche M) et mini-carte (coin bas droit).
## Fond : image satellite réelle de l'île, ombrée par le relief (ombrage précalculé, outils/carte_relief.py).
## Dessus : pistes de latérite, rues de Port-Néré, noms des lieux, barrages du Cobra (rouge, vert une fois levés),
## patrouilles en alerte, la moto, le cheval, les pirogues, et Faris (flèche dans la direction du regard).
## Clic gauche sur la grande carte : poser une balise (colonne lumineuse dans le monde, distance affichée) ;
## clic droit : l'enlever. La balise disparaît quand on l'atteint.
class_name Carte
extends CanvasLayer

const TAILLE_GRANDE := 680.0
const TAILLE_MINI := 210.0
const ZOOM_MINI := 5.0          # la mini-carte montre ~1 km autour de Faris
# partie du terrain montrée par la grande carte (l'île et ses îlots, en fraction du terrain)
const VUE_MIN := Vector2(0.104, 0.248)
const VUE_TAILLE := 0.70

var main: Node
var joueur: Joueur
var fond: Texture2D
var ombre: Texture2D
var lieux: Array = []           # [nom, Vector2 monde]
var grande: Control
var cadre_carte: Control        # zone de la grande carte (découpée : rien ne déborde)
var mini_carte: Control
var ouverte := false
var balise := Vector3.INF
var colonne: MeshInstance3D
var info: Label
var t_info := 0.0


func construire(p_main: Node, _terrain: Terrain, p_lieux: Array) -> void:
	main = p_main
	joueur = main.joueur
	lieux = p_lieux
	fond = load("res://data/talanke_satellite.jpg")
	ombre = load("res://data/carte_ombre.png")   # ombrage du relief précalculé (outils/carte_relief.py)
	layer = 5
	mini_carte = Control.new()
	mini_carte.size = Vector2(TAILLE_MINI, TAILLE_MINI)
	mini_carte.anchor_left = 1.0
	mini_carte.anchor_right = 1.0
	mini_carte.anchor_top = 1.0
	mini_carte.anchor_bottom = 1.0
	mini_carte.offset_left = -TAILLE_MINI - 18.0
	mini_carte.offset_right = -18.0
	mini_carte.offset_top = -TAILLE_MINI - 50.0
	mini_carte.offset_bottom = -50.0
	mini_carte.clip_contents = true
	mini_carte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mini_carte.draw.connect(_dessiner_mini)
	add_child(mini_carte)
	grande = Control.new()
	grande.set_anchors_preset(Control.PRESET_FULL_RECT)
	grande.visible = false
	grande.draw.connect(_dessiner_grande)
	add_child(grande)
	cadre_carte = Control.new()
	cadre_carte.clip_contents = true
	cadre_carte.draw.connect(_dessiner_cadre)
	cadre_carte.gui_input.connect(_clic_carte)
	grande.add_child(cadre_carte)
	info = Label.new()
	info.add_theme_font_size_override("font_size", 18)
	info.add_theme_constant_override("outline_size", 6)
	info.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	info.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
	info.anchor_left = 1.0
	info.anchor_right = 1.0
	info.offset_left = -320
	info.offset_right = -20
	info.offset_top = 52
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(info)
	# colonne de lumière de la balise, visible de loin
	colonne = MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 0.6
	cy.bottom_radius = 0.6
	cy.height = 120.0
	cy.radial_segments = 10
	cy.cap_top = false
	cy.cap_bottom = false
	colonne.mesh = cy
	var mc := StandardMaterial3D.new()
	mc.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mc.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mc.albedo_color = Color(1.0, 0.82, 0.25, 0.35)
	mc.cull_mode = BaseMaterial3D.CULL_DISABLED
	colonne.material_override = mc
	colonne.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	colonne.visible = false
	main.add_child(colonne)


# ---------------------------------------------------------------------
# Repères
# ---------------------------------------------------------------------
func _vers_carte(p: Vector2, origine: Vector2, echelle: float) -> Vector2:
	return origine + (p + Vector2.ONE * Terrain.TAILLE * 0.5) / Terrain.TAILLE * echelle


func _vers_monde(q: Vector2, origine: Vector2, echelle: float) -> Vector2:
	return (q - origine) / echelle * Terrain.TAILLE - Vector2.ONE * Terrain.TAILLE * 0.5


func _cadre_grande() -> Array:
	var vue := grande.size
	var s := minf(TAILLE_GRANDE, minf(vue.x, vue.y) - 80.0)
	return [(vue - Vector2(s, s)) * 0.5, s]


# ---------------------------------------------------------------------
# Dessin
# ---------------------------------------------------------------------
func _dessiner_grande() -> void:
	var cadre := _cadre_grande()
	var o: Vector2 = cadre[0]
	var s: float = cadre[1]
	grande.draw_rect(Rect2(Vector2.ZERO, grande.size), Color(0, 0, 0, 0.55))
	grande.draw_rect(Rect2(o - Vector2(6, 6), Vector2(s + 12, s + 12)), Color(0.12, 0.1, 0.08))
	var police := ThemeDB.fallback_font
	grande.draw_string(police, o + Vector2(0, -16), "ÎLE DE TALANKÉ — M : fermer · clic gauche : poser une balise · clic droit : l'enlever",
			HORIZONTAL_ALIGNMENT_LEFT, s, 15, Color(1, 1, 1, 0.9))



func _dessiner_cadre() -> void:
	var s := cadre_carte.size.x / VUE_TAILLE           # taille du terrain entier, à cette échelle
	_couches(cadre_carte, -VUE_MIN * s, s, 1.0)
	# échelle graphique (1 km) et nord
	var police := ThemeDB.fallback_font
	var km := s / Terrain.TAILLE * 1000.0
	var e0 := Vector2(14, cadre_carte.size.y - 18)
	cadre_carte.draw_line(e0, e0 + Vector2(km, 0), Color.WHITE, 3.0)
	cadre_carte.draw_string(police, e0 + Vector2(km + 8, 5), "1 km", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	cadre_carte.draw_string(police, Vector2(cadre_carte.size.x - 24, 26), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)


func _dessiner_mini() -> void:
	var s := TAILLE_MINI * ZOOM_MINI
	var j := Vector2(joueur.global_position.x, joueur.global_position.z)
	var centre := Vector2(TAILLE_MINI, TAILLE_MINI) * 0.5
	var o := centre - (j + Vector2.ONE * Terrain.TAILLE * 0.5) / Terrain.TAILLE * s
	mini_carte.draw_rect(Rect2(Vector2.ZERO, mini_carte.size), Color(0.1, 0.16, 0.22))
	_couches(mini_carte, o, s, 0.75)
	mini_carte.draw_rect(Rect2(Vector2.ZERO, mini_carte.size), Color(0, 0, 0, 0.9), false, 3.0)


func _couches(c: Control, o: Vector2, s: float, k: float) -> void:
	c.draw_texture_rect(fond, Rect2(o, Vector2(s, s)), false, Color(0.92, 0.92, 0.9))
	c.draw_texture_rect(ombre, Rect2(o, Vector2(s, s)), false)
	var e := s / Terrain.TAILLE          # pixels par mètre
	# rues de Port-Néré et des villages
	for v in [main.ville, main.bome, main.tikane]:
		if v == null:
			continue
		for r in v.rues:
			var pts: PackedVector2Array = r["pts"]
			var ligne_c := PackedVector2Array()
			for p in pts:
				ligne_c.append(_vers_carte(p, o, s))
			c.draw_polyline(ligne_c, Color(0.82, 0.8, 0.76), maxf(1.0, r["l"] * e * 0.8))
	# pistes de latérite
	for trace in main.reperes_routes:
		var ligne_c := PackedVector2Array()
		for i in range(0, (trace as PackedVector2Array).size(), 3):
			ligne_c.append(_vers_carte(trace[i], o, s))
		c.draw_polyline(ligne_c, Color(0.15, 0.06, 0.02, 0.8), maxf(2.0, 9.0 * e) + 2.0)
		c.draw_polyline(ligne_c, Color(0.86, 0.42, 0.18), maxf(2.0, 9.0 * e))
	var police := ThemeDB.fallback_font
	# lieux
	for l in lieux:
		var q := _vers_carte(l[1], o, s)
		c.draw_circle(q, 4.0 * k, Color(1, 1, 1))
		var taille := int(16 * k)
		var decal := Vector2(7, 5)
		# un voisin proche à l'est : le nom s'écrit à gauche du point (Akwéri / Bomé, par exemple)
		for l2 in lieux:
			var q2 := _vers_carte(l2[1], o, s)
			if l2 != l and q2.x > q.x and q2.x - q.x < 120.0 and absf(q2.y - q.y) < 18.0:
				decal = Vector2(-7.0 - police.get_string_size(l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x, 5)
		c.draw_string_outline(police, q + decal, l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, taille, 5, Color(0, 0, 0, 0.85))
		c.draw_string(police, q + decal, l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, taille, Color(1, 0.97, 0.9))
	# barrages du Cobra
	var co: Node = main.get_node_or_null("Controles")
	if co:
		for poste in co.postes:
			var pc: Vector3 = poste["centre"]
			var q := _vers_carte(Vector2(pc.x, pc.z), o, s)
			var col := Color(0.3, 0.85, 0.35) if poste["leve"] else (Color(1, 0.15, 0.1) if poste["alerte"] else Color(0.85, 0.2, 0.15))
			c.draw_rect(Rect2(q - Vector2(5, 5) * k, Vector2(10, 10) * k), col)
			c.draw_rect(Rect2(q - Vector2(5, 5) * k, Vector2(10, 10) * k), Color.BLACK, false, 1.5)
	# patrouilles : visibles seulement quand elles sont lancées à la poursuite de Faris
	var pa: Node = main.get_node_or_null("Patrouilles")
	if pa:
		for pk in pa.pickups:
			if pk["etat"] == "poursuite":
				var pp: Vector3 = (pk["noeud"] as Node3D).global_position
				var q := _vers_carte(Vector2(pp.x, pp.z), o, s)
				c.draw_circle(q, 6.0 * k, Color(1, 0.1, 0.05))
				c.draw_circle(q, 6.0 * k, Color.BLACK, false, 1.5)
	# montures et embarcations
	for nom in ["MotoFaris", "Cheval", "Pirogue0", "Pirogue1"]:
		var n: Node3D = main.get_node_or_null(nom)
		if n == null or n == joueur.a_cheval:
			continue
		var q := _vers_carte(Vector2(n.global_position.x, n.global_position.z), o, s)
		var col: Color = {"MotoFaris": Color(1, 0.3, 0.25), "Cheval": Color(0.85, 0.75, 0.6)}.get(nom, Color(0.4, 0.75, 1.0))
		c.draw_circle(q, 4.5 * k, Color.BLACK)
		c.draw_circle(q, 3.2 * k, col)
	# balise
	if balise != Vector3.INF:
		var qb := _vers_carte(Vector2(balise.x, balise.z), o, s)
		c.draw_circle(qb, 7.0 * k, Color(1.0, 0.82, 0.25), false, 3.0)
		c.draw_circle(qb, 2.5 * k, Color(1.0, 0.82, 0.25))
	# Faris : flèche dans la direction du regard
	var j := Vector2(joueur.global_position.x, joueur.global_position.z)
	var qj := _vers_carte(j, o, s)
	var lacet: float = joueur.lacet
	var av := Vector2(-sin(lacet), -cos(lacet))
	var cote := Vector2(-av.y, av.x)
	var fleche := PackedVector2Array([qj + av * 11.0 * k, qj - av * 6.0 * k + cote * 7.0 * k, qj - av * 3.0 * k, qj - av * 6.0 * k - cote * 7.0 * k])
	c.draw_colored_polygon(fleche, Color(1, 1, 1))
	c.draw_polyline(fleche + PackedVector2Array([fleche[0]]), Color.BLACK, 1.5)


# ---------------------------------------------------------------------
# Interaction
# ---------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("carte"):
		ouverte = not ouverte
		grande.visible = ouverte
		mini_carte.visible = not ouverte
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if ouverte else Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()


func _clic_carte(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	var s := cadre_carte.size.x / VUE_TAILLE
	var q: Vector2 = (event as InputEventMouseButton).position
	if event.button_index == MOUSE_BUTTON_LEFT:
		var m := _vers_monde(q, -VUE_MIN * s, s)
		poser_balise(Vector3(m.x, main.terrain.hauteur(m.x, m.y), m.y))
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		balise = Vector3.INF
		colonne.visible = false


func poser_balise(p: Vector3) -> void:
	balise = p
	colonne.global_position = p + Vector3(0, 60.0, 0)
	colonne.visible = true


func _process(_delta: float) -> void:
	if joueur == null:
		return
	if balise != Vector3.INF:
		var d := Vector2(balise.x - joueur.global_position.x, balise.z - joueur.global_position.z).length()
		if d < 12.0:
			balise = Vector3.INF
			colonne.visible = false
			info.text = "Balise atteinte."
			t_info = 3.0
		else:
			info.text = "Balise : %s" % (("%d m" % int(d)) if d < 1000.0 else ("%s km" % String.num(d / 1000.0, 1).replace(".", ",")))
	elif t_info > 0.0:
		t_info -= _delta
		if t_info <= 0.0:
			info.text = ""
	else:
		info.text = ""
	if ouverte:
		var cadre := _cadre_grande()
		cadre_carte.position = cadre[0]
		cadre_carte.size = Vector2(cadre[1], cadre[1])
		grande.queue_redraw()
		cadre_carte.queue_redraw()
	else:
		mini_carte.queue_redraw()

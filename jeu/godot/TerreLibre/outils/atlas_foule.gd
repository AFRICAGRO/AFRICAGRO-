## Outil (hors jeu) : photographie chaque habitant sous 8 angles, 8 images de marche + 1 au repos,
## et range le tout dans data/foule/atlas.png. Ces silhouettes servent à la foule lointaine (foule.gd).
## Lancer : godot --path . res://outils/atlas_foule.tscn (avec un affichage, même virtuel).
extends Node3D

const MODELES := ["homme2", "homme3", "villageois", "ancien", "femme", "femme2", "femme_agee", "pecheur",
	"garcon", "fille", "cultivateur"]
const TUILE := Vector2i(48, 96)
const SUR := 4  # suréchantillonnage : rendu 4 fois plus grand puis réduit (bords nets)
const COLONNES := 4  # blocs par ligne (un bloc = un modèle : 9 colonnes x 8 directions)


func _ready() -> void:
	var vp := SubViewport.new()
	vp.size = TUILE * SUR
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.75, 0.78)
	env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var soleil := DirectionalLight3D.new()
	soleil.rotation_degrees = Vector3(-40, 25, 0)
	soleil.light_energy = 1.0
	vp.add_child(soleil)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = 2.1
	cam.position = Vector3(0, 1.05, 6)
	vp.add_child(cam)
	cam.current = true
	var lignes := int(ceil(MODELES.size() / float(COLONNES)))
	var atlas := Image.create(COLONNES * 9 * TUILE.x, lignes * 8 * TUILE.y, false, Image.FORMAT_RGBA8)
	for mi in MODELES.size():
		var perso: Node3D = (load("res://personnages/%s.glb" % MODELES[mi]) as PackedScene).instantiate()
		Apparence.ameliorer(perso)
		vp.add_child(perso)
		var ap: AnimationPlayer = perso.find_child("AnimationPlayer", true, false)
		var duree := ap.get_animation("Marche").length
		for d in 8:
			perso.rotation.y = -d * PI / 4.0
			for f in 9:
				if f < 8:
					ap.play("Marche")
					ap.seek(duree * f / 8.0, true)
				else:
					ap.play("Repos")
					ap.seek(0.4, true)
				ap.advance(0.0)
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				var im := vp.get_texture().get_image()
				im.convert(Image.FORMAT_RGBA8)
				im.resize(TUILE.x, TUILE.y, Image.INTERPOLATE_LANCZOS)
				var x := ((mi % COLONNES) * 9 + f) * TUILE.x
				var y := ((mi / COLONNES) * 8 + d) * TUILE.y
				atlas.blit_rect(im, Rect2i(Vector2i.ZERO, TUILE), Vector2i(x, y))
		print("atlas : ", MODELES[mi], " (marche ", snappedf(duree, 0.01), " s)")
		perso.queue_free()
	DirAccess.make_dir_recursive_absolute("res://data/foule")
	atlas.save_png("res://data/foule/atlas.png")
	print("ATLAS OK ", atlas.get_size())
	get_tree().quit()

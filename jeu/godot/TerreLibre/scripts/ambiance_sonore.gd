## Ambiance sonore de l'île, réglée selon l'endroit où se trouve Faris et l'heure :
## vagues près de la mer, vent, cigales le jour et grillons la nuit, oiseaux en forêt, pluie,
## rumeur de la ville à Port-Néré, cris de mouettes près du rivage. Sons créés par programme
## (outils/sons_ambiance.py).
class_name AmbianceSonore
extends Node

var terrain: Terrain
var joueur: Node3D
var ville: VillePortNere
var bome: Node3D   # VillageBome, réglé par main.gd
var ambiances: Ambiances
var proche: VegetationProche
var oiseaux: Oiseaux
var pistes := {}     # nom -> AudioStreamPlayer
var cibles := {}     # nom -> volume visé (0..1)
var nuit := 0.0
var minuterie := 0.0
var mouette: AudioStreamPlayer3D
var prochain_cri := 4.0
var rng := RandomNumberGenerator.new()


func preparer(t: Terrain, j: Node3D, v: VillePortNere, a: Ambiances, p: VegetationProche, o: Oiseaux) -> void:
	terrain = t
	joueur = j
	ville = v
	ambiances = a
	proche = p
	oiseaux = o
	for nom in ["vagues", "vent", "cigales", "grillons", "oiseaux", "pluie", "ville", "village"]:
		var s: AudioStreamWAV = load("res://sons/%s.wav" % nom)
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(s.get_length() * s.mix_rate)
		var lecteur := AudioStreamPlayer.new()
		lecteur.stream = s
		lecteur.volume_db = -80.0
		add_child(lecteur)
		lecteur.play(rng.randf() * 10.0)
		pistes[nom] = lecteur
		cibles[nom] = 0.0
	mouette = AudioStreamPlayer3D.new()
	mouette.stream = load("res://sons/mouette.wav")
	mouette.unit_size = 25.0
	mouette.max_db = -2.0
	add_child(mouette)


func regler_nuit(f: float) -> void:
	nuit = f


func _process(delta: float) -> void:
	if joueur == null:
		return
	minuterie -= delta
	if minuterie <= 0.0:
		minuterie = 0.4
		_evaluer()
	for nom in pistes:
		var l: AudioStreamPlayer = pistes[nom]
		var v := db_to_linear(l.volume_db) if l.volume_db > -79.0 else 0.0
		v = move_toward(v, cibles[nom], delta * 0.5)
		l.volume_db = linear_to_db(maxf(v, 0.0001))
	# cris de mouettes près du rivage, en journée
	prochain_cri -= delta
	if prochain_cri <= 0.0:
		prochain_cri = rng.randf_range(3.0, 9.0)
		if cibles["vagues"] > 0.25 and nuit < 0.6 and oiseaux and oiseaux.visible:
			mouette.global_position = oiseaux.centre + Vector3(rng.randf_range(-30, 30), 20, rng.randf_range(-30, 30))
			mouette.pitch_scale = rng.randf_range(0.85, 1.2)
			mouette.play()


func _evaluer() -> void:
	var p := joueur.global_position
	# proximité de la mer : part des points voisins sous le niveau de l'eau
	var mer := 0.0
	for i in 16:
		var a := TAU * i / 16.0
		for d in [25.0, 60.0]:
			if terrain.hauteur(p.x + cos(a) * d, p.z + sin(a) * d) < 0.0:
				mer += 1.0 / 32.0
	# densité d'arbres autour
	var arbres := 0
	if proche:
		var c := Vector2i(floori(p.x / VegetationProche.CASE), floori(p.z / VegetationProche.CASE))
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				var k := c + Vector2i(dx, dz)
				if proche.arbres_par_case.has(k):
					arbres += proche.arbres_par_case[k].size()
	var foret := clampf(arbres / 25.0, 0.0, 1.0)
	var en_ville := 0.0
	if ville:
		en_ville = 1.0 - smoothstep(180.0, 450.0, Vector2(p.x, p.z).distance_to(ville.centre))
	var pluie: bool = ambiances != null and ambiances.LISTE[ambiances.index]["pluie"]
	var jour := 1.0 - smoothstep(0.4, 0.9, nuit)
	cibles["vagues"] = smoothstep(0.0, 0.45, mer) * 0.9
	cibles["vent"] = 0.25 + 0.35 * smoothstep(20.0, 120.0, p.y) + 0.15 * mer
	cibles["cigales"] = jour * (0.15 + 0.35 * foret) * (1.0 - en_ville * 0.8) * (0.3 if pluie else 1.0)
	cibles["grillons"] = (1.0 - jour) * (0.3 + 0.4 * foret) * (1.0 - en_ville * 0.5)
	cibles["oiseaux"] = jour * foret * 0.7 * (0.3 if pluie else 1.0)
	cibles["pluie"] = 0.8 if pluie else 0.0
	cibles["ville"] = en_ville * (0.7 if jour > 0.5 else 0.35)
	var au_village := 0.0
	if bome:
		au_village = 1.0 - smoothstep(90.0, 280.0, Vector2(p.x, p.z).distance_to(bome.centre))
	cibles["village"] = au_village * (0.6 if jour > 0.5 else 0.12)

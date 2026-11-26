## Ambiances lumineuses réalistes : ciels photographiés (HDRI Poly Haven, CC0) + soleil aligné sur le ciel.
## Touche N : passer à l'ambiance suivante (fondu de 3 secondes).
class_name Ambiances
extends Node

# rot : rotation du ciel (degrés) pour placer le soleil ; elev : hauteur du soleil dans la photo.
# Dans toutes ces photos le soleil est vers u = 0,6 : il apparaît en direction +Z, décalé de 3,4°.
const LISTE := [
	{"nom": "Heure dorée", "nuit": 0.35, "ciel": "doree", "rot": -90.0, "elev": 10.5, "energie_ciel": 0.55,
	 "soleil": Color(1.0, 0.72, 0.48), "energie": 1.6, "ambiant": Color(0.62, 0.55, 0.62), "a_energie": 0.55,
	 "brume": Color(0.86, 0.68, 0.62), "densite": 0.00035, "ombre": 1.0, "mer": 1.0, "secheresse": 0.0, "mouille": 0.0, "pluie": false},
	{"nom": "Midi, harmattan", "nuit": 0.0, "ciel": "midi", "rot": 20.0, "elev": 43.0, "energie_ciel": 0.8,
	 "soleil": Color(1.0, 0.95, 0.86), "energie": 1.45, "ambiant": Color(0.62, 0.66, 0.72), "a_energie": 0.6,
	 "brume": Color(0.84, 0.76, 0.62), "densite": 0.0011, "ombre": 1.0, "mer": 1.0, "secheresse": 1.0, "mouille": 0.0, "pluie": false},
	{"nom": "Saison des pluies", "nuit": 0.25, "ciel": "pluie", "rot": 0.0, "elev": 50.0, "energie_ciel": 0.75,
	 "soleil": Color(0.85, 0.9, 0.95), "energie": 0.35, "ambiant": Color(0.72, 0.76, 0.8), "a_energie": 0.75,
	 "brume": Color(0.6, 0.65, 0.68), "densite": 0.0024, "ombre": 0.25, "mer": 0.45, "secheresse": 0.0, "mouille": 1.0, "pluie": true},
	{"nom": "Nuit (île occupée)", "nuit": 1.0, "ciel": "nuit", "rot": -40.0, "elev": 17.0, "energie_ciel": 0.25,
	 "soleil": Color(0.55, 0.65, 0.95), "energie": 0.25, "ambiant": Color(0.2, 0.25, 0.4), "a_energie": 0.3,
	 "brume": Color(0.08, 0.1, 0.16), "densite": 0.0012, "ombre": 0.6, "mer": 0.25, "secheresse": 0.0, "mouille": 0.0, "pluie": false},
	{"nom": "Aube", "nuit": 0.3, "ciel": "aube", "rot": 87.0, "elev": 9.7, "energie_ciel": 0.65,
	 "soleil": Color(1.0, 0.8, 0.7), "energie": 1.1, "ambiant": Color(0.6, 0.62, 0.72), "a_energie": 0.55,
	 "brume": Color(0.8, 0.74, 0.76), "densite": 0.0014, "ombre": 0.8, "mer": 0.8, "secheresse": 0.0, "mouille": 0.0, "pluie": false},
]

var soleil: DirectionalLight3D
var env: Environment
var ciel: PanoramaSkyMaterial
var terrain_mat: ShaderMaterial
var pluie: CPUParticles3D
var index := 0
var courant := {}
var depart := {}
var t := 1.0
var ciel_change := true
var textures := {}
var mer_mat: ShaderMaterial
## Objets éclairés la nuit (réverbères, fenêtres) : ils reçoivent regler_nuit(0..1).
var eclairages: Array = []


func preparer(p_soleil: DirectionalLight3D, p_env: Environment, p_terrain_mat: ShaderMaterial, p_pluie: CPUParticles3D) -> void:
	soleil = p_soleil
	env = p_env
	ciel = PanoramaSkyMaterial.new()
	env.sky.sky_material = ciel
	terrain_mat = p_terrain_mat
	pluie = p_pluie
	for a in LISTE:
		textures[a["ciel"]] = load("res://data/ciels/%s.hdr" % a["ciel"])
	courant = LISTE[0].duplicate()
	_appliquer(courant, LISTE[0])


func nom() -> String:
	return LISTE[index]["nom"]


func suivante() -> void:
	index = (index + 1) % LISTE.size()
	depart = courant.duplicate()
	t = 0.0
	ciel_change = false
	pluie.emitting = LISTE[index]["pluie"]


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ambiance"):
		suivante()
	if t < 1.0:
		t = minf(1.0, t + delta / 3.0)
		var cible: Dictionary = LISTE[index]
		var k := smoothstep(0.0, 1.0, t)
		for cle in cible:
			if cle == "rot":
				continue
			var a = depart[cle]
			if a is Color or a is float:
				courant[cle] = lerp(a, cible[cle], k)
		# le ciel photographié change à mi-fondu, quand la brume est la plus forte
		if t >= 0.5 and not ciel_change:
			ciel_change = true
			courant["ciel"] = cible["ciel"]
			courant["rot"] = cible["rot"]
		_appliquer(courant, cible)


func _appliquer(a: Dictionary, _cible: Dictionary) -> void:
	ciel.panorama = textures[a["ciel"]]
	ciel.energy_multiplier = a["energie_ciel"]
	env.sky_rotation = Vector3(0, deg_to_rad(a["rot"]), 0)
	soleil.rotation_degrees = Vector3(-a["elev"], 3.4 + a["rot"], 0)
	soleil.light_color = a["soleil"]
	soleil.light_energy = a["energie"]
	soleil.shadow_opacity = a["ombre"]
	env.ambient_light_color = a["ambiant"]
	env.ambient_light_energy = a["a_energie"]
	env.fog_light_color = a["brume"]
	# brume renforcée pendant le fondu pour masquer le changement de ciel
	var voile := sin(t * PI) * 0.0025 if t < 1.0 else 0.0
	env.fog_density = a["densite"] + voile
	terrain_mat.set_shader_parameter("secheresse", a["secheresse"])
	terrain_mat.set_shader_parameter("mouille", a["mouille"])
	if mer_mat:
		mer_mat.set_shader_parameter("lumiere", a["mer"])
	for o in eclairages:
		o.regler_nuit(a["nuit"])

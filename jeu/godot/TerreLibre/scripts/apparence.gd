## Finitions des personnages appliquées au chargement :
## - peau : grain et pores (texture de détail répétée), reflet doux sur les contours (« rim »),
##   la teinte, les sourcils, les lèvres et les paumes étant peints dans le modèle (couleurs de sommets) ;
## - cheveux : petites boucles serrées (relief) au lieu d'une surface lisse.
## Les matériaux d'un même modèle sont partagés : le travail n'est fait qu'une fois par modèle.
class_name Apparence
extends RefCounted


static func ameliorer(racine: Node) -> void:
	for mi in racine.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for k in m.mesh.get_surface_count():
			var mat := m.mesh.surface_get_material(k) as StandardMaterial3D
			if mat == null or mat.has_meta("ameliore"):
				continue
			mat.set_meta("ameliore", true)
			match mat.resource_name:
				"Peau":
					mat.vertex_color_use_as_albedo = true
					mat.vertex_color_is_srgb = false  # la teinte exportée est déjà linéaire
					mat.albedo_texture = load("res://data/textures/peau_detail.jpg")
					mat.albedo_color = Color(1.7, 1.66, 1.62)  # compense la texture de grain (moyenne ~0,75 en linéaire)
					mat.normal_enabled = true
					mat.normal_texture = load("res://data/textures/peau_nor.jpg")
					mat.normal_scale = 0.45
					mat.uv1_scale = Vector3(16, 16, 1)
					mat.roughness = 0.62
					mat.metallic_specular = 0.32
					mat.rim_enabled = true
					mat.rim = 0.12
					mat.rim_tint = 0.65
				"Cheveux":
					if mat.albedo_texture == null: # pas les foulards
						mat.albedo_texture = load("res://data/textures/cheveux_detail.jpg")
						mat.normal_enabled = true
						mat.normal_texture = load("res://data/textures/cheveux_nor.jpg")
						mat.normal_scale = 0.9
						mat.uv1_scale = Vector3(30, 30, 1)
						mat.roughness = 0.8
						mat.metallic_specular = 0.3

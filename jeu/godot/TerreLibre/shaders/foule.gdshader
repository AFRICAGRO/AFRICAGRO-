// Foule lointaine : chaque passant est une carte toujours tournée vers la caméra, qui affiche la bonne
// silhouette (8 angles de vue) et la bonne image de marche, tirées de data/foule/atlas.png.
// Données par passant (INSTANCE_CUSTOM) : x = modèle, y = direction du regard (radians),
// z = phase de la marche, w = état (1 marche, 0 immobile, < 0 caché car remplacé par un vrai personnage).
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, skip_vertex_transform;

uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform float colonnes = 4.0;   // blocs de modèles par ligne
uniform float lignes = 3.0;
uniform float distance_max = 260.0;
uniform float cadence = 0.74;   // cycles de marche par seconde

varying float etat;
varying vec2 tuile;   // coin de la tuile dans l'atlas (en tuiles)
varying float loin;

void vertex() {
	vec3 origine = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 vers_cam = CAMERA_POSITION_WORLD - origine;
	loin = length(vers_cam);
	vers_cam.y = 0.0;
	vers_cam = normalize(vers_cam + vec3(0.0001, 0.0, 0.0));
	vec3 droite = vec3(vers_cam.z, 0.0, -vers_cam.x);
	vec3 monde = origine + droite * VERTEX.x + vec3(0.0, VERTEX.y, 0.0);
	VERTEX = (VIEW_MATRIX * vec4(monde, 1.0)).xyz;
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(vers_cam * 0.55 + vec3(0.0, 0.85, 0.0)), 0.0)).xyz);
	etat = INSTANCE_CUSTOM.w;
	// angle sous lequel la caméra voit le passant -> une des 8 vues
	float vue = atan(vers_cam.x, vers_cam.z) - INSTANCE_CUSTOM.y;
	float d = mod(round(vue / (PI * 0.25)), 8.0);
	float image = 8.0;
	if (etat > 0.5) {
		image = floor(fract(TIME * cadence + INSTANCE_CUSTOM.z) * 8.0);
	}
	float m = INSTANCE_CUSTOM.x;
	tuile = vec2(mod(m, colonnes) * 9.0 + image, floor(m / colonnes) * 8.0 + d);
}

void fragment() {
	if (etat < -0.5 || loin > distance_max) {
		discard;
	}
	vec2 taille = vec2(1.0 / (colonnes * 9.0), 1.0 / (lignes * 8.0));
	vec4 c = texture(atlas, (tuile + UV) * taille);
	if (c.a < 0.5) {
		discard;
	}
	ALBEDO = c.rgb * 1.15;
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
}

// Rivière de Tikané : eau sombre de forêt qui coule vers la mer.
// UV.x = travers du lit (0 à 1), UV.y = distance le long du cours (en mètres).
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;

uniform vec3 couleur_fond : source_color = vec3(0.1, 0.14, 0.11);
uniform vec3 couleur_bord : source_color = vec3(0.3, 0.27, 0.18);
uniform vec3 couleur_ciel : source_color = vec3(0.55, 0.62, 0.66);
uniform float vitesse = 0.6;

float bruit(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.5);
	float b = fract(sin(dot(i + vec2(1.0, 0.0), vec2(127.1, 311.7))) * 43758.5);
	float c = fract(sin(dot(i + vec2(0.0, 1.0), vec2(127.1, 311.7))) * 43758.5);
	float d = fract(sin(dot(i + vec2(1.0, 1.0), vec2(127.1, 311.7))) * 43758.5);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	float bord = abs(UV.x - 0.5) * 2.0;
	vec2 p = vec2(UV.x * 6.0, UV.y * 0.9 - TIME * vitesse);
	float n1 = bruit(p * 1.7);
	float n2 = bruit(p * 4.3 + vec2(3.1, -TIME * vitesse * 0.7));
	float dx = (bruit(p * 2.0 + vec2(0.05, 0.0)) - bruit(p * 2.0 - vec2(0.05, 0.0)));
	float dy = (bruit(p * 2.0 + vec2(0.0, 0.05)) - bruit(p * 2.0 - vec2(0.0, 0.05)));
	NORMAL_MAP = normalize(vec3(dx * 2.5 + (n2 - 0.5) * 0.4, dy * 2.5, 1.0)) * 0.5 + 0.5;
	ALBEDO = mix(couleur_fond, couleur_bord, smoothstep(0.55, 1.0, bord)) + vec3(0.02) * n1;
	// pas de reflets du ciel dans ce rendu : on les imite (Fresnel), l'eau ne paraît plus noire
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(ALBEDO, couleur_ciel, fres * 0.75 + 0.1);
	ROUGHNESS = 0.06;
	SPECULAR = 0.5;
	// bords fondus pour se mêler aux berges ; petites crêtes d'écume claire au courant
	float ecume = smoothstep(0.82, 0.95, n2) * (1.0 - bord) * 0.25;
	ALBEDO += vec3(ecume);
	ALPHA = (0.92 - 0.6 * smoothstep(0.75, 1.0, bord));
}

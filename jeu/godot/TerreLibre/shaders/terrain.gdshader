// Terrain réaliste de l'île de Talanké : 5 matières photographiées (Poly Haven, CC0)
// mélangées selon l'altitude, la pente et l'image satellite réelle.
// Au loin, l'image satellite prend le relais pour garder la cohérence de l'île.
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

uniform sampler2D satellite : source_color, filter_linear_mipmap;
uniform sampler2D sable_c : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sable_n : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D laterite_c : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D laterite_n : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D herbe_c : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D herbe_n : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D foret_c : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D foret_n : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D roche_c : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roche_n : hint_normal, filter_linear_mipmap, repeat_enable;

uniform float secheresse : hint_range(0.0, 1.0) = 0.0; // harmattan : herbe jaunie
uniform float mouille : hint_range(0.0, 1.0) = 0.0;    // pluie : sol sombre et brillant
uniform float distance_detail = 260.0;

varying vec3 monde;
varying float pente;

void vertex() {
	monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	pente = 1.0 - NORMAL.y;
}

// deux échelles mélangées pour casser la répétition des textures
vec3 couleur(sampler2D t, vec2 uv) {
	vec3 a = texture(t, uv).rgb;
	vec3 b = texture(t, uv * 0.23 + vec2(0.37, 0.71)).rgb;
	return mix(a, b, 0.35);
}

void fragment() {
	float h = monde.y;
	vec2 uv = monde.xz;
	vec3 sat = texture(satellite, UV).rgb;
	float vert_sat = clamp((sat.g - max(sat.r, sat.b)) * 6.0, 0.0, 1.0);
	float rouge_sat = clamp((sat.r - sat.g) * 4.0 - 0.1, 0.0, 1.0);

	// poids de chaque matière
	float w_sable = 1.0 - smoothstep(1.5, 4.5, h);
	float w_laterite = smoothstep(1.5, 4.0, h) * (0.25 + rouge_sat * 1.6) * (1.0 - smoothstep(30.0, 80.0, h) * 0.6);
	float w_herbe = smoothstep(3.0, 9.0, h) * (1.0 - vert_sat * 0.5);
	float w_foret = smoothstep(18.0, 45.0, h) * (0.4 + vert_sat * 1.2);
	float w_roche = smoothstep(0.55, 0.85, pente) * 3.0;
	float somme = w_sable + w_laterite + w_herbe + w_foret + w_roche + 0.0001;
	w_sable /= somme; w_laterite /= somme; w_herbe /= somme; w_foret /= somme; w_roche /= somme;

	vec3 herbe = couleur(herbe_c, uv / 5.0);
	herbe = mix(herbe, herbe * vec3(1.2, 1.05, 0.7), secheresse);
	vec3 col = couleur(sable_c, uv / 4.0) * w_sable
		+ couleur(laterite_c, uv / 4.5) * w_laterite
		+ herbe * w_herbe
		+ couleur(foret_c, uv / 6.0) * w_foret
		+ couleur(roche_c, uv / 8.0) * w_roche;
	vec3 nrm = texture(sable_n, uv / 4.0).rgb * w_sable
		+ texture(laterite_n, uv / 4.5).rgb * w_laterite
		+ texture(herbe_n, uv / 5.0).rgb * w_herbe
		+ texture(foret_n, uv / 6.0).rgb * w_foret
		+ texture(roche_n, uv / 8.0).rgb * w_roche;

	// au loin : couleurs de l'image satellite (cohérence et pas de répétition visible)
	float loin = smoothstep(distance_detail * 0.4, distance_detail, length(VERTEX));
	vec3 macro = sat * 1.15;
	col = mix(col * mix(vec3(1.0), sat * 2.0, 0.25), macro, loin * 0.75);

	col *= mix(1.0, 0.72, mouille);
	ALBEDO = col;
	NORMAL_MAP = mix(nrm, vec3(0.5, 0.5, 1.0), loin);
	NORMAL_MAP_DEPTH = 1.2;
	ROUGHNESS = mix(0.95, 0.65, mouille);
	SPECULAR = mix(0.2, 0.35, mouille);
}

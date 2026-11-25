// Mer : petites vagues, couleur selon la profondeur réelle (lagon turquoise sur le sable, bleu profond au large),
// écume qui roule vers la plage et se brise sur le sable. La profondeur vient de la carte du relief de l'île.
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;

uniform vec3 profonde : source_color = vec3(0.05, 0.27, 0.36);
uniform vec3 claire : source_color = vec3(0.20, 0.62, 0.62);
uniform vec3 lagon : source_color = vec3(0.45, 0.78, 0.7);
uniform float force_vagues = 0.18;
uniform float lumiere = 1.0; // baisse sous la pluie et la nuit
uniform sampler2D hauteurs : filter_linear, repeat_disable; // relief de l'île (mètres)
uniform float taille = 5383.0;
uniform bool relief_actif = false;

varying vec3 monde;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(w.x * 0.08 + TIME * 1.1) * force_vagues + cos(w.z * 0.07 + TIME * 0.9) * force_vagues;
	monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float bruit(vec2 p) {
	return sin(p.x * 1.7 + sin(p.y * 1.3)) * 0.5 + sin(p.y * 2.3 + sin(p.x * 0.9)) * 0.5;
}

void fragment() {
	vec3 w = monde;
	float ride = sin(w.x * 0.9 + TIME * 2.0) * cos(w.z * 0.8 - TIME * 1.6);
	NORMAL = normalize(NORMAL + vec3(ride * 0.05, 0.0, ride * 0.05));
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float prof = 30.0;
	if (relief_actif) {
		vec2 uv = w.xz / taille + 0.5;
		if (uv.x > 0.0 && uv.x < 1.0 && uv.y > 0.0 && uv.y < 1.0) {
			prof = max(0.0, -texture(hauteurs, uv).r);
		}
	}
	vec3 eau = mix(lagon, claire, smoothstep(0.3, 3.5, prof));
	eau = mix(eau, profonde, smoothstep(4.0, 18.0, prof));
	vec3 couleur = mix(eau, profonde, fresnel * 0.6);
	// écume : vagues qui avancent vers le rivage, plus serrées et plus blanches en eau peu profonde
	float n = bruit(w.xz * 0.35 + TIME * 0.15) * 0.6;
	float rouleaux = sin(prof * 3.2 - TIME * 1.7 + n * 2.0);
	float ecume = smoothstep(0.55, 0.95, rouleaux) * (1.0 - smoothstep(0.0, 2.2, prof));
	ecume += (1.0 - smoothstep(0.0, 0.35, prof)) * (0.65 + 0.35 * sin(TIME * 2.3 + n * 4.0)); // ligne d'écume sur le sable
	ecume *= 0.75 + 0.25 * bruit(w.xz * 2.1 - TIME * 0.4);
	ecume = clamp(ecume, 0.0, 1.0);
	ALBEDO = mix(couleur, vec3(0.92, 0.95, 0.95), ecume) * lumiere;
	ALPHA = mix(mix(0.55, 0.82, smoothstep(0.0, 2.5, prof)), 0.97, max(fresnel, ecume));
	ROUGHNESS = mix(0.1, 0.8, ecume);
	SPECULAR = mix(0.6, 0.2, ecume);
}

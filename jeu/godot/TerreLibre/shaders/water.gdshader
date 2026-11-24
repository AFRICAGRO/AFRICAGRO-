// Mer turquoise stylisée : petites vagues, transparence près du rivage, reflets du soleil.
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;

uniform vec3 profonde : source_color = vec3(0.07, 0.36, 0.42);
uniform vec3 claire : source_color = vec3(0.20, 0.62, 0.62);
uniform float force_vagues = 0.18;
uniform float lumiere = 1.0; // baisse sous la pluie et la nuit

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(w.x * 0.08 + TIME * 1.1) * force_vagues + cos(w.z * 0.07 + TIME * 0.9) * force_vagues;
}

void fragment() {
	vec3 w = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float ride = sin(w.x * 0.9 + TIME * 2.0) * cos(w.z * 0.8 - TIME * 1.6);
	NORMAL = normalize(NORMAL + vec3(ride * 0.05, 0.0, ride * 0.05));
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(claire, profonde, 0.55 + 0.45 * fresnel) * lumiere;
	ALPHA = mix(0.82, 0.96, fresnel);
	ROUGHNESS = 0.12;
	SPECULAR = 0.6;
}

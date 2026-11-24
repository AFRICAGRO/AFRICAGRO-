// Arbres « imposteurs » : photos de rendus d'arbres réels (Poly Haven, CC0) sur des plans croisés.
// Très léger pour la carte graphique, réaliste à moyenne et grande distance. Léger balancement au vent.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert;

uniform sampler2D image : source_color, filter_linear_mipmap;
uniform float vent = 0.06;

void vertex() {
	float hauteur = max(VERTEX.y, 0.0);
	vec3 base = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float phase = base.x * 0.05 + base.z * 0.07;
	VERTEX.x += sin(TIME * 1.3 + phase) * vent * hauteur * 0.08;
	VERTEX.z += cos(TIME * 1.1 + phase) * vent * hauteur * 0.06;
	// éclairage doux : normale orientée vers le haut, comme un feuillage
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.65));
}

void fragment() {
	vec4 c = texture(image, UV);
	ALBEDO = c.rgb * COLOR.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.45;
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
}

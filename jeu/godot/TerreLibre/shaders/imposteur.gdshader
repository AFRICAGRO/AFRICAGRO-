// Arbres « imposteurs » : photos de rendus d'arbres réels (Poly Haven, CC0) sur des plans croisés.
// Très léger pour la carte graphique, réaliste à moyenne et grande distance. Léger balancement au vent.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert;

uniform sampler2D image : source_color, filter_linear_mipmap;
uniform float vent = 0.06;
uniform float rayon_proche = 70.0; // en deçà, l'arbre 3D détaillé prend le relais (0 = jamais caché)

varying float cache;

void vertex() {
	float hauteur = max(VERTEX.y, 0.0);
	vec3 base = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float dc = distance(base, CAMERA_POSITION_WORLD);
	cache = rayon_proche > 0.0 ? 1.0 - smoothstep(rayon_proche - 6.0, rayon_proche, dc) : 0.0;
	float phase = base.x * 0.05 + base.z * 0.07;
	VERTEX.x += sin(TIME * 1.3 + phase) * vent * hauteur * 0.08;
	VERTEX.z += cos(TIME * 1.1 + phase) * vent * hauteur * 0.06;
	// éclairage doux : normale orientée vers le haut, comme un feuillage
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.65));
}

void fragment() {
	float trame = fract(dot(FRAGCOORD.xy, vec2(0.0671, 0.5833)) * 13.7);
	if (cache > trame) discard;
	vec4 c = texture(image, UV);
	ALBEDO = c.rgb * COLOR.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.45;
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
}

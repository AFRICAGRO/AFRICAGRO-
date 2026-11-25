// Feuillage proche (arbres 3D, buissons) : rameaux détourés, balancement au vent,
// lumière qui traverse les feuilles, et fondu avec les arbres « imposteurs » au-delà de rayon_proche.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert;

uniform sampler2D image : source_color, filter_linear_mipmap;
uniform float vent = 1.0;
uniform float rayon_proche = 70.0;  // au-delà, l'imposteur prend le relais (0 = toujours visible)
uniform float translucidite = 0.35;

varying float cache;

void vertex() {
	vec3 base = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float d = distance(base, CAMERA_POSITION_WORLD);
	cache = rayon_proche > 0.0 ? smoothstep(rayon_proche - 6.0, rayon_proche, d) : 0.0;
	float phase = base.x * 0.07 + base.z * 0.05;
	float poids = COLOR.a; // 0 au tronc, 1 au bout des branches
	float t = TIME * 1.4 + phase;
	VERTEX.x += (sin(t) * 0.06 + sin(t * 3.7 + VERTEX.y) * 0.025) * poids * vent;
	VERTEX.z += (cos(t * 0.9) * 0.05 + cos(t * 4.1 + VERTEX.x) * 0.025) * poids * vent;
	VERTEX.y += sin(t * 5.3 + VERTEX.x * 3.0) * 0.015 * poids * vent;
}

void fragment() {
	// fondu tramé (pas de transparence coûteuse)
	float trame = fract(dot(FRAGCOORD.xy, vec2(0.0671, 0.5833)) * 13.7);
	if (cache > trame) discard;
	vec4 c = texture(image, UV);
	ALBEDO = c.rgb * COLOR.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
	BACKLIGHT = c.rgb * translucidite;
}

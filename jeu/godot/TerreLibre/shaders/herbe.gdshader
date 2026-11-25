// Touffes d'herbe autour du joueur : vent, teinte par touffe, disparition douce au loin.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert;

uniform sampler2D image : source_color, filter_linear_mipmap;
uniform float distance_max = 42.0;

varying float cache;

void vertex() {
	vec3 base = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float d = distance(base, CAMERA_POSITION_WORLD);
	cache = smoothstep(distance_max * 0.7, distance_max, d);
	float h = clamp(VERTEX.y, 0.0, 2.0);
	float t = TIME * 1.8 + base.x * 0.21 + base.z * 0.17;
	VERTEX.x += sin(t) * 0.09 * h;
	VERTEX.z += cos(t * 0.8) * 0.07 * h;
	// herbe éclairée comme le sol sur lequel elle pousse
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	float trame = fract(dot(FRAGCOORD.xy, vec2(0.0671, 0.5833)) * 13.7);
	if (cache > trame) discard;
	vec4 c = texture(image, UV);
	ALBEDO = c.rgb * COLOR.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.45;
	ROUGHNESS = 0.9;
	SPECULAR = 0.15;
	BACKLIGHT = c.rgb * 0.25;
}

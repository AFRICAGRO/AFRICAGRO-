// Écorce des arbres proches : même fondu tramé que le feuillage.
shader_type spatial;

uniform sampler2D image : source_color, filter_linear_mipmap;
uniform sampler2D relief : hint_normal, filter_linear_mipmap;
uniform float rayon_proche = 70.0;
uniform vec3 teinte = vec3(1.0);

varying float cache;

void vertex() {
	vec3 base = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float d = distance(base, CAMERA_POSITION_WORLD);
	cache = rayon_proche > 0.0 ? smoothstep(rayon_proche - 6.0, rayon_proche, d) : 0.0;
}

void fragment() {
	float trame = fract(dot(FRAGCOORD.xy, vec2(0.0671, 0.5833)) * 13.7);
	if (cache > trame) discard;
	ALBEDO = texture(image, UV).rgb * teinte * COLOR.rgb;
	NORMAL_MAP = texture(relief, UV).rgb;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}

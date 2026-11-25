// Mouettes : battements d'ailes dans le shader (COLOR.r = position le long de l'aile, COLOR.g = côté).
// INSTANCE_CUSTOM.r = phase, INSTANCE_CUSTOM.g = amplitude du battement (0 = vol plané).
shader_type spatial;
render_mode cull_disabled;

void vertex() {
	float aile = COLOR.r;
	float phase = INSTANCE_CUSTOM.r * 6.2832 + TIME * 9.0;
	float amp = INSTANCE_CUSTOM.g;
	VERTEX.y += sin(phase) * amp * aile * 0.45 + aile * aile * 0.08;
}

void fragment() {
	// dessous blanc, dessus gris clair, bouts d'ailes noirs
	vec3 c = mix(vec3(0.93, 0.93, 0.92), vec3(0.62, 0.65, 0.68), step(0.5, COLOR.b));
	c = mix(c, vec3(0.08), smoothstep(0.82, 0.9, COLOR.r));
	ALBEDO = c;
	ROUGHNESS = 0.8;
}

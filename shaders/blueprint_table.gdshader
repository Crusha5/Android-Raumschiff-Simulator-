shader_type spatial;
render_mode unshaded, cull_disabled;
// Leuchtendes Konstruktionsraster auf dem Blaupausen-Tisch

void fragment() {
	vec2 uv = UV * 20.0;
	vec2 g = abs(fract(uv) - 0.5);
	float line = smoothstep(0.47, 0.5, max(g.x, g.y));
	vec2 g2 = abs(fract(UV * 4.0) - 0.5);
	float major = smoothstep(0.485, 0.5, max(g2.x, g2.y));
	float scan = 0.5 + 0.5 * sin(UV.x * 30.0 - TIME * 3.0);
	vec3 base = vec3(0.03, 0.12, 0.24);
	vec3 ink = vec3(0.45, 0.75, 1.0);
	ALBEDO = base + ink * (line * 0.45 + major * 0.8) + ink * 0.04 * scan;
	EMISSION = ALBEDO * 1.6;
}

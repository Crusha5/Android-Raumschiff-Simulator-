shader_type spatial;
// Triebwerksstrahl: additiv, wird vom Glow aufgeblüht.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 flame_color : source_color = vec3(0.56, 0.78, 1.0);
uniform float power = 0.0;

varying float t;

void vertex() {
	t = clamp(VERTEX.z, 0.0, 1.0);
}

void fragment() {
	float flick = 0.85 + 0.15 * sin(TIME * 63.0 + t * 30.0) * sin(TIME * 23.0);
	float fres = pow(clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 1.5);
	float core = pow(1.0 - t, 2.5);
	float shock = 0.5 + 0.5 * sin(t * 40.0 - TIME * 8.0);
	vec3 c = mix(flame_color, vec3(1.0), core * 0.75);
	ALBEDO = c * (0.35 + core * 2.6 + shock * 0.25 * (1.0 - t)) * fres * (1.0 - t) * power * flick * 2.2;
}

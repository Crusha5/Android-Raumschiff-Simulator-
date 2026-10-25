shader_type spatial;
// Schildblase: leuchtet bei Treffern auf.
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform vec3 col : source_color = vec3(0.4, 0.7, 1.0);
uniform float hit = 0.0;
uniform vec3 hit_dir = vec3(0.0, 0.0, -1.0);

varying vec3 onrm;
void vertex() { onrm = normalize(VERTEX); }

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	float spot = pow(max(dot(onrm, normalize(hit_dir)), 0.0), 6.0);
	float hexes = 0.6 + 0.4 * step(0.5, fract(onrm.x * 9.0 + floor(onrm.y * 9.0) * 0.5));
	ALBEDO = col * (rim * 0.6 + spot * 2.2 * hexes) * hit;
}

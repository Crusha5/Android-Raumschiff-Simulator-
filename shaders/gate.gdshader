shader_type spatial;
// Wirbelnde Sprungtor-Fläche.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
#include "res://shaders/common.gdshaderinc"

uniform vec3 col_a : source_color = vec3(0.3, 0.6, 1.0);
uniform vec3 col_b : source_color = vec3(0.8, 0.4, 1.0);
uniform float power = 1.0;

varying vec2 p;
void vertex() { p = VERTEX.xy; }

void fragment() {
	float r = length(p);
	float a = atan(p.y, p.x);
	float sw = fbm4(vec3(cos(a) * 2.0, sin(a) * 2.0, r * 4.0 - TIME * 0.8) + vec3(0.0, 0.0, a * 0.5 + r * 3.0 - TIME * 0.3));
	float edge = smoothstep(1.0, 0.75, r);
	float core = smoothstep(0.6, 0.0, r);
	vec3 c = mix(col_a, col_b, sw);
	ALBEDO = c * (sw * 0.9 + core * 0.35) * edge * power * 0.8;
}

shader_type spatial;
// Explosionsfeuerball: wächst, kühlt ab, verblasst.
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;
#include "res://shaders/common.gdshaderinc"

uniform float age = 0.0; // 0..1
uniform vec3 hot : source_color = vec3(1.0, 0.85, 0.5);
uniform vec3 cool : source_color = vec3(1.0, 0.35, 0.1);

varying vec3 onrm;
void vertex() { onrm = normalize(VERTEX); }

void fragment() {
	float n = fbm4(onrm * 3.0 + vec3(age * 3.0));
	float fres = pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.5);
	vec3 c = mix(hot, cool, clamp(age * 1.6 + n * 0.4, 0.0, 1.0));
	float a = (1.0 - age) * (1.0 - age);
	ALBEDO = c * fres * (0.6 + n) * a * 4.0;
}

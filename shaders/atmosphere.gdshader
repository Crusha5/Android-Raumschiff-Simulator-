shader_type spatial;
// Atmosphärensaum um den Planeten.
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform vec3 atmo : source_color = vec3(0.35, 0.65, 1.0);
uniform vec3 sun_dir = vec3(0.8, 0.3, 0.5);
uniform float strength = 1.6;

varying vec3 wn;

void vertex() {
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float lit = smoothstep(-0.35, 0.6, dot(wn, normalize(sun_dir)));
	ALBEDO = atmo * pow(rim, 3.0) * strength * lit;
}

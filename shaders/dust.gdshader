shader_type spatial;
// Raumstaub, der beim Fliegen als Streifen an der Kamera vorbeizieht.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, skip_vertex_transform, fog_disabled;

uniform vec3 cam_pos;
uniform vec3 vel;
uniform float box = 260.0;
uniform float streak = 0.05;
uniform float width = 0.07;
uniform float bright = 1.0;

varying float fade;

void vertex() {
	vec3 head = mod(VERTEX - cam_pos, box) - box * 0.5 + cam_pos;
	vec3 tail = head - vel * streak;
	vec3 hv = (VIEW_MATRIX * vec4(head, 1.0)).xyz;
	vec3 tv = (VIEW_MATRIX * vec4(tail, 1.0)).xyz;
	vec3 dir = tv - hv;
	if (length(dir) < 0.001) dir = vec3(0.0, 0.001, 0.0);
	vec3 side = normalize(cross(normalize(dir), normalize(hv)));
	vec3 p = mix(hv, tv, UV.x) + side * width * UV.y;
	VERTEX = p;
	fade = (1.0 - smoothstep(box * 0.25, box * 0.5, length(hv))) * (1.0 - UV.x);
}

void fragment() {
	ALBEDO = vec3(0.75, 0.82, 1.0) * fade * bright;
}

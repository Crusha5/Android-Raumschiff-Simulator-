shader_type spatial;
// Hangarboden mit Leuchtringen und Raster.
uniform vec3 base : source_color = vec3(0.16, 0.18, 0.22);
uniform vec3 glow_col : source_color = vec3(1.0, 0.71, 0.28);
uniform vec3 grid_col : source_color = vec3(0.62, 0.83, 1.0);
uniform float radius = 30.0;

varying vec3 opos;
void vertex() { opos = VERTEX; }

void fragment() {
	float r = length(opos.xz) / radius;
	vec2 g = abs(fract(opos.xz * 0.5) - 0.5);
	vec2 fw = fwidth(opos.xz * 0.5) + 1e-4;
	float gl = max(smoothstep(0.5 - fw.x * 1.5, 0.5, g.x), smoothstep(0.5 - fw.y * 1.5, 0.5, g.y));
	float ring1 = 1.0 - smoothstep(0.0, 0.006 + fwidth(r), abs(r - 0.62));
	float ring2 = (1.0 - smoothstep(0.0, 0.012 + fwidth(r), abs(r - 0.7))) * step(0.5, fract(atan(opos.z, opos.x) * 12.0 / 6.2831));
	float ring3 = 1.0 - smoothstep(0.0, 0.004 + fwidth(r), abs(r - 0.38));
	ALBEDO = base * (1.0 - gl * 0.4);
	METALLIC = 0.3;
	ROUGHNESS = 0.35 + gl * 0.3;
	EMISSION = glow_col * (ring1 * 2.5 + ring2 * 1.2) + grid_col * (ring3 * 0.8 + gl * 0.03);
	float edge = smoothstep(0.85, 1.0, r);
	ALBEDO *= 1.0 - edge;
	EMISSION *= 1.0 - edge;
}

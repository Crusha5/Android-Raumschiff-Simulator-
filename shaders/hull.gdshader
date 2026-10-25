shader_type spatial;
// Rumpf-Lack mit Paneelfugen, Nieten, leichter Abnutzung und Lackmustern im Objektraum.
#include "res://shaders/common.gdshaderinc"

uniform vec3 hull_color : source_color = vec3(0.79, 0.76, 0.70);
uniform vec3 accent_color : source_color = vec3(1.0, 0.71, 0.28);
uniform int pattern = 1; // 0 uni, 1 Bauchbinde, 2 Rennstreifen, 3 Zweiton, 4 Warnmuster, 5 Tarn, 6 Rippen
uniform vec3 half_ext = vec3(2.5, 1.3, 5.5);
uniform float panel_scale = 1.1;
uniform float metal = 0.4;
uniform float rough = 0.48;
uniform float wear = 1.0;

varying vec3 opos;
varying vec3 onrm;

void vertex() {
	opos = VERTEX;
	onrm = NORMAL;
}

float grid(vec2 uv, float w) {
	vec2 g = abs(fract(uv) - 0.5);
	vec2 fw = fwidth(uv) * 1.2 + 1e-4;
	vec2 e = smoothstep(vec2(0.5) - w - fw, vec2(0.5) - w, g);
	return max(e.x, e.y);
}

void fragment() {
	vec3 an = abs(onrm);
	vec2 uv;
	if (an.x > an.y && an.x > an.z) uv = opos.zy;
	else if (an.y > an.z) uv = opos.xz;
	else uv = opos.xy;
	uv *= panel_scale;
	uv.x += floor(uv.y) * 0.37; // versetzte Paneele
	float seam = grid(uv * vec2(0.5, 1.0), 0.008);
	vec2 rv = fract(uv * vec2(0.5, 1.0) * vec2(4.0, 1.0)) - 0.5;
	float rivet = (1.0 - smoothstep(0.04, 0.07, length(vec2(rv.x * 0.5, rv.y - 0.42)))) * 0.6;

	vec3 q = opos / half_ext;
	float m = 0.0;
	vec3 col2 = accent_color;
	if (pattern == 1) {
		m = step(abs(q.y - 0.05), 0.22) * step(0.5, an.x + an.z * 0.8) * step(q.z, 0.85);
	} else if (pattern == 2) {
		float top = step(0.5, onrm.y) * step(abs(abs(q.x) - 0.2), 0.07);
		float side = step(0.5, an.x) * step(abs(q.y - 0.55), 0.06);
		m = max(top, side);
	} else if (pattern == 3) {
		m = step(q.y, -0.05);
	} else if (pattern == 4) {
		float zone = step(q.y, -0.35);
		float stripe = step(0.5, fract((opos.x + opos.y + opos.z) * 0.55));
		m = zone;
		col2 = mix(vec3(0.07, 0.07, 0.08), accent_color, stripe);
	} else if (pattern == 5) {
		float n = vnoise(floor(opos * 0.9 + 0.5) * 0.37 + opos * 0.12);
		float n2 = vnoise(opos * 0.35 + 7.0);
		m = step(0.62, n2);
		col2 = mix(accent_color, hull_color * 0.55, step(0.5, n));
	} else if (pattern == 6) {
		float rib = smoothstep(0.35, 0.5, abs(fract(opos.z * 1.6) - 0.5));
		seam = max(seam * 0.3, rib * 0.6);
	}
	vec3 base = mix(hull_color, col2, m);
	float dirt = fbm4(opos * 0.7) ;
	base *= mix(1.0, 0.82 + dirt * 0.3, wear);
	base *= 1.0 - seam * 0.38 - rivet * 0.12;
	ALBEDO = base;
	METALLIC = metal;
	ROUGHNESS = clamp(rough + seam * 0.25 + (dirt - 0.5) * 0.2 * wear, 0.05, 1.0);
}

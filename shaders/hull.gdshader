shader_type spatial;
// Rumpf-Lack mit echten Detailtexturen (Platten, Fugen, Nieten, Luken), Abnutzung und Lackmustern im Objektraum.
#include "res://shaders/common.gdshaderinc"
#include "res://shaders/detail.gdshaderinc"

uniform vec3 hull_color : source_color = vec3(0.79, 0.76, 0.70);
uniform vec3 accent_color : source_color = vec3(1.0, 0.71, 0.28);
uniform int pattern = 1; // 0 uni, 1 Bauchbinde, 2 Rennstreifen, 3 Zweiton, 4 Warnmuster, 5 Tarn, 6 Rippen
uniform vec3 half_ext = vec3(2.5, 1.3, 5.5);
uniform float panel_scale = 1.1;
uniform float metal = 0.4;
uniform float rough = 0.48;
uniform float wear = 1.0;
uniform float det_strength = 1.0;
uniform float micro = 1.0;
uniform sampler2D det_n : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D det_m : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mic_n : filter_linear_mipmap_anisotropic, repeat_enable;

varying vec3 opos;
varying vec3 onrm;

void vertex() {
	opos = VERTEX;
	onrm = NORMAL;
}

void fragment() {
	vec3 an = abs(onrm);
	vec3 T;
	vec3 B;
	vec2 uv = det_uv(opos, onrm, T, B) * panel_scale * 0.36;
	uv.x += floor(uv.y) * 0.37;
	vec4 mk = texture(det_m, uv);
	float sf = 0.0;
	if (pattern == 6) sf = 1.0;
	vec3 pn = det_normal(det_n, uv, normalize(onrm), T, B, det_strength * (1.0 - sf * 0.7));
	if (micro > 0.0) {
		vec3 m2 = texture(mic_n, uv * 5.0).rgb * 2.0 - 1.0;
		pn = normalize(pn + (T * m2.x - B * m2.y) * 0.35 * micro);
	}

	vec3 q = opos / half_ext;
	float m = 0.0;
	vec3 col2 = accent_color;
	float seam = 1.0 - mk.r;
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
		pn = normalize(pn + vec3(0.0, 0.0, 1.0) * (rib - 0.5) * 0.3 * an.x);
		seam = max(seam * 0.3, rib * 0.5);
	}
	vec3 base = mix(hull_color, col2, m);
	float dirt = fbm4(opos * 0.7);
	base *= 1.0 + (mk.a - 0.5) * 0.45;
	base *= mix(1.0, 0.8 + dirt * 0.32, wear);
	// Schmutz sammelt sich in Fugen, Kanten sind abgerieben
	base *= mix(1.0, mk.r, 0.55);
	float chip = mk.b * wear * smoothstep(0.45, 0.75, dirt + mk.a * 0.3);
	base = mix(base, vec3(0.55, 0.56, 0.58), chip * 0.55);
	ALBEDO = base;
	METALLIC = mix(metal, 0.85, chip);
	ROUGHNESS = clamp(rough + (mk.g - 0.5) * 0.7 + (dirt - 0.5) * 0.2 * wear - chip * 0.2, 0.05, 1.0);
	AO = mk.r;
	AO_LIGHT_AFFECT = 0.35;
	NORMAL = normalize((VIEW_MATRIX * (MODEL_MATRIX * vec4(pn, 0.0))).xyz);
}

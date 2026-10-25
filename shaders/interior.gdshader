shader_type spatial;
// Innenraum-Oberflächen: Wände mit senkrechten Paneelen, Sockel und Lichtband; Bodenfliesen; Deckenpaneele.
#include "res://shaders/common.gdshaderinc"

uniform vec3 wall_col : source_color = vec3(0.62, 0.64, 0.68);
uniform vec3 trim_col : source_color = vec3(0.16, 0.17, 0.2);
uniform vec3 floor_col : source_color = vec3(0.2, 0.21, 0.24);
uniform vec3 ceil_col : source_color = vec3(0.3, 0.31, 0.34);
uniform vec3 accent : source_color = vec3(0.25, 0.66, 1.0);
uniform float glow = 1.0;
uniform float panel = 1.6;
uniform float tile = 1.5;
uniform float band_y = 2.65;

varying vec3 wpos;
varying vec3 wn;

void vertex() {
	wpos = VERTEX;
	wn = NORMAL;
}

float seam_line(float x, float w) {
	float f = abs(fract(x) - 0.5);
	float fw = fwidth(x) + 1e-4;
	return smoothstep(0.5 - w - fw, 0.5 - w + fw * 0.5, f);
}

void fragment() {
	vec3 n = normalize(wn);
	vec3 c;
	float rough = 0.5;
	float metal = 0.1;
	vec3 em = vec3(0.0);
	if (n.y > 0.7) {
		vec2 uv = wpos.xz / tile;
		float s = max(seam_line(uv.x, 0.012), seam_line(uv.y, 0.012));
		float rnd = h31(vec3(floor(uv), 3.0));
		float inner = max(seam_line(uv.x * 2.0, 0.006), seam_line(uv.y * 2.0, 0.006)) * step(0.7, rnd);
		c = floor_col * (0.82 + rnd * 0.28) * (1.0 - s * 0.55 - inner * 0.2);
		rough = 0.16 + rnd * 0.18 + s * 0.5;
		metal = 0.12;
	} else if (n.y < -0.7) {
		vec2 uv = wpos.xz / (tile * 1.4);
		float s = max(seam_line(uv.x, 0.02), seam_line(uv.y, 0.02));
		c = ceil_col * (1.0 - s * 0.5);
		rough = 0.7;
	} else {
		vec2 t2 = normalize(vec2(-n.z, n.x));
		float u = dot(wpos.xz, t2);
		float v = wpos.y;
		float pu = u / panel;
		float s = seam_line(pu, 0.008) * (1.0 - clamp(fwidth(pu) * 6.0, 0.0, 0.8));
		float hs = 0.0;
		hs = max(hs, 1.0 - smoothstep(0.0, 0.012 + fwidth(v), abs(v - 1.12)));
		hs = max(hs, 1.0 - smoothstep(0.0, 0.012 + fwidth(v), abs(v - 0.16)));
		hs = max(hs, 1.0 - smoothstep(0.0, 0.012 + fwidth(v), abs(fract((v - band_y) / 2.4 + 0.5) - 0.5) * 2.4));
		float edge = smoothstep(0.3, 0.5, abs(fract(pu) - 0.5)) * (1.0 - clamp(fwidth(pu) * 8.0, 0.0, 1.0));
		float rnd = h31(vec3(floor(pu), floor((v - band_y) / 2.4), 7.0));
		c = wall_col * (0.88 + rnd * 0.14) * (1.0 - edge * 0.12);
		if (v < 0.16) { c = trim_col; rough = 0.4; metal = 0.4; }
		else if (v > 1.0 && v < 1.12) { c = trim_col * 1.2; metal = 0.5; rough = 0.35; }
		c *= 1.0 - max(s, hs) * 0.5;
		float band = 1.0 - smoothstep(0.0, 0.02 + fwidth(v), abs(v - band_y));
		em = accent * band * 2.2 * glow;
		rough = mix(0.55, 0.42, rnd);
	}
	ALBEDO = c;
	ROUGHNESS = rough;
	METALLIC = metal;
	EMISSION = em;
}

shader_type spatial;
// Innenraum-Oberflächen: Wände mit senkrechten Paneelen, Sockel und Lichtband; Bodenfliesen; Deckenpaneele.
#include "res://shaders/common.gdshaderinc"

uniform sampler2D deck_n : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D deck_m : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wall_n : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wall_m : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ceil_n : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ceil_m : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float room_h = 8.0;

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

vec3 tn(sampler2D t, vec2 uv, vec3 n, vec3 T, vec3 B, float k) {
	vec3 v = texture(t, uv).rgb * 2.0 - 1.0;
	return normalize(n * max(v.z, 0.2) + (T * v.x - B * v.y) * k);
}

void fragment() {
	vec3 n = normalize(wn);
	vec3 c;
	float rough = 0.5;
	float metal = 0.1;
	vec3 em = vec3(0.0);
	vec3 pn = n;
	float ao = 1.0;
	if (n.y > 0.7) {
		vec2 uv = wpos.xz / (tile * 2.6667);
		vec4 mk = texture(deck_m, uv);
		pn = tn(deck_n, uv, n, vec3(1.0, 0.0, 0.0), vec3(0.0, 0.0, 1.0), 0.8);
		float dirt = fbm4(wpos * 0.35);
		c = floor_col * (0.88 + (mk.a - 0.5) * 0.4) * mix(1.0, mk.r, 0.45) * (0.88 + dirt * 0.24);
		c = mix(c, vec3(0.5, 0.52, 0.55), mk.b * 0.35);
		rough = clamp(0.2 + (mk.g - 0.5) * 0.5 + (1.0 - mk.r) * 0.35 + dirt * 0.12, 0.08, 1.0);
		metal = 0.35;
		ao = mk.r;
	} else if (n.y < -0.7) {
		vec2 uv = wpos.xz / (tile * 2.6);
		vec4 mk = texture(ceil_m, uv);
		pn = tn(ceil_n, uv, n, vec3(1.0, 0.0, 0.0), vec3(0.0, 0.0, 1.0), 0.8);
		c = ceil_col * mix(1.0, mk.r, 0.7) * (0.9 + (mk.a - 0.5) * 0.4);
		rough = 0.6 + (mk.g - 0.5) * 0.4;
		ao = mk.r;
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
		vec2 wuv = vec2(u / (panel * 2.0), -v / (panel * 2.0));
		vec4 mk = texture(wall_m, wuv);
		vec3 T3 = vec3(t2.x, 0.0, t2.y);
		pn = tn(wall_n, wuv, n, T3, vec3(0.0, -1.0, 0.0), 0.9);
		ao = mk.r;
		c = wall_col * (0.9 + rnd * 0.1 + (mk.a - 0.5) * 0.3) * (1.0 - edge * 0.08) * mix(1.0, mk.r, 0.6);
		if (v < 0.16) { c = trim_col; rough = 0.4; metal = 0.4; }
		else if (v > 1.0 && v < 1.12) { c = trim_col * 1.2; metal = 0.5; rough = 0.35; }
		c *= 1.0 - max(s, hs) * 0.5;
		float band = 1.0 - smoothstep(0.0, 0.02 + fwidth(v), abs(v - band_y));
		em = accent * band * 2.2 * glow;
		rough = clamp(mix(0.55, 0.42, rnd) + (mk.g - 0.5) * 0.5, 0.1, 1.0);
		// Kontaktschatten am Boden und unter der Decke
		ao *= mix(0.55, 1.0, smoothstep(0.0, 0.6, v)) * mix(0.75, 1.0, smoothstep(0.0, 0.8, room_h - v));
	}
	// Fake-AO in Raumecken am Boden
	ALBEDO = c * mix(0.75, 1.0, ao);
	AO = ao;
	AO_LIGHT_AFFECT = 0.25;
	NORMAL = normalize((VIEW_MATRIX * (MODEL_MATRIX * vec4(pn, 0.0))).xyz);
	ROUGHNESS = rough;
	METALLIC = metal;
	EMISSION = em;
}

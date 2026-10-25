// Gemeinsamer Code für den Weltraumhimmel
#include "res://shaders/common.gdshaderinc"

uniform vec3 neb_a : source_color = vec3(0.36, 0.12, 0.46);
uniform vec3 neb_b : source_color = vec3(0.05, 0.30, 0.45);
uniform vec3 neb_c : source_color = vec3(0.70, 0.30, 0.16);
uniform vec3 band_normal = vec3(0.25, 0.9, 0.35);
uniform float neb_strength = 0.55;

vec3 star_layer(vec3 d, float scale, float thresh, float size, float gain) {
	vec3 p = d * scale;
	vec3 c = floor(p);
	vec3 f = fract(p);
	float h = h31(c);
	if (h < thresh) return vec3(0.0);
	vec3 sp = h33(c) * 0.6 + 0.2;
	float dist = length(f - sp);
	float b = smoothstep(size, 0.0, dist);
	vec3 tint = mix(vec3(1.0, 0.82, 0.65), vec3(0.7, 0.82, 1.0), h33(c + 7.0).x);
	float mag = pow((h - thresh) / (1.0 - thresh), 2.0);
	return tint * b * (0.25 + mag * gain);
}

vec3 nebula(vec3 d, float band) {
	vec3 col = vec3(0.004, 0.006, 0.012);
	float n = fbm6(d * 2.1 + 3.0);
	float n2 = fbm4(d * 4.3 - 2.0);
	float dust = smoothstep(0.45, 0.75, fbm4(d * 7.0 + 11.0));
	vec3 neb = neb_a * smoothstep(0.42, 0.85, n) + neb_b * smoothstep(0.5, 0.9, n2) * (0.4 + band) + neb_c * smoothstep(0.62, 0.95, n * n2 * 1.6) * band;
	neb *= (0.35 + band * 0.9) * (1.0 - dust * 0.7 * band);
	col += neb * neb_strength;
	col += vec3(0.55, 0.6, 0.75) * band * 0.035 * (0.6 + n);
	return col;
}



shader_type spatial;
// Prozeduraler Planet: Ozeane, Kontinente, Polkappen, Wolken.
#include "res://shaders/common.gdshaderinc"

uniform vec3 deep : source_color = vec3(0.02, 0.08, 0.18);
uniform vec3 shallow : source_color = vec3(0.06, 0.24, 0.36);
uniform vec3 land_a : source_color = vec3(0.30, 0.34, 0.20);
uniform vec3 land_b : source_color = vec3(0.52, 0.44, 0.30);
uniform vec3 ice : source_color = vec3(0.88, 0.92, 0.96);
uniform float sea = 0.53;

varying vec3 onrm;

void vertex() {
	onrm = normalize(VERTEX);
}

void fragment() {
	vec3 n = onrm;
	float h = fbm6(n * 2.4 + 4.0);
	float lat = abs(n.y);
	vec3 c;
	float r;
	if (h < sea) {
		c = mix(deep, shallow, smoothstep(sea - 0.12, sea, h));
		r = 0.22;
	} else {
		float k = smoothstep(sea, sea + 0.2, h);
		c = mix(land_a, land_b, k + (fbm4(n * 14.0) - 0.5) * 0.5);
		r = 0.9;
	}
	float icek = smoothstep(0.78, 0.86, lat + (h - 0.5) * 0.25);
	c = mix(c, ice, icek);
	float cl = smoothstep(0.52, 0.78, fbm6(n * 4.5 + vec3(TIME * 0.002, 0.0, 0.0)));
	c = mix(c, vec3(0.95), cl * 0.9);
	r = mix(r, 0.95, max(cl, icek));
	ALBEDO = c;
	ROUGHNESS = r;
	METALLIC = 0.0;
	SPECULAR = 0.35;
}

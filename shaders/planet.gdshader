shader_type spatial;
// Prozeduraler Planet: 0 = Erdähnlich, 1 = Gasriese, 2 = Lavawelt.
#include "res://shaders/common.gdshaderinc"

uniform int kind = 0;
uniform vec3 c0 : source_color = vec3(0.02, 0.08, 0.18);
uniform vec3 c1 : source_color = vec3(0.06, 0.24, 0.36);
uniform vec3 c2 : source_color = vec3(0.30, 0.34, 0.20);
uniform vec3 c3 : source_color = vec3(0.52, 0.44, 0.30);
uniform float sea = 0.53;

varying vec3 onrm;

void vertex() {
	onrm = normalize(VERTEX);
}

void fragment() {
	vec3 n = onrm;
	vec3 c;
	float r = 0.9;
	if (kind == 1) {
		float warp = fbm4(n * 3.0) * 0.35;
		float b = n.y * 7.0 + warp * 4.0 + fbm4(n * vec3(1.0, 9.0, 1.0)) * 1.2;
		float t = 0.5 + 0.5 * sin(b * 2.1);
		float t2 = 0.5 + 0.5 * sin(b * 5.3 + 1.0);
		c = mix(mix(c0, c1, t), mix(c2, c3, t2), smoothstep(0.3, 0.8, fbm4(n * 2.0 + 5.0)));
		float storm = 1.0 - smoothstep(0.0, 0.12, length(vec2(n.x - 0.55, (n.y + 0.25) * 1.8)));
		c = mix(c, c2 * 1.4, storm * 0.8);
		r = 0.75;
		EMISSION = vec3(0.0);
	} else if (kind == 2) {
		float h = fbm6(n * 3.0 + 2.0);
		float cracks = 1.0 - smoothstep(0.0, 0.05, abs(fbm4(n * 9.0) - 0.5));
		c = mix(c0, c1, smoothstep(0.35, 0.7, h));
		c = mix(c, c2, smoothstep(0.6, 0.8, fbm4(n * 18.0)));
		EMISSION = c3 * cracks * smoothstep(0.55, 0.3, h) * 2.5;
		r = 0.95;
	} else {
		float h = fbm6(n * 2.4 + 4.0);
		float lat = abs(n.y);
		if (h < sea) {
			c = mix(c0, c1, smoothstep(sea - 0.12, sea, h));
			r = 0.22;
		} else {
			float k = smoothstep(sea, sea + 0.2, h);
			c = mix(c2, c3, k + (fbm4(n * 14.0) - 0.5) * 0.5);
			r = 0.9;
		}
		float icek = smoothstep(0.78, 0.86, lat + (h - 0.5) * 0.25);
		c = mix(c, vec3(0.88, 0.92, 0.96), icek);
		float cl = smoothstep(0.52, 0.78, fbm6(n * 4.5 + vec3(TIME * 0.002, 0.0, 0.0)));
		c = mix(c, vec3(0.95), cl * 0.9);
		r = mix(r, 0.95, max(cl, icek));
	}
	ALBEDO = c;
	ROUGHNESS = r;
	METALLIC = 0.0;
	SPECULAR = 0.35;
}

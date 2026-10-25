shader_type spatial;
// Fenster ins All für Innenräume: Sterne, Nebel, Sonne und der Planet des Systems.
render_mode unshaded, cull_disabled;
#include "res://shaders/sky_common.gdshaderinc"

uniform vec3 planet_dir = vec3(0.0, -0.3, -1.0);
uniform float planet_ang = 0.3;
uniform int planet_kind = 0;
uniform vec3 p0 : source_color = vec3(0.02, 0.08, 0.18);
uniform vec3 p1 : source_color = vec3(0.06, 0.24, 0.36);
uniform vec3 p2 : source_color = vec3(0.30, 0.34, 0.20);
uniform vec3 p3 : source_color = vec3(0.52, 0.44, 0.30);
uniform vec3 atmo : source_color = vec3(0.35, 0.65, 1.0);
uniform vec3 sun_dir = vec3(0.8, 0.3, 0.5);
uniform vec3 sun_col : source_color = vec3(1.0, 0.95, 0.88);

void fragment() {
	vec3 d = normalize((INV_VIEW_MATRIX * vec4(-VIEW, 0.0)).xyz);
	float band = exp(-pow(dot(d, normalize(band_normal)) / 0.28, 2.0));
	vec3 col = nebula(d, band) * 1.3;
	col += star_layer(d, 120.0, 0.6 - band * 0.2, 0.25, 2.0);
	col += star_layer(d, 45.0, 0.9, 0.16, 6.0);
	vec3 pd = normalize(planet_dir);
	vec3 sd = normalize(sun_dir);
	float sa = max(dot(d, sd), 0.0);
	col += sun_col * (pow(sa, 3000.0) * 30.0 + pow(sa, 300.0) * 0.6 + pow(sa, 30.0) * 0.06);
	float ang = acos(clamp(dot(d, pd), -1.0, 1.0));
	float sr = sin(planet_ang);
	if (ang < planet_ang * 1.06) {
		vec3 up = abs(pd.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
		vec3 bx = normalize(cross(up, pd));
		vec3 by = cross(pd, bx);
		vec2 q = vec2(dot(d, bx), dot(d, by)) / sr;
		float r2 = dot(q, q);
		if (r2 < 1.0) {
			float z = sqrt(1.0 - r2);
			vec3 sn = normalize(bx * q.x + by * q.y - pd * z);
			float lit = clamp(dot(sn, sd) * 1.2 + 0.1, 0.0, 1.0);
			vec3 surf;
			if (planet_kind == 1) {
				float b = sn.y * 7.0 + fbm4(sn * 3.0) * 1.4;
				surf = mix(mix(p0, p1, 0.5 + 0.5 * sin(b * 2.1)), mix(p2, p3, 0.5 + 0.5 * sin(b * 5.3)), 0.5);
			} else if (planet_kind == 2) {
				float h = fbm4(sn * 3.0 + 2.0);
				surf = mix(p0, p1, smoothstep(0.35, 0.7, h));
				surf += p3 * (1.0 - smoothstep(0.0, 0.05, abs(fbm4(sn * 9.0) - 0.5))) * (1.0 - lit) * 1.5;
			} else {
				float h = fbm4(sn * 2.4 + 4.0);
				surf = h < 0.53 ? mix(p0, p1, smoothstep(0.41, 0.53, h)) : mix(p2, p3, smoothstep(0.53, 0.73, h));
				surf = mix(surf, vec3(0.95), smoothstep(0.55, 0.8, fbm4(sn * 4.5 + 1.0)) * 0.85);
			}
			float rim = pow(1.0 - z, 3.0);
			col = surf * (0.03 + lit * 1.1) + atmo * rim * lit * 1.4;
		} else {
			float glowr = 1.0 - smoothstep(1.0, 1.12, sqrt(r2));
			col += atmo * glowr * 0.5 * clamp(dot(-pd, sd) + 0.6, 0.0, 1.0);
		}
	}
	ALBEDO = col;
}

shader_type sky;
// Prozeduraler Weltraum (OpenGL-Fallback): alles in voller Auflösung.
#include "res://shaders/sky_common.gdshaderinc"

void sky() {
	vec3 d = normalize(EYEDIR);
	float band = exp(-pow(dot(d, normalize(band_normal)) / 0.28, 2.0));
	vec3 col = nebula(d, band);
	if (!AT_CUBEMAP_PASS) {
		col += star_layer(d, 170.0, 0.62 - band * 0.25, 0.22, 1.6) * 0.9;
		col += star_layer(d, 60.0, 0.9, 0.14, 9.0);
		col += star_layer(d, 380.0, 0.55 - band * 0.35, 0.28, 0.6) * (0.25 + band * 0.6);
	}
	COLOR = col + sun_glow(d);
}

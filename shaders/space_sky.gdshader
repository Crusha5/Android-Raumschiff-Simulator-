shader_type sky;
// Prozeduraler Weltraum (Vulkan): Nebel in halber Auflösung, Sterne scharf in voller Auflösung.
render_mode use_half_res_pass;
#include "res://shaders/sky_common.gdshaderinc"

void sky() {
	vec3 d = normalize(EYEDIR);
	float band = exp(-pow(dot(d, normalize(band_normal)) / 0.28, 2.0));
	if (AT_CUBEMAP_PASS) {
		COLOR = nebula(d, band) + sun_glow(d);
	} else if (AT_HALF_RES_PASS) {
		COLOR = nebula(d, band);
	} else {
		vec3 col = HALF_RES_COLOR.rgb;
		col += star_layer(d, 170.0, 0.62 - band * 0.25, 0.22, 1.6) * 0.9;
		col += star_layer(d, 60.0, 0.9, 0.14, 9.0);
		col += star_layer(d, 380.0, 0.55 - band * 0.35, 0.28, 0.6) * (0.25 + band * 0.6);
		COLOR = col + sun_glow(d);
	}
}

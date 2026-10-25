shader_type spatial;
// Fenster ins All für Innenräume: Sterne und Nebel in Blickrichtung.
render_mode unshaded, cull_disabled;
#include "res://shaders/sky_common.gdshaderinc"

void fragment() {
	vec3 d = normalize((INV_VIEW_MATRIX * vec4(-VIEW, 0.0)).xyz);
	float band = exp(-pow(dot(d, normalize(band_normal)) / 0.28, 2.0));
	vec3 col = nebula(d, band) * 1.3;
	col += star_layer(d, 120.0, 0.6 - band * 0.2, 0.25, 2.0);
	col += star_layer(d, 45.0, 0.9, 0.16, 6.0);
	ALBEDO = col;
}

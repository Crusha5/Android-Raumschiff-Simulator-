shader_type spatial;
// Unlackiertes Metall: gebürstet, mit feinen Kratzern und Rauheitsvariation.
#include "res://shaders/detail.gdshaderinc"

uniform vec3 albedo : source_color = vec3(0.3);
uniform float metallic = 0.5;
uniform float roughness = 0.45;
uniform float det_scale = 0.5;
uniform float det_strength = 0.8;
uniform float panels = 0.0;
uniform sampler2D det_n : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D det_m : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D pan_n : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D pan_m : filter_linear_mipmap_anisotropic, repeat_enable;

varying vec3 opos;
varying vec3 onrm;

void vertex() {
	opos = VERTEX;
	onrm = NORMAL;
}

void fragment() {
	vec3 T;
	vec3 B;
	vec2 uv = det_uv(opos, onrm, T, B) * det_scale;
	vec4 mk = texture(det_m, uv);
	vec3 pn = det_normal(det_n, uv, normalize(onrm), T, B, det_strength);
	float cav = mk.r;
	float rv = mk.g;
	if (panels > 0.0) {
		vec2 uv2 = uv * 0.5;
		vec4 pm = texture(pan_m, uv2);
		pn = normalize(pn + (det_normal(pan_n, uv2, normalize(onrm), T, B, 1.0) - normalize(onrm)) * panels);
		cav *= mix(1.0, pm.r, panels);
		rv = mix(rv, pm.g, panels * 0.5);
	}
	ALBEDO = albedo * mix(1.0, cav, 0.6) * (0.92 + rv * 0.16);
	METALLIC = metallic;
	ROUGHNESS = clamp(roughness + (rv - 0.5) * 0.5, 0.04, 1.0);
	AO = cav;
	AO_LIGHT_AFFECT = 0.3;
	NORMAL = normalize((VIEW_MATRIX * (MODEL_MATRIX * vec4(pn, 0.0))).xyz);
}

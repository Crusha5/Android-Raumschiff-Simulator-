// Detail-Texturen im Objektraum (Projektion nach dominanter Achse, passend zu den Geo-UVs).
// Normal-Map: RGB roh (nicht als Normal-Map importiert), Maske: R Hohlraum, G Rauheit, B Kanten, A Farbvariation.

vec2 det_uv(vec3 p, vec3 n, out vec3 T, out vec3 B) {
	vec3 an = abs(n);
	if (an.x > an.y && an.x > an.z) { T = vec3(0.0, 0.0, 1.0); B = vec3(0.0, 1.0, 0.0); return p.zy; }
	if (an.y > an.z) { T = vec3(1.0, 0.0, 0.0); B = vec3(0.0, 0.0, 1.0); return p.xz; }
	T = vec3(1.0, 0.0, 0.0); B = vec3(0.0, 1.0, 0.0); return p.xy;
}

// Höhenfeld-Normale aus der Normal-Map auf die Fläche übertragen
vec3 det_normal(sampler2D tex, vec2 uv, vec3 n, vec3 T, vec3 B, float strength) {
	vec3 t = texture(tex, uv).rgb * 2.0 - 1.0;
	return normalize(n * max(t.z, 0.2) + (T * t.x - B * t.y) * strength);
}

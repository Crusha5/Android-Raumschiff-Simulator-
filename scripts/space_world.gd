class_name SpaceWorld
extends Node3D
## Das Sonnensystem Sol-7: Himmel, Sonne, Planet, Mond, Stationen, Asteroidenfeld, Raumstaub.

const SKY_SHADER := preload("res://shaders/space_sky.gdshader")
const SKY_SHADER_COMPAT := preload("res://shaders/space_sky_compat.gdshader")
const PLANET_SHADER := preload("res://shaders/planet.gdshader")
const ATMO_SHADER := preload("res://shaders/atmosphere.gdshader")
const DUST_SHADER := preload("res://shaders/dust.gdshader")

const PLANET_POS := Vector3(-26000, -16000, -52000)
const PLANET_R := 20000.0
const SUN_DIR := Vector3(1.0, 0.35, 0.55)

var env: Environment
var sun: DirectionalLight3D
var stations: Array = []
var rocks: Array = []
var dust_mat: ShaderMaterial

func _ready() -> void:
	_build_env()
	_build_planet()
	_build_stations()
	_build_rocks()
	_build_dust()

func _build_env() -> void:
	var sky_mat := ShaderMaterial.new()
	var compat := RenderingServer.get_current_rendering_method() == "gl_compatibility"
	sky_mat.shader = SKY_SHADER_COMPAT if compat else SKY_SHADER
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.1
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_strength = 1.0
	env.glow_bloom = 0.03
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 1.0)
	env.set_glow_level(2, 0.8)
	env.set_glow_level(3, 0.6)
	env.set_glow_level(4, 0.4)
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.05

	sun = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.95, 0.88)
	sun.light_energy = 1.7
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 700.0
	sun.shadow_bias = 0.05
	add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, -SUN_DIR.normalized(), Vector3.UP)
	var shine := DirectionalLight3D.new()
	shine.light_color = Color(0.45, 0.62, 0.9)
	shine.light_energy = 0.35
	shine.shadow_enabled = false
	shine.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(shine)
	shine.look_at_from_position(Vector3.ZERO, PLANET_POS.normalized(), Vector3.UP)

func _build_planet() -> void:
	var pm := SphereMesh.new()
	pm.radius = PLANET_R
	pm.height = PLANET_R * 2.0
	pm.radial_segments = 128
	pm.rings = 64
	var planet := MeshInstance3D.new()
	planet.mesh = pm
	var mat := ShaderMaterial.new()
	mat.shader = PLANET_SHADER
	planet.material_override = mat
	planet.position = PLANET_POS
	planet.rotation = Vector3(0.35, 0.8, 0.0)
	planet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(planet)
	var am := SphereMesh.new()
	am.radius = PLANET_R * 1.035
	am.height = PLANET_R * 2.07
	am.radial_segments = 96
	am.rings = 48
	var atmo := MeshInstance3D.new()
	atmo.mesh = am
	var amat := ShaderMaterial.new()
	amat.shader = ATMO_SHADER
	amat.set_shader_parameter("sun_dir", SUN_DIR.normalized())
	atmo.material_override = amat
	atmo.position = PLANET_POS
	atmo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(atmo)
	# Mond
	var mm := SphereMesh.new()
	mm.radius = 2600.0
	mm.height = 5200.0
	mm.radial_segments = 64
	mm.rings = 32
	var moon := MeshInstance3D.new()
	moon.mesh = mm
	var mmat := StandardMaterial3D.new()
	var nt := NoiseTexture2D.new()
	nt.width = 512
	nt.height = 256
	nt.seamless = true
	var fn := FastNoiseLite.new()
	fn.noise_type = FastNoiseLite.TYPE_CELLULAR
	fn.frequency = 0.02
	nt.noise = fn
	var cr := Gradient.new()
	cr.set_color(0, Color(0.32, 0.31, 0.3))
	cr.set_color(1, Color(0.66, 0.64, 0.6))
	nt.color_ramp = cr
	mmat.albedo_texture = nt
	mmat.roughness = 1.0
	moon.material_override = mmat
	moon.position = Vector3(30000, 9000, -38000)
	moon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(moon)

func _build_stations() -> void:
	_make_station("Kepler-Dock", Vector3(0, 0, -14000), 0.4, 0.05, Color.html("#3fa9ff"), "hub")
	_make_station("Vesta-Ring", Vector3(8000, 1400, -6500), -2.1, -0.08, Color.html("#ffb547"), "hub")
	_make_station("Halden-Mine", Vector3(-7200, -900, -4200), 2.6, 0.1, Color.html("#ff6a3d"), "mine")

func _make_station(sname: String, pos: Vector3, yaw: float, pitch: float, accent: Color, kind: String) -> void:
	var g := Node3D.new()
	g.name = sname
	g.position = pos
	g.rotation = Vector3(pitch, yaw, 0.0)
	add_child(g)
	var hull := ShipBuilder.hull_mat(Color(0.66, 0.67, 0.7), accent, 1, Vector3(60, 60, 140), 0.12, 0.18, 0.55, 0.8)
	var dark := ShipBuilder.std(Color(0.26, 0.28, 0.31), 0.35, 0.5)
	var acc := ShipBuilder.hull_mat(accent, accent, 0, Vector3(60, 60, 60), 0.2, 0.3, 0.5, 0.4)
	var solar := ShipBuilder.hull_mat(Color(0.08, 0.13, 0.25), Color(0.1, 0.2, 0.4), 0, Vector3(130, 2, 35), 0.25, 0.8, 0.22, 0.3)
	var gh := Geo.new()
	var gt := Geo.new()
	var ga := Geo.new()
	var gs := Geo.new()
	var gw := Geo.new()
	var gbay := Geo.new()
	var gcor := Geo.new()
	var gbeacon := Geo.new()
	var I := Transform3D.IDENTITY
	gh.cyl(50, 50, -120, 120, 40, I)
	gt.cyl(30, 50, -165, -120, 40, I)
	gt.cyl(18, 30, -185, -165, 24, I)
	ga.cyl(51.5, 51.5, 55, 66, 40, I, false)
	ga.cyl(51.5, 51.5, -80, -72, 40, I, false)
	for i in 8:
		var a := TAU * i / 8.0
		gt.box(Vector3(14, 10, 160), 1.5, Transform3D(Basis(Vector3.BACK, a), Vector3(cos(a) * 52, sin(a) * 52, -20)))
	for i in 16:
		var a := TAU * (i + 0.5) / 16.0
		for k in 4:
			gw.box(Vector3(5, 2.2, 1.2), 0.2, Transform3D(Basis(Vector3.BACK, a) * Basis(Vector3.UP, PI / 2), Vector3(cos(a) * 50.6, sin(a) * 50.6, -60.0 + k * 26.0)))
	# Solarflügel
	for sx in [-1.0, 1.0]:
		gs.box(Vector3(260, 2, 70), 0.5, Geo.at(sx * 200.0, 0, -140))
		gt.box(Vector3(90, 6, 6), 1.0, Geo.at(sx * 95.0, 0, -140))
		for k in 5:
			gt.box(Vector3(2, 3, 72), 0.3, Geo.at(sx * (80.0 + k * 52.0), 0, -140))
	if kind == "mine":
		for i in 5:
			var a := TAU * i / 5.0
			gt.cyl(22, 22, -90, 0, 20, Geo.at(cos(a) * 95, sin(a) * 95, 0))
			gh.cyl(24, 24, -80, -70, 20, Geo.at(cos(a) * 95, sin(a) * 95, 0), false)
			gt.box(Vector3(60, 8, 8), 1.0, Transform3D(Basis(Vector3.BACK, a), Vector3(cos(a) * 70, sin(a) * 70, -45)))
		for i in 3:
			gt.box(Vector3(8, 8, 260), 1.0, Geo.rot(0, -70.0 + i * 70.0, -260, Vector3(0.0, 0.0, 0.0)))
	# Antennen
	gt.cyl(2, 2, -185, -260, 6, I, true)
	gt.cyl(1.2, 1.2, 0, 90, 6, Transform3D(Basis(Vector3.RIGHT, -PI / 2), Vector3(0, 50, -100)))
	gh.sphere(18, 16, 8, Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0, 150, -100)), -PI / 2 + 0.9)
	# Andockbucht (öffnet nach +Z)
	for y in [43.0, -43.0]:
		gh.box(Vector3(116, 7, 96), 2.0, Geo.at(0, y, 168))
	for x in [56.0, -56.0]:
		gh.box(Vector3(7, 80, 96), 2.0, Geo.at(x, 0, 168))
	gt.box(Vector3(106, 80, 4), 1.0, Geo.at(0, 0, 122))
	gt.box(Vector3(30, 8, 50), 1.5, Geo.at(0, -38, 150))
	for zz in range(132, 212, 14):
		ga.box(Vector3(94, 1.5, 3), 0.3, Geo.at(0, 38.8, zz))
		gw.box(Vector3(3, 1.0, 3), 0.2, Geo.at(-50.5, 0, zz))
		gw.box(Vector3(3, 1.0, 3), 0.2, Geo.at(50.5, 0, zz))
	for k in 4:
		gbay.box(Vector3(10, 4, 2), 0.4, Geo.at(-47.0 if k < 2 else 47.0, -37.0 if k % 2 == 1 else 37.0, 214))
	gbay.box(Vector3(80, 1.2, 1.2), 0.3, Geo.at(0, -38.5, 214))
	for i in 12:
		var z := 280.0 + i * 120.0
		for c in [[-55.0, -45.0], [55.0, -45.0], [-55.0, 45.0], [55.0, 45.0]]:
			gcor.box(Vector3(1.6, 1.6, 1.6), 0.3, Geo.at(c[0], c[1], z))
	gbeacon.sphere(6, 12, 8, Geo.at(0, 0, -262))

	gh.to_node(g, hull)
	gt.to_node(g, dark)
	ga.to_node(g, acc)
	gs.to_node(g, solar)
	gw.to_node(g, ShipBuilder.emissive(Color(1.0, 0.85, 0.6), 3.0), false)
	var bay_mat := ShipBuilder.emissive(Color(0.15, 1.0, 0.3), 3.0)
	gbay.to_node(g, bay_mat, false)
	var cor_mat := ShipBuilder.emissive(Color(0.15, 1.0, 0.3), 2.0)
	var cor := gcor.to_node(g, cor_mat, false)
	var beacon_mat := ShipBuilder.emissive(Color(1.0, 0.25, 0.2), 8.0)
	gbeacon.to_node(g, beacon_mat, false)

	# Rotierender Wohnring
	var spin := Node3D.new()
	g.add_child(spin)
	var rh := Geo.new()
	var rt := Geo.new()
	var rw := Geo.new()
	rh.torus(220, 20, 72, 16, I)
	for i in 6:
		var a := TAU * i / 6.0
		rt.box(Vector3(170, 10, 10), 1.5, Transform3D(Basis(Vector3.BACK, a), Vector3(cos(a) * 135, sin(a) * 135, 0)))
		rh.box(Vector3(46, 34, 56), 4.0, Transform3D(Basis(Vector3.BACK, a + PI / 6), Vector3(cos(a + PI / 6) * 222, sin(a + PI / 6) * 222, 0)))
	for i in 48:
		var a := TAU * i / 48.0
		rw.box(Vector3(5, 5, 2), 0.3, Transform3D(Basis(Vector3.BACK, a), Vector3(cos(a) * 220, sin(a) * 220, 20.5)))
		rw.box(Vector3(5, 5, 2), 0.3, Transform3D(Basis(Vector3.BACK, a), Vector3(cos(a) * 220, sin(a) * 220, -20.5)))
	rh.to_node(spin, ShipBuilder.hull_mat(Color(0.72, 0.73, 0.75), accent, 0, Vector3(240, 240, 30), 0.15, 0.18, 0.55, 0.8))
	rt.to_node(spin, dark)
	rw.to_node(spin, ShipBuilder.emissive(Color(1.0, 0.86, 0.62), 3.5), false)

	for i in 4:
		var a := TAU * i / 4.0 + PI / 4
		var fl := OmniLight3D.new()
		fl.light_color = Color(1.0, 0.9, 0.75)
		fl.light_energy = 1.6
		fl.omni_range = 230.0
		fl.position = Vector3(cos(a) * 140, sin(a) * 140, 90)
		g.add_child(fl)
	var bay_light := OmniLight3D.new()
	bay_light.light_color = Color(1.0, 0.92, 0.8)
	bay_light.light_energy = 2.0
	bay_light.omni_range = 140.0
	bay_light.position = Vector3(0, 30, 165)
	g.add_child(bay_light)

	stations.append({
		"name": sname, "node": g, "spin": spin, "kind": kind,
		"bay_mat": bay_mat, "cor_mat": cor_mat, "cor": cor, "beacon_mat": beacon_mat,
		"entrance": g.to_global(Vector3(0, 0, 250)),
	})

func _rock_mesh(seed_v: int) -> ArrayMesh:
	var fn := FastNoiseLite.new()
	fn.seed = seed_v
	fn.frequency = 1.3
	fn.fractal_octaves = 3
	var g := Geo.new()
	var la := 10
	var lo := 14
	var pts := []
	for i in la + 1:
		var row := []
		var lat := -PI / 2 + PI * i / la
		for j in lo:
			var lon := TAU * j / lo
			var d := Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon))
			var k := 1.0 + fn.get_noise_3dv(d) * 0.45 + fn.get_noise_3dv(d * 3.0) * 0.12
			row.append(d * k * Vector3(1.0, 0.8, 1.15))
		pts.append(row)
	for i in la:
		for j in lo:
			var j2 := (j + 1) % lo
			var a: Vector3 = pts[i][j]
			var b: Vector3 = pts[i][j2]
			var c: Vector3 = pts[i + 1][j2]
			var d: Vector3 = pts[i + 1][j]
			for t in [[a, b, c], [a, c, d]]:
				var n: Vector3 = (t[1] - t[0]).cross(t[2] - t[0])
				if n.length_squared() < 1e-10:
					continue
				n = n.normalized()
				if n.dot(t[0] + t[1] + t[2]) < 0.0:
					n = -n
				g.tri(t[0], t[1], t[2], n, n, n)
	return g.commit()

func _build_rocks() -> void:
	var st: Dictionary = stations[2]
	var node: Node3D = st.node
	var c := node.position
	var inv := node.global_transform.affine_inverse()
	var mat := StandardMaterial3D.new()
	var nt := NoiseTexture2D.new()
	nt.width = 256
	nt.height = 256
	nt.seamless = true
	var fn := FastNoiseLite.new()
	fn.frequency = 0.05
	nt.noise = fn
	var gr := Gradient.new()
	gr.set_color(0, Color(0.22, 0.2, 0.18))
	gr.set_color(1, Color(0.55, 0.5, 0.44))
	nt.color_ramp = gr
	mat.albedo_texture = nt
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.6, 0.6, 0.6)
	mat.roughness = 0.95
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var variants := 3
	var per := [[], [], []]
	var n := 0
	while n < 260:
		var p := c + Vector3(rng.randf_range(-3600, 3600), rng.randf_range(-900, 900), rng.randf_range(-3600, 3600))
		var lp := inv * p
		if p.distance_to(c) < 700.0:
			continue
		if lp.z > 0.0 and abs(lp.x) < 260.0 and abs(lp.y) < 260.0 and lp.z < 2400.0:
			continue
		var r := rng.randf_range(12, 110) * (2.2 if rng.randf() < 0.08 else 1.0)
		var b := Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)).scaled(Vector3(r, r, r))
		per[n % variants].append(Transform3D(b, p))
		rocks.append({"p": p, "r": r * 0.95})
		n += 1
	for v in variants:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _rock_mesh(11 + v * 17)
		mm.instance_count = per[v].size()
		for i in per[v].size():
			mm.set_instance_transform(i, per[v][i])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = mat
		add_child(mi)

func _build_dust() -> void:
	var n := 700
	var box := 260.0
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in n:
		var p := Vector3(rng.randf() * box, rng.randf() * box, rng.randf() * box)
		var base := verts.size()
		for uv in [Vector2(0, -1), Vector2(0, 1), Vector2(1, 1), Vector2(1, -1)]:
			verts.append(p)
			uvs.append(uv)
		idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.custom_aabb = AABB(Vector3(-1e6, -1e6, -1e6), Vector3(2e6, 2e6, 2e6))
	dust_mat = ShaderMaterial.new()
	dust_mat.shader = DUST_SHADER
	dust_mat.set_shader_parameter("box", box)
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = dust_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func animate(t: float, dt: float, nav_target, ship_pos: Vector3) -> void:
	var blink := 3.0 if sin(t * 4.0) > 0.0 else 0.2
	for st in stations:
		st.spin.rotation.z += dt * 0.06
		st.bay_mat.emission_energy_multiplier = blink
		st.beacon_mat.emission_energy_multiplier = 1.0 + 9.0 * max(0.0, sin(t * 2.2))
		st.cor_mat.emission_energy_multiplier = 1.0 + 2.0 * max(0.0, sin(t * 5.0 - 1.0))
		st.cor.visible = (nav_target == st) or ship_pos.distance_to(st.node.position) < 4000.0

func update_dust(cam_pos: Vector3, vel: Vector3) -> void:
	dust_mat.set_shader_parameter("cam_pos", cam_pos)
	dust_mat.set_shader_parameter("vel", vel)
	dust_mat.set_shader_parameter("bright", clampf(0.25 + vel.length() / 200.0, 0.25, 1.2))

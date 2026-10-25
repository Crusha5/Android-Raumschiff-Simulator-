class_name SpaceWorld
extends Node3D
## Ein Sternsystem: Himmel, Sonne, Planet, Mond, Stationen, Sprungtore, Handelsrouten, Asteroiden, Raumstaub.

const SKY_SHADER := preload("res://shaders/space_sky.gdshader")
const SKY_SHADER_COMPAT := preload("res://shaders/space_sky_compat.gdshader")
const PLANET_SHADER := preload("res://shaders/planet.gdshader")
const ATMO_SHADER := preload("res://shaders/atmosphere.gdshader")
const DUST_SHADER := preload("res://shaders/dust.gdshader")
const GATE_SHADER := preload("res://shaders/gate.gdshader")

const LANE_SPACING := 2500.0
const LANE_SPEED := 2600.0

var sys_id := ""
var sys: Dictionary
var env: Environment
var sky_mat: ShaderMaterial
var sun: DirectionalLight3D
var shine: DirectionalLight3D
var content: Node3D       # wird bei jedem Systemwechsel neu gebaut
var dynamic: Node3D       # Schiffe, Geschosse, Effekte
var stations: Array = []
var gates: Array = []
var lanes: Array = []
var rocks: Array = []
var planet_pos := Vector3.ZERO
var planet_r := 1.0
var dust_mat: ShaderMaterial
var lane_mats: Array = []
var _rock_meshes := {}

func _ready() -> void:
	sky_mat = ShaderMaterial.new()
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
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 700.0
	sun.shadow_bias = 0.05
	add_child(sun)
	shine = DirectionalLight3D.new()
	shine.light_energy = 0.35
	shine.shadow_enabled = false
	shine.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(shine)
	_build_dust()
	dynamic = Node3D.new()
	dynamic.name = "Dynamic"
	add_child(dynamic)

func build(id: String) -> void:
	sys_id = id
	sys = Universe.system(id)
	if content:
		content.queue_free()
	for c in dynamic.get_children():
		c.queue_free()
	content = Node3D.new()
	add_child(content)
	stations = []
	gates = []
	lanes = []
	rocks = []
	lane_mats = []
	var neb: Array = sys.neb
	sky_mat.set_shader_parameter("neb_a", neb[0])
	sky_mat.set_shader_parameter("neb_b", neb[1])
	sky_mat.set_shader_parameter("neb_c", neb[2])
	sky_mat.set_shader_parameter("band_normal", sys.band)
	var sd: Vector3 = (sys.sun_dir as Vector3).normalized()
	sun.light_color = sys.sun_color
	sun.light_energy = sys.sun_energy
	sun.look_at_from_position(Vector3.ZERO, -sd, Vector3.UP if absf(sd.y) < 0.95 else Vector3.RIGHT)
	_build_planet()
	for st in sys.stations:
		_make_station(st)
	for g in sys.gates:
		_make_gate(g)
	for ln in sys.lanes:
		_make_lane(ln)
	for f in sys.fields:
		_build_rocks(f)

# ------------------------------------------------------------------ Planet
func _build_planet() -> void:
	var pd: Dictionary = sys.planet
	planet_pos = pd.pos
	planet_r = pd.r
	var pm := SphereMesh.new()
	pm.radius = planet_r
	pm.height = planet_r * 2.0
	pm.radial_segments = 128
	pm.rings = 64
	var planet := MeshInstance3D.new()
	planet.mesh = pm
	var mat := ShaderMaterial.new()
	mat.shader = PLANET_SHADER
	mat.set_shader_parameter("kind", int(pd.kind))
	for i in 4:
		mat.set_shader_parameter("c%d" % i, pd.c[i])
	planet.material_override = mat
	planet.position = planet_pos
	planet.rotation = Vector3(0.35, 0.8, 0.12)
	planet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	content.add_child(planet)
	var am := SphereMesh.new()
	am.radius = planet_r * 1.035
	am.height = planet_r * 2.07
	am.radial_segments = 96
	am.rings = 48
	var atmo := MeshInstance3D.new()
	atmo.mesh = am
	var amat := ShaderMaterial.new()
	amat.shader = ATMO_SHADER
	amat.set_shader_parameter("sun_dir", (sys.sun_dir as Vector3).normalized())
	amat.set_shader_parameter("atmo", pd.atmo)
	atmo.material_override = amat
	atmo.position = planet_pos
	atmo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	content.add_child(atmo)
	shine.light_color = (pd.atmo as Color).lerp(Color(0.5, 0.6, 0.8), 0.5)
	shine.look_at_from_position(Vector3.ZERO, planet_pos.normalized(), Vector3.UP)
	var md: Dictionary = sys.moon
	if not md.is_empty():
		var mm := SphereMesh.new()
		mm.radius = md.r
		mm.height = md.r * 2.0
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
		moon.position = md.pos
		moon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		content.add_child(moon)

# ------------------------------------------------------------------ Stationen
func _make_station(d: Dictionary) -> void:
	var g := Node3D.new()
	g.name = d.n
	g.position = d.pos
	g.rotation = Vector3(d.pitch, d.yaw, 0.0)
	content.add_child(g)
	var kind: String = d.kind
	var accent: Color = d.accent
	var free := kind == "freeport"
	var hull_c := Color(0.25, 0.24, 0.27) if free else Color(0.66, 0.67, 0.7)
	var hull := ShipBuilder.hull_mat(hull_c, accent, 0 if free else 1, Vector3(60, 60, 140), 0.12, 0.18, 0.55, 0.8)
	var dark := ShipBuilder.std(Color(0.26, 0.28, 0.31) if not free else Color(0.12, 0.12, 0.14), 0.35, 0.5)
	var acc := ShipBuilder.hull_mat(accent, accent, 0, Vector3(60, 60, 60), 0.2, 0.3, 0.5, 0.4)
	var solar := ShipBuilder.hull_mat(Color(0.08, 0.13, 0.25), Color(0.1, 0.2, 0.4), 0, Vector3(130, 2, 35), 0.25, 0.8, 0.22, 0.3)
	var gh := Geo.new()
	var gt := Geo.new()
	var ga := Geo.new()
	var gs := Geo.new()
	var gw := Geo.new()
	var gn := Geo.new()
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
	if not free:
		for sx in [-1.0, 1.0]:
			gs.box(Vector3(260, 2, 70), 0.5, Geo.at(sx * 200.0, 0, -140))
			gt.box(Vector3(90, 6, 6), 1.0, Geo.at(sx * 95.0, 0, -140))
			for k in 5:
				gt.box(Vector3(2, 3, 72), 0.3, Geo.at(sx * (80.0 + k * 52.0), 0, -140))
	match kind:
		"mine":
			for i in 5:
				var a := TAU * i / 5.0
				gt.cyl(22, 22, -90, 0, 20, Geo.at(cos(a) * 95, sin(a) * 95, 0))
				gh.cyl(24, 24, -80, -70, 20, Geo.at(cos(a) * 95, sin(a) * 95, 0), false)
				gt.box(Vector3(60, 8, 8), 1.0, Transform3D(Basis(Vector3.BACK, a), Vector3(cos(a) * 70, sin(a) * 70, -45)))
			for i in 3:
				gt.box(Vector3(8, 8, 300), 1.0, Geo.at(-70.0 + i * 70.0, -70, -200))
				gw.box(Vector3(3, 3, 300), 0.4, Geo.at(-70.0 + i * 70.0, -64, -200))
		"shipyard":
			# Gerüst mit einem Schiff im Bau
			for sx in [-1.0, 1.0]:
				for sy in [-1.0, 1.0]:
					gt.box(Vector3(8, 8, 520), 1.0, Geo.at(sx * 150, sy * 70 - 260, -60))
			for k in 7:
				var z := -320.0 + k * 85.0
				gt.box(Vector3(308, 6, 6), 1.0, Geo.at(0, -190, z))
				gt.box(Vector3(308, 6, 6), 1.0, Geo.at(0, -330, z))
				gt.box(Vector3(6, 146, 6), 1.0, Geo.at(-150, -260, z))
				gt.box(Vector3(6, 146, 6), 1.0, Geo.at(150, -260, z))
				gn.box(Vector3(4, 4, 4), 0.5, Geo.at(-150, -186, z))
				gn.box(Vector3(4, 4, 4), 0.5, Geo.at(150, -186, z))
			gt.box(Vector3(30, 140, 30), 2.0, Geo.at(0, -120, -60))
			var proto := ShipBuilder.build({"frame": "kondor", "engine": "ionen", "rcs": "rcs4", "weapon": "lanze", "shield": "s3", "cargo": "k120", "armor": "a3", "extra": "x0"},
				{"hull": "#4a4f58", "accent": "#9fd4ff", "pattern": "uni", "flame": "auto"})
			proto.scale = Vector3.ONE * 11.0
			proto.position = Vector3(0, -260, -60)
			for f in proto.get_meta("flames"):
				f.visible = false
			g.add_child(proto)
		"refinery":
			for i in 4:
				var a := TAU * i / 4.0 + PI / 4
				gh.sphere(45, 24, 12, Geo.at(cos(a) * 140, sin(a) * 140, -60))
				gt.cyl(5, 5, 0, 1, 8, Transform3D(Basis.looking_at(Vector3(cos(a), sin(a), 0)).scaled(Vector3(1, 1, 95)), Vector3(cos(a) * 50, sin(a) * 50, -60)), false)
				ga.cyl(46, 46, -64, -56, 24, Geo.at(cos(a) * 140, sin(a) * 140, 0), false)
			gt.cyl(14, 10, -185, -330, 16, I)
			gn.cyl(15, 15, -300, -296, 16, I, false)
		"freeport":
			for i in 10:
				var a := TAU * i / 10.0
				var len := 120.0 + (i % 3) * 60.0
				gt.frustum(Vector2(14, 14), Vector2(1, 1), len, Transform3D(Basis.looking_at(-Vector3(cos(a), sin(a), 0.3).normalized()), Vector3(cos(a), sin(a), 0) * (50 + len * 0.5) + Vector3(0, 0, -40)))
			for i in 24:
				var a := TAU * i / 24.0
				gn.box(Vector3(3, 3, 30), 0.3, Transform3D(Basis(Vector3.BACK, a), Vector3(cos(a) * 51.5, sin(a) * 51.5, 20)))
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
	gn.to_node(g, ShipBuilder.emissive(accent, 4.0), false)
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
	var segs := 72
	if free:
		for k in 3:
			var a0 := TAU * k / 3.0
			for j in 14:
				var a := a0 + j * 0.06
				rh.box(Vector3(36, 30, 40), 3.0, Transform3D(Basis(Vector3.BACK, a), Vector3(cos(a) * 220, sin(a) * 220, 0)))
	else:
		rh.torus(220, 20, segs, 16, I)
	for i in 6:
		var a := TAU * i / 6.0
		rt.box(Vector3(170, 10, 10), 1.5, Transform3D(Basis(Vector3.BACK, a), Vector3(cos(a) * 135, sin(a) * 135, 0)))
		if not free:
			rh.box(Vector3(46, 34, 56), 4.0, Transform3D(Basis(Vector3.BACK, a + PI / 6), Vector3(cos(a + PI / 6) * 222, sin(a + PI / 6) * 222, 0)))
	for i in 48:
		var a := TAU * i / 48.0
		rw.box(Vector3(5, 5, 2), 0.3, Transform3D(Basis(Vector3.BACK, a), Vector3(cos(a) * 220, sin(a) * 220, 20.5)))
		rw.box(Vector3(5, 5, 2), 0.3, Transform3D(Basis(Vector3.BACK, a), Vector3(cos(a) * 220, sin(a) * 220, -20.5)))
	rh.to_node(spin, ShipBuilder.hull_mat(hull_c.lightened(0.05), accent, 0, Vector3(240, 240, 30), 0.15, 0.18, 0.55, 0.8))
	rt.to_node(spin, dark)
	rw.to_node(spin, ShipBuilder.emissive(accent.lerp(Color(1, 0.86, 0.62), 0.3 if free else 0.85), 3.5), false)

	for i in 4:
		var a := TAU * i / 4.0 + PI / 4
		var fl := OmniLight3D.new()
		fl.light_color = accent.lerp(Color(1.0, 0.9, 0.75), 0.6)
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
		"id": d.id, "name": d.n, "kind": kind, "shop": d.shop, "accent": accent, "node": g, "spin": spin,
		"bay_mat": bay_mat, "cor_mat": cor_mat, "cor": cor, "beacon_mat": beacon_mat,
		"entrance": g.to_global(Vector3(0, 0, 250)), "pos": g.position, "type": "station",
	})

func station_by_id(id: String) -> Dictionary:
	for st in stations:
		if st.id == id:
			return st
	return {}

func gate_by_id(id: String) -> Dictionary:
	for g in gates:
		if g.id == id:
			return g
	return {}

# ------------------------------------------------------------------ Sprungtore
func _make_gate(d: Dictionary) -> void:
	var g := Node3D.new()
	g.name = d.id
	g.position = d.pos
	g.rotation = Vector3(0, d.yaw, 0)
	content.add_child(g)
	var gm := Geo.new()
	var gd := Geo.new()
	var gl := Geo.new()
	var gi := Geo.new()
	var I := Transform3D.IDENTITY
	gm.torus(190, 18, 72, 14, I)
	gd.torus(170, 6, 72, 8, I)
	for i in 8:
		var a := TAU * i / 8.0
		var xf := Transform3D(Basis(Vector3.BACK, a), Vector3(cos(a) * 200, sin(a) * 200, 0))
		gm.box(Vector3(60, 46, 70), 6.0, xf)
		gd.box(Vector3(30, 60, 90), 4.0, xf)
		gl.box(Vector3(6, 6, 74), 1.0, Transform3D(Basis(Vector3.BACK, a), Vector3(cos(a) * 232, sin(a) * 232, 0)))
	gi.torus(172, 2.2, 96, 6, Geo.at(0, 0, 8))
	gi.torus(172, 2.2, 96, 6, Geo.at(0, 0, -8))
	var dest := Universe.system(d.to)
	var col: Color = dest.neb[1]
	gm.to_node(g, ShipBuilder.hull_mat(Color(0.5, 0.52, 0.56), col, 0, Vector3(200, 200, 20), 0.08, 0.25, 0.5, 0.8))
	gd.to_node(g, ShipBuilder.std(Color(0.18, 0.19, 0.22), 0.4, 0.5))
	gl.to_node(g, ShipBuilder.emissive(Color(1, 0.3, 0.25), 5.0), false)
	var inner_mat := ShipBuilder.emissive(col.lightened(0.4), 4.0)
	gi.to_node(g, inner_mat, false)
	var disc := MeshInstance3D.new()
	var dg := Geo.new()
	var pts := []
	for i in 64:
		var a := TAU * i / 64.0
		pts.append(Vector3(cos(a), sin(a), 0))
	dg.poly(pts, Vector3(0, 0, -1), I)
	disc.mesh = dg.commit()
	disc.scale = Vector3(168, 168, 1)
	var dm := ShaderMaterial.new()
	dm.shader = GATE_SHADER
	dm.set_shader_parameter("col_a", col.lightened(0.2))
	dm.set_shader_parameter("col_b", (dest.neb[0] as Color).lightened(0.3))
	dm.set_shader_parameter("power", 0.6)
	disc.material_override = dm
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(disc)
	var lamp := OmniLight3D.new()
	lamp.light_color = col.lightened(0.3)
	lamp.light_energy = 3.0
	lamp.omni_range = 600.0
	g.add_child(lamp)
	gates.append({"id": d.id, "name": "Sprungtor " + dest.n, "to": d.to, "to_gate": d.to_gate, "node": g, "pos": g.position,
		"disc_mat": dm, "inner_mat": inner_mat, "type": "gate", "entrance": g.position})

# ------------------------------------------------------------------ Handelsrouten
func _endpoint(id: String) -> Dictionary:
	var st := station_by_id(id)
	if not st.is_empty():
		return {"pos": st.entrance, "name": st.name, "off": 900.0}
	var g := gate_by_id(id)
	return {"pos": g.pos, "name": g.name, "off": 700.0}

func _make_lane(ln: Array) -> void:
	var a := _endpoint(ln[0])
	var b := _endpoint(ln[1])
	var pa: Vector3 = a.pos
	var pb: Vector3 = b.pos
	var dir := (pb - pa).normalized()
	var p0 := pa + dir * float(a.off)
	var p1 := pb - dir * float(b.off)
	var length := p0.distance_to(p1)
	var n := maxi(2, int(length / LANE_SPACING) + 1)
	var basis := Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT)
	var gm := Geo.new()
	var gl := Geo.new()
	var rings := []
	for i in n:
		var p := p0.lerp(p1, float(i) / float(n - 1))
		rings.append(p)
		var xf := Transform3D(basis, p)
		gm.torus(42, 3.5, 40, 8, xf)
		for k in 4:
			var ang := TAU * k / 4.0 + PI / 4
			var o := Vector3(cos(ang), sin(ang), 0) * 46.0
			gm.box(Vector3(9, 9, 14), 1.2, xf * Transform3D(Basis(Vector3.BACK, ang), o))
			gl.box(Vector3(3, 3, 15), 0.5, xf * Transform3D(Basis(Vector3.BACK, ang), o * 1.12))
	var node := Node3D.new()
	content.add_child(node)
	gm.to_node(node, ShipBuilder.std(Color(0.42, 0.44, 0.48), 0.4, 0.45))
	var lm := ShipBuilder.emissive(Color(1.0, 0.75, 0.35), 3.0)
	gl.to_node(node, lm, false)
	lane_mats.append(lm)
	lanes.append({"a": ln[0], "b": ln[1], "a_name": a.name, "b_name": b.name, "p0": p0, "p1": p1, "rings": rings, "dir": dir})

# ------------------------------------------------------------------ Asteroiden
func _rock_mesh(seed_v: int) -> ArrayMesh:
	if _rock_meshes.has(seed_v):
		return _rock_meshes[seed_v]
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
	var m := g.commit()
	_rock_meshes[seed_v] = m
	return m

func _build_rocks(f: Dictionary) -> void:
	var c: Vector3 = f.c
	var ice: bool = f.ice
	var mat := StandardMaterial3D.new()
	var nt := NoiseTexture2D.new()
	nt.width = 256
	nt.height = 256
	nt.seamless = true
	var fn := FastNoiseLite.new()
	fn.frequency = 0.05
	nt.noise = fn
	var gr := Gradient.new()
	if ice:
		gr.set_color(0, Color(0.45, 0.55, 0.65))
		gr.set_color(1, Color(0.85, 0.92, 1.0))
		mat.roughness = 0.35
		mat.metallic = 0.1
	else:
		gr.set_color(0, Color(0.22, 0.2, 0.18))
		gr.set_color(1, Color(0.55, 0.5, 0.44))
		mat.roughness = 0.95
	nt.color_ramp = gr
	mat.albedo_texture = nt
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.6, 0.6, 0.6)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(c.x) * 31 + int(c.z)
	var keep_clear := []
	for st in stations:
		keep_clear.append(st)
	var per := [[], [], []]
	var count := 0
	var tries := 0
	var r_field: float = f.r
	while count < int(f.n) and tries < 5000:
		tries += 1
		var p := c + Vector3(rng.randf_range(-r_field, r_field), rng.randf_range(-r_field * 0.25, r_field * 0.25), rng.randf_range(-r_field, r_field))
		var bad := false
		for st in keep_clear:
			var node: Node3D = st.node
			if p.distance_to(node.position) < 700.0:
				bad = true
				break
			var lp := node.to_local(p)
			if lp.z > 0.0 and absf(lp.x) < 260.0 and absf(lp.y) < 260.0 and lp.z < 2400.0:
				bad = true
				break
		for ln in lanes:
			var seg_p := Geometry3D.get_closest_point_to_segment(p, ln.p0, ln.p1)
			if seg_p.distance_to(p) < 250.0:
				bad = true
				break
		if bad:
			continue
		var r := rng.randf_range(12, 110) * (2.2 if rng.randf() < 0.08 else 1.0)
		var b := Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)).scaled(Vector3(r, r, r))
		per[count % 3].append(Transform3D(b, p))
		rocks.append({"p": p, "r": r * 0.95})
		count += 1
	for v in 3:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _rock_mesh(11 + v * 17)
		mm.instance_count = per[v].size()
		for i in per[v].size():
			mm.set_instance_transform(i, per[v][i])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = mat
		content.add_child(mi)

# ------------------------------------------------------------------ Staub
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

func animate(t: float, dt: float, nav_pos: Vector3, ship_pos: Vector3) -> void:
	var blink := 3.0 if sin(t * 4.0) > 0.0 else 0.2
	for st in stations:
		st.spin.rotation.z += dt * 0.06
		st.bay_mat.emission_energy_multiplier = blink
		st.beacon_mat.emission_energy_multiplier = 1.0 + 9.0 * max(0.0, sin(t * 2.2))
		st.cor_mat.emission_energy_multiplier = 1.0 + 2.0 * max(0.0, sin(t * 5.0 - 1.0))
		st.cor.visible = nav_pos.distance_to(st.node.position) < 600.0 or ship_pos.distance_to(st.node.position) < 4000.0
	for g in gates:
		g.inner_mat.emission_energy_multiplier = 2.5 + 2.0 * sin(t * 1.7)
	for m in lane_mats:
		m.emission_energy_multiplier = 2.0 + 1.5 * max(0.0, sin(t * 3.0))

func update_dust(cam_pos: Vector3, vel: Vector3, streak := 0.05) -> void:
	dust_mat.set_shader_parameter("cam_pos", cam_pos)
	dust_mat.set_shader_parameter("vel", vel)
	dust_mat.set_shader_parameter("streak", streak)
	dust_mat.set_shader_parameter("bright", clampf(0.25 + vel.length() / 200.0, 0.25, 1.4))

class_name Hangar
extends Node3D
## Werfthalle: Drehteller mit Leuchtringen, Hallenwand mit Lichtbändern, eigene Beleuchtung.

const FLOOR_SHADER := preload("res://shaders/floor.gdshader")

var env: Environment
var lights: Array = []
var floor_node: Node3D
var ship: Node3D
var pivot: Node3D
var cam: Camera3D
var rot := 0.6
var tilt := 0.0
var dragging := false
var center := Vector3.ZERO
var radius := 10.0
var panel_frac := 0.5

func _ready() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.035, 0.045, 0.065)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.42, 0.56)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.065, 0.09)
	env.fog_density = 0.006
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1

	floor_node = Node3D.new()
	add_child(floor_node)
	var gf := Geo.new()
	gf.cyl(30, 30, -0.6, 0.0, 72, Transform3D(Basis(Vector3.RIGHT, -PI / 2), Vector3.ZERO))
	var fm := ShaderMaterial.new()
	fm.shader = FLOOR_SHADER
	gf.to_node(floor_node, fm)
	var gr := Geo.new()
	gr.cyl(31.5, 32.5, -1.2, 0.05, 72, Transform3D(Basis(Vector3.RIGHT, -PI / 2), Vector3.ZERO))
	gr.to_node(floor_node, ShipBuilder.std(Color(0.12, 0.13, 0.15), 0.8, 0.35))

	# Hallenwand mit Lichtbändern und Kranbahn
	var gw := Geo.new()
	var gl := Geo.new()
	var ga := Geo.new()
	gw.cyl(95, 95, -10, 60, 48, Transform3D(Basis(Vector3.RIGHT, -PI / 2), Vector3.ZERO), false, true)
	for i in 24:
		var a := TAU * i / 24.0
		var p := Vector3(cos(a) * 93.0, 0, sin(a) * 93.0)
		var b := Basis(Vector3.UP, -a + PI / 2)
		gw.box(Vector3(10, 70, 3), 0.5, Transform3D(b, p + Vector3(0, 25, 0)))
		gl.box(Vector3(1.4, 44, 1.0), 0.2, Transform3D(b, p * 0.985 + Vector3(0, 22, 0)))
		if i % 3 == 0:
			ga.box(Vector3(6, 1.2, 1.0), 0.2, Transform3D(b, p * 0.985 + Vector3(0, 2.5, 0)))
	for x in [-24.0, 24.0]:
		gw.box(Vector3(3, 3, 190), 0.4, Geo.at(x, 46, 0))
	gw.box(Vector3(52, 2.5, 4), 0.4, Geo.at(0, 45, 6))
	gw.to_node(self, ShipBuilder.std(Color(0.11, 0.13, 0.17), 0.6, 0.5), false)
	gl.to_node(self, ShipBuilder.emissive(Color(0.62, 0.83, 1.0), 2.2), false)
	ga.to_node(self, ShipBuilder.emissive(Color(1.0, 0.71, 0.28), 3.0), false)

	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.9, 0.78)
	key.light_energy = 1.3
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 120.0
	add_child(key)
	key.look_at_from_position(Vector3(22, 34, 26), Vector3.ZERO, Vector3.UP)
	lights.append(key)
	var rim := SpotLight3D.new()
	rim.light_color = Color(0.55, 0.75, 1.0)
	rim.light_energy = 6.0
	rim.spot_range = 120.0
	rim.spot_angle = 35.0
	add_child(rim)
	rim.look_at_from_position(Vector3(-30, 22, -36), Vector3.ZERO, Vector3.UP)
	lights.append(rim)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.7, 0.8, 1.0)
	fill.light_energy = 0.55
	add_child(fill)
	fill.look_at_from_position(Vector3(-20, 8, 30), Vector3.ZERO, Vector3.UP)
	lights.append(fill)
	var under := OmniLight3D.new()
	under.light_color = Color(1.0, 0.7, 0.35)
	under.light_energy = 1.2
	under.omni_range = 30.0
	under.position = Vector3(0, -2, 0)
	floor_node.add_child(under)

	cam = Camera3D.new()
	cam.fov = 38.0
	cam.near = 0.1
	cam.far = 800.0
	add_child(cam)

func set_ship(s: Node3D) -> void:
	if ship:
		ship.queue_free()
	if pivot == null:
		pivot = Node3D.new()
		add_child(pivot)
	ship = s
	pivot.add_child(ship)
	var aabb := _aabb(ship, Transform3D.IDENTITY)
	var c := aabb.get_center()
	ship.position = Vector3(-c.x, 0.0, -c.z)
	center = Vector3(0.0, c.y, 0.0)
	radius = aabb.size.length() * 0.5
	floor_node.position.y = aabb.position.y - 0.9
	var sc := maxf(0.6, radius / 13.0)
	floor_node.scale = Vector3(sc, 1, sc)
	pivot.rotation.y = rot

static func _aabb(n: Node3D, xf: Transform3D) -> AABB:
	var out := AABB()
	var first := true
	for c in n.get_children():
		if not (c is Node3D):
			continue
		var cx: Transform3D = xf * (c as Node3D).transform
		var a: AABB
		if c is MeshInstance3D:
			var mi := c as MeshInstance3D
			if mi.mesh == null:
				continue
			if mi.material_override is ShaderMaterial and (mi.material_override as ShaderMaterial).shader == ShipBuilder.FLAME_SHADER:
				continue
			a = cx * mi.mesh.get_aabb()
		else:
			a = _aabb(c as Node3D, cx)
			if a.size == Vector3.ZERO:
				continue
		out = a if first else out.merge(a)
		first = false
	return out

func activate(vp: Viewport) -> void:
	cam.make_current()
	visible = true

func update(dt: float, view_size: Vector2) -> void:
	if not ship:
		return
	if not dragging:
		rot += dt * 0.22
	pivot.rotation.y = rot
	var aspect: float = view_size.x / maxf(view_size.y, 1.0)
	var tv := tan(deg_to_rad(cam.fov * 0.5))
	var th := tv * aspect
	var free_h := th * (1.0 - panel_frac)
	var d := radius / minf(free_h, tv) * 1.05
	var el := 0.3 + tilt
	cam.position = center + Vector3(0, sin(el), cos(el)) * d
	cam.look_at(center, Vector3.UP)
	cam.h_offset = panel_frac * th * d
	var flames: Array = ship.get_meta("flames", [])
	for f in flames:
		f.scale.z = float(ship.get_meta("flame_len", 5.0)) * (0.35 + randf() * 0.04)
		f.material_override.set_shader_parameter("power", 0.32)
	var beacon = ship.get_meta("beacon") if ship.has_meta("beacon") else null
	if beacon:
		beacon.emission_energy_multiplier = 1.0 + 7.0 * max(0.0, sin(Time.get_ticks_msec() * 0.004))
	var strobe = ship.get_meta("strobe", null)
	if strobe:
		strobe.emission_energy_multiplier = 14.0 if fmod(Time.get_ticks_msec() * 0.001, 1.4) < 0.08 else 0.4
	var el_light = ship.get_meta("eng_light", null)
	if el_light:
		el_light.light_energy = 1.5

func drag(rel: Vector2) -> void:
	rot += rel.x * 0.01
	tilt = clampf(tilt + rel.y * 0.004, -0.45, 0.65)

class_name Combat
extends Node3D
## Geschosse, Treffer und Effekte (Explosionen, Funken).

const FIREBALL_SHADER := preload("res://shaders/fireball.gdshader")

signal ship_hit(ship: ShipState, dmg: float, attacker: ShipState)
signal ship_destroyed(ship: ShipState, attacker: ShipState)

var bolts: Array = []
var effects: Array = []
var _bolt_mesh: Dictionary = {}
var _bolt_mat: Dictionary = {}
var _spark_mat: StandardMaterial3D
var _quad: QuadMesh
var world: SpaceWorld
var ships: Array = []   # alle ShipState (Spieler + NPC)

func _ready() -> void:
	_spark_mat = StandardMaterial3D.new()
	_spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_spark_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_spark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_spark_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_spark_mat.vertex_color_use_as_albedo = true
	_spark_mat.albedo_color = Color(1, 1, 1)
	_quad = QuadMesh.new()
	_quad.size = Vector2(1, 1)
	_quad.material = _spark_mat

func _mesh_for(size: float) -> Mesh:
	var key := snappedf(size, 0.1)
	if not _bolt_mesh.has(key):
		var g := Geo.new()
		g.box(Vector3(0.55, 0.55, 10.0) * size, 0.2 * size, Transform3D.IDENTITY)
		_bolt_mesh[key] = g.commit()
	return _bolt_mesh[key]

func _mat_for(col: String) -> Material:
	if not _bolt_mat.has(col):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color.html(col) * 4.0
		_bolt_mat[col] = m
	return _bolt_mat[col]

func spawn_bolt(owner: ShipState, at: Vector3, dir: Vector3, w: Dictionary) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh_for(float(w.size))
	mi.material_override = _mat_for(w.color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var v := dir * float(w.speed) + owner.vel
	mi.global_position = at
	mi.look_at(at + v, Vector3.UP if absf(v.normalized().y) < 0.98 else Vector3.RIGHT)
	bolts.append({"node": mi, "pos": at, "vel": v, "life": float(w.range) / float(w.speed), "dmg": float(w.dmg), "owner": owner})
	if owner.is_player or randf() < 0.5:
		spark(at, Color.html(w.color), 0.5, 4)

func update(dt: float) -> void:
	var i := 0
	while i < bolts.size():
		var b: Dictionary = bolts[i]
		var p0: Vector3 = b.pos
		var p1: Vector3 = p0 + b.vel * dt
		b.pos = p1
		b.life -= dt
		var dead: bool = b.life <= 0.0
		if not dead:
			for s in ships:
				if not s.alive or s == b.owner:
					continue
				if (b.owner as ShipState).faction == s.faction:
					continue
				if (b.owner as ShipState).faction != "player" and s.faction != "player":
					continue
				var cp := Geometry3D.get_closest_point_to_segment(s.pos, p0, p1)
				if cp.distance_to(s.pos) < s.radius:
					var hull_dmg: float = s.take_damage(b.dmg, (p0 - s.pos).normalized())
					spark(cp, Color(1.0, 0.7, 0.4) if s.shield <= 0.0 else Color(0.5, 0.8, 1.0), 1.0, 10)
					ship_hit.emit(s, hull_dmg, b.owner)
					if not s.alive:
						explode(s.pos, s.radius)
						ship_destroyed.emit(s, b.owner)
					dead = true
					break
		if not dead and world:
			for st in world.stations:
				if p1.distance_to(st.node.position) < 260.0:
					dead = true
					break
		if not dead and world and b.owner.is_player:
			for r in world.rocks:
				if p1.distance_to(r.p) < r.r:
					spark(p1, Color(1.0, 0.8, 0.5), 0.8, 6)
					dead = true
					break
		if dead:
			b.node.queue_free()
			bolts.remove_at(i)
		else:
			b.node.global_position = p1
			i += 1
	var j := 0
	while j < effects.size():
		var e: Dictionary = effects[j]
		e.t += dt
		var k: float = e.t / e.life
		if k >= 1.0:
			e.node.queue_free()
			effects.remove_at(j)
			continue
		if e.has("mat"):
			e.mat.set_shader_parameter("age", k)
			e.node.scale = Vector3.ONE * e.size * (0.4 + k * 1.8)
		if e.has("light"):
			e.light.light_energy = e.energy * (1.0 - k) * (1.0 - k)
		j += 1

func clear() -> void:
	for b in bolts:
		if is_instance_valid(b.node):
			b.node.queue_free()
	bolts = []
	for e in effects:
		if is_instance_valid(e.node):
			e.node.queue_free()
	effects = []

func spark(at: Vector3, col: Color, scale_f: float, amount: int) -> void:
	var p := CPUParticles3D.new()
	p.mesh = _quad
	p.amount = amount
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.45
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 8.0 * scale_f
	p.initial_velocity_max = 40.0 * scale_f
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.6 * scale_f
	p.scale_amount_max = 1.6 * scale_f
	p.color = col * 3.0
	add_child(p)
	p.global_position = at
	p.emitting = true
	effects.append({"node": p, "t": 0.0, "life": 0.8})

func explode(at: Vector3, size: float) -> void:
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 24
	sm.rings = 12
	var fb := MeshInstance3D.new()
	fb.mesh = sm
	var mat := ShaderMaterial.new()
	mat.shader = FIREBALL_SHADER
	fb.material_override = mat
	fb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fb)
	fb.global_position = at
	effects.append({"node": fb, "t": 0.0, "life": 1.6, "mat": mat, "size": size * 1.4})
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.3)
	light.omni_range = size * 25.0
	add_child(light)
	light.global_position = at
	effects.append({"node": light, "t": 0.0, "life": 1.2, "light": light, "energy": 8.0})
	var p := CPUParticles3D.new()
	p.mesh = _quad
	p.amount = 60
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = 1.8
	p.spread = 180.0
	p.initial_velocity_min = size * 2.0
	p.initial_velocity_max = size * 9.0
	p.gravity = Vector3.ZERO
	p.damping_min = 2.0
	p.damping_max = 6.0
	p.scale_amount_min = size * 0.12
	p.scale_amount_max = size * 0.35
	var grad := Gradient.new()
	grad.set_color(0, Color(4.0, 2.6, 1.2, 1.0))
	grad.set_color(1, Color(0.6, 0.15, 0.05, 0.0))
	p.color_ramp = grad
	add_child(p)
	p.global_position = at
	p.emitting = true
	effects.append({"node": p, "t": 0.0, "life": 2.2})

class_name Interior
extends Node3D
## Begehbare Innenräume.
## Station: hohe Promenade mit Galerie und Panoramafenster, Bar, begehbarer Hangar mit dem eigenen Schiff.
## Schiff: Cockpit, Gang mit Konsolen je Bauteil, Laderaum, Maschinenraum.

const WINDOW_SHADER := preload("res://shaders/window.gdshader")
const ROOM_SHADER := preload("res://shaders/interior.gdshader")
const BP_SHADER := preload("res://shaders/blueprint_table.gdshader")
const TEX_DECK_N := preload("res://textures/deck_n.png")
const TEX_DECK_M := preload("res://textures/deck_m.png")
const TEX_WALL_N := preload("res://textures/wall_n.png")
const TEX_WALL_M := preload("res://textures/wall_m.png")

var env: Environment
var interactables: Array = []   # {pos, r, label, action, arg}
var spawn := Transform3D.IDENTITY
var spawns := {}
var actors: Array = []
var doors: Array = []
var spinners: Array = []
var body: StaticBody3D
var kind := ""
var rng := RandomNumberGenerator.new()
var _t := 0.0
var obstacles: Array = []   # Rect2 im Grundriss (x, z) für die Wegfindung
var nav: AStarGrid2D
var nav_org := Vector2.ZERO
const NAV_CELL := 0.4
const NAV_PAD := 0.38

func _ready() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.012, 0.02)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.72)
	env.ambient_light_energy = 0.8
	env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.06

func clear() -> void:
	for c in get_children():
		c.queue_free()
	interactables = []
	actors = []
	doors = []
	spinners = []
	spawns = {}
	obstacles = []
	nav = null
	body = StaticBody3D.new()
	add_child(body)

# ------------------------------------------------------------------ Bausteine
func collider(size: Vector3, pos: Vector3, rot_y := 0.0) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = pos
	cs.rotation.y = rot_y
	body.add_child(cs)
	if pos.y - size.y * 0.5 < 1.6 and pos.y + size.y * 0.5 > 0.15:
		var c := absf(cos(rot_y))
		var sn := absf(sin(rot_y))
		var ex := c * size.x * 0.5 + sn * size.z * 0.5
		var ez := sn * size.x * 0.5 + c * size.z * 0.5
		obstacles.append(Rect2(pos.x - ex, pos.z - ez, ex * 2.0, ez * 2.0))

# ------------------------------------------------------------------ Wegfindung
## Rastert alle Hindernisse in ein A*-Gitter, damit Figuren um Tische herumlaufen.
func build_nav() -> void:
	var bounds := Rect2()
	var first := true
	for a in actors:
		if a.mode == "walk" or a.kind == "cleaner":
			var r := Rect2(a.area.position.x, a.area.position.z, a.area.size.x, a.area.size.z).grow(1.0)
			bounds = r if first else bounds.merge(r)
			first = false
	if first:
		return
	# Stehende Personen sind ebenfalls Hindernisse (und bekommen eine Kollision)
	for a in actors:
		if (a.kind == "human" or a.kind == "servo") and a.mode != "walk":
			var p: Vector3 = a.node.position
			obstacles.append(Rect2(p.x - 0.3, p.z - 0.3, 0.6, 0.6))
			var cs := CollisionShape3D.new()
			var cy := CylinderShape3D.new()
			cy.radius = 0.3
			cy.height = 1.7
			cs.shape = cy
			cs.position = p + Vector3(0, 0.85, 0)
			body.add_child(cs)
	nav = AStarGrid2D.new()
	nav_org = bounds.position
	var w := int(ceil(bounds.size.x / NAV_CELL))
	var h := int(ceil(bounds.size.y / NAV_CELL))
	nav.region = Rect2i(0, 0, w, h)
	nav.cell_size = Vector2(NAV_CELL, NAV_CELL)
	nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	nav.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	nav.update()
	for o in obstacles:
		var r: Rect2 = (o as Rect2).grow(NAV_PAD)
		var x0 := maxi(0, int(floor((r.position.x - nav_org.x) / NAV_CELL)))
		var x1 := mini(w - 1, int(floor((r.end.x - nav_org.x) / NAV_CELL)))
		var z0 := maxi(0, int(floor((r.position.y - nav_org.y) / NAV_CELL)))
		var z1 := mini(h - 1, int(floor((r.end.y - nav_org.y) / NAV_CELL)))
		for x in range(x0, x1 + 1):
			for z in range(z0, z1 + 1):
				var cc := nav_org + Vector2(x + 0.5, z + 0.5) * NAV_CELL
				if r.has_point(cc):
					nav.set_point_solid(Vector2i(x, z), true)
	for a in actors:
		if a.mode == "walk" or a.kind == "cleaner":
			a.navi = self
			if not nav_free(a.node.position):
				a.node.position = nav_random(a.area, a.node.position.y)
			a.target = a.node.position

func _cell(p: Vector3) -> Vector2i:
	return Vector2i(int(floor((p.x - nav_org.x) / NAV_CELL)), int(floor((p.z - nav_org.y) / NAV_CELL)))

func nav_free(p: Vector3) -> bool:
	if nav == null:
		return true
	var c := _cell(p)
	return nav.is_in_boundsv(c) and not nav.is_point_solid(c)

func nav_random(area: AABB, y := 0.0) -> Vector3:
	for i in 40:
		var p := Vector3(randf_range(area.position.x, area.end.x), y, randf_range(area.position.z, area.end.z))
		if nav_free(p):
			return p
	return area.get_center() * Vector3(1, 0, 1) + Vector3(0, y, 0)

func nav_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	if nav == null:
		out.append(to)
		return out
	var a := _cell(from)
	var b := _cell(to)
	if not nav.is_in_boundsv(a) or not nav.is_in_boundsv(b):
		return out
	var ids := nav.get_id_path(a, b, true)
	# Wegpunkte ausdünnen: nur Richtungswechsel behalten
	var prev_dir := Vector2i.ZERO
	for i in range(1, ids.size()):
		var d: Vector2i = ids[i] - ids[i - 1]
		if d != prev_dir and i > 1:
			var q: Vector2i = ids[i - 1]
			out.append(Vector3(nav_org.x + (q.x + 0.5) * NAV_CELL, from.y, nav_org.y + (q.y + 0.5) * NAV_CELL))
		prev_dir = d
	out.append(Vector3(to.x, from.y, to.z))
	return out

## Fester Block: sichtbar (in Geo g) und begehbar (Kollision)
func solid(g: Geo, size: Vector3, pos: Vector3, r := 0.04, collide := true) -> void:
	g.box(size, r, Geo.at(pos.x, pos.y, pos.z))
	if collide:
		collider(size, pos)

## Raum aus Boden, Decke und Wänden mit Öffnungen. openings: [{side:"n|s|e|w", from, to, h, y0?}]
func room(g: Geo, x0: float, x1: float, z0: float, z1: float, h: float, openings: Array, t := 0.4) -> void:
	solid(g, Vector3(x1 - x0, 0.2, z1 - z0), Vector3((x0 + x1) / 2, -0.1, (z0 + z1) / 2), 0.0)
	solid(g, Vector3(x1 - x0, 0.2, z1 - z0), Vector3((x0 + x1) / 2, h + 0.1, (z0 + z1) / 2), 0.0)
	for side in ["n", "s", "e", "w"]:
		var horiz: bool = side == "n" or side == "s"
		var a0 := x0 if horiz else z0
		var a1 := x1 if horiz else z1
		var fixed: float = (z0 if side == "n" else z1) if horiz else (x1 if side == "e" else x0)
		var fixed_o: float = fixed + (-t / 2 if side in ["n", "w"] else t / 2)
		var ops := []
		for o in openings:
			if o.side == side:
				ops.append(o)
		ops.sort_custom(func(a, b): return a.from < b.from)
		var cur := a0
		for o in ops:
			_wall_seg(g, horiz, cur, float(o.from), fixed_o, 0.0, h, t)
			_wall_seg(g, horiz, float(o.from), float(o.to), fixed_o, float(o.h), h, t)
			if o.has("y0") and float(o.y0) > 0.0:
				_wall_seg(g, horiz, float(o.from), float(o.to), fixed_o, 0.0, float(o.y0), t)
			cur = float(o.to)
		_wall_seg(g, horiz, cur, a1, fixed_o, 0.0, h, t)

func _wall_seg(g: Geo, horiz: bool, a: float, b: float, fixed: float, y0: float, y1: float, t: float) -> void:
	if b - a < 0.01 or y1 - y0 < 0.01:
		return
	var c := (a + b) / 2
	var y := (y0 + y1) / 2
	if horiz:
		solid(g, Vector3(b - a, y1 - y0, t), Vector3(c, y, fixed), 0.0)
	else:
		solid(g, Vector3(t, y1 - y0, b - a), Vector3(fixed, y, c), 0.0)

func room_mat(wall: Color, accent: Color, floor_c := Color(0.2, 0.21, 0.24), ceil_c := Color(0.28, 0.29, 0.32), panel := 1.6, band := 2.65, glow := 1.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = ROOM_SHADER
	m.set_shader_parameter("wall_col", wall)
	m.set_shader_parameter("trim_col", wall.darkened(0.7))
	m.set_shader_parameter("floor_col", floor_c)
	m.set_shader_parameter("ceil_col", ceil_c)
	m.set_shader_parameter("accent", accent)
	m.set_shader_parameter("panel", panel)
	m.set_shader_parameter("band_y", band)
	m.set_shader_parameter("glow", glow)
	m.set_shader_parameter("deck_n", TEX_DECK_N)
	m.set_shader_parameter("deck_m", TEX_DECK_M)
	m.set_shader_parameter("wall_n", TEX_WALL_N)
	m.set_shader_parameter("wall_m", TEX_WALL_M)
	m.set_shader_parameter("ceil_n", ShipBuilder.TEX_HULL_N)
	m.set_shader_parameter("ceil_m", ShipBuilder.TEX_HULL_M)
	return m

func window(size: Vector2, xf: Transform3D, sys_id: String, from_pos := Vector3.ZERO) -> void:
	var q := QuadMesh.new()
	q.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = WINDOW_SHADER
	var sys := Universe.system(sys_id)
	if not sys.is_empty():
		m.set_shader_parameter("neb_a", sys.neb[0])
		m.set_shader_parameter("neb_b", sys.neb[1])
		m.set_shader_parameter("neb_c", sys.neb[2])
		m.set_shader_parameter("band_normal", sys.band)
		var pd: Dictionary = sys.planet
		var rel: Vector3 = (pd.pos as Vector3) - from_pos
		# Planet in Blickrichtung des Fensters rücken, damit man ihn sieht
		var look := -xf.basis.z.normalized()
		var dir := rel.normalized().lerp(look, 0.75).normalized()
		dir = (dir + Vector3(0.0, -0.12, 0.0)).normalized()
		m.set_shader_parameter("planet_dir", dir)
		m.set_shader_parameter("planet_ang", clampf(asin(clampf(float(pd.r) / rel.length(), 0.0, 0.9)) * 0.9, 0.12, 0.42))
		m.set_shader_parameter("planet_kind", int(pd.kind))
		for i in 4:
			m.set_shader_parameter("p%d" % i, pd.c[i])
		m.set_shader_parameter("atmo", pd.atmo)
		m.set_shader_parameter("sun_dir", (sys.sun_dir as Vector3).normalized())
		m.set_shader_parameter("sun_col", sys.sun_color)
	mi.material_override = m
	mi.transform = xf
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func neon(text: String, pos: Vector3, rot_y: float, col: Color, size := 64) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = UIKit.F_BOLD
	l.font_size = size
	l.pixel_size = 0.004
	l.modulate = Color(col.r * 2.2, col.g * 2.2, col.b * 2.2)
	l.outline_size = 0
	l.shaded = false
	l.position = pos
	l.rotation.y = rot_y
	add_child(l)
	return l

func lamp(pos: Vector3, col: Color, energy: float, rng_m: float) -> OmniLight3D:
	var o := OmniLight3D.new()
	o.position = pos
	o.light_color = col
	o.light_energy = energy
	o.omni_range = rng_m
	o.omni_attenuation = 0.9
	o.shadow_enabled = false
	add_child(o)
	return o

func probe(center: Vector3, size: Vector3) -> void:
	var p := ReflectionProbe.new()
	p.position = center
	p.size = size
	p.box_projection = true
	p.interior = true
	p.update_mode = ReflectionProbe.UPDATE_ONCE
	p.intensity = 0.8
	p.ambient_mode = ReflectionProbe.AMBIENT_COLOR
	p.ambient_color = Color(0.3, 0.32, 0.38)
	p.ambient_color_energy = 0.3
	add_child(p)

func add_interact(pos: Vector3, r: float, label: String, action: String, arg := "") -> void:
	interactables.append({"pos": pos, "r": r, "label": label, "action": action, "arg": arg})

func add_actor(a: Actor, pos: Vector3, rot_y := 0.0, mode := "idle") -> Actor:
	a.node.position = pos
	a.node.rotation.y = rot_y
	a.base_rot = rot_y
	a.mode = mode
	a.home = pos
	a.target = pos
	add_child(a.node)
	actors.append(a)
	return a

func label3d(a: Actor, title: String, pname: String) -> void:
	var l := Label3D.new()
	l.text = title + "\n" + pname
	l.font = UIKit.F_SEMI
	l.font_size = 34
	l.pixel_size = 0.004
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = Color(1.15, 1.08, 0.92)
	l.outline_size = 8
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.position = Vector3(0, 2.15, 0)
	a.node.add_child(l)

func door(pos: Vector3, width: float, h: float, along_z: bool, col: Color) -> void:
	var n := Node3D.new()
	n.position = pos
	add_child(n)
	var panels := []
	for sx in [-1.0, 1.0]:
		var p := Node3D.new()
		n.add_child(p)
		var g := Geo.new()
		var sz := Vector3(0.12, h, width / 2) if along_z else Vector3(width / 2, h, 0.12)
		g.box(sz, 0.03, Geo.at(0, h / 2, 0))
		var ge := Geo.new()
		var sl := Vector3(0.14, 0.06, width / 2 * 0.8) if along_z else Vector3(width / 2 * 0.8, 0.06, 0.14)
		ge.box(sl, 0.01, Geo.at(0, h * 0.55, 0))
		g.to_node(p, ShipBuilder.std(Color(0.32, 0.34, 0.38), 0.6, 0.35))
		ge.to_node(p, ShipBuilder.emissive(col, 2.0), false)
		var closed := Vector3(0, 0, sx * width / 4) if along_z else Vector3(sx * width / 4, 0, 0)
		var opened := Vector3(0, 0, sx * width * 0.75) if along_z else Vector3(sx * width * 0.75, 0, 0)
		p.position = closed
		panels.append({"node": p, "closed": closed, "open": opened})
	doors.append({"pos": pos, "panels": panels, "k": 0.0})

func tree(g_trunk: Geo, g_leaf: Geo, p: Vector3, h: float) -> void:
	g_trunk.cyl(0.08, 0.12, 0.0, h, 8, Transform3D(Basis(Vector3.RIGHT, -PI / 2), p))
	for k in 4:
		var a := TAU * k / 4.0 + 0.4
		g_leaf.sphere(0.55 + 0.15 * (k % 2), 10, 6, Geo.at(p.x + cos(a) * 0.35, p.y + h + 0.1 * k, p.z + sin(a) * 0.35))
	g_leaf.sphere(0.6, 10, 6, Geo.at(p.x, p.y + h + 0.45, p.z))

func planter(g: Geo, gt: Geo, gl: Geo, p: Vector3) -> void:
	solid(g, Vector3(1.4, 0.6, 1.4), p + Vector3(0, 0.3, 0), 0.12)
	tree(gt, gl, p + Vector3(0, 0.6, 0), 1.6)

func bench(g: Geo, p: Vector3, along_x: bool) -> void:
	var sz := Vector3(2.6, 0.12, 0.6) if along_x else Vector3(0.6, 0.12, 2.6)
	solid(g, sz, p + Vector3(0, 0.45, 0), 0.04)
	for k in [-1.0, 1.0]:
		var o := Vector3(k * 1.0, 0, 0) if along_x else Vector3(0, 0, k * 1.0)
		g.box(Vector3(0.12, 0.45, 0.5) if along_x else Vector3(0.5, 0.45, 0.12), 0.02, Geo.at(p.x + o.x, 0.22, p.z + o.z))

func update(dt: float, player_pos: Vector3) -> void:
	_t += dt
	for a in actors:
		a.update(dt, player_pos)
	for d in doors:
		var near: bool = player_pos.distance_to(d.pos) < 3.6
		d.k = move_toward(d.k, 1.0 if near else 0.0, dt * 2.5)
		for p in d.panels:
			p.node.position = (p.closed as Vector3).lerp(p.open, d.k)
	for s in spinners:
		s.node.rotate_y(dt * float(s.speed))

## Konstruktionstisch mit leuchtendem Raster und einem kleinen Hologramm des eigenen Schiffs
func _blueprint_table(p: Vector3, ship_bp: Dictionary, ship_paint: Dictionary, gt: Geo, rot := 0.0) -> void:
	var b := Basis(Vector3.UP, rot)
	var w := 2.6
	var d := 1.5
	solid(gt, Vector3(w * 0.8, 0.8, d * 0.7), p + Vector3(0, 0.4, 0), 0.08)
	var top := Geo.new()
	top.box(Vector3(w, 0.1, d), 0.03, Transform3D(b, p + Vector3(0, 0.86, 0)))
	top.to_node(self, ShipBuilder.std(Color(0.12, 0.13, 0.16), 0.6, 0.35))
	var gg := Geo.new()
	gg.box(Vector3(w - 0.16, 0.02, d - 0.16), 0.0, Transform3D(b, p + Vector3(0, 0.92, 0)))
	var gm := ShaderMaterial.new()
	gm.shader = BP_SHADER
	gg.to_node(self, gm, false)
	collider(Vector3(w, 1.0, d), p + Vector3(0, 0.5, 0), rot)
	var holo := ShipBuilder.build(ship_bp, ship_paint)
	for f in holo.get_meta("flames"):
		f.visible = false
	holo.get_meta("eng_light").visible = false
	var aabb := Hangar._aabb(holo, Transform3D.IDENTITY)
	var sc := 1.1 / maxf(aabb.size.z, aabb.size.x)
	var pivot := Node3D.new()
	pivot.position = p + Vector3(0, 1.35, 0)
	add_child(pivot)
	holo.scale = Vector3.ONE * sc
	holo.position = -aabb.get_center() * sc
	pivot.add_child(holo)
	spinners.append({"node": pivot, "speed": 0.5})
	var l := OmniLight3D.new()
	l.light_color = Color(0.45, 0.75, 1.0)
	l.light_energy = 1.2
	l.omni_range = 4.0
	l.position = p + Vector3(0, 1.6, 0)
	add_child(l)
	neon("BLAUPAUSE", p + Vector3(0, 2.4, 0), rot, Color(0.55, 0.8, 1.0), 40)
	add_interact(p + Vector3(0, 1.0, 0), 2.6, "Konstruktionstisch · Schiff entwerfen und umbauen", "blueprint")

func _people_cfg(r: RandomNumberGenerator) -> Dictionary:
	var tops := [Color(0.22, 0.27, 0.35), Color(0.35, 0.18, 0.16), Color(0.2, 0.3, 0.24), Color(0.4, 0.36, 0.3), Color(0.14, 0.14, 0.16), Color(0.5, 0.45, 0.2), Color(0.25, 0.2, 0.35)]
	var pants := [Color(0.12, 0.13, 0.16), Color(0.25, 0.22, 0.18), Color(0.18, 0.2, 0.25), Color(0.3, 0.3, 0.32)]
	return {"top": tops[r.randi() % tops.size()], "pants": pants[r.randi() % pants.size()],
		"accent": [Color(1, 0.71, 0.28), Color(0.62, 0.83, 1.0), Color(0.5, 0.9, 0.55), Color(1, 0.45, 0.6)][r.randi() % 4],
		"pads": r.randf() < 0.3, "cap": r.randf() < 0.2}

# ------------------------------------------------------------------ Station
func build_station(st: Dictionary, ship_bp: Dictionary, ship_paint: Dictionary, has_job: bool) -> void:
	clear()
	kind = "station"
	rng.seed = hash(st.id)
	var accent: Color = st.accent
	var free: bool = st.kind == "freeport"
	var wall_c := Color(0.24, 0.23, 0.27) if free else Color(0.66, 0.68, 0.72)
	var spos: Vector3 = st.pos
	var H := 8.0
	var gr := Geo.new()   # Räume (Raumshader)
	var gt := Geo.new()   # Möbel dunkel
	var gm := Geo.new()   # Metall hell
	var gl := Geo.new()   # Lichtbänder
	var ga := Geo.new()   # Akzentlicht
	var gtr := Geo.new()  # Baumstämme
	var glf := Geo.new()  # Blätter

	# --- Promenade
	room(gr, -16, 16, -12, 12, H, [
		{"side": "n", "from": -10.0, "to": 10.0, "h": 7.0, "y0": 1.0},
		{"side": "e", "from": -2.0, "to": 2.0, "h": 3.4},
		{"side": "w", "from": -2.0, "to": 2.0, "h": 3.8}])
	window(Vector2(20, 6), Transform3D(Basis.IDENTITY, Vector3(0, 4.0, -12.25)), st.sys, spos)
	for x in [-5.0, 0.0, 5.0]:
		solid(gm, Vector3(0.3, 6.0, 0.4), Vector3(x, 4.0, -12.0), 0.06)
	solid(gm, Vector3(20.4, 0.3, 0.5), Vector3(0, 1.0, -11.95), 0.05)
	# Galerie (obere Ebene, nur Optik)
	gm.box(Vector3(32, 0.3, 2.5), 0.05, Geo.at(0, 4.3, 10.75))
	gm.box(Vector3(2.5, 0.3, 24), 0.05, Geo.at(14.75, 4.3, 0))
	gm.box(Vector3(2.5, 0.3, 24), 0.05, Geo.at(-14.75, 4.3, 0))
	for x in range(-15, 16, 3):
		gm.box(Vector3(0.06, 1.0, 0.06), 0.01, Geo.at(x, 4.95, 9.5))
	for x in [-12.0, -6.0, 6.0, 12.0]:
		solid(gm, Vector3(0.3, 4.2, 0.3), Vector3(x, 2.1, 9.55), 0.05)
	for z in range(-11, 12, 3):
		for sx in [-1.0, 1.0]:
			gm.box(Vector3(0.06, 1.0, 0.06), 0.01, Geo.at(sx * 13.5, 4.95, z))
	gm.box(Vector3(30, 0.06, 0.06), 0.01, Geo.at(0, 5.45, 9.5))
	for sx in [-1.0, 1.0]:
		gm.box(Vector3(0.06, 0.06, 22), 0.01, Geo.at(sx * 13.5, 5.45, 0))
	gl.box(Vector3(30, 0.04, 0.06), 0.01, Geo.at(0, 4.13, 9.5))
	var ggal := Geo.new()
	for x in range(-13, 14, 4):
		ggal.box(Vector3(1.6, 2.2, 0.05), 0.02, Geo.at(x, 5.6, 11.75))
	for z in range(-9, 10, 4):
		for sx in [-1.0, 1.0]:
			ggal.box(Vector3(0.05, 2.2, 1.6), 0.02, Geo.at(sx * 15.75, 5.6, z))
	ggal.to_node(self, ShipBuilder.emissive(Color(1.0, 0.8, 0.55).lerp(accent, 0.25) * 0.6, 0.9), false)
	for x in range(-12, 13, 6):
		gl.box(Vector3(0.35, 0.05, 20), 0.01, Geo.at(x, H - 0.03, 0))
	ga.box(Vector3(30, 0.012, 0.08), 0.005, Geo.at(0, 0.006, 0.0))
	# Mitte: Auftragskiosk mit Sternkarte
	var up := Transform3D(Basis(Vector3.RIGHT, -PI / 2), Vector3(0, 0, -2))
	gt.cyl(2.4, 2.5, 0.0, 1.05, 32, up)
	gm.cyl(2.45, 2.45, 1.05, 1.12, 32, up)
	gt.cyl(1.0, 1.2, 0.0, 0.25, 24, up)
	collider(Vector3(4.6, 1.1, 4.6), Vector3(0, 0.55, -2))
	var holo := Node3D.new()
	holo.position = Vector3(0, 2.6, -2)
	add_child(holo)
	var gh := Geo.new()
	gh.torus(1.6, 0.012, 64, 4, Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3.ZERO))
	gh.torus(1.0, 0.01, 48, 4, Transform3D(Basis(Vector3.RIGHT, PI / 2 + 0.3), Vector3.ZERO))
	gh.torus(0.55, 0.01, 40, 4, Transform3D(Basis(Vector3.RIGHT, PI / 2 - 0.2), Vector3.ZERO))
	for i in 14:
		var a := TAU * i / 14.0
		var r := 0.4 + (i % 4) * 0.35
		gh.sphere(0.05, 8, 4, Geo.at(cos(a) * r, sin(a * 3.0) * 0.25, sin(a) * r))
	gh.sphere(0.12, 12, 6, Transform3D.IDENTITY)
	gh.to_node(holo, ShipBuilder.emissive(Color(0.35, 0.7, 1.0), 2.4), false)
	spinners.append({"node": holo, "speed": 0.25})
	var mara := add_actor(Actor.human({"female": true, "top": Color(0.16, 0.22, 0.32), "accent": Color(0.62, 0.83, 1.0), "hair_style": 3, "hair": Color(0.3, 0.18, 0.1), "pads": true}, rng), Vector3(0, 0, -0.6), PI, "idle")
	label3d(mara, "Auftraggeberin", "Mara Lenz")
	add_interact(Vector3(0, 1.0, 1.2), 2.6, "Auftraggeberin Mara · Frachtaufträge", "jobs")
	neon("AUFTRÄGE", Vector3(0, 4.6, -2), 0.0, Color(0.62, 0.83, 1.0), 72)
	# Ausrüster (Süd-Ost)
	solid(gt, Vector3(6.5, 1.05, 1.0), Vector3(8.5, 0.52, 9.0))
	gm.box(Vector3(6.55, 0.05, 1.05), 0.02, Geo.at(8.5, 1.06, 9.0))
	ga.box(Vector3(6.5, 0.03, 0.03), 0.01, Geo.at(8.5, 1.0, 8.49))
	for k in 4:
		var x := 6.0 + k * 1.7
		solid(gm, Vector3(1.2, 0.08, 0.7), Vector3(x, 1.9, 11.4), 0.02, false)
		solid(gm, Vector3(1.2, 0.08, 0.7), Vector3(x, 2.9, 11.4), 0.02, false)
		gm.cyl(0.25, 0.32, -0.4, 0.4, 14, Geo.at(x, 2.25, 11.4))
		gm.cyl(0.08, 0.06, -0.6, -0.4, 8, Geo.at(x, 2.25, 11.4))
		ga.cyl(0.2, 0.2, 0.39, 0.42, 14, Geo.at(x, 2.25, 11.4), true)
	neon("AUSRÜSTER", Vector3(8.5, 3.7, 11.75), PI, Color(1.0, 0.71, 0.28), 72)
	var jonas := add_actor(Actor.human({"female": false, "top": Color(0.32, 0.26, 0.18), "accent": Color(1.0, 0.71, 0.28), "hair_style": 4, "cap": true, "top2": Color(0.6, 0.4, 0.12)}, rng), Vector3(8.5, 0, 10.2), 0.0, "idle")
	label3d(jonas, "Ausrüster", "Jonas Brack")
	add_interact(Vector3(8.5, 1.0, 7.6), 2.6, "Ausrüster Jonas · Teile, Tuning, Reparatur", "shop")
	# Lackiererei (Süd-West)
	solid(gt, Vector3(6.0, 1.05, 1.0), Vector3(-8.5, 0.52, 9.0))
	gm.box(Vector3(6.05, 0.05, 1.05), 0.02, Geo.at(-8.5, 1.06, 9.0))
	ga.box(Vector3(6.0, 0.03, 0.03), 0.01, Geo.at(-8.5, 1.0, 8.49))
	var cols := [Color(0.66, 0.2, 0.17), Color(0.95, 0.76, 0.19), Color(0.18, 0.29, 0.42), Color(0.25, 0.76, 0.79), Color(0.36, 0.39, 0.28), Color(0.85, 0.82, 0.9), Color(0.12, 0.12, 0.14)]
	var gpaint := Geo.new()
	for k in 7:
		gpaint.col = cols[k]
		gpaint.box(Vector3(0.7, 2.2, 0.06), 0.02, Geo.at(-11.4 + k * 0.85, 2.4, 11.75))
	gpaint.to_node(self, Actor.vmat(0.25, 0.3))
	neon("LACKIEREREI", Vector3(-8.5, 3.9, 11.75), PI, Color(1.0, 0.45, 0.6), 66)
	var ida := add_actor(Actor.human({"female": true, "top": Color(0.2, 0.2, 0.23), "accent": Color(1.0, 0.45, 0.6), "hair_style": 1, "hair": Color(0.7, 0.15, 0.2), "visor": true}, rng), Vector3(-8.5, 0, 10.2), 0.0, "idle")
	label3d(ida, "Lackiererin", "Ida Farn")
	add_interact(Vector3(-8.5, 1.0, 7.6), 2.6, "Lackiererin Ida · Schiff gestalten", "paint")
	# Info-Bot am Hangar
	var info := add_actor(Actor.human({"robot": true, "accent": accent.lightened(0.2)}, rng), Vector3(-13.2, 0, 3.6), -PI / 2 + 0.4, "idle")
	label3d(info, "Info-Bot", "IB-12")
	add_interact(Vector3(-12.0, 1.0, 3.2), 2.2, "Info-Bot · Tipps und Hilfe", "info")
	# Bänke, Pflanzen
	for p in [Vector3(-8, 0, -6), Vector3(8, 0, -6), Vector3(-8, 0, 3), Vector3(8, 0, 3)]:
		planter(gt, gtr, glf, p)
	bench(gt, Vector3(-4.5, 0, -8.5), true)
	bench(gt, Vector3(4.5, 0, -8.5), true)
	bench(gt, Vector3(-11.5, 0, -4), false)
	bench(gt, Vector3(11.5, 0, -6), false)
	neon("HANGAR", Vector3(-15.75, 4.3, 0), PI / 2, accent, 64)
	neon("BAR", Vector3(15.75, 3.9, 0), -PI / 2, Color(1.0, 0.5, 0.25), 72)
	neon(String(st.name).to_upper(), Vector3(0, 7.2, -11.75), 0.0, accent, 110)
	door(Vector3(-16.0, 0, 0), 4.0, 3.8, true, accent)
	# Menschen und Roboter
	for i in 5:
		var w := add_actor(Actor.human(_people_cfg(rng), rng), Vector3(rng.randf_range(-10, 10), 0, rng.randf_range(-7, 6)), rng.randf() * TAU, "walk")
		w.area = AABB(Vector3(-12, 0, -9), Vector3(24, 0, 14))
		w.speed = rng.randf_range(0.9, 1.3)
		w._pick_target()
	add_actor(Actor.human(_people_cfg(rng), rng), Vector3(-4.5, 0, -8.5), 0.0, "sit")
	var d1 := add_actor(Actor.drone(accent, rng), Vector3(0, 5.5, 2), 0.0, "fly")
	d1.area = AABB(Vector3(-12, 5.0, -8), Vector3(24, 1.5, 16))
	var d2 := add_actor(Actor.drone(Color(1.0, 0.71, 0.28), rng), Vector3(6, 3.5, -4), 0.0, "fly")
	d2.area = AABB(Vector3(-10, 2.8, -9), Vector3(20, 1.5, 14))
	var cl := add_actor(Actor.cleaner(rng), Vector3(4, 0, 0), 0.0, "clean")
	cl.area = AABB(Vector3(-12, 0, -9), Vector3(24, 0, 15))
	cl._pick_target()

	# --- Bar
	var bar_c := Color(0.3, 0.22, 0.2) if not free else Color(0.18, 0.12, 0.16)
	var grb := Geo.new()
	room(grb, 16, 30, -9, 7, 4.4, [{"side": "w", "from": -9.0, "to": 7.0, "h": 4.4}, {"side": "s", "from": 18.0, "to": 27.0, "h": 3.6, "y0": 0.9}])
	window(Vector2(9, 2.7), Transform3D(Basis(Vector3.UP, PI), Vector3(22.5, 2.25, 7.25)), st.sys, spos)
	solid(gt, Vector3(1.1, 1.1, 9.0), Vector3(26.2, 0.55, -2.5))
	gm.box(Vector3(1.15, 0.06, 9.05), 0.02, Geo.at(26.2, 1.12, -2.5))
	ga.box(Vector3(0.03, 0.03, 9.0), 0.01, Geo.at(25.64, 1.05, -2.5))
	gl.box(Vector3(0.05, 0.04, 8.8), 0.01, Geo.at(25.62, 0.25, -2.5))
	for k in 3:
		solid(gm, Vector3(0.5, 0.06, 8.0), Vector3(29.6, 1.6 + k * 0.6, -2.5), 0.02, false)
	var gbot := Geo.new()
	for k in 3:
		for j in 14:
			gbot.col = [Color(1, 0.5, 0.2), Color(0.4, 1, 0.6), Color(0.5, 0.7, 1), Color(1, 0.3, 0.6), Color(1, 0.9, 0.4)][(j + k) % 5]
			gbot.cyl(0.06, 0.05, 0.0, 0.3, 8, Transform3D(Basis(Vector3.RIGHT, -PI / 2), Vector3(29.5, 1.63 + k * 0.6, -6.0 + j * 0.5)))
	var bm := StandardMaterial3D.new()
	bm.vertex_color_use_as_albedo = true
	bm.emission_enabled = true
	bm.emission = Color(0.6, 0.5, 0.4)
	bm.emission_energy_multiplier = 0.8
	bm.roughness = 0.1
	gbot.to_node(self, bm, false)
	for k in 4:
		var z := -6.0 + k * 2.2
		gm.cyl(0.25, 0.25, 0.0, 0.06, 12, Transform3D(Basis(Vector3.RIGHT, -PI / 2), Vector3(25.0, 0.72, z)))
		gt.cyl(0.04, 0.04, 0.0, 0.72, 6, Transform3D(Basis(Vector3.RIGHT, -PI / 2), Vector3(25.0, 0.0, z)))
	for p in [Vector3(20, 0, -5), Vector3(20, 0, 1), Vector3(23, 0, 4.5)]:
		gt.cyl(0.6, 0.6, 0.72, 0.78, 20, Transform3D(Basis(Vector3.RIGHT, -PI / 2), p))
		gt.cyl(0.08, 0.2, 0.0, 0.72, 8, Transform3D(Basis(Vector3.RIGHT, -PI / 2), p))
		collider(Vector3(1.2, 0.8, 1.2), p + Vector3(0, 0.4, 0))
		ga.torus(0.6, 0.015, 32, 4, Transform3D(Basis(Vector3.RIGHT, PI / 2), p + Vector3(0, 0.78, 0)))
		for sx in [-1.0, 1.0]:
			gm.cyl(0.22, 0.22, 0.42, 0.48, 12, Transform3D(Basis(Vector3.RIGHT, -PI / 2), p + Vector3(sx * 1.0, 0, 0)))
			gt.cyl(0.04, 0.04, 0.0, 0.42, 6, Transform3D(Basis(Vector3.RIGHT, -PI / 2), p + Vector3(sx * 1.0, 0, 0)))
	solid(gt, Vector3(0.9, 1.6, 0.6), Vector3(17.0, 0.8, -8.3), 0.15)
	var gj := Geo.new()
	gj.torus(0.35, 0.04, 24, 6, Transform3D(Basis.IDENTITY, Vector3(17.0, 1.2, -7.98)))
	gj.box(Vector3(0.7, 0.05, 0.02), 0.01, Geo.at(17.0, 0.5, -7.99))
	gj.to_node(self, ShipBuilder.emissive(Color(1.0, 0.3, 0.7), 3.0), false)
	neon("ZUR LETZTEN SCHLEUSE", Vector3(23.0, 3.6, -8.75), 0.0, Color(1.0, 0.5, 0.25), 60)
	var sully := add_actor(Actor.human({"female": false, "top": Color(0.3, 0.16, 0.14), "accent": Color(1.0, 0.5, 0.25), "hair_style": 4, "hair": Color(0.55, 0.55, 0.58)}, rng), Vector3(27.6, 0, -1.0), PI / 2, "wipe")
	label3d(sully, "Barkeeper", "Old Sully")
	add_interact(Vector3(25.0, 1.0, -1.0), 2.4, "Barkeeper Sully · Neuigkeiten & Kopfgeld", "bar")
	var servo := add_actor(Actor.human({"robot": true, "accent": Color(1.0, 0.5, 0.25), "top": Color(0.5, 0.25, 0.15)}, rng), Vector3(27.6, 0, -5.2), PI / 2, "wipe")
	servo.ph = 2.0
	add_actor(Actor.human(_people_cfg(rng), rng), Vector3(19.0, 0, -5), PI / 2, "sit")
	add_actor(Actor.human(_people_cfg(rng), rng), Vector3(21.0, 0, 1), -PI / 2, "sit")
	add_actor(Actor.human(_people_cfg(rng), rng), Vector3(24.4, 0, -6.0), PI / 2, "sit")
	lamp(Vector3(21, 3.8, -4), Color(1.0, 0.75, 0.45), 2.6, 11.0)
	lamp(Vector3(21, 3.8, 3), Color(1.0, 0.6, 0.4), 2.2, 10.0)
	lamp(Vector3(27, 3.6, -2.5), Color(1.0, 0.85, 0.6), 2.4, 9.0)
	grb.to_node(self, room_mat(bar_c, Color(1.0, 0.5, 0.25), Color(0.16, 0.12, 0.1), Color(0.18, 0.14, 0.12), 1.2, 2.9, 0.8))

	# --- Gang und Hangar
	var grh := Geo.new()
	room(grh, -20, -16, -2, 2, 4.0, [{"side": "e", "from": -2.0, "to": 2.0, "h": 3.8}, {"side": "w", "from": -2.0, "to": 2.0, "h": 3.8}])
	room(grh, -54, -20, -17, 17, 14.0, [{"side": "e", "from": -2.0, "to": 2.0, "h": 3.8}, {"side": "w", "from": -12.0, "to": 12.0, "h": 11.0, "y0": 1.0}])
	window(Vector2(24, 10), Transform3D(Basis(Vector3.UP, PI / 2), Vector3(-54.3, 6.0, 0)), st.sys, spos)
	var gfield := Geo.new()
	gfield.box(Vector3(0.05, 10, 24), 0.0, Geo.at(-54.0, 6.0, 0))
	var fm := StandardMaterial3D.new()
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(accent.r, accent.g, accent.b, 0.08)
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	gfield.to_node(self, fm, false)
	collider(Vector3(0.4, 12, 24), Vector3(-54.0, 6.0, 0))
	ga.box(Vector3(0.2, 0.15, 24), 0.03, Geo.at(-53.9, 1.0, 0))
	ga.box(Vector3(0.2, 0.15, 24), 0.03, Geo.at(-53.9, 11.0, 0))
	door(Vector3(-20.0, 0, 0), 4.0, 3.8, true, accent)
	# Landeplattform
	var pad := Vector3(-37, 0, 0)
	gt.cyl(9.5, 9.5, 0.0, 0.08, 48, Transform3D(Basis(Vector3.RIGHT, -PI / 2), pad))
	var gpad := Geo.new()
	gpad.torus(9.0, 0.06, 64, 4, Transform3D(Basis(Vector3.RIGHT, PI / 2), pad + Vector3(0, 0.09, 0)))
	gpad.torus(5.0, 0.04, 48, 4, Transform3D(Basis(Vector3.RIGHT, PI / 2), pad + Vector3(0, 0.09, 0)))
	gpad.to_node(self, ShipBuilder.emissive(Color(1.0, 0.71, 0.28), 1.3), false)
	# Das eigene Schiff in Originalgröße
	var ship := ShipBuilder.build(ship_bp, ship_paint)
	ship.get_meta("load").visible = has_job
	for f in ship.get_meta("flames"):
		f.visible = false
	var aabb := Hangar._aabb(ship, Transform3D.IDENTITY)
	ship.rotation.y = PI / 2
	ship.position = pad + Vector3(-aabb.get_center().z, -aabb.position.y + 0.1, aabb.get_center().x)
	add_child(ship)
	var len_s := aabb.size.z
	var wid_s := aabb.size.x
	collider(Vector3(len_s * 0.92, aabb.size.y, wid_s * 0.9), Vector3(pad.x, aabb.size.y / 2 + 0.1, pad.z))
	var side_z := wid_s / 2 + 1.4
	add_interact(Vector3(pad.x, 1.0, side_z), 3.4, "«%s» · An Bord gehen" % Game.s.name, "board")
	add_interact(Vector3(pad.x, 1.0, -side_z), 3.4, "«%s» · An Bord gehen" % Game.s.name, "board")
	gm.box(Vector3(2.0, 0.12, 2.6), 0.03, Geo.at(pad.x, 0.06, side_z - 0.2))
	ga.box(Vector3(2.0, 0.02, 0.06), 0.01, Geo.at(pad.x, 0.13, side_z + 1.05))
	# Roboter am Schiff
	for p in [[Vector3(pad.x - len_s * 0.3, 0, side_z + 1.6), PI], [Vector3(pad.x + len_s * 0.3, 0, -side_z - 1.6), 0.0]]:
		var w := add_actor(Actor.welder(), p[0], 0.0, "weld")
		w.base_rot = p[1]
		w.ph = rng.randf() * 4.0
		collider(Vector3(1.0, 1.0, 1.0), p[0] + Vector3(0, 0.5, 0))
	var ld := add_actor(Actor.loader(accent), Vector3(-46, 0, -12.5), 0.0, "load")
	ld.path = [Vector3(-46, 0, -12.5), Vector3(-26, 0, -12.5)]
	var dr := add_actor(Actor.drone(accent, rng), Vector3(-30, 6, 6), 0.0, "fly")
	dr.area = AABB(Vector3(-50, 4.0, -14), Vector3(28, 6.0, 28))
	var cl2 := add_actor(Actor.cleaner(rng), Vector3(-25, 0, 6), 0.0, "clean")
	cl2.area = AABB(Vector3(-30, 0, 4), Vector3(8, 0, 8))
	cl2._pick_target()
	# Kisten
	var gcr := Geo.new()
	for i in 10:
		var cx := -50.0 + (i % 5) * 1.6
		var cz := 13.0 + int(i / 5) * 1.7
		var hgt := 2.8 if i % 3 == 0 else 1.4
		gcr.col = Color.html(ShipBuilder.CONTAINER_COLORS[i % 3])
		solid(gcr, Vector3(1.4, hgt, 1.5), Vector3(cx, hgt / 2, cz), 0.04)
	gcr.to_node(self, Actor.vmat(0.55, 0.2))
	# Mechaniker-Roboter R-7 an der Werkbank
	solid(gt, Vector3(3.0, 1.0, 1.0), Vector3(-24, 0.5, 15.6))
	gm.box(Vector3(2.8, 0.05, 0.9), 0.01, Geo.at(-24, 1.02, 15.6))
	for k in 3:
		gm.cyl(0.08, 0.08, 0.0, 0.25, 8, Transform3D(Basis(Vector3.RIGHT, -PI / 2), Vector3(-25 + k * 0.8, 1.05, 15.6)))
	var r7 := add_actor(Actor.human({"robot": true, "accent": Color(0.5, 0.9, 0.55), "top": Color(0.85, 0.6, 0.15)}, rng), Vector3(-24, 0, 14.6), 0.0, "idle")
	label3d(r7, "Mechanik-Einheit", "R-7")
	add_interact(Vector3(-24, 1.0, 13.2), 2.4, "Mechanik-Roboter R-7 · Teile tunen", "tune")
	neon("WERKSTATT", Vector3(-24, 3.0, 16.75), PI, Color(0.5, 0.9, 0.55), 56)
	_blueprint_table(Vector3(-31.0, 0, 12.0), ship_bp, ship_paint, gt, PI)
	neon("HANGAR %d" % (1 + absi(hash(st.id)) % 9), Vector3(-20.25, 8.0, 0), -PI / 2, accent, 140)
	for x in [-46.0, -37.0, -28.0]:
		gl.box(Vector3(0.5, 0.06, 26), 0.02, Geo.at(x, 13.96, 0))
		lamp(Vector3(x, 11.0, 0), Color(1.0, 0.95, 0.88), 4.0, 24.0)
	lamp(Vector3(-37, 2.0, 0), accent, 1.2, 10.0)
	grh.to_node(self, room_mat(wall_c * 0.85, accent, Color(0.18, 0.19, 0.21), Color(0.22, 0.23, 0.26), 2.4, 3.4, 1.0))

	# Promenade-Licht und Materialien
	for p in [Vector3(-9, 7.0, -6), Vector3(9, 7.0, -6), Vector3(-9, 7.0, 6), Vector3(9, 7.0, 6), Vector3(0, 7.0, 0)]:
		lamp(p, Color(1.0, 0.93, 0.85) if not free else accent.lerp(Color.WHITE, 0.4), 3.2, 18.0)
	lamp(Vector3(0, 3.2, -2), Color(0.4, 0.7, 1.0), 1.2, 6.0)
	gr.to_node(self, room_mat(wall_c, accent, Color(0.2, 0.21, 0.24) if not free else Color(0.1, 0.1, 0.12), Color(0.3, 0.31, 0.34), 1.6, 2.65, 1.0))
	gt.to_node(self, ShipBuilder.std(Color(0.14, 0.15, 0.18), 0.45, 0.4))
	gm.to_node(self, ShipBuilder.std(Color(0.55, 0.57, 0.6), 0.7, 0.3))
	gl.to_node(self, ShipBuilder.emissive(Color(1.0, 0.94, 0.85) if not free else accent, 1.8), false)
	ga.to_node(self, ShipBuilder.emissive(accent, 1.2), false)
	gtr.to_node(self, ShipBuilder.std(Color(0.3, 0.2, 0.12), 0.0, 0.9))
	glf.to_node(self, ShipBuilder.std(Color(0.2, 0.48, 0.22), 0.0, 0.7))
	probe(Vector3(0, 4, 0), Vector3(32, 8, 24))
	probe(Vector3(23, 2.2, -1), Vector3(14, 4.4, 16))
	probe(Vector3(-37, 7, 0), Vector3(34, 14, 34))
	spawns["dock"] = Transform3D(Basis(Vector3.UP, 0.4), Vector3(pad.x + 1.5, 0.1, side_z + 2.0))
	spawns["ship"] = spawns["dock"]
	spawns["hall"] = Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(-13.0, 0.1, 0.0))
	spawn = spawns["dock"]
	build_nav()

# ------------------------------------------------------------------ Schiffsinneres
func build_ship(bp: Dictionary, paint: Dictionary, job: Dictionary, sys_id: String) -> void:
	clear()
	kind = "ship"
	rng.seed = 7
	var rows := {}
	var present := {}
	for m in bp.mods:
		present[Game.mod(m[0]).cat] = true
		for c in Game.footprint(m):
			rows[c.y] = true
	var cats := []
	for c in Game.CATS:
		if present.has(c[0]) and not c[0] in ["hull", "wing", "cockpit"]:
			cats.append([c[0], c[1]])
	cats.append(["blueprint", "Blaupause"])
	var st := Game.bp_stats(bp, Game.s.tune)
	var L: float = clampf(roundf(maxf(rows.size() * 1.6 + 2.0, cats.size() * 1.25 + 4.0) / 2.0) * 2.0, 8.0, 22.0)
	var style := clampi(int(float(st.cap) / 30.0), 0, 3)
	var W := 3.2
	var H := 2.6
	var hc := Color.html(paint.hull)
	var ac := Color.html(paint.accent)
	var fc := Game.flame_color(paint, Game.main_engine(bp))
	var gr := Geo.new()
	var gt := Geo.new()
	var gl := Geo.new()
	var ga := Geo.new()
	var gs := Geo.new()
	var gsc := Geo.new()
	var z0 := -L / 2
	var z1 := L / 2
	var cw := 4.4
	var cd := 3.4
	var hw := 5.6
	var hd := 5.0 + style * 1.2
	# Gang
	room(gr, -W / 2, W / 2, z0, z1, H, [{"side": "n", "from": -W / 2, "to": W / 2, "h": H}, {"side": "s", "from": -W / 2, "to": W / 2, "h": H}], 0.2)
	for z in range(int(z0) + 1, int(z1), 2):
		gt.box(Vector3(W + 0.1, 0.18, 0.25), 0.04, Geo.at(0, H - 0.09, z))
		gt.box(Vector3(0.14, H, 0.22), 0.04, Geo.at(-W / 2 + 0.05, H / 2, z))
		gt.box(Vector3(0.14, H, 0.22), 0.04, Geo.at(W / 2 - 0.05, H / 2, z))
	gl.box(Vector3(0.05, 0.02, L), 0.01, Geo.at(-W / 2 + 0.2, 0.012, 0))
	gl.box(Vector3(0.05, 0.02, L), 0.01, Geo.at(W / 2 - 0.2, 0.012, 0))
	gs.box(Vector3(0.4, 0.03, L - 1.0), 0.01, Geo.at(0, H - 0.02, 0))
	# Cockpit
	room(gr, -cw / 2, cw / 2, z0 - cd, z0, H + 0.4, [{"side": "s", "from": -W / 2, "to": W / 2, "h": H}, {"side": "n", "from": -cw / 2, "to": cw / 2, "h": H + 0.1, "y0": 0.9}], 0.2)
	window(Vector2(cw, H - 0.6), Transform3D(Basis.IDENTITY, Vector3(0, 0.9 + (H - 0.6) / 2, z0 - cd - 0.12)), sys_id)
	window(Vector2(cd * 0.7, 1.2), Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(-cw / 2 + 0.01, 1.7, z0 - cd * 0.6)), sys_id)
	window(Vector2(cd * 0.7, 1.2), Transform3D(Basis(Vector3.UP, PI / 2), Vector3(cw / 2 - 0.01, 1.7, z0 - cd * 0.6)), sys_id)
	gt.box(Vector3(cw - 0.4, 0.25, 0.9), 0.05, Transform3D(Basis(Vector3.RIGHT, 0.35), Vector3(0, 1.0, z0 - cd + 0.5)))
	for sx in [-1.0, 0.0, 1.0]:
		gsc.box(Vector3(0.7, 0.4, 0.02), 0.01, Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(sx * 0.9, 1.25, z0 - cd + 0.72)))
	solid(gt, Vector3(0.7, 0.5, 0.7), Vector3(0, 0.25, z0 - 1.4), 0.08)
	gt.box(Vector3(0.7, 1.0, 0.15), 0.06, Transform3D(Basis(Vector3.RIGHT, -0.2), Vector3(0, 1.0, z0 - 1.05)))
	ga.box(Vector3(0.72, 0.05, 0.72), 0.02, Geo.at(0, 0.52, z0 - 1.4))
	add_interact(Vector3(0, 1.0, z0 - 1.6), 1.8, "Pilotensitz · Abdocken", "undock")
	# Schleuse (links, vorne)
	var lz := z0 + 1.6
	ga.box(Vector3(0.1, 2.2, 0.12), 0.02, Geo.at(-W / 2 + 0.03, 1.1, lz - 0.7))
	ga.box(Vector3(0.1, 2.2, 0.12), 0.02, Geo.at(-W / 2 + 0.03, 1.1, lz + 0.7))
	ga.box(Vector3(0.1, 0.12, 1.5), 0.02, Geo.at(-W / 2 + 0.03, 2.2, lz))
	gsc.box(Vector3(0.03, 0.25, 0.25), 0.01, Geo.at(-W / 2 + 0.04, 1.3, lz + 0.95))
	add_interact(Vector3(-W / 2 + 0.6, 1.0, lz), 1.4, "Schleuse · Hangar betreten", "leave")
	# Konsolen für Bauteile
	var slots := cats
	var per_side := int(ceil(slots.size() / 2.0))
	var span := L - 4.0
	for i in slots.size():
		var side := -1.0 if i < per_side else 1.0
		var k := i if i < per_side else i - per_side
		var cnt := per_side if side < 0 else slots.size() - per_side
		var z := z0 + 3.2 + (span - 1.0) * (float(k) + 0.5) / float(cnt)
		if side < 0 and absf(z - lz) < 1.2:
			z += 1.2
		var x := side * (W / 2 - 0.3)
		solid(gt, Vector3(0.45, 1.0, 0.9), Vector3(x, 0.5, z), 0.06)
		gsc.box(Vector3(0.02, 0.32, 0.55), 0.01, Transform3D(Basis(Vector3.FORWARD, side * 0.25), Vector3(x - side * 0.12, 1.3, z)))
		ga.box(Vector3(0.48, 0.05, 0.92), 0.02, Geo.at(x, 1.01, z))
		var ck: String = slots[i][0]
		if ck == "blueprint":
			neon("BLAUPAUSE\nKonstruktion", Vector3(x - side * 0.05, 1.95, z), -side * PI / 2, Color(0.55, 0.8, 1.0), 18)
			add_interact(Vector3(x - side * 0.6, 1.0, z), 1.2, "Konstruktionskonsole · Schiff umbauen", "blueprint")
			continue
		var best := ""
		var n := 0
		for m in bp.mods:
			if Game.mod(m[0]).cat == ck:
				n += 1
				if best == "" or int(Game.mod(m[0]).price) > int(Game.mod(best).price):
					best = m[0]
		var lvl := Game.tune_level(best)
		neon("%s\n%s%s%s" % [String(slots[i][1]).to_upper(), ("%d× " % n) if n > 1 else "", Game.mod(best).n, (" +%d" % lvl) if lvl > 0 else ""], Vector3(x - side * 0.05, 1.95, z), -side * PI / 2, ac.lerp(Color.WHITE, 0.4), 18)
		add_interact(Vector3(x - side * 0.6, 1.0, z), 1.2, "%s · Systemstatus" % slots[i][1], "console", ck)
	# Laderaum
	room(gr, -hw / 2, hw / 2, z1, z1 + hd, H + 0.6, [{"side": "n", "from": -W / 2, "to": W / 2, "h": H}], 0.2)
	gl.box(Vector3(hw - 0.4, 0.02, 0.06), 0.01, Geo.at(0, 0.012, z1 + 0.3))
	if not job.is_empty() and job.get("type", "cargo") == "cargo":
		var n := clampi(int(job.mass / 8.0) + 1, 1, 6)
		var gc := Geo.new()
		for i in n:
			var cx := -1.6 + (i % 3) * 1.6
			var cz := z1 + 1.5 + int(i / 3) * 1.8
			gc.col = Color.html(ShipBuilder.CONTAINER_COLORS[i % 3])
			solid(gc, Vector3(1.3, 1.2, 1.5), Vector3(cx, 0.6, cz), 0.05)
		gc.to_node(self, Actor.vmat(0.55, 0.2))
		neon(String(job.cargo).to_upper(), Vector3(0, 2.4, z1 + hd - 0.12), PI, ac.lerp(Color.WHITE, 0.5), 32)
	else:
		for i in 3:
			gt.box(Vector3(1.4, 0.1, 1.6), 0.03, Geo.at(-1.6 + i * 1.6, 0.05, z1 + 2.0))
		neon("LADERAUM LEER", Vector3(0, 2.4, z1 + hd - 0.12), PI, Color(0.6, 0.6, 0.6), 32)
	var ge := Geo.new()
	ge.cyl(0.5, 0.5, 0.0, 1.8, 16, Transform3D(Basis(Vector3.RIGHT, -PI / 2), Vector3(-1.5, 0.3, z1 + hd - 0.8)))
	ge.cyl(0.5, 0.5, 0.0, 1.8, 16, Transform3D(Basis(Vector3.RIGHT, -PI / 2), Vector3(1.5, 0.3, z1 + hd - 0.8)))
	ge.to_node(self, ShipBuilder.emissive(fc, 2.0), false)
	for k in 6:
		gt.box(Vector3(0.06, 1.9, 0.06), 0.01, Geo.at(-1.5 - 0.6 + k * 0.24, 1.25, z1 + hd - 0.25))
	lamp(Vector3(0, 1.4, z1 + hd - 0.9), fc, 1.2, 5.0)
	var bot := add_actor(Actor.drone(ac, rng), Vector3(0, 1.8, 0), 0.0, "fly")
	bot.area = AABB(Vector3(-0.8, 1.6, z0 + 1.0), Vector3(1.6, 0.5, L - 2.0))
	bot.speed = 0.8

	gr.to_node(self, room_mat(hc.lerp(Color(0.72, 0.74, 0.78), 0.45), ac, Color(0.17, 0.18, 0.2), Color(0.25, 0.26, 0.29), 1.0, 1.9, 0.9))
	gt.to_node(self, ShipBuilder.std(Color(0.16, 0.17, 0.2), 0.5, 0.42))
	gl.to_node(self, ShipBuilder.emissive(ac, 1.5), false)
	ga.to_node(self, ShipBuilder.std(ac, 0.3, 0.45))
	gs.to_node(self, ShipBuilder.emissive(Color(0.9, 0.95, 1.0), 1.1), false)
	gsc.to_node(self, ShipBuilder.emissive(Color(0.15, 0.4, 0.7), 1.0), false)
	for z in range(int(z0), int(z1) + 1, 4):
		lamp(Vector3(0, H - 0.4, z), Color(1.0, 0.95, 0.88), 1.0, 5.0)
	lamp(Vector3(0, 2.0, z0 - cd * 0.5), Color(0.6, 0.8, 1.0), 0.8, 5.0)
	lamp(Vector3(0, 2.2, z1 + hd * 0.5), Color(1.0, 0.9, 0.75), 1.0, 7.0)
	probe(Vector3(0, 1.4, (z0 - cd + z1 + hd) / 2), Vector3(hw, H + 0.8, L + cd + hd))
	spawn = Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(-W / 2 + 0.9, 0.1, lz))
	spawns["ship"] = spawn
	build_nav()

class_name Interior
extends Node3D
## Begehbare Innenräume: Stationsdeck (Händler, Bar, Hangarfenster) und Schiffsinneres (Konsolen, Pilotensitz).

const WINDOW_SHADER := preload("res://shaders/window.gdshader")

var env: Environment
var interactables: Array = []   # {pos, r, label, action, arg}
var spawn := Transform3D.IDENTITY
var people: Array = []
var body: StaticBody3D
var kind := ""
var _t := 0.0

func _ready() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.012, 0.02)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.72)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1

func clear() -> void:
	for c in get_children():
		c.queue_free()
	interactables = []
	people = []
	body = StaticBody3D.new()
	add_child(body)

## Fester Block: sichtbar (in Geo g) und begehbar (Kollision)
func solid(g: Geo, size: Vector3, pos: Vector3, r := 0.04, collide := true) -> void:
	g.box(size, r, Geo.at(pos.x, pos.y, pos.z))
	if collide:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		cs.position = pos
		body.add_child(cs)

func window(size: Vector2, xf: Transform3D, sys_id: String) -> void:
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

func lamp(pos: Vector3, col: Color, energy: float, rng: float) -> void:
	var o := OmniLight3D.new()
	o.position = pos
	o.light_color = col
	o.light_energy = energy
	o.omni_range = rng
	o.shadow_enabled = false
	add_child(o)

func add_interact(pos: Vector3, r: float, label: String, action: String, arg := "") -> void:
	interactables.append({"pos": pos, "r": r, "label": label, "action": action, "arg": arg})

# ------------------------------------------------------------------ Figuren
func person(pos: Vector3, rot_y: float, body_col: Color, accent: Color, title: String, pname: String, wander := false) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = rot_y
	add_child(n)
	var gb := Geo.new()
	var ga := Geo.new()
	var gs := Geo.new()
	for sx in [-1.0, 1.0]:
		gb.box(Vector3(0.17, 0.85, 0.2), 0.05, Geo.at(sx * 0.12, 0.43, 0))
		gb.box(Vector3(0.12, 0.62, 0.13), 0.04, Transform3D(Basis(Vector3.FORWARD, sx * 0.12), Vector3(sx * 0.33, 1.15, 0)))
	gb.frustum(Vector2(0.46, 0.26), Vector2(0.38, 0.22), 0.65, Transform3D(Basis(Vector3.RIGHT, -PI / 2), Vector3(0, 1.2, 0)))
	ga.box(Vector3(0.48, 0.08, 0.28), 0.03, Geo.at(0, 1.0, 0))
	ga.box(Vector3(0.1, 0.4, 0.02), 0.01, Geo.at(0.12, 1.28, -0.12))
	gs.sphere(0.15, 14, 8, Geo.at(0, 1.68, 0))
	gs.box(Vector3(0.1, 0.12, 0.1), 0.02, Geo.at(0, 1.55, 0))
	var gv := Geo.new()
	gv.box(Vector3(0.24, 0.07, 0.04), 0.02, Geo.at(0, 1.7, -0.13))
	gb.to_node(n, ShipBuilder.std(body_col, 0.2, 0.7))
	ga.to_node(n, ShipBuilder.std(accent, 0.3, 0.5))
	gs.to_node(n, ShipBuilder.std(Color(0.78, 0.62, 0.52), 0.0, 0.7))
	gv.to_node(n, ShipBuilder.emissive(accent.lightened(0.3), 2.5), false)
	if title != "":
		var l := Label3D.new()
		l.text = title + "\n" + pname if pname != "" else title
		l.font = UIKit.F_SEMI
		l.font_size = 40
		l.pixel_size = 0.004
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.modulate = Color(1.2, 1.1, 0.9)
		l.outline_size = 8
		l.outline_modulate = Color(0, 0, 0, 0.8)
		l.position = Vector3(0, 2.1, 0)
		l.no_depth_test = false
		n.add_child(l)
	people.append({"node": n, "base_rot": rot_y, "phase": randf() * TAU, "wander": wander, "home": pos, "target": pos, "wait": randf() * 3.0})
	return n

func update(dt: float, player_pos: Vector3) -> void:
	_t += dt
	for p in people:
		var n: Node3D = p.node
		if p.wander:
			var to: Vector3 = p.target - n.position
			to.y = 0.0
			if to.length() < 0.3:
				p.wait -= dt
				if p.wait <= 0.0:
					p.target = p.home + Vector3(randf_range(-6, 6), 0, randf_range(-4, 4))
					p.wait = randf_range(2.0, 6.0)
			else:
				n.position += to.normalized() * dt * 1.1
				n.rotation.y = lerp_angle(n.rotation.y, atan2(-to.x, -to.z), dt * 4.0)
				n.position.y = absf(sin(_t * 7.0 + p.phase)) * 0.04
		else:
			var d := player_pos - n.position
			d.y = 0.0
			var target_rot: float = p.base_rot
			if d.length() < 4.0:
				target_rot = atan2(-d.x, -d.z)
			n.rotation.y = lerp_angle(n.rotation.y, target_rot, dt * 3.0)
			n.position.y = sin(_t * 1.6 + p.phase) * 0.01

# ------------------------------------------------------------------ Stationsdeck
func build_station(st: Dictionary, ship_fit: Dictionary, ship_paint: Dictionary, has_job: bool) -> void:
	clear()
	kind = "station"
	var accent: Color = st.accent
	var free: bool = st.kind == "freeport"
	var wall_c := Color(0.2, 0.2, 0.23) if free else Color(0.62, 0.64, 0.68)
	var gf := Geo.new()   # Boden
	var gw := Geo.new()   # Wände
	var gt := Geo.new()   # Theken, Möbel
	var gl := Geo.new()   # Lichtbänder
	var ga := Geo.new()   # Akzent
	var gp := Geo.new()   # Pflanzen
	var H := 4.4
	# Boden, Decke
	solid(gf, Vector3(24, 0.2, 18), Vector3(0, -0.1, 0))
	solid(gw, Vector3(24, 0.2, 18), Vector3(0, H + 0.1, 0))
	for x in range(-10, 11, 4):
		gl.box(Vector3(0.25, 0.04, 14), 0.01, Geo.at(x, H - 0.02, 0))
	# Nordwand mit Panoramafenster
	solid(gw, Vector3(24, 0.8, 0.4), Vector3(0, 0.4, -9.2))
	solid(gw, Vector3(24, 0.4, 0.4), Vector3(0, H - 0.2, -9.2))
	solid(gw, Vector3(4, H, 0.4), Vector3(-10, H / 2, -9.2))
	solid(gw, Vector3(4, H, 0.4), Vector3(10, H / 2, -9.2))
	for x in [-4.0, 0.0, 4.0]:
		solid(gt, Vector3(0.25, H, 0.5), Vector3(x, H / 2, -9.1))
	window(Vector2(16, H - 1.2), Transform3D(Basis.IDENTITY, Vector3(0, 0.8 + (H - 1.2) / 2, -9.35)), st.sys)
	# Ostwand
	solid(gw, Vector3(0.4, H, 18), Vector3(12.2, H / 2, 0))
	# Südwand
	solid(gw, Vector3(24, H, 0.4), Vector3(0, H / 2, 9.2))
	# Westwand mit Hangarfenster und Schleuse
	solid(gw, Vector3(0.4, 0.7, 13), Vector3(-12.2, 0.35, -2.5))
	solid(gw, Vector3(0.4, 0.6, 18), Vector3(-12.2, H - 0.3, 0))
	solid(gw, Vector3(0.4, H, 3), Vector3(-12.2, H / 2, -7.5))
	solid(gw, Vector3(0.4, H, 2.2), Vector3(-12.2, H / 2, 4.9))
	solid(gw, Vector3(0.4, H, 1.4), Vector3(-12.2, H / 2, 8.3))
	var glass := ShipBuilder.std(Color(0.1, 0.16, 0.2), 0.9, 0.05)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.12, 0.2, 0.26, 0.18)
	var gg := Geo.new()
	solid(gg, Vector3(0.05, H - 1.3, 10), Vector3(-12.2, 0.7 + (H - 1.3) / 2, -1.0), 0.0)
	gg.to_node(self, glass, false)
	# Schleusentür
	ga.box(Vector3(0.2, 2.6, 0.15), 0.03, Geo.at(-12.1, 1.3, 6.0))
	ga.box(Vector3(0.2, 2.6, 0.15), 0.03, Geo.at(-12.1, 1.3, 7.6))
	ga.box(Vector3(0.2, 0.15, 1.75), 0.03, Geo.at(-12.1, 2.6, 6.8))
	gl.box(Vector3(0.05, 0.08, 1.4), 0.01, Geo.at(-12.0, 2.45, 6.8))
	add_interact(Vector3(-11.3, 1.0, 6.8), 2.2, "Schleuse · An Bord gehen", "board")
	neon("HANGAR", Vector3(-12.0, 3.2, 6.8), PI / 2, accent, 48)
	# Hangarbucht hinter dem Fenster mit dem eigenen Schiff
	var gh := Geo.new()
	gh.box(Vector3(30, 0.4, 30), 0.1, Geo.at(-28, -2.2, -1))
	gh.box(Vector3(0.6, 16, 30), 0.1, Geo.at(-43, 5, -1))
	gh.box(Vector3(30, 0.6, 30), 0.1, Geo.at(-28, 12, -1))
	gh.box(Vector3(30, 16, 0.6), 0.1, Geo.at(-28, 5, -16))
	gh.box(Vector3(30, 16, 0.6), 0.1, Geo.at(-28, 5, 14))
	for z in [-10.0, -1.0, 8.0]:
		gl.box(Vector3(18, 0.1, 0.4), 0.02, Geo.at(-28, 11.6, z))
	gh.to_node(self, ShipBuilder.std(wall_c * 0.6, 0.5, 0.5))
	var ship := ShipBuilder.build(ship_fit, ship_paint)
	ship.get_meta("load").visible = has_job
	for f in ship.get_meta("flames"):
		f.visible = false
	ship.position = Vector3(-28, 1.2, -1)
	ship.rotation.y = PI / 2 + 0.35
	var sc: float = 14.0 / maxf(float(Game.part("frame", ship_fit.frame).dim.z), 11.0)
	ship.scale = Vector3.ONE * minf(1.0, sc)
	add_child(ship)
	lamp(Vector3(-28, 9, -1), Color(1.0, 0.92, 0.8), 3.0, 30.0)
	lamp(Vector3(-20, 3, 6), accent, 1.5, 14.0)
	# Auftragsbrett (Ost)
	solid(gt, Vector3(1.0, 1.05, 4.0), Vector3(10.6, 0.52, -2.5))
	ga.box(Vector3(1.05, 0.06, 4.05), 0.02, Geo.at(10.6, 1.06, -2.5))
	var gholo := Geo.new()
	gholo.box(Vector3(0.05, 2.0, 3.6), 0.01, Geo.at(11.95, 2.6, -2.5))
	gholo.to_node(self, ShipBuilder.emissive(Color(0.2, 0.45, 0.8), 0.9), false)
	neon("AUFTRÄGE", Vector3(11.9, 3.85, -2.5), -PI / 2, Color(0.62, 0.83, 1.0), 64)
	person(Vector3(11.4, 0, -2.5), -PI / 2, Color(0.18, 0.22, 0.3), Color(0.62, 0.83, 1.0), "Auftraggeberin", "Mara Lenz")
	add_interact(Vector3(9.6, 1.0, -2.5), 2.4, "Auftraggeberin Mara · Frachtaufträge", "jobs")
	# Ausrüster (Süd-Ost)
	solid(gt, Vector3(4.5, 1.05, 1.0), Vector3(5.5, 0.52, 7.8))
	ga.box(Vector3(4.55, 0.06, 1.05), 0.02, Geo.at(5.5, 1.06, 7.8))
	for k in 4:
		solid(gt, Vector3(0.9, 0.9, 0.6), Vector3(3.8 + k * 1.15, 1.6, 8.7), 0.05, false)
		gl.box(Vector3(0.5, 0.05, 0.3), 0.01, Geo.at(3.8 + k * 1.15, 2.1, 8.6))
	neon("AUSRÜSTER", Vector3(5.5, 3.6, 8.95), PI, Color(1.0, 0.71, 0.28), 64)
	person(Vector3(5.5, 0, 8.5), PI, Color(0.32, 0.28, 0.22), Color(1.0, 0.71, 0.28), "Ausrüster", "Jonas Brack")
	add_interact(Vector3(5.5, 1.0, 6.7), 2.4, "Ausrüster Jonas · Teile kaufen & reparieren", "shop")
	# Lackierer (Süd-West)
	solid(gt, Vector3(4.0, 1.05, 1.0), Vector3(-5.5, 0.52, 7.8))
	var gcol := Geo.new()
	var cols := [Color(0.66, 0.2, 0.17), Color(0.95, 0.76, 0.19), Color(0.18, 0.29, 0.42), Color(0.25, 0.76, 0.79), Color(0.36, 0.39, 0.28), Color(0.85, 0.82, 0.9)]
	for k in 6:
		var gk := Geo.new()
		gk.box(Vector3(0.55, 1.6, 0.06), 0.02, Geo.at(-7.4 + k * 0.72, 2.2, 8.95))
		gk.to_node(self, ShipBuilder.std(cols[k], 0.3, 0.35))
	neon("LACKIEREREI", Vector3(-5.5, 3.6, 8.95), PI, Color(1.0, 0.45, 0.6), 60)
	person(Vector3(-5.5, 0, 8.5), PI, Color(0.25, 0.25, 0.27), Color(1.0, 0.45, 0.6), "Lackiererin", "Ida Farn")
	add_interact(Vector3(-5.5, 1.0, 6.7), 2.4, "Lackiererin Ida · Schiff gestalten", "paint")
	# Bar (Nord-Ost)
	solid(gt, Vector3(5.0, 1.1, 1.0), Vector3(8.5, 0.55, -6.2))
	ga.box(Vector3(5.05, 0.07, 1.1), 0.02, Geo.at(8.5, 1.12, -6.2))
	gl.box(Vector3(4.8, 0.04, 0.05), 0.01, Geo.at(8.5, 0.3, -5.68))
	for k in 5:
		var gb2 := Geo.new()
		gb2.cyl(0.07, 0.07, 0.0, 0.28, 8, Transform3D(Basis(Vector3.RIGHT, -PI / 2), Vector3(6.6 + k * 0.9, 1.15, -6.4)))
		gb2.to_node(self, ShipBuilder.emissive([Color(1, 0.5, 0.2), Color(0.4, 1, 0.6), Color(0.5, 0.7, 1), Color(1, 0.3, 0.6), Color(1, 0.9, 0.4)][k], 1.5), false)
	for k in 4:
		gt.cyl(0.25, 0.25, 0.0, 0.08, 12, Transform3D(Basis(Vector3.RIGHT, -PI / 2), Vector3(6.8 + k * 1.2, 0.75, -5.3)))
		gt.cyl(0.05, 0.05, 0.0, 0.75, 6, Transform3D(Basis(Vector3.RIGHT, -PI / 2), Vector3(6.8 + k * 1.2, 0.0, -5.3)))
	neon("BAR · ZUR LETZTEN SCHLEUSE", Vector3(8.5, 3.4, -8.95), 0.0, Color(1.0, 0.5, 0.25), 48)
	person(Vector3(8.5, 0, -7.2), 0.0, Color(0.3, 0.16, 0.14), Color(1.0, 0.5, 0.25), "Barkeeper", "Old Sully")
	add_interact(Vector3(8.5, 1.0, -5.2), 2.4, "Barkeeper Sully · Neuigkeiten & Kopfgeld", "bar")
	# Mitte: Säulen, Bänke, Pflanzen
	for p in [Vector3(-4, 0, -3), Vector3(4, 0, -3), Vector3(-4, 0, 3), Vector3(4, 0, 3)]:
		solid(gw, Vector3(0.7, H, 0.7), p + Vector3(0, H / 2, 0), 0.1)
		gl.box(Vector3(0.74, 0.06, 0.74), 0.01, Geo.at(p.x, 2.6, p.z))
	for p in [Vector3(0, 0, -1.5), Vector3(0, 0, 1.5)]:
		solid(gt, Vector3(3.0, 0.45, 0.6), p + Vector3(0, 0.22, 0), 0.08)
	for p in [Vector3(-9, 0, -7.5), Vector3(-1.8, 0, -7.8), Vector3(1.8, 0, -7.8)]:
		solid(gt, Vector3(0.9, 0.7, 0.9), p + Vector3(0, 0.35, 0), 0.1)
		for k in 6:
			var a := TAU * k / 6.0
			gp.frustum(Vector2(0.18, 0.05), Vector2(0.02, 0.02), 1.2, Transform3D(Basis(Vector3(cos(a), 0, sin(a)).cross(Vector3.UP).normalized(), 0.5) * Basis(Vector3.RIGHT, -PI / 2), p + Vector3(cos(a) * 0.2, 1.1, sin(a) * 0.2)))
	# Bodenleitlinien
	gl.box(Vector3(0.12, 0.02, 14), 0.01, Geo.at(-8, 0.01, 0))
	gl.box(Vector3(0.12, 0.02, 14), 0.01, Geo.at(8, 0.01, 0))
	# Passanten
	person(Vector3(-2, 0, 0), 0.0, Color(0.4, 0.42, 0.45), accent, "", "", true)
	person(Vector3(2, 0, -5), 1.0, Color(0.22, 0.3, 0.26), Color(0.5, 0.9, 0.6), "", "", true)
	person(Vector3(-7.4, 0, -5.4), 0.6, Color(0.35, 0.25, 0.35), Color(1, 0.7, 0.4), "", "")

	gf.to_node(self, ShipBuilder.hull_mat(Color(0.22, 0.23, 0.26) if not free else Color(0.1, 0.1, 0.12), accent, 0, Vector3(12, 1, 9), 0.6, 0.3, 0.45, 0.5))
	gw.to_node(self, ShipBuilder.hull_mat(wall_c, accent, 0, Vector3(12, 3, 9), 0.9, 0.15, 0.6, 0.6))
	gt.to_node(self, ShipBuilder.std(Color(0.16, 0.17, 0.2), 0.4, 0.45))
	gl.to_node(self, ShipBuilder.emissive(Color(1.0, 0.92, 0.8) if not free else accent, 1.6), false)
	ga.to_node(self, ShipBuilder.emissive(accent, 0.9), false)
	gp.to_node(self, ShipBuilder.std(Color(0.2, 0.45, 0.22), 0.0, 0.8))
	for p in [Vector3(-6, 3.8, -4), Vector3(6, 3.8, -4), Vector3(-6, 3.8, 4), Vector3(6, 3.8, 4), Vector3(0, 3.8, 0)]:
		lamp(p, Color(1.0, 0.93, 0.85) if not free else accent.lerp(Color.WHITE, 0.4), 1.4, 9.0)
	neon(String(st.name).to_upper(), Vector3(0, 3.9, 8.95), PI, accent, 80)
	spawn = Transform3D(Basis(Vector3.UP, -PI / 2 - 0.5), Vector3(-9.5, 0.1, 6.0))

# ------------------------------------------------------------------ Schiffsinneres
func build_ship(fit: Dictionary, paint: Dictionary, job: Dictionary, sys_id: String) -> void:
	clear()
	kind = "ship"
	var F := Game.part("frame", fit.frame)
	var style := int(F.style)
	var L: float = [10.0, 14.0, 12.0, 18.0][style]
	var W := 3.2
	var H := 2.6
	var hc := Color.html(paint.hull)
	var ac := Color.html(paint.accent)
	var fc := Game.flame_color(paint, fit.engine)
	var gf := Geo.new()
	var gw := Geo.new()
	var gt := Geo.new()
	var gl := Geo.new()
	var ga := Geo.new()
	var gs := Geo.new()
	var gsc := Geo.new()
	var z0 := -L / 2
	var z1 := L / 2
	# Korridor
	solid(gf, Vector3(W, 0.2, L), Vector3(0, -0.1, 0))
	solid(gw, Vector3(W, 0.2, L), Vector3(0, H + 0.1, 0))
	solid(gw, Vector3(0.2, H, L), Vector3(-W / 2 - 0.1, H / 2, 0))
	solid(gw, Vector3(0.2, H, L), Vector3(W / 2 + 0.1, H / 2, 0))
	for z in range(int(z0) + 1, int(z1), 2):
		gt.box(Vector3(W + 0.1, 0.18, 0.25), 0.04, Geo.at(0, H - 0.09, z))
		gt.box(Vector3(0.18, H, 0.25), 0.04, Geo.at(-W / 2 + 0.05, H / 2, z))
		gt.box(Vector3(0.18, H, 0.25), 0.04, Geo.at(W / 2 - 0.05, H / 2, z))
	gl.box(Vector3(0.06, 0.03, L), 0.01, Geo.at(-W / 2 + 0.2, 0.02, 0))
	gl.box(Vector3(0.06, 0.03, L), 0.01, Geo.at(W / 2 - 0.2, 0.02, 0))
	gs.box(Vector3(0.5, 0.03, L - 1.0), 0.01, Geo.at(0, H - 0.02, 0))
	# Cockpit
	var cw := 4.4
	var cd := 3.4
	solid(gf, Vector3(cw, 0.2, cd), Vector3(0, -0.1, z0 - cd / 2))
	solid(gw, Vector3(cw, 0.2, cd), Vector3(0, H + 0.3, z0 - cd / 2))
	solid(gw, Vector3(0.2, H + 0.4, cd), Vector3(-cw / 2 - 0.1, H / 2, z0 - cd / 2))
	solid(gw, Vector3(0.2, H + 0.4, cd), Vector3(cw / 2 + 0.1, H / 2, z0 - cd / 2))
	solid(gw, Vector3((cw - W) / 2, H, 0.2), Vector3(-(W + cw) / 4, H / 2, z0))
	solid(gw, Vector3((cw - W) / 2, H, 0.2), Vector3((W + cw) / 4, H / 2, z0))
	solid(gw, Vector3(cw, 0.9, 0.3), Vector3(0, 0.45, z0 - cd - 0.15))
	window(Vector2(cw, H - 0.7), Transform3D(Basis.IDENTITY, Vector3(0, 0.9 + (H - 0.7) / 2, z0 - cd - 0.05)), sys_id)
	window(Vector2(cd * 0.7, 1.2), Transform3D(Basis(Vector3.UP, PI / 2), Vector3(-cw / 2 + 0.01, 1.7, z0 - cd * 0.6)), sys_id)
	window(Vector2(cd * 0.7, 1.2), Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(cw / 2 - 0.01, 1.7, z0 - cd * 0.6)), sys_id)
	gt.box(Vector3(cw - 0.4, 0.25, 0.9), 0.05, Transform3D(Basis(Vector3.RIGHT, 0.35), Vector3(0, 1.0, z0 - cd + 0.5)))
	for sx in [-1.0, 0.0, 1.0]:
		gsc.box(Vector3(0.7, 0.4, 0.02), 0.01, Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(sx * 0.9, 1.25, z0 - cd + 0.72)))
	solid(gt, Vector3(0.7, 0.5, 0.7), Vector3(0, 0.25, z0 - 1.4), 0.08)
	gt.box(Vector3(0.7, 1.0, 0.15), 0.06, Transform3D(Basis(Vector3.RIGHT, -0.2), Vector3(0, 1.0, z0 - 1.05)))
	ga.box(Vector3(0.72, 0.05, 0.72), 0.02, Geo.at(0, 0.52, z0 - 1.4))
	add_interact(Vector3(0, 1.0, z0 - 1.6), 1.8, "Pilotensitz · Abdocken", "undock")
	# Schleuse (links, vorne)
	var lz := z0 + 1.6
	ga.box(Vector3(0.12, 2.2, 0.12), 0.02, Geo.at(-W / 2 + 0.02, 1.1, lz - 0.7))
	ga.box(Vector3(0.12, 2.2, 0.12), 0.02, Geo.at(-W / 2 + 0.02, 1.1, lz + 0.7))
	ga.box(Vector3(0.12, 0.12, 1.5), 0.02, Geo.at(-W / 2 + 0.02, 2.2, lz))
	gs.box(Vector3(0.03, 0.25, 0.25), 0.01, Geo.at(-W / 2 + 0.03, 1.3, lz + 0.95))
	add_interact(Vector3(-W / 2 + 0.6, 1.0, lz), 1.4, "Schleuse · Station betreten", "leave")
	# Konsolen für Bauteile
	var slots := [["engine", "Triebwerk"], ["rcs", "Düsen"], ["weapon", "Waffen"], ["shield", "Schild"], ["cargo", "Frachtmodul"], ["armor", "Panzerung"], ["extra", "Extra"]]
	var per_side := 4
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
		var part := Game.part(slots[i][0], fit[slots[i][0]])
		neon("%s\n%s" % [String(slots[i][1]).to_upper(), part.n], Vector3(x - side * 0.05, 1.95, z), -side * PI / 2, ac.lerp(Color.WHITE, 0.4), 18)
		add_interact(Vector3(x - side * 0.6, 1.0, z), 1.2, "%s · %s tauschen" % [slots[i][1], part.n], "console", slots[i][0])
	# Laderaum hinten
	var hw := 5.6
	var hd := 5.0 + style * 1.2
	solid(gf, Vector3(hw, 0.2, hd), Vector3(0, -0.1, z1 + hd / 2))
	solid(gw, Vector3(hw, 0.2, hd), Vector3(0, H + 0.6, z1 + hd / 2))
	solid(gw, Vector3(0.2, H + 0.8, hd), Vector3(-hw / 2 - 0.1, H / 2, z1 + hd / 2))
	solid(gw, Vector3(0.2, H + 0.8, hd), Vector3(hw / 2 + 0.1, H / 2, z1 + hd / 2))
	solid(gw, Vector3((hw - W) / 2, H, 0.2), Vector3(-(W + hw) / 4, H / 2, z1))
	solid(gw, Vector3((hw - W) / 2, H, 0.2), Vector3((W + hw) / 4, H / 2, z1))
	solid(gw, Vector3(hw, H + 0.8, 0.2), Vector3(0, H / 2, z1 + hd + 0.1))
	gl.box(Vector3(hw - 0.4, 0.03, 0.06), 0.01, Geo.at(0, 0.02, z1 + 0.3))
	if not job.is_empty() and job.get("type", "cargo") == "cargo":
		var n := clampi(int(job.mass / 8.0) + 1, 1, 6)
		for i in n:
			var gc := Geo.new()
			var cx := -1.6 + (i % 3) * 1.6
			var cz := z1 + 1.5 + int(i / 3) * 1.8
			solid(gc, Vector3(1.3, 1.2, 1.5), Vector3(cx, 0.6, cz), 0.05)
			gc.to_node(self, ShipBuilder.hull_mat(Color.html(ShipBuilder.CONTAINER_COLORS[i % 3]), Color.WHITE, 6, Vector3(0.65, 0.6, 0.75), 1.0, 0.3, 0.6, 0.6))
		neon(String(job.cargo).to_upper(), Vector3(0, 2.4, z1 + hd - 0.05), PI, ac.lerp(Color.WHITE, 0.5), 36)
	else:
		for i in 3:
			gt.box(Vector3(1.4, 0.1, 1.6), 0.03, Geo.at(-1.6 + i * 1.6, 0.05, z1 + 2.0))
		neon("LADERAUM LEER", Vector3(0, 2.4, z1 + hd - 0.05), PI, Color(0.6, 0.6, 0.6), 36)
	# Maschinenraum-Gitter mit Triebwerksglühen
	var ge := Geo.new()
	ge.cyl(0.5, 0.5, 0.0, 1.8, 16, Transform3D(Basis(Vector3.RIGHT, -PI / 2), Vector3(-1.5, 0.3, z1 + hd - 0.8)))
	ge.cyl(0.5, 0.5, 0.0, 1.8, 16, Transform3D(Basis(Vector3.RIGHT, -PI / 2), Vector3(1.5, 0.3, z1 + hd - 0.8)))
	ge.to_node(self, ShipBuilder.emissive(fc, 3.0), false)
	for k in 6:
		gt.box(Vector3(0.06, 1.9, 0.06), 0.01, Geo.at(-1.5 - 0.6 + k * 0.24, 1.25, z1 + hd - 0.2))
	lamp(Vector3(0, 1.4, z1 + hd - 0.9), fc, 1.2, 5.0)

	gf.to_node(self, ShipBuilder.hull_mat(Color(0.2, 0.21, 0.24), ac, 0, Vector3(2, 1, L / 2), 1.6, 0.35, 0.5, 0.6))
	gw.to_node(self, ShipBuilder.hull_mat(hc.lerp(Color(0.7, 0.72, 0.75), 0.4), ac, 1, Vector3(2, 1.3, L / 2), 1.3, 0.15, 0.55, 0.5))
	gt.to_node(self, ShipBuilder.std(Color(0.18, 0.19, 0.22), 0.5, 0.45))
	gl.to_node(self, ShipBuilder.emissive(ac, 2.2), false)
	ga.to_node(self, ShipBuilder.std(ac, 0.3, 0.45))
	gs.to_node(self, ShipBuilder.emissive(Color(0.9, 0.95, 1.0), 1.1), false)
	gsc.to_node(self, ShipBuilder.emissive(Color(0.15, 0.4, 0.7), 1.0), false)
	for z in range(int(z0), int(z1) + 1, 4):
		lamp(Vector3(0, H - 0.4, z), Color(1.0, 0.95, 0.88), 0.9, 5.0)
	lamp(Vector3(0, 2.0, z0 - cd * 0.5), Color(0.6, 0.8, 1.0), 0.8, 5.0)
	lamp(Vector3(0, 2.2, z1 + hd * 0.5), Color(1.0, 0.9, 0.75), 1.0, 7.0)
	spawn = Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(-W / 2 + 0.9, 0.1, lz))

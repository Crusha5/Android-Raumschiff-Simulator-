class_name Actor
extends RefCounted
## Figuren und Roboter für Innenräume: gegliederte Menschen mit Gesicht und Animation,
## Drohnen, Putzroboter, Servo-Bots, Lader und Schweißarme.

const SKIN := [Color(0.96, 0.8, 0.69), Color(0.87, 0.66, 0.5), Color(0.72, 0.5, 0.36), Color(0.52, 0.34, 0.24), Color(0.36, 0.23, 0.16)]
const HAIR := [Color(0.08, 0.06, 0.05), Color(0.3, 0.18, 0.1), Color(0.62, 0.42, 0.2), Color(0.85, 0.7, 0.42), Color(0.55, 0.55, 0.58), Color(0.7, 0.15, 0.2), Color(0.2, 0.45, 0.75)]

var node: Node3D
var kind := "human"
var mode := "idle"
var bones := {}
var t := 0.0
var phase := 0.0
var ph := 0.0
var home := Vector3.ZERO
var target := Vector3.ZERO
var wait := 0.0
var speed := 1.1
var area := AABB()
var base_rot := 0.0
var talk := 0.0
var path: Array = []
var path_i := 0
var mats := {}
var navi: Object = null
var route := PackedVector3Array()
var route_i := 0
var blocked := 0.0
var height := 0.0

static func vmat(rough := 0.6, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = rough
	m.metallic = metal
	return m

static func _limb(g: Geo, length: float, r0: float, r1: float, offset := Vector3.ZERO) -> void:
	var xf := Transform3D(Basis(Vector3.RIGHT, PI / 2), offset)
	g.cyl(r0, r1, 0.0, length, 12, xf, false)
	g.sphere(r0, 10, 6, Geo.at(offset.x, offset.y, offset.z))
	g.sphere(r1, 10, 6, Geo.at(offset.x, offset.y - length, offset.z))

static func _bone(parent: Node3D, pos: Vector3, nm: String) -> Node3D:
	var b := Node3D.new()
	b.name = nm
	b.position = pos
	parent.add_child(b)
	return b

## cfg: skin, hair, hair_style, top, top2, pants, boots, accent, robot(bool), female(bool), visor(bool), pads(bool)
static func human(cfg: Dictionary, rng: RandomNumberGenerator) -> Actor:
	var a := Actor.new()
	a.kind = "servo" if cfg.get("robot", false) else "human"
	a.ph = rng.randf() * TAU
	var robot: bool = cfg.get("robot", false)
	var skin: Color = cfg.get("skin", SKIN[rng.randi() % SKIN.size()])
	var hair: Color = cfg.get("hair", HAIR[rng.randi() % HAIR.size()])
	var top: Color = cfg.get("top", Color(0.2, 0.24, 0.3))
	var top2: Color = cfg.get("top2", top.lightened(0.25))
	var pants: Color = cfg.get("pants", Color(0.15, 0.16, 0.18))
	var boots: Color = cfg.get("boots", Color(0.08, 0.08, 0.09))
	var accent: Color = cfg.get("accent", Color(1.0, 0.71, 0.28))
	var female: bool = cfg.get("female", rng.randf() < 0.5)
	var metal := Color(0.62, 0.65, 0.7)
	if robot:
		skin = metal
		top = cfg.get("top", Color(0.85, 0.86, 0.88))
		top2 = Color(0.3, 0.32, 0.36)
		pants = Color(0.3, 0.32, 0.36)
		boots = Color(0.2, 0.21, 0.24)
	var root := Node3D.new()
	a.node = root
	var mat := vmat(0.35 if robot else 0.62, 0.6 if robot else 0.0)
	var emis := StandardMaterial3D.new()
	emis.vertex_color_use_as_albedo = true
	emis.emission_enabled = true
	emis.emission = accent
	emis.emission_energy_multiplier = 2.2
	a.mats["emis"] = emis
	var sw := 0.9 if female else 1.0   # Schulterbreite
	var hips := _bone(root, Vector3(0, 0.95, 0), "hips")
	var torso := _bone(hips, Vector3.ZERO, "torso")
	var g := Geo.new()
	# Becken und Gürtel
	g.col = pants
	g.box(Vector3(0.33 * (1.04 if female else 1.0), 0.18, 0.2), 0.05, Geo.at(0, 0.02, 0))
	g.col = Color(0.1, 0.09, 0.08) if not robot else accent.darkened(0.3)
	g.box(Vector3(0.35, 0.05, 0.215), 0.015, Geo.at(0, 0.11, 0))
	g.col = accent
	g.box(Vector3(0.06, 0.04, 0.02), 0.005, Geo.at(0, 0.11, -0.11))
	# Oberkörper
	g.col = top
	var chest_xf := Transform3D(Basis(Vector3.RIGHT, -PI / 2), Vector3(0, 0.34, 0))
	g.frustum(Vector2(0.42 * sw, 0.23), Vector2(0.31, 0.2), 0.46, chest_xf)
	if female and not robot:
		g.sphere(0.055, 10, 6, Geo.at(-0.07, 0.4, -0.085))
		g.sphere(0.055, 10, 6, Geo.at(0.07, 0.4, -0.085))
	g.col = top2
	g.box(Vector3(0.035, 0.38, 0.02), 0.005, Geo.at(0.05 if not robot else 0.0, 0.33, -0.112))
	g.box(Vector3(0.2, 0.06, 0.2), 0.02, Geo.at(0, 0.58, 0))  # Kragen
	if cfg.get("pads", false):
		g.col = accent.darkened(0.2)
		for sx in [-1.0, 1.0]:
			g.box(Vector3(0.14, 0.06, 0.2), 0.03, Geo.at(sx * 0.2 * sw, 0.56, 0))
	if robot:
		g.col = Color(0.15, 0.16, 0.18)
		g.box(Vector3(0.2, 0.14, 0.02), 0.01, Geo.at(0, 0.36, -0.115))
	g.col = skin
	g.cyl(0.05, 0.05, 0.0, 0.08, 10, Transform3D(Basis(Vector3.RIGHT, -PI / 2), Vector3(0, 0.56, 0)), false)
	g.to_node(torso, mat)
	if robot:
		var ge := Geo.new()
		ge.col = accent
		ge.box(Vector3(0.12, 0.03, 0.01), 0.004, Geo.at(0, 0.39, -0.126))
		ge.box(Vector3(0.05, 0.05, 0.01), 0.004, Geo.at(0.05, 0.33, -0.126))
		ge.to_node(torso, emis, false)
	# Kopf
	var head := _bone(torso, Vector3(0, 0.62, 0), "head")
	var gh := Geo.new()
	if robot:
		gh.col = skin
		gh.box(Vector3(0.22, 0.2, 0.22), 0.05, Geo.at(0, 0.11, 0))
		gh.col = Color(0.05, 0.06, 0.08)
		gh.box(Vector3(0.18, 0.12, 0.02), 0.02, Geo.at(0, 0.11, -0.11))
		gh.col = skin
		gh.cyl(0.008, 0.008, 0.0, 0.1, 6, Transform3D(Basis(Vector3.RIGHT, -PI / 2), Vector3(0.07, 0.21, 0)), false)
		gh.to_node(head, mat)
		var gf := Geo.new()
		gf.col = accent
		gf.box(Vector3(0.04, 0.025, 0.01), 0.008, Geo.at(-0.045, 0.125, -0.122))
		gf.box(Vector3(0.04, 0.025, 0.01), 0.008, Geo.at(0.045, 0.125, -0.122))
		gf.box(Vector3(0.07, 0.008, 0.01), 0.003, Geo.at(0, 0.08, -0.122))
		gf.sphere(0.015, 6, 4, Geo.at(0.07, 0.31, 0))
		gf.to_node(head, emis, false)
	else:
		gh.col = skin
		gh.sphere(0.112, 18, 12, Transform3D(Basis.IDENTITY.scaled(Vector3(0.9, 1.12, 1.0)), Vector3(0, 0.12, 0)))
		gh.box(Vector3(0.12, 0.08, 0.1), 0.035, Geo.at(0, 0.045, -0.035))   # Kinn
		gh.frustum(Vector2(0.03, 0.025), Vector2(0.012, 0.01), 0.04, Geo.at(0, 0.1, -0.115), Vector2(0, -0.006))  # Nase
		for sx in [-1.0, 1.0]:
			gh.box(Vector3(0.02, 0.045, 0.03), 0.008, Geo.at(sx * 0.103, 0.11, 0.0))   # Ohren
			gh.col = Color(0.96, 0.96, 0.94)
			gh.sphere(0.017, 8, 6, Geo.at(sx * 0.04, 0.135, -0.093))
			gh.col = Color(0.12, 0.08, 0.05) if rng.randf() < 0.6 else Color(0.2, 0.35, 0.5)
			gh.sphere(0.009, 6, 4, Geo.at(sx * 0.04, 0.135, -0.108))
			gh.col = hair.darkened(0.2)
			gh.box(Vector3(0.04, 0.008, 0.012), 0.003, Transform3D(Basis(Vector3.BACK, sx * 0.12), Vector3(sx * 0.042, 0.163, -0.1)))
			gh.col = skin
		gh.col = Color(0.55, 0.28, 0.26) if female else skin.darkened(0.35)
		gh.box(Vector3(0.042, 0.009, 0.01), 0.004, Geo.at(0, 0.058, -0.1))
		# Haare
		gh.col = hair
		var hs: int = cfg.get("hair_style", rng.randi() % 5)
		match hs:
			0:  # kurz
				gh.sphere(0.12, 16, 8, Transform3D(Basis.IDENTITY.scaled(Vector3(0.93, 0.9, 1.04)), Vector3(0, 0.15, 0.008)), PI / 2, -0.3)
			1:  # Dutt
				gh.sphere(0.12, 16, 8, Transform3D(Basis.IDENTITY.scaled(Vector3(0.93, 0.92, 1.04)), Vector3(0, 0.15, 0.008)), PI / 2, -0.3)
				gh.sphere(0.05, 10, 6, Geo.at(0, 0.21, 0.09))
			2:  # Irokese
				gh.box(Vector3(0.03, 0.06, 0.2), 0.012, Geo.at(0, 0.235, 0.0))
			3:  # lang
				gh.sphere(0.12, 16, 8, Transform3D(Basis.IDENTITY.scaled(Vector3(0.95, 0.92, 1.05)), Vector3(0, 0.15, 0.008)), PI / 2, -0.3)
				gh.box(Vector3(0.21, 0.24, 0.06), 0.03, Geo.at(0, 0.06, 0.08))
			4:  # Glatze mit Bart
				gh.box(Vector3(0.13, 0.06, 0.05), 0.02, Geo.at(0, 0.03, -0.07))
		if cfg.get("visor", false):
			gh.col = accent.darkened(0.5)
			gh.box(Vector3(0.22, 0.05, 0.05), 0.02, Geo.at(0, 0.14, -0.08))
		if cfg.get("cap", false):
			gh.col = top2
			gh.sphere(0.122, 16, 8, Transform3D(Basis.IDENTITY.scaled(Vector3(0.95, 0.75, 1.05)), Vector3(0, 0.175, 0.01)), PI / 2, 0.0)
			gh.box(Vector3(0.17, 0.012, 0.09), 0.005, Geo.at(0, 0.18, -0.12))
		gh.to_node(head, mat)
	# Arme
	for sx in [-1.0, 1.0]:
		var side := "l" if sx < 0 else "r"
		var up := _bone(torso, Vector3(sx * 0.22 * sw, 0.52, 0), "upper_" + side)
		up.rotation.z = sx * 0.09
		var ga := Geo.new()
		ga.col = top
		_limb(ga, 0.29, 0.058 * sw, 0.05)
		ga.to_node(up, mat)
		var fore := _bone(up, Vector3(0, -0.29, 0), "fore_" + side)
		var gfo := Geo.new()
		gfo.col = top
		_limb(gfo, 0.21, 0.048, 0.042)
		gfo.col = top2
		gfo.cyl(0.046, 0.046, 0.2, 0.23, 10, Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3.ZERO), false)
		gfo.col = skin
		gfo.box(Vector3(0.05, 0.09, 0.08), 0.02, Geo.at(0, -0.29, -0.005))
		gfo.box(Vector3(0.03, 0.05, 0.03), 0.01, Geo.at(sx * -0.01, -0.27, -0.045))
		gfo.to_node(fore, mat)
		a.bones["upper_" + side] = up
		a.bones["fore_" + side] = fore
		var th := _bone(hips, Vector3(sx * 0.095, -0.02, 0), "thigh_" + side)
		var gt := Geo.new()
		gt.col = pants
		_limb(gt, 0.45, 0.078, 0.058)
		gt.to_node(th, mat)
		var sh := _bone(th, Vector3(0, -0.45, 0), "shin_" + side)
		var gs := Geo.new()
		gs.col = pants
		_limb(gs, 0.4, 0.056, 0.045)
		gs.col = boots
		gs.box(Vector3(0.11, 0.13, 0.15), 0.03, Geo.at(0, -0.39, 0.0))
		gs.box(Vector3(0.105, 0.07, 0.26), 0.03, Geo.at(0, -0.465, -0.05))
		gs.to_node(sh, mat)
		a.bones["thigh_" + side] = th
		a.bones["shin_" + side] = sh
	a.bones["hips"] = hips
	a.bones["torso"] = torso
	a.bones["head"] = head
	a.height = 1.8
	return a

## Schwebende Drohne
static func drone(accent: Color, rng: RandomNumberGenerator) -> Actor:
	var a := Actor.new()
	a.kind = "drone"
	a.ph = rng.randf() * TAU
	a.speed = 1.6
	var root := Node3D.new()
	a.node = root
	var body := _bone(root, Vector3.ZERO, "body")
	var g := Geo.new()
	g.col = Color(0.82, 0.84, 0.86)
	g.sphere(0.2, 18, 10, Transform3D.IDENTITY)
	g.col = Color(0.2, 0.22, 0.25)
	g.torus(0.215, 0.03, 32, 8, Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3.ZERO))
	for sx in [-1.0, 1.0]:
		g.col = Color(0.3, 0.32, 0.36)
		g.cyl(0.06, 0.05, -0.08, 0.08, 10, Transform3D(Basis(Vector3.UP, PI / 2), Vector3(sx * 0.26, 0, 0)))
		g.box(Vector3(0.08, 0.03, 0.03), 0.01, Geo.at(sx * 0.21, 0, 0))
	g.cyl(0.006, 0.006, 0.0, 0.14, 6, Transform3D(Basis(Vector3.RIGHT, -PI / 2), Vector3(0.05, 0.18, 0)), false)
	g.to_node(body, vmat(0.3, 0.5))
	var e := Geo.new()
	e.col = accent
	e.cyl(0.07, 0.07, -0.205, -0.19, 16, Transform3D.IDENTITY)
	e.torus(0.217, 0.008, 40, 4, Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3.ZERO))
	e.sphere(0.014, 6, 4, Geo.at(0.05, 0.33, 0))
	for sx in [-1.0, 1.0]:
		e.cyl(0.04, 0.04, 0.081, 0.082, 10, Transform3D(Basis(Vector3.UP, PI / 2), Vector3(sx * 0.26, 0, 0)))
	var em := StandardMaterial3D.new()
	em.vertex_color_use_as_albedo = true
	em.emission_enabled = true
	em.emission = accent
	em.emission_energy_multiplier = 3.0
	e.to_node(body, em, false)
	a.bones["body"] = body
	return a

## Putzroboter
static func cleaner(rng: RandomNumberGenerator) -> Actor:
	var a := Actor.new()
	a.kind = "cleaner"
	a.ph = rng.randf() * TAU
	a.speed = 0.6
	var root := Node3D.new()
	a.node = root
	var g := Geo.new()
	var xf := Transform3D(Basis(Vector3.RIGHT, -PI / 2), Vector3.ZERO)
	g.col = Color(0.92, 0.92, 0.9)
	g.cyl(0.3, 0.28, 0.03, 0.14, 24, xf)
	g.col = Color(0.15, 0.16, 0.18)
	g.cyl(0.305, 0.305, 0.03, 0.07, 24, xf, false)
	g.col = Color(0.85, 0.6, 0.1)
	g.box(Vector3(0.36, 0.02, 0.06), 0.01, Geo.at(0, 0.145, -0.14))
	g.col = Color(0.2, 0.22, 0.25)
	g.sphere(0.12, 14, 6, Geo.at(0, 0.14, 0.04), PI / 2, 0.0)
	g.to_node(root, vmat(0.35, 0.2))
	var e := Geo.new()
	e.col = Color(1.0, 0.6, 0.1)
	e.sphere(0.025, 8, 4, Geo.at(0, 0.27, 0.04))
	var em := StandardMaterial3D.new()
	em.vertex_color_use_as_albedo = true
	em.emission_enabled = true
	em.emission = Color(1.0, 0.6, 0.1)
	em.emission_energy_multiplier = 4.0
	e.to_node(root, em, false)
	a.mats["beacon"] = em
	var brush := _bone(root, Vector3(0, 0.02, -0.18), "brush")
	var gb := Geo.new()
	gb.col = Color(0.3, 0.5, 0.8)
	for k in 4:
		gb.box(Vector3(0.16, 0.012, 0.02), 0.004, Transform3D(Basis(Vector3.UP, k * PI / 4), Vector3.ZERO))
	gb.to_node(brush, vmat(0.8))
	a.bones["brush"] = brush
	return a

## Lader mit Gabel und Kiste
static func loader(accent: Color) -> Actor:
	var a := Actor.new()
	a.kind = "loader"
	a.speed = 1.4
	var root := Node3D.new()
	a.node = root
	var g := Geo.new()
	g.col = Color(0.12, 0.12, 0.13)
	for sx in [-1.0, 1.0]:
		g.box(Vector3(0.35, 0.4, 2.0), 0.12, Geo.at(sx * 0.65, 0.2, 0))
	g.col = Color(0.95, 0.72, 0.15)
	g.box(Vector3(1.1, 0.8, 1.6), 0.1, Geo.at(0, 0.8, 0.15))
	g.col = Color(0.1, 0.1, 0.1)
	for k in 5:
		g.box(Vector3(1.12, 0.1, 0.06), 0.01, Transform3D(Basis(Vector3.RIGHT, 0.6), Vector3(0, 0.75, 0.95 - k * 0.0) + Vector3(-0.44 + k * 0.22, 0, 0) * 0.0 + Vector3(0, -0.2 + k * 0.1, 0)))
	g.col = Color(0.25, 0.26, 0.3)
	g.box(Vector3(0.6, 0.5, 0.5), 0.08, Geo.at(0, 1.45, 0.45))
	g.col = Color(0.1, 0.2, 0.3)
	g.box(Vector3(0.5, 0.25, 0.02), 0.02, Geo.at(0, 1.5, 0.19))
	g.col = Color(0.3, 0.32, 0.35)
	for sx in [-1.0, 1.0]:
		g.box(Vector3(0.1, 2.6, 0.1), 0.02, Geo.at(sx * 0.42, 1.3, -0.72))
	g.to_node(root, vmat(0.45, 0.4))
	var fork := _bone(root, Vector3(0, 0.3, -0.8), "fork")
	var gf := Geo.new()
	gf.col = Color(0.3, 0.32, 0.35)
	gf.box(Vector3(0.95, 0.4, 0.06), 0.02, Geo.at(0, 0.2, 0))
	for sx in [-1.0, 1.0]:
		gf.box(Vector3(0.1, 0.05, 1.0), 0.02, Geo.at(sx * 0.3, 0.0, -0.5))
	gf.col = Color.html(ShipBuilder.CONTAINER_COLORS[randi() % 3])
	gf.box(Vector3(0.9, 0.75, 0.9), 0.04, Geo.at(0, 0.42, -0.52))
	gf.to_node(fork, vmat(0.55, 0.2))
	var e := Geo.new()
	e.col = Color(1.0, 0.55, 0.1)
	e.sphere(0.06, 8, 4, Geo.at(0, 1.75, 0.45))
	var em := StandardMaterial3D.new()
	em.vertex_color_use_as_albedo = true
	em.emission_enabled = true
	em.emission = Color(1.0, 0.55, 0.1)
	em.emission_energy_multiplier = 5.0
	e.to_node(root, em, false)
	a.mats["beacon"] = em
	a.bones["fork"] = fork
	return a

## Schweißroboterarm mit Funken
static func welder() -> Actor:
	var a := Actor.new()
	a.kind = "welder"
	var root := Node3D.new()
	a.node = root
	var g := Geo.new()
	var up := Transform3D(Basis(Vector3.RIGHT, -PI / 2), Vector3.ZERO)
	g.col = Color(0.2, 0.2, 0.22)
	g.cyl(0.4, 0.45, 0.0, 0.3, 20, up)
	g.to_node(root, vmat(0.5, 0.4))
	var yaw := _bone(root, Vector3(0, 0.3, 0), "yaw")
	var gy := Geo.new()
	gy.col = Color(0.95, 0.5, 0.12)
	gy.cyl(0.26, 0.26, 0.0, 0.35, 16, up)
	gy.to_node(yaw, vmat(0.4, 0.3))
	var s1 := _bone(yaw, Vector3(0, 0.45, 0), "s1")
	var g1 := Geo.new()
	g1.col = Color(0.95, 0.5, 0.12)
	g1.box(Vector3(0.22, 1.5, 0.22), 0.06, Geo.at(0, 0.75, 0))
	g1.col = Color(0.15, 0.15, 0.17)
	g1.cyl(0.16, 0.16, -0.15, 0.15, 14, Transform3D(Basis(Vector3.UP, PI / 2), Vector3.ZERO))
	g1.to_node(s1, vmat(0.4, 0.3))
	var s2 := _bone(s1, Vector3(0, 1.5, 0), "s2")
	var g2 := Geo.new()
	g2.col = Color(0.95, 0.5, 0.12)
	g2.box(Vector3(0.16, 1.1, 0.16), 0.05, Geo.at(0, 0.55, 0))
	g2.col = Color(0.15, 0.15, 0.17)
	g2.cyl(0.12, 0.12, -0.12, 0.12, 12, Transform3D(Basis(Vector3.UP, PI / 2), Vector3.ZERO))
	g2.cyl(0.05, 0.02, 1.1, 1.35, 8, Transform3D(Basis(Vector3.RIGHT, -PI / 2), Vector3.ZERO))
	g2.to_node(s2, vmat(0.4, 0.3))
	var tip := _bone(s2, Vector3(0, 1.38, 0), "tip")
	var sp := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.04, 0.04)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.vertex_color_use_as_albedo = true
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	q.material = sm
	sp.mesh = q
	sp.amount = 40
	sp.lifetime = 0.6
	sp.direction = Vector3(0, -1, 0)
	sp.spread = 70.0
	sp.initial_velocity_min = 1.0
	sp.initial_velocity_max = 3.5
	sp.gravity = Vector3(0, -6, 0)
	sp.color = Color(3.0, 2.0, 0.8)
	sp.emitting = true
	tip.add_child(sp)
	var l := OmniLight3D.new()
	l.light_color = Color(0.6, 0.8, 1.0)
	l.light_energy = 2.0
	l.omni_range = 4.0
	tip.add_child(l)
	a.bones["yaw"] = yaw
	a.bones["s1"] = s1
	a.bones["s2"] = s2
	a.bones["sparks"] = sp
	a.bones["light"] = l
	return a

# ------------------------------------------------------------------ Animation
func _walk_pose(p: float, amount: float) -> void:
	var s := sin(p)
	for side in ["l", "r"]:
		var k := 1.0 if side == "l" else -1.0
		bones["thigh_" + side].rotation.x = s * 0.55 * k * amount
		bones["shin_" + side].rotation.x = -maxf(0.0, -sin(p + (0.0 if side == "l" else PI)) ) * 0.9 * amount
		bones["upper_" + side].rotation.x = -s * 0.4 * k * amount
		bones["fore_" + side].rotation.x = 0.35 * amount
	bones["hips"].position.y = 0.95 + absf(cos(p)) * 0.035 * amount
	bones["torso"].rotation.y = s * 0.08 * amount

func _reset_pose() -> void:
	for side in ["l", "r"]:
		bones["thigh_" + side].rotation = Vector3.ZERO
		bones["shin_" + side].rotation = Vector3.ZERO
		bones["upper_" + side].rotation = Vector3(0, 0, (-1.0 if side == "l" else 1.0) * 0.09)
		bones["fore_" + side].rotation = Vector3.ZERO
	bones["hips"].position.y = 0.95

func _look_at_player(player_pos: Vector3, dt: float, max_turn := 1.1) -> void:
	var head: Node3D = bones["head"]
	var to := player_pos - node.global_position
	to.y = 0.0
	var want := 0.0
	if to.length() < 5.0 and to.length() > 0.2:
		var local_yaw := atan2(-to.x, -to.z) - node.global_rotation.y
		want = clampf(wrapf(local_yaw, -PI, PI), -max_turn, max_turn)
	head.rotation.y = lerp_angle(head.rotation.y, want, dt * 4.0)

func update(dt: float, player_pos: Vector3) -> void:
	t += dt
	match kind:
		"human", "servo":
			_update_human(dt, player_pos)
		"drone":
			_update_drone(dt)
		"cleaner":
			_update_cleaner(dt)
		"loader":
			_update_loader(dt)
		"welder":
			_update_welder(dt)

func _pick_target() -> void:
	route = PackedVector3Array()
	route_i = 0
	if navi:
		target = navi.nav_random(area, node.position.y)
		route = navi.nav_path(node.position, target)
		if route.is_empty():
			target = node.position
	else:
		target = Vector3(randf_range(area.position.x, area.end.x), node.position.y, randf_range(area.position.z, area.end.z))

## Nächster Wegpunkt auf dem Weg zum Ziel
func _waypoint() -> Vector3:
	while route_i < route.size() and Vector2(route[route_i].x - node.position.x, route[route_i].z - node.position.z).length() < 0.22 and route_i < route.size() - 1:
		route_i += 1
	if route_i < route.size():
		return route[route_i]
	return target

func _update_human(dt: float, player_pos: Vector3) -> void:
	var near := player_pos.distance_to(node.global_position) < 3.2
	match mode:
		"walk":
			var to := _waypoint() - node.position
			to.y = 0.0
			var rest := target - node.position
			rest.y = 0.0
			# Kurz warten, wenn der Spieler im Weg steht
			var pp := player_pos - node.global_position
			pp.y = 0.0
			if pp.length() < 1.1 and to.length() > 0.01 and pp.normalized().dot(to.normalized()) > 0.4:
				blocked += dt
				if blocked > 2.5:
					blocked = 0.0
					_pick_target()
				_reset_pose()
				_idle_motion(dt)
				_look_at_player(player_pos, dt)
				return
			blocked = 0.0
			if rest.length() < 0.3 or wait > 0.0:
				wait -= dt
				_reset_pose()
				_idle_motion(dt)
				if wait <= 0.0 and rest.length() < 0.3:
					_pick_target()
					wait = randf_range(1.5, 5.0)
				elif wait <= 0.0:
					wait = 0.0
			else:
				node.position += to.normalized() * minf(speed * dt, to.length() + 0.05)
				node.rotation.y = lerp_angle(node.rotation.y, atan2(-to.x, -to.z), dt * 5.0)
				phase += dt * speed * 5.2
				_walk_pose(phase, 1.0)
				bones["head"].rotation.y = lerp_angle(bones["head"].rotation.y, 0.0, dt * 3.0)
		"sit":
			bones["hips"].position.y = 0.52
			for side in ["l", "r"]:
				bones["thigh_" + side].rotation.x = 1.5
				bones["shin_" + side].rotation.x = -1.45
				bones["upper_" + side].rotation.x = 0.45
				bones["fore_" + side].rotation.x = 1.0
			bones["fore_r"].rotation.x = 1.1 + sin(t * 0.7 + ph) * 0.25
			bones["torso"].rotation.x = 0.06 + sin(t * 1.4 + ph) * 0.01
			_look_at_player(player_pos, dt, 0.9)
		"wipe":
			_idle_motion(dt)
			bones["upper_r"].rotation = Vector3(0.75 + sin(t * 3.0) * 0.12, 0.0, 0.25 + cos(t * 3.0) * 0.2)
			bones["fore_r"].rotation.x = 0.9
			if near:
				bones["upper_r"].rotation = bones["upper_r"].rotation.lerp(Vector3(0, 0, 0.09), 0.8)
				bones["fore_r"].rotation.x = 0.3
			_look_at_player(player_pos, dt)
		_:
			_idle_motion(dt)
			_look_at_player(player_pos, dt)
			if near:
				talk += dt
				var g := sin(talk * 2.6)
				if g > 0.2:
					bones["upper_r"].rotation.x = lerpf(bones["upper_r"].rotation.x, 0.5 + g * 0.25, dt * 5.0)
					bones["fore_r"].rotation.x = lerpf(bones["fore_r"].rotation.x, 1.1 + g * 0.3, dt * 5.0)
				else:
					bones["upper_r"].rotation.x = lerpf(bones["upper_r"].rotation.x, 0.0, dt * 3.0)
					bones["fore_r"].rotation.x = lerpf(bones["fore_r"].rotation.x, 0.1, dt * 3.0)
			if mode == "idle_rot":
				node.rotation.y = lerp_angle(node.rotation.y, base_rot, dt * 2.0)

func _idle_motion(dt: float) -> void:
	var b := sin(t * 1.5 + ph)
	bones["torso"].rotation.x = b * 0.012
	bones["torso"].scale = Vector3(1.0 + b * 0.008, 1.0, 1.0 + b * 0.01)
	bones["hips"].position.y = 0.95 + b * 0.002
	for side in ["l", "r"]:
		var k := 1.0 if side == "l" else -1.0
		bones["upper_" + side].rotation.x = sin(t * 0.8 + ph + k) * 0.03
		bones["fore_" + side].rotation.x = 0.12 + sin(t * 0.9 + ph) * 0.03

func _update_drone(dt: float) -> void:
	var to := target - node.position
	if to.length() < 0.5:
		wait -= dt
		if wait <= 0.0:
			target = Vector3(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y), randf_range(area.position.z, area.end.z))
			wait = randf_range(0.5, 3.0)
	else:
		node.position += to.normalized() * minf(speed, to.length() * 2.0) * dt
		var flat := Vector3(to.x, 0, to.z)
		if flat.length() > 0.1:
			node.rotation.y = lerp_angle(node.rotation.y, atan2(-flat.x, -flat.z), dt * 3.0)
	var body: Node3D = bones["body"]
	body.position.y = sin(t * 2.2 + ph) * 0.06
	body.rotation.z = sin(t * 1.3 + ph) * 0.12
	body.rotation.x = clampf(to.length(), 0.0, 1.0) * 0.18

func _update_cleaner(dt: float) -> void:
	var to := _waypoint() - node.position
	to.y = 0.0
	var rest := target - node.position
	rest.y = 0.0
	if rest.length() < 0.3:
		wait -= dt
		if wait <= 0.0:
			_pick_target()
			wait = randf_range(0.5, 2.0)
	else:
		var want := atan2(-to.x, -to.z)
		node.rotation.y = lerp_angle(node.rotation.y, want, dt * 2.5)
		if absf(wrapf(want - node.rotation.y, -PI, PI)) < 0.4:
			node.position += -node.global_basis.z * speed * dt
	bones["brush"].rotation.y += dt * 14.0
	mats["beacon"].emission_energy_multiplier = 5.0 if fmod(t, 1.0) < 0.15 else 0.6

func _update_loader(dt: float) -> void:
	if path.size() < 2:
		return
	var tgt: Vector3 = path[path_i]
	var to := tgt - node.position
	to.y = 0.0
	var fork: Node3D = bones["fork"]
	if to.length() < 0.25:
		wait += dt
		fork.position.y = 0.3 + clampf(sin(wait * 1.2) * 1.4, 0.0, 1.2)
		if wait > 2.6:
			wait = 0.0
			path_i = (path_i + 1) % path.size()
	else:
		var want := atan2(-to.x, -to.z)
		node.rotation.y = lerp_angle(node.rotation.y, want, dt * 1.8)
		if absf(wrapf(want - node.rotation.y, -PI, PI)) < 0.3:
			node.position += -node.global_basis.z * speed * dt
		fork.position.y = lerpf(fork.position.y, 0.5, dt * 2.0)
	mats["beacon"].emission_energy_multiplier = 6.0 if fmod(t, 0.8) < 0.4 else 0.5

func _update_welder(dt: float) -> void:
	bones["yaw"].rotation.y = sin(t * 0.4 + ph) * 0.5 + base_rot
	bones["s1"].rotation.x = -0.5 + sin(t * 0.7 + ph) * 0.15
	bones["s2"].rotation.x = -1.2 + sin(t * 0.9 + ph) * 0.2
	var on := fmod(t + ph, 4.0) < 2.6
	bones["sparks"].emitting = on
	bones["light"].light_energy = (1.5 + randf() * 2.5) if on else 0.0

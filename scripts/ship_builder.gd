class_name ShipBuilder
extends RefCounted
## Baut ein Schiff aus den eingebauten Bauteilen. Jedes Teil ist sichtbar und ändert die Form.

const HULL_SHADER := preload("res://shaders/hull.gdshader")
const FLAME_SHADER := preload("res://shaders/flame.gdshader")
const CONTAINER_COLORS := ["#c8642a", "#2f6fa8", "#d8b23a"]

static func std(col: Color, metal: float, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = metal
	m.roughness = rough
	return m

static func emissive(col: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.02, 0.02, 0.02)
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	m.roughness = 1.0
	return m

static func hull_mat(hull: Color, accent: Color, pattern: int, half: Vector3, scale := 1.1, metal := 0.4, rough := 0.48, wear := 1.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = HULL_SHADER
	m.set_shader_parameter("hull_color", hull)
	m.set_shader_parameter("accent_color", accent)
	m.set_shader_parameter("pattern", pattern)
	m.set_shader_parameter("half_ext", half)
	m.set_shader_parameter("panel_scale", scale)
	m.set_shader_parameter("metal", metal)
	m.set_shader_parameter("rough", rough)
	m.set_shader_parameter("wear", wear)
	return m

static func disc(g: Geo, center: Vector3, r: float, seg: int) -> void:
	var pts := []
	for i in seg:
		var a := TAU * i / seg
		pts.append(center + Vector3(cos(a) * r, sin(a) * r, 0.0))
	g.poly(pts, center - Vector3(0, 0, 1), Transform3D.IDENTITY)

static func build(fit: Dictionary, paint: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Ship"
	var F := Game.part("frame", fit.frame)
	var E := Game.part("engine", fit.engine)
	var R := Game.part("rcs", fit.rcs)
	var C := Game.part("cargo", fit.cargo)
	var A := Game.part("armor", fit.armor)
	var dim: Vector3 = F.dim
	var w := dim.x
	var h := dim.y
	var l := dim.z
	var style := int(F.style)
	var hc := Color.html(paint.hull)
	var ac := Color.html(paint.accent)
	var fc := Game.flame_color(paint, fit.engine)

	var gh := Geo.new()  # lackierter Rumpf
	var ga := Geo.new()  # Akzentfarbe
	var gt := Geo.new()  # dunkles Metall
	var ge := Geo.new()  # Triebwerksmetall
	var gp := Geo.new()  # Panzer
	var gg := Geo.new()  # Glas
	var gf := Geo.new()  # Düsenglühen
	var gl := Geo.new()  # helles Metall

	var bz := 0.1 * l  # Mitte des Rumpfkörpers
	var rear := 0.43 * l
	var front := -0.23 * l
	var eye := Vector3.ZERO

	match style:
		0:  # Spatz
			bz = 0.1 * l; rear = bz + 0.33 * l; front = bz - 0.33 * l
			gh.box(Vector3(w, h, l * 0.66), 0.22, Geo.at(0, 0, bz))
			gh.frustum(Vector2(w * 0.98, h * 0.96), Vector2(w * 0.42, h * 0.34), l * 0.3, Geo.at(0, 0, front - l * 0.15), Vector2(0, -h * 0.12))
			gg.frustum(Vector2(w * 0.62, h * 0.42), Vector2(w * 0.5, h * 0.06), l * 0.2, Geo.at(0, h * 0.7, front + l * 0.1), Vector2(0, -h * 0.17))
			gt.box(Vector3(w * 0.68, h * 0.46, l * 0.05), 0.05, Geo.at(0, h * 0.7, front + l * 0.22))
			gt.box(Vector3(w * 0.34, h * 0.2, l * 0.36), 0.08, Geo.at(0, h * 0.6, bz + 0.1 * l))
			eye = Vector3(0, h * 0.78, front + l * 0.08)
		1:  # Lastesel
			bz = 0.08 * l; rear = bz + 0.35 * l; front = bz - 0.35 * l
			gh.box(Vector3(w, h, l * 0.7), 0.3, Geo.at(0, 0, bz))
			gh.frustum(Vector2(w * 0.98, h * 0.96), Vector2(w * 0.7, h * 0.55), l * 0.22, Geo.at(0, 0, front - l * 0.11), Vector2(0, -h * 0.1))
			gg.frustum(Vector2(w * 0.8, h * 0.4), Vector2(w * 0.74, h * 0.08), l * 0.14, Geo.at(0, h * 0.7, front + l * 0.07), Vector2(0, -h * 0.15))
			gt.box(Vector3(w * 0.84, h * 0.44, l * 0.05), 0.05, Geo.at(0, h * 0.7, front + l * 0.16))
			for sx in [-1.0, 1.0]:
				gh.box(Vector3(w * 0.26, h * 0.7, l * 0.5), 0.15, Geo.at(sx * w * 0.62, -h * 0.05, bz + 0.05 * l))
				gt.box(Vector3(w * 0.05, h * 0.5, l * 0.36), 0.03, Geo.at(sx * w * 0.76, -h * 0.05, bz + 0.05 * l))
			gt.box(Vector3(w * 0.22, h * 0.16, l * 0.3), 0.06, Geo.at(0, h * 0.58, bz + 0.12 * l))
			eye = Vector3(0, h * 0.76, front + l * 0.05)
		2:  # Pfeil
			bz = 0.15 * l; rear = bz + 0.25 * l; front = bz - 0.25 * l
			gh.box(Vector3(w, h, l * 0.5), 0.18, Geo.at(0, 0, bz))
			gh.frustum(Vector2(w * 0.98, h * 0.96), Vector2(w * 0.12, h * 0.1), l * 0.45, Geo.at(0, 0, front - l * 0.225), Vector2(0, -h * 0.15))
			gg.frustum(Vector2(w * 0.5, h * 0.5), Vector2(w * 0.16, h * 0.04), l * 0.3, Geo.at(0, h * 0.65, front - l * 0.02), Vector2(0, -h * 0.22))
			var span := w * 0.95
			var sweep := l * 0.12
			for sx in [-1.0, 1.0]:
				var th := -PI / 2 if sx > 0 else PI / 2
				var xf := Transform3D(Basis(Vector3.UP, th), Vector3(sx * (w * 0.5 + span * 0.5 - 0.2), -h * 0.12, bz + l * 0.02))
				gh.frustum(Vector2(l * 0.34, 0.32), Vector2(l * 0.12, 0.2), span, xf, Vector2(sweep * sx, 0))
				ga.box(Vector3(0.25, h * 0.75, l * 0.13), 0.05, Geo.at(sx * (w * 0.5 + span - 0.3), h * 0.1, bz + l * 0.02 + sweep))
			eye = Vector3(0, h * 0.72, front - l * 0.03)
		3:  # Kondor
			bz = 0.06 * l; rear = bz + 0.36 * l; front = bz - 0.36 * l
			gh.box(Vector3(w, h, l * 0.72), 0.35, Geo.at(0, 0, bz))
			gh.frustum(Vector2(w * 0.98, h * 0.96), Vector2(w * 0.5, h * 0.45), l * 0.2, Geo.at(0, 0, front - l * 0.1), Vector2(0, -h * 0.12))
			gh.box(Vector3(w * 0.5, h * 0.45, l * 0.16), 0.15, Geo.at(0, h * 0.7, front + l * 0.14))
			gg.box(Vector3(w * 0.52, h * 0.14, l * 0.165), 0.04, Geo.at(0, h * 0.76, front + l * 0.135))
			ga.frustum(Vector2(0.45, h * 0.9), Vector2(0.3, h * 0.2), l * 0.22, Geo.at(0, h * 0.95, rear - l * 0.12), Vector2(0, -h * 0.35))
			for sx in [-1.0, 1.0]:
				gt.box(Vector3(w * 0.06, h * 0.12, l * 0.6), 0.03, Geo.at(sx * w * 0.5, h * 0.3, bz))
			gt.box(Vector3(w * 1.06, h * 0.12, l * 0.12), 0.04, Geo.at(0, -h * 0.2, rear - l * 0.05))
			eye = Vector3(0, h * 0.78, front + l * 0.08)
	gt.box(Vector3(w * 0.9, h * 0.82, 0.3), 0.06, Geo.at(0, 0, rear + 0.15))

	# Positionslichter
	var nav_r := Geo.new()
	var nav_g := Geo.new()
	var nav_w := Geo.new()
	var wx := w * 0.5 + 0.15
	if style == 2:
		wx = w * 0.5 + w * 0.95 - 0.2
	nav_r.sphere(0.22, 8, 6, Geo.at(-wx, 0.0, bz), PI / 2)
	nav_g.sphere(0.22, 8, 6, Geo.at(wx, 0.0, bz), PI / 2)
	nav_w.sphere(0.2, 8, 6, Geo.at(0, h * 0.5 + 0.15, rear), PI / 2)

	# Triebwerke
	var flames := []
	var r := float(E.r)
	var elen := float(E.len)
	var nz := rear - elen * 0.5 + elen * 0.25
	var positions := [[-1.0, 0.0], [1.0, 0.0]]
	if int(E.nac) == 4:
		positions = [[-1.0, 1.0], [1.0, 1.0], [-1.0, -1.0], [1.0, -1.0]]
	var flame_mat := ShaderMaterial.new()
	flame_mat.shader = FLAME_SHADER
	flame_mat.set_shader_parameter("flame_color", fc)
	var cone := Geo.new()
	cone.cyl(r * 0.72, 0.0, 0.0, 1.0, 16, Transform3D.IDENTITY, false)
	var cone_mesh := cone.commit()
	var light_pos := Vector3.ZERO
	var z_end := 0.0
	for pp in positions:
		var sx: float = pp[0]
		var sy: float = pp[1]
		var x := sx * (w * 0.5 + r * 0.95)
		var y := sy * h * 0.3 if int(E.nac) == 4 else -h * 0.08
		var zf := nz - elen * 0.5
		var zb := nz + elen * 0.5 - elen * 0.18
		z_end = zb + elen * 0.18
		var xf := Geo.at(x, y, 0)
		ge.cyl(r * 0.86, r, zf, zb, 20, xf)
		gt.cyl(r * 0.42, r * 0.86, zf - elen * 0.12, zf, 20, xf)
		gt.cyl(r * 0.82, r * 0.98, zb, z_end, 20, xf, false)
		ge.cyl(r * 0.76, r * 0.92, zb, z_end, 20, xf, false, true)
		disc(gf, Vector3(x, y, zb + 0.08), r * 0.78, 20)
		if E.ring:
			(gf if E.glow else ga).cyl(r * 1.04, r * 1.04, nz - elen * 0.12, nz + elen * 0.02, 20, xf)
		if E.glow:
			gf.cyl(r * 1.02, r * 1.02, zb - elen * 0.1, zb - elen * 0.05, 20, xf)
		for k in 3:
			gt.cyl(r * 1.005, r * 1.005, zf + elen * (0.15 + k * 0.14), zf + elen * (0.18 + k * 0.14), 20, xf, false)
		var pyl_w: float = abs(x) - w * 0.5 + 0.3
		gt.box(Vector3(pyl_w, 0.4, elen * 0.45), 0.06, Geo.at(sx * (w * 0.5 + pyl_w * 0.5 - 0.3), y, nz))
		var fm := MeshInstance3D.new()
		fm.mesh = cone_mesh
		fm.material_override = flame_mat
		fm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fm.position = Vector3(x, y, z_end - 0.15)
		fm.scale = Vector3(1, 1, 0.01)
		root.add_child(fm)
		flames.append(fm)
		light_pos += Vector3(x, y, z_end + r * 2.0)
	light_pos /= positions.size()

	# Manövrierdüsen
	var gr := ga if R.acc else gt
	var zfr := front + 0.6
	var zbk := rear - 0.6
	for sz in [-1.0, 1.0]:
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				if int(R.k) == 4 and sy != (1.0 if sz < 0 else -1.0):
					continue
				var zz := zfr if sz < 0 else zbk
				gr.box(Vector3(0.55, 0.55, 0.7), 0.08, Geo.at(sx * (w * 0.5 + 0.2), sy * (h * 0.5 - 0.3), zz))
				gt.cyl(0.14, 0.2, 0.0, 0.32, 8, Transform3D(Basis(Vector3.UP, sx * PI / 2), Vector3(sx * (w * 0.5 + 0.45), sy * (h * 0.5 - 0.3), zz)))

	# Frachtmodul
	var ci := int(C.idx)
	var mw: float = w * float([0.7, 0.88, 1.0, 1.12][ci])
	var mh: float = h * float([0.55, 0.8, 1.0, 1.2][ci])
	var ml: float = l * float([0.4, 0.58, 0.72, 0.86][ci])
	var my := -h * 0.5 - mh * 0.5 - 0.3
	var mz := bz + l * 0.02
	var rt := 0.28
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			gt.box(Vector3(rt, rt, ml), 0.04, Geo.at(sx * mw * 0.5, my + sy * mh * 0.5, mz))
	for sz in [-1.0, 1.0]:
		for sx in [-1.0, 1.0]:
			gt.box(Vector3(rt, mh, rt), 0.04, Geo.at(sx * mw * 0.5, my, mz + sz * ml * 0.5))
		gt.box(Vector3(mw, rt, rt), 0.04, Geo.at(0, my - mh * 0.5, mz + sz * ml * 0.5))
		gt.box(Vector3(mw, rt, rt), 0.04, Geo.at(0, my + mh * 0.5, mz + sz * ml * 0.5))
	gt.box(Vector3(w * 0.5, 0.55, ml * 0.6), 0.08, Geo.at(0, -h * 0.5 - 0.2, mz))
	var load := Node3D.new()
	load.name = "Load"
	root.add_child(load)
	var cn: int = [1, 1, 2, 3][ci]
	for i in cn:
		var seg := ml / cn
		var gc := Geo.new()
		gc.box(Vector3(mw * 0.9, mh * 0.88, seg * 0.9), 0.06, Geo.at(0, my, mz - ml * 0.5 + seg * (i + 0.5)))
		var cmat := hull_mat(Color.html(CONTAINER_COLORS[i % 3]), Color.WHITE, 6, Vector3(mw, mh, seg) * 0.5, 1.0, 0.3, 0.6, 0.7)
		gc.to_node(load, cmat)
	load.visible = false

	# Panzerung
	var at_lvl := int(A.t)
	if at_lvl > 0:
		for sx in [-1.0, 1.0]:
			gp.box(Vector3(0.38, h * 0.72, l * (0.3 + 0.15 * at_lvl)), 0.1, Geo.at(sx * (w * 0.5 + 0.2), h * 0.02, bz - l * 0.08))
			if at_lvl >= 3:
				gp.box(Vector3(0.34, h * 0.5, l * 0.2), 0.08, Geo.at(sx * (w * 0.5 + 0.2), h * 0.05, rear - l * 0.1))
		if at_lvl >= 2:
			gp.box(Vector3(w * 0.72, 0.32, l * 0.3), 0.1, Geo.at(0, h * 0.5 + 0.16, bz + l * 0.08))
		if at_lvl >= 3:
			gp.box(Vector3(w * 0.8, 0.32, l * 0.18), 0.1, Geo.at(0, -h * 0.5 - 0.06, front + l * 0.05))

	# Extras
	var beacon_mat: StandardMaterial3D = null
	match String(fit.extra):
		"nav":
			gt.cyl(0.08, 0.08, 0.0, 1.5, 6, Transform3D(Basis(Vector3.RIGHT, -PI / 2), Vector3(w * 0.25, h * 0.5, rear - l * 0.12)))
			gl.sphere(0.95, 14, 6, Transform3D(Basis(Vector3.RIGHT, -0.7), Vector3(w * 0.25, h * 0.5 + 1.6, rear - l * 0.12)), -PI / 2 + 1.0)
		"bake":
			gt.box(Vector3(0.6, 0.5, 0.6), 0.06, Geo.at(0, h * 0.5 + 0.25, rear - 0.6))
			var gb := Geo.new()
			gb.sphere(0.28, 10, 6, Geo.at(0, h * 0.5 + 0.6, rear - 0.6))
			beacon_mat = emissive(Color(1.0, 0.15, 0.1), 6.0)
			gb.to_node(root, beacon_mat, false)
		"daempfer":
			var gy := Geo.new()
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					gy.cyl(0.22, 0.22, -0.45, 0.45, 10, Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(sx * mw * 0.42, -h * 0.5 - 0.3, mz + sz * ml * 0.4)))
			gy.to_node(root, std(Color(0.95, 0.76, 0.19), 0.3, 0.45))

	var half := Vector3(w * 0.5, h * 0.5, l * 0.5)
	gh.to_node(root, hull_mat(hc, ac, Game.pattern_code(paint.pattern), half, 0.7, 0.15, 0.5))
	ga.to_node(root, hull_mat(ac, ac, 0, half, 0.6, 0.15, 0.45, 0.5))
	gp.to_node(root, hull_mat(hc * 0.6, ac, 0, half, 2.2, 0.3, 0.45, 0.8))
	gt.to_node(root, std(Color(0.28, 0.3, 0.34), 0.45, 0.45))
	ge.to_node(root, std(Color(0.55, 0.57, 0.6), 0.7, 0.3))
	gl.to_node(root, std(Color(0.75, 0.77, 0.8), 0.5, 0.35))
	var glass := std(Color(0.04, 0.08, 0.12), 0.95, 0.05)
	glass.emission_enabled = true
	glass.emission = Color(0.05, 0.18, 0.28)
	glass.emission_energy_multiplier = 0.6
	gg.to_node(root, glass)
	gf.to_node(root, emissive(fc, 5.0), false)
	nav_r.to_node(root, emissive(Color(1.0, 0.2, 0.15), 8.0), false)
	nav_g.to_node(root, emissive(Color(0.2, 1.0, 0.4), 8.0), false)
	var strobe := emissive(Color(1, 1, 1), 10.0)
	nav_w.to_node(root, strobe, false)

	var light := OmniLight3D.new()
	light.light_color = fc
	light.omni_range = 16.0 + l * 0.5
	light.light_energy = 0.0
	light.position = light_pos
	light.shadow_enabled = false
	root.add_child(light)

	root.set_meta("flames", flames)
	root.set_meta("load", load)
	root.set_meta("beacon", beacon_mat)
	root.set_meta("strobe", strobe)
	root.set_meta("eng_light", light)
	root.set_meta("eye", eye)
	root.set_meta("flame_len", elen)
	root.set_meta("radius", max(l * 0.6, w * 1.2))
	return root

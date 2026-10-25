class_name ShipBuilder
extends RefCounted
## Baut Schiffe aus Blaupausen (Module auf einem Raster).

const HULL_SHADER := preload("res://shaders/hull.gdshader")
const FLAME_SHADER := preload("res://shaders/flame.gdshader")
const METAL_SHADER := preload("res://shaders/metal.gdshader")
const TEX_HULL_N := preload("res://textures/hull_n.png")
const TEX_HULL_M := preload("res://textures/hull_m.png")
const TEX_METAL_N := preload("res://textures/metal_n.png")
const TEX_METAL_M := preload("res://textures/metal_m.png")
const CONTAINER_COLORS := ["#c8642a", "#2f6fa8", "#d8b23a"]

## Metall mit Detailtexturen. panels > 0 legt zusätzlich Plattenfugen auf.
static func std(col: Color, metal: float, rough: float, panels := 0.0, scale := 0.5) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = METAL_SHADER
	m.set_shader_parameter("albedo", col)
	m.set_shader_parameter("metallic", metal)
	m.set_shader_parameter("roughness", rough)
	m.set_shader_parameter("det_scale", scale)
	m.set_shader_parameter("panels", panels)
	m.set_shader_parameter("det_n", TEX_METAL_N)
	m.set_shader_parameter("det_m", TEX_METAL_M)
	m.set_shader_parameter("pan_n", TEX_HULL_N)
	m.set_shader_parameter("pan_m", TEX_HULL_M)
	return m

## Einfaches Material ohne Texturen (Glas u. Ä.)
static func plain(col: Color, metal: float, rough: float) -> StandardMaterial3D:
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
	m.set_shader_parameter("det_n", TEX_HULL_N)
	m.set_shader_parameter("det_m", TEX_HULL_M)
	m.set_shader_parameter("mic_n", TEX_METAL_N)
	m.set_shader_parameter("micro", 1.0 if scale >= 0.4 else 0.0)
	return m

static func disc(g: Geo, center: Vector3, r: float, seg: int) -> void:
	var pts := []
	for i in seg:
		var a := TAU * i / seg
		pts.append(center + Vector3(cos(a) * r, sin(a) * r, 0.0))
	g.poly(pts, center - Vector3(0, 0, 1), Transform3D.IDENTITY)

const BODY := ["cockpit", "hull", "shield", "power", "util", "armor"]
const TALL := ["cp3", "h3", "hk", "r3"]

## Baut das 3D-Modell eines Schiffs aus seiner Blaupause. Jedes Modul ist sichtbar.
static func build(bp: Dictionary, paint: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Ship"
	var C := Game.CELL
	var hc := Color.html(paint.hull)
	var ac := Color.html(paint.accent)
	var fc := Game.flame_color(paint, Game.main_engine(bp))
	var mods: Array = bp.mods
	var cells := Game.bp_cells(bp)
	var gh := Geo.new()  # lackierter Rumpf
	var ga := Geo.new()  # Akzentfarbe
	var gt := Geo.new()  # dunkles Metall
	var ge := Geo.new()  # Triebwerksmetall
	var gp := Geo.new()  # Panzer
	var gg := Geo.new()  # Glas
	var gf := Geo.new()  # Düsenglühen
	var gl := Geo.new()  # helles Metall
	var gm := Geo.new()  # Mündungen
	var gsh := Geo.new() # Schildemitter
	var gpw := Geo.new() # Reaktorleuchten
	var gy := Geo.new()  # gelbe Teile
	var gk := Geo.new()  # Laderaum-Verkleidung
	# Grenzen und Mittelpunkt
	var lo := Vector2i(99, 99)
	var hi := Vector2i(-99, -99)
	for c in cells:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	if cells.is_empty():
		lo = Vector2i.ZERO
		hi = Vector2i.ZERO
	var off := Vector3((lo.x + hi.x) * 0.5 * C, 0.0, (lo.y + hi.y) * 0.5 * C)
	var cpos := func(x: float, z: float) -> Vector3: return Vector3(x * C, 0.0, z * C) - off
	var cat_at := func(c: Vector2i) -> String:
		if not cells.has(c):
			return ""
		return String(Game.MODULES[mods[cells[c]][0]].cat)
	var id_at := func(c: Vector2i) -> String:
		if not cells.has(c):
			return ""
		return String(mods[cells[c]][0])
	var is_body := func(c: Vector2i) -> bool:
		var ct: String = cat_at.call(c)
		return ct in BODY and id_at.call(c) != "hb"
	var height := func(c: Vector2i) -> float:
		return 2.4 if id_at.call(c) in TALL else 1.9
	var max_h := 1.9
	# Rumpfkörper: zusammenhängende Läufe je Reihe
	for z in range(lo.y, hi.y + 1):
		var x := lo.x
		while x <= hi.x:
			if not is_body.call(Vector2i(x, z)):
				x += 1
				continue
			var x0 := x
			var hh := 1.9
			while x <= hi.x and is_body.call(Vector2i(x, z)):
				hh = maxf(hh, height.call(Vector2i(x, z)))
				x += 1
			var n := x - x0
			max_h = maxf(max_h, hh)
			var ctr: Vector3 = cpos.call((x0 + x - 1) * 0.5, z)
			gh.box(Vector3(n * C - 0.06, hh, C + 0.04), 0.24, Transform3D(Basis.IDENTITY, ctr))
			# Kiel unten und Panelfugen
			gt.box(Vector3(n * C * 0.7, 0.14, C * 0.9), 0.04, Transform3D(Basis.IDENTITY, ctr + Vector3(0, -hh * 0.5 - 0.04, 0)))
	# Bug, Heck und Seiten der Rumpfzellen
	for c in cells:
		if not is_body.call(c):
			continue
		var p: Vector3 = cpos.call(c.x, c.y)
		var hh: float = height.call(c)
		var front: Vector2i = c + Vector2i(0, -1)
		var back: Vector2i = c + Vector2i(0, 1)
		var cat: String = cat_at.call(c)
		if not cells.has(front):
			if cat == "cockpit":
				gg.frustum(Vector2(C * 0.86, hh * 0.86), Vector2(C * 0.42, hh * 0.3), C * 0.55, Geo.at(p.x, p.y + hh * 0.04, p.z - C * 0.5 - C * 0.27), Vector2(0, -hh * 0.18))
			else:
				gh.frustum(Vector2(C * 0.96, hh * 0.94), Vector2(C * 0.5, hh * 0.42), C * 0.5, Geo.at(p.x, p.y, p.z - C * 0.5 - C * 0.24), Vector2(0, -hh * 0.14))
		if not cells.has(back):
			gt.box(Vector3(C * 0.82, hh * 0.72, 0.22), 0.05, Geo.at(p.x, p.y, p.z + C * 0.5 + 0.08))
			gf.box(Vector3(C * 0.3, 0.08, 0.04), 0.01, Geo.at(p.x, p.y + hh * 0.2, p.z + C * 0.5 + 0.2))
		for sx in [-1, 1]:
			var side: Vector2i = c + Vector2i(sx, 0)
			if not cells.has(side):
				ga.box(Vector3(0.06, 0.16, C * 0.82), 0.02, Geo.at(p.x + sx * (C * 0.5 - 0.01), p.y + hh * 0.18, p.z))
				gt.box(Vector3(0.08, hh * 0.5, 0.12), 0.02, Geo.at(p.x + sx * (C * 0.5 - 0.01), p.y - hh * 0.1, p.z - C * 0.3))
	var eye := Vector3(0, 0.9, 0)
	var guns := []
	var flames := []
	var light_pos := Vector3.ZERO
	var flame_len := 4.0
	var flame_mat := ShaderMaterial.new()
	flame_mat.shader = FLAME_SHADER
	flame_mat.set_shader_parameter("flame_color", fc)
	var cone := Geo.new()
	cone.cyl(0.72, 0.0, 0.0, 1.0, 16, Transform3D.IDENTITY, false)
	var cone_mesh := cone.commit()
	var load := Node3D.new()
	load.name = "Load"
	root.add_child(load)
	var beacon_mat: StandardMaterial3D = null
	var ncont := 0
	var shield_tier := 0
	for m in mods:
		var id: String = m[0]
		var d: Dictionary = Game.MODULES[id]
		var sx := int(d.sz[0])
		var sz := int(d.sz[1])
		var x0 := int(m[1])
		var z0 := int(m[2])
		var ctr: Vector3 = cpos.call(x0 + (sx - 1) * 0.5, z0 + (sz - 1) * 0.5)
		var wd := sx * C
		var ln := sz * C
		var side := signf(ctr.x) if absf(ctr.x) > 0.1 else 0.0
		var hh := 2.4 if id in TALL else 1.9
		match String(d.cat):
			"cockpit":
				var zf := ctr.z - ln * 0.5
				if id == "cp3":
					gh.box(Vector3(wd * 0.62, 1.1, ln * 0.55), 0.2, Geo.at(ctr.x, hh * 0.5 + 0.5, ctr.z + ln * 0.12))
					gg.box(Vector3(wd * 0.64, 0.32, ln * 0.4), 0.06, Geo.at(ctr.x, hh * 0.5 + 0.7, ctr.z - ln * 0.02))
					gt.box(Vector3(wd * 0.2, 0.7, 0.2), 0.03, Geo.at(ctr.x + wd * 0.18, hh * 0.5 + 1.3, ctr.z + ln * 0.25))
					eye = Vector3(ctr.x, hh * 0.5 + 0.7, ctr.z - ln * 0.1)
				else:
					var cl := ln * (0.62 if id == "cp2" else 0.5)
					gg.frustum(Vector2(C * 0.64, 0.62), Vector2(C * 0.36, 0.08), cl, Geo.at(ctr.x, hh * 0.5 + 0.18, zf + cl * 0.5 + 0.15), Vector2(0, -0.25))
					gt.box(Vector3(C * 0.7, 0.12, cl * 0.9), 0.04, Geo.at(ctr.x, hh * 0.5 + 0.02, zf + cl * 0.5 + 0.2))
					gt.box(Vector3(C * 0.3, 0.22, ln * 0.3), 0.06, Geo.at(ctr.x, hh * 0.5 + 0.1, ctr.z + ln * 0.3))
					eye = Vector3(ctr.x, hh * 0.5 + 0.12, zf + cl * 0.55)
			"hull":
				if id == "hb":
					var bh := 1.7
					gh.frustum(Vector2(C * 0.96, bh), Vector2(C * 0.16, bh * 0.22), C * 1.05, Geo.at(ctr.x, -0.05, ctr.z - 0.02), Vector2(0, -bh * 0.2))
					ga.box(Vector3(0.1, 0.1, C * 0.8), 0.02, Geo.at(ctr.x, bh * 0.25, ctr.z))
				elif id == "h2":
					for k in 3:
						gt.box(Vector3(wd + 0.08, 0.14, 0.18), 0.03, Geo.at(ctr.x, hh * 0.5 + 0.02, ctr.z - ln * 0.33 + k * ln * 0.33))
				elif id == "h3":
					gp.box(Vector3(wd * 0.8, 0.22, ln * 0.8), 0.06, Geo.at(ctr.x, hh * 0.5 + 0.08, ctr.z))
					for k in 4:
						gl.box(Vector3(0.12, 0.06, 0.12), 0.02, Geo.at(ctr.x + (k % 2 - 0.5) * wd * 0.6, hh * 0.5 + 0.2, ctr.z + (int(k / 2) - 0.5) * ln * 0.6))
				elif id == "hk":
					gt.box(Vector3(wd * 0.36, 0.42, ln * 0.5), 0.08, Geo.at(ctr.x - wd * 0.18, hh * 0.5 + 0.15, ctr.z))
					gl.cyl(0.25, 0.25, 0.0, 0.5, 10, Transform3D(Basis(Vector3.RIGHT, -PI / 2), Vector3(ctr.x + wd * 0.22, hh * 0.5, ctr.z + ln * 0.15)))
				else:
					gt.box(Vector3(wd * 0.36, 0.12, ln * 0.5), 0.03, Geo.at(ctr.x, hh * 0.5 + 0.03, ctr.z))
			"shield":
				shield_tier = maxi(shield_tier, int(d.tier))
				var st := int(d.tier)
				gt.cyl(0.42 + st * 0.08, 0.52 + st * 0.08, 0.0, 0.3, 14, Transform3D(Basis(Vector3.RIGHT, -PI / 2), Vector3(ctr.x, hh * 0.5, ctr.z)))
				gsh.sphere(0.36 + st * 0.08, 12, 6, Geo.at(ctr.x, hh * 0.5 + 0.3, ctr.z), PI / 2)
			"power":
				for k in [-1.0, 1.0]:
					gpw.box(Vector3(0.1, 0.06, ln * 0.7), 0.02, Geo.at(ctr.x + k * wd * 0.28, hh * 0.5 + 0.02, ctr.z))
				gt.cyl(0.36, 0.36, 0.0, 0.34, 12, Transform3D(Basis(Vector3.RIGHT, -PI / 2), Vector3(ctr.x, hh * 0.5, ctr.z)))
				gpw.cyl(0.26, 0.26, 0.3, 0.36, 12, Transform3D(Basis(Vector3.RIGHT, -PI / 2), Vector3(ctr.x, hh * 0.5, ctr.z)))
			"util":
				match id:
					"nav":
						gt.cyl(0.07, 0.07, 0.0, 1.1, 6, Transform3D(Basis(Vector3.RIGHT, -PI / 2), Vector3(ctr.x, hh * 0.5, ctr.z)))
						gl.sphere(0.7, 14, 6, Transform3D(Basis(Vector3.RIGHT, -0.7), Vector3(ctr.x, hh * 0.5 + 1.2, ctr.z)), -PI / 2 + 1.0)
					"bake":
						gt.box(Vector3(0.6, 0.4, 0.6), 0.06, Geo.at(ctr.x, hh * 0.5 + 0.2, ctr.z))
						var gb := Geo.new()
						gb.sphere(0.26, 10, 6, Geo.at(ctr.x, hh * 0.5 + 0.55, ctr.z))
						beacon_mat = emissive(Color(1.0, 0.15, 0.1), 6.0)
						gb.to_node(root, beacon_mat, false)
					"daempfer":
						for k in [-1.0, 1.0]:
							gy.cyl(0.18, 0.18, -0.7, 0.7, 10, Transform3D(Basis.IDENTITY, Vector3(ctr.x + k * 0.45, hh * 0.5 + 0.12, ctr.z)))
			"armor":
				var t := int(d.tier)
				gp.box(Vector3(wd * 0.92, 0.2 + t * 0.06, ln * 0.92), 0.08, Geo.at(ctr.x, hh * 0.5 + 0.06, ctr.z))
				for sx2 in [-1, 1]:
					if not cells.has(Vector2i(x0 + (sx - 1 if sx2 > 0 else 0) + sx2, z0)):
						gp.box(Vector3(0.18 + t * 0.06, hh * 0.86, ln * 0.94), 0.06, Geo.at(ctr.x + sx2 * (wd * 0.5 + 0.06), 0.0, ctr.z))
			"weapon":
				var wsz := float(d.size)
				var py := -0.15
				gt.box(Vector3(0.95, 0.78, C * 0.9), 0.12, Geo.at(ctr.x, py, ctr.z + 0.1))
				gl.box(Vector3(0.6, 0.12, C * 0.6), 0.04, Geo.at(ctr.x, py + 0.44, ctr.z + 0.1))
				var blen := 1.0 + wsz * 0.7
				var br := 0.11 * (0.8 + wsz * 0.3)
				var bz := ctr.z - C * 0.35
				var xf := Geo.at(ctr.x, py, bz)
				ge.cyl(br * 1.25, br, -blen, 0.0, 10, xf)
				if wsz > 1.5:
					gt.cyl(br * 2.4, br * 2.4, -blen * 0.55, -blen * 0.25, 10, xf, true)
				elif wsz < 0.9:
					for k in 3:
						var a := TAU * k / 3.0
						ge.cyl(br * 0.55, br * 0.55, -blen * 1.02, -0.1, 6, Geo.at(ctr.x + cos(a) * br * 1.2, py + sin(a) * br * 1.2, bz))
				gm.cyl(br * 1.3, br * 1.3, -blen - 0.05, -blen + 0.06, 10, xf, true)
				guns.append({"id": id, "pos": Vector3(ctr.x, py, bz - blen - 0.3), "color": d.color})
			"rcs":
				gt.box(Vector3(1.1, 0.95, 1.3), 0.14, Geo.at(ctr.x, 0.0, ctr.z))
				var acc: bool = int(d.tier) >= 3
				(ga if acc else gl).box(Vector3(1.14, 0.14, 0.5), 0.03, Geo.at(ctr.x, 0.3, ctr.z))
				var dirs := [Vector3.UP, Vector3.DOWN]
				if side != 0.0:
					dirs.append(Vector3(side, 0, 0))
				var nn := 1 if int(d.tier) < 2 else 2
				for dv in dirs:
					for k in nn:
						var zo := (k - (nn - 1) * 0.5) * 0.45
						var base: Vector3 = Vector3(ctr.x, 0.0, ctr.z + zo) + (dv as Vector3) * (0.42 if dv.y != 0 else 0.5)
						gt.cyl(0.11, 0.17, 0.0, 0.26, 8, Transform3D(Basis.looking_at(-(dv as Vector3), Vector3.FORWARD if dv.y != 0 else Vector3.UP), base))
			"cargo":
				var mh := 2.2 if sx > 1 or sz > 2 else 1.9
				var mw := wd * 0.94
				var ml := ln * 0.96
				var rt := 0.22
				for a in [-1.0, 1.0]:
					for b in [-1.0, 1.0]:
						gt.box(Vector3(rt, rt, ml), 0.04, Geo.at(ctr.x + a * mw * 0.5, b * mh * 0.5, ctr.z))
					for b in [-1.0, 1.0]:
						gt.box(Vector3(rt, mh, rt), 0.04, Geo.at(ctr.x + a * mw * 0.5, 0.0, ctr.z + b * ml * 0.5))
				for b in [-1.0, 1.0]:
					gt.box(Vector3(mw, rt, rt), 0.04, Geo.at(ctr.x, mh * 0.5, ctr.z + b * ml * 0.5))
					gt.box(Vector3(mw, rt, rt), 0.04, Geo.at(ctr.x, -mh * 0.5, ctr.z + b * ml * 0.5))
				gt.box(Vector3(0.5, 0.5, ml), 0.06, Geo.at(ctr.x, -mh * 0.5 + 0.1, ctr.z))
				gk.box(Vector3(mw - 0.3, mh * 0.78, ml - 0.3), 0.1, Geo.at(ctr.x, 0.0, ctr.z))
				for i in sx:
					for k in sz:
						var gc := Geo.new()
						var cc: Vector3 = cpos.call(x0 + i, z0 + k)
						gc.box(Vector3(C * 0.86, mh * 0.86, C * 0.9), 0.05, Geo.at(cc.x, 0.0, cc.z))
						var cmat := hull_mat(Color.html(CONTAINER_COLORS[ncont % 3]), Color.WHITE, 6, Vector3(C, mh, C) * 0.5, 1.0, 0.3, 0.6, 0.7)
						gc.to_node(load, cmat)
						ncont += 1
			"engine":
				var r := float(d.r) * 1.15
				var zf := ctr.z - ln * 0.5
				var zb := ctr.z + ln * 0.5
				var nozzles := []
				if sx == 1:
					nozzles = [Vector2(ctr.x, -0.1)]
				else:
					nozzles = [Vector2(ctr.x - C * 0.5, -0.1), Vector2(ctr.x + C * 0.5, -0.1)]
					gt.box(Vector3(wd * 0.96, r * 1.6, ln * 0.8), 0.2, Geo.at(ctr.x, -0.1, ctr.z - ln * 0.08))
				flame_len = maxf(flame_len, 2.4 + r * 2.2)
				for nz in nozzles:
					var xf := Geo.at(nz.x, nz.y, 0)
					ge.cyl(r * 0.86, r, zf + 0.2, zb - 0.35, 20, xf)
					gt.cyl(r * 0.4, r * 0.86, zf, zf + 0.2, 20, xf)
					gt.cyl(r * 0.82, r * 0.98, zb - 0.35, zb + 0.35, 20, xf, false)
					ge.cyl(r * 0.74, r * 0.9, zb - 0.35, zb + 0.35, 20, xf, false, true)
					disc(gf, Vector3(nz.x, nz.y, zb - 0.25), r * 0.76, 20)
					if d.ring:
						(gf if d.glow else ga).cyl(r * 1.04, r * 1.04, ctr.z - ln * 0.1, ctr.z + ln * 0.05, 20, xf)
					if d.glow:
						gf.cyl(r * 1.02, r * 1.02, zb - 0.7, zb - 0.6, 20, xf)
					for k in 3:
						gt.cyl(r * 1.005, r * 1.005, zf + 0.5 + k * 0.55, zf + 0.6 + k * 0.55, 20, xf, false)
					var fm := MeshInstance3D.new()
					fm.mesh = cone_mesh
					fm.material_override = flame_mat
					fm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					fm.position = Vector3(nz.x, nz.y, zb + 0.2)
					fm.scale = Vector3(r, r, 0.01)
					root.add_child(fm)
					flames.append(fm)
					light_pos += Vector3(nz.x, nz.y, zb + r * 2.0)
				# Pylone zu benachbarten Modulen
				for sx2 in [-1, 1]:
					var nb := Vector2i(x0 + (sx if sx2 > 0 else -1), z0)
					if cells.has(nb):
						gt.box(Vector3(C * 0.5, 0.45, ln * 0.55), 0.06, Geo.at(ctr.x + sx2 * (wd * 0.5 - C * 0.1), -0.1, ctr.z - ln * 0.05))
			"wing":
				var t := int(d.tier)
				var span := C * (1.35 + t * 0.15)
				var root_l := C * 0.95
				var tip_l := C * 0.34
				var sweep := C * (0.35 + t * 0.1)
				if side == 0.0:
					# Mittig: Seitenleitwerk
					var xf := Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(ctr.x, 0.95 + span * 0.5 - 0.2, ctr.z))
					gh.frustum(Vector2(0.22, root_l), Vector2(0.12, tip_l), span, xf, Vector2(0, sweep))
					ga.box(Vector3(0.24, 0.18, tip_l), 0.03, Geo.at(ctr.x, 0.95 + span - 0.25, ctr.z + sweep))
				else:
					var th := -PI / 2 if side > 0 else PI / 2
					var xf := Transform3D(Basis(Vector3.UP, th), Vector3(ctr.x + side * (span * 0.5 - C * 0.5), -0.15, ctr.z))
					gh.frustum(Vector2(root_l, 0.26), Vector2(tip_l, 0.14), span, xf, Vector2(sweep * side, 0))
					ga.box(Vector3(0.22, 0.2, tip_l + 0.1), 0.04, Geo.at(ctr.x + side * (span - C * 0.5 - 0.05), -0.15, ctr.z + sweep))
	if flames.size() > 0:
		light_pos /= flames.size()
	# Positionslichter an den äußersten Punkten
	var nav_r := Geo.new()
	var nav_g := Geo.new()
	var nav_w := Geo.new()
	var xl := lo.x * C - off.x - C * 0.5
	var xr := hi.x * C - off.x + C * 0.5
	for m in mods:
		if Game.MODULES[m[0]].cat == "wing":
			var d: Dictionary = Game.MODULES[m[0]]
			var span := C * (1.35 + int(d.tier) * 0.15)
			var cx: float = cpos.call(float(m[1]), 0.0).x
			if cx < -0.1:
				xl = minf(xl, cx - span + C * 0.5)
			elif cx > 0.1:
				xr = maxf(xr, cx + span - C * 0.5)
	nav_r.sphere(0.2, 8, 6, Geo.at(xl - 0.05, -0.1, 0.0), PI / 2)
	nav_g.sphere(0.2, 8, 6, Geo.at(xr + 0.05, -0.1, 0.0), PI / 2)
	nav_w.sphere(0.18, 8, 6, Geo.at(0, max_h * 0.5 + 0.12, hi.y * C - off.z), PI / 2)

	var half := Vector3((hi.x - lo.x + 1) * C * 0.5, max_h * 0.5, (hi.y - lo.y + 1) * C * 0.5)
	gh.to_node(root, hull_mat(hc, ac, Game.pattern_code(paint.pattern), half, 0.7, 0.15, 0.5))
	ga.to_node(root, hull_mat(ac, ac, 0, half, 0.6, 0.15, 0.45, 0.5))
	gp.to_node(root, hull_mat(hc * 0.6, ac, 0, half, 2.2, 0.3, 0.45, 0.8))
	gt.to_node(root, std(Color(0.28, 0.3, 0.34), 0.45, 0.45, 0.35))
	ge.to_node(root, std(Color(0.55, 0.57, 0.6), 0.7, 0.3))
	gl.to_node(root, std(Color(0.75, 0.77, 0.8), 0.5, 0.35))
	gy.to_node(root, std(Color(0.95, 0.76, 0.19), 0.3, 0.45))
	gk.to_node(root, hull_mat(hc.darkened(0.45), ac, 6, half, 0.8, 0.35, 0.5, 0.9))
	var glass := plain(Color(0.04, 0.08, 0.12), 0.95, 0.05)
	glass.emission_enabled = true
	glass.emission = Color(0.05, 0.18, 0.28)
	glass.emission_energy_multiplier = 0.6
	gg.to_node(root, glass)
	gf.to_node(root, emissive(fc, 5.0), false)
	var scol: Color = [Color(0.4, 0.7, 1.0), Color(0.45, 1.0, 0.8), Color(0.8, 0.55, 1.0), Color(1.0, 0.8, 0.4)][shield_tier]
	gsh.to_node(root, emissive(scol, 3.0), false)
	gpw.to_node(root, emissive(Color(0.75, 0.55, 1.0), 3.0), false)
	if guns.size() > 0:
		gm.to_node(root, emissive(Color.html(guns[0].color), 4.0), false)
	nav_r.to_node(root, emissive(Color(1.0, 0.2, 0.15), 8.0), false)
	nav_g.to_node(root, emissive(Color(0.2, 1.0, 0.4), 8.0), false)
	var strobe := emissive(Color(1, 1, 1), 10.0)
	nav_w.to_node(root, strobe, false)
	load.visible = false

	var light := OmniLight3D.new()
	light.light_color = fc
	light.omni_range = 16.0 + half.z
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
	root.set_meta("flame_len", flame_len)
	root.set_meta("guns", guns)
	root.set_meta("radius", maxf(half.z * 1.2, half.x * 1.4))
	return root

class_name Geo
extends RefCounted
## Baut eigene Geometrie (gefaste Kästen, Kegelstümpfe, Zylinder, Tori) zu einem Mesh zusammen.
## Alles landet in einem SurfaceTool, damit ein Schiff aus wenigen Draw-Calls besteht.

var st := SurfaceTool.new()
var count := 0

func _init() -> void:
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

static func _uv(p: Vector3, n: Vector3) -> Vector2:
	var a := n.abs()
	if a.x >= a.y and a.x >= a.z:
		return Vector2(p.z, p.y) * 0.25
	if a.y >= a.z:
		return Vector2(p.x, p.z) * 0.25
	return Vector2(p.x, p.y) * 0.25

## Ein Dreieck; Orientierung wird über die Normalen bestimmt (Godot: Vorderseite im Uhrzeigersinn).
func tri(a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3) -> void:
	var cr := (b - a).cross(c - a)
	if cr.dot(na + nb + nc) > 0.0:
		var t := b; b = c; c = t
		var tn := nb; nb = nc; nc = tn
	st.set_normal(na); st.set_uv(_uv(a, na)); st.add_vertex(a)
	st.set_normal(nb); st.set_uv(_uv(b, nb)); st.add_vertex(b)
	st.set_normal(nc); st.set_uv(_uv(c, nc)); st.add_vertex(c)
	count += 1

## Konvexes Polygon mit flacher Normale, nach außen gerichtet relativ zu `ctr`.
func poly(pts: Array, ctr: Vector3, xf: Transform3D) -> void:
	if pts.size() < 3:
		return
	var fc := Vector3.ZERO
	for p in pts:
		fc += p
	fc /= pts.size()
	var n: Vector3 = (pts[1] - pts[0]).cross(pts[2] - pts[0])
	if n.length_squared() < 1e-12:
		n = (pts[2] - pts[0]).cross(pts[pts.size() - 1] - pts[0])
	n = n.normalized()
	if n.dot(fc - ctr) < 0.0:
		n = -n
	var wn := (xf.basis * n).normalized()
	var w := []
	for p in pts:
		w.append(xf * p)
	for i in range(1, w.size() - 1):
		tri(w[0], w[i], w[i + 1], wn, wn, wn)

static func _cp(face: int, s: Vector3, h: Vector3, r: float) -> Vector3:
	var v := Vector3(s.x * (h.x - r), s.y * (h.y - r), s.z * (h.z - r))
	v[face] = s[face] * h[face]
	return v

## Kasten mit gefasten Kanten (Fase r).
func box(size: Vector3, r: float, xf: Transform3D) -> void:
	var h := size * 0.5
	r = clampf(r, 0.0, min(h.x, min(h.y, h.z)) * 0.9)
	var quad := [Vector2(1, 1), Vector2(1, -1), Vector2(-1, -1), Vector2(-1, 1)]
	for axis in 3:
		var u := (axis + 1) % 3
		var v := (axis + 2) % 3
		for sg in [-1.0, 1.0]:
			var pts := []
			for q in quad:
				var s := Vector3.ZERO
				s[axis] = sg; s[u] = q.x; s[v] = q.y
				pts.append(_cp(axis, s, h, r))
			poly(pts, Vector3.ZERO, xf)
	if r < 0.001:
		return
	for i in 3:
		for j in range(i + 1, 3):
			var k := 3 - i - j
			for si in [-1.0, 1.0]:
				for sj in [-1.0, 1.0]:
					var pts := []
					for sk in [-1.0, 1.0]:
						var s := Vector3.ZERO
						s[i] = si; s[j] = sj; s[k] = sk
						pts.append(_cp(i, s, h, r))
					for sk in [1.0, -1.0]:
						var s := Vector3.ZERO
						s[i] = si; s[j] = sj; s[k] = sk
						pts.append(_cp(j, s, h, r))
					poly(pts, Vector3.ZERO, xf)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var s := Vector3(sx, sy, sz)
				poly([_cp(0, s, h, r), _cp(1, s, h, r), _cp(2, s, h, r)], Vector3.ZERO, xf)

## Kegelstumpf-Kasten: hinten (+Z) Größe `back`, vorne (-Z) Größe `front`, vorne um `off` verschoben.
func frustum(back: Vector2, front: Vector2, length: float, xf: Transform3D, off := Vector2.ZERO) -> void:
	var zb := length * 0.5
	var zf := -length * 0.5
	var b := [Vector3(back.x / 2, back.y / 2, zb), Vector3(-back.x / 2, back.y / 2, zb), Vector3(-back.x / 2, -back.y / 2, zb), Vector3(back.x / 2, -back.y / 2, zb)]
	var f := [Vector3(front.x / 2 + off.x, front.y / 2 + off.y, zf), Vector3(-front.x / 2 + off.x, front.y / 2 + off.y, zf), Vector3(-front.x / 2 + off.x, -front.y / 2 + off.y, zf), Vector3(front.x / 2 + off.x, -front.y / 2 + off.y, zf)]
	var ctr := Vector3(off.x * 0.5, off.y * 0.5, 0.0)
	poly(b, ctr, xf)
	if front.x > 0.001 and front.y > 0.001:
		poly(f, ctr, xf)
	for i in 4:
		var j := (i + 1) % 4
		if front.x > 0.001 and front.y > 0.001:
			poly([b[i], b[j], f[j], f[i]], ctr, xf)
		else:
			poly([b[i], b[j], f[i]], ctr, xf)

## Zylinder/Kegel entlang Z von z0 (Radius r0) bis z1 (Radius r1). invert = Innenseite sichtbar.
func cyl(r0: float, r1: float, z0: float, z1: float, seg: int, xf: Transform3D, caps := true, invert := false) -> void:
	var slope := -(r1 - r0) / (z1 - z0)
	var sgn := -1.0 if invert else 1.0
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var c0 := Vector3(cos(a0), sin(a0), 0.0)
		var c1 := Vector3(cos(a1), sin(a1), 0.0)
		var p00 := xf * (c0 * r0 + Vector3(0, 0, z0))
		var p01 := xf * (c1 * r0 + Vector3(0, 0, z0))
		var p10 := xf * (c0 * r1 + Vector3(0, 0, z1))
		var p11 := xf * (c1 * r1 + Vector3(0, 0, z1))
		var n0 := (xf.basis * (Vector3(c0.x, c0.y, slope) * sgn)).normalized()
		var n1 := (xf.basis * (Vector3(c1.x, c1.y, slope) * sgn)).normalized()
		if r0 > 0.0001:
			tri(p00, p01, p11, n0, n1, n1)
		if r1 > 0.0001:
			tri(p00, p11, p10, n0, n1, n0)
		if caps and not invert:
			if r0 > 0.0001:
				var nc0 := (xf.basis * Vector3(0, 0, signf(z0 - z1))).normalized()
				tri(xf * Vector3(0, 0, z0), p00, p01, nc0, nc0, nc0)
			if r1 > 0.0001:
				var nc1 := (xf.basis * Vector3(0, 0, signf(z1 - z0))).normalized()
				tri(xf * Vector3(0, 0, z1), p10, p11, nc1, nc1, nc1)

## Torus in der XY-Ebene (Achse Z).
func torus(big_r: float, small_r: float, seg_major: int, seg_minor: int, xf: Transform3D) -> void:
	for i in seg_major:
		for j in seg_minor:
			var pts := []
			var nrm := []
			for d in [[0, 0], [1, 0], [1, 1], [0, 1]]:
				var th: float = TAU * (i + int(d[0])) / seg_major
				var ph: float = TAU * (j + int(d[1])) / seg_minor
				var n := Vector3(cos(ph) * cos(th), cos(ph) * sin(th), sin(ph))
				pts.append(xf * Vector3((big_r + small_r * cos(ph)) * cos(th), (big_r + small_r * cos(ph)) * sin(th), small_r * sin(ph)))
				nrm.append((xf.basis * n).normalized())
			tri(pts[0], pts[1], pts[2], nrm[0], nrm[1], nrm[2])
			tri(pts[0], pts[2], pts[3], nrm[0], nrm[2], nrm[3])

## Kugel (oder Kuppel, wenn max_lat < PI/2).
func sphere(r: float, seg: int, rings: int, xf: Transform3D, max_lat := PI / 2) -> void:
	for i in rings:
		var la0 := -PI / 2 + (max_lat + PI / 2) * i / rings
		var la1 := -PI / 2 + (max_lat + PI / 2) * (i + 1) / rings
		for j in seg:
			var lo0 := TAU * j / seg
			var lo1 := TAU * (j + 1) / seg
			var n := [Vector3(cos(la0) * cos(lo0), sin(la0), cos(la0) * sin(lo0)), Vector3(cos(la0) * cos(lo1), sin(la0), cos(la0) * sin(lo1)),
				Vector3(cos(la1) * cos(lo1), sin(la1), cos(la1) * sin(lo1)), Vector3(cos(la1) * cos(lo0), sin(la1), cos(la1) * sin(lo0))]
			var p := []
			var wn := []
			for k in 4:
				p.append(xf * (n[k] * r))
				wn.append((xf.basis * n[k]).normalized())
			if i > 0:
				tri(p[0], p[1], p[2], wn[0], wn[1], wn[2])
			tri(p[0], p[2], p[3], wn[0], wn[2], wn[3])

func commit() -> ArrayMesh:
	if count == 0:
		return null
	return st.commit()

## Erzeugt eine MeshInstance3D aus dem Gebauten und hängt sie an `parent`.
func to_node(parent: Node3D, mat: Material, shadows := true) -> MeshInstance3D:
	var m := commit()
	if m == null:
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

static func at(x: float, y: float, z: float) -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(x, y, z))

static func rot(x: float, y: float, z: float, euler: Vector3) -> Transform3D:
	return Transform3D(Basis.from_euler(euler), Vector3(x, y, z))

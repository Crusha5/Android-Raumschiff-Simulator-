class_name Universe
extends RefCounted
## Die Sternenkarte: Systeme, Stationen, Sprungtore, Handelsrouten, Gefahrenzonen.

const SYSTEMS := {
	"sol7": {
		"n": "Sol-7", "desc": "Heimatsystem · gesichert", "danger": 0.12,
		"sun_dir": Vector3(1.0, 0.35, 0.55), "sun_color": Color(1.0, 0.95, 0.88), "sun_energy": 1.7,
		"neb": [Color(0.36, 0.12, 0.46), Color(0.05, 0.30, 0.45), Color(0.70, 0.30, 0.16)], "band": Vector3(0.25, 0.9, 0.35),
		"planet": {"pos": Vector3(-26000, -16000, -52000), "r": 20000.0, "kind": 0, "atmo": Color(0.35, 0.65, 1.0),
			"c": [Color(0.02, 0.08, 0.18), Color(0.06, 0.24, 0.36), Color(0.30, 0.34, 0.20), Color(0.52, 0.44, 0.30)]},
		"moon": {"pos": Vector3(30000, 9000, -38000), "r": 2600.0},
		"stations": [
			{"id": "kepler", "n": "Kepler-Dock", "pos": Vector3(0, 0, -14000), "yaw": 0.4, "pitch": 0.05, "accent": Color(0.25, 0.66, 1.0), "kind": "hub", "shop": 1},
			{"id": "vesta", "n": "Vesta-Ring", "pos": Vector3(8000, 1400, -6500), "yaw": -2.1, "pitch": -0.08, "accent": Color(1.0, 0.71, 0.28), "kind": "hub", "shop": 2},
			{"id": "halden", "n": "Halden-Mine", "pos": Vector3(-7200, -900, -4200), "yaw": 2.6, "pitch": 0.1, "accent": Color(1.0, 0.42, 0.24), "kind": "mine", "shop": 1},
		],
		"gates": [{"id": "g_sol_vega", "to": "vega", "to_gate": "g_vega_sol", "pos": Vector3(15000, 2200, -24000), "yaw": 0.9}],
		"lanes": [["kepler", "vesta"], ["kepler", "g_sol_vega"]],
		"fields": [{"c": Vector3(-7200, -900, -4200), "r": 3600.0, "n": 260, "ice": false}],
		"zones": [{"c": Vector3(-7200, -900, -4200), "r": 5000.0}, {"c": Vector3(9000, 1500, -20000), "r": 4000.0}],
	},
	"vega": {
		"n": "Vega-Tiefe", "desc": "Industriesystem · Piratenaktivität", "danger": 0.4,
		"sun_dir": Vector3(-0.6, 0.3, 0.7), "sun_color": Color(0.85, 0.9, 1.0), "sun_energy": 1.8,
		"neb": [Color(0.14, 0.32, 0.75), Color(0.16, 0.62, 0.52), Color(0.6, 0.75, 1.0)], "band": Vector3(0.8, 0.3, 0.4),
		"planet": {"pos": Vector3(34000, -8000, -62000), "r": 28000.0, "kind": 1, "atmo": Color(1.0, 0.75, 0.45),
			"c": [Color(0.55, 0.38, 0.22), Color(0.82, 0.66, 0.45), Color(0.4, 0.22, 0.14), Color(0.95, 0.88, 0.72)]},
		"moon": {"pos": Vector3(-24000, 14000, -30000), "r": 1800.0},
		"stations": [
			{"id": "orion", "n": "Orion-Werft", "pos": Vector3(2000, 500, -9000), "yaw": 1.0, "pitch": 0.0, "accent": Color(0.62, 0.83, 1.0), "kind": "shipyard", "shop": 3},
			{"id": "hydra", "n": "Hydra-Raffinerie", "pos": Vector3(-9000, -1500, -16000), "yaw": -0.6, "pitch": 0.05, "accent": Color(0.5, 0.9, 0.55), "kind": "refinery", "shop": 2},
		],
		"gates": [
			{"id": "g_vega_sol", "to": "sol7", "to_gate": "g_sol_vega", "pos": Vector3(-12000, 1500, 3000), "yaw": -2.3},
			{"id": "g_vega_nyx", "to": "nyx", "to_gate": "g_nyx_vega", "pos": Vector3(16000, -2000, -20000), "yaw": 0.7},
		],
		"lanes": [["g_vega_sol", "orion"], ["orion", "hydra"], ["orion", "g_vega_nyx"]],
		"fields": [{"c": Vector3(-9000, -1500, -16000), "r": 4200.0, "n": 220, "ice": true}],
		"zones": [{"c": Vector3(-9000, -1500, -16000), "r": 6000.0}, {"c": Vector3(10000, -1000, -16000), "r": 5000.0}],
	},
	"nyx": {
		"n": "Nyx-Grenze", "desc": "Gesetzlos · hohe Gefahr", "danger": 0.85,
		"sun_dir": Vector3(0.2, 0.6, -0.7), "sun_color": Color(1.0, 0.58, 0.42), "sun_energy": 1.4,
		"neb": [Color(0.5, 0.08, 0.06), Color(0.25, 0.05, 0.3), Color(0.95, 0.4, 0.1)], "band": Vector3(0.1, 0.2, 0.95),
		"planet": {"pos": Vector3(-20000, 12000, -45000), "r": 15000.0, "kind": 2, "atmo": Color(1.0, 0.35, 0.2),
			"c": [Color(0.06, 0.03, 0.03), Color(0.2, 0.06, 0.04), Color(0.12, 0.1, 0.1), Color(1.0, 0.35, 0.08)]},
		"moon": {},
		"stations": [
			{"id": "freeport", "n": "Freihafen Nyx", "pos": Vector3(0, -800, -8000), "yaw": 2.2, "pitch": -0.05, "accent": Color(1.0, 0.31, 0.55), "kind": "freeport", "shop": 3},
		],
		"gates": [{"id": "g_nyx_vega", "to": "vega", "to_gate": "g_vega_nyx", "pos": Vector3(9000, 1000, 7000), "yaw": -2.6}],
		"lanes": [["g_nyx_vega", "freeport"]],
		"fields": [{"c": Vector3(-6000, 500, -15000), "r": 5000.0, "n": 300, "ice": false}],
		"zones": [{"c": Vector3(-6000, 500, -15000), "r": 7000.0}, {"c": Vector3(6000, 0, -2000), "r": 5000.0}],
	},
}

static func system(id: String) -> Dictionary:
	return SYSTEMS.get(id, {})

static func station(id: String) -> Dictionary:
	for sid in SYSTEMS:
		for st in SYSTEMS[sid].stations:
			if st.id == id:
				var d: Dictionary = st.duplicate()
				d["sys"] = sid
				return d
	return {}

static func gate(id: String) -> Dictionary:
	for sid in SYSTEMS:
		for g in SYSTEMS[sid].gates:
			if g.id == id:
				var d: Dictionary = g.duplicate()
				d["sys"] = sid
				return d
	return {}

static func all_stations() -> Array:
	var out := []
	for sid in SYSTEMS:
		for st in SYSTEMS[sid].stations:
			var d: Dictionary = st.duplicate()
			d["sys"] = sid
			out.append(d)
	return out

## Kürzester Weg über Sprungtore: Liste der Systeme von a nach b (inkl. beider).
static func path(a: String, b: String) -> Array:
	if a == b:
		return [a]
	var prev := {a: ""}
	var queue := [a]
	while queue.size() > 0:
		var cur: String = queue.pop_front()
		for g in SYSTEMS[cur].gates:
			var nx: String = g.to
			if not prev.has(nx):
				prev[nx] = cur
				if nx == b:
					var out := [b]
					var c := b
					while prev[c] != "":
						c = prev[c]
						out.push_front(c)
					return out
				queue.append(nx)
	return []

static func jumps(a: String, b: String) -> int:
	return maxi(0, path(a, b).size() - 1)

## Sprungtor im System `from`, das Richtung System `to` führt.
static func gate_towards(from: String, to: String) -> Dictionary:
	var p := path(from, to)
	if p.size() < 2:
		return {}
	for g in SYSTEMS[from].gates:
		if g.to == p[1]:
			var d: Dictionary = g.duplicate()
			d["sys"] = from
			return d
	return {}

static func object_pos(sys: String, id: String) -> Vector3:
	for st in SYSTEMS[sys].stations:
		if st.id == id:
			return st.pos
	for g in SYSTEMS[sys].gates:
		if g.id == id:
			return g.pos
	return Vector3.ZERO

## Grobe Reisestrecke zwischen zwei Stationen (für Lohn und Zeitlimit).
static func route_length(from_id: String, to_id: String) -> float:
	var a := station(from_id)
	var b := station(to_id)
	if a.sys == b.sys:
		return (a.pos as Vector3).distance_to(b.pos)
	var p := path(a.sys, b.sys)
	var total := 0.0
	var cur_pos: Vector3 = a.pos
	for i in range(p.size() - 1):
		var g := gate_towards(p[i], p[i + 1])
		total += cur_pos.distance_to(g.pos)
		cur_pos = gate(g.to_gate).pos
	total += cur_pos.distance_to(b.pos)
	return total

class_name Npc
extends ShipState
## KI-Schiff: Piraten greifen an, weichen aus und fliehen; Händler fliegen zwischen Stationen.

var ai := "approach"
var ai_t := 0.0
var break_dir := Vector3.ZERO
var speed_target := 0.0
var aim_err := 0.03
var dest := Vector3.ZERO
var dest_id := ""
var throttle := 0.6
var job_tag := ""   # z. B. "bounty" oder "loot"
var rng := RandomNumberGenerator.new()

## Blaupause eines Piratenschiffs: Vorlage nach Stufe, Module passend aufgewertet
static func pirate_bp(tier: int, r: RandomNumberGenerator) -> Dictionary:
	var pool := ["spatz", "hornisse"] if tier < 2 else (["hornisse", "pfeil"] if tier < 3 else ["pfeil", "hornisse", "kondor"])
	return tiered_bp(pool[r.randi() % pool.size()], tier, r)

static func trader_bp(r: RandomNumberGenerator) -> Dictionary:
	return tiered_bp(["esel", "esel", "kondor", "spatz"][r.randi() % 4], 1, r)

## Ersetzt jedes Modul durch eines derselben Kategorie und Größe mit passender Stufe
static func tiered_bp(tpl: String, tier: int, r: RandomNumberGenerator) -> Dictionary:
	for t in range(tier, -1, -1):
		var bp := _tiered_once(tpl, t, r)
		if Game.validate(bp).ok:
			return bp
	return Game.template_bp(tpl)

static func _tiered_once(tpl: String, tier: int, r: RandomNumberGenerator) -> Dictionary:
	var bp := Game.template_bp(tpl)
	var pick := {}
	for m in bp.mods:
		var d: Dictionary = Game.mod(m[0])
		if d.cat in ["cockpit", "hull", "cargo", "util", "wing"]:
			continue
		var key: String = "%s/%d/%d" % [d.cat, int(d.sz[0]), int(d.sz[1])]
		if not pick.has(key):
			var cands := []
			for id in Game.MODULES:
				var e: Dictionary = Game.MODULES[id]
				if e.cat == d.cat and int(e.sz[0]) == int(d.sz[0]) and int(e.sz[1]) == int(d.sz[1]) and absi(int(e.tier) - tier) <= (0 if d.cat == "power" else 1) and int(e.tier) <= tier:
					cands.append(id)
			pick[key] = cands[r.randi() % cands.size()] if not cands.is_empty() else m[0]
		m[0] = pick[key]
	return bp

static func pirate_paint(r: RandomNumberGenerator) -> Dictionary:
	var hulls := ["#1c1e22", "#4a4f58", "#5c6448", "#7a1030"]
	var accents := ["#a8322a", "#ff4f8b", "#f2c230", "#ff6a3d"]
	var pats := ["warn", "tarn", "zweiton", "renn"]
	return {"hull": hulls[r.randi() % 4], "accent": accents[r.randi() % 4], "pattern": pats[r.randi() % 4], "flame": "rot"}

static func trader_paint(r: RandomNumberGenerator) -> Dictionary:
	var hulls := ["#c9c2b2", "#e4e8ec", "#2f4a6b", "#1f6066", "#d9d2e6"]
	var accents := ["#ffb547", "#3fc1c9", "#e4e8ec", "#f2c230"]
	return {"hull": hulls[r.randi() % hulls.size()], "accent": accents[r.randi() % accents.size()], "pattern": ["band", "uni", "zweiton"][r.randi() % 3], "flame": "auto"}

func _turn_towards(dir: Vector3, dt: float) -> void:
	var fwd := forward()
	var ang_left := fwd.angle_to(dir)
	if ang_left < 0.0005:
		return
	var up := quat * Vector3.UP
	if absf(dir.normalized().dot(up)) > 0.98:
		up = quat * Vector3.BACK
	var target_q := Basis.looking_at(dir, up).get_rotation_quaternion()
	var rate := 1.15 * float(S.turn) * clampf(sqrt(30.0 / float(S.dry)), 0.5, 1.3)
	quat = quat.slerp(target_q, clampf(rate * dt / ang_left, 0.0, 1.0)).normalized()

func update_ai(dt: float, player: ShipState, world: SpaceWorld, combat) -> void:
	tick(dt)
	var fwd := forward()
	var vmax := float(S.vmax)
	var desired := fwd
	if faction == "trader":
		var to_d := dest - pos
		desired = to_d.normalized()
		speed_target = vmax * 0.55
		if to_d.length() < 300.0:
			alive = false   # angekommen, verschwindet in der Station
	else:
		var to_p := player.pos - pos
		var dist := to_p.length()
		match ai:
			"approach":
				desired = to_p / maxf(dist, 1.0)
				speed_target = vmax
				if dist < 1800.0:
					ai = "attack"
			"attack":
				var bs := float(weapon.speed)
				desired = ShipState.lead_dir(pos, vel, player.pos, player.vel, bs)
				speed_target = vmax if dist > 700.0 else vmax * 0.6
				if dist < 230.0:
					ai = "break"
					ai_t = rng.randf_range(1.4, 2.8)
					var side := (fwd.cross(quat * Vector3.UP)).normalized() * (1.0 if rng.randf() < 0.5 else -1.0)
					break_dir = (side + (quat * Vector3.UP) * rng.randf_range(-0.6, 0.6) + fwd * 0.3).normalized()
				if hull_frac() < 0.22 and rng.randf() < 0.004:
					ai = "flee"
				if fwd.angle_to(desired) < 0.11 and dist < float(weapon.range) * 0.9 and player.alive:
					_fire(combat, desired)
			"break":
				desired = break_dir
				speed_target = vmax
				ai_t -= dt
				if ai_t <= 0.0:
					ai = "attack"
			"flee":
				desired = -to_p / maxf(dist, 1.0)
				speed_target = vmax
				if dist > 4500.0:
					alive = false
					job_tag = "fled"
	# Stationen und Planet ausweichen
	for st in world.stations:
		var node: Node3D = st.node
		var d := pos.distance_to(node.position)
		if d < 450.0:
			desired = (desired + (pos - node.position).normalized() * 2.0).normalized()
	if pos.distance_to(world.planet_pos) < world.planet_r + 1500.0:
		desired = (desired + (pos - world.planet_pos).normalized() * 2.0).normalized()
	_turn_towards(desired, dt)
	var accel := float(S.thrust) / float(S.dry)
	vel = vel.move_toward(forward() * speed_target, accel * dt)
	pos += vel * dt
	throttle = clampf(speed_target / vmax, 0.0, 1.0)

func _fire(combat, aim: Vector3) -> void:
	fire_groups(combat, func(_w): return aim, 0.55, aim_err, rng)

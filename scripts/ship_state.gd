class_name ShipState
extends RefCounted
## Zustand eines Schiffs im All (Spieler oder NPC): Position, Werte, Schild, Energie, Modell.

const SHIELD_SHADER := preload("res://shaders/shield.gdshader")

var bp: Dictionary
var paint: Dictionary
var S: Dictionary
var pos := Vector3.ZERO
var vel := Vector3.ZERO
var quat := Quaternion.IDENTITY
var ang := Vector3.ZERO
var hp := 100.0
var shield := 0.0
var shield_delay := 0.0
var energy := 100.0
var faction := "player"      # player, pirate, trader
var name := ""
var model: Node3D
var radius := 8.0
var shield_mat: ShaderMaterial
var shield_hit := 0.0
var fire_cd := 0.0
var alive := true
var is_player := false
var leader := false
var reward := 0
var xp := 0
var gun_offsets: Array = []
var weapon: Dictionary = {}     # Hauptwaffe (für Vorhaltepunkt und KI)
var groups: Array = []          # [{w, offs: [Vector3], cd}]
var _tune: Dictionary = {}

func setup(b: Dictionary, p: Dictionary, parent: Node3D, tune: Dictionary = {}) -> void:
	bp = b
	paint = p
	_tune = tune
	S = Game.bp_stats(bp, tune)
	hp = float(S.hp_max)
	shield = float(S.shield)
	energy = float(S.energy)
	rebuild_model(parent)

func rebuild_model(parent: Node3D) -> void:
	if model and is_instance_valid(model):
		model.queue_free()
	model = ShipBuilder.build(bp, paint)
	parent.add_child(model)
	var dim: Vector3 = S.dim
	radius = maxf(dim.z * 0.5, dim.x * 0.8)
	# Waffen nach Typ gruppieren: jede Gruppe feuert mit eigener Kadenz
	gun_offsets = []
	groups = []
	var by_id := {}
	for g in model.get_meta("guns"):
		gun_offsets.append(g.pos)
		if not by_id.has(g.id):
			var w: Dictionary = Game.mod(g.id).duplicate()
			w.dmg = float(w.dmg) * (1.0 + 0.07 * int(_tune.get(g.id, 0)))
			by_id[g.id] = {"w": w, "offs": [], "cd": 0.0}
			groups.append(by_id[g.id])
		by_id[g.id].offs.append(g.pos)
	weapon = {}
	var best := -1.0
	for gr in groups:
		var dps: float = float(gr.w.dmg) * float(gr.w.rate) * float(gr.offs.size())
		if dps > best:
			best = dps
			weapon = gr.w
	if weapon.is_empty():
		weapon = Game.mod("puls1").duplicate()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 32
	sm.rings = 16
	var sh := MeshInstance3D.new()
	sh.mesh = sm
	shield_mat = ShaderMaterial.new()
	shield_mat.shader = SHIELD_SHADER
	var tier := 0
	for m in bp.mods:
		if Game.mod(m[0]).cat == "shield":
			tier = maxi(tier, int(Game.mod(m[0]).tier))
	shield_mat.set_shader_parameter("col", [Color(0.4, 0.7, 1.0), Color(0.45, 1.0, 0.8), Color(0.8, 0.55, 1.0), Color(1.0, 0.8, 0.4)][tier])
	sh.material_override = shield_mat
	sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sh.scale = Vector3(dim.x * 0.9 + 2.0, dim.y * 1.3 + 2.0, dim.z * 0.62 + 1.5)
	sh.position = Vector3(0, -dim.y * 0.15, dim.z * 0.05)
	model.add_child(sh)

func hull_frac() -> float:
	return clampf(hp / float(S.hp_max), 0.0, 1.0)

func shield_frac() -> float:
	return clampf(shield / maxf(float(S.shield), 1.0), 0.0, 1.0)

func forward() -> Vector3:
	return quat * Vector3(0, 0, -1)

## Schaden: zuerst Schild, dann Hülle. Gibt den Hüllenschaden zurück.
func take_damage(amount: float, from_dir: Vector3) -> float:
	shield_delay = 3.0
	shield_hit = 1.0
	if shield_mat:
		shield_mat.set_shader_parameter("hit_dir", (quat.inverse() * from_dir).normalized())
	if shield > 0.0:
		var absorbed := minf(shield, amount)
		shield -= absorbed
		amount -= absorbed
	var dmg := amount * float(S.dmg)
	hp -= dmg
	if hp <= 0.0:
		alive = false
	return dmg

func tick(dt: float) -> void:
	shield_delay -= dt
	if shield_delay <= 0.0:
		shield = minf(float(S.shield), shield + float(S.shield_regen) * dt)
	energy = minf(float(S.energy), energy + float(S.energy_regen) * dt)
	fire_cd -= dt
	for gr in groups:
		gr.cd -= dt
	if shield_hit > 0.0:
		shield_hit = maxf(0.0, shield_hit - dt * 2.5)
	if shield_mat:
		shield_mat.set_shader_parameter("hit", shield_hit * (1.0 if shield > 0.0 else 0.25))

func sync_model() -> void:
	if model:
		model.global_position = pos
		model.quaternion = quat

func set_engine(power: float, rng: RandomNumberGenerator, t0: float) -> void:
	if not model:
		return
	var flen: float = model.get_meta("flame_len")
	for fl in model.get_meta("flames"):
		fl.scale.z = flen * (0.25 + power * 2.4 + rng.randf() * power * 0.35)
		fl.material_override.set_shader_parameter("power", 0.2 + power * 0.9)
	model.get_meta("eng_light").light_energy = power * 3.0
	if model.has_meta("beacon"):
		model.get_meta("beacon").emission_energy_multiplier = 1.0 + 7.0 * max(0.0, sin(t0 * 4.0))
	model.get_meta("strobe").emission_energy_multiplier = 14.0 if fmod(t0, 1.4) < 0.08 else 0.4

## Feuert alle bereiten Waffengruppen. rate_mult < 1 für langsamere KI.
func fire_groups(combat, aim_for: Callable, rate_mult := 1.0, spread := 0.0, rng: RandomNumberGenerator = null) -> bool:
	var fired := false
	for gr in groups:
		var w: Dictionary = gr.w
		var cost: float = float(w.energy) * float(gr.offs.size())
		if gr.cd > 0.0 or energy < cost:
			continue
		gr.cd = 1.0 / (float(w.rate) * rate_mult)
		energy -= cost
		var aim: Vector3 = aim_for.call(w)
		for o in gr.offs:
			var dir := aim
			if spread > 0.0 and rng:
				dir = (aim + Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * spread).normalized()
			combat.spawn_bolt(self, pos + quat * (o as Vector3), dir, w)
		fired = true
	return fired

## Mündungen der Waffen in Weltkoordinaten
func muzzles() -> Array:
	var out := []
	for o in gun_offsets:
		out.append(pos + quat * (o as Vector3))
	return out

## Vorhaltepunkt: Richtung, in die ein Geschoss mit `speed` fliegen muss, um `t` zu treffen.
static func lead_dir(sp: Vector3, sv: Vector3, tp: Vector3, tv: Vector3, speed: float) -> Vector3:
	var r := tp - sp
	var v := tv - sv
	var a := v.dot(v) - speed * speed
	var b := 2.0 * r.dot(v)
	var c := r.dot(r)
	var t := 0.0
	if absf(a) < 0.001:
		t = -c / b if absf(b) > 0.001 else 0.0
	else:
		var disc := b * b - 4.0 * a * c
		if disc >= 0.0:
			var sq := sqrt(disc)
			var t1 := (-b - sq) / (2.0 * a)
			var t2 := (-b + sq) / (2.0 * a)
			t = minf(t1, t2) if minf(t1, t2) > 0.0 else maxf(t1, t2)
	if t <= 0.0:
		return r.normalized()
	return (r + v * t).normalized()

static func lead_point(sp: Vector3, sv: Vector3, tp: Vector3, tv: Vector3, speed: float) -> Vector3:
	var d := lead_dir(sp, sv, tp, tv, speed)
	var dist := sp.distance_to(tp)
	return sp + d * dist

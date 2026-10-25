extends Node3D
## Frachtpilot – Hauptskript: Spielzustand, Flugphysik, Andocken, Aufträge, Werft, Kamera.

const K = preload("res://scripts/ui_kit.gd")

var world: SpaceWorld
var hangar: Hangar
var world_env: WorldEnvironment
var cam: Camera3D
var cockpit: Node3D
var ui_root: Control
var hud: Hud
var station_ui: StationUI
var menu_layer: Control
var menu_box: VBoxContainer
var intro_layer: Control

var ship_model: Node3D
var state := "docked"
var pos := Vector3.ZERO
var vel := Vector3.ZERO
var quat := Quaternion.IDENTITY
var ang := Vector3.ZERO
var fa := true
var hull := 100.0
var dock_at: Dictionary
var job: Dictionary = {}
var offers: Array = []
var last_result: Dictionary = {}
var nav_target = null
var S: Dictionary
var preview_fit: Dictionary = {}
var pend_paint: Dictionary = {}
var cam_mode := "cockpit"
var hit_cd := 0.0
var t0 := 0.0
var anim: Dictionary = {}
var chase_init := false
var cam_pos := Vector3.ZERO
var cam_q := Quaternion.IDENTITY
var reset_armed := false
var rng := RandomNumberGenerator.new()
var accel_now := 0.0

func _ready() -> void:
	rng.randomize()
	S = Game.stats(Game.s.fit)
	hull = float(Game.s.hull)

	world_env = WorldEnvironment.new()
	add_child(world_env)
	world = SpaceWorld.new()
	add_child(world)
	hangar = Hangar.new()
	add_child(hangar)

	cam = Camera3D.new()
	cam.fov = 60.0
	cam.near = 0.05
	cam.far = 300000.0
	add_child(cam)
	_build_cockpit()

	var layer := CanvasLayer.new()
	add_child(layer)
	ui_root = Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.theme = K.make_theme()
	layer.add_child(ui_root)
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud = Hud.new()
	ui_root.add_child(hud)
	hud.cam_pressed.connect(toggle_cam)
	hud.fa_pressed.connect(toggle_fa)
	hud.menu_pressed.connect(open_menu)
	hud.invert_y = bool(Game.s.invert_y)
	station_ui = StationUI.new()
	station_ui.main = self
	ui_root.add_child(station_ui)
	_build_menu()
	_build_intro()

	var si := clampi(int(Game.s.station), 0, world.stations.size() - 1)
	dock_at = world.stations[si]
	rebuild_flight_ship()
	place_docked(dock_at)
	make_offers(dock_at)
	enter_hangar()
	intro_layer.visible = not bool(Game.s.intro_seen)

# ------------------------------------------------------------------ Aufbau
func _build_cockpit() -> void:
	cockpit = Node3D.new()
	cam.add_child(cockpit)
	var gf := Geo.new()
	var gs := Geo.new()
	var gi := Geo.new()
	for sx in [-1.0, 1.0]:
		gf.box(Vector3(0.07, 1.7, 0.12), 0.02, Geo.rot(sx * 1.2, 0.05, -1.0, Vector3(0, 0, sx * 0.3)))
		gf.box(Vector3(0.9, 0.05, 0.1), 0.015, Geo.rot(sx * 0.95, 0.6, -1.02, Vector3(0, 0, -sx * 0.35)))
	gf.box(Vector3(3.0, 0.32, 0.7), 0.04, Geo.rot(0, -0.69, -1.05, Vector3(0.3, 0, 0)))
	gs.box(Vector3(0.26, 0.09, 0.01), 0.004, Geo.rot(-0.62, -0.535, -0.79, Vector3(-1.1, 0.2, 0)))
	gs.box(Vector3(0.26, 0.09, 0.01), 0.004, Geo.rot(0.62, -0.535, -0.79, Vector3(-1.1, -0.2, 0)))
	gi.box(Vector3(1.2, 0.006, 0.006), 0.001, Geo.at(0, -0.528, -0.86))
	gf.to_node(cockpit, ShipBuilder.std(Color(0.045, 0.05, 0.06), 0.3, 0.7), true)
	gs.to_node(cockpit, ShipBuilder.emissive(Color(0.3, 0.55, 0.8), 0.6), false)
	gi.to_node(cockpit, ShipBuilder.emissive(Color(1.0, 0.71, 0.28), 1.6), false)

func _overlay(alpha := 0.55) -> Control:
	var c := ColorRect.new()
	c.color = Color(0.01, 0.015, 0.03, alpha)
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_root.add_child(c)
	return c

func _center_panel(parent: Control, width: float) -> VBoxContainer:
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(cc)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(width, 0)
	cc.add_child(p)
	var v := K.vbox(12)
	p.add_child(v)
	return v

func _build_menu() -> void:
	menu_layer = _overlay()
	menu_box = _center_panel(menu_layer, 460)
	menu_layer.visible = false

func _build_intro() -> void:
	intro_layer = _overlay(0.6)
	var v := _center_panel(intro_layer, 560)
	v.add_child(K.lbl("Willkommen an Bord, Pilot", 24, K.FG, K.F_BOLD))
	v.add_child(K.wrap("Du startest als Kadett mit einem kleinen Frachter im System Sol-7. Nimm Aufträge an, dock an der Zielstation an und kassier den Lohn. In der Werft tauschst du Triebwerk, Rumpf, Frachtraum und mehr, in der Lackiererei gestaltest du dein Schiff. Jeder Rang schaltet neue Teile und bessere Aufträge frei. Lieferst du ohne Kratzer, steigt dein Serienbonus.", 13, K.FG))
	var keys := RichTextLabel.new()
	keys.bbcode_enabled = true
	keys.fit_content = true
	keys.scroll_active = false
	keys.add_theme_font_override("normal_font", K.F_REG)
	keys.add_theme_font_override("bold_font", K.F_SEMI)
	keys.add_theme_font_size_override("normal_font_size", 13)
	keys.add_theme_font_size_override("bold_font_size", 13)
	keys.text = "[color=#ffb547][b]Linke Hälfte ziehen[/b][/color] – Nase hoch/runter, links/rechts\n[color=#ffb547][b]Rolltasten[/b][/color] – um die Längsachse rollen\n[color=#ffb547][b]Schubhebel[/b][/color] – Zielgeschwindigkeit, unter Null rückwärts\n[color=#7fe08a][b]Grüner Kreis[/b][/color] – deine tatsächliche Flugrichtung\n[color=#9fd4ff][b]Blaue Raute[/b][/color] – Zielstation\n[b]Andocken[/b] – durch den grünen Lichterkorridor, unter 30 m/s in die Bucht\n[b]FA[/b] – Flugassistent; aus = reine Newton-Physik"
	v.add_child(keys)
	v.add_child(K.btn("Verstanden", func():
		intro_layer.visible = false
		Game.s.intro_seen = true
		Game.save_game(), true))

# ------------------------------------------------------------------ Schiff
func rebuild_flight_ship() -> void:
	if ship_model:
		ship_model.queue_free()
	ship_model = ShipBuilder.build(Game.s.fit, Game.s.paint)
	world.add_child(ship_model)
	_set_load(ship_model)

func _set_load(n: Node3D) -> void:
	var l: Node3D = n.get_meta("load")
	l.visible = not job.is_empty()

func rebuild_hangar_ship() -> void:
	var s := ShipBuilder.build(view_fit(), view_paint())
	_set_load(s)
	hangar.set_ship(s)

func view_fit() -> Dictionary:
	return preview_fit if not preview_fit.is_empty() else Game.s.fit

func view_paint() -> Dictionary:
	return pend_paint if not pend_paint.is_empty() else Game.s.paint

func ship_hull() -> float:
	return hull

func dock_station() -> Dictionary:
	return dock_at

# ------------------------------------------------------------------ Aufträge
func lock_reason(o: Dictionary) -> String:
	if int(o.rank) > Game.rank():
		return "Ab Rang " + Game.rank_name(int(o.rank))
	if int(o.mass) > int(S.cap):
		return "Braucht %d t Frachtraum" % int(o.mass)
	return ""

func make_offers(st: Dictionary) -> void:
	var others := world.stations.filter(func(x): return x != st)
	var rk := Game.rank()
	for _try in 12:
		offers = []
		for i in 4:
			var pool := Game.CARGO.filter(func(c): return (not c.has("from") or c.from == st.kind) and int(c.r) <= rk + 1)
			var c: Dictionary = pool[rng.randi() % pool.size()]
			var dest: Dictionary = others[rng.randi() % others.size()]
			var dist: float = st.node.position.distance_to(dest.node.position)
			var mass := rng.randi_range(int(c.m[0]), int(c.m[1]))
			var pay := roundi(dist / 1000.0 * (40.0 + mass * 3.0) * float(c.p) * (1.0 + int(c.r) * 0.08) / 10.0) * 10
			var tm := roundi((dist / 190.0 + 70.0) * (0.68 if c.get("express", false) else 1.0))
			offers.append({"cargo": c.n, "fragile": c.get("fragile", false), "express": c.get("express", false), "rank": int(c.r),
				"mass": mass, "dest": dest, "dist": dist, "pay": pay, "time": tm})
		var open := 0
		for o in offers:
			if lock_reason(o) == "":
				open += 1
		if open >= 2:
			break
	offers.sort_custom(func(a, b): return int(lock_reason(a) != "") < int(lock_reason(b) != ""))

func next_goal() -> Dictionary:
	var rk := Game.rank()
	var best := {}
	for slot in Game.SLOTS:
		var k: String = slot[0]
		var cur_price := int(Game.part(k, Game.s.fit[k]).price)
		for id in Game.PARTS[k]:
			var p: Dictionary = Game.PARTS[k][id]
			if Game.s.owned[k].has(id) or int(p.rank) > rk or int(p.price) <= cur_price:
				continue
			if k == "cargo" and int(p.size) > int(Game.part("frame", Game.s.fit.frame).max_mod):
				continue
			if best.is_empty() or int(p.price) < int(best.p.price):
				best = {"k": k, "id": id, "p": p}
	return best

func take_offer(i: int) -> void:
	var o: Dictionary = offers[i]
	job = o.duplicate()
	job.pay = roundi(float(o.pay) * Game.streak_mult())
	job.time = roundi(float(o.time) * float(S.time))
	job.cond = 100.0
	job.elapsed = 0.0
	last_result = {}
	nav_target = job.dest
	_set_load(ship_model)
	rebuild_hangar_ship()
	station_ui.refresh()

func cancel_job() -> void:
	Game.s.credits = int(Game.s.credits) - roundi(float(job.pay) * 0.25)
	job = {}
	nav_target = null
	_set_load(ship_model)
	rebuild_hangar_ship()
	make_offers(dock_at)
	Game.save_game()
	station_ui.refresh()

func repair() -> void:
	var cost := roundi(roundi(100.0 - hull) * float(S.hp_max) * 0.09)
	if int(Game.s.credits) >= cost:
		Game.s.credits = int(Game.s.credits) - cost
		hull = 100.0
		Game.s.hull = 100.0
		Game.save_game()
		station_ui.refresh()

# ------------------------------------------------------------------ Werft & Lack
func clear_previews() -> void:
	if not preview_fit.is_empty() or not pend_paint.is_empty():
		preview_fit = {}
		pend_paint = {}
		rebuild_hangar_ship()

func try_part(slot: String, id: String) -> void:
	var f: Dictionary = Game.s.fit.duplicate()
	f[slot] = id
	f = Game.fix_cargo(f)
	f[slot] = id
	preview_fit = {} if f == Game.s.fit else f
	rebuild_hangar_ship()
	station_ui.refresh()

func equip(slot: String, id: String) -> void:
	Game.s.fit[slot] = id
	Game.fix_cargo(Game.s.fit)
	S = Game.stats(Game.s.fit)
	preview_fit = {}
	Game.save_game()
	rebuild_flight_ship()
	rebuild_hangar_ship()
	if job.is_empty():
		make_offers(dock_at)
	station_ui.refresh()

func buy(slot: String, id: String) -> void:
	var p := Game.part(slot, id)
	if int(Game.s.credits) < int(p.price):
		return
	Game.s.credits = int(Game.s.credits) - int(p.price)
	Game.s.owned[slot].append(id)
	hud.show_banner(p.n + " gekauft und eingebaut", K.OK, 2.2)
	equip(slot, id)

func set_paint(key: String, val: String) -> void:
	var p: Dictionary = view_paint().duplicate()
	p[key] = val
	pend_paint = {} if p == Game.s.paint else p
	rebuild_hangar_ship()
	station_ui.refresh()

func paint_cost(p: Dictionary) -> int:
	var c := 0
	var sp: Dictionary = Game.s.paint
	if p.hull != sp.hull or p.accent != sp.accent or p.pattern != sp.pattern:
		c += Game.PAINT_FEE
	if not Game.s.patterns.has(p.pattern):
		for pt in Game.PATTERNS:
			if pt.id == p.pattern:
				c += int(pt.price)
	return c

func apply_paint() -> void:
	var cost := paint_cost(pend_paint)
	if int(Game.s.credits) < cost:
		return
	Game.s.credits = int(Game.s.credits) - cost
	if not Game.s.patterns.has(pend_paint.pattern):
		Game.s.patterns.append(pend_paint.pattern)
	Game.s.paint = pend_paint
	pend_paint = {}
	Game.save_game()
	rebuild_flight_ship()
	rebuild_hangar_ship()
	station_ui.refresh()

func reset_paint() -> void:
	pend_paint = {}
	rebuild_hangar_ship()
	station_ui.refresh()

func rename(t: String) -> void:
	t = t.strip_edges().substr(0, 18)
	if t != "" and t != Game.s.name:
		Game.s.name = t
		Game.save_game()
		station_ui.refresh()

# ------------------------------------------------------------------ Andocken
func place_docked(st: Dictionary) -> void:
	var n: Node3D = st.node
	pos = n.to_global(Vector3(0, 0, 165))
	quat = n.global_basis.get_rotation_quaternion()
	vel = Vector3.ZERO
	ang = Vector3.ZERO

func enter_hangar() -> void:
	state = "docked"
	world.visible = false
	hangar.visible = true
	world_env.environment = hangar.env
	hangar.cam.make_current()
	hud.visible = false
	hud.release_all()
	station_ui.visible = true
	hangar.panel_frac = StationUI.PANEL_FRAC
	station_ui.tab = "fracht"
	rebuild_hangar_ship()
	station_ui.refresh()

func undock() -> void:
	preview_fit = {}
	pend_paint = {}
	menu_layer.visible = false
	station_ui.visible = false
	hangar.visible = false
	world.visible = true
	world_env.environment = world.env
	cam.make_current()
	hud.visible = true
	var n: Node3D = dock_at.node
	pos = n.to_global(Vector3(0, 0, 330))
	quat = n.global_basis.get_rotation_quaternion() * Quaternion(Vector3.UP, PI)
	vel = quat * Vector3(0, 0, -1) * 30.0
	ang = Vector3.ZERO
	state = "flying"
	hud.set_throttle(30.0 / float(S.vmax))
	last_result = {}
	chase_init = false
	if not job.is_empty():
		job.elapsed = 0.0
		nav_target = job.dest
	hud.show_banner("Abgedockt – gute Reise", K.OK, 2.5)
	_update_topbar()

func begin_dock(st: Dictionary) -> void:
	state = "docking"
	hud.set_throttle(0.0)
	var n: Node3D = st.node
	anim = {"st": st, "t": 0.0, "p0": pos, "q0": quat, "p1": n.to_global(Vector3(0, 0, 165)), "q1": n.global_basis.get_rotation_quaternion()}
	hud.show_banner("Andockklammern greifen …", K.OK)

func finish_dock(st: Dictionary) -> void:
	dock_at = st
	Game.s.station = world.stations.find(st)
	hud.hide_banner()
	if not job.is_empty() and job.dest == st:
		var in_time: bool = float(job.elapsed) <= float(job.time)
		var cond: float = max(0.0, float(job.cond))
		var perfect := cond >= 95.0
		var bonus := roundi(float(job.pay) * 0.25) if in_time else 0
		var pay := roundi(float(job.pay) * cond / 100.0) + bonus
		var rk0 := Game.rank()
		var xp := roundi(pay / 12.0) + (20 if perfect else 0) + (15 if in_time else 0)
		Game.s.credits = int(Game.s.credits) + pay
		Game.s.deliveries = int(Game.s.deliveries) + 1
		Game.s.xp = int(Game.s.xp) + xp
		if perfect:
			Game.s.streak = int(Game.s.streak) + 1
			Game.s.best = max(int(Game.s.best), int(Game.s.streak))
		else:
			Game.s.streak = 0
		var rk1 := Game.rank()
		var txt := "[b]%s[/b] ausgeliefert · Zustand %d%% · Flugzeit %s\nLohn [b]%s cr[/b]%s · +%d EP" % [job.cargo, roundi(cond), Game.mmss(job.elapsed), Game.fmt(pay), (" inkl. Pünktlichkeitsbonus %s cr" % Game.fmt(bonus)) if bonus > 0 else "", xp]
		if perfect:
			txt += "\n[color=#7fe08a]Ohne Kratzer: Serie %d, nächster Lohn ×%s[/color]" % [int(Game.s.streak), String.num(Game.streak_mult(), 2).replace(".", ",")]
		elif int(Game.s.best) > 0:
			txt += "\nLadung beschädigt: Serie verloren"
		if rk1 > rk0:
			var un := []
			for slot in Game.SLOTS:
				for id in Game.PARTS[slot[0]]:
					if int(Game.PARTS[slot[0]][id].rank) == rk1:
						un.append(Game.PARTS[slot[0]][id].n)
			txt += "\n\n[color=#ffb547][b]Befördert zum %s![/b][/color]%s" % [Game.rank_name(rk1), (" Neu in der Werft: " + ", ".join(un)) if un.size() > 0 else ""]
		last_result = {"text": txt}
		job = {}
		nav_target = null
	Game.s.hull = hull
	Game.save_game()
	_set_load(ship_model)
	make_offers(st)
	enter_hangar()
	_update_topbar()

# ------------------------------------------------------------------ Schaden
func collide(normal: Vector3, impact: float) -> void:
	if hit_cd > 0.0:
		return
	hit_cd = 0.4
	var vn := vel.dot(normal)
	if vn < 0.0:
		vel -= normal * vn * 1.4
	vel *= 0.5
	var raw: float = clampf(impact * 0.22, 3.0, 70.0) * float(S.dmg)
	hull -= raw * 100.0 / float(S.hp_max)
	if not job.is_empty():
		job.cond = float(job.cond) - raw * (1.8 if job.fragile else 0.7) * float(S.fragile)
	hud.flash()
	if int(Game.s.streak) > 0 and not job.is_empty():
		Game.s.streak = 0
		hud.show_banner("Kratzer! Lieferserie verloren", K.DANGER, 2.2)
	if hull <= 0.0:
		destroyed()
		return
	if hud.banner_free():
		hud.show_banner("Kollision · Hülle %d%%" % maxi(0, roundi(hull)), K.DANGER, 1.8)

func destroyed() -> void:
	var cost := roundi((600.0 + Game.rank() * 400.0) * float(S.salvage))
	last_result = {"bad": true, "text": "[b]Schiff zerstört.[/b] Bergung und Reparatur: −%s cr%s" % [Game.fmt(cost), ("\nDie Ladung %s ist verloren." % job.cargo) if not job.is_empty() else ""]}
	Game.s.credits = int(Game.s.credits) - cost
	Game.s.streak = 0
	job = {}
	nav_target = null
	hull = 100.0
	place_docked(dock_at)
	finish_dock(dock_at)

# ------------------------------------------------------------------ Physik
func _key(a: int, b: int) -> float:
	return 1.0 if Input.is_physical_key_pressed(a) or Input.is_physical_key_pressed(b) else 0.0

func physics(dt: float) -> void:
	var kp := _key(KEY_W, KEY_UP) - _key(KEY_S, KEY_DOWN)
	var ky := _key(KEY_A, KEY_LEFT) - _key(KEY_D, KEY_RIGHT)
	var kr := _key(KEY_Q, KEY_Q) - _key(KEY_E, KEY_E)
	if Input.is_physical_key_pressed(KEY_R):
		hud.set_throttle(hud.throttle + dt * 0.6)
	if Input.is_physical_key_pressed(KEY_F):
		hud.set_throttle(hud.throttle - dt * 0.6)
	var sy := hud.stick.y * (1.0 if bool(Game.s.invert_y) else -1.0)
	var sx := hud.stick.x
	var ip := clampf(kp + signf(sy) * sy * sy, -1.0, 1.0)
	var iy := clampf(ky - signf(sx) * sx * sx, -1.0, 1.0)
	var ir := clampf(kr + hud.roll, -1.0, 1.0)

	var mass: float = float(S.dry) + (float(job.mass) if not job.is_empty() else 0.0)
	var agility: float = float(S.turn) * clampf(sqrt(30.0 / mass), 0.45, 1.25)
	var r_acc: float = 3.2 * float(S.turn) * clampf(30.0 / mass, 0.3, 1.3)
	var tgt := Vector3(ip * 1.05, iy * 0.75, ir * 1.7) * agility
	ang.x = move_toward(ang.x, tgt.x, r_acc * dt)
	ang.y = move_toward(ang.y, tgt.y, r_acc * dt)
	ang.z = move_toward(ang.z, tgt.z, r_acc * dt)
	quat = (quat * Quaternion.from_euler(ang * dt)).normalized()

	var fwd := quat * Vector3(0, 0, -1)
	var rgt := quat * Vector3(1, 0, 0)
	var upv := quat * Vector3(0, 1, 0)
	var main_a: float = float(S.thrust) / mass
	var rcs: float = main_a * 0.4 * float(S.strafe)
	var thr := hud.throttle
	if fa:
		var dv := fwd * (thr * float(S.vmax)) - vel
		var df := dv.dot(fwd)
		var dr := dv.dot(rgt)
		var du := dv.dot(upv)
		var lim := (main_a if df > 0.0 else rcs * 1.6) * dt
		var af := clampf(df, -lim, lim)
		vel += fwd * af + rgt * clampf(dr, -rcs * dt, rcs * dt) + upv * clampf(du, -rcs * dt, rcs * dt)
		accel_now = af / dt
	else:
		var a := thr * main_a if thr >= 0.0 else (thr / -Hud.THR_MIN) * rcs * 1.6
		vel += fwd * a * dt
		accel_now = a
	pos += vel * dt
	hit_cd -= dt

	var sp := vel.length()
	var sr: float = S.dim.z * 0.45
	var dp := pos - SpaceWorld.PLANET_POS
	if dp.length() < SpaceWorld.PLANET_R + 150.0:
		pos = SpaceWorld.PLANET_POS + dp.normalized() * (SpaceWorld.PLANET_R + 160.0)
		collide(dp.normalized(), max(sp, 200.0))
	for r in world.rocks:
		var d: float = pos.distance_to(r.p)
		if d < r.r + sr:
			var n: Vector3 = (pos - r.p).normalized()
			pos = r.p + n * (r.r + sr + 0.5)
			collide(n, sp)
	for st in world.stations:
		var node: Node3D = st.node
		var d := pos.distance_to(node.position)
		if d > 320.0:
			continue
		var lp := node.to_local(pos)
		var in_corr := lp.z > 118.0 and absf(lp.x) < 47.0 and absf(lp.y) < 37.0
		if d < 262.0 and not in_corr:
			var n := (pos - node.position).normalized()
			pos = node.position + n * 264.0
			collide(n, sp)
		elif in_corr and lp.z < 330.0 and state == "flying":
			if sp < 30.0:
				begin_dock(st)
			elif hit_cd <= 0.0 and lp.z < 215.0:
				collide(node.global_basis.z.normalized(), sp)

# ------------------------------------------------------------------ Kamera & HUD
func toggle_cam() -> void:
	cam_mode = "chase" if cam_mode == "cockpit" else "cockpit"
	hud.cam_btn.text = "Außen" if cam_mode == "cockpit" else "Cockpit"
	chase_init = false

func toggle_fa() -> void:
	fa = not fa
	hud.fa_btn.text = "FA ein" if fa else "FA aus"
	hud.fa_btn.theme_type_variation = "BtnOn" if fa else ""
	hud.show_banner("Flugassistent aktiv" if fa else "Flugassistent aus – Newton-Physik", K.OK if fa else K.AMBER, 2.2)

func _update_camera(dt: float) -> void:
	ship_model.global_position = pos
	ship_model.quaternion = quat
	var dim: Vector3 = S.dim
	if cam_mode == "cockpit":
		ship_model.visible = false
		cockpit.visible = true
		var eye: Vector3 = ship_model.get_meta("eye")
		cam.global_position = pos + quat * eye
		cam.quaternion = quat
	else:
		ship_model.visible = true
		cockpit.visible = false
		var want := pos + quat * Vector3(0, dim.y * 1.4 + 4.0, dim.z * 1.5 + 16.0)
		if not chase_init:
			cam_pos = want
			cam_q = quat
			chase_init = true
		cam_pos = cam_pos.lerp(want, 1.0 - exp(-dt * 7.0))
		cam_q = cam_q.slerp(quat, 1.0 - exp(-dt * 4.5))
		cam.global_position = want.lerp(cam_pos, 0.35)
		cam.quaternion = cam_q
	world.update_dust(cam.global_position, vel)
	var f := maxf(0.0, hud.throttle)
	var flen: float = ship_model.get_meta("flame_len")
	for fl in ship_model.get_meta("flames"):
		fl.scale.z = flen * (0.25 + f * 2.4 + rng.randf() * f * 0.35)
		fl.material_override.set_shader_parameter("power", 0.2 + f * 0.9)
	ship_model.get_meta("eng_light").light_energy = f * 3.0
	var beacon = ship_model.get_meta("beacon") if ship_model.has_meta("beacon") else null
	if beacon:
		beacon.emission_energy_multiplier = 1.0 + 7.0 * max(0.0, sin(t0 * 4.0))
	ship_model.get_meta("strobe").emission_energy_multiplier = 14.0 if fmod(t0, 1.4) < 0.08 else 0.4

func _screen_marker(world_p: Vector3, clamp_edge: bool) -> Dictionary:
	var vs := hud.size
	var local := cam.global_transform.affine_inverse() * world_p
	var ctr := vs * 0.5
	var mx := vs.x * 0.36
	var my := vs.y * 0.34
	if local.z < 0.0:
		var p := cam.unproject_position(world_p)
		if absf(p.x - ctr.x) <= mx and absf(p.y - ctr.y) <= my:
			return {"vis": true, "pos": p, "edge": false}
		if not clamp_edge:
			return {"vis": false}
		var d := p - ctr
		var k := minf(mx / maxf(absf(d.x), 0.001), my / maxf(absf(d.y), 0.001))
		return {"vis": true, "pos": ctr + d * k, "edge": true}
	if not clamp_edge:
		return {"vis": false}
	var d2 := Vector2(local.x, -local.y)
	if d2.length() < 0.001:
		d2 = Vector2(0, 1)
	var k2 := minf(mx / maxf(absf(d2.x), 0.001), my / maxf(absf(d2.y), 0.001))
	return {"vis": true, "pos": ctr + d2 * k2, "edge": true}

func _update_hud() -> void:
	var sp := vel.length()
	hud.spd_lbl.text = str(roundi(sp))
	hud.hull_bar.set_value(hull / 100.0, K.DANGER if hull < 35.0 else (K.AMBER if hull < 70.0 else K.OK))
	var cond: float = clampf(float(job.cond), 0.0, 100.0) if not job.is_empty() else 0.0
	hud.cargo_bar.set_value(cond / 100.0, K.DANGER if cond < 50.0 else K.OK)
	hud.acc_lbl.text = ("%s %d m/s²" % ["▲" if accel_now > 0.0 else "▼", roundi(absf(accel_now))]) if absf(accel_now) > 1.0 else "—"
	hud.pro_vis = false
	if sp > 3.0 and state == "flying":
		var m := _screen_marker(pos + vel / sp * 2000.0, false)
		hud.pro_vis = m.vis
		if m.vis:
			hud.pro_pos = m.pos
	hud.tgt_vis = false
	hud.bay_vis = false
	if nav_target != null and state == "flying":
		var tn: Node3D = nav_target.node
		var d := pos.distance_to(tn.position)
		var m := _screen_marker(tn.position, true)
		hud.tgt_vis = true
		hud.tgt_pos = m.pos
		hud.tgt_edge = m.edge
		var closing := -vel.dot((pos - tn.position).normalized())
		var dist_txt := ("%.1f km" % (d / 1000.0)) if d >= 1000.0 else ("%d m" % roundi(d))
		var eta_txt := ""
		if closing > 5.0 and d / closing < 6000.0:
			eta_txt = "  ·  " + Game.mmss(d / closing)
		hud.tgt_text = "%s  %s%s" % [nav_target.name, dist_txt, eta_txt]
		if d < 5000.0:
			var bm := _screen_marker(nav_target.entrance, false)
			hud.bay_vis = bm.vis
			if bm.vis:
				hud.bay_pos = bm.pos
	if not job.is_empty() and state == "flying":
		var left: float = float(job.time) - float(job.elapsed)
		hud.timer_lbl.text = ("Bonus " + Game.mmss(left)) if left >= 0.0 else "Bonus verpasst"
		hud.timer_lbl.add_theme_color_override("font_color", K.FG if left >= 0.0 else K.DANGER)
	else:
		hud.timer_lbl.text = ""
	if state == "flying" and hud.banner_free():
		var msg := ""
		var col := K.AMBER
		for st in world.stations:
			var node: Node3D = st.node
			if pos.distance_to(node.position) > 1800.0:
				continue
			var lp := node.to_local(pos)
			var away := vel.dot(node.global_basis.z.normalized()) > 2.0
			if away and lp.z > 200.0:
				msg = ""
			elif lp.z > 200.0 and absf(lp.x) < 160.0 and absf(lp.y) < 140.0:
				if sp < 30.0:
					msg = "%s: Anflug frei – weiter in die Bucht" % st.name
					col = K.OK
				else:
					msg = "%s: Anflugkorridor – unter 30 m/s" % st.name
			else:
				msg = "%s: Anflug nur durch den grünen Korridor" % st.name
			break
		if msg != "":
			hud.show_banner(msg, col)
		elif hud.banner.visible and hud.banner_until == INF:
			hud.hide_banner()

func _update_topbar() -> void:
	var rn := Game.rank_name(Game.rank())
	if int(Game.s.streak) > 0:
		rn += " · Serie ×" + String.num(Game.streak_mult(), 2).replace(".", ",")
	hud.rank_lbl.text = rn.to_upper()
	hud.credits_lbl.text = Game.fmt(Game.s.credits) + " cr"
	if not job.is_empty():
		hud.cargo_lbl.text = "%s · %d t" % [job.cargo, int(job.mass)]
		hud.dest_lbl.text = "→ " + String(job.dest.name)
	else:
		hud.cargo_lbl.text = "Freier Flug" if nav_target != null else "Kein Auftrag"
		hud.dest_lbl.text = ("→ " + String(nav_target.name)) if nav_target != null else ""
	var mass: float = float(S.dry) + (float(job.mass) if not job.is_empty() else 0.0)
	hud.mass_lbl.text = "%d t" % roundi(mass)

# ------------------------------------------------------------------ Menü
func open_menu() -> void:
	reset_armed = false
	_fill_menu()
	menu_layer.visible = true
	hud.release_all()

func _fill_menu() -> void:
	for c in menu_box.get_children():
		c.queue_free()
	menu_box.add_child(K.lbl("Bordcomputer", 22, K.FG, K.F_BOLD))
	if state == "flying":
		menu_box.add_child(K.caps("Navigationsziel"))
		for st in world.stations:
			var d: float = pos.distance_to(st.node.position) / 1000.0
			var txt := "%s · %.1f km%s" % [st.name, d, " · Auftragsziel" if not job.is_empty() and job.dest == st else ""]
			var s2: Dictionary = st
			var b := K.btn(txt, func():
				nav_target = s2
				menu_layer.visible = false
				_update_topbar())
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.add_theme_color_override("font_color", K.ICE)
			menu_box.add_child(b)
	menu_box.add_child(K.caps("Steuerung"))
	var r := K.hbox(8)
	r.add_child(K.wrap("Höhenachse umkehren (wie im Flugsimulator)", 13, K.FG))
	r.add_child(K.btn("Umgekehrt" if Game.s.invert_y else "Normal", func():
		Game.s.invert_y = not bool(Game.s.invert_y)
		Game.save_game()
		_fill_menu(), bool(Game.s.invert_y)))
	menu_box.add_child(r)
	var r2 := K.hbox(8)
	r2.add_child(K.wrap("Spielstand zurücksetzen", 13, K.FG))
	var rb := K.btn("Zurücksetzen", Callable())
	rb.pressed.connect(func():
		if not reset_armed:
			reset_armed = true
			rb.text = "Wirklich? Nochmal tippen"
			return
		Game.reset_game()
		get_tree().reload_current_scene())
	r2.add_child(rb)
	menu_box.add_child(r2)
	var close := K.btn("Weiterfliegen" if state == "flying" else "Schließen", func(): menu_layer.visible = false, true)
	close.custom_minimum_size = Vector2(0, 46)
	menu_box.add_child(close)

# ------------------------------------------------------------------ Schleife
func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	t0 += dt
	if state == "docked":
		hangar.update(dt, get_viewport().get_visible_rect().size)
		return
	world.animate(t0, dt, nav_target, pos)
	var paused := menu_layer.visible or intro_layer.visible
	if state == "flying" and not paused:
		physics(dt)
		if not job.is_empty():
			job.elapsed = float(job.elapsed) + dt
	elif state == "docking":
		anim.t = float(anim.t) + dt / 2.6
		var k: float = anim.t
		k = k * k * (3.0 - 2.0 * k) if k < 1.0 else 1.0
		pos = anim.p0.lerp(anim.p1, k)
		quat = anim.q0.slerp(anim.q1, k)
		vel = Vector3.ZERO
		if anim.t >= 1.0:
			finish_dock(anim.st)
			return
	_update_camera(dt)
	_update_hud()
	if Engine.get_process_frames() % 20 == 0:
		_update_topbar()

func _input(event: InputEvent) -> void:
	if state == "docked" and event is InputEventScreenDrag and not menu_layer.visible:
		var vs := get_viewport().get_visible_rect().size
		if event.position.x < vs.x * (1.0 - StationUI.PANEL_FRAC):
			hangar.drag(event.relative)
	if event is InputEventKey and event.pressed and not event.echo and state == "flying":
		match event.physical_keycode:
			KEY_C: toggle_cam()
			KEY_V: toggle_fa()
			KEY_X: hud.set_throttle(0.0)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if intro_layer.visible:
			return
		if menu_layer.visible:
			menu_layer.visible = false
		else:
			open_menu()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		Game.s.hull = hull
		Game.save_game()

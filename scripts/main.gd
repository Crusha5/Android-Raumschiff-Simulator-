extends Node3D
## Frachtpilot – Hauptskript: Zustände (Laufen, Fliegen, Andocken, Handelsroute, Sprung, Zerstörung),
## Flugphysik, Kampf, Gegner-Regie, Aufträge, Werft und Kamera.

const K = preload("res://scripts/ui_kit.gd")

var world: SpaceWorld
var hangar: Hangar
var interior: Interior
var walker: Walker
var world_env: WorldEnvironment
var cam: Camera3D
var cockpit: Node3D
var combat: Combat
var ui_root: Control
var hud: Hud
var walk_hud: WalkHud
var station_ui: StationUI
var menu_layer: Control
var menu_box: VBoxContainer
var intro_layer: Control
var modal_layer: Control
var modal_box: VBoxContainer
var fade_rect: ColorRect

var player: ShipState
var S: Dictionary
var state := "walk"        # walk, panel, flying, docking, lane, jump, dead
var loc := "station"       # beim Laufen: station oder ship
var panel_hangar := false
var fa := true
var job: Dictionary = {}
var offers: Array = []
var bounties: Array = []
var last_result: Dictionary = {}
var nav: Dictionary = {}
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
var npcs: Array = []
var target: Npc = null
var pirate_timer := 40.0
var trader_timer := 3.0
var dead_t := 0.0
var lane: Dictionary = {}
var jump: Dictionary = {}
var wreck_node: Node3D
var wreck_looted_once := false
var bounty_spawned := false
var action_kind := ""
var action_arg = null
var fov_base := 60.0

func _ready() -> void:
	rng.randomize()
	world_env = WorldEnvironment.new()
	add_child(world_env)
	world = SpaceWorld.new()
	add_child(world)
	hangar = Hangar.new()
	add_child(hangar)
	hangar.visible = false
	interior = Interior.new()
	add_child(interior)
	walker = Walker.new()
	add_child(walker)

	cam = Camera3D.new()
	cam.fov = fov_base
	cam.near = 0.05
	cam.far = 300000.0
	add_child(cam)
	_build_cockpit()

	var layer := CanvasLayer.new()
	add_child(layer)
	ui_root = Control.new()
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.theme = K.make_theme()
	layer.add_child(ui_root)
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud = Hud.new()
	ui_root.add_child(hud)
	hud.cam_pressed.connect(toggle_cam)
	hud.fa_pressed.connect(toggle_fa)
	hud.menu_pressed.connect(open_menu)
	hud.action_pressed.connect(do_action)
	hud.target_pressed.connect(cycle_target)
	walk_hud = WalkHud.new()
	ui_root.add_child(walk_hud)
	walk_hud.interact_pressed.connect(_walk_interact)
	walk_hud.menu_pressed.connect(open_menu)
	walk_hud.quick_undock.connect(undock)
	station_ui = StationUI.new()
	station_ui.main = self
	ui_root.add_child(station_ui)
	station_ui.visible = false
	_build_menu()
	_build_modal()
	_build_intro()
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(fade_rect)
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	job = Game.s.job.duplicate(true)
	world.build(Game.s.system)
	_new_combat()
	player = ShipState.new()
	player.is_player = true
	player.faction = "player"
	player.setup(Game.s.fit, Game.s.paint, world)
	player.hp = float(player.S.hp_max) * float(Game.s.hull) / 100.0
	S = player.S
	combat.ships = [player]
	_set_load()
	if not job.is_empty():
		_nav_from_job()
	make_offers()
	enter_station(false)
	intro_layer.visible = not bool(Game.s.intro_seen)

# ------------------------------------------------------------------ Aufbau
func _new_combat() -> void:
	combat = Combat.new()
	combat.world = world
	world.dynamic.add_child(combat)
	combat.ship_hit.connect(_on_ship_hit)
	combat.ship_destroyed.connect(_on_ship_destroyed)
	npcs = []
	target = null
	if player:
		combat.ships = [player]

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
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_root.add_child(c)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c

func _center_panel(parent: Control, width: float) -> VBoxContainer:
	var cc := CenterContainer.new()
	parent.add_child(cc)
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(width, 0)
	cc.add_child(p)
	var v := K.vbox(12)
	p.add_child(v)
	return v

func _build_menu() -> void:
	menu_layer = _overlay()
	var sc := ScrollContainer.new()
	menu_layer.add_child(sc)
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var cc := CenterContainer.new()
	cc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.add_child(cc)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(500, 0)
	cc.add_child(p)
	menu_box = K.vbox(10)
	p.add_child(menu_box)
	menu_layer.visible = false

func _build_modal() -> void:
	modal_layer = _overlay(0.6)
	modal_box = _center_panel(modal_layer, 520)
	modal_layer.visible = false

func show_modal(head: String, text: String, button := "Weiter") -> void:
	for c in modal_box.get_children():
		c.queue_free()
	modal_box.add_child(K.lbl(head, 22, K.FG, K.F_BOLD))
	var rl := RichTextLabel.new()
	rl.bbcode_enabled = true
	rl.fit_content = true
	rl.scroll_active = false
	rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rl.add_theme_font_override("normal_font", K.F_REG)
	rl.add_theme_font_override("bold_font", K.F_BOLD)
	rl.add_theme_font_size_override("normal_font_size", 14)
	rl.add_theme_font_size_override("bold_font_size", 14)
	rl.text = text
	modal_box.add_child(rl)
	var b := K.btn(button, func(): modal_layer.visible = false, true)
	b.custom_minimum_size = Vector2(0, 46)
	modal_box.add_child(b)
	modal_layer.visible = true
	hud.release_all()
	walk_hud.release_all()

func _build_intro() -> void:
	intro_layer = _overlay(0.6)
	var v := _center_panel(intro_layer, 600)
	v.add_child(K.lbl("Willkommen an Bord, Pilot", 24, K.FG, K.F_BOLD))
	v.add_child(K.wrap("Du stehst auf dem Deck von Kepler-Dock im System Sol-7. Sprich mit der Auftraggeberin für Frachtaufträge, mit dem Barkeeper für Kopfgelder, mit dem Ausrüster für neue Teile. Durch die Schleuse gehst du an Bord – dort tauschst du an den Konsolen Teile aus deinem Lager, und vom Pilotensitz aus dockst du ab.", 13, K.FG))
	var keys := RichTextLabel.new()
	keys.bbcode_enabled = true
	keys.fit_content = true
	keys.scroll_active = false
	keys.add_theme_font_override("normal_font", K.F_REG)
	keys.add_theme_font_override("bold_font", K.F_SEMI)
	keys.add_theme_font_size_override("normal_font_size", 13)
	keys.add_theme_font_size_override("bold_font_size", 13)
	keys.text = "[color=#ffb547][b]Laufen:[/b][/color] links ziehen = gehen, rechts ziehen = umsehen\n[color=#ffb547][b]Fliegen:[/b][/color] links ziehen = lenken, Rolltasten links, Schubhebel rechts\n[color=#ff5a4e][b]Kampf:[/b][/color] FEUER halten – die Waffen schwenken auf das markierte Ziel. ZIEL wechselt den Gegner.\n[color=#9fd4ff][b]Reisen:[/b][/color] An Handelsrouten-Ringen und Sprungtoren erscheint unten ein Knopf.\n[color=#ff8c3a][b]Zerstört?[/b][/color] Deine Teile bleiben im Wrack. Flieg hin und berge sie, bevor Plünderer kommen."
	v.add_child(keys)
	v.add_child(K.btn("Los geht's", func():
		intro_layer.visible = false
		Game.s.intro_seen = true
		Game.save_game(), true))

func _fade(to: float, secs: float) -> void:
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", to, secs)

# ------------------------------------------------------------------ Hilfen
func dock_station() -> Dictionary:
	var d := Universe.station(Game.s.station)
	d["name"] = d.n
	return d

func ship_hull_frac() -> float:
	return player.hull_frac()

func repair_cost() -> int:
	return roundi((1.0 - player.hull_frac()) * 100.0 * float(S.hp_max) * 0.09)

func where_sold(tier: int) -> String:
	var names := []
	for st in Universe.all_stations():
		if int(st.shop) >= tier:
			names.append(st.n)
	return ", ".join(names)

func view_fit() -> Dictionary:
	return preview_fit if not preview_fit.is_empty() else Game.s.fit

func view_paint() -> Dictionary:
	return pend_paint if not pend_paint.is_empty() else Game.s.paint

func _set_load() -> void:
	var l: Node3D = player.model.get_meta("load")
	l.visible = not job.is_empty() and job.get("type", "cargo") == "cargo"

func _v3(a) -> Vector3:
	if a is Vector3:
		return a
	return Vector3(float(a[0]), float(a[1]), float(a[2]))

func _arr(v: Vector3) -> Array:
	return [v.x, v.y, v.z]

func news_lines() -> Array:
	var out := []
	var sys := Universe.system(Game.s.system)
	out.append("Hier in %s? %s." % [sys.n, sys.desc])
	if not Game.s.wreck.is_empty():
		var w: Dictionary = Game.s.wreck
		out.append("Man erzählt sich, dein altes Wrack treibt noch in %s. Wenn du dich beeilst, ist noch was zu holen." % Universe.system(w.sys).n)
	var tips := ["In der Orion-Werft in Vega-Tiefe gibt's die dicksten Triebwerke. Durchs Sprungtor von Sol-7, dann die Handelsroute nehmen.",
		"Im Freihafen Nyx fragt keiner, was du geladen hast. Die Piraten dort fragen auch nicht, bevor sie schießen.",
		"Ein Ladungsdämpfer hat schon so manchem Medizinfrachter den Bonus gerettet.",
		"Auf Handelsrouten bist du sicher. Daneben nicht."]
	out.append(tips[rng.randi() % tips.size()])
	return out

# ------------------------------------------------------------------ Aufträge
func lock_reason(o: Dictionary) -> String:
	if int(o.rank) > Game.rank():
		return "Ab Rang " + Game.rank_name(int(o.rank))
	if o.get("type", "cargo") == "cargo" and int(o.mass) > int(S.cap):
		return "Braucht %d t Frachtraum" % int(o.mass)
	return ""

func make_offers() -> void:
	var here := Universe.station(Game.s.station)
	var rk := Game.rank()
	var all := Universe.all_stations().filter(func(x): return x.id != here.id)
	var local := all.filter(func(x): return x.sys == here.sys)
	for _try in 12:
		offers = []
		for i in 5:
			var pool := Game.CARGO.filter(func(c): return (not c.has("from") or c.from == here.kind) and int(c.r) <= rk + 1)
			var c: Dictionary = pool[rng.randi() % pool.size()]
			var dest: Dictionary = local[rng.randi() % local.size()] if (rng.randf() < 0.6 and local.size() > 0) else all[rng.randi() % all.size()]
			var dist := Universe.route_length(here.id, dest.id)
			var jumps := Universe.jumps(here.sys, dest.sys)
			var danger := 0.0
			for sid in Universe.path(here.sys, dest.sys):
				danger = maxf(danger, float(Universe.system(sid).danger))
			var mass := rng.randi_range(int(c.m[0]), int(c.m[1]))
			var pay := roundi(dist / 1000.0 * (40.0 + mass * 3.0) * float(c.p) * (1.0 + int(c.r) * 0.08) * (1.0 + danger * 0.8) / 10.0) * 10 + jumps * 400
			var tm := roundi((dist / 190.0 + 70.0 + jumps * 40.0) * (0.68 if c.get("express", false) else 1.0))
			offers.append({"type": "cargo", "cargo": c.n, "fragile": c.get("fragile", false), "express": c.get("express", false), "rank": int(c.r),
				"mass": mass, "dest": dest.id, "dest_name": dest.n, "dest_sys": dest.sys, "dist": dist, "pay": pay, "time": tm})
		var open := 0
		for o in offers:
			if lock_reason(o) == "":
				open += 1
		if open >= 2:
			break
	offers.sort_custom(func(a, b): return int(lock_reason(a) != "") < int(lock_reason(b) != ""))
	# Kopfgelder
	bounties = []
	var cands := [here.sys]
	for g in Universe.system(here.sys).gates:
		cands.append(g.to)
	for i in rng.randi_range(1, 3):
		var sid: String = cands[rng.randi() % cands.size()]
		var sys := Universe.system(sid)
		if float(sys.danger) < 0.1:
			continue
		var zone: Dictionary = sys.zones[rng.randi() % sys.zones.size()]
		var tier := clampi(int(round(float(sys.danger) * 2.5 + rk * 0.3 + rng.randf_range(-0.5, 0.5))), 0, 3)
		var cnt := clampi(rng.randi_range(0, tier + 1), 0, 3)
		var p: Vector3 = zone.c + Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.3, 0.3), rng.randf_range(-1, 1)) * float(zone.r) * 0.5
		bounties.append({"type": "bounty", "target": Game.PIRATE_NAMES[rng.randi() % Game.PIRATE_NAMES.size()], "sys": sid, "sys_name": sys.n,
			"zone_name": "Asteroidenfeld" if p.distance_to(sys.fields[0].c) < float(sys.fields[0].r) else "Tiefraum", "pos": _arr(p),
			"count": cnt, "tier": tier, "pay": 1500 + tier * 1800 + cnt * 600, "rank": maxi(0, tier - 1)})

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

func take_offer(o: Dictionary) -> void:
	job = o.duplicate(true)
	if job.type == "cargo":
		job.pay = roundi(float(o.pay) * Game.streak_mult())
		job.time = roundi(float(o.time) * float(S.time))
		job.cond = 100.0
		job.elapsed = 0.0
	bounty_spawned = false
	last_result = {}
	_nav_from_job()
	Game.s.job = job
	Game.save_game()
	_set_load()
	station_ui.refresh()

func _nav_from_job() -> void:
	if job.is_empty():
		return
	if job.type == "cargo":
		nav = {"kind": "station", "id": job.dest, "sys": job.dest_sys}
	else:
		nav = {"kind": "point", "sys": job.sys, "pos": job.pos, "name": "Kopfgeld: " + String(job.target)}

func cancel_job() -> void:
	Game.s.credits = int(Game.s.credits) - roundi(float(job.pay) * 0.25)
	job = {}
	Game.s.job = {}
	nav = {}
	_set_load()
	make_offers()
	Game.save_game()
	station_ui.refresh()

func repair() -> void:
	var cost := repair_cost()
	if int(Game.s.credits) >= cost:
		Game.s.credits = int(Game.s.credits) - cost
		player.hp = float(S.hp_max)
		Game.s.hull = 100.0
		Game.save_game()
		station_ui.refresh()

# ------------------------------------------------------------------ Werft & Lack
func clear_previews() -> void:
	if not preview_fit.is_empty() or not pend_paint.is_empty():
		preview_fit = {}
		pend_paint = {}
		_rebuild_hangar_ship()

func _rebuild_hangar_ship() -> void:
	if not panel_hangar:
		return
	var s := ShipBuilder.build(view_fit(), view_paint())
	s.get_meta("load").visible = not job.is_empty() and job.get("type", "cargo") == "cargo"
	hangar.set_ship(s)

func try_part(slot: String, id: String) -> void:
	var f: Dictionary = Game.s.fit.duplicate()
	f[slot] = id
	f = Game.fix_cargo(f)
	f[slot] = id
	preview_fit = {} if f == Game.s.fit else f
	_rebuild_hangar_ship()
	station_ui.refresh()

func equip(slot: String, id: String) -> void:
	var frac := player.hull_frac()
	Game.s.fit[slot] = id
	Game.fix_cargo(Game.s.fit)
	preview_fit = {}
	player.setup(Game.s.fit, Game.s.paint, world)
	player.hp = float(player.S.hp_max) * frac
	S = player.S
	_set_load()
	Game.save_game()
	_rebuild_hangar_ship()
	if job.is_empty():
		make_offers()
	station_ui.refresh()

func buy(slot: String, id: String) -> void:
	var p := Game.part(slot, id)
	if int(Game.s.credits) < int(p.price):
		return
	Game.s.credits = int(Game.s.credits) - int(p.price)
	Game.s.owned[slot].append(id)
	equip(slot, id)

func set_paint(key: String, val: String) -> void:
	var p: Dictionary = view_paint().duplicate()
	p[key] = val
	pend_paint = {} if p == Game.s.paint else p
	_rebuild_hangar_ship()
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
	var frac := player.hull_frac()
	player.setup(Game.s.fit, Game.s.paint, world)
	player.hp = float(player.S.hp_max) * frac
	_set_load()
	Game.save_game()
	_rebuild_hangar_ship()
	station_ui.refresh()

func reset_paint() -> void:
	pend_paint = {}
	_rebuild_hangar_ship()
	station_ui.refresh()

func rename(t: String) -> void:
	t = t.strip_edges().substr(0, 18)
	if t != "" and t != Game.s.name:
		Game.s.name = t
		Game.save_game()
		station_ui.refresh()

# ------------------------------------------------------------------ Laufen
func _show_view(view: String) -> void:
	world.visible = view == "space"
	hangar.visible = view == "hangar"
	interior.visible = view == "interior"
	cockpit.visible = view == "space" and cam_mode == "cockpit"
	match view:
		"space":
			world_env.environment = world.env
			cam.make_current()
		"hangar":
			world_env.environment = hangar.env
			hangar.cam.make_current()
		"interior":
			world_env.environment = interior.env
			walker.cam.make_current()
	hud.visible = view == "space"
	walk_hud.visible = view == "interior"
	hud.release_all()
	walk_hud.release_all()

func enter_station(show_result := true) -> void:
	state = "walk"
	loc = "station"
	var st := dock_station()
	interior.build_station(st, Game.s.fit, Game.s.paint, not job.is_empty() and job.get("type", "") == "cargo")
	walker.place(interior.spawn)
	_show_view("interior")
	walk_hud.loc_lbl.text = st.n
	walk_hud.sub_lbl.text = Universe.system(st.sys).n.to_upper() + " · STATIONSDECK"
	walk_hud.undock_btn.visible = true
	_update_walk_top()
	if show_result and not last_result.is_empty():
		show_modal(last_result.get("head", "Angedockt"), last_result.text)

func enter_ship() -> void:
	state = "walk"
	loc = "ship"
	interior.build_ship(Game.s.fit, Game.s.paint, job, Game.s.system)
	walker.place(interior.spawn)
	_show_view("interior")
	walk_hud.loc_lbl.text = "«%s»" % Game.s.name
	walk_hud.sub_lbl.text = "AN BORD · " + String(Game.part("frame", Game.s.fit.frame).n).to_upper()
	walk_hud.undock_btn.visible = false
	_update_walk_top()

func _update_walk_top() -> void:
	walk_hud.credits_lbl.text = Game.fmt(Game.s.credits) + " cr"

func _walk_interact() -> void:
	if action_kind == "":
		return
	var arg = action_arg
	match action_kind:
		"board":
			_transition(func(): enter_ship())
		"leave":
			_transition(func(): enter_station(false))
		"undock":
			_transition(func(): undock())
		"jobs":
			open_panel("jobs", "Mara Lenz · Auftraggeberin", dock_station().n, false)
		"bar":
			open_panel("bar", "Old Sully · Barkeeper", dock_station().n, false)
		"shop":
			open_panel("shop", "Jonas Brack · Ausrüster", dock_station().n, true)
		"paint":
			open_panel("paint", "Ida Farn · Lackiererin", dock_station().n, true)
		"console":
			station_ui.slot = arg
			open_panel("console", "Konsole · " + station_ui._slot_name(arg), "«%s»" % Game.s.name, true, arg)

func _transition(cb: Callable) -> void:
	walk_hud.release_all()
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 1.0, 0.25)
	tw.tween_callback(cb)
	tw.tween_property(fade_rect, "color:a", 0.0, 0.35)

func open_panel(mode: String, title: String, sub: String, with_hangar: bool, slot := "") -> void:
	state = "panel"
	panel_hangar = with_hangar
	preview_fit = {}
	pend_paint = {}
	if with_hangar:
		hangar.panel_frac = StationUI.PANEL_FRAC
		_rebuild_hangar_ship()
		_show_view("hangar")
	else:
		walk_hud.visible = false
	walk_hud.set_prompt("", "")
	station_ui.open(mode, title, sub, slot)

func close_panel() -> void:
	station_ui.visible = false
	preview_fit = {}
	pend_paint = {}
	state = "walk"
	if loc == "ship" and panel_hangar:
		var xf := walker.global_transform
		var yaw := walker.yaw
		var pitch := walker.pitch
		interior.build_ship(Game.s.fit, Game.s.paint, job, Game.s.system)
		walker.global_transform = xf
		walker.yaw = yaw
		walker.pitch = pitch
	elif loc == "station" and panel_hangar:
		var xf2 := walker.global_transform
		var yaw2 := walker.yaw
		interior.build_station(dock_station(), Game.s.fit, Game.s.paint, not job.is_empty() and job.get("type", "") == "cargo")
		walker.global_transform = xf2
		walker.yaw = yaw2
	panel_hangar = false
	_show_view("interior")
	_update_walk_top()

func _walk_update(dt: float) -> void:
	walker.move_input = Vector2(walk_hud.stick.x, -walk_hud.stick.y)
	walker.look_delta = walk_hud.take_look()
	walker.step(dt)
	interior.update(dt, walker.global_position)
	var best = null
	var bd := 1e9
	var lp := walker.global_position + Vector3(0, 1.0, 0)
	var look := walker.look_dir()
	for it in interior.interactables:
		var d: float = lp.distance_to(it.pos)
		if d < float(it.r):
			var facing := look.dot((it.pos - lp).normalized())
			var score := d - facing
			if score < bd:
				bd = score
				best = it
	if best:
		action_kind = best.action
		action_arg = best.arg
		var btn := "Sprechen"
		match String(best.action):
			"board", "leave": btn = "Durchgehen"
			"undock": btn = "Abdocken"
			"console": btn = "Bedienen"
		walk_hud.set_prompt(best.label, btn)
	else:
		action_kind = ""
		walk_hud.set_prompt("", "")

# ------------------------------------------------------------------ Andocken / Abdocken
func _station_node(id: String) -> Dictionary:
	return world.station_by_id(id)

func undock() -> void:
	if state == "flying":
		return
	preview_fit = {}
	pend_paint = {}
	menu_layer.visible = false
	station_ui.visible = false
	var st := _station_node(Game.s.station)
	var n: Node3D = st.node
	player.pos = n.to_global(Vector3(0, 0, 330))
	player.quat = n.global_basis.get_rotation_quaternion() * Quaternion(Vector3.UP, PI)
	player.vel = player.forward() * 30.0
	player.ang = Vector3.ZERO
	player.alive = true
	player.model.visible = true
	player.shield = float(S.shield)
	player.energy = float(S.energy)
	state = "flying"
	_show_view("space")
	hud.set_throttle(30.0 / float(S.vmax))
	last_result = {}
	chase_init = false
	if not job.is_empty() and job.type == "cargo":
		job.elapsed = 0.0
	pirate_timer = rng.randf_range(25.0, 50.0)
	_spawn_wreck_node()
	hud.show_banner("Abgedockt – gute Reise", K.OK, 2.5)
	_update_topbar()

func begin_dock(st: Dictionary) -> void:
	state = "docking"
	hud.set_throttle(0.0)
	var n: Node3D = st.node
	anim = {"st": st, "t": 0.0, "p0": player.pos, "q0": player.quat, "p1": n.to_global(Vector3(0, 0, 165)), "q1": n.global_basis.get_rotation_quaternion()}
	hud.show_banner("Andockklammern greifen …", K.OK)

func finish_dock(st: Dictionary) -> void:
	Game.s.station = st.id
	Game.s.system = world.sys_id
	hud.hide_banner()
	last_result = {}
	if not job.is_empty() and job.type == "cargo" and job.dest == st.id:
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
		var txt := "[b]%s[/b] ausgeliefert · Zustand %d%% · Flugzeit %s\nLohn [b]%s cr[/b]%s · +%d EP" % [job.cargo, roundi(cond), Game.mmss(job.elapsed), Game.fmt(pay), (" inkl. Pünktlichkeitsbonus %s cr" % Game.fmt(bonus)) if bonus > 0 else "", xp]
		if perfect:
			txt += "\n[color=#7fe08a]Ohne Kratzer: Serie %d, nächster Lohn ×%s[/color]" % [int(Game.s.streak), String.num(Game.streak_mult(), 2).replace(".", ",")]
		elif int(Game.s.best) > 0:
			txt += "\nLadung beschädigt: Serie verloren"
		txt += _promo_text(rk0)
		last_result = {"head": "Lieferung abgeschlossen", "text": txt}
		job = {}
		nav = {}
	elif not job.is_empty() and job.type == "cargo":
		last_result = {"head": "Angedockt: " + st.name, "text": "Dein Auftrag geht weiter: [b]%s[/b] nach [b]%s[/b]." % [job.cargo, job.dest_name]}
	Game.s.job = job
	Game.s.hull = player.hull_frac() * 100.0
	Game.save_game()
	_set_load()
	_clear_npcs()
	make_offers()
	enter_station(true)
	_update_topbar()

func _promo_text(rk0: int) -> String:
	var rk1 := Game.rank()
	if rk1 <= rk0:
		return ""
	var un := []
	for slot in Game.SLOTS:
		for id in Game.PARTS[slot[0]]:
			if int(Game.PARTS[slot[0]][id].rank) == rk1:
				un.append(Game.PARTS[slot[0]][id].n)
	return "\n\n[color=#ffb547][b]Befördert zum %s![/b][/color]%s" % [Game.rank_name(rk1), (" Neu freigeschaltet: " + ", ".join(un)) if un.size() > 0 else ""]

# ------------------------------------------------------------------ Schaden & Kampf
func collide(normal: Vector3, impact: float) -> void:
	if hit_cd > 0.0:
		return
	hit_cd = 0.4
	var vn := player.vel.dot(normal)
	if vn < 0.0:
		player.vel -= normal * vn * 1.4
	player.vel *= 0.5
	var raw: float = clampf(impact * 0.22, 3.0, 70.0) * float(S.hp_max) / 100.0
	player.shield = 0.0
	player.take_damage(raw, normal)
	_on_ship_hit(player, raw, null)
	if not player.alive:
		combat.explode(player.pos, player.radius)
		_player_destroyed()
		return
	if hud.banner_free():
		hud.show_banner("Kollision · Hülle %d%%" % maxi(0, roundi(player.hull_frac() * 100.0)), K.DANGER, 1.8)

func _on_ship_hit(ship: ShipState, dmg: float, attacker) -> void:
	if ship == player:
		hud.flash(0.25 if player.shield > 0.0 else 0.45)
		if dmg > 0.0 and not job.is_empty() and job.type == "cargo":
			job.cond = float(job.cond) - dmg * 100.0 / float(S.hp_max) * (1.8 if job.fragile else 0.7) * float(S.fragile)
			if int(Game.s.streak) > 0:
				Game.s.streak = 0
				hud.show_banner("Ladung beschädigt – Lieferserie verloren", K.DANGER, 2.2)
	elif attacker == player and ship is Npc and target == null:
		target = ship

func _on_ship_destroyed(ship: ShipState, attacker) -> void:
	if ship == player:
		_player_destroyed()
		return
	npcs.erase(ship)
	combat.ships.erase(ship)
	if ship.model:
		ship.model.queue_free()
	if target == ship:
		target = null
	if attacker == player and ship.faction == "pirate":
		var rk0 := Game.rank()
		Game.s.credits = int(Game.s.credits) + ship.reward
		Game.s.xp = int(Game.s.xp) + ship.xp
		Game.s.kills = int(Game.s.kills) + 1
		var msg := "%s abgeschossen · +%s cr" % [ship.name, Game.fmt(ship.reward)]
		if ship.leader and not job.is_empty() and job.type == "bounty":
			Game.s.credits = int(Game.s.credits) + int(job.pay)
			Game.s.xp = int(Game.s.xp) + 60 + int(job.tier) * 40
			msg = "Kopfgeld kassiert: %s · +%s cr" % [job.target, Game.fmt(job.pay)]
			job = {}
			nav = {}
			Game.s.job = {}
		var promo := _promo_text(rk0)
		hud.show_banner(msg, K.OK, 3.0)
		if promo != "":
			show_modal("Beförderung", promo.strip_edges())
		Game.save_game()
		_update_topbar()

func _player_destroyed() -> void:
	if state == "dead":
		return
	state = "dead"
	dead_t = 3.0
	player.alive = false
	player.model.visible = false
	hud.release_all()
	hud.flash(0.9)
	var parts := {}
	for sl in Game.SLOTS:
		var k: String = sl[0]
		if Game.s.fit[k] != Game.BASE_FIT[k]:
			parts[k] = Game.s.fit[k]
			Game.s.owned[k].erase(Game.s.fit[k])
	var old_lost: bool = not Game.s.wreck.is_empty()
	var txt := "Die Rettungskapsel hat dich nach [b]%s[/b] gebracht. Die Versicherung stellt dir einen Spatz mit Grundausstattung." % dock_station().n
	if parts.size() > 0:
		var names := []
		for k in parts:
			names.append(Game.part(k, parts[k]).n)
		Game.s.wreck = {"sys": world.sys_id, "pos": _arr(player.pos), "parts": parts, "name": Game.s.name, "paint": Game.s.paint.duplicate(),
			"fit": Game.s.fit.duplicate(), "protected": Game.s.fit.extra == "bake"}
		txt += "\n\n[color=#ff8c3a][b]Dein Wrack treibt in %s.[/b][/color] Darin: %s. Flieg hin und berge es – die Teile landen wieder in deinem Lager." % [Universe.system(world.sys_id).n, ", ".join(names)]
		if not Game.s.fit.extra == "bake":
			txt += " Beeil dich, Plünderer haben es auch schon entdeckt."
	if old_lost:
		txt += "\n\nDein vorheriges Wrack haben Plünderer inzwischen ausgeschlachtet."
	if not job.is_empty() and job.type == "cargo":
		txt += "\n\nDie Ladung [b]%s[/b] ist verloren, der Auftrag gescheitert." % job.cargo
		job = {}
		nav = {}
	Game.s.fit = Game.BASE_FIT.duplicate()
	Game.s.streak = 0
	Game.s.hull = 100.0
	Game.s.job = job
	Game.save_game()
	last_result = {"head": "Schiff zerstört", "text": txt}

func _respawn() -> void:
	var st := Universe.station(Game.s.station)
	_clear_npcs()
	combat.clear()
	if st.sys != world.sys_id:
		world.build(st.sys)
		_new_combat()
	wreck_node = null
	Game.s.system = st.sys
	player.setup(Game.s.fit, Game.s.paint, world)
	S = player.S
	player.alive = true
	combat.ships = [player]
	_set_load()
	wreck_looted_once = false
	make_offers()
	enter_station(true)

# ------------------------------------------------------------------ NPCs
func _clear_npcs() -> void:
	for n in npcs:
		if n.model and is_instance_valid(n.model):
			n.model.queue_free()
	npcs = []
	target = null
	if combat:
		combat.ships = [player] if player else []
		combat.clear()

func spawn_pirates(count: int, tier: int, center: Vector3, leader_name := "", tag := "") -> void:
	for i in count:
		var n := Npc.new()
		n.rng.seed = rng.randi()
		n.faction = "pirate"
		var t := clampi(tier + (1 if i == 0 and leader_name != "" else 0), 0, 3)
		n.setup(Npc.pirate_fit(t, rng), Npc.pirate_paint(rng), world.dynamic)
		n.pos = center + Vector3(rng.randf_range(-150, 150), rng.randf_range(-80, 80), rng.randf_range(-150, 150))
		var to_p := (player.pos - n.pos).normalized()
		n.quat = Basis.looking_at(to_p, Vector3.UP).get_rotation_quaternion()
		n.vel = to_p * float(n.S.vmax) * 0.6
		n.aim_err = 0.05 - t * 0.008
		n.reward = 80 + t * 140
		n.xp = 8 + t * 6
		n.job_tag = tag
		if i == 0 and leader_name != "":
			n.leader = true
			n.name = leader_name
			n.hp *= 1.5
		else:
			n.name = ["Pirat", "Freibeuter", "Plünderer"][rng.randi() % 3] if tag != "loot" else "Plünderer"
		n.sync_model()
		npcs.append(n)
		combat.ships.append(n)
	hud.hostile_warn = 3.0

func _spawn_trader() -> void:
	var pts := []
	for st in world.stations:
		pts.append(st.entrance)
	for g in world.gates:
		pts.append(g.pos)
	if pts.size() < 2:
		return
	var a: Vector3 = pts[rng.randi() % pts.size()]
	var b: Vector3 = pts[rng.randi() % pts.size()]
	if a == b:
		return
	var n := Npc.new()
	n.rng.seed = rng.randi()
	n.faction = "trader"
	var f := {"frame": ["esel", "kondor", "spatz"][rng.randi() % 3], "engine": "orion", "rcs": "rcs1", "weapon": "puls1", "shield": "s1", "cargo": "k28", "armor": "a1", "extra": "x0"}
	f = Game.fix_cargo(f)
	if f.frame != "spatz":
		f.cargo = "k60"
	n.setup(f, Npc.trader_paint(rng), world.dynamic)
	n.model.get_meta("load").visible = true
	var start := a.lerp(b, rng.randf_range(0.0, 0.6))
	n.pos = start + Vector3(rng.randf_range(-200, 200), rng.randf_range(-100, 100), rng.randf_range(-200, 200))
	n.dest = b
	n.quat = Basis.looking_at((b - n.pos).normalized(), Vector3.UP).get_rotation_quaternion()
	n.vel = (b - n.pos).normalized() * float(n.S.vmax) * 0.5
	n.name = ["Frachter", "Tanker", "Kurier", "Erzfrachter"][rng.randi() % 4] + " " + str(rng.randi_range(100, 999))
	npcs.append(n)
	combat.ships.append(n)

func _director(dt: float) -> void:
	var sys := Universe.system(world.sys_id)
	var danger := float(sys.danger)
	var near_station := false
	for st in world.stations:
		if player.pos.distance_to(st.node.position) < 3000.0:
			near_station = true
	var in_zone := false
	for z in sys.zones:
		if player.pos.distance_to(z.c) < float(z.r):
			in_zone = true
	var hostiles := 0
	var traders := 0
	for n in npcs:
		if n.faction == "pirate":
			hostiles += 1
		else:
			traders += 1
	pirate_timer -= dt * (2.0 if in_zone else 1.0)
	if pirate_timer <= 0.0:
		pirate_timer = rng.randf_range(45.0, 90.0)
		if hostiles == 0 and not near_station and state == "flying" and rng.randf() < danger + 0.15:
			var tier := clampi(int(round(danger * 2.5 + Game.rank() * 0.25 + rng.randf_range(-0.7, 0.3))), 0, 3)
			var cnt := clampi(1 + int(rng.randf() * (danger * 3.0 + 0.5)), 1, 4)
			var dir := (player.forward() + Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.4, 0.4), rng.randf_range(-1, 1))).normalized()
			spawn_pirates(cnt, tier, player.pos + dir * 2300.0)
			hud.show_banner("Piraten im Anflug!", K.DANGER, 3.0)
	trader_timer -= dt
	if trader_timer <= 0.0:
		trader_timer = rng.randf_range(8.0, 20.0)
		if traders < 4:
			_spawn_trader()
	# Kopfgeld-Ziel
	if not job.is_empty() and job.type == "bounty" and job.sys == world.sys_id and not bounty_spawned:
		var p := _v3(job.pos)
		if player.pos.distance_to(p) < 3200.0:
			bounty_spawned = true
			spawn_pirates(1 + int(job.count), int(job.tier), p, String(job.target), "bounty")
			hud.show_banner("%s gesichtet!" % job.target, K.DANGER, 3.0)
	# Plünderer am Wrack
	var w: Dictionary = Game.s.wreck
	if not w.is_empty() and w.sys == world.sys_id and not wreck_looted_once and not w.get("protected", false):
		if player.pos.distance_to(_v3(w.pos)) < 3500.0:
			wreck_looted_once = true
			spawn_pirates(2, clampi(int(round(danger * 2.0)), 0, 3), _v3(w.pos) + Vector3(0, 100, 0), "", "loot")
			hud.show_banner("Plünderer am Wrack!", K.DANGER, 3.0)

func cycle_target() -> void:
	var hs := npcs.filter(func(n): return n.faction == "pirate" and n.alive)
	if hs.is_empty():
		target = null
		return
	hs.sort_custom(func(a, b): return a.pos.distance_to(player.pos) < b.pos.distance_to(player.pos))
	var idx := hs.find(target)
	target = hs[(idx + 1) % hs.size()]

func _auto_target() -> void:
	if target != null and (not target.alive or not npcs.has(target)):
		target = null
	if target == null:
		var best: Npc = null
		var bd := 4000.0
		for n in npcs:
			if n.faction != "pirate":
				continue
			var d: float = n.pos.distance_to(player.pos)
			if d < bd:
				bd = d
				best = n
		target = best

# ------------------------------------------------------------------ Wrack
func _spawn_wreck_node() -> void:
	if wreck_node and is_instance_valid(wreck_node):
		wreck_node.queue_free()
	wreck_node = null
	var w: Dictionary = Game.s.wreck
	if w.is_empty() or w.sys != world.sys_id:
		return
	var f: Dictionary = w.get("fit", Game.BASE_FIT)
	var p: Dictionary = w.get("paint", Game.s.paint).duplicate()
	p.hull = "#3a3632"
	p.accent = "#4a3a30"
	wreck_node = ShipBuilder.build(f, p)
	for fl in wreck_node.get_meta("flames"):
		fl.visible = false
	wreck_node.get_meta("eng_light").visible = false
	var b := OmniLight3D.new()
	b.light_color = Color(1.0, 0.45, 0.15)
	b.light_energy = 3.0
	b.omni_range = 60.0
	wreck_node.add_child(b)
	wreck_node.set_meta("fire", b)
	world.dynamic.add_child(wreck_node)
	wreck_node.global_position = _v3(w.pos)
	wreck_node.rotation = Vector3(0.6, 1.1, 0.4)

func _salvage() -> void:
	var w: Dictionary = Game.s.wreck
	var names := []
	for k in w.parts:
		if not Game.s.owned[k].has(w.parts[k]):
			Game.s.owned[k].append(w.parts[k])
		names.append(Game.part(k, w.parts[k]).n)
	Game.s.wreck = {}
	Game.save_game()
	if wreck_node:
		combat.explode(wreck_node.global_position, 4.0)
		wreck_node.queue_free()
		wreck_node = null
	show_modal("Wrack geborgen", "Im Laderaum: [b]%s[/b].\n\nDie Teile liegen in deinem Lager. Geh an Bord zu den Konsolen und bau sie wieder ein." % ", ".join(names))

# ------------------------------------------------------------------ Reisen
func _resolve_nav() -> Dictionary:
	## Liefert {pos, name, entrance?, via_gate} im aktuellen System
	if nav.is_empty():
		return {}
	var sys: String = nav.sys
	if sys != world.sys_id:
		var g := Universe.gate_towards(world.sys_id, sys)
		if g.is_empty():
			return {}
		var gn := world.gate_by_id(g.id)
		var final_name := ""
		if nav.kind == "station":
			final_name = Universe.station(nav.id).n
		elif nav.kind == "wreck":
			final_name = "Wrack"
		else:
			final_name = String(nav.get("name", "Ziel"))
		return {"pos": gn.pos, "name": "%s → %s" % [gn.name, final_name], "via_gate": true}
	match String(nav.kind):
		"station":
			var st := world.station_by_id(nav.id)
			if st.is_empty():
				return {}
			return {"pos": st.node.position, "name": st.name, "entrance": st.entrance, "station": st}
		"gate":
			var g := world.gate_by_id(nav.id)
			return {"pos": g.pos, "name": g.name}
		"wreck":
			if Game.s.wreck.is_empty():
				return {}
			return {"pos": _v3(Game.s.wreck.pos), "name": "Wrack «%s»" % Game.s.wreck.get("name", "")}
		"point":
			return {"pos": _v3(nav.pos), "name": String(nav.get("name", "Wegpunkt"))}
	return {}

func _find_action() -> void:
	action_kind = ""
	action_arg = null
	var sp := player.vel.length()
	var w: Dictionary = Game.s.wreck
	if wreck_node and not w.is_empty() and player.pos.distance_to(wreck_node.global_position) < 160.0:
		if sp < 60.0:
			action_kind = "salvage"
			hud.set_action("Wrack bergen")
		else:
			hud.set_action("")
			if hud.banner_free():
				hud.show_banner("Zum Bergen unter 60 m/s abbremsen", K.AMBER)
		return
	for g in world.gates:
		if player.pos.distance_to(g.pos) < 520.0:
			action_kind = "jump"
			action_arg = g
			hud.set_action("Sprung → " + Universe.system(g.to).n)
			return
	for ln in world.lanes:
		for end in [0, 1]:
			var p: Vector3 = ln.p0 if end == 0 else ln.p1
			if player.pos.distance_to(p) < 320.0:
				action_kind = "lane"
				action_arg = {"lane": ln, "from": end}
				hud.set_action("Handelsroute → " + String(ln.b_name if end == 0 else ln.a_name))
				return
	hud.set_action("")

func do_action() -> void:
	match action_kind:
		"salvage":
			_salvage()
		"jump":
			_start_jump(action_arg)
		"lane":
			_start_lane(action_arg)
	hud.set_action("")

func _start_lane(a: Dictionary) -> void:
	var ln: Dictionary = a.lane
	var from_p: Vector3 = ln.p0 if a.from == 0 else ln.p1
	var to_p: Vector3 = ln.p1 if a.from == 0 else ln.p0
	state = "lane"
	lane = {"t": 0.0, "from": from_p, "to": to_p, "dir": (to_p - from_p).normalized(), "start": player.pos, "q0": player.quat}
	# Gegner bleiben zurück
	for n in npcs.duplicate():
		if n.faction == "pirate":
			npcs.erase(n)
			combat.ships.erase(n)
			n.model.queue_free()
	target = null
	hud.show_banner("Handelsroute aktiv", K.AMBER, 2.0)

func _lane_update(dt: float) -> void:
	lane.t += dt
	var dir: Vector3 = lane.dir
	var q1 := Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT).get_rotation_quaternion()
	if lane.t < 1.0:
		var k: float = lane.t
		player.quat = (lane.q0 as Quaternion).slerp(q1, k * k * (3.0 - 2.0 * k))
		player.pos = (lane.start as Vector3).lerp(lane.from, k * k)
		player.vel = dir * 100.0
	else:
		player.quat = q1
		var remaining := player.pos.distance_to(lane.to)
		var spd := minf(SpaceWorld.LANE_SPEED, 200.0 + (lane.t - 1.0) * 2500.0)
		spd = minf(spd, remaining * 2.0 + 150.0)
		player.vel = dir * spd
		player.pos += player.vel * dt
		if remaining < 60.0 or (player.pos - lane.to).dot(dir) > 0.0:
			player.vel = dir * 150.0
			hud.set_throttle(150.0 / float(S.vmax))
			state = "flying"
			hud.show_banner("Handelsroute verlassen", K.AMBER, 2.0)
	cam.fov = lerpf(cam.fov, fov_base + clampf(player.vel.length() / SpaceWorld.LANE_SPEED, 0.0, 1.0) * 18.0, dt * 3.0)

func _start_jump(g: Dictionary) -> void:
	state = "jump"
	jump = {"t": 0.0, "gate": g, "start": player.pos, "q0": player.quat, "built": false}
	_clear_npcs()
	hud.show_banner("Sprungsequenz eingeleitet", K.ICE, 2.0)

func _jump_update(dt: float) -> void:
	jump.t += dt
	var t: float = jump.t
	var g: Dictionary = jump.gate
	if t < 1.6:
		var gp: Vector3 = g.pos
		var dir := (gp - player.pos).normalized()
		if player.pos.distance_to(gp) < 5.0:
			dir = player.forward()
		var q1 := Basis.looking_at(dir, Vector3.UP).get_rotation_quaternion()
		player.quat = player.quat.slerp(q1, clampf(dt * 3.0, 0.0, 1.0))
		player.vel = player.forward() * (100.0 + t * 500.0)
		player.pos += player.vel * dt
		hud.tint_rect.color.a = clampf((t - 0.8) * 1.2, 0.0, 0.9)
		cam.fov = lerpf(cam.fov, fov_base + 25.0, dt * 2.0)
	elif not jump.built:
		jump.built = true
		var dest := Universe.gate(g.to_gate)
		world.build(g.to)
		_new_combat()
		player.rebuild_model(world)
		_set_load()
		var dg := world.gate_by_id(g.to_gate)
		var n: Node3D = dg.node
		var out := n.global_basis.z.normalized()
		player.pos = dg.pos + out * 700.0
		player.quat = Basis.looking_at(out, Vector3.UP).get_rotation_quaternion()
		player.vel = out * 200.0
		Game.s.system = g.to
		_spawn_wreck_node()
		bounty_spawned = false
		wreck_looted_once = false
		pirate_timer = rng.randf_range(30.0, 60.0)
		trader_timer = 1.0
	elif t < 3.4:
		player.vel = player.forward() * 200.0
		player.pos += player.vel * dt
		hud.tint_rect.color.a = clampf(0.9 - (t - 1.6) * 0.6, 0.0, 0.9)
		cam.fov = lerpf(cam.fov, fov_base, dt * 2.0)
	else:
		hud.tint_rect.color.a = 0.0
		state = "flying"
		hud.set_throttle(200.0 / float(S.vmax))
		var sys := Universe.system(world.sys_id)
		hud.show_banner("%s · %s" % [sys.n, sys.desc], K.ICE, 4.0)

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

	var mass: float = float(S.dry) + (float(job.mass) if not job.is_empty() and job.type == "cargo" else 0.0)
	var agility: float = float(S.turn) * clampf(sqrt(30.0 / mass), 0.45, 1.25)
	var r_acc: float = 3.2 * float(S.turn) * clampf(30.0 / mass, 0.3, 1.3)
	var tgt := Vector3(ip * 1.05, iy * 0.75, ir * 1.7) * agility
	player.ang.x = move_toward(player.ang.x, tgt.x, r_acc * dt)
	player.ang.y = move_toward(player.ang.y, tgt.y, r_acc * dt)
	player.ang.z = move_toward(player.ang.z, tgt.z, r_acc * dt)
	player.quat = (player.quat * Quaternion.from_euler(player.ang * dt)).normalized()

	var fwd := player.forward()
	var rgt := player.quat * Vector3(1, 0, 0)
	var upv := player.quat * Vector3(0, 1, 0)
	var main_a: float = float(S.thrust) / mass
	var rcs: float = main_a * 0.4 * float(S.strafe)
	var thr := hud.throttle
	var vel := player.vel
	if fa:
		var dv := fwd * (thr * float(S.vmax)) - vel
		var df := dv.dot(fwd)
		var dr := dv.dot(rgt)
		var du := dv.dot(upv)
		var lim := (main_a if df > 0.0 else rcs * 1.6) * dt
		var af := clampf(df, -lim, lim)
		vel += fwd * af + rgt * clampf(dr, -rcs * dt, rcs * dt) + upv * clampf(du, -rcs * dt, rcs * dt)
	else:
		var a := thr * main_a if thr >= 0.0 else (thr / -Hud.THR_MIN) * rcs * 1.6
		vel += fwd * a * dt
	player.vel = vel
	player.pos += vel * dt
	hit_cd -= dt
	player.tick(dt)

	# Waffen
	var w := player.weapon
	if hud.firing and player.fire_cd <= 0.0 and player.energy >= float(w.energy):
		player.fire_cd = 1.0 / float(w.rate)
		player.energy -= float(w.energy)
		var aim := fwd
		if target != null and target.alive:
			var ld := ShipState.lead_dir(player.pos, player.vel, target.pos, target.vel, float(w.speed))
			if fwd.angle_to(ld) < 0.26:
				aim = ld
		for m in player.muzzles():
			combat.spawn_bolt(player, m, aim, w)

	var sp := vel.length()
	var sr: float = S.dim.z * 0.45
	var dp := player.pos - world.planet_pos
	if dp.length() < world.planet_r + 150.0:
		player.pos = world.planet_pos + dp.normalized() * (world.planet_r + 160.0)
		collide(dp.normalized(), max(sp, 200.0))
	for r in world.rocks:
		var d: float = player.pos.distance_to(r.p)
		if d < r.r + sr:
			var n: Vector3 = (player.pos - r.p).normalized()
			player.pos = r.p + n * (r.r + sr + 0.5)
			collide(n, sp)
	for st in world.stations:
		var node: Node3D = st.node
		var d := player.pos.distance_to(node.position)
		if d > 320.0:
			continue
		var lp := node.to_local(player.pos)
		var in_corr := lp.z > 118.0 and absf(lp.x) < 47.0 and absf(lp.y) < 37.0
		if d < 262.0 and not in_corr:
			var n := (player.pos - node.position).normalized()
			player.pos = node.position + n * 264.0
			collide(n, sp)
		elif in_corr and lp.z < 330.0 and state == "flying":
			if sp < 30.0:
				begin_dock(st)
			elif hit_cd <= 0.0 and lp.z < 215.0:
				collide(node.global_basis.z.normalized(), sp)
	for g in world.gates:
		var gn: Node3D = g.node
		var lp := gn.to_local(player.pos)
		var rr := Vector2(lp.x, lp.y).length()
		if absf(lp.z) < 30.0 and rr > 160.0 and rr < 250.0:
			collide((player.pos - gn.to_global(Vector3(lp.x, lp.y, 0).normalized() * 200.0)).normalized(), sp)

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
	player.sync_model()
	var dim: Vector3 = S.dim
	var shake := Vector3.ZERO
	if hud.flash_rect.color.a > 0.1:
		shake = Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), 0) * hud.flash_rect.color.a * 0.15
	if cam_mode == "cockpit" and state != "dead":
		player.model.visible = false
		cockpit.visible = true
		var eye: Vector3 = player.model.get_meta("eye")
		cam.global_position = player.pos + player.quat * (eye + shake)
		cam.quaternion = player.quat
	else:
		player.model.visible = state != "dead"
		cockpit.visible = false
		var want := player.pos + player.quat * Vector3(0, dim.y * 1.4 + 4.0, dim.z * 1.5 + 16.0)
		if not chase_init:
			cam_pos = want
			cam_q = player.quat
			chase_init = true
		if state != "dead":
			cam_pos = cam_pos.lerp(want, 1.0 - exp(-dt * 7.0))
			cam_q = cam_q.slerp(player.quat, 1.0 - exp(-dt * 4.5))
			cam.global_position = want.lerp(cam_pos, 0.35) + player.quat * shake * 4.0
			cam.quaternion = cam_q
	var streak := 0.05
	if state == "lane":
		streak = 0.012
	elif state == "jump":
		streak = 0.03
	world.update_dust(cam.global_position, player.vel, streak)
	player.set_engine(maxf(0.0, hud.throttle) if state == "flying" else 1.0, rng, t0)
	for n in npcs:
		n.sync_model()
		n.set_engine(n.throttle, rng, t0)
	if wreck_node:
		wreck_node.rotate_object_local(Vector3(0.3, 1, 0.2).normalized(), dt * 0.08)
		var fire: OmniLight3D = wreck_node.get_meta("fire")
		fire.light_energy = 2.0 + rng.randf() * 2.5

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
	var sp := player.vel.length()
	hud.spd_lbl.text = str(roundi(sp))
	var hf := player.hull_frac()
	hud.hull_bar.set_value(hf, K.DANGER if hf < 0.35 else (K.AMBER if hf < 0.7 else K.OK))
	hud.shield_bar.set_value(player.shield_frac(), Color(0.5, 0.8, 1.0))
	hud.energy_bar.set_value(player.energy / float(S.energy), K.AMBER)
	var cargo_job: bool = not job.is_empty() and job.type == "cargo"
	var cond: float = clampf(float(job.cond), 0.0, 100.0) if cargo_job else 0.0
	hud.cargo_bar.set_value(cond / 100.0, K.DANGER if cond < 50.0 else K.OK)
	hud.pro_vis = false
	if sp > 3.0 and state == "flying":
		var m := _screen_marker(player.pos + player.vel / sp * 2000.0, false)
		hud.pro_vis = m.vis
		if m.vis:
			hud.pro_pos = m.pos
	var mk := []
	var nv := _resolve_nav()
	if not nv.is_empty() and state in ["flying", "lane"]:
		var np: Vector3 = nv.pos
		var d := player.pos.distance_to(np)
		var m := _screen_marker(np, true)
		var closing := -player.vel.dot((player.pos - np).normalized())
		var eta_txt := ""
		if closing > 5.0 and d / closing < 6000.0:
			eta_txt = "  ·  " + Game.mmss(d / closing)
		mk.append({"kind": "nav", "pos": m.pos, "edge": m.edge, "text": "%s  %s%s" % [nv.name, Game.dist_txt(d), eta_txt]})
		if nv.has("entrance") and d < 5000.0:
			var bm := _screen_marker(nv.entrance, false)
			if bm.vis:
				mk.append({"kind": "bay", "pos": bm.pos, "edge": false})
	if wreck_node and (nav.is_empty() or nav.kind != "wreck"):
		var wp := wreck_node.global_position
		var m := _screen_marker(wp, true)
		mk.append({"kind": "wreck", "pos": m.pos, "edge": m.edge, "text": "Wrack  " + Game.dist_txt(player.pos.distance_to(wp))})
	hud.lead_vis = false
	for n in npcs:
		var d: float = n.pos.distance_to(player.pos)
		if n.faction == "pirate":
			var m := _screen_marker(n.pos, true)
			var sel: bool = n == target
			mk.append({"kind": "hostile", "pos": m.pos, "edge": m.edge, "sel": sel, "hp": n.hull_frac(), "sh": n.shield_frac(),
				"text": "%s · %s" % [n.name, Game.dist_txt(d)]})
			if sel and d < 2500.0:
				var lp := ShipState.lead_point(player.pos, player.vel, n.pos, n.vel, float(player.weapon.speed))
				var lm := _screen_marker(lp, false)
				hud.lead_vis = lm.vis
				if lm.vis:
					hud.lead_pos = lm.pos
		elif d < 3000.0:
			var m := _screen_marker(n.pos, false)
			if m.vis:
				mk.append({"kind": "trader", "pos": m.pos, "edge": false})
	hud.markers = mk
	if cargo_job and state == "flying":
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
			if player.pos.distance_to(node.position) > 1800.0:
				continue
			var lp := node.to_local(player.pos)
			var away := player.vel.dot(node.global_basis.z.normalized()) > 2.0
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
	hud.sys_lbl.text = Universe.system(world.sys_id).n.to_upper()
	if not job.is_empty() and job.type == "cargo":
		hud.cargo_lbl.text = "%s · %d t" % [job.cargo, int(job.mass)]
		hud.dest_lbl.text = "→ " + String(job.dest_name)
	elif not job.is_empty():
		hud.cargo_lbl.text = "Kopfgeld: " + String(job.target)
		hud.dest_lbl.text = "→ " + String(job.sys_name)
	else:
		var nv := _resolve_nav()
		hud.cargo_lbl.text = "Freier Flug" if not nv.is_empty() else "Kein Auftrag"
		hud.dest_lbl.text = ("→ " + String(nv.name)) if not nv.is_empty() else ""
	var mass: float = float(S.dry) + (float(job.mass) if not job.is_empty() and job.type == "cargo" else 0.0)
	hud.mass_lbl.text = "%d t" % roundi(mass)

# ------------------------------------------------------------------ Menü
func open_menu() -> void:
	reset_armed = false
	_fill_menu()
	menu_layer.visible = true
	hud.release_all()
	walk_hud.release_all()

func _nav_btn(txt: String, nv: Dictionary, col: Color) -> Button:
	var b := K.btn(txt, func():
		nav = nv
		menu_layer.visible = false
		_update_topbar())
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_color_override("font_color", col)
	return b

func _fill_menu() -> void:
	for c in menu_box.get_children():
		c.queue_free()
	menu_box.add_child(K.lbl("Bordcomputer", 22, K.FG, K.F_BOLD))
	var cur := world.sys_id
	menu_box.add_child(K.wrap("System %s · %s · Rang %s · %s cr" % [Universe.system(cur).n, Universe.system(cur).desc, Game.rank_name(Game.rank()), Game.fmt(Game.s.credits)], 12))
	if state in ["flying", "walk", "panel"]:
		menu_box.add_child(K.caps("Navigationsziel"))
		for sid in Universe.SYSTEMS:
			var sys: Dictionary = Universe.SYSTEMS[sid]
			var j := Universe.jumps(cur, sid)
			menu_box.add_child(K.caps("%s · %s" % [sys.n, "hier" if j == 0 else "%d Sprung" % j], K.ICE if j == 0 else K.MUTED, 10))
			for st in sys.stations:
				var extra := ""
				if not job.is_empty() and job.type == "cargo" and job.dest == st.id:
					extra = " · Auftragsziel"
				var dist_s := ""
				if sid == cur and state == "flying":
					dist_s = " · " + Game.dist_txt(player.pos.distance_to(st.pos))
				menu_box.add_child(_nav_btn(st.n + dist_s + extra, {"kind": "station", "id": st.id, "sys": sid}, K.ICE))
			if sid == cur:
				for g in sys.gates:
					menu_box.add_child(_nav_btn("Sprungtor → " + Universe.system(g.to).n, {"kind": "gate", "id": g.id, "sys": sid}, K.AMBER))
		if not Game.s.wreck.is_empty():
			menu_box.add_child(_nav_btn("Wrack «%s» in %s" % [Game.s.wreck.get("name", ""), Universe.system(Game.s.wreck.sys).n], {"kind": "wreck", "sys": Game.s.wreck.sys}, Color(1.0, 0.55, 0.2)))
		if not job.is_empty() and job.type == "bounty":
			menu_box.add_child(_nav_btn("Kopfgeld: %s in %s" % [job.target, job.sys_name], {"kind": "point", "sys": job.sys, "pos": job.pos, "name": "Kopfgeld: " + String(job.target)}, K.DANGER))
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
	var close := K.btn("Weiter", func(): menu_layer.visible = false, true)
	close.custom_minimum_size = Vector2(0, 46)
	menu_box.add_child(close)

# ------------------------------------------------------------------ Schleife
func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	t0 += dt
	var paused := menu_layer.visible or intro_layer.visible or modal_layer.visible
	match state:
		"walk":
			if not paused:
				_walk_update(dt)
			return
		"panel":
			if panel_hangar:
				hangar.update(dt, get_viewport().get_visible_rect().size)
			return
	world.animate(t0, dt, _resolve_nav().get("pos", Vector3(1e9, 0, 0)), player.pos)
	if paused and state == "flying":
		_update_camera(0.0)
		return
	match state:
		"flying":
			physics(dt)
			if not job.is_empty() and job.type == "cargo":
				job.elapsed = float(job.elapsed) + dt
			_auto_target()
			_director(dt)
			_find_action()
			cam.fov = lerpf(cam.fov, fov_base, dt * 3.0)
		"docking":
			anim.t = float(anim.t) + dt / 2.6
			var k: float = anim.t
			k = k * k * (3.0 - 2.0 * k) if k < 1.0 else 1.0
			player.pos = anim.p0.lerp(anim.p1, k)
			player.quat = anim.q0.slerp(anim.q1, k)
			player.vel = Vector3.ZERO
			if anim.t >= 1.0:
				finish_dock(anim.st)
				return
		"lane":
			_lane_update(dt)
			hud.set_action("")
		"jump":
			_jump_update(dt)
			hud.set_action("")
		"dead":
			dead_t -= dt
			if dead_t <= 0.0:
				_respawn()
				return
	for n in npcs.duplicate():
		n.update_ai(dt, player, world, combat)
		if not n.alive:
			npcs.erase(n)
			combat.ships.erase(n)
			if n.model:
				n.model.queue_free()
			if target == n:
				target = null
	combat.update(dt)
	_update_camera(dt)
	_update_hud()
	if Engine.get_process_frames() % 20 == 0:
		_update_topbar()

func _input(event: InputEvent) -> void:
	if state == "panel" and panel_hangar and event is InputEventScreenDrag:
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
		if intro_layer.visible or modal_layer.visible:
			return
		if menu_layer.visible:
			menu_layer.visible = false
		elif state == "panel":
			close_panel()
		else:
			open_menu()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if player:
			Game.s.hull = player.hull_frac() * 100.0
		Game.s.job = job
		Game.save_game()

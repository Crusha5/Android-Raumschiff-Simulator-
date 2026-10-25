extends Node
## Automatischer Rundgang: Station, Schiff, Flug, Kampf, Handelsroute, Sprung, Zerstörung, Bergung.
var main: Node
var errors := 0

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var dir := OS.get_environment("SHOT_DIR")
	if dir != "":
		img.save_png(dir + "/" + name + ".png")
	print("SHOT ", name, " state=", main.state)

func wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func check(cond: bool, what: String) -> void:
	if not cond:
		errors += 1
		print("FAIL ", what)
	else:
		print("OK   ", what)

func look_at_point(p: Vector3) -> void:
	main.player.quat = Basis.looking_at((p - main.player.pos).normalized(), Vector3.UP).get_rotation_quaternion()

func _ready() -> void:
	Game.reset_game()
	if OS.get_environment("RICH") == "1":
		Game.s.credits = 300000
		Game.s.xp = 6000
	Game.s.intro_seen = true
	if OS.get_environment("SCALE") != "":
		get_viewport().scaling_3d_scale = float(OS.get_environment("SCALE"))
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await wait(30)
	await shot("00_hangar_spawn")
	check(main.state == "walk", "startet im Hangar der Station")
	main.walker.place(Transform3D(Basis(Vector3.UP, 0.98), Vector3(-22, 0.1, 10)))
	await wait(20)
	await shot("01_hangar_view")
	main.walker.place(Transform3D(Basis(Vector3.UP, -PI / 4), Vector3(-12, 0.1, 8)))
	await wait(20)
	await shot("02_promenade")
	# Figuren im Zeitraffer laufen lassen: niemand darf in Tischen/Kiosk landen
	var inside := 0
	var moved := 0.0
	var startp := {}
	for a in main.interior.actors:
		startp[a] = a.node.position
	for k in 1500:
		main.interior.update(0.05, Vector3(100, 0, 100))
		for a in main.interior.actors:
			if a.mode == "walk":
				var hit := false
				for o in main.interior.obstacles:
					if (o as Rect2).grow(-0.05).has_point(Vector2(a.node.position.x, a.node.position.z)):
						hit = true
				if hit:
					inside += 1
	for a in main.interior.actors:
		if a.mode == "walk":
			moved += a.node.position.distance_to(startp[a])
	check(moved > 5.0, "Passanten bewegen sich (%.1f m)" % moved)
	check(inside == 0, "Passanten laufen um Hindernisse (%d Treffer)" % inside)
	main.walker.place(Transform3D(Basis(Vector3.UP, PI * 0.8), Vector3(-6, 0.1, -9)))
	await wait(10)
	await shot("03_promenade_back")
	main.walker.place(Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 2.0)))
	await wait(15)
	main._walk_update(0.016)
	await shot("04_mara")
	check(main.action_kind == "jobs", "Auftraggeberin ansprechbar")
	main._walk_interact()
	await wait(10)
	var idx := -1
	for i in main.offers.size():
		if main.lock_reason(main.offers[i]) == "" and main.offers[i].dest_sys == "sol7":
			idx = i
			break
	if idx < 0:
		idx = 0
	main.take_offer(main.offers[idx])
	check(not main.job.is_empty(), "Auftrag angenommen")
	main.close_panel()
	main.walker.place(Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(22.5, 0.1, -1.0)))
	await wait(15)
	main._walk_update(0.016)
	await shot("05_bar")
	main.walker.place(Transform3D(Basis(Vector3.UP, PI * 0.9), Vector3(6, 0.1, 5.5)))
	await wait(10)
	await shot("06_shops")
	main.walker.place(Transform3D(Basis(Vector3.UP, PI), Vector3(8.5, 0.1, 8.0)))
	main.walker.pitch = -0.1
	await wait(30)
	await shot("06b_jonas_close")
	main.walker.place(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(28.5, 0.1, 4.0)))
	await wait(20)
	await shot("06c_bar_room")
	main.walker.place(Transform3D(Basis(Vector3.UP, PI), Vector3(-24, 0.1, 12.4)))
	await wait(10)
	main._walk_update(0.016)
	check(main.action_kind == "tune", "R-7 ansprechbar")
	await shot("07_r7")
	main._walk_interact()
	await wait(10)
	var before := int(Game.s.credits)
	main.tune("funke")
	check(Game.tune_level("funke") == 1 and int(Game.s.credits) < before, "Triebwerk getunt")
	await wait(10)
	await shot("08_tune")
	# Wischen in der Liste (synthetische Touch-Ereignisse)
	var sc: ScrollContainer = main.station_ui.scroll
	var r := sc.get_global_rect()
	var p0 := r.get_center() + Vector2(0, r.size.y * 0.3)
	var before_s := sc.scroll_vertical
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.position = p0
	ev.pressed = true
	Input.parse_input_event(ev)
	await wait(1)
	for k in 12:
		var dr := InputEventScreenDrag.new()
		dr.index = 0
		dr.position = p0 - Vector2(0, (k + 1) * 14)
		dr.relative = Vector2(0, -14)
		Input.parse_input_event(dr)
		await wait(1)
	var ev2 := InputEventScreenTouch.new()
	ev2.index = 0
	ev2.position = p0 - Vector2(0, 168)
	ev2.pressed = false
	var t_rel := Time.get_ticks_msec()
	Input.parse_input_event(ev2)
	await wait(2)
	print("scroll ", before_s, " -> ", sc.scroll_vertical, " max ", sc.get_v_scroll_bar().max_value, " h ", sc.size.y)
	check(sc.scroll_vertical > before_s or sc.get_v_scroll_bar().max_value <= sc.size.y, "Liste lässt sich wischen")
	check(TouchScroll.suppress_until >= t_rel and not TouchScroll.dragging_any, "Wisch sperrt Knöpfe kurz")
	main.close_panel()
	# Blaupause: Schiff erweitern und bauen
	Game.s.credits = int(Game.s.credits) + 20000
	main.open_blueprint()
	await wait(10)
	await shot("08b_blueprint")
	var ui: BlueprintUI = main.bp_ui
	check(ui.visible and ui.check.ok, "Blaupause offen, Schiff gültig")
	var cap0 := int(main.S.cap)
	ui.select_brush("k2")
	ui.cell_action(Vector2i(-2, -1), true)
	ui.select_brush("w2")
	ui.cell_action(Vector2i(-2, -2), true)
	ui.select_brush("r1")
	ui.cell_action(Vector2i(0, 2), true)
	ui.select_brush("funke")
	ui.cell_action(Vector2i(0, 3), true)
	print("bp errors ", ui.check.errors, " bad ", ui.check.bad)
	await wait(5)
	await shot("08c_blueprint_edit")
	check(ui.check.ok, "Erweiterter Entwurf gültig")
	ui.select_brush("h1")
	ui.cell_action(Vector2i(0, 5), true)
	check(not ui.check.ok, "Abgasstrahl-Regel greift")
	ui._undo()
	check(ui.check.ok, "Rückgängig")
	ui.tab = "stats"
	ui._refresh_side(true)
	await wait(3)
	await shot("08d_blueprint_stats")
	ui._build()
	await wait(3)
	check(int(main.S.cap) > cap0, "Umbau: mehr Frachtraum (%d → %d t)" % [cap0, int(main.S.cap)])
	ui._toggle_view()
	await wait(20)
	await shot("08e_blueprint_3d")
	ui.tab = "plans"
	ui._refresh_side(true)
	ui.load_bp(Game.template_bp("kondor"), "Kondor")
	ui._toggle_view()
	ui._toggle_view()
	await wait(20)
	await shot("08f_kondor_3d")
	print("kondor plan ", ui.plan, " block ", main.build_block(ui.edit, ui.plan))
	main.close_panel()
	await wait(5)
	# Zum Schiff und einsteigen
	var board = null
	for it in main.interior.interactables:
		if it.action == "board":
			board = it
			break
	main.walker.place(Transform3D(Basis.IDENTITY, board.pos + Vector3(0, -0.9, 1.0)))
	await wait(5)
	main._walk_update(0.016)
	check(main.action_kind == "board", "Einstieg am Schiff")
	await shot("09_board")
	if OS.get_environment("QUICK") == "1":
		print("ERRORS ", errors)
		get_tree().quit()
		return
	# An Bord
	main.enter_ship()
	await wait(20)
	await shot("10_ship_interior")
	main.walker.place(Transform3D(Basis(Vector3.UP, 0.0), Vector3(0, 0.1, main.interior.spawn.origin.z + 1.0)))
	await wait(10)
	await shot("11_ship_corridor")
	main.walker.place(Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0.1, -2.0)))
	await wait(10)
	await shot("11b_ship_rear")
	main.open_panel("console", "Konsole · Waffen", "«Möwe»", true, "weapon")
	await wait(10)
	await shot("12_console")
	main.close_panel()
	# Abdocken
	main.undock()
	await wait(60)
	check(main.state == "flying", "abgedockt")
	await shot("f09_cockpit")
	main.toggle_cam()
	await wait(30)
	await shot("f10_chase")
	# Kampf
	main.spawn_pirates(2, 0, main.player.pos + main.player.forward() * 900.0)
	await wait(5)
	check(main.npcs.size() >= 2, "Piraten erscheinen")
	main.hud.firing = true
	for k in 240:
		if main.target:
			look_at_point(main.target.pos)
		main.player.shield = 999.0
		main.player.hp = main.player.S.hp_max
		await get_tree().process_frame
		if k == 60:
			await shot("f11_combat")
	main.hud.firing = false
	var pir: int = main.npcs.filter(func(n): return n.faction == "pirate").size()
	print("Piraten übrig: ", pir, " Abschüsse: ", Game.s.kills)
	check(int(Game.s.kills) >= 1, "mindestens ein Abschuss")
	await shot("f12_after_combat")
	# Handelsroute
	var ln: Dictionary = main.world.lanes[0]
	main.player.pos = ln.p0 + Vector3(0, 50, 0)
	main.player.vel = Vector3.ZERO
	await wait(3)
	main._find_action()
	check(main.action_kind == "lane", "Handelsroute erkannt")
	main.do_action()
	await wait(80)
	await shot("f13_lane")
	for k in 600:
		if main.state != "lane":
			break
		await get_tree().process_frame
	check(main.state == "flying", "Handelsroute beendet")
	# Sprungtor
	var g: Dictionary = main.world.gates[0]
	main.player.pos = g.pos + g.node.global_basis.z * 400.0
	look_at_point(g.pos)
	main.player.vel = Vector3.ZERO
	await wait(5)
	await shot("f14_gate")
	main._find_action()
	check(main.action_kind == "jump", "Sprungtor erkannt")
	main.do_action()
	await wait(70)
	await shot("f15_hyperspace")
	for k in 400:
		if main.state == "flying":
			break
		await get_tree().process_frame
	check(main.world.sys_id == "vega", "in Vega-Tiefe angekommen")
	await wait(30)
	await shot("f16_vega")
	var orion: Dictionary = main.world.station_by_id("orion")
	main.player.pos = orion.node.to_global(Vector3(300, 200, 1400))
	look_at_point(orion.node.position)
	await wait(30)
	await shot("f17_orion")
	# Zerstörung
	for m in Game.s.bp.mods:
		if m[0] == "puls1":
			m[0] = "puls2"
	main._refit()
	main.player.hp = 1.0
	main.player.shield = 0.0
	main.collide(Vector3.UP, 400.0)
	await wait(10)
	check(main.state == "dead", "Schiff zerstört")
	await shot("f18_explosion")
	for k in 300:
		if main.state == "walk":
			break
		await get_tree().process_frame
	check(main.state == "walk", "Respawn an Station")
	check(not Game.s.wreck.is_empty(), "Wrack angelegt")
	check(Game.inv_count("puls2") == 0 and int(Game.s.wreck.mods.get("puls2", 0)) == 2, "Module im Wrack")
	await shot("f19_respawn")
	main.modal_layer.visible = false
	# Zum Wrack fliegen und bergen
	main.undock()
	await wait(5)
	if main.world.sys_id != Game.s.wreck.sys:
		print("Wrack in anderem System – direkt bergen")
		main._salvage()
		check(Game.inv_count("puls2") == 2, "Module geborgen")
		check(Game.s.designs.size() > 0, "Bauplan des Wracks gespeichert")
	else:
		main.player.pos = main._v3(Game.s.wreck.pos) + Vector3(0, 0, 60)
		main.player.vel = Vector3.ZERO
		look_at_point(main._v3(Game.s.wreck.pos))
		await wait(10)
		await shot("f20_wreck")
		main._find_action()
		check(main.action_kind == "salvage", "Bergung möglich")
		main.do_action()
		check(Game.inv_count("puls2") == 2, "Module geborgen")
	print("credits ", Game.s.credits, " xp ", Game.s.xp, " kills ", Game.s.kills)
	print("ERRORS ", errors)
	get_tree().quit()

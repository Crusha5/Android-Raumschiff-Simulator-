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
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await wait(30)
	await shot("00_deck")
	check(main.state == "walk", "startet auf dem Stationsdeck")
	# Zum Auftragsbrett drehen und laufen
	main.walker.place(Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(7.5, 0.1, -2.5)))
	await wait(10)
	await shot("01_deck_board")
	main._walk_update(0.016)
	check(main.action_kind == "jobs", "Auftraggeberin ansprechbar")
	main._walk_interact()
	await wait(10)
	await shot("02_jobs")
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
	# Bar
	main.walker.place(Transform3D(Basis.IDENTITY, Vector3(8.5, 0.1, -3.8)))
	await wait(5)
	main._walk_update(0.016)
	await shot("03_bar_view")
	# Ausrüster
	main.open_panel("shop", "Jonas Brack · Ausrüster", "Kepler-Dock", true, "weapon")
	main.station_ui.slot = "weapon"
	main.station_ui.refresh()
	main.try_part("weapon", "puls2")
	await wait(20)
	await shot("04_shop")
	main.close_panel()
	# An Bord
	main.enter_ship()
	await wait(20)
	await shot("05_ship_interior")
	main.walker.place(Transform3D(Basis(Vector3.UP, 0.0), Vector3(0, 0.1, main.interior.spawn.origin.z + 1.0)))
	await wait(10)
	await shot("06_ship_corridor")
	main.walker.place(Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0.1, -2.0)))
	await wait(10)
	await shot("07_ship_rear")
	main.open_panel("console", "Konsole · Waffen", "«Möwe»", true, "weapon")
	await wait(10)
	await shot("08_console")
	main.close_panel()
	# Abdocken
	main.undock()
	await wait(60)
	check(main.state == "flying", "abgedockt")
	await shot("09_cockpit")
	main.toggle_cam()
	await wait(30)
	await shot("10_chase")
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
			await shot("11_combat")
	main.hud.firing = false
	var pir: int = main.npcs.filter(func(n): return n.faction == "pirate").size()
	print("Piraten übrig: ", pir, " Abschüsse: ", Game.s.kills)
	check(int(Game.s.kills) >= 1, "mindestens ein Abschuss")
	await shot("12_after_combat")
	# Handelsroute
	var ln: Dictionary = main.world.lanes[0]
	main.player.pos = ln.p0 + Vector3(0, 50, 0)
	main.player.vel = Vector3.ZERO
	await wait(3)
	main._find_action()
	check(main.action_kind == "lane", "Handelsroute erkannt")
	main.do_action()
	await wait(80)
	await shot("13_lane")
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
	await shot("14_gate")
	main._find_action()
	check(main.action_kind == "jump", "Sprungtor erkannt")
	main.do_action()
	await wait(70)
	await shot("15_hyperspace")
	for k in 400:
		if main.state == "flying":
			break
		await get_tree().process_frame
	check(main.world.sys_id == "vega", "in Vega-Tiefe angekommen")
	await wait(30)
	await shot("16_vega")
	var orion: Dictionary = main.world.station_by_id("orion")
	main.player.pos = orion.node.to_global(Vector3(300, 200, 1400))
	look_at_point(orion.node.position)
	await wait(30)
	await shot("17_orion")
	# Zerstörung
	Game.s.fit.weapon = "puls2"
	Game.s.owned.weapon.append("puls2")
	main.player.hp = 1.0
	main.player.shield = 0.0
	main.collide(Vector3.UP, 400.0)
	await wait(10)
	check(main.state == "dead", "Schiff zerstört")
	await shot("18_explosion")
	for k in 300:
		if main.state == "walk":
			break
		await get_tree().process_frame
	check(main.state == "walk", "Respawn an Station")
	check(not Game.s.wreck.is_empty(), "Wrack angelegt")
	check(not Game.s.owned.weapon.has("puls2"), "Teil im Wrack")
	await shot("19_respawn")
	main.modal_layer.visible = false
	# Zum Wrack fliegen und bergen
	main.undock()
	await wait(5)
	if main.world.sys_id != Game.s.wreck.sys:
		print("Wrack in anderem System")
	else:
		main.player.pos = main._v3(Game.s.wreck.pos) + Vector3(0, 0, 60)
		main.player.vel = Vector3.ZERO
		look_at_point(main._v3(Game.s.wreck.pos))
		await wait(10)
		await shot("20_wreck")
		main._find_action()
		check(main.action_kind == "salvage", "Bergung möglich")
		main.do_action()
		check(Game.s.owned.weapon.has("puls2"), "Teil geborgen")
	print("credits ", Game.s.credits, " xp ", Game.s.xp, " kills ", Game.s.kills)
	print("ERRORS ", errors)
	get_tree().quit()

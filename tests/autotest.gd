extends Node
## Automatischer Rundgang für Tests: lädt das Spiel, klickt sich durch und speichert Screenshots.
var main: Node
var out := "user://shots/"

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OS.get_environment("SHOT_DIR") + "/" + name + ".png")
	print("SHOT ", name)

func wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _ready() -> void:
	Game.reset_game()
	var rich := OS.get_environment("RICH") == "1"
	if rich:
		Game.s.credits = 300000
		Game.s.xp = 6000
		Game.s.intro_seen = true
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await wait(30)
	await shot("00_intro")
	main.intro_layer.visible = false
	await wait(10)
	await shot("01_fracht")
	if rich:
		for p in [["frame", "kondor"], ["engine", "hyperion"], ["cargo", "k120"], ["armor", "a3"], ["rcs", "rcs4"], ["extra", "bake"]]:
			main.buy(p[0], p[1])
		main.set_paint("pattern", "warn")
		main.set_paint("hull", "#4a4f58")
		main.set_paint("flame", "violett")
		main.apply_paint()
	main.station_ui._set_tab("werft")
	await wait(5)
	main.try_part("engine", "orion")
	await wait(20)
	await shot("02_werft")
	main.station_ui._set_tab("lack")
	main.set_paint("hull", "#2f4a6b")
	await wait(20)
	await shot("03_lack")
	main.reset_paint()
	main.station_ui._set_tab("fracht")
	await wait(3)
	var idx := 0
	for i in main.offers.size():
		if main.lock_reason(main.offers[i]) == "":
			idx = i
			break
	main.take_offer(idx)
	await wait(5)
	main.undock()
	await wait(90)
	await shot("04_cockpit")
	main.toggle_cam()
	await wait(40)
	await shot("05_chase")
	# Zum Ziel ausrichten und hinfliegen (Teleport kurz vor den Korridor)
	var st: Dictionary = main.nav_target
	var n: Node3D = st.node
	main.pos = n.to_global(Vector3(0, 40, 900))
	var look := Basis.looking_at(n.global_position - main.pos, Vector3.UP)
	main.quat = look.get_rotation_quaternion()
	main.vel = Vector3.ZERO
	main.hud.set_throttle(0.0)
	await wait(40)
	await shot("06_station")
	main.toggle_cam()
	await wait(20)
	await shot("07_station_cockpit")
	# Andocken auslösen
	main.pos = n.to_global(Vector3(0, 0, 300))
	main.quat = (n.global_basis.get_rotation_quaternion() * Quaternion(Vector3.UP, 0.0))
	main.vel = n.global_basis * Vector3(0, 0, -10)
	await wait(240)
	await shot("08_delivered")
	# Asteroidenfeld + Planet ansehen
	main.undock()
	main.toggle_cam()
	var mine: Node3D = main.world.stations[2].node
	main.pos = mine.to_global(Vector3(600, 300, 2600))
	main.quat = Basis.looking_at(mine.global_position - main.pos, Vector3.UP).get_rotation_quaternion()
	main.vel = Vector3.ZERO
	await wait(40)
	await shot("09_asteroids")
	main.pos = Vector3(0, 0, -2000)
	main.quat = Basis.looking_at(main.world.PLANET_POS - main.pos, Vector3.UP).get_rotation_quaternion()
	await wait(30)
	await shot("10_planet")
	main.quat = Basis.looking_at(Vector3(0.2, 0.9, 0.3), Vector3.FORWARD).get_rotation_quaternion()
	await wait(20)
	await shot("11_sky")
	print("credits ", Game.s.credits, " xp ", Game.s.xp, " deliveries ", Game.s.deliveries)
	get_tree().quit()

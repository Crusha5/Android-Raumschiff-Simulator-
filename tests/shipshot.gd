extends Node
## Rendert alle Vorlagen in der Werfthalle (für Screenshots).
func _ready() -> void:
	var h := Hangar.new()
	add_child(h)
	var env := WorldEnvironment.new()
	env.environment = h.env
	add_child(env)
	h.cam.make_current()
	h.panel_frac = 0.0
	var r := RandomNumberGenerator.new()
	var paints := [{"hull": "#c9c2b2", "accent": "#ffb547", "pattern": "band", "flame": "auto"}, {"hull": "#2f4a6b", "accent": "#e4e8ec", "pattern": "renn", "flame": "auto"},
		{"hull": "#a8322a", "accent": "#1c1e22", "pattern": "zweiton", "flame": "auto"}, {"hull": "#4a4f58", "accent": "#f2c230", "pattern": "warn", "flame": "auto"}, {"hull": "#e4e8ec", "accent": "#3fc1c9", "pattern": "band", "flame": "auto"}]
	var i := 0
	for t in Game.TEMPLATES:
		h.set_ship(ShipBuilder.build(Game.template_bp(t.id), paints[i % paints.size()]))
		h.rot = 0.7
		h.tilt = 0.05
		for k in 8:
			h.update(0.0, get_viewport().get_visible_rect().size)
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_DIR") + "/ship_%s.png" % t.id)
		print("shot ", t.id)
		i += 1
	get_tree().quit()

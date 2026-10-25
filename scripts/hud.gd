class_name Hud
extends Control
## Flug-HUD mit Touch-Steuerung: Joystick (linke Hälfte), Schubhebel und Rolltasten (rechts).

signal cam_pressed
signal fa_pressed
signal menu_pressed

const K = preload("res://scripts/ui_kit.gd")
const THR_MIN := -0.25
const STICK_R := 60.0

var throttle := 0.0
var stick := Vector2.ZERO
var roll := 0.0
var invert_y := false

var _stick_idx := -1
var _stick_origin := Vector2.ZERO
var _thr_idx := -1
var _roll_idx := -1
var _roll_val := 0.0
var _hint := true

# Vom Hauptskript gesetzt
var pro_vis := false
var pro_pos := Vector2.ZERO
var tgt_vis := false
var tgt_pos := Vector2.ZERO
var tgt_edge := false
var tgt_text := ""
var bay_vis := false
var bay_pos := Vector2.ZERO
var cockpit := true

var job_box: PanelContainer
var rank_lbl: Label
var credits_lbl: Label
var cargo_lbl: Label
var dest_lbl: Label
var timer_lbl: Label
var cam_btn: Button
var fa_btn: Button
var banner: Label
var banner_until := 0.0
var spd_lbl: Label
var mass_lbl: Label
var acc_lbl: Label
var hull_bar: UIKit.Bar
var cargo_bar: UIKit.Bar
var flash_rect: ColorRect

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	job_box = K.card("Hud")
	job_box.position = Vector2(10, 10)
	job_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(job_box)
	var jv := K.vbox(2)
	job_box.add_child(jv)
	var r1 := K.hbox(16)
	rank_lbl = K.caps("Kadett")
	credits_lbl = K.lbl("0 cr", 15, K.AMBER, K.F_MONO)
	r1.add_child(rank_lbl)
	r1.add_child(K.spacer())
	r1.add_child(credits_lbl)
	jv.add_child(r1)
	var r2 := K.hbox(10)
	cargo_lbl = K.lbl("Kein Auftrag", 14, K.FG)
	dest_lbl = K.lbl("", 13, K.ICE)
	timer_lbl = K.lbl("", 13, K.FG, K.F_MONO)
	r2.add_child(cargo_lbl)
	r2.add_child(dest_lbl)
	r2.add_child(timer_lbl)
	jv.add_child(r2)

	var tr := K.hbox(6)
	tr.anchor_left = 1.0
	tr.anchor_right = 1.0
	tr.offset_left = -10
	tr.offset_right = -10
	tr.offset_top = 10
	tr.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(tr)
	cam_btn = K.btn("Außen", func(): cam_pressed.emit())
	fa_btn = K.btn("FA ein", func(): fa_pressed.emit(), true)
	tr.add_child(cam_btn)
	tr.add_child(fa_btn)
	tr.add_child(K.btn("Menü", func(): menu_pressed.emit()))

	banner = K.lbl("", 14, K.OK, K.F_SEMI)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	banner.offset_top = 74
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.visible = false
	add_child(banner)

	var inst := K.hbox(18)
	inst.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	inst.grow_horizontal = Control.GROW_DIRECTION_BOTH
	inst.grow_vertical = Control.GROW_DIRECTION_BEGIN
	inst.offset_bottom = -12
	inst.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(inst)
	var m1 := K.vbox(3)
	m1.add_child(K.caps("Hülle"))
	hull_bar = UIKit.Bar.new(92, 6)
	m1.add_child(hull_bar)
	m1.add_child(K.caps("Ladung"))
	cargo_bar = UIKit.Bar.new(92, 6)
	m1.add_child(cargo_bar)
	inst.add_child(m1)
	var m2 := K.vbox(0)
	spd_lbl = K.lbl("0", 36, K.AMBER, K.F_MONO)
	spd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	spd_lbl.custom_minimum_size = Vector2(80, 0)
	m2.add_child(spd_lbl)
	var u := K.caps("m/s")
	u.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	m2.add_child(u)
	inst.add_child(m2)
	var m3 := K.vbox(2)
	m3.add_child(K.caps("Masse"))
	mass_lbl = K.lbl("0 t", 13, K.FG, K.F_MONO)
	m3.add_child(mass_lbl)
	m3.add_child(K.caps("Schub"))
	acc_lbl = K.lbl("—", 13, K.FG, K.F_MONO)
	m3.add_child(acc_lbl)
	inst.add_child(m3)

	flash_rect = ColorRect.new()
	flash_rect.color = Color(1.0, 0.2, 0.12, 0.0)
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash_rect)

func thr_rect() -> Rect2:
	var hgt := minf(size.y * 0.48, 250.0)
	return Rect2(Vector2(size.x - 16 - 62, size.y - 30 - hgt), Vector2(62, hgt))

func roll_centers() -> Array:
	var t := thr_rect()
	var x := t.position.x - 14 - 29
	return [Vector2(x, t.end.y - 29 - 68), Vector2(x, t.end.y - 29)]

func set_throttle(v: float) -> void:
	throttle = clampf(v, THR_MIN, 1.0)
	if absf(throttle) < 0.035:
		throttle = 0.0

func _throttle_from(p: Vector2) -> void:
	var t := thr_rect()
	var f := 1.0 - clampf((p.y - t.position.y) / t.size.y, 0.0, 1.0)
	set_throttle(THR_MIN + f * (1.0 - THR_MIN))

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var e := make_input_local(event) as InputEventScreenTouch
		var p := e.position
		if e.pressed:
			if p.y < 64.0:
				return
			var rc := roll_centers()
			if thr_rect().grow(16).has_point(p):
				_thr_idx = e.index
				_throttle_from(p)
			elif p.distance_to(rc[0]) < 36.0:
				_roll_idx = e.index; _roll_val = 1.0
			elif p.distance_to(rc[1]) < 36.0:
				_roll_idx = e.index; _roll_val = -1.0
			elif p.x < size.x * 0.5 and _stick_idx < 0:
				_stick_idx = e.index
				_stick_origin = p
				stick = Vector2.ZERO
				_hint = false
		else:
			if e.index == _stick_idx:
				_stick_idx = -1
				stick = Vector2.ZERO
			if e.index == _thr_idx:
				_thr_idx = -1
			if e.index == _roll_idx:
				_roll_idx = -1
				_roll_val = 0.0
	elif event is InputEventScreenDrag:
		var e := make_input_local(event) as InputEventScreenDrag
		if e.index == _stick_idx:
			var d := e.position - _stick_origin
			if d.length() > STICK_R:
				d = d.normalized() * STICK_R
			stick = d / STICK_R
		elif e.index == _thr_idx:
			_throttle_from(e.position)
	roll = _roll_val

func release_all() -> void:
	_stick_idx = -1; _thr_idx = -1; _roll_idx = -1; _roll_val = 0.0
	stick = Vector2.ZERO
	roll = 0.0

func show_banner(text: String, color: Color, secs := 0.0) -> void:
	banner.text = text
	banner.add_theme_color_override("font_color", color)
	var sb := UIKit.box_style(Color(color.r * 0.12, color.g * 0.12, color.b * 0.12, 0.8), Color(color, 0.45), 1, 4, Vector2(14, 7))
	banner.add_theme_stylebox_override("normal", sb)
	banner.visible = true
	banner_until = (Time.get_ticks_msec() / 1000.0 + secs) if secs > 0.0 else INF

func hide_banner() -> void:
	banner.visible = false
	banner_until = 0.0

func banner_free() -> bool:
	return not banner.visible or banner_until == INF

func flash() -> void:
	flash_rect.color.a = 0.45
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(80)

func _process(delta: float) -> void:
	if flash_rect.color.a > 0.0:
		flash_rect.color.a = maxf(0.0, flash_rect.color.a - delta * 1.2)
	if banner.visible and banner_until != INF and Time.get_ticks_msec() / 1000.0 > banner_until:
		hide_banner()
	queue_redraw()

func _draw() -> void:
	var font := K.F_MONO
	# Zentrum / Fadenkreuz
	var c := size * 0.5
	var am := Color(K.AMBER, 0.75)
	for d in [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]:
		draw_line(c + d * 5.0, c + d * 13.0, am, 1.6, true)
	draw_circle(c, 1.6, K.AMBER)
	# Prograd
	if pro_vis:
		draw_circle(pro_pos, 6.0, K.OK, false, 1.8, true)
		for d in [Vector2(0, -1), Vector2(-1, 0), Vector2(1, 0)]:
			draw_line(pro_pos + d * 6.0, pro_pos + d * 12.0, K.OK, 1.8, true)
	# Ziel
	if tgt_vis:
		var col := K.AMBER if tgt_edge else K.ICE
		var pts := PackedVector2Array([tgt_pos + Vector2(0, -15), tgt_pos + Vector2(15, 0), tgt_pos + Vector2(0, 15), tgt_pos + Vector2(-15, 0), tgt_pos + Vector2(0, -15)])
		draw_polyline(pts, col, 2.0, true)
		var tx := tgt_pos + Vector2(22, 5)
		if tx.x > size.x - 240:
			tx.x = tgt_pos.x - 22 - font.get_string_size(tgt_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(font, tx, tgt_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
	if bay_vis:
		draw_circle(bay_pos, 9.0, K.OK, false, 2.0, true)
		draw_string(K.F_SEMI, bay_pos + Vector2(14, 4), "BUCHT", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, K.OK)
	# Joystick
	if _stick_idx >= 0:
		draw_circle(_stick_origin, 70.0, Color(K.AMBER, 0.35), false, 1.5, true)
		var kp := _stick_origin + stick * STICK_R
		draw_circle(kp, 27.0, Color(K.AMBER, 0.22), true, -1.0, true)
		draw_circle(kp, 27.0, K.AMBER, false, 2.0, true)
	elif _hint:
		var hc := Vector2(80, size.y - 90)
		draw_arc(hc, 55.0, 0, TAU, 48, Color(K.AMBER, 0.25), 1.5, true)
		draw_string(K.F_SEMI, hc + Vector2(-26, 0), "LENKEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, K.MUTED)
		draw_string(K.F_REG, hc + Vector2(-17, 15), "ziehen", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, K.MUTED)
	# Schubhebel
	var t := thr_rect()
	draw_style_box(UIKit.box_style(K.PANEL, K.LINE, 1, 6), t)
	var rng := 1.0 - THR_MIN
	var zero_y := t.end.y - t.size.y * (-THR_MIN / rng)
	var val_y := t.end.y - t.size.y * ((throttle - THR_MIN) / rng)
	draw_line(Vector2(t.position.x + 4, zero_y), Vector2(t.end.x - 4, zero_y), K.MUTED, 2.0)
	if throttle >= 0.0:
		draw_rect(Rect2(Vector2(t.position.x + 8, val_y), Vector2(t.size.x - 16, zero_y - val_y)), K.AMBER)
	else:
		draw_rect(Rect2(Vector2(t.position.x + 8, zero_y), Vector2(t.size.x - 16, val_y - zero_y)), K.ICE)
	draw_string(K.F_SEMI, Vector2(t.position.x, t.position.y - 8), "SCHUB", HORIZONTAL_ALIGNMENT_CENTER, t.size.x, 10, K.MUTED)
	draw_string(font, Vector2(t.position.x, t.end.y + 16), "%d%%" % roundi(throttle * 100.0), HORIZONTAL_ALIGNMENT_CENTER, t.size.x, 11, K.AMBER)
	# Rolltasten
	var rc := roll_centers()
	for i in 2:
		var act := _roll_idx >= 0 and ((_roll_val > 0.0) == (i == 0))
		draw_circle(rc[i], 29.0, Color(K.AMBER, 0.25) if act else K.PANEL, true, -1.0, true)
		draw_circle(rc[i], 29.0, K.LINE, false, 1.0, true)
		draw_arc(rc[i], 11.0, -2.6 if i == 0 else -0.5, 2.0 if i == 0 else 4.1, 20, K.AMBER, 2.2, true)
		var tip: Vector2 = rc[i] + Vector2(cos(-2.6 if i == 0 else 4.1), sin(-2.6 if i == 0 else 4.1)) * 11.0
		draw_circle(tip, 3.0, K.AMBER)

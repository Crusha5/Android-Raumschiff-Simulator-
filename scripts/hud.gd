class_name Hud
extends Control
## Flug-HUD mit Touch-Steuerung: Joystick (linke Hälfte), Rolltasten (links), Feuer, Ziel und Schubhebel (rechts).

signal cam_pressed
signal fa_pressed
signal menu_pressed
signal action_pressed
signal target_pressed

const K = preload("res://scripts/ui_kit.gd")
const THR_MIN := -0.25
const STICK_R := 60.0

var throttle := 0.0
var stick := Vector2.ZERO
var roll := 0.0
var firing := false

var _stick_idx := -1
var _stick_origin := Vector2.ZERO
var _thr_idx := -1
var _roll_idx := -1
var _roll_val := 0.0
var _fire_idx := -1
var _hint := true

# Vom Hauptskript gesetzt
var pro_vis := false
var pro_pos := Vector2.ZERO
var markers: Array = []
var lead_vis := false
var lead_pos := Vector2.ZERO
var hostile_warn := 0.0

var job_box: PanelContainer
var rank_lbl: Label
var credits_lbl: Label
var cargo_lbl: Label
var dest_lbl: Label
var timer_lbl: Label
var sys_lbl: Label
var cam_btn: Button
var fa_btn: Button
var action_btn: Button
var banner: Label
var banner_until := 0.0
var spd_lbl: Label
var mass_lbl: Label
var shield_bar: UIKit.Bar
var hull_bar: UIKit.Bar
var energy_bar: UIKit.Bar
var cargo_bar: UIKit.Bar
var flash_rect: ColorRect
var tint_rect: ColorRect

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	tint_rect = ColorRect.new()
	tint_rect.color = Color(0.4, 0.6, 1.0, 0.0)
	tint_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tint_rect)

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
	sys_lbl = K.caps("Sol-7", K.MUTED, 10)
	jv.add_child(sys_lbl)

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
	banner.offset_top = 78
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.visible = false
	add_child(banner)

	action_btn = K.btn("Aktion", func(): action_pressed.emit(), true)
	action_btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	action_btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	action_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	action_btn.offset_bottom = -92
	action_btn.custom_minimum_size = Vector2(240, 48)
	action_btn.add_theme_font_size_override("font_size", 16)
	action_btn.visible = false
	add_child(action_btn)

	var inst := K.hbox(16)
	inst.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	inst.grow_horizontal = Control.GROW_DIRECTION_BOTH
	inst.grow_vertical = Control.GROW_DIRECTION_BEGIN
	inst.offset_bottom = -10
	inst.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(inst)
	var m1 := K.vbox(2)
	var bars := []
	for t in ["Schild", "Hülle", "Energie"]:
		var row := K.hbox(6)
		var l := K.caps(t, K.MUTED, 9)
		l.custom_minimum_size = Vector2(46, 0)
		row.add_child(l)
		var b := UIKit.Bar.new(88, 5)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(b)
		m1.add_child(row)
		bars.append(b)
	shield_bar = bars[0]
	hull_bar = bars[1]
	energy_bar = bars[2]
	inst.add_child(m1)
	var m2 := K.vbox(0)
	spd_lbl = K.lbl("0", 34, K.AMBER, K.F_MONO)
	spd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	spd_lbl.custom_minimum_size = Vector2(80, 0)
	m2.add_child(spd_lbl)
	var u := K.caps("m/s", K.MUTED, 9)
	u.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	m2.add_child(u)
	inst.add_child(m2)
	var m3 := K.vbox(2)
	var rr := K.hbox(6)
	var ll := K.caps("Ladung", K.MUTED, 9)
	ll.custom_minimum_size = Vector2(46, 0)
	rr.add_child(ll)
	cargo_bar = UIKit.Bar.new(70, 5)
	cargo_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rr.add_child(cargo_bar)
	m3.add_child(rr)
	m3.add_child(K.caps("Masse", K.MUTED, 9))
	mass_lbl = K.lbl("0 t", 13, K.FG, K.F_MONO)
	m3.add_child(mass_lbl)
	inst.add_child(m3)

	flash_rect = ColorRect.new()
	flash_rect.color = Color(1.0, 0.2, 0.12, 0.0)
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash_rect)

# ------------------------------------------------------------------ Layout
func thr_rect() -> Rect2:
	var hgt := minf(size.y * 0.44, 210.0)
	return Rect2(Vector2(size.x - 14 - 54, size.y - 30 - hgt), Vector2(54, hgt))

func fire_center() -> Vector2:
	var t := thr_rect()
	return Vector2(t.position.x - 24 - 46, size.y - 44 - 62)

func target_center() -> Vector2:
	var f := fire_center()
	return f + Vector2(-58, -66)

func roll_centers() -> Array:
	var y := size.y * 0.42
	return [Vector2(36, y), Vector2(36, y + 64)]

func set_throttle(v: float) -> void:
	throttle = clampf(v, THR_MIN, 1.0)
	if absf(throttle) < 0.035:
		throttle = 0.0

func _throttle_from(p: Vector2) -> void:
	var t := thr_rect()
	var f := 1.0 - clampf((p.y - t.position.y) / t.size.y, 0.0, 1.0)
	set_throttle(THR_MIN + f * (1.0 - THR_MIN))

func set_action(text: String) -> void:
	action_btn.visible = text != ""
	action_btn.text = text

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var e := make_input_local(event) as InputEventScreenTouch
		var p := e.position
		if e.pressed:
			if p.y < 64.0:
				return
			if action_btn.visible and action_btn.get_global_rect().grow(6).has_point(p):
				return
			var rc := roll_centers()
			if thr_rect().grow(16).has_point(p):
				_thr_idx = e.index
				_throttle_from(p)
			elif p.distance_to(fire_center()) < 54.0:
				_fire_idx = e.index
				firing = true
			elif p.distance_to(target_center()) < 30.0:
				target_pressed.emit()
			elif p.distance_to(rc[0]) < 30.0:
				_roll_idx = e.index; _roll_val = 1.0
			elif p.distance_to(rc[1]) < 30.0:
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
			if e.index == _fire_idx:
				_fire_idx = -1
				firing = false
	elif event is InputEventScreenDrag:
		var e := make_input_local(event) as InputEventScreenDrag
		if e.index == _stick_idx:
			var d := e.position - _stick_origin
			if d.length() > STICK_R:
				d = d.normalized() * STICK_R
			stick = d / STICK_R
		elif e.index == _thr_idx:
			_throttle_from(e.position)
	elif event is InputEventKey and not event.echo:
		if event.physical_keycode == KEY_SPACE:
			firing = event.pressed
		elif event.physical_keycode == KEY_T and event.pressed:
			target_pressed.emit()
		elif event.physical_keycode == KEY_G and event.pressed and action_btn.visible:
			action_pressed.emit()
	roll = _roll_val

func release_all() -> void:
	_stick_idx = -1; _thr_idx = -1; _roll_idx = -1; _roll_val = 0.0; _fire_idx = -1
	stick = Vector2.ZERO
	roll = 0.0
	firing = false

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

func flash(strength := 0.45) -> void:
	flash_rect.color.a = maxf(flash_rect.color.a, strength)
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(60)

func _process(delta: float) -> void:
	if flash_rect.color.a > 0.0:
		flash_rect.color.a = maxf(0.0, flash_rect.color.a - delta * 1.2)
	if banner.visible and banner_until != INF and Time.get_ticks_msec() / 1000.0 > banner_until:
		hide_banner()
	hostile_warn = maxf(0.0, hostile_warn - delta)
	queue_redraw()

# ------------------------------------------------------------------ Zeichnen
func _bracket(c: Vector2, r: float, col: Color, w := 2.0) -> void:
	var l := r * 0.45
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var p := c + Vector2(sx * r, sy * r)
			draw_line(p, p - Vector2(sx * l, 0), col, w, true)
			draw_line(p, p - Vector2(0, sy * l), col, w, true)

func _draw() -> void:
	var font := K.F_MONO
	var c := size * 0.5
	var am := Color(K.AMBER, 0.75)
	for d in [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]:
		draw_line(c + d * 5.0, c + d * 13.0, am, 1.6, true)
	draw_circle(c, 1.6, K.AMBER)
	if pro_vis:
		draw_circle(pro_pos, 6.0, K.OK, false, 1.8, true)
		for d in [Vector2(0, -1), Vector2(-1, 0), Vector2(1, 0)]:
			draw_line(pro_pos + d * 6.0, pro_pos + d * 12.0, K.OK, 1.8, true)
	for m in markers:
		var p: Vector2 = m.pos
		var kind: String = m.kind
		var edge: bool = m.edge
		match kind:
			"nav", "wreck":
				var col := K.ICE if kind == "nav" else Color(1.0, 0.55, 0.2)
				if edge:
					col = K.AMBER if kind == "nav" else col
				var pts := PackedVector2Array([p + Vector2(0, -15), p + Vector2(15, 0), p + Vector2(0, 15), p + Vector2(-15, 0), p + Vector2(0, -15)])
				draw_polyline(pts, col, 2.0, true)
				if kind == "wreck":
					draw_line(p + Vector2(-6, -6), p + Vector2(6, 6), col, 2.0, true)
					draw_line(p + Vector2(-6, 6), p + Vector2(6, -6), col, 2.0, true)
				var txt: String = m.text
				var tx := p + Vector2(22, 5)
				if tx.x > size.x - 250:
					tx.x = p.x - 22 - font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
				draw_string(font, tx, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
			"bay":
				draw_circle(p, 9.0, K.OK, false, 2.0, true)
				draw_string(K.F_SEMI, p + Vector2(14, 4), "BUCHT", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, K.OK)
			"hostile":
				var col := K.DANGER
				if edge:
					var dir := (p - c).normalized()
					var tip := p
					var side := Vector2(-dir.y, dir.x)
					draw_colored_polygon(PackedVector2Array([tip, tip - dir * 14 + side * 7, tip - dir * 14 - side * 7]), Color(col, 0.9 if m.sel else 0.55))
				else:
					var r := 16.0 if m.sel else 10.0
					_bracket(p, r, col, 2.2 if m.sel else 1.5)
					if m.sel:
						var bw := 44.0
						var y := p.y + r + 6
						draw_rect(Rect2(p.x - bw / 2, y, bw, 3), Color(1, 1, 1, 0.15))
						draw_rect(Rect2(p.x - bw / 2, y, bw * float(m.sh), 3), Color(0.5, 0.8, 1.0))
						draw_rect(Rect2(p.x - bw / 2, y + 5, bw, 3), Color(1, 1, 1, 0.15))
						draw_rect(Rect2(p.x - bw / 2, y + 5, bw * float(m.hp), 3), K.DANGER)
						draw_string(font, Vector2(p.x - 60, y + 22), m.text, HORIZONTAL_ALIGNMENT_CENTER, 120, 11, col)
			"trader":
				if not edge:
					draw_circle(p, 3.0, Color(0.7, 0.75, 0.8, 0.7))
	if lead_vis:
		draw_circle(lead_pos, 7.0, K.DANGER, false, 1.6, true)
		draw_line(lead_pos + Vector2(-4, 0), lead_pos + Vector2(4, 0), K.DANGER, 1.4, true)
		draw_line(lead_pos + Vector2(0, -4), lead_pos + Vector2(0, 4), K.DANGER, 1.4, true)
	if hostile_warn > 0.0 and fmod(hostile_warn, 0.6) > 0.25:
		draw_string(K.F_BOLD, Vector2(0, 122), "FEINDKONTAKT", HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, K.DANGER)
	# Joystick
	if _stick_idx >= 0:
		draw_circle(_stick_origin, 70.0, Color(K.AMBER, 0.35), false, 1.5, true)
		var kp := _stick_origin + stick * STICK_R
		draw_circle(kp, 27.0, Color(K.AMBER, 0.22), true, -1.0, true)
		draw_circle(kp, 27.0, K.AMBER, false, 2.0, true)
	elif _hint:
		var hc := Vector2(150, size.y - 95)
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
	# Feuer
	var fc := fire_center()
	draw_circle(fc, 46.0, Color(K.DANGER, 0.3) if firing else Color(0.08, 0.03, 0.03, 0.75), true, -1.0, true)
	draw_circle(fc, 46.0, Color(K.DANGER, 0.8), false, 2.0, true)
	draw_circle(fc, 34.0, Color(K.DANGER, 0.35), false, 1.0, true)
	draw_string(K.F_BOLD, fc + Vector2(-46, 6), "FEUER", HORIZONTAL_ALIGNMENT_CENTER, 92, 15, K.DANGER)
	# Ziel wechseln
	var tc := target_center()
	draw_circle(tc, 24.0, K.PANEL, true, -1.0, true)
	draw_circle(tc, 24.0, Color(K.DANGER, 0.5), false, 1.5, true)
	_bracket(tc, 9.0, K.DANGER, 1.6)
	draw_string(K.F_SEMI, tc + Vector2(-30, 38), "ZIEL", HORIZONTAL_ALIGNMENT_CENTER, 60, 10, K.MUTED)
	# Rolltasten
	var rc := roll_centers()
	for i in 2:
		var act := _roll_idx >= 0 and ((_roll_val > 0.0) == (i == 0))
		draw_circle(rc[i], 24.0, Color(K.AMBER, 0.25) if act else K.PANEL, true, -1.0, true)
		draw_circle(rc[i], 24.0, K.LINE, false, 1.0, true)
		var a0 := -2.6 if i == 0 else -0.5
		var a1 := 2.0 if i == 0 else 4.1
		draw_arc(rc[i], 9.0, a0, a1, 20, K.AMBER, 2.0, true)
		var ta := a0 if i == 0 else a1
		draw_circle(rc[i] + Vector2(cos(ta), sin(ta)) * 9.0, 2.6, K.AMBER)

class_name WalkHud
extends Control
## Oberfläche beim Laufen: Bewegen (links), Umsehen (rechts ziehen), Interaktion.

signal interact_pressed
signal menu_pressed
signal quick_undock

const K = preload("res://scripts/ui_kit.gd")
const STICK_R := 60.0

var stick := Vector2.ZERO
var look := Vector2.ZERO
var _stick_idx := -1
var _stick_origin := Vector2.ZERO
var _look_idx := -1
var _look_last := Vector2.ZERO
var _mouse_look := false

var loc_lbl: Label
var sub_lbl: Label
var credits_lbl: Label
var act_btn: Button
var prompt: Label
var undock_btn: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := K.card("Hud")
	box.position = Vector2(10, 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var v := K.vbox(0)
	box.add_child(v)
	var r := K.hbox(16)
	loc_lbl = K.lbl("Station", 15, K.FG, K.F_BOLD)
	credits_lbl = K.lbl("0 cr", 15, K.AMBER, K.F_MONO)
	r.add_child(loc_lbl)
	r.add_child(K.spacer())
	r.add_child(credits_lbl)
	v.add_child(r)
	sub_lbl = K.caps("Sol-7")
	v.add_child(sub_lbl)
	var tr := K.hbox(6)
	tr.anchor_left = 1.0
	tr.anchor_right = 1.0
	tr.offset_left = -10
	tr.offset_right = -10
	tr.offset_top = 10
	tr.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(tr)
	undock_btn = K.btn("Abdocken", func(): quick_undock.emit(), true)
	tr.add_child(undock_btn)
	tr.add_child(K.btn("Menü", func(): menu_pressed.emit()))
	prompt = K.lbl("", 14, K.FG, K.F_SEMI)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt.grow_vertical = Control.GROW_DIRECTION_BEGIN
	prompt.offset_bottom = -22
	prompt.add_theme_stylebox_override("normal", UIKit.box_style(K.PANEL, K.LINE, 1, 4, Vector2(14, 7)))
	prompt.visible = false
	add_child(prompt)
	act_btn = K.btn("Benutzen", func(): interact_pressed.emit(), true)
	act_btn.custom_minimum_size = Vector2(150, 64)
	act_btn.add_theme_font_size_override("font_size", 17)
	act_btn.anchor_left = 1.0
	act_btn.anchor_right = 1.0
	act_btn.anchor_top = 1.0
	act_btn.anchor_bottom = 1.0
	act_btn.offset_left = -170
	act_btn.offset_right = -20
	act_btn.offset_top = -150
	act_btn.offset_bottom = -86
	act_btn.visible = false
	add_child(act_btn)

func set_prompt(text: String, button: String) -> void:
	prompt.visible = text != ""
	prompt.text = text
	act_btn.visible = text != ""
	act_btn.text = button

func release_all() -> void:
	_stick_idx = -1
	_look_idx = -1
	stick = Vector2.ZERO

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var e := make_input_local(event) as InputEventScreenTouch
		var p := e.position
		if e.pressed:
			if p.y < 64.0:
				return
			if act_btn.visible and act_btn.get_global_rect().grow(8).has_point(p):
				return
			if p.x < size.x * 0.45 and _stick_idx < 0:
				_stick_idx = e.index
				_stick_origin = p
				stick = Vector2.ZERO
			elif _look_idx < 0:
				_look_idx = e.index
				_look_last = p
		else:
			if e.index == _stick_idx:
				_stick_idx = -1
				stick = Vector2.ZERO
			if e.index == _look_idx:
				_look_idx = -1
	elif event is InputEventScreenDrag:
		var e := make_input_local(event) as InputEventScreenDrag
		if e.index == _stick_idx:
			var d := e.position - _stick_origin
			if d.length() > STICK_R:
				d = d.normalized() * STICK_R
			stick = d / STICK_R
		elif e.index == _look_idx:
			look += e.position - _look_last
			_look_last = e.position
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E:
		if act_btn.visible:
			interact_pressed.emit()

func take_look() -> Vector2:
	var l := look
	look = Vector2.ZERO
	return l

func _process(_d: float) -> void:
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	draw_circle(c, 2.0, Color(1, 1, 1, 0.6))
	if _stick_idx >= 0:
		draw_circle(_stick_origin, 70.0, Color(K.AMBER, 0.35), false, 1.5, true)
		var kp := _stick_origin + stick * STICK_R
		draw_circle(kp, 27.0, Color(K.AMBER, 0.22), true, -1.0, true)
		draw_circle(kp, 27.0, K.AMBER, false, 2.0, true)
	else:
		var hc := Vector2(90, size.y - 90)
		draw_arc(hc, 55.0, 0, TAU, 48, Color(K.AMBER, 0.25), 1.5, true)
		draw_string(K.F_SEMI, hc + Vector2(-25, 0), "GEHEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, K.MUTED)
		draw_string(K.F_SEMI, Vector2(size.x * 0.62, size.y - 40), "RECHTS ZIEHEN: UMSEHEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(K.MUTED, 0.7))

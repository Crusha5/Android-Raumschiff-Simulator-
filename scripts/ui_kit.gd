class_name UIKit
extends RefCounted
## Farben, Schriften, Theme und kleine Bausteine für die Oberfläche.

const AMBER := Color(1.0, 0.71, 0.28)
const AMBER_DIM := Color(0.61, 0.42, 0.15)
const ICE := Color(0.62, 0.83, 1.0)
const OK := Color(0.5, 0.88, 0.54)
const DANGER := Color(1.0, 0.35, 0.31)
const FG := Color(0.93, 0.9, 0.83)
const MUTED := Color(0.58, 0.57, 0.53)
const PANEL := Color(0.03, 0.045, 0.08, 0.86)
const LINE := Color(1.0, 0.71, 0.28, 0.24)

const F_REG := preload("res://fonts/ChakraPetch-Regular.ttf")
const F_SEMI := preload("res://fonts/ChakraPetch-SemiBold.ttf")
const F_BOLD := preload("res://fonts/ChakraPetch-Bold.ttf")
const F_MONO := preload("res://fonts/IBMPlexMono-Medium.ttf")

static func box_style(bg: Color, border: Color, bw := 1, radius := 4, pad := Vector2(12, 8)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad.x
	s.content_margin_right = pad.x
	s.content_margin_top = pad.y
	s.content_margin_bottom = pad.y
	s.anti_aliasing = true
	return s

static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = F_SEMI
	t.default_font_size = 15
	var normal := box_style(PANEL, LINE)
	var hover := box_style(Color(0.08, 0.08, 0.1, 0.9), Color(1.0, 0.71, 0.28, 0.5))
	var pressed := box_style(Color(1.0, 0.71, 0.28, 0.25), AMBER)
	var disabled := box_style(Color(0.03, 0.045, 0.08, 0.5), Color(1, 1, 1, 0.07))
	for state in [["normal", normal], ["hover", hover], ["pressed", pressed], ["disabled", disabled], ["hover_pressed", pressed]]:
		t.set_stylebox(state[0], "Button", state[1])
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", AMBER)
	t.set_color("font_hover_color", "Button", AMBER)
	t.set_color("font_pressed_color", "Button", FG)
	t.set_color("font_hover_pressed_color", "Button", FG)
	t.set_color("font_disabled_color", "Button", Color(0.58, 0.57, 0.53, 0.6))
	t.set_font_size("font_size", "Button", 14)
	# Hervorgehobener Knopf
	t.set_type_variation("BtnOn", "Button")
	var on := box_style(Color(1.0, 0.71, 0.28, 0.16), AMBER)
	t.set_stylebox("normal", "BtnOn", on)
	t.set_stylebox("hover", "BtnOn", on)
	t.set_stylebox("pressed", "BtnOn", box_style(Color(1.0, 0.71, 0.28, 0.32), AMBER))
	t.set_stylebox("disabled", "BtnOn", box_style(Color(1.0, 0.71, 0.28, 0.05), Color(1.0, 0.71, 0.28, 0.2)))
	t.set_color("font_disabled_color", "BtnOn", Color(1.0, 0.71, 0.28, 0.4))
	# Karten
	t.set_type_variation("Card", "PanelContainer")
	t.set_stylebox("panel", "Card", box_style(Color(1, 1, 1, 0.025), Color(1, 1, 1, 0.09), 1, 4, Vector2(12, 10)))
	t.set_type_variation("CardEq", "PanelContainer")
	t.set_stylebox("panel", "CardEq", box_style(Color(0.5, 0.88, 0.54, 0.06), Color(0.5, 0.88, 0.54, 0.55), 1, 4, Vector2(12, 10)))
	t.set_type_variation("CardSel", "PanelContainer")
	t.set_stylebox("panel", "CardSel", box_style(Color(0.62, 0.83, 1.0, 0.08), ICE, 1, 4, Vector2(12, 10)))
	t.set_type_variation("CardGoal", "PanelContainer")
	t.set_stylebox("panel", "CardGoal", box_style(Color(1.0, 0.71, 0.28, 0.05), LINE, 1, 4, Vector2(12, 10)))
	t.set_type_variation("CardGood", "PanelContainer")
	t.set_stylebox("panel", "CardGood", box_style(Color(0.5, 0.88, 0.54, 0.08), Color(0.5, 0.88, 0.54, 0.0), 0, 2, Vector2(12, 10)))
	t.set_type_variation("CardBad", "PanelContainer")
	t.set_stylebox("panel", "CardBad", box_style(Color(1.0, 0.35, 0.31, 0.09), Color(1, 0.35, 0.31, 0.0), 0, 2, Vector2(12, 10)))
	t.set_stylebox("panel", "PanelContainer", box_style(Color(0.035, 0.05, 0.085, 0.94), LINE, 1, 6, Vector2(16, 14)))
	t.set_type_variation("Hud", "PanelContainer")
	t.set_stylebox("panel", "Hud", box_style(PANEL, LINE, 1, 4, Vector2(10, 7)))
	t.set_color("font_color", "Label", FG)
	# Eingabefeld
	t.set_stylebox("normal", "LineEdit", box_style(Color(1, 1, 1, 0.05), LINE, 1, 4, Vector2(10, 8)))
	t.set_stylebox("focus", "LineEdit", box_style(Color(1, 1, 1, 0.07), ICE, 1, 4, Vector2(10, 8)))
	t.set_color("font_color", "LineEdit", FG)
	t.set_font_size("font_size", "LineEdit", 16)
	# Scrollbalken
	var grab := box_style(Color(1.0, 0.71, 0.28, 0.35), Color(0, 0, 0, 0), 0, 3, Vector2(2, 2))
	var track := box_style(Color(1, 1, 1, 0.03), Color(0, 0, 0, 0), 0, 3, Vector2(2, 2))
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab)
	t.set_stylebox("scroll", "VScrollBar", track)
	return t

static func lbl(text: String, size := 14, color := FG, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font:
		l.add_theme_font_override("font", font)
	return l

static func caps(text: String, color := MUTED, size := 11) -> Label:
	var l := lbl(text.to_upper(), size, color, F_SEMI)
	return l

static func wrap(text: String, size := 13, color := MUTED) -> Label:
	var l := lbl(text, size, color, F_REG)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

static func btn(text: String, cb: Callable, on := false, disabled := false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	if on:
		b.theme_type_variation = "BtnOn"
	b.disabled = disabled
	b.custom_minimum_size = Vector2(0, 40)
	b.pressed.connect(func():
		if cb.is_valid() and TouchScroll.tap_ok():
			cb.call())
	return b

static func hbox(sep := 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func vbox(sep := 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func card(variation := "Card") -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = variation
	return p

static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c

## Einfacher Balken (0..1)
class Bar extends Control:
	var frac := 0.0
	var color := Color.WHITE
	var back := Color(1, 1, 1, 0.08)
	func _init(w := 90.0, h := 6.0) -> void:
		custom_minimum_size = Vector2(w, h)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func set_value(f: float, c: Color) -> void:
		if absf(f - frac) > 0.001 or c != color:
			frac = clampf(f, 0.0, 1.0)
			color = c
			queue_redraw()
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, back)
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * frac, size.y)), color)

## Vergleichsbalken: alter Wert grau, neuer Wert farbig
class StatBar extends Control:
	var a := 0.0
	var b := 0.0
	var cls := 0
	func _init() -> void:
		custom_minimum_size = Vector2(60, 6)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.07))
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * clampf(a, 0, 1), size.y)), Color(1, 1, 1, 0.22))
		var c := UIKit.AMBER
		if cls > 0:
			c = UIKit.OK
		elif cls < 0:
			c = Color(1.0, 0.35, 0.31, 0.75)
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * clampf(b, 0, 1), size.y)), Color(c, 0.85))

## Farbtupfer zum Antippen
class Swatch extends Button:
	var col := Color.WHITE
	var on := false
	var locked := false
	func _init(c: Color, is_on: bool, is_locked: bool) -> void:
		col = c
		on = is_on
		locked = is_locked
		custom_minimum_size = Vector2(38, 38)
		focus_mode = Control.FOCUS_NONE
		flat = true
		disabled = is_locked
	func _draw() -> void:
		var ctr := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 3.0
		if on:
			draw_circle(ctr, r + 2.5, UIKit.AMBER, false, 2.0, true)
		draw_circle(ctr, r - 1.5, Color(col, 0.25 if locked else 1.0), true, -1.0, true)
		draw_circle(ctr, r - 1.5, Color(1, 1, 1, 0.18), false, 1.5, true)

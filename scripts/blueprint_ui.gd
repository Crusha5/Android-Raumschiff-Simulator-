class_name BlueprintUI
extends Control
## Blaupausen-Editor: Schiff Modul für Modul auf einem Raster entwerfen, prüfen und bauen.
## Links der Plan (Bug zeigt nach rechts) oder die 3D-Ansicht, rechts Module, Werte und Pläne.

const K = preload("res://scripts/ui_kit.gd")
const SIDE_FRAC := 0.42
const PAPER := Color(0.04, 0.13, 0.24)
const PAPER2 := Color(0.06, 0.19, 0.33)
const INK := Color(0.72, 0.86, 1.0)

var main: Node
var edit: Dictionary = {"mods": []}
var brush := "h1"
var tool := "place"
var mirror := true
var undo: Array = []
var sel := -1
var tab := "mods"
var cat := "hull"
var view3d := false
var msg := ""
var msg_col := INK
var design_name := ""
var check: Dictionary = {}
var st: Dictionary = {}
var plan: Dictionary = {}

var canvas: Canvas
var side: PanelContainer
var scroll: ScrollContainer
var content: VBoxContainer
var credits_lbl: Label
var tab_btns := {}
var build_btn: Button
var reason_lbl: Label
var tb := {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas = Canvas.new()
	canvas.ui = self
	add_child(canvas)
	canvas.anchor_right = 1.0 - SIDE_FRAC
	canvas.anchor_bottom = 1.0
	canvas.offset_right = -6
	# Werkzeugleiste über dem Plan
	var bar := K.hbox(6)
	bar.position = Vector2(8, 8)
	add_child(bar)
	tb.view = K.btn("3D", func(): _toggle_view())
	tb.mirror = K.btn("Spiegeln", func(): mirror = not mirror; _sync_tools())
	tb.erase = K.btn("Entfernen", func(): tool = "erase" if tool == "place" else "place"; _sync_tools())
	tb.undo = K.btn("↶", func(): _undo())
	tb.clear = K.btn("Leeren", func(): _clear())
	for k in ["view", "mirror", "erase", "undo", "clear"]:
		tb[k].custom_minimum_size = Vector2(0, 36)
		bar.add_child(tb[k])
	tb.undo.custom_minimum_size = Vector2(44, 36)
	# Seitenleiste
	side = PanelContainer.new()
	side.anchor_left = 1.0 - SIDE_FRAC
	side.anchor_right = 1.0
	side.anchor_bottom = 1.0
	side.offset_top = 8
	side.offset_bottom = -8
	side.offset_right = -8
	add_child(side)
	var v := K.vbox(8)
	side.add_child(v)
	var head := K.hbox(8)
	var hl := K.vbox(0)
	hl.add_child(K.caps("Konstruktion"))
	hl.add_child(K.lbl("Blaupause", 19, K.FG, K.F_BOLD))
	head.add_child(hl)
	head.add_child(K.spacer())
	credits_lbl = K.lbl("", 16, K.AMBER, K.F_MONO)
	head.add_child(credits_lbl)
	v.add_child(head)
	var tabs := K.hbox(6)
	for t in [["mods", "Module"], ["stats", "Werte"], ["plans", "Pläne"]]:
		var id: String = t[0]
		var b := K.btn(t[1], func(): tab = id; _refresh_side(true))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 34)
		tab_btns[id] = b
		tabs.add_child(b)
	v.add_child(tabs)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	TouchScroll.attach(scroll)
	content = K.vbox(8)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	reason_lbl = K.wrap("", 11, K.MUTED)
	v.add_child(reason_lbl)
	var br := K.hbox(6)
	var back := K.btn("Zurück", func(): main.close_panel())
	back.custom_minimum_size = Vector2(0, 44)
	br.add_child(back)
	build_btn = K.btn("Bauen", func(): _build(), true)
	build_btn.custom_minimum_size = Vector2(0, 44)
	build_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	build_btn.add_theme_font_size_override("font_size", 16)
	br.add_child(build_btn)
	v.add_child(br)
	visible = false

func open() -> void:
	edit = Game.copy_bp(Game.s.bp)
	undo = []
	sel = -1
	tool = "place"
	view3d = false
	design_name = String(Game.s.name)
	msg = "Tippe ein Modul rechts an und setze es auf den Plan. Ziehen setzt mehrere."
	msg_col = INK
	visible = true
	scroll.scroll_vertical = 0
	_sync_tools()
	_changed(false)

func _sync_tools() -> void:
	tb.view.text = "Plan" if view3d else "3D"
	tb.view.theme_type_variation = "BtnOn" if view3d else ""
	tb.mirror.theme_type_variation = "BtnOn" if mirror else ""
	tb.erase.theme_type_variation = "BtnOn" if tool == "erase" else ""
	tb.undo.disabled = undo.is_empty()
	for k in ["mirror", "erase", "undo", "clear"]:
		tb[k].visible = not view3d
	canvas.visible = not view3d
	canvas.queue_redraw()

func _toggle_view() -> void:
	view3d = not view3d
	if view3d:
		main.preview_bp = Game.copy_bp(edit)
		main._rebuild_hangar_ship()
	_sync_tools()

# ---------------------------------------------------------------- Bearbeiten
func _push_undo() -> void:
	undo.append(Game.copy_bp(edit))
	if undo.size() > 40:
		undo.pop_front()

func _undo() -> void:
	if undo.is_empty():
		return
	edit = undo.pop_back()
	sel = -1
	_changed()

func _clear() -> void:
	_push_undo()
	var keep := []
	for m in edit.mods:
		if Game.mod(m[0]).cat == "cockpit":
			keep.append(m)
			break
	edit.mods = keep
	sel = -1
	msg = "Plan geleert. Das Cockpit bleibt stehen."
	msg_col = INK
	_changed()

func load_bp(bp: Dictionary, name: String) -> void:
	_push_undo()
	edit = Game.copy_bp(bp)
	design_name = name
	sel = -1
	msg = "«%s» geladen." % name
	msg_col = INK
	_changed()

func _anchor_for(id: String, c: Vector2i) -> Vector2i:
	var d := Game.mod(id)
	return Vector2i(c.x - int((int(d.sz[0]) - 1) / 2), c.y - int((int(d.sz[1]) - 1) / 2))

func _mirror_anchor(id: String, a: Vector2i) -> Vector2i:
	return Vector2i(-a.x - (int(Game.mod(id).sz[0]) - 1), a.y)

func place(c: Vector2i, stroke := false) -> bool:
	var cells := Game.bp_cells(edit)
	if cells.has(c):
		if not stroke:
			sel = cells[c]
			var m: Array = edit.mods[sel]
			var why: String = check.bad.get(sel, "")
			msg = String(Game.mod(m[0]).n) + (" · " + why if why != "" else " · in Ordnung")
			msg_col = K.DANGER if why != "" else INK
			canvas.queue_redraw()
		return false
	var d := Game.mod(brush)
	if stroke and (int(d.sz[0]) > 1 or int(d.sz[1]) > 1 or d.cat == "cockpit"):
		return false
	var a := _anchor_for(brush, c)
	if d.cat == "cockpit":
		for i in range(edit.mods.size() - 1, -1, -1):
			if Game.mod(edit.mods[i][0]).cat == "cockpit":
				edit.mods.remove_at(i)
		cells = Game.bp_cells(edit)
	if not Game.can_place(edit, brush, a.x, a.y, cells):
		msg = "%s passt hier nicht hin (%d×%d Felder)." % [d.n, int(d.sz[0]), int(d.sz[1])]
		msg_col = K.AMBER
		canvas.queue_redraw()
		return false
	edit.mods.append([brush, a.x, a.y])
	if mirror and d.cat != "cockpit":
		var ma := _mirror_anchor(brush, a)
		if ma != a and Game.can_place(edit, brush, ma.x, ma.y):
			edit.mods.append([brush, ma.x, ma.y])
	sel = -1
	msg = ""
	return true

func erase(c: Vector2i) -> bool:
	var cells := Game.bp_cells(edit)
	if not cells.has(c):
		return false
	var i: int = cells[c]
	var m: Array = edit.mods[i]
	if Game.mod(m[0]).cat == "cockpit":
		msg = "Das Cockpit lässt sich nur ersetzen, nicht entfernen."
		msg_col = K.AMBER
		canvas.queue_redraw()
		return false
	edit.mods.remove_at(i)
	if mirror:
		var ma := _mirror_anchor(m[0], Vector2i(m[1], m[2]))
		for j in edit.mods.size():
			var n: Array = edit.mods[j]
			if n[0] == m[0] and n[1] == ma.x and n[2] == ma.y:
				edit.mods.remove_at(j)
				break
	sel = -1
	msg = ""
	return true

func cell_action(c: Vector2i, first: bool) -> void:
	if not Game.in_grid(c):
		return
	if first:
		_push_undo()
	var ok := erase(c) if tool == "erase" else place(c, not first)
	if ok:
		_changed()
	elif first:
		undo.pop_back()
		_sync_tools()

func _changed(side_reset := false) -> void:
	check = Game.validate(edit)
	st = Game.bp_stats(edit, Game.s.tune)
	plan = Game.build_plan(edit, main.shop_tier())
	if view3d:
		main.preview_bp = Game.copy_bp(edit)
		main._rebuild_hangar_ship()
	_sync_tools()
	_refresh_side(side_reset)

func _build() -> void:
	var why: String = main.build_block(edit, plan)
	if why != "":
		msg = why
		msg_col = K.DANGER
		canvas.queue_redraw()
		return
	var total := int(plan.total)
	if main.build_blueprint(edit):
		msg = "Umbau fertig%s. Dein Schiff steht im Hangar." % ((" · −%s cr" % Game.fmt(total)) if total > 0 else "")
		msg_col = K.OK
		edit = Game.copy_bp(Game.s.bp)
		undo = []
		_changed()

# ---------------------------------------------------------------- Seitenleiste
func _refresh_side(reset_scroll := false) -> void:
	if not is_instance_valid(content):
		return
	credits_lbl.text = Game.fmt(Game.s.credits) + " cr"
	for k in tab_btns:
		tab_btns[k].theme_type_variation = "BtnOn" if k == tab else ""
	var sv := 0 if reset_scroll else scroll.scroll_vertical
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()
	match tab:
		"mods": _mods_tab()
		"stats": _stats_tab()
		"plans": _plans_tab()
	var why: String = main.build_block(edit, plan)
	var total := int(plan.total)
	build_btn.text = ("Bauen · %s cr" % Game.fmt(total)) if total > 0 else "Bauen"
	build_btn.disabled = why != ""
	if why == "Keine Änderung":
		reason_lbl.text = "Entwurf entspricht deinem Schiff."
		reason_lbl.add_theme_color_override("font_color", K.MUTED)
	elif why != "":
		reason_lbl.text = why
		reason_lbl.add_theme_color_override("font_color", K.DANGER)
	else:
		var parts := []
		if int(plan.cost) > 0:
			parts.append("Module %s cr" % Game.fmt(plan.cost))
		parts.append("Montage %s cr" % Game.fmt(plan.fee))
		reason_lbl.text = "Bereit · " + " · ".join(parts)
		reason_lbl.add_theme_color_override("font_color", K.OK)
	canvas.queue_redraw()
	await get_tree().process_frame
	scroll.scroll_vertical = sv

func _mods_tab() -> void:
	var cs := ScrollContainer.new()
	cs.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cs.custom_minimum_size = Vector2(0, 40)
	var row := K.hbox(5)
	cs.add_child(row)
	TouchScroll.attach(cs, true)
	for c in Game.CATS:
		var id: String = c[0]
		var b := K.btn(c[1], func(): cat = id; _refresh_side(true), id == cat)
		b.custom_minimum_size = Vector2(0, 34)
		b.add_theme_color_override("font_color", Color.html(c[2]))
		row.add_child(b)
	content.add_child(cs)
	var rk := Game.rank()
	var counts := Game.bp_counts(edit)
	var ship := Game.bp_counts(Game.s.bp)
	var tier: int = main.shop_tier()
	for id in Game.MODULES:
		var d: Dictionary = Game.MODULES[id]
		if d.cat != cat:
			continue
		var c := K.card("CardSel" if id == brush else "Card")
		var locked := int(d.rank) > rk
		if locked:
			c.modulate = Color(1, 1, 1, 0.6)
		var v := K.vbox(3)
		c.add_child(v)
		var r1 := K.hbox(6)
		r1.add_child(K.lbl(d.n, 14, K.FG))
		r1.add_child(K.lbl("%d×%d" % [int(d.sz[0]), int(d.sz[1])], 11, K.MUTED, K.F_MONO))
		r1.add_child(K.spacer())
		var have := int(ship.get(id, 0)) + Game.inv_count(id)
		var price_txt := ""
		var pc := K.AMBER
		if int(d.price) == 0:
			price_txt = "gratis"
			pc = K.OK
		elif locked:
			price_txt = "ab " + Game.rank_name(int(d.rank))
			pc = K.MUTED
		else:
			price_txt = Game.fmt(d.price) + " cr"
		r1.add_child(K.lbl(price_txt, 12, pc, K.F_MONO))
		v.add_child(r1)
		var meta := _meta(d)
		var used := int(counts.get(id, 0))
		var tail := []
		if used > 0:
			tail.append("im Plan %d" % used)
		if int(d.price) > 0:
			tail.append("vorhanden %d" % have)
			if int(d.tier) > tier and have < used:
				tail.append("nicht hier erhältlich")
		if not tail.is_empty():
			meta += " · " + " · ".join(tail)
		v.add_child(K.wrap(meta, 11))
		var pid: String = id
		c.mouse_filter = Control.MOUSE_FILTER_PASS
		c.gui_input.connect(func(ev: InputEvent): _card_tap(ev, pid))
		content.add_child(c)
	content.add_child(K.wrap(_cat_hint(cat), 11))

var _tap_start := Vector2.ZERO
func _card_tap(ev: InputEvent, id: String) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_tap_start = ev.global_position
		elif ev.global_position.distance_to(_tap_start) < 14.0 and TouchScroll.tap_ok():
			select_brush(id)

func select_brush(id: String) -> void:
	brush = id
	tool = "place"
	var d := Game.mod(id)
	msg = "%s gewählt · Feld antippen%s" % [d.n, " oder ziehen" if int(d.sz[0]) == 1 and int(d.sz[1]) == 1 and d.cat != "cockpit" else ""]
	msg_col = INK
	_sync_tools()
	_refresh_side()

func _cat_hint(c: String) -> String:
	match c:
		"cockpit": return "Genau ein Cockpit. Ein neues ersetzt das alte."
		"engine": return "Hinter Triebwerken muss frei bleiben – der Abgasstrahl braucht Platz."
		"weapon": return "Vor Waffen muss frei bleiben. Gleiche Waffen feuern gemeinsam."
		"power": return "Jedes Modul braucht Leistung. Überschuss lädt die Waffenenergie schneller."
		"wing": return "Flügel an den Seiten, in der Mitte wird daraus ein Leitwerk."
		"cargo": return "Mehr Frachtraum heißt größere Aufträge – aber auch mehr Masse."
		"rcs": return "Düsen weit außen drehen das Schiff am besten."
	return "Alle Module müssen mit dem Cockpit verbunden sein."

static func _meta(d: Dictionary) -> String:
	var p := []
	match String(d.cat):
		"cockpit": p.append("%d HP · %d Energie · +%d Leistung" % [int(d.hp), int(d.energy), int(d.pwr)])
		"hull": p.append("%d HP" % int(d.hp))
		"engine": p.append("%s kN · %d m/s" % [Game.fmt(d.thrust), int(d.vmax)])
		"rcs": p.append("Drehmoment %s · Seitenschub %d" % [str(d.torque).replace(".", ","), int(d.strafe)])
		"weapon": p.append("%d dps · %s m · %s Energie" % [roundi(float(d.dmg) * float(d.rate)), Game.fmt(d.range), str(d.energy).replace(".", ",")])
		"shield": p.append("%d Schild · %d/s" % [int(d.cap), int(d.regen)])
		"power": p.append("+%d Leistung · +%d Energie" % [int(d.pwr), int(d.energy)])
		"cargo": p.append("%d t Fracht" % int(d.cap))
		"armor": p.append("+%d HP · −%s %% Schaden" % [int(d.hp), str(float(d.red) * 100.0).replace(".", ",")])
		"wing": p.append("+%s Wendigkeit · %d HP" % [str(d.torque).replace(".", ","), int(d.hp)])
		"util": p.append(d.d)
	if int(d.pwr) < 0:
		p.append("%d Leistung" % int(d.pwr))
	p.append("%s t" % str(d.mass).replace(".", ","))
	return " · ".join(p)

func _stats_tab() -> void:
	content.add_child(K.caps("Entwurf gegen dein Schiff"))
	content.add_child(main.station_ui._stats_box(main.S, st))
	# Energiebilanz
	var c := K.card()
	var v := K.vbox(4)
	c.add_child(v)
	var r := K.hbox(8)
	r.add_child(K.caps("Leistung"))
	r.add_child(K.spacer())
	var ok := int(st.pwr_gen) >= int(st.pwr_use)
	r.add_child(K.lbl("%d / %d" % [int(st.pwr_use), int(st.pwr_gen)], 13, K.OK if ok else K.DANGER, K.F_MONO))
	v.add_child(r)
	var bar := UIKit.Bar.new(100, 6)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.set_value(float(st.pwr_use) / maxf(1.0, float(st.pwr_gen)), K.OK if ok else K.DANGER)
	v.add_child(bar)
	v.add_child(K.wrap("Waffenenergie %d · lädt %d/s · Seitenschub ×%s" % [int(st.energy), int(st.energy_regen), String.num(float(st.strafe), 2).replace(".", ",")], 11))
	content.add_child(c)
	for e in check.errors:
		content.add_child(K.wrap("✕ " + e, 12, K.DANGER))
	for w in check.warns:
		content.add_child(K.wrap("! " + w, 12, K.AMBER))
	if check.errors.is_empty() and check.warns.is_empty():
		content.add_child(K.wrap("✓ Blaupause flugtauglich.", 12, K.OK))
	if not plan.missing.is_empty():
		content.add_child(K.caps("Fehlende Module (werden gekauft)"))
		for id in plan.missing:
			var d: Dictionary = Game.mod(id)
			var rr := K.hbox(8)
			rr.add_child(K.wrap("%d× %s" % [int(plan.missing[id]), d.n], 12, K.FG))
			rr.add_child(K.lbl(Game.fmt(int(plan.missing[id]) * int(d.price)) + " cr", 12, K.AMBER, K.F_MONO))
			content.add_child(rr)
	var spare := _freed()
	if not spare.is_empty():
		content.add_child(K.caps("Kommt ins Lager"))
		content.add_child(K.wrap(", ".join(spare), 12))

func _freed() -> Array:
	var out := []
	var now := Game.bp_counts(Game.s.bp)
	var nxt := Game.bp_counts(edit)
	for id in now:
		var n := int(now[id]) - int(nxt.get(id, 0))
		if n > 0 and int(Game.mod(id).price) > 0:
			out.append("%d× %s" % [n, Game.mod(id).n])
	return out

func _plans_tab() -> void:
	content.add_child(K.caps("Entwurf speichern"))
	var r := K.hbox(6)
	var le := LineEdit.new()
	le.text = design_name
	le.max_length = 22
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.text_changed.connect(func(t: String): design_name = t)
	r.add_child(le)
	r.add_child(K.btn("Speichern", func(): _save_design(), true))
	content.add_child(r)
	content.add_child(_plan_card("Aktuelles Schiff", "«%s» · %d Module" % [Game.s.name, Game.s.bp.mods.size()], Game.s.bp, -1))
	if not Game.s.designs.is_empty():
		content.add_child(K.caps("Deine Blaupausen"))
		for i in Game.s.designs.size():
			var d: Dictionary = Game.s.designs[i]
			content.add_child(_plan_card(d.n, "%d Module" % d.mods.size(), d, i))
	content.add_child(K.caps("Vorlagen der Werft"))
	for t in Game.TEMPLATES:
		content.add_child(_plan_card(t.n, t.d, Game.template_bp(t.id), -2))

func _plan_card(n: String, sub: String, bp: Dictionary, idx: int) -> Control:
	var c := K.card()
	var v := K.vbox(4)
	c.add_child(v)
	var r := K.hbox(6)
	var tl := K.vbox(0)
	tl.add_child(K.lbl(n, 14, K.FG))
	var sst := Game.bp_stats(Game.clean_bp(bp), Game.s.tune)
	tl.add_child(K.wrap("%s · %d t Fracht · %d dps · %d HP" % [sub, int(sst.cap), roundi(float(sst.dps)), roundi(float(sst.hp_max))], 11))
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(tl)
	var b := Game.clean_bp(bp)
	r.add_child(K.btn("Laden", func(): load_bp(b, n); tab = "mods"; _refresh_side(true)))
	if idx >= 0:
		r.add_child(K.btn("✕", func():
			Game.s.designs.remove_at(idx)
			Game.save_game()
			_refresh_side()))
	v.add_child(r)
	return c

func _save_design() -> void:
	var n := design_name.strip_edges()
	if n == "":
		n = "Entwurf %d" % (Game.s.designs.size() + 1)
	for i in Game.s.designs.size():
		if Game.s.designs[i].n == n:
			Game.s.designs.remove_at(i)
			break
	Game.s.designs.push_front({"n": n, "mods": Game.copy_bp(edit).mods})
	while Game.s.designs.size() > 12:
		Game.s.designs.pop_back()
	Game.save_game()
	msg = "Blaupause «%s» gespeichert." % n
	msg_col = K.OK
	_refresh_side()

# ---------------------------------------------------------------- Plan zeichnen
class Canvas extends Control:
	var ui: BlueprintUI
	var _down := false
	var _last := Vector2i(999, 999)
	var cell := 30.0
	var origin := Vector2.ZERO

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		clip_contents = true

	func _layout() -> void:
		var cols := Game.GRID_Z * 2 + 1
		var rows := Game.GRID_X * 2 + 1
		var top := 52.0
		var bottom := 46.0
		cell = floorf(minf((size.x - 20.0) / cols, (size.y - top - bottom) / rows))
		var gw := cell * cols
		var gh := cell * rows
		origin = Vector2((size.x - gw) * 0.5, top + (size.y - top - bottom - gh) * 0.5)

	## Rasterzelle → Rechteck. Bug (z negativ) zeigt nach rechts, Backbord (x negativ) nach oben.
	func cell_rect(c: Vector2i) -> Rect2:
		return Rect2(origin + Vector2((Game.GRID_Z - c.y) * cell, (c.x + Game.GRID_X) * cell), Vector2(cell, cell))

	func mod_rect(m: Array) -> Rect2:
		var d := Game.mod(m[0])
		var a := cell_rect(Vector2i(int(m[1]), int(m[2]) + int(d.sz[1]) - 1))
		return Rect2(a.position, Vector2(cell * int(d.sz[1]), cell * int(d.sz[0])))

	func pos_cell(p: Vector2) -> Vector2i:
		var q := (p - origin) / cell
		return Vector2i(int(floor(q.y)) - Game.GRID_X, Game.GRID_Z - int(floor(q.x)))

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				_down = true
				_last = pos_cell(ev.position)
				ui.cell_action(_last, true)
			else:
				_down = false
			accept_event()
		elif ev is InputEventMouseMotion and _down:
			var c := pos_cell(ev.position)
			if c != _last:
				_last = c
				ui.cell_action(c, false)
			accept_event()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void:
		_layout()
		draw_rect(Rect2(Vector2.ZERO, size), BlueprintUI.PAPER)
		var cols := Game.GRID_Z * 2 + 1
		var rows := Game.GRID_X * 2 + 1
		var grid := Rect2(origin, Vector2(cols, rows) * cell)
		draw_rect(grid, BlueprintUI.PAPER2)
		var ink := BlueprintUI.INK
		for i in cols + 1:
			var x := origin.x + i * cell
			draw_line(Vector2(x, grid.position.y), Vector2(x, grid.end.y), Color(ink, 0.12), 1.0)
		for j in rows + 1:
			var y := origin.y + j * cell
			draw_line(Vector2(grid.position.x, y), Vector2(grid.end.x, y), Color(ink, 0.12), 1.0)
		# Mittellinie
		var cy := origin.y + (Game.GRID_X + 0.5) * cell
		var xx := grid.position.x
		while xx < grid.end.x:
			draw_line(Vector2(xx, cy), Vector2(minf(xx + 8.0, grid.end.x), cy), Color(ink, 0.35), 1.0)
			xx += 14.0
		draw_rect(grid, Color(ink, 0.5), false, 1.5)
		var f := UIKit.F_SEMI
		draw_string(f, Vector2(grid.end.x - 46, grid.position.y - 6), "BUG ▶", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(ink, 0.8))
		draw_string(f, Vector2(grid.position.x, grid.position.y - 6), "◀ HECK", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(ink, 0.6))
		var bp: Dictionary = ui.edit
		var bad: Dictionary = ui.check.get("bad", {})
		# Abgasstrahl und Schussfeld
		for i in bp.mods.size():
			var m: Array = bp.mods[i]
			var d := Game.mod(m[0])
			var r := mod_rect(m)
			if d.cat == "engine":
				var col := Color(1, 0.35, 0.3, 0.5) if bad.has(i) else Color(1.0, 0.68, 0.35, 0.22)
				draw_rect(Rect2(Vector2(grid.position.x, r.position.y + cell * 0.25), Vector2(r.position.x - grid.position.x, r.size.y - cell * 0.5)), col)
			elif d.cat == "weapon":
				var col := Color(1, 0.35, 0.3, 0.55) if bad.has(i) else Color(1.0, 0.45, 0.4, 0.28)
				var y := r.get_center().y
				draw_line(Vector2(r.end.x, y), Vector2(grid.end.x, y), col, 2.0)
		# Module
		for i in bp.mods.size():
			var m: Array = bp.mods[i]
			var d := Game.mod(m[0])
			var r := mod_rect(m).grow(-2.0)
			var col := Game.cat_color(d.cat)
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(col.darkened(0.55), 0.92)
			sb.border_color = Color(1.0, 0.35, 0.3) if bad.has(i) else Color(col, 0.95)
			sb.set_border_width_all(3 if bad.has(i) or i == ui.sel else 1)
			if i == ui.sel:
				sb.border_color = Color.WHITE
			sb.set_corner_radius_all(4)
			draw_style_box(sb, r)
			_icon(d, m[0], r, col)
		# Statuszeile
		var info := ui.msg
		if info == "":
			var stt: Dictionary = ui.st
			info = "%d t · %d m/s² · %d m/s · Fracht %d t · %d dps · Leistung %d/%d" % [roundi(float(stt.dry)), roundi(float(stt.thrust) / maxf(1.0, float(stt.dry))), roundi(float(stt.vmax)), int(stt.cap), roundi(float(stt.dps)), int(stt.pwr_use), int(stt.pwr_gen)]
		draw_string(UIKit.F_REG, Vector2(grid.position.x, grid.end.y + 22), info, HORIZONTAL_ALIGNMENT_LEFT, size.x - grid.position.x - 10, 13, ui.msg_col if ui.msg != "" else Color(ink, 0.85))
		if ui.tool == "erase":
			draw_rect(grid, Color(1, 0.35, 0.3, 0.6), false, 2.5)

	## Kleines Symbol je Kategorie
	func _icon(d: Dictionary, id: String, r: Rect2, col: Color) -> void:
		var c := r.get_center()
		var s := minf(r.size.x, r.size.y)
		var lc := Color(col.lightened(0.3), 0.95)
		match String(d.cat):
			"cockpit":
				var pts := PackedVector2Array([Vector2(r.end.x - s * 0.15, c.y), Vector2(c.x - r.size.x * 0.2, r.position.y + s * 0.22), Vector2(c.x - r.size.x * 0.2, r.end.y - s * 0.22)])
				draw_colored_polygon(pts, Color(lc, 0.75))
			"engine":
				for k in int(d.sz[0]):
					var yy := r.position.y + (k + 0.5) * r.size.y / int(d.sz[0])
					draw_rect(Rect2(Vector2(r.position.x + s * 0.12, yy - s * 0.22), Vector2(r.size.x * 0.7, s * 0.44)), Color(lc, 0.6))
					draw_colored_polygon(PackedVector2Array([Vector2(r.position.x + s * 0.12, yy - s * 0.28), Vector2(r.position.x - s * 0.05, yy - s * 0.38), Vector2(r.position.x - s * 0.05, yy + s * 0.38), Vector2(r.position.x + s * 0.12, yy + s * 0.28)]), Color(1, 0.7, 0.35, 0.8))
			"weapon":
				draw_circle(c - Vector2(s * 0.1, 0), s * 0.2, Color(lc, 0.7))
				draw_line(c, Vector2(r.end.x - 2, c.y), lc, 3.0)
			"shield":
				draw_arc(c, s * 0.28, PI * 0.5, PI * 1.5, 16, lc, 2.0)
				draw_arc(c, s * 0.18, PI * 0.5, PI * 1.5, 16, Color(lc, 0.6), 2.0)
			"power":
				draw_circle(c, s * 0.25, Color(lc, 0.35))
				draw_circle(c, s * 0.12, lc)
			"cargo":
				draw_rect(Rect2(r.position + Vector2(4, 4), r.size - Vector2(8, 8)), Color(lc, 0.5), false, 1.5)
				draw_line(r.position + Vector2(4, 4), r.end - Vector2(4, 4), Color(lc, 0.35), 1.0)
				draw_line(Vector2(r.end.x - 4, r.position.y + 4), Vector2(r.position.x + 4, r.end.y - 4), Color(lc, 0.35), 1.0)
			"rcs":
				for dv in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
					draw_line(c + dv * s * 0.1, c + dv * s * 0.32, lc, 2.0)
			"armor":
				for k in 3:
					var yy := r.position.y + r.size.y * (0.28 + k * 0.22)
					draw_line(Vector2(r.position.x + 5, yy), Vector2(r.end.x - 5, yy), Color(lc, 0.7), 2.0)
			"wing":
				var up := r.get_center().y < origin.y + (Game.GRID_X + 0.5) * cell
				var tip := r.position.y + 3 if up else r.end.y - 3
				var base := r.end.y - 3 if up else r.position.y + 3
				if absf(r.get_center().y - (origin.y + (Game.GRID_X + 0.5) * cell)) < 2.0:
					draw_line(Vector2(r.position.x + 4, c.y), Vector2(r.end.x - 4, c.y), lc, 3.0)
				else:
					draw_colored_polygon(PackedVector2Array([Vector2(r.end.x - 3, base), Vector2(r.position.x + 3, base), Vector2(r.position.x + 3, tip)]), Color(lc, 0.6))
			"hull":
				if id == "hb":
					draw_colored_polygon(PackedVector2Array([Vector2(r.position.x + 3, r.position.y + 3), Vector2(r.end.x - 3, c.y), Vector2(r.position.x + 3, r.end.y - 3)]), Color(lc, 0.45))
				else:
					draw_rect(Rect2(c - Vector2(s, s) * 0.18, Vector2(s, s) * 0.36), Color(lc, 0.25 + 0.15 * int(d.tier)))
			"util":
				draw_circle(c, s * 0.14, lc)
				draw_arc(c, s * 0.28, 0, TAU, 20, Color(lc, 0.5), 1.5)
		if cell >= 28.0 and (int(d.sz[0]) > 1 or int(d.sz[1]) > 1):
			draw_string(UIKit.F_SEMI, r.position + Vector2(4, 12), String(d.n).substr(0, 14), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 6, 9, Color(lc, 0.9))

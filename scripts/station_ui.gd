class_name StationUI
extends Control
## Stationsmenü im Hangar: Frachtbörse, Werft (Bauteile), Lackiererei.

const K = preload("res://scripts/ui_kit.gd")
const PANEL_FRAC := 0.5

const STAT_ROWS := [
	["Beschleunigung", "acc", "m/s²", 150.0, 1],
	["Höchstgeschw.", "vmax", "m/s", 560.0, 1],
	["Wendigkeit", "turn", "%", 250.0, 1],
	["Frachtraum", "cap", "t", 120.0, 1],
	["Hülle", "hp_max", "HP", 400.0, 1],
	["Schutz", "prot", "%", 50.0, 1],
	["Leermasse", "dry", "t", 95.0, -1]]

var main: Node
var tab := "fracht"
var w_slot := "engine"

var panel: PanelContainer
var station_lbl: Label
var name_lbl: Label
var credits_lbl: Label
var tab_btns := {}
var scroll: ScrollContainer
var content: VBoxContainer
var foot_lbl: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel = PanelContainer.new()
	panel.anchor_left = 1.0 - PANEL_FRAC
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 0
	panel.offset_right = -10
	panel.offset_top = 10
	panel.offset_bottom = -10
	add_child(panel)
	var v := K.vbox(10)
	panel.add_child(v)
	var head := K.hbox(10)
	var hl := K.vbox(0)
	station_lbl = K.caps("Station")
	name_lbl = K.lbl("«Möwe»", 22, K.FG, K.F_BOLD)
	hl.add_child(station_lbl)
	hl.add_child(name_lbl)
	head.add_child(hl)
	head.add_child(K.spacer())
	var hr := K.vbox(0)
	var kl := K.caps("Konto")
	kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hr.add_child(kl)
	credits_lbl = K.lbl("0 cr", 18, K.AMBER, K.F_MONO)
	credits_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hr.add_child(credits_lbl)
	head.add_child(hr)
	v.add_child(head)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	for t in [["fracht", "Fracht"], ["werft", "Werft"], ["lack", "Lackiererei"]]:
		var id: String = t[0]
		var b := K.btn(t[1], func(): _set_tab(id))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(b)
		tab_btns[id] = b
	v.add_child(tabs)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	content = K.vbox(10)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	var foot := K.hbox(8)
	var und := K.btn("Abdocken", func(): main.undock(), true)
	und.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	und.custom_minimum_size = Vector2(0, 46)
	und.add_theme_font_size_override("font_size", 16)
	foot.add_child(und)
	foot.add_child(K.btn("Menü", func(): main.open_menu()))
	v.add_child(foot)

func _set_tab(id: String) -> void:
	if tab != id:
		tab = id
		main.clear_previews()
		scroll.scroll_vertical = 0
	refresh()

func refresh() -> void:
	var sv := scroll.scroll_vertical
	var st: Dictionary = main.dock_station()
	station_lbl.text = String(st.name).to_upper()
	name_lbl.text = "«%s»" % Game.s.name
	credits_lbl.text = Game.fmt(Game.s.credits) + " cr"
	for id in tab_btns:
		tab_btns[id].theme_type_variation = "BtnOn" if id == tab else ""
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()
	match tab:
		"fracht": _fracht()
		"werft": _werft()
		"lack": _lack()
	await get_tree().process_frame
	scroll.scroll_vertical = sv

# ---------------------------------------------------------------- Fracht
func _rank_box() -> Control:
	var rk := Game.rank()
	var xp := int(Game.s.xp)
	var card := K.card("CardGoal")
	var v := K.vbox(6)
	card.add_child(v)
	var r := K.hbox(8)
	r.add_child(K.caps("Rang"))
	r.add_child(K.lbl(Game.rank_name(rk), 16, K.AMBER, K.F_BOLD))
	r.add_child(K.spacer())
	var bar := UIKit.Bar.new(100, 6)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if rk + 1 < Game.RANKS.size():
		var cur := int(Game.RANKS[rk][0])
		var nxt := int(Game.RANKS[rk + 1][0])
		r.add_child(K.lbl("%s / %s EP" % [Game.fmt(xp), Game.fmt(nxt)], 12, K.MUTED, K.F_MONO))
		bar.set_value(float(xp - cur) / float(nxt - cur), K.AMBER)
	else:
		r.add_child(K.lbl("Höchster Rang", 12, K.MUTED))
		bar.set_value(1.0, K.AMBER)
	v.add_child(r)
	v.add_child(bar)
	if rk + 1 < Game.RANKS.size():
		var un := []
		for slot in Game.SLOTS:
			for id in Game.PARTS[slot[0]]:
				if int(Game.PARTS[slot[0]][id].rank) == rk + 1:
					un.append(Game.PARTS[slot[0]][id].n)
		if un.size() > 0:
			v.add_child(K.wrap("Ab %s: %s" % [Game.rank_name(rk + 1), ", ".join(un)], 12))
	var g: Dictionary = main.next_goal()
	if not g.is_empty():
		var miss: int = int(g.p.price) - int(Game.s.credits)
		var gl := RichTextLabel.new()
		gl.bbcode_enabled = true
		gl.fit_content = true
		gl.scroll_active = false
		gl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		gl.add_theme_font_size_override("normal_font_size", 12)
		gl.add_theme_font_override("normal_font", K.F_REG)
		gl.add_theme_font_override("bold_font", K.F_SEMI)
		gl.add_theme_color_override("default_color", K.MUTED)
		var tail := "noch [color=#ece5d3]%s cr[/color]" % Game.fmt(miss) if miss > 0 else "[color=#7fe08a][b]jetzt leistbar[/b][/color]"
		gl.text = "Nächstes Upgrade: [color=#9fd4ff][b]%s[/b][/color] · %s" % [g.p.n, tail]
		v.add_child(gl)
	if int(Game.s.streak) > 0:
		v.add_child(K.wrap("Lieferserie: %d ohne Kratzer · Lohn ×%s" % [int(Game.s.streak), String.num(Game.streak_mult(), 2).replace(".", ",")], 12, K.OK))
	return card

func _fracht() -> void:
	var lr: Dictionary = main.last_result
	if not lr.is_empty():
		var c := K.card("CardBad" if lr.get("bad", false) else "CardGood")
		var rl := RichTextLabel.new()
		rl.bbcode_enabled = true
		rl.fit_content = true
		rl.scroll_active = false
		rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rl.add_theme_font_size_override("normal_font_size", 13)
		rl.add_theme_font_size_override("bold_font_size", 13)
		rl.add_theme_font_override("normal_font", K.F_REG)
		rl.add_theme_font_override("bold_font", K.F_BOLD)
		rl.text = lr.text
		c.add_child(rl)
		content.add_child(c)
	content.add_child(_rank_box())
	var job: Dictionary = main.job
	if not job.is_empty():
		content.add_child(K.caps("Aktiver Auftrag"))
		var c := _offer_card(job, -1, "")
		content.add_child(c)
	else:
		content.add_child(K.caps("Frachtbörse · Frachtraum %d t" % int(main.S.cap)))
		var offers: Array = main.offers
		for i in offers.size():
			content.add_child(_offer_card(offers[i], i, main.lock_reason(offers[i])))
	var dmg := roundi(100.0 - main.ship_hull())
	var cost := roundi(dmg * float(main.S.hp_max) * 0.09)
	content.add_child(K.caps("Reparatur"))
	var r := K.hbox(8)
	r.add_child(K.lbl("Hülle %d%%" % roundi(main.ship_hull()), 13, K.MUTED, K.F_REG))
	r.add_child(K.spacer())
	if dmg > 0:
		r.add_child(K.btn("Reparieren · %s cr" % Game.fmt(cost), func(): main.repair(), false, int(Game.s.credits) < cost))
	else:
		r.add_child(K.lbl("Kein Schaden", 13, K.MUTED, K.F_REG))
	content.add_child(r)
	content.add_child(K.lbl("Lieferungen: %d · Beste Serie: %d" % [int(Game.s.deliveries), int(Game.s.best)], 12, K.MUTED, K.F_REG))

func _offer_card(o: Dictionary, i: int, lock: String) -> Control:
	var c := K.card()
	if lock != "":
		c.modulate = Color(1, 1, 1, 0.6)
	var v := K.vbox(4)
	c.add_child(v)
	var r1 := K.hbox(8)
	r1.add_child(K.lbl(o.cargo, 15, K.FG))
	if o.get("fragile", false):
		r1.add_child(_tag("ZERBRECHLICH", K.DANGER))
	if o.get("express", false):
		r1.add_child(_tag("EXPRESS", K.ICE))
	r1.add_child(K.spacer())
	var pay: float = o.pay * (Game.streak_mult() if i >= 0 else 1.0)
	r1.add_child(K.lbl(Game.fmt(pay) + " cr", 15, K.AMBER, K.F_MONO))
	v.add_child(r1)
	var r2 := K.hbox(8)
	var tm: float = o.time * (float(main.S.time) if i >= 0 else 1.0)
	var det := "%d t nach %s · %.1f km · Bonus bei < %s min" % [int(o.mass), o.dest.name, o.dist / 1000.0, Game.mmss(tm)]
	if i < 0:
		det = "%d t nach %s · Zustand %d%%" % [int(o.mass), o.dest.name, roundi(o.cond)]
	r2.add_child(K.wrap(det, 12))
	if i >= 0:
		if lock != "":
			var ll := K.caps(lock, K.MUTED, 11)
			r2.add_child(ll)
		else:
			r2.add_child(K.btn("Annehmen", func(): main.take_offer(i), true))
	else:
		r2.add_child(K.btn("Abbrechen −%s cr" % Game.fmt(o.pay * 0.25), func(): main.cancel_job()))
	v.add_child(r2)
	return c

func _tag(text: String, col: Color) -> Control:
	var l := K.lbl(text, 10, col, K.F_SEMI)
	l.add_theme_stylebox_override("normal", UIKit.box_style(Color(0, 0, 0, 0), col, 1, 3, Vector2(5, 1)))
	return l

# ---------------------------------------------------------------- Werft
func _werft() -> void:
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 6)
	for s in Game.SLOTS:
		var id: String = s[0]
		var b := K.btn(s[1], func(): _pick_slot(id), id == w_slot)
		b.custom_minimum_size = Vector2(0, 36)
		chips.add_child(b)
	content.add_child(chips)
	content.add_child(_stats_box(main.S, Game.stats(main.view_fit())))
	var rk := Game.rank()
	var fit: Dictionary = Game.s.fit
	var vf: Dictionary = main.view_fit()
	for id in Game.PARTS[w_slot]:
		var p: Dictionary = Game.PARTS[w_slot][id]
		var own: bool = Game.s.owned[w_slot].has(id)
		var eq: bool = fit[w_slot] == id
		var sel: bool = vf[w_slot] == id and not eq
		var fits := not (w_slot == "cargo" and int(p.size) > int(Game.part("frame", fit.frame).max_mod))
		var too_small: bool = w_slot == "cargo" and not main.job.is_empty() and int(p.cap) < int(main.job.mass)
		var c := K.card("CardEq" if eq else ("CardSel" if sel else "Card"))
		if int(p.rank) > rk:
			c.modulate = Color(1, 1, 1, 0.55)
		var v := K.vbox(4)
		c.add_child(v)
		var r1 := K.hbox(8)
		var nm := K.lbl(p.n, 15, K.FG)
		r1.add_child(nm)
		if own and not eq:
			r1.add_child(K.lbl("im Lager", 11, K.MUTED, K.F_REG))
		r1.add_child(K.spacer())
		if eq:
			r1.add_child(K.caps("Eingebaut", K.OK))
		elif int(p.rank) > rk:
			r1.add_child(K.caps("Ab " + Game.rank_name(int(p.rank))))
		elif not fits:
			r1.add_child(K.caps("Rumpf zu klein"))
		elif too_small:
			r1.add_child(K.caps("Ladung passt nicht"))
		elif own:
			r1.add_child(K.btn("Einbauen", func(): main.equip(w_slot, id), true))
		else:
			r1.add_child(K.btn("Kaufen · %s cr" % Game.fmt(p.price), func(): main.buy(w_slot, id), true, int(Game.s.credits) < int(p.price)))
		v.add_child(r1)
		var meta := _part_meta(w_slot, p)
		if p.d != "" and w_slot != "extra":
			meta += " · " + p.d
		v.add_child(K.wrap(meta, 12))
		var pid: String = id
		c.gui_input.connect(func(ev: InputEvent): _card_tap(ev, pid))
		content.add_child(c)
	content.add_child(K.wrap("Tippe ein Teil an, um es am Schiff anzuprobieren. Gekaufte Teile bleiben in deinem Lager.", 12))

var _tap_start := Vector2.ZERO
func _card_tap(ev: InputEvent, id: String) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_tap_start = ev.global_position
		elif ev.global_position.distance_to(_tap_start) < 14.0:
			main.try_part(w_slot, id)

func _pick_slot(id: String) -> void:
	w_slot = id
	main.clear_previews()
	refresh()

func _part_meta(k: String, p: Dictionary) -> String:
	match k:
		"frame":
			return "%d HP · %s t · Module bis %s" % [int(p.hp), str(p.mass), ["", "S", "M", "L"][int(p.max_mod)]]
		"engine":
			return "%s kN · %d m/s · %s t" % [Game.fmt(p.thrust), int(p.vmax), str(p.mass)]
		"rcs":
			return "Wendigkeit ×%s" % str(p.turn).replace(".", ",")
		"cargo":
			return "%d t · Größe %s · %s t" % [int(p.cap), ["", "S", "M", "L"][int(p.size)], str(p.mass)]
		"armor":
			if int(p.hp) > 0:
				return "+%d HP · −%d %% Schaden · %s t" % [int(p.hp), roundi((1.0 - float(p.dmg)) * 100.0), str(p.mass)]
			return "Kein Zusatzgewicht"
	return p.d

static func stat_value(st: Dictionary, key: String) -> float:
	match key:
		"acc": return float(st.thrust) / float(st.dry)
		"turn": return float(st.turn) * 100.0
		"prot": return (1.0 - float(st.dmg)) * 100.0
	return float(st[key])

func _stats_box(a: Dictionary, b: Dictionary) -> Control:
	var c := K.card()
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 5)
	c.add_child(g)
	for row in STAT_ROWS:
		var va := stat_value(a, row[1])
		var vb := stat_value(b, row[1])
		var d := vb - va
		var cls := 0
		if absf(d) >= 0.5:
			cls = 1 if d * row[4] > 0 else -1
		g.add_child(K.lbl(row[0], 11, K.MUTED, K.F_REG))
		var sb := UIKit.StatBar.new()
		sb.a = va / row[3]
		sb.b = vb / row[3]
		sb.cls = cls
		g.add_child(sb)
		var txt := "%d %s" % [roundi(vb), row[2]]
		var vl := K.lbl(txt, 12, K.FG, K.F_MONO)
		if cls != 0:
			vl.text = txt + "  %s%d" % ["+" if d > 0 else "", roundi(d)]
			vl.add_theme_color_override("font_color", K.OK if cls > 0 else K.DANGER)
		vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		vl.custom_minimum_size = Vector2(96, 0)
		g.add_child(vl)
	return c

# ---------------------------------------------------------------- Lackiererei
func _lack() -> void:
	var p: Dictionary = main.view_paint()
	var rk := Game.rank()
	content.add_child(K.caps("Rufname"))
	var le := LineEdit.new()
	le.text = Game.s.name
	le.max_length = 18
	le.text_submitted.connect(func(t: String): main.rename(t))
	le.focus_exited.connect(func(): main.rename(le.text))
	content.add_child(le)
	for key in [["hull", "Grundfarbe"], ["accent", "Akzentfarbe"]]:
		content.add_child(K.caps(key[1]))
		var fl := HFlowContainer.new()
		fl.add_theme_constant_override("h_separation", 6)
		fl.add_theme_constant_override("v_separation", 6)
		for col in Game.COLORS:
			var locked := int(col[2]) > rk
			var sw := UIKit.Swatch.new(Color.html(col[1]), p[key[0]] == col[1], locked)
			sw.tooltip_text = col[0] + (" – ab " + Game.rank_name(int(col[2])) if locked else "")
			var k0: String = key[0]
			var v0: String = col[1]
			sw.pressed.connect(func(): main.set_paint(k0, v0))
			fl.add_child(sw)
		content.add_child(fl)
	content.add_child(K.caps("Muster"))
	var pf := HFlowContainer.new()
	pf.add_theme_constant_override("h_separation", 6)
	pf.add_theme_constant_override("v_separation", 6)
	for pt in Game.PATTERNS:
		var locked := int(pt.r) > rk
		var own: bool = Game.s.patterns.has(pt.id)
		var txt: String = pt.n
		if locked:
			txt += " · ab " + Game.rank_name(int(pt.r))
		elif not own:
			txt += " · %s cr" % Game.fmt(pt.price)
		var pid: String = pt.id
		var b := K.btn(txt, func(): main.set_paint("pattern", pid), p.pattern == pt.id, locked)
		b.custom_minimum_size = Vector2(0, 36)
		pf.add_child(b)
	content.add_child(pf)
	content.add_child(K.caps("Triebwerksfarbe"))
	var ff := HFlowContainer.new()
	ff.add_theme_constant_override("h_separation", 6)
	ff.add_theme_constant_override("v_separation", 6)
	for f in Game.FLAMES:
		var locked := int(f.r) > rk
		var txt: String = f.n
		if locked:
			txt += " · ab " + Game.rank_name(int(f.r))
		var fid: String = f.id
		var b := K.btn(txt, func(): main.set_paint("flame", fid), p.flame == f.id, locked)
		b.custom_minimum_size = Vector2(0, 36)
		if f.c != "":
			b.add_theme_color_override("font_color", Color.html(f.c))
		ff.add_child(b)
	content.add_child(ff)
	if not main.pend_paint.is_empty():
		var cost: int = main.paint_cost(main.pend_paint)
		var r := K.hbox(8)
		r.add_child(K.btn("Verwerfen", func(): main.reset_paint()))
		r.add_child(K.spacer())
		r.add_child(K.btn(("Lackieren · %s cr" % Game.fmt(cost)) if cost > 0 else "Übernehmen", func(): main.apply_paint(), true, int(Game.s.credits) < cost))
		content.add_child(r)
	else:
		content.add_child(K.wrap("Farben und Muster siehst du sofort am Schiff. Bezahlt wird erst beim Lackieren.", 12))

class_name StationUI
extends Control
## Gesprächs- und Werkstattfenster: Aufträge, Ausrüster, Lackiererei, Bar, Schiffskonsole.

const K = preload("res://scripts/ui_kit.gd")
const PANEL_FRAC := 0.5

const STAT_ROWS := [
	["Beschleunigung", "acc", "m/s²", 150.0, 1],
	["Höchstgeschw.", "vmax", "m/s", 560.0, 1],
	["Wendigkeit", "turn", "%", 250.0, 1],
	["Feuerkraft", "dps", "dps", 220.0, 1],
	["Schild", "shield", "", 260.0, 1],
	["Hülle", "hp_max", "HP", 400.0, 1],
	["Frachtraum", "cap", "t", 120.0, 1],
	["Leermasse", "dry", "t", 110.0, -1]]

var main: Node
var mode := "jobs"
var slot := "engine"
var title := ""
var subtitle := ""

var panel: PanelContainer
var sub_lbl: Label
var title_lbl: Label
var credits_lbl: Label
var scroll: ScrollContainer
var content: VBoxContainer

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
	sub_lbl = K.caps("Station")
	title_lbl = K.lbl("", 21, K.FG, K.F_BOLD)
	hl.add_child(sub_lbl)
	hl.add_child(title_lbl)
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
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	TouchScroll.attach(scroll)
	content = K.vbox(10)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	var back := K.btn("Zurück", func(): main.close_panel(), true)
	back.custom_minimum_size = Vector2(0, 46)
	back.add_theme_font_size_override("font_size", 16)
	v.add_child(back)

func open(m: String, t: String, sub: String, s := "") -> void:
	mode = m
	title = t
	subtitle = sub
	if s != "":
		slot = s
	scroll.scroll_vertical = 0
	visible = true
	refresh()

func refresh() -> void:
	var sv := scroll.scroll_vertical
	sub_lbl.text = subtitle.to_upper()
	title_lbl.text = title
	credits_lbl.text = Game.fmt(Game.s.credits) + " cr"
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()
	match mode:
		"jobs": _jobs()
		"shop": _shop()
		"console": _console()
		"paint": _paint()
		"bar": _bar()
		"tune": _tune_all()
	await get_tree().process_frame
	scroll.scroll_vertical = sv

func _rich(text: String, size := 13, col := K.FG) -> RichTextLabel:
	var rl := RichTextLabel.new()
	rl.bbcode_enabled = true
	rl.fit_content = true
	rl.scroll_active = false
	rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rl.add_theme_font_size_override("normal_font_size", size)
	rl.add_theme_font_size_override("bold_font_size", size)
	rl.add_theme_font_override("normal_font", K.F_REG)
	rl.add_theme_font_override("bold_font", K.F_BOLD)
	rl.add_theme_color_override("default_color", col)
	rl.text = text
	rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return rl

func _say(text: String) -> void:
	var c := K.card("CardGoal")
	c.add_child(_rich("[i]„%s“[/i]" % text, 13, K.FG))
	content.add_child(c)

# ---------------------------------------------------------------- Rang
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
	var g: Dictionary = main.next_goal()
	if not g.is_empty():
		var miss: int = int(g.p.price) - int(Game.s.credits)
		var tail := "noch [color=#ece5d3]%s cr[/color]" % Game.fmt(miss) if miss > 0 else "[color=#7fe08a][b]jetzt leistbar[/b][/color]"
		v.add_child(_rich("Nächstes Modul: [color=#9fd4ff][b]%s[/b][/color] (%s) · %s" % [g.p.n, Game.cat_name(g.p.cat), tail], 12, K.MUTED))
	var best_t := -1
	var best_s := ""
	for id in Game.bp_counts(Game.s.bp):
		if Game.tunable(id) and Game.tune_level(id) < Game.TUNE_MAX:
			var tc := Game.tune_cost(id)
			if best_t < 0 or tc < best_t:
				best_t = tc
				best_s = Game.mod(id).n
	if best_t > 0:
		var ok := int(Game.s.credits) >= best_t
		v.add_child(_rich("Tuning: [color=#9fd4ff][b]%s[/b][/color] eine Stufe für %s cr%s" % [best_s, Game.fmt(best_t), " · [color=#7fe08a][b]jetzt leistbar[/b][/color] beim Mechanik-Roboter R-7 im Hangar" if ok else ""], 12, K.MUTED))
	if int(Game.s.streak) > 0:
		v.add_child(K.wrap("Lieferserie: %d ohne Kratzer · Lohn ×%s" % [int(Game.s.streak), String.num(Game.streak_mult(), 2).replace(".", ",")], 12, K.OK))
	return card

# ---------------------------------------------------------------- Aufträge
func _jobs() -> void:
	_say(["Pünktlich und heil ankommen, dann zahlt sich das aus.", "Ich hab da was für dich, wenn du Platz im Laderaum hast.", "Vorsicht auf den Routen nach Nyx – da draußen wird geschossen."][randi() % 3])
	content.add_child(_rank_box())
	var job: Dictionary = main.job
	if not job.is_empty():
		content.add_child(K.caps("Aktiver Auftrag"))
		content.add_child(_offer_card(job, -1, ""))
		return
	content.add_child(K.caps("Frachtaufträge · Frachtraum %d t" % int(main.S.cap)))
	var offers: Array = main.offers
	for i in offers.size():
		content.add_child(_offer_card(offers[i], i, main.lock_reason(offers[i])))
	content.add_child(K.lbl("Lieferungen: %d · Abschüsse: %d · Beste Serie: %d" % [int(Game.s.deliveries), int(Game.s.kills), int(Game.s.best)], 12, K.MUTED, K.F_REG))

func _offer_card(o: Dictionary, i: int, lock: String) -> Control:
	var c := K.card()
	if lock != "":
		c.modulate = Color(1, 1, 1, 0.6)
	var v := K.vbox(4)
	c.add_child(v)
	var r1 := K.hbox(8)
	var bounty: bool = o.get("type", "cargo") == "bounty"
	r1.add_child(K.lbl(("Kopfgeld: " + o.target) if bounty else o.cargo, 15, K.FG))
	if o.get("fragile", false):
		r1.add_child(_tag("ZERBRECHLICH", K.DANGER))
	if o.get("express", false):
		r1.add_child(_tag("EXPRESS", K.ICE))
	if bounty:
		r1.add_child(_tag("KAMPF", K.DANGER))
	elif o.get("dest_sys", "") != Game.s.system:
		r1.add_child(_tag("%d SPRUNG" % Universe.jumps(Game.s.system, o.dest_sys), K.AMBER))
	r1.add_child(K.spacer())
	var pay: float = o.pay * (Game.streak_mult() if i >= 0 and not bounty else 1.0)
	r1.add_child(K.lbl(Game.fmt(pay) + " cr", 15, K.AMBER, K.F_MONO))
	v.add_child(r1)
	var r2 := K.hbox(8)
	var det := ""
	if bounty:
		det = "%s · %s · %d Begleiter" % [o.sys_name, o.zone_name, int(o.count)]
	elif i >= 0:
		var tm: float = o.time * float(main.S.time)
		det = "%d t nach %s (%s) · %s · Bonus bei < %s min" % [int(o.mass), o.dest_name, Universe.system(o.dest_sys).n, Game.dist_txt(o.dist), Game.mmss(tm)]
	else:
		det = "%d t nach %s · Zustand %d%%" % [int(o.mass), o.dest_name, roundi(o.cond)]
	r2.add_child(K.wrap(det, 12))
	if i >= 0:
		if lock != "":
			r2.add_child(K.caps(lock, K.MUTED, 11))
		else:
			r2.add_child(K.btn("Annehmen", func(): main.take_offer(o), true))
	else:
		r2.add_child(K.btn("Abbrechen −%s cr" % Game.fmt(float(o.pay) * 0.25), func(): main.cancel_job()))
	v.add_child(r2)
	return c

func _tag(text: String, col: Color) -> Control:
	var l := K.lbl(text, 10, col, K.F_SEMI)
	l.add_theme_stylebox_override("normal", UIKit.box_style(Color(0, 0, 0, 0), col, 1, 3, Vector2(5, 1)))
	return l

# ---------------------------------------------------------------- Bar
func _bar() -> void:
	for line in main.news_lines():
		_say(line)
	content.add_child(_rank_box())
	var job: Dictionary = main.job
	if not job.is_empty():
		content.add_child(K.caps("Aktiver Auftrag"))
		content.add_child(_offer_card(job, -1, ""))
		return
	content.add_child(K.caps("Kopfgeld-Aufträge"))
	var b: Array = main.bounties
	if b.is_empty():
		content.add_child(K.wrap("Heute keine Kopfgelder. Komm später wieder.", 13))
	for o in b:
		content.add_child(_offer_card(o, 0, main.lock_reason(o)))

# ---------------------------------------------------------------- Ausrüster
func _shop() -> void:
	var st: Dictionary = main.dock_station()
	var shop_lvl := int(st.shop)
	_say("Module kaufst du bei mir, eingebaut wird am Blaupausen-Tisch im Hangar. Ausgebautes lagere ich für dich ein." if shop_lvl < 3 else "Willkommen in der besten Werft weit und breit. Hier gibt's jedes Modul – wenn du's bezahlen kannst.")
	var hull_frac: float = main.ship_hull_frac()
	if hull_frac < 0.999:
		var r := K.hbox(8)
		var cost: int = main.repair_cost()
		r.add_child(K.lbl("Hülle %d%%" % roundi(hull_frac * 100.0), 13, K.DANGER, K.F_REG))
		r.add_child(K.spacer())
		r.add_child(K.btn("Reparieren · %s cr" % Game.fmt(cost), func(): main.repair(), true, int(Game.s.credits) < cost))
		content.add_child(r)
	var bp_btn := K.btn("Blaupause öffnen – Schiff umbauen", func(): main.open_blueprint(), true)
	bp_btn.custom_minimum_size = Vector2(0, 42)
	content.add_child(bp_btn)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 6)
	if not Game.CATS.any(func(c): return c[0] == slot):
		slot = "engine"
	for c in Game.CATS:
		var id: String = c[0]
		var b := K.btn(c[1], func(): _pick_slot(id), id == slot)
		b.custom_minimum_size = Vector2(0, 34)
		chips.add_child(b)
	content.add_child(chips)
	_module_list(shop_lvl)

func _module_list(shop_lvl: int) -> void:
	var rk := Game.rank()
	var ship := Game.bp_counts(Game.s.bp)
	for id in Game.MODULES:
		var p: Dictionary = Game.MODULES[id]
		if p.cat != slot:
			continue
		var sold := int(p.tier) <= shop_lvl
		var c := K.card("CardEq" if ship.has(id) else "Card")
		if int(p.rank) > rk or not sold:
			c.modulate = Color(1, 1, 1, 0.55)
		var v := K.vbox(4)
		c.add_child(v)
		var r1 := K.hbox(8)
		r1.add_child(K.lbl(p.n, 15, K.FG))
		r1.add_child(K.lbl("%d×%d" % [int(p.sz[0]), int(p.sz[1])], 11, K.MUTED, K.F_MONO))
		r1.add_child(K.spacer())
		if int(p.price) == 0:
			r1.add_child(K.caps("Grundausstattung", K.OK))
		elif int(p.rank) > rk:
			r1.add_child(K.caps("Ab " + Game.rank_name(int(p.rank))))
		elif not sold:
			r1.add_child(K.caps("Nicht im Angebot"))
		else:
			r1.add_child(K.btn("Kaufen · %s cr" % Game.fmt(p.price), func(): main.buy_module(id), true, int(Game.s.credits) < int(p.price)))
		v.add_child(r1)
		var meta := BlueprintUI._meta(p) + " · " + String(p.d)
		var inv := Game.inv_count(id)
		var tail := []
		if ship.has(id):
			tail.append("eingebaut %d" % int(ship[id]))
		if inv > 0:
			tail.append("im Lager %d" % inv)
		if int(p.price) > 0 and not sold:
			tail.append("erhältlich bei: " + main.where_sold(int(p.tier)))
		if not tail.is_empty():
			meta += " · " + " · ".join(tail)
		var r2 := K.hbox(8)
		r2.add_child(K.wrap(meta, 12))
		if inv > 0 and int(p.price) > 0:
			r2.add_child(K.btn("Verkaufen +%s" % Game.fmt(roundi(float(p.price) * 0.5)), func(): main.sell_module(id)))
		v.add_child(r2)
		content.add_child(c)

func _tune_card(id: String) -> Control:
	var p := Game.mod(id)
	var lvl := Game.tune_level(id)
	var c := K.card("CardGoal")
	var v := K.vbox(6)
	c.add_child(v)
	var r := K.hbox(8)
	r.add_child(K.caps(Game.cat_name(p.cat)))
	r.add_child(K.lbl(p.n, 14, K.FG))
	var n := int(Game.bp_counts(Game.s.bp).get(id, 0))
	if n > 1:
		r.add_child(K.lbl("×%d" % n, 12, K.MUTED, K.F_MONO))
	r.add_child(K.spacer())
	var pips := ""
	for i in Game.TUNE_MAX:
		pips += "■" if i < lvl else "□"
	r.add_child(K.lbl(pips, 14, K.AMBER, K.F_MONO))
	v.add_child(r)
	var r2 := K.hbox(8)
	r2.add_child(K.wrap("Je Stufe %s · gilt für alle Module dieses Typs · Stufe %d/%d" % [Game.TUNE_TEXT[p.cat], lvl, Game.TUNE_MAX], 12))
	if lvl < Game.TUNE_MAX:
		var cost := Game.tune_cost(id)
		r2.add_child(K.btn("Tunen · %s cr" % Game.fmt(cost), func(): main.tune(id), true, int(Game.s.credits) < cost))
	else:
		r2.add_child(K.caps("Maximal getunt", K.OK))
	v.add_child(r2)
	return c

func _tune_all() -> void:
	_say("Piep. Ich bin R-7, Mechanik-Einheit. Ich hole aus deinen Modulen mehr raus. Jede Stufe gilt für alle Module des Typs und hält für immer.")
	var ids := Game.bp_counts(Game.s.bp).keys()
	ids.sort_custom(func(a, b): return Game.CATS.map(func(c): return c[0]).find(Game.mod(a).cat) < Game.CATS.map(func(c): return c[0]).find(Game.mod(b).cat))
	for id in ids:
		if Game.tunable(id):
			content.add_child(_tune_card(id))
	content.add_child(_stats_box(main.S, main.S))

func _console() -> void:
	var counts := Game.bp_counts(Game.s.bp)
	var lines := []
	for id in counts:
		if Game.mod(id).cat == slot:
			lines.append("%d× %s" % [int(counts[id]), Game.mod(id).n])
	_say("Bordrechner: %s – %s. Umbauen kannst du am Konstruktionstisch." % [Game.cat_name(slot), ", ".join(lines) if not lines.is_empty() else "nicht verbaut"])
	var b := K.btn("Blaupause öffnen", func(): main.open_blueprint(), true)
	b.custom_minimum_size = Vector2(0, 42)
	content.add_child(b)
	content.add_child(_stats_box(main.S, main.S))
	for id in counts:
		if Game.mod(id).cat == slot:
			var c := K.card()
			var v := K.vbox(2)
			c.add_child(v)
			var lvl := Game.tune_level(id)
			v.add_child(K.lbl("%d× %s%s" % [int(counts[id]), Game.mod(id).n, (" · Tuning +%d" % lvl) if lvl > 0 else ""], 14, K.FG))
			v.add_child(K.wrap(BlueprintUI._meta(Game.mod(id)), 12))
			content.add_child(c)

func _pick_slot(id: String) -> void:
	slot = id
	refresh()

static func stat_value(st: Dictionary, key: String) -> float:
	match key:
		"acc": return float(st.thrust) / float(st.dry)
		"turn": return float(st.turn) * 100.0
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
func _paint() -> void:
	_say("Farbe ist mehr als Deko – man soll dich erkennen, wenn du andockst.")
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
			sw.pressed.connect(func():
				if TouchScroll.tap_ok():
					main.set_paint(k0, v0))
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

extends Node
## Autoload "Game": Spieldaten (Bauteile, Ränge, Lacke, Fracht) und Spielstand.

const SAVE_PATH := "user://frachtpilot_save.json"

const SLOTS := [["frame", "Rumpf"], ["engine", "Triebwerk"], ["rcs", "Düsen"], ["weapon", "Waffen"], ["shield", "Schild"],
	["cargo", "Fracht"], ["armor", "Panzer"], ["extra", "Extra"]]

const BASE_FIT := {"frame": "spatz", "engine": "funke", "rcs": "rcs1", "weapon": "puls1", "shield": "s0", "cargo": "k12", "armor": "a0", "extra": "x0"}

## tier = Ausstattungsstufe einer Werft (0–3). Höhere Stufen gibt es nur an großen Werften.
const PARTS := {
	"frame": {
		"spatz": {"n": "Spatz", "d": "Wendiger Einsteiger-Rumpf", "price": 0, "rank": 0, "tier": 0, "mass": 16.0, "hp": 100, "max_mod": 1, "turn": 1.0, "dim": Vector3(5.0, 2.6, 11.0), "style": 0},
		"esel": {"n": "Lastesel", "d": "Robuster Mittelklasse-Frachter", "price": 14000, "rank": 1, "tier": 1, "mass": 28.0, "hp": 150, "max_mod": 2, "turn": 0.85, "dim": Vector3(6.6, 3.4, 15.0), "style": 1},
		"pfeil": {"n": "Pfeil", "d": "Kurier-Rumpf: leicht, schnell, empfindlich", "price": 30000, "rank": 2, "tier": 2, "mass": 13.0, "hp": 80, "max_mod": 1, "turn": 1.35, "dim": Vector3(4.4, 2.2, 14.0), "style": 2},
		"kondor": {"n": "Kondor", "d": "Schwerlast-Rumpf für die größten Module", "price": 55000, "rank": 3, "tier": 3, "mass": 45.0, "hp": 230, "max_mod": 3, "turn": 0.7, "dim": Vector3(8.6, 4.2, 20.0), "style": 3},
	},
	"engine": {
		"funke": {"n": "Funke Mk1", "d": "Serientriebwerk", "price": 0, "rank": 0, "tier": 0, "mass": 4.0, "thrust": 1300.0, "vmax": 260.0, "nac": 2, "r": 0.85, "len": 5.0, "flame": "#8fc8ff", "ring": false, "glow": false},
		"orion": {"n": "Orion Mk2", "d": "Mehr Schub, höhere Spitze", "price": 6500, "rank": 0, "tier": 1, "mass": 6.0, "thrust": 1900.0, "vmax": 330.0, "nac": 2, "r": 1.15, "len": 6.5, "flame": "#8fc8ff", "ring": true, "glow": false},
		"hyperion": {"n": "Hyperion Mk3", "d": "Vier Düsen, enormer Schub", "price": 22000, "rank": 2, "tier": 2, "mass": 9.0, "thrust": 3200.0, "vmax": 420.0, "nac": 4, "r": 0.95, "len": 7.0, "flame": "#ffad5a", "ring": false, "glow": false},
		"ionen": {"n": "Ionenstrahl X", "d": "Spitzentechnik aus der Orion-Werft", "price": 60000, "rank": 4, "tier": 3, "mass": 11.0, "thrust": 4600.0, "vmax": 540.0, "nac": 2, "r": 1.35, "len": 9.5, "flame": "#c49bff", "ring": true, "glow": true},
	},
	"rcs": {
		"rcs1": {"n": "Düsen Standard", "d": "Grundausstattung", "price": 0, "rank": 0, "tier": 0, "mass": 1.0, "turn": 1.0, "strafe": 1.0, "k": 4, "acc": false},
		"rcs2": {"n": "Düsen Plus", "d": "Schnelleres Drehen", "price": 3500, "rank": 0, "tier": 1, "mass": 1.5, "turn": 1.2, "strafe": 1.25, "k": 4, "acc": false},
		"rcs3": {"n": "Vektordüsen", "d": "Präzise beim Andocken und im Kurvenkampf", "price": 12000, "rank": 1, "tier": 2, "mass": 2.0, "turn": 1.45, "strafe": 1.5, "k": 8, "acc": false},
		"rcs4": {"n": "Gyro-Vektor", "d": "Dreht wie ein Jäger", "price": 30000, "rank": 3, "tier": 3, "mass": 2.5, "turn": 1.75, "strafe": 1.8, "k": 8, "acc": true},
	},
	"weapon": {
		"puls1": {"n": "Pulslaser Mk1", "d": "Zuverlässig, schnelle Schussfolge", "price": 0, "rank": 0, "tier": 0, "mass": 2.0, "dmg": 6.0, "rate": 5.0, "speed": 1100.0, "range": 1300.0, "energy": 4.0, "color": "#ff5a4e", "size": 1.0},
		"puls2": {"n": "Pulslaser Mk2", "d": "Mehr Wumms, weiter", "price": 7000, "rank": 0, "tier": 1, "mass": 2.5, "dmg": 9.0, "rate": 6.0, "speed": 1300.0, "range": 1500.0, "energy": 5.0, "color": "#ff8a3a", "size": 1.1},
		"plasma": {"n": "Plasmakanone", "d": "Langsam, aber jeder Treffer sitzt", "price": 18000, "rank": 1, "tier": 2, "mass": 4.0, "dmg": 26.0, "rate": 1.8, "speed": 850.0, "range": 1400.0, "energy": 12.0, "color": "#7fd1ff", "size": 2.2},
		"gatling": {"n": "Partikel-Gatling", "d": "Sperrfeuer gegen wendige Jäger", "price": 32000, "rank": 2, "tier": 2, "mass": 4.5, "dmg": 4.5, "rate": 14.0, "speed": 1500.0, "range": 1200.0, "energy": 2.0, "color": "#ffe066", "size": 0.8},
		"lanze": {"n": "Ionenlanze", "d": "Schwerste Bordwaffe, frisst Energie", "price": 65000, "rank": 4, "tier": 3, "mass": 6.0, "dmg": 42.0, "rate": 1.6, "speed": 2200.0, "range": 2000.0, "energy": 17.0, "color": "#c49bff", "size": 2.6},
	},
	"shield": {
		"s0": {"n": "Basisschild", "d": "Hält ein paar Treffer ab", "price": 0, "rank": 0, "tier": 0, "mass": 1.0, "cap": 40.0, "regen": 6.0},
		"s1": {"n": "Deflektor Mk2", "d": "Doppelte Kapazität", "price": 6000, "rank": 0, "tier": 1, "mass": 1.5, "cap": 80.0, "regen": 9.0},
		"s2": {"n": "Prisma-Schild", "d": "Lädt schnell wieder auf", "price": 20000, "rank": 1, "tier": 2, "mass": 2.5, "cap": 150.0, "regen": 15.0},
		"s3": {"n": "Bastion", "d": "Militärischer Schildgenerator", "price": 50000, "rank": 3, "tier": 3, "mass": 4.0, "cap": 260.0, "regen": 22.0},
	},
	"cargo": {
		"k12": {"n": "Frachtkorb 12 t", "d": "Klein, passt überall", "price": 0, "rank": 0, "tier": 0, "mass": 3.0, "cap": 12, "size": 1, "idx": 0},
		"k28": {"n": "Container 28 t", "d": "Größe S", "price": 6000, "rank": 0, "tier": 1, "mass": 5.0, "cap": 28, "size": 1, "idx": 1},
		"k60": {"n": "Doppelcontainer 60 t", "d": "Größe M, braucht Lastesel oder Kondor", "price": 18000, "rank": 1, "tier": 2, "mass": 9.0, "cap": 60, "size": 2, "idx": 2},
		"k120": {"n": "Schwerlastrahmen 120 t", "d": "Größe L, nur Kondor", "price": 45000, "rank": 3, "tier": 3, "mass": 15.0, "cap": 120, "size": 3, "idx": 3},
	},
	"armor": {
		"a0": {"n": "Keine Panzerung", "d": "Leicht, aber ungeschützt", "price": 0, "rank": 0, "tier": 0, "mass": 0.0, "hp": 0, "dmg": 1.0, "t": 0},
		"a1": {"n": "Leichtplatten", "d": "Etwas Schutz gegen Kratzer", "price": 4000, "rank": 0, "tier": 1, "mass": 3.0, "hp": 40, "dmg": 0.85, "t": 1},
		"a2": {"n": "Verbundpanzer", "d": "Steckt Asteroiden weg", "price": 15000, "rank": 1, "tier": 2, "mass": 7.0, "hp": 90, "dmg": 0.7, "t": 2},
		"a3": {"n": "Titan-Keramik", "d": "Fast unzerstörbar, aber schwer", "price": 40000, "rank": 3, "tier": 3, "mass": 12.0, "hp": 160, "dmg": 0.55, "t": 3},
	},
	"extra": {
		"x0": {"n": "Kein Extra", "d": "", "price": 0, "rank": 0, "tier": 0, "mass": 0.0},
		"nav": {"n": "Navigationsrechner", "d": "+25 % Zeit für den Pünktlichkeitsbonus", "price": 5000, "rank": 0, "tier": 1, "mass": 0.5},
		"bake": {"n": "Bergungsbake", "d": "Wrack bleibt vor Plünderern geschützt", "price": 6000, "rank": 0, "tier": 1, "mass": 0.5},
		"daempfer": {"n": "Ladungsdämpfer", "d": "−60 % Schaden an der Ladung", "price": 8000, "rank": 1, "tier": 2, "mass": 1.0},
		"reaktor": {"n": "Zusatzreaktor", "d": "+60 % Waffenenergie und schnelleres Aufladen", "price": 16000, "rank": 1, "tier": 2, "mass": 2.0},
	},
}

const RANKS := [[0, "Kadett"], [400, "Frachtpilot"], [1200, "Linienpilot"], [2800, "Senior-Pilot"], [5500, "Kapitän"], [9500, "Kommodore"], [15000, "Legende"]]

const COLORS := [
	["Sand", "#c9c2b2", 0], ["Arktis", "#e4e8ec", 0], ["Graphit", "#4a4f58", 0], ["Marine", "#2f4a6b", 0],
	["Signalrot", "#a8322a", 0], ["Oliv", "#5c6448", 0], ["Bernstein", "#ffb547", 0], ["Signalgelb", "#f2c230", 1],
	["Petrol", "#1f6066", 1], ["Türkis", "#3fc1c9", 2], ["Schwarz", "#1c1e22", 2], ["Perlmutt", "#d9d2e6", 3],
	["Gold", "#c9a646", 4], ["Rubin", "#7a1030", 5]]

const PATTERNS := [
	{"id": "uni", "n": "Uni", "price": 0, "r": 0, "code": 0},
	{"id": "band", "n": "Bauchbinde", "price": 0, "r": 0, "code": 1},
	{"id": "renn", "n": "Rennstreifen", "price": 1500, "r": 1, "code": 2},
	{"id": "zweiton", "n": "Zweiton", "price": 1500, "r": 1, "code": 3},
	{"id": "warn", "n": "Warnmuster", "price": 2500, "r": 2, "code": 4},
	{"id": "tarn", "n": "Splittertarn", "price": 4000, "r": 3, "code": 5}]

const FLAMES := [
	{"id": "auto", "n": "Triebwerk", "c": "", "r": 0}, {"id": "blau", "n": "Blau", "c": "#8fc8ff", "r": 0},
	{"id": "bern", "n": "Bernstein", "c": "#ffad5a", "r": 1}, {"id": "gruen", "n": "Grün", "c": "#7fffa0", "r": 2},
	{"id": "violett", "n": "Violett", "c": "#c49bff", "r": 3}, {"id": "weiss", "n": "Weiß", "c": "#ffffff", "r": 4},
	{"id": "rot", "n": "Rot", "c": "#ff6a5a", "r": 5}]

const PAINT_FEE := 350

const CARGO := [
	{"n": "Post & Stückgut", "m": [1, 6], "p": 1.6, "r": 0},
	{"n": "Medizinische Güter", "m": [2, 8], "p": 3.0, "fragile": true, "r": 0},
	{"n": "Hydroponik-Setzlinge", "m": [4, 11], "p": 2.4, "fragile": true, "r": 0},
	{"n": "Reaktor-Ersatzteile", "m": [8, 24], "p": 1.9, "r": 0},
	{"n": "Treibstoffzellen", "m": [16, 40], "p": 1.4, "r": 1},
	{"n": "Wassereis", "m": [30, 70], "p": 1.1, "r": 1},
	{"n": "Diplomatenpost", "m": [1, 3], "p": 4.5, "express": true, "r": 1},
	{"n": "Nickel-Eisen-Erz", "m": [50, 115], "p": 0.9, "from": "mine", "r": 2},
	{"n": "Kolonie-Module", "m": [70, 120], "p": 1.3, "r": 3},
	{"n": "Antimaterie-Kanister", "m": [3, 9], "p": 6.0, "fragile": true, "express": true, "r": 4},
	{"n": "Schmuggelware", "m": [2, 10], "p": 5.0, "from": "freeport", "r": 1}]

const PIRATE_NAMES := ["Rotzahn", "Kaltblut", "die Elster", "Grauwolf", "Narbe", "Schakal", "Viper", "Brandt", "Morgana", "der Geier"]

var s: Dictionary = {}

func _ready() -> void:
	load_game()

func default_save() -> Dictionary:
	return {
		"credits": 3000, "hull": 100.0, "deliveries": 0, "system": "sol7", "station": "kepler", "invert_y": false, "intro_seen": false,
		"xp": 0, "streak": 0, "best": 0, "kills": 0, "name": "Möwe",
		"fit": BASE_FIT.duplicate(),
		"owned": {"frame": ["spatz"], "engine": ["funke"], "rcs": ["rcs1"], "weapon": ["puls1"], "shield": ["s0"], "cargo": ["k12"], "armor": ["a0"], "extra": ["x0"]},
		"paint": {"hull": "#c9c2b2", "accent": "#ffb547", "pattern": "band", "flame": "auto"},
		"patterns": ["uni", "band"],
		"wreck": {},
		"job": {},
		"tune": {},
	}

func load_game() -> void:
	s = default_save()
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f:
			var data = JSON.parse_string(f.get_as_text())
			if data is Dictionary:
				for k in data.keys():
					s[k] = data[k]
	s.credits = int(s.credits); s.xp = int(s.xp); s.streak = int(s.streak); s.best = int(s.best); s.kills = int(s.kills)
	s.deliveries = int(s.deliveries); s.hull = clampf(float(s.hull), 1.0, 100.0)
	# Alte Spielstände (Station als Zahl) übernehmen
	if not (s.station is String):
		s.station = ["kepler", "vesta", "halden"][clampi(int(s.station), 0, 2)]
		s.system = "sol7"
	if Universe.station(s.station).is_empty():
		s.station = "kepler"; s.system = "sol7"
	s.system = Universe.station(s.station).sys
	var d := default_save()
	for slot in SLOTS:
		var k: String = slot[0]
		if not s.fit.has(k) or not PARTS[k].has(s.fit[k]):
			s.fit[k] = d.fit[k]
		if not s.owned.has(k):
			s.owned[k] = d.owned[k]
		if not s.owned[k].has(s.fit[k]):
			s.owned[k].append(s.fit[k])
		if not s.owned[k].has(BASE_FIT[k]):
			s.owned[k].append(BASE_FIT[k])
	for k in d.paint.keys():
		if not s.paint.has(k):
			s.paint[k] = d.paint[k]
	if not (s.wreck is Dictionary):
		s.wreck = {}
	if not (s.job is Dictionary):
		s.job = {}
	if not s.has("tune") or not (s.tune is Dictionary):
		s.tune = {}

func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(s))

func reset_game() -> void:
	s = default_save()
	save_game()

func part(k: String, id: String) -> Dictionary:
	return PARTS[k][id]

func rank_of(xp: int) -> int:
	var r := 0
	for i in RANKS.size():
		if xp >= int(RANKS[i][0]):
			r = i
	return r

func rank() -> int:
	return rank_of(int(s.xp))

func rank_name(i: int) -> String:
	return RANKS[clampi(i, 0, RANKS.size() - 1)][1]

func streak_mult() -> float:
	return 1.0 + min(int(s.streak), 10) * 0.05

func stats(fit: Dictionary, tune: Dictionary = {}) -> Dictionary:
	var f := part("frame", fit.frame)
	var e := part("engine", fit.engine)
	var r := part("rcs", fit.rcs)
	var c := part("cargo", fit.cargo)
	var a := part("armor", fit.armor)
	var x := part("extra", fit.extra)
	var w := part("weapon", fit.weapon)
	var sh := part("shield", fit.shield)
	var reactor: bool = fit.extra == "reaktor"
	var tl := func(id: String) -> int: return int(tune.get(id, 0))
	return {
		"dry": float(f.mass) + float(e.mass) + float(r.mass) + float(c.mass) + float(a.mass) + float(x.mass) + float(w.mass) + float(sh.mass),
		"thrust": float(e.thrust) * (1.0 + 0.06 * tl.call(fit.engine)), "vmax": float(e.vmax) * (1.0 + 0.04 * tl.call(fit.engine)),
		"turn": float(f.turn) * float(r.turn) * (1.0 + 0.05 * tl.call(fit.rcs)), "strafe": float(r.strafe),
		"cap": roundi(float(c.cap) * (1.0 + 0.1 * tl.call(fit.cargo))),
		"hp_max": float(f.hp) * (1.0 + 0.08 * tl.call(fit.frame)) + float(a.hp) * (1.0 + 0.1 * tl.call(fit.armor)), "dmg": float(a.dmg),
		"fragile": 0.4 if fit.extra == "daempfer" else 1.0,
		"time": 1.25 if fit.extra == "nav" else 1.0,
		"dim": f.dim,
		"shield": float(sh.cap) * (1.0 + 0.08 * tl.call(fit.shield)), "shield_regen": float(sh.regen) * (1.0 + 0.06 * tl.call(fit.shield)),
		"energy": 160.0 if reactor else 100.0, "energy_regen": 40.0 if reactor else 26.0,
		"wdmg_mult": 1.0 + 0.07 * tl.call(fit.weapon),
		"dps": float(w.dmg) * float(w.rate) * 2.0 * (1.0 + 0.07 * tl.call(fit.weapon)),
	}

const TUNE_MAX := 5
const TUNE_TEXT := {"frame": "+8 % Hülle", "engine": "+6 % Schub, +4 % Spitze", "rcs": "+5 % Wendigkeit", "weapon": "+7 % Schaden",
	"shield": "+8 % Kapazität, +6 % Aufladung", "cargo": "+10 % Frachtraum", "armor": "+10 % Panzerung"}

func tunable(slot: String, id: String) -> bool:
	if not TUNE_TEXT.has(slot):
		return false
	if slot == "armor" and id == "a0":
		return false
	return true

func tune_level(id: String) -> int:
	return int(s.tune.get(id, 0))

func tune_cost(slot: String, id: String) -> int:
	var lvl := tune_level(id)
	var base := maxf(300.0, float(part(slot, id).price) * 0.12)
	return roundi(base * pow(float(lvl + 1), 1.5) / 50.0) * 50

## Passt das Frachtmodul an den Rumpf an (größtes passendes aus dem Lager).
func fix_cargo(fit: Dictionary) -> Dictionary:
	var mx := int(part("frame", fit.frame).max_mod)
	if int(part("cargo", fit.cargo).size) <= mx:
		return fit
	var best := "k12"
	for id in s.owned.cargo:
		var p := part("cargo", id)
		if int(p.size) <= mx and int(p.cap) > int(part("cargo", best).cap):
			best = id
	fit.cargo = best
	return fit

func flame_color(paint: Dictionary, engine_id: String) -> Color:
	for f in FLAMES:
		if f.id == paint.flame and f.c != "":
			return Color.html(f.c)
	return Color.html(part("engine", engine_id).flame)

func pattern_code(id: String) -> int:
	for p in PATTERNS:
		if p.id == id:
			return int(p.code)
	return 0

func fmt(n: float) -> String:
	var v := int(round(n))
	var neg := v < 0
	var t := str(abs(v))
	var out := ""
	while t.length() > 3:
		out = "." + t.substr(t.length() - 3) + out
		t = t.substr(0, t.length() - 3)
	return ("−" if neg else "") + t + out

func mmss(sec: float) -> String:
	var t := int(max(sec, 0.0))
	return "%d:%02d" % [t / 60, t % 60]

func dist_txt(d: float) -> String:
	return ("%.1f km" % (d / 1000.0)) if d >= 1000.0 else ("%d m" % roundi(d))

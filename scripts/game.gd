extends Node
## Autoload "Game": Spieldaten (Bauteile, Ränge, Lacke, Fracht) und Spielstand.

const SAVE_PATH := "user://frachtpilot_save.json"

## Raster der Blaupause: Zellen von 2 m. x = quer (−4..4), z = längs (−7..7, negativ = Bug).
const CELL := 2.0
const GRID_X := 4
const GRID_Z := 7

## Modulkategorien: [id, Name, Farbe im Plan]
const CATS := [
	["cockpit", "Cockpit", "#9fd4ff"], ["hull", "Rumpf", "#c9c2b2"], ["engine", "Antrieb", "#ffad5a"], ["rcs", "Düsen", "#e6d27a"],
	["weapon", "Waffen", "#ff6a5a"], ["shield", "Schild", "#7fe0c8"], ["power", "Energie", "#c49bff"], ["cargo", "Fracht", "#d8a04a"],
	["armor", "Panzer", "#8a929e"], ["wing", "Flügel", "#7fb0ff"], ["util", "System", "#7fe08a"]]

## Alle Bauteile der Blaupause. sz = [Breite x, Länge z] in Zellen.
## tier = Ausstattungsstufe einer Werft (0–3), rank = nötiger Rang, pwr = Leistung (+ erzeugt, − verbraucht).
const MODULES := {
	# Cockpits
	"cp1": {"n": "Cockpit Spatz", "cat": "cockpit", "d": "Einfache Kanzel mit Bordrechner", "sz": [1, 2], "mass": 9.0, "hp": 45, "pwr": 8, "energy": 80, "torque": 4.0, "price": 0, "tier": 0, "rank": 0},
	"cp2": {"n": "Jägerkanzel", "cat": "cockpit", "d": "Schlank, mit eingebauten Lagedüsen", "sz": [1, 2], "mass": 8.0, "hp": 40, "pwr": 9, "energy": 95, "torque": 9.0, "price": 9000, "tier": 1, "rank": 1},
	"cp3": {"n": "Kommandobrücke", "cat": "cockpit", "d": "Breit, gepanzert, viel Bordenergie", "sz": [3, 2], "mass": 22.0, "hp": 150, "pwr": 18, "energy": 130, "torque": 6.0, "price": 26000, "tier": 2, "rank": 2},
	# Rumpf
	"hb": {"n": "Bugkeil", "cat": "hull", "d": "Spitze Nase, leicht", "sz": [1, 1], "mass": 1.5, "hp": 12, "pwr": 0, "price": 400, "tier": 0, "rank": 0},
	"h1": {"n": "Rumpfsegment", "cat": "hull", "d": "Leichter Standardrahmen", "sz": [1, 1], "mass": 2.5, "hp": 20, "pwr": 0, "price": 300, "tier": 0, "rank": 0},
	"h2": {"n": "Verstärktes Segment", "cat": "hull", "d": "Doppelte Spanten", "sz": [1, 1], "mass": 4.0, "hp": 36, "pwr": 0, "price": 1200, "tier": 1, "rank": 0},
	"hk": {"n": "Rumpfblock 2×2", "cat": "hull", "d": "Großes Segment für breite Schiffe", "sz": [2, 2], "mass": 9.0, "hp": 85, "pwr": 0, "price": 3000, "tier": 1, "rank": 1},
	"h3": {"n": "Schwerer Rahmen", "cat": "hull", "d": "Militärisch, sehr robust", "sz": [1, 1], "mass": 6.5, "hp": 60, "pwr": 0, "price": 3500, "tier": 2, "rank": 1},
	# Antrieb
	"funke": {"n": "Funke Mk1", "cat": "engine", "d": "Serientriebwerk", "sz": [1, 2], "mass": 2.0, "hp": 10, "pwr": -2, "thrust": 650.0, "vmax": 260.0, "r": 0.62, "flame": "#8fc8ff", "ring": false, "glow": false, "price": 0, "tier": 0, "rank": 0},
	"orion": {"n": "Orion Mk2", "cat": "engine", "d": "Mehr Schub, höhere Spitze", "sz": [1, 2], "mass": 3.0, "hp": 14, "pwr": -3, "thrust": 950.0, "vmax": 330.0, "r": 0.74, "flame": "#8fc8ff", "ring": true, "glow": false, "price": 3200, "tier": 1, "rank": 0},
	"bst": {"n": "Schub-Block", "cat": "engine", "d": "Doppeldüse für schwere Frachter", "sz": [2, 2], "mass": 8.0, "hp": 30, "pwr": -6, "thrust": 2600.0, "vmax": 340.0, "r": 0.82, "flame": "#ffad5a", "ring": false, "glow": false, "price": 15000, "tier": 2, "rank": 1},
	"hyperion": {"n": "Hyperion Mk3", "cat": "engine", "d": "Enormer Schub", "sz": [1, 2], "mass": 4.5, "hp": 18, "pwr": -5, "thrust": 1600.0, "vmax": 420.0, "r": 0.8, "flame": "#ffad5a", "ring": false, "glow": true, "price": 11000, "tier": 2, "rank": 2},
	"ionen": {"n": "Ionenstrahl X", "cat": "engine", "d": "Spitzentechnik aus der Orion-Werft", "sz": [1, 2], "mass": 5.5, "hp": 22, "pwr": -7, "thrust": 2300.0, "vmax": 540.0, "r": 0.86, "flame": "#c49bff", "ring": true, "glow": true, "price": 30000, "tier": 3, "rank": 4},
	# Düsen
	"rcs1": {"n": "Lagedüsen", "cat": "rcs", "d": "Grundausstattung", "sz": [1, 1], "mass": 0.5, "hp": 6, "pwr": 0, "torque": 3.0, "strafe": 150.0, "price": 0, "tier": 0, "rank": 0},
	"rcs2": {"n": "Lagedüsen Plus", "cat": "rcs", "d": "Schnelleres Drehen", "sz": [1, 1], "mass": 0.7, "hp": 8, "pwr": -1, "torque": 4.5, "strafe": 220.0, "price": 1600, "tier": 1, "rank": 0},
	"rcs3": {"n": "Vektordüsen", "cat": "rcs", "d": "Präzise im Kurvenkampf", "sz": [1, 1], "mass": 1.0, "hp": 10, "pwr": -1, "torque": 6.5, "strafe": 320.0, "price": 5500, "tier": 2, "rank": 1},
	"rcs4": {"n": "Gyro-Vektor", "cat": "rcs", "d": "Dreht wie ein Jäger", "sz": [1, 1], "mass": 1.2, "hp": 12, "pwr": -2, "torque": 9.0, "strafe": 450.0, "price": 14000, "tier": 3, "rank": 3},
	# Waffen (je Modul ein Lauf)
	"puls1": {"n": "Pulslaser Mk1", "cat": "weapon", "d": "Zuverlässig, schnelle Schussfolge", "sz": [1, 1], "mass": 1.0, "hp": 6, "pwr": -1, "dmg": 6.0, "rate": 5.0, "speed": 1100.0, "range": 1300.0, "energy": 2.0, "color": "#ff5a4e", "size": 1.0, "price": 0, "tier": 0, "rank": 0},
	"puls2": {"n": "Pulslaser Mk2", "cat": "weapon", "d": "Mehr Wumms, weiter", "sz": [1, 1], "mass": 1.2, "hp": 7, "pwr": -1, "dmg": 9.0, "rate": 6.0, "speed": 1300.0, "range": 1500.0, "energy": 2.5, "color": "#ff8a3a", "size": 1.1, "price": 3500, "tier": 1, "rank": 0},
	"plasma": {"n": "Plasmakanone", "cat": "weapon", "d": "Langsam, aber jeder Treffer sitzt", "sz": [1, 1], "mass": 2.0, "hp": 9, "pwr": -3, "dmg": 26.0, "rate": 1.8, "speed": 850.0, "range": 1400.0, "energy": 6.0, "color": "#7fd1ff", "size": 2.2, "price": 9000, "tier": 2, "rank": 1},
	"gatling": {"n": "Partikel-Gatling", "cat": "weapon", "d": "Sperrfeuer gegen wendige Jäger", "sz": [1, 1], "mass": 2.2, "hp": 9, "pwr": -2, "dmg": 4.5, "rate": 14.0, "speed": 1500.0, "range": 1200.0, "energy": 1.0, "color": "#ffe066", "size": 0.8, "price": 16000, "tier": 2, "rank": 2},
	"lanze": {"n": "Ionenlanze", "cat": "weapon", "d": "Schwerste Bordwaffe, frisst Energie", "sz": [1, 1], "mass": 3.0, "hp": 12, "pwr": -5, "dmg": 42.0, "rate": 1.6, "speed": 2200.0, "range": 2000.0, "energy": 8.5, "color": "#c49bff", "size": 2.6, "price": 32000, "tier": 3, "rank": 4},
	# Schild
	"s0": {"n": "Basisschild", "cat": "shield", "d": "Hält ein paar Treffer ab", "sz": [1, 1], "mass": 1.0, "hp": 6, "pwr": -1, "cap": 40.0, "regen": 6.0, "price": 0, "tier": 0, "rank": 0},
	"s1": {"n": "Deflektor Mk2", "cat": "shield", "d": "Doppelte Kapazität", "sz": [1, 1], "mass": 1.5, "hp": 8, "pwr": -2, "cap": 80.0, "regen": 9.0, "price": 6000, "tier": 1, "rank": 0},
	"s2": {"n": "Prisma-Schild", "cat": "shield", "d": "Lädt schnell wieder auf", "sz": [1, 1], "mass": 2.5, "hp": 10, "pwr": -3, "cap": 150.0, "regen": 15.0, "price": 20000, "tier": 2, "rank": 1},
	"s3": {"n": "Bastion", "cat": "shield", "d": "Militärischer Schildgenerator", "sz": [1, 1], "mass": 4.0, "hp": 14, "pwr": -5, "cap": 260.0, "regen": 22.0, "price": 50000, "tier": 3, "rank": 3},
	# Energie
	"r1": {"n": "Hilfsreaktor", "cat": "power", "d": "Mehr Leistung für Waffen und Schilde", "sz": [1, 1], "mass": 2.0, "hp": 10, "pwr": 6, "energy": 30, "regen": 6.0, "price": 2500, "tier": 1, "rank": 0},
	"r2": {"n": "Fusionsreaktor", "cat": "power", "d": "Kräftig und zuverlässig", "sz": [1, 2], "mass": 5.0, "hp": 20, "pwr": 14, "energy": 60, "regen": 12.0, "price": 9000, "tier": 2, "rank": 1},
	"r3": {"n": "Antimaterie-Kern", "cat": "power", "d": "Gewaltige Leistung", "sz": [2, 2], "mass": 8.0, "hp": 30, "pwr": 26, "energy": 100, "regen": 20.0, "price": 26000, "tier": 3, "rank": 3},
	# Fracht
	"k1": {"n": "Frachtmodul S", "cat": "cargo", "d": "Klein, passt überall", "sz": [1, 1], "mass": 1.2, "hp": 6, "pwr": 0, "cap": 8, "price": 0, "tier": 0, "rank": 0},
	"k2": {"n": "Container M", "cat": "cargo", "d": "Ein Standardcontainer", "sz": [1, 2], "mass": 3.0, "hp": 12, "pwr": 0, "cap": 22, "price": 3000, "tier": 1, "rank": 0},
	"k3": {"n": "Containerrahmen L", "cat": "cargo", "d": "Vier Container im Gestell", "sz": [2, 2], "mass": 6.0, "hp": 20, "pwr": 0, "cap": 50, "price": 9000, "tier": 2, "rank": 1},
	"k4": {"n": "Schwerlastrahmen XL", "cat": "cargo", "d": "Für Erz und Kolonie-Module", "sz": [2, 3], "mass": 10.0, "hp": 30, "pwr": 0, "cap": 90, "price": 22000, "tier": 3, "rank": 3},
	# Panzer
	"a1": {"n": "Leichtplatten", "cat": "armor", "d": "Etwas Schutz gegen Kratzer", "sz": [1, 1], "mass": 1.5, "hp": 18, "pwr": 0, "red": 0.025, "price": 1000, "tier": 1, "rank": 0},
	"a2": {"n": "Verbundpanzer", "cat": "armor", "d": "Steckt Asteroiden weg", "sz": [1, 1], "mass": 3.0, "hp": 32, "pwr": 0, "red": 0.04, "price": 3500, "tier": 2, "rank": 1},
	"a3": {"n": "Titan-Keramik", "cat": "armor", "d": "Fast unzerstörbar, aber schwer", "sz": [1, 1], "mass": 5.0, "hp": 50, "pwr": 0, "red": 0.06, "price": 9000, "tier": 3, "rank": 3},
	# Flügel
	"w1": {"n": "Stabilisator", "cat": "wing", "d": "Kleine Flosse, ruhigere Kurven", "sz": [1, 1], "mass": 1.2, "hp": 10, "pwr": 0, "torque": 1.5, "price": 600, "tier": 0, "rank": 0},
	"w2": {"n": "Deltaflügel", "cat": "wing", "d": "Mehr Wendigkeit, trägt Positionslichter", "sz": [1, 1], "mass": 1.8, "hp": 16, "pwr": 0, "torque": 2.5, "price": 2500, "tier": 1, "rank": 0},
	"w3": {"n": "Gefechtsflügel", "cat": "wing", "d": "Verstärkt und gepfeilt", "sz": [1, 1], "mass": 2.5, "hp": 26, "pwr": 0, "torque": 3.5, "price": 7000, "tier": 2, "rank": 2},
	# System
	"nav": {"n": "Navigationsrechner", "cat": "util", "d": "+25 % Zeit für den Pünktlichkeitsbonus", "sz": [1, 1], "mass": 0.5, "hp": 4, "pwr": -1, "price": 5000, "tier": 1, "rank": 0},
	"bake": {"n": "Bergungsbake", "cat": "util", "d": "Wrack bleibt vor Plünderern geschützt", "sz": [1, 1], "mass": 0.5, "hp": 4, "pwr": -1, "price": 6000, "tier": 1, "rank": 0},
	"daempfer": {"n": "Ladungsdämpfer", "cat": "util", "d": "−60 % Schaden an der Ladung", "sz": [1, 1], "mass": 1.0, "hp": 4, "pwr": -1, "price": 8000, "tier": 2, "rank": 1},
}

## Vorlagen: [Modul, x, z]
const TEMPLATES := [
	{"id": "spatz", "n": "Spatz", "d": "Wendiger Einsteiger", "mods": [
		["cp1", 0, -3], ["puls1", -1, -2], ["puls1", 1, -2], ["rcs1", -1, -1], ["rcs1", 1, -1], ["s0", 0, -1],
		["k1", -1, 0], ["k1", 1, 0], ["h1", 0, 0], ["h1", 0, 1], ["funke", -1, 1], ["funke", 1, 1]]},
	{"id": "esel", "n": "Lastesel", "d": "Robuster Mittelklasse-Frachter", "mods": [
		["hb", 0, -5], ["cp1", 0, -4], ["puls2", -1, -3], ["puls2", 1, -3], ["rcs2", -1, -2], ["rcs2", 1, -2], ["h2", 0, -2],
		["s1", 0, -1], ["k2", -1, -1], ["k2", 1, -1], ["h2", 0, 0], ["r1", 0, 1], ["k2", -1, 1], ["k2", 1, 1],
		["h1", 0, 2], ["orion", -1, 3], ["orion", 1, 3], ["h1", 0, 3]]},
	{"id": "pfeil", "n": "Pfeil", "d": "Kurier: leicht, schnell, empfindlich", "mods": [
		["hb", 0, -5], ["cp2", 0, -4], ["puls2", -1, -2], ["puls2", 1, -2], ["h1", 0, -2], ["s1", 0, -1], ["w2", -1, -1], ["w2", 1, -1],
		["w2", -2, 0], ["w2", 2, 0], ["rcs2", -1, 0], ["rcs2", 1, 0], ["k2", 0, 0], ["r2", 0, 2], ["w1", 0, 4], ["hyperion", -1, 2], ["hyperion", 1, 2]]},
	{"id": "kondor", "n": "Kondor", "d": "Schwerlaster für die größten Ladungen", "mods": [
		["cp3", -1, -5], ["plasma", -2, -4], ["plasma", 2, -4], ["a2", -2, -3], ["a2", 2, -3], ["h3", -1, -3], ["h3", 1, -3], ["s2", 0, -3],
		["rcs3", -2, -2], ["rcs3", 2, -2], ["r2", 0, -2], ["h3", -1, -2], ["h3", 1, -2],
		["k4", -2, -1], ["k4", 1, -1], ["h2", 0, 0], ["h2", 0, 1], ["r1", 0, 2],
		["h2", -1, 2], ["h2", 1, 2], ["bst", -2, 3], ["bst", 1, 3], ["h1", 0, 3], ["rcs3", 0, 4]]},
	{"id": "hornisse", "n": "Hornisse", "d": "Abfangjäger mit viel Feuerkraft", "mods": [
		["cp2", 0, -3], ["puls2", -1, -2], ["puls2", 1, -2], ["w2", -2, -1], ["w2", 2, -1], ["rcs2", -1, -1], ["rcs2", 1, -1],
		["s1", 0, -1], ["r1", 0, 0], ["h1", -1, 0], ["h1", 1, 0], ["orion", -1, 1], ["orion", 1, 1], ["w1", 0, 1]]},
]

const START_TEMPLATE := "spatz"

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
	_calibrate()
	load_game()

## Kalibrierung: der Spatz hat Wendigkeit 1,0 und Schub-Seitwärts 1,0
var _turn_ref := 0.0
var _strafe_ref := 0.0

func default_save() -> Dictionary:
	return {
		"credits": 3000, "hull": 100.0, "deliveries": 0, "system": "sol7", "station": "kepler", "invert_y": false, "intro_seen": false,
		"xp": 0, "streak": 0, "best": 0, "kills": 0, "name": "Möwe",
		"bp": template_bp(START_TEMPLATE),
		"inv": {},
		"designs": [],
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
	for k in d.paint.keys():
		if not s.paint.has(k):
			s.paint[k] = d.paint[k]
	if not (s.wreck is Dictionary):
		s.wreck = {}
	if not (s.job is Dictionary):
		s.job = {}
	if not s.has("tune") or not (s.tune is Dictionary):
		s.tune = {}
	if not (s.inv is Dictionary):
		s.inv = {}
	if not (s.designs is Array):
		s.designs = []
	# Spielstände bis 0.4 hatten feste Bauteil-Slots statt einer Blaupause
	if s.has("fit") and s.fit is Dictionary:
		_migrate_fit()
	s.bp = clean_bp(s.bp)
	if not validate(s.bp).ok:
		s.bp = template_bp(START_TEMPLATE)
	for k in s.inv.keys():
		s.inv[k] = int(s.inv[k])
		if not MODULES.has(k) or int(s.inv[k]) <= 0:
			s.inv.erase(k)
	var ds := []
	for dsg in s.designs:
		if dsg is Dictionary and dsg.has("mods"):
			ds.append({"n": String(dsg.get("n", "Entwurf")), "mods": clean_bp(dsg).mods})
	s.designs = ds
	if s.wreck.has("parts") and not s.wreck.has("mods"):
		var wm := {}
		for k in s.wreck.parts:
			for e in _legacy_mods(k, String(s.wreck.parts[k])):
				wm[e[0]] = int(wm.get(e[0], 0)) + int(e[1])
		s.wreck.mods = wm
		s.wreck.bp = template_bp(_legacy_template(String(s.wreck.get("fit", {}).get("frame", "spatz"))))
		s.wreck.erase("parts")
		s.wreck.erase("fit")

const _LEGACY_CARGO := {"k28": "k2", "k60": "k3", "k120": "k4"}

func _legacy_template(frame: String) -> String:
	return {"spatz": "spatz", "esel": "esel", "pfeil": "pfeil", "kondor": "kondor"}.get(frame, "spatz")

## Alte Bauteile → Module (mit Anzahl), für Lager und Wracks
func _legacy_mods(slot: String, id: String) -> Array:
	match slot:
		"engine", "weapon", "rcs", "armor":
			if MODULES.has(id) and int(MODULES[id].price) > 0:
				return [[id, 2]]
		"shield":
			if MODULES.has(id) and int(MODULES[id].price) > 0:
				return [[id, 1]]
		"cargo":
			if _LEGACY_CARGO.has(id):
				return [[_LEGACY_CARGO[id], 1]]
		"extra":
			if id == "reaktor":
				return [["r1", 2]]
			if MODULES.has(id):
				return [[id, 1]]
	return []

func _migrate_fit() -> void:
	var fit: Dictionary = s.fit
	var bp := template_bp(_legacy_template(String(fit.get("frame", "spatz"))))
	for m in bp.mods:
		var cat: String = MODULES[m[0]].cat
		var slot: String = {"engine": "engine", "weapon": "weapon", "shield": "shield", "rcs": "rcs"}.get(cat, "")
		if slot != "" and fit.has(slot) and MODULES.has(String(fit[slot])) and String(MODULES[String(fit[slot])].cat) == cat:
			m[0] = String(fit[slot])
	if validate(bp).ok:
		s.bp = bp
	var owned: Dictionary = s.get("owned", {})
	for slot in owned:
		for id in owned[slot]:
			if slot == "frame":
				var refund := {"esel": 14000, "pfeil": 30000, "kondor": 55000}
				if refund.has(id) and id != fit.get("frame", ""):
					s.credits = int(s.credits) + roundi(refund[id] * 0.6)
				continue
			for e in _legacy_mods(slot, String(id)):
				s.inv[e[0]] = int(s.inv.get(e[0], 0)) + int(e[1])
	s.erase("fit")
	s.erase("owned")

func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(s))

func reset_game() -> void:
	s = default_save()
	save_game()

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

# ------------------------------------------------------------------ Blaupausen
func mod(id: String) -> Dictionary:
	return MODULES[id]

func cat_name(cat: String) -> String:
	for c in CATS:
		if c[0] == cat:
			return c[1]
	return cat

func cat_color(cat: String) -> Color:
	for c in CATS:
		if c[0] == cat:
			return Color.html(c[2])
	return Color.WHITE

func template(id: String) -> Dictionary:
	for t in TEMPLATES:
		if t.id == id:
			return t
	return TEMPLATES[0]

func template_bp(id: String) -> Dictionary:
	var out := []
	for m in template(id).mods:
		out.append([String(m[0]), int(m[1]), int(m[2])])
	return {"mods": out}

## Normalisiert eine Blaupause (JSON liefert Zahlen als float)
func clean_bp(bp) -> Dictionary:
	var out := []
	if bp is Dictionary and bp.has("mods") and bp.mods is Array:
		for m in bp.mods:
			if m is Array and m.size() >= 3 and MODULES.has(String(m[0])):
				out.append([String(m[0]), int(m[1]), int(m[2])])
	return {"mods": out}

func copy_bp(bp: Dictionary) -> Dictionary:
	return clean_bp(bp)

## Zellen, die ein Modul belegt
func footprint(m: Array) -> Array:
	var d: Dictionary = MODULES[m[0]]
	var out := []
	for dx in int(d.sz[0]):
		for dz in int(d.sz[1]):
			out.append(Vector2i(int(m[1]) + dx, int(m[2]) + dz))
	return out

## Vector2i(x, z) → Index des Moduls
func bp_cells(bp: Dictionary) -> Dictionary:
	var cells := {}
	for i in bp.mods.size():
		for c in footprint(bp.mods[i]):
			cells[c] = i
	return cells

func bp_counts(bp: Dictionary) -> Dictionary:
	var out := {}
	for m in bp.mods:
		out[m[0]] = int(out.get(m[0], 0)) + 1
	return out

func in_grid(c: Vector2i) -> bool:
	return absi(c.x) <= GRID_X and absi(c.y) <= GRID_Z

## Passt ein Modul an diese Stelle? (Raster und Überschneidung)
func can_place(bp: Dictionary, id: String, x: int, z: int, cells := {}) -> bool:
	if cells.is_empty():
		cells = bp_cells(bp)
	for c in footprint([id, x, z]):
		if not in_grid(c) or cells.has(c):
			return false
	return true

## Prüft die Blaupause. bad: Index → Grund
func validate(bp: Dictionary) -> Dictionary:
	var errors := []
	var warns := []
	var bad := {}
	var cells := {}
	var cockpits := []
	var engines := 0
	for i in bp.mods.size():
		var m: Array = bp.mods[i]
		for c in footprint(m):
			if not in_grid(c):
				bad[i] = "außerhalb des Rasters"
			elif cells.has(c):
				bad[i] = "überschneidet sich"
			cells[c] = i
		var cat: String = MODULES[m[0]].cat
		if cat == "cockpit":
			cockpits.append(i)
		elif cat == "engine":
			engines += 1
	if cockpits.size() == 0:
		errors.append("Ein Cockpit fehlt.")
	elif cockpits.size() > 1:
		errors.append("Nur ein Cockpit erlaubt.")
		for i in cockpits.slice(1):
			bad[i] = "zweites Cockpit"
	if engines == 0:
		errors.append("Mindestens ein Triebwerk nötig.")
	# Zusammenhang ab Cockpit
	if cockpits.size() > 0:
		var seen := {cockpits[0]: true}
		var stack := [cockpits[0]]
		while not stack.is_empty():
			var i: int = stack.pop_back()
			for c in footprint(bp.mods[i]):
				for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n: Vector2i = c + dv
					if cells.has(n) and not seen.has(cells[n]):
						seen[cells[n]] = true
						stack.append(cells[n])
		var loose := 0
		for i in bp.mods.size():
			if not seen.has(i):
				loose += 1
				bad[i] = "nicht verbunden"
		if loose > 0:
			errors.append("%d Modul%s ohne Verbindung zum Cockpit." % [loose, "" if loose == 1 else "e"])
	# Abgasstrahl und Schussfeld
	var blocked_e := 0
	var blocked_w := 0
	for i in bp.mods.size():
		var m: Array = bp.mods[i]
		var d: Dictionary = MODULES[m[0]]
		if d.cat == "engine":
			for dx in int(d.sz[0]):
				for z in range(int(m[2]) + int(d.sz[1]), GRID_Z + 1):
					if cells.has(Vector2i(int(m[1]) + dx, z)):
						bad[i] = "Abgasstrahl blockiert"
			if bad.get(i, "") == "Abgasstrahl blockiert":
				blocked_e += 1
		elif d.cat == "weapon":
			for z in range(-GRID_Z, int(m[2])):
				if cells.has(Vector2i(int(m[1]), z)):
					bad[i] = "Schussfeld blockiert"
			if bad.get(i, "") == "Schussfeld blockiert":
				blocked_w += 1
	if blocked_e > 0:
		errors.append("Hinter Triebwerken muss frei bleiben (Abgasstrahl).")
	if blocked_w > 0:
		errors.append("Vor Waffen muss frei bleiben (Schussfeld).")
	var st := bp_stats(bp)
	if int(st.pwr_use) > int(st.pwr_gen):
		errors.append("Zu wenig Energie: Bedarf %d, Erzeugung %d. Baue einen Reaktor ein." % [int(st.pwr_use), int(st.pwr_gen)])
	if errors.is_empty():
		if float(st.thrust) / maxf(float(st.dry), 1.0) < 15.0:
			warns.append("Sehr träge – mehr Schub einplanen.")
		if int(st.cap) <= 0:
			warns.append("Kein Frachtraum – nur Kopfgeldjagd möglich.")
		if (st.guns as Dictionary).is_empty():
			warns.append("Keine Waffen an Bord.")
	return {"ok": errors.is_empty() and bad.is_empty(), "errors": errors, "warns": warns, "bad": bad}

## Werte eines Schiffs aus seiner Blaupause
func bp_stats(bp: Dictionary, tune: Dictionary = {}) -> Dictionary:
	var tl := func(id: String) -> int: return int(tune.get(id, 0))
	var dry := 0.0
	var thrust := 0.0
	var vsum := 0.0
	var torque := 0.0
	var strafe := 50.0
	var cap := 0.0
	var hp := 0.0
	var red := 0.0
	var sh := 0.0
	var shr := 0.0
	var gen := 0
	var use := 0
	var energy := 0.0
	var eregen := 22.0
	var dps := 0.0
	var guns := {}
	var flags := {}
	var com := Vector2.ZERO
	var lo := Vector2i(99, 99)
	var hi := Vector2i(-99, -99)
	var eng_tail := 0
	for m in bp.mods:
		var id: String = m[0]
		var d: Dictionary = MODULES[id]
		var t: int = tl.call(id)
		var ms := float(d.mass)
		dry += ms
		var ctr := Vector2(float(m[1]) + (float(d.sz[0]) - 1.0) * 0.5, float(m[2]) + (float(d.sz[1]) - 1.0) * 0.5)
		com += ctr * ms
		for c in footprint(m):
			lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
			hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
		var p := int(d.pwr)
		if p > 0:
			gen += roundi(p * (1.0 + 0.1 * t)) if d.cat == "power" else p
		else:
			use -= p
		var hpm := 0.08 if d.cat in ["hull", "cockpit"] else (0.1 if d.cat == "armor" else 0.0)
		hp += float(d.hp) * (1.0 + hpm * t)
		match String(d.cat):
			"cockpit":
				torque += float(d.torque)
				energy += float(d.energy)
			"engine":
				var th := float(d.thrust) * (1.0 + 0.06 * t)
				thrust += th
				vsum += float(d.vmax) * (1.0 + 0.04 * t) * th
				eng_tail = maxi(eng_tail, int(m[2]) + int(d.sz[1]) - 1)
			"rcs":
				torque += float(d.torque) * (1.0 + 0.05 * t)
				strafe += float(d.strafe)
			"wing":
				torque += float(d.torque)
			"weapon":
				var wm := 1.0 + 0.07 * t
				dps += float(d.dmg) * float(d.rate) * wm
				guns[id] = int(guns.get(id, 0)) + 1
			"shield":
				sh += float(d.cap) * (1.0 + 0.08 * t)
				shr += float(d.regen) * (1.0 + 0.06 * t)
			"power":
				energy += float(d.energy) * (1.0 + 0.1 * t)
				eregen += float(d.regen) * (1.0 + 0.1 * t)
			"cargo":
				cap += float(d.cap) * (1.0 + 0.1 * t)
			"armor":
				red += float(d.red)
			"util":
				flags[id] = true
	if dry <= 0.0:
		dry = 1.0
	com /= dry
	var inertia := 0.0
	for m in bp.mods:
		var d: Dictionary = MODULES[m[0]]
		var ctr := Vector2(float(m[1]) + (float(d.sz[0]) - 1.0) * 0.5, float(m[2]) + (float(d.sz[1]) - 1.0) * 0.5)
		inertia += float(d.mass) * (1.0 + 0.25 * ctr.distance_squared_to(com))
	inertia = maxf(inertia, 1.0)
	eregen += maxf(0.0, float(gen - use)) * 2.0
	var acc := thrust / dry
	var vmax := (vsum / thrust if thrust > 0.0 else 0.0) * clampf(0.85 + 0.15 * acc / 50.0, 0.85, 1.1)
	var turn_raw := torque / inertia
	var strafe_raw := strafe / dry
	var turn := 1.0
	var strafe_v := 1.0
	if _turn_ref > 0.0:
		turn = clampf(sqrt(turn_raw / _turn_ref), 0.3, 2.6)
		strafe_v = clampf(strafe_raw / _strafe_ref, 0.4, 2.4)
	var w := float(hi.x - lo.x + 1) * CELL
	var l := float(maxi(hi.y, eng_tail) - lo.y + 1) * CELL + (1.0 if thrust > 0.0 else 0.0)
	return {
		"dry": dry, "thrust": thrust, "vmax": vmax, "turn": turn, "strafe": strafe_v,
		"turn_raw": turn_raw, "strafe_raw": strafe_raw,
		"cap": roundi(cap), "hp_max": hp, "dmg": maxf(0.5, 1.0 - red),
		"fragile": 0.4 if flags.has("daempfer") else 1.0,
		"time": 1.25 if flags.has("nav") else 1.0,
		"bake": flags.has("bake"),
		"dim": Vector3(w, 2.4, l),
		"shield": sh, "shield_regen": shr,
		"energy": maxf(energy, 40.0), "energy_regen": eregen,
		"pwr_gen": gen, "pwr_use": use,
		"dps": dps, "guns": guns, "wdmg_mult": 1.0,
		"cells": bp_cells(bp).size(), "modules": bp.mods.size(),
	}

func _calibrate() -> void:
	var st := bp_stats(template_bp(START_TEMPLATE))
	_turn_ref = float(st.turn_raw)
	_strafe_ref = float(st.strafe_raw)

## Wert aller kaufpflichtigen Module
func bp_value(bp: Dictionary) -> int:
	var v := 0
	for m in bp.mods:
		v += int(MODULES[m[0]].price)
	return v

func inv_count(id: String) -> int:
	return int(s.inv.get(id, 0))

func inv_add(id: String, n: int) -> void:
	var v := inv_count(id) + n
	if v <= 0:
		s.inv.erase(id)
	else:
		s.inv[id] = v

## Was kostet es, die Blaupause bp hier zu bauen? shop_tier = Ausstattung der Werft
func build_plan(bp: Dictionary, shop_tier: int) -> Dictionary:
	var need := bp_counts(bp)
	var have := bp_counts(s.bp)
	var missing := {}
	var cost := 0
	var locks := []
	var rk := rank()
	for id in need:
		var d: Dictionary = MODULES[id]
		if int(d.price) == 0:
			continue
		var m: int = int(need[id]) - int(have.get(id, 0)) - inv_count(id)
		if m > 0:
			missing[id] = m
			cost += m * int(d.price)
			if int(d.rank) > rk:
				locks.append("%s erst ab Rang %s" % [d.n, rank_name(int(d.rank))])
			elif int(d.tier) > shop_tier:
				locks.append("%s gibt es hier nicht" % d.n)
	# Montage: je verändertem Modul
	var old := {}
	for m in s.bp.mods:
		old["%s|%d|%d" % m] = true
	var changed := 0
	for m in bp.mods:
		if not old.has("%s|%d|%d" % m):
			changed += 1
	var fee := changed * 40
	return {"missing": missing, "cost": cost, "fee": fee, "total": cost + fee, "locks": locks, "changed": changed}

## Baut die Blaupause: alte Module ins Lager, neue aus dem Lager oder gekauft
func apply_build(bp: Dictionary, plan: Dictionary) -> void:
	for id in bp_counts(s.bp):
		if int(MODULES[id].price) > 0:
			inv_add(id, int(bp_counts(s.bp)[id]))
	for id in plan.missing:
		inv_add(id, int(plan.missing[id]))
	var need := bp_counts(bp)
	for id in need:
		if int(MODULES[id].price) > 0:
			inv_add(id, -int(need[id]))
	s.credits = int(s.credits) - int(plan.total)
	s.bp = copy_bp(bp)

const TUNE_MAX := 5
const TUNE_TEXT := {"cockpit": "+8 % Hülle", "hull": "+8 % Hülle", "engine": "+6 % Schub, +4 % Spitze", "rcs": "+5 % Wendigkeit", "weapon": "+7 % Schaden",
	"shield": "+8 % Kapazität, +6 % Aufladung", "cargo": "+10 % Frachtraum", "armor": "+10 % Panzerung", "power": "+10 % Leistung und Energie"}

func tunable(id: String) -> bool:
	return TUNE_TEXT.has(String(MODULES[id].cat))

func tune_level(id: String) -> int:
	return int(s.tune.get(id, 0))

func tune_cost(id: String) -> int:
	var lvl := tune_level(id)
	var base := maxf(300.0, float(MODULES[id].price) * 0.25)
	return roundi(base * pow(float(lvl + 1), 1.5) / 50.0) * 50

## Stärkstes Triebwerk der Blaupause
func main_engine(bp: Dictionary) -> String:
	var best := "funke"
	var bt := -1.0
	for m in bp.mods:
		var d: Dictionary = MODULES[m[0]]
		if d.cat == "engine" and float(d.thrust) > bt:
			bt = float(d.thrust)
			best = m[0]
	return best

func flame_color(paint: Dictionary, engine_id: String) -> Color:
	for f in FLAMES:
		if f.id == paint.flame and f.c != "":
			return Color.html(f.c)
	return Color.html(MODULES[engine_id].flame)

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

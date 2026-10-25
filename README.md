# Frachtpilot

3D-Raumfrachter-Simulator für Android, gebaut mit Godot 4.7.

Inspiriert von Freelancer: Du läufst in Ego-Sicht über Stationsdecks und durch dein eigenes Schiff, nimmst Fracht- und Kopfgeldaufträge an, fliegst durch drei Sternsysteme und kämpfst gegen Piraten.

- **Universum:** Sol-7 (sicher), Vega-Tiefe (Industrie), Nyx-Grenze (gesetzlos) – verbunden durch Sprungtore, innerhalb der Systeme Handelsrouten-Ringe.
- **Laufen:** Station mit hoher Promenade, Galerie und Panoramafenster (mit dem Planeten des Systems), Bar und begehbarem Hangar, in dem das eigene Schiff in Originalgröße steht. Gegliederte Menschen mit Animation, Drohnen, Putz-, Lade-, Schweiß- und Servo-Roboter. Begehbares Schiff mit Cockpit, Konsolen pro Bauteil-Slot, Laderaum und Maschinenraum.
- **Schiffsbau mit Blaupause:** Das Schiff wird Modul für Modul auf einem Raster (9 × 15 Felder à 2 m) entworfen: Cockpits, Rumpfsegmente, Bugkeile, Triebwerke, Lagedüsen, Waffen, Schilde, Reaktoren, Frachtmodule, Panzerplatten, Flügel/Leitwerke und Systeme – rund 40 Module. Regeln: ein Cockpit, alles verbunden, Abgasstrahl hinter Triebwerken und Schussfeld vor Waffen frei, genug Leistung. Masse, Schwerpunkt und Trägheit bestimmen Beschleunigung und Wendigkeit. Spiegeln, Rückgängig, Vorlagen (Spatz, Lastesel, Pfeil, Kondor, Hornisse), eigene Blaupausen speichern. Gebaut wird am Konstruktionstisch im Hangar; fehlende Module werden gekauft, ausgebaute landen im Lager. Das 3D-Modell entsteht aus der Blaupause.
- **Tuning:** Jeder Modultyp hat 5 Tuning-Stufen beim Mechanik-Roboter R-7.
- **Kampf:** Zielhilfe wie in Freelancer, Energie, Schilde, KI-Piraten (Angriff, Ausweichen, Flucht), Kopfgeldjagd, Explosionen.
- **Zerstörung:** Respawn im Basisschiff an der letzten Station; die gekauften Module treiben im Wrack und können geborgen werden – Plünderer inklusive. Der Bauplan bleibt als Blaupause erhalten.
- **Fortschritt:** Ränge, Lieferserie, gesperrte Aufträge und Teile als Ziele.

## APK bekommen

Bei jedem Push auf `main` baut GitHub Actions automatisch eine APK:
**Actions → „Android-APK bauen“ → letzter Lauf → Artifacts → frachtpilot-apk**

Damit Updates ohne Neuinstallation klappen, braucht das Repo zwei Secrets mit einem festen Signierschlüssel:
`KEYSTORE_BASE64` (Keystore als Base64, Alias `frachtpilot`) und `KEYSTORE_PASSWORD`.
Ohne Secrets wird bei jedem Lauf ein neuer Wegwerf-Schlüssel erzeugt.

## Aufbau

| Pfad | Inhalt |
|---|---|
| `scripts/game.gd` | Autoload: Module, Vorlagen, Blaupausen-Prüfung und -Werte, Ränge, Lacke, Fracht, Spielstand |
| `scripts/blueprint_ui.gd` | Blaupausen-Editor (Raster, Module, Werte, Pläne, Bauen) |
| `scripts/touch_scroll.gd` | zuverlässiges Wischen in Listen mit Schwung |
| `scripts/universe.gd` | Sternenkarte: Systeme, Stationen, Tore, Routen, Gefahrenzonen |
| `scripts/ship_state.gd`, `npc.gd` | Schiffszustand, Schaden, Vorhalt; KI für Piraten und Händler |
| `scripts/combat.gd` | Geschosse, Treffer, Explosionen |
| `scripts/interior.gd`, `walker.gd`, `walk_hud.gd` | begehbare Innenräume, Spielfigur, Lauf-Oberfläche |
| `scripts/actor.gd` | Menschen und Roboter mit prozeduraler Animation |
| `scripts/main.gd` | Spielablauf, Flugphysik, Andocken, Werft-Aktionen, Kamera |
| `scripts/ship_builder.gd` | baut das 3D-Schiff aus der Blaupause |
| `scripts/space_world.gd` | Himmel, Sonne, Planet, Mond, Stationen, Asteroiden, Staub |
| `scripts/hangar.gd` | Werfthalle mit Drehteller |
| `scripts/hud.gd` | Flug-HUD und Touch-Steuerung |
| `scripts/station_ui.gd` | Gesprächsfenster: Aufträge, Bar, Ausrüster, Lackiererei, Schiffskonsole |
| `scripts/geo.gd` | Geometrie-Baukasten (gefaste Kästen, Zylinder, Tori) |
| `shaders/` | Rumpflack, Metall, Innenräume, Himmel, Planet, Atmosphäre, Triebwerk, Staub, Hallenboden |
| `textures/`, `tools/gen_textures.py` | selbst erzeugte PBR-Detailtexturen (Normal-Maps, Hohlraum, Rauheit) |
| `tests/autotest.tscn` | automatischer Rundgang mit Screenshots |

## Lokal testen

```
godot --path . res://tests/autotest.tscn   # SHOT_DIR=/pfad für Screenshots
```

Schriften: Chakra Petch und IBM Plex Mono (SIL Open Font License, siehe `fonts/`).

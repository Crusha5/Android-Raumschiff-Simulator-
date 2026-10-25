# Frachtpilot

3D-Raumfrachter-Simulator für Android, gebaut mit Godot 4.7.

Du fliegst einen kleinen Frachter im System Sol-7, nimmst an Stationen Aufträge an, dockst an der Zielstation an und kassierst den Lohn. In der Werft tauschst du Rumpf, Triebwerk, Düsen, Frachtmodul, Panzerung und Extras. Jedes Teil ist am Schiff sichtbar und ändert das Flugverhalten. In der Lackiererei wählst du Farben, Muster und Triebwerksfarbe. Ränge schalten neue Teile und Aufträge frei, Lieferungen ohne Kratzer erhöhen den Serienbonus.

## APK bekommen

Bei jedem Push auf `main` baut GitHub Actions automatisch eine APK:
**Actions → „Android-APK bauen“ → letzter Lauf → Artifacts → frachtpilot-apk**

Damit Updates ohne Neuinstallation klappen, braucht das Repo zwei Secrets mit einem festen Signierschlüssel:
`KEYSTORE_BASE64` (Keystore als Base64, Alias `frachtpilot`) und `KEYSTORE_PASSWORD`.
Ohne Secrets wird bei jedem Lauf ein neuer Wegwerf-Schlüssel erzeugt.

## Aufbau

| Pfad | Inhalt |
|---|---|
| `scripts/game.gd` | Autoload: Bauteile, Ränge, Lacke, Fracht, Spielstand |
| `scripts/main.gd` | Spielablauf, Flugphysik, Andocken, Werft-Aktionen, Kamera |
| `scripts/ship_builder.gd` | baut das Schiff aus den eingebauten Teilen |
| `scripts/space_world.gd` | Himmel, Sonne, Planet, Mond, Stationen, Asteroiden, Staub |
| `scripts/hangar.gd` | Werfthalle mit Drehteller |
| `scripts/hud.gd` | Flug-HUD und Touch-Steuerung |
| `scripts/station_ui.gd` | Stationsmenü: Fracht, Werft, Lackiererei |
| `scripts/geo.gd` | Geometrie-Baukasten (gefaste Kästen, Zylinder, Tori) |
| `shaders/` | Rumpflack, Himmel, Planet, Atmosphäre, Triebwerk, Staub, Hallenboden |
| `tests/autotest.tscn` | automatischer Rundgang mit Screenshots |

## Lokal testen

```
godot --path . res://tests/autotest.tscn   # SHOT_DIR=/pfad für Screenshots
```

Schriften: Chakra Petch und IBM Plex Mono (SIL Open Font License, siehe `fonts/`).

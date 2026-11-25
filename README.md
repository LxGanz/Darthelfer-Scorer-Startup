# Scorer-Startscript

Startet auf einem Linux-Rechner (X11) die Dart-Scorer-Seite <https://scorer.darthelfer.de/>:

1. Touchscreen einrichten (dem richtigen Monitor zuordnen, optional um 180° gedreht)
2. Firefox mit der Seite auf dem Touch-Monitor öffnen
3. Den Knopf auf der Seite klicken (per Beschriftung oder CSS-Selektor, **nicht** per Pixelposition)
4. Das dadurch geöffnete zweite Fenster auf den anderen Monitor verschieben und in den Vollbildmodus schalten

## Installation

```bash
sudo apt install xdotool x11-xserver-utils x11-utils xinput python3-venv
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

Selenium lädt den passenden `geckodriver` beim ersten Start selbst herunter (Internet nötig).
Alternativ `geckodriver` manuell installieren und in den `PATH` legen.

> **Hinweis Ubuntu:** Die Snap-Version von Firefox arbeitet schlecht mit `geckodriver` zusammen.
> Wenn Firefox nicht startet, die .deb-Version von Mozilla verwenden.

## Einrichtung

1. `config.env` prüfen: Monitornamen (`xrandr`), Touchscreen-Name (`xinput list`).
2. Knopf finden: `BUTTON_TEXT` und `BUTTON_SELECTOR` leer lassen und `./startup.sh` starten.
   Das Script listet alle klickbaren Elemente der Seite auf. Die passende Beschriftung
   dann bei `BUTTON_TEXT` eintragen (oder per Entwicklerwerkzeuge einen CSS-Selektor bei `BUTTON_SELECTOR`).
3. Erneut starten.

Eigene Anpassungen, die nicht ins Git sollen, in `config.local.env` ablegen (überschreibt `config.env`).

## Autostart

Beispiel `~/.config/autostart/scorer.desktop`:

```ini
[Desktop Entry]
Type=Application
Name=Scorer
Exec=/pfad/zu/scorer-startup/startup.sh
```

## Hinweise

- Das Script bleibt laufen, solange der Browser offen ist. Wird es beendet, schließt sich Firefox.
- `TOUCH_ROTATE_180`: Ist die Berührung nach dem Start seitenverkehrt, den Wert in `config.env` umstellen (1 ↔ 0).
- Das alte Script liegt zum Vergleich in `legacy/`.

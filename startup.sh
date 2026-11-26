#!/bin/bash
# Startscript: richtet den Touchscreen ein, startet Firefox, klickt den Knopf
# auf der Scorer-Seite und schiebt das neu geöffnete Fenster im Vollbild auf den zweiten Monitor.
# Danach beendet sich das Script; Firefox läuft weiter.
set -u

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DISPLAY="${DISPLAY:-:0}"

# shellcheck source=config.env
source "$DIR/config.env"
# Optionale lokale Überschreibungen (nicht im Git)
[ -f "$DIR/config.local.env" ] && source "$DIR/config.local.env"

log() { echo "[$(date +%T)] $*"; }
die() { log "FEHLER: $*" >&2; exit 1; }

# Geometrie eines Monitors als "x y breite hoehe" (leer, wenn nicht angeschlossen)
monitor_geometry() {
    local g
    g=$(xrandr | grep -oP "^$1 connected (primary )?\K[0-9]+x[0-9]+\+[0-9]+\+[0-9]+") || return 0
    # "1920x1080+1920+0" -> "1920 1080 1920 0" -> umsortieren zu "x y w h"
    read -r w h x y <<< "$(echo "$g" | tr 'x+' '  ')"
    echo "$x $y $w $h"
}

# Auf X-Server warten und Bildschirm nie abschalten
until xset q >/dev/null 2>&1; do sleep 1; done
xset s off -dpms s noblank

# Auf den Touch-Monitor warten (Monitore sind direkt nach dem Login manchmal noch nicht bereit)
TOUCH_GEOM=""
for _ in $(seq 1 30); do
    TOUCH_GEOM=$(monitor_geometry "$TOUCH_OUTPUT")
    [ -n "$TOUCH_GEOM" ] && break
    sleep 1
done
[ -n "$TOUCH_GEOM" ] || die "Monitor $TOUCH_OUTPUT nicht gefunden (siehe 'xrandr')"

# Zielmonitor für das zweite Fenster
if [ -z "$TARGET_OUTPUT" ]; then
    TARGET_OUTPUT=$(xrandr | awk -v t="$TOUCH_OUTPUT" '$2=="connected" && $1!=t {print $1; exit}')
fi
[ -n "$TARGET_OUTPUT" ] || die "Kein zweiter Monitor gefunden"
TARGET_GEOM=$(monitor_geometry "$TARGET_OUTPUT")
[ -n "$TARGET_GEOM" ] || die "Monitor $TARGET_OUTPUT nicht gefunden"
log "Touch-Monitor $TOUCH_OUTPUT: $TOUCH_GEOM | Ziel-Monitor $TARGET_OUTPUT: $TARGET_GEOM"

# --- Touchscreen einrichten ---
DEVICE_ID=$(xinput list | awk -v n="$TOUCH_NAME" 'index($0,n){
    for(i=1;i<=NF;i++) if($i ~ /^id=/){ sub("id=","",$i); print $i }
}' | sort -n | head -n1)

if [ -z "$DEVICE_ID" ]; then
    log "WARNUNG: Touchscreen '$TOUCH_NAME' nicht gefunden"
else
    # Wichtig: map-to-output setzt die Matrix selbst. Eine vorher gesetzte Drehung ginge verloren,
    # deshalb wird die Matrix (Monitor-Zuordnung + Drehung) hier in einem Schritt berechnet.
    xinput map-to-output "$DEVICE_ID" "$TOUCH_OUTPUT"
    if [ "$TOUCH_ROTATE_180" = "1" ]; then
        read -r TW TH <<< "$(xdpyinfo | awk '/dimensions:/{split($2,a,"x"); print a[1], a[2]}')"
        read -r X Y W H <<< "$TOUCH_GEOM"
        MATRIX=$(awk -v w="$W" -v h="$H" -v ox="$X" -v oy="$Y" -v tw="$TW" -v th="$TH" 'BEGIN{
            c0=w/tw; c1=h/th; c2=ox/tw; c3=oy/th;
            printf "%f 0 %f 0 %f %f 0 0 1", -c0, c0+c2, -c1, c1+c3
        }')
        xinput set-prop "$DEVICE_ID" "Coordinate Transformation Matrix" $MATRIX
    fi
    log "Touchscreen eingerichtet (ID $DEVICE_ID)"
fi

# --- Firefox starten ---
# -marionette erlaubt dem Python-Script, sich kurz anzudocken. Firefox gehört diesem Script nicht
# (setsid), läuft also weiter, wenn das Script fertig ist.
mkdir -p "$FIREFOX_PROFILE"
setsid firefox -marionette -no-remote -profile "$FIREFOX_PROFILE" --new-window "$URL" >/dev/null 2>&1 &

# --- Knopf klicken, zweites Fenster verschieben, danach beenden ---
PY="$DIR/.venv/bin/python"
[ -x "$PY" ] || PY="python3"

ARGS=(--url "$URL" --touch-geom "$TOUCH_GEOM" --target-geom "$TARGET_GEOM" --timeout "$TIMEOUT")
[ -n "$BUTTON_TEXT" ] && ARGS+=(--button-text "$BUTTON_TEXT")
[ -n "$BUTTON_SELECTOR" ] && ARGS+=(--button-selector "$BUTTON_SELECTOR")
[ "${KEEP_RUNNING:-0}" = "1" ] && ARGS+=(--keep-running)

# Optional: Mauszeiger ausblenden (sudo apt install unclutter)
# unclutter -idle 1 -root &

exec "$PY" "$DIR/scorer_launcher.py" "${ARGS[@]}"

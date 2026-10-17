#!/bin/bash
# Spence – lokaler Server (einfach doppelklicken)
# PHP-Server über public/ mit der Schnittstelle api/ und der lokalen Datenbank app/spence.db.
# Die Schrift kommt aus der gemeinsamen Ablage aller Werkzeuge (~/Sites/alltagstudio/public/fonts).

cd "$(dirname "$0")" || exit 1

PORT=8750
PIDFILE=".spence-server.pid"
LOG="starten.log"
URL="http://127.0.0.1:${PORT}/"
DB="app/spence.db"
SICHERUNGEN="app/sicherungen"
SCHRIFT="$(cd .. && pwd)/alltagstudio/public/fonts"

log(){ echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"; }

fail(){
  echo ""
  echo "FEHLER: $1"
  echo ""
  echo "Dieses Fenster bleibt offen, damit du die Meldung lesen kannst."
  echo "Mit Enter schliessen."
  log "FEHLER: $1"
  read -r _
  exit 1
}

echo "=== Spence starten ==="
log "Start angefordert (Port ${PORT})"

# Interpreter suchen: PHP mit SQLite – zuerst das aus MAMP (wie bei klog), sonst das im Pfad
PHP=""
for KANDIDAT in /Applications/MAMP/bin/php/php8.2*/bin/php /Applications/MAMP/bin/php/php8.*/bin/php "$(command -v php 2>/dev/null)"; do
  if [ -x "$KANDIDAT" ] && "$KANDIDAT" -r 'exit(extension_loaded("pdo_sqlite") && PHP_VERSION_ID >= 80000 ? 0 : 1);' 2>/dev/null; then
    PHP="$KANDIDAT"; break
  fi
done
if [ -z "$PHP" ]; then
  fail "Kein PHP 8 mit SQLite gefunden. Bitte MAMP installieren (mamp.info, kostenlos) – es bringt PHP 8.2 mit – und danach erneut doppelklicken."
fi
log "PHP: ${PHP}"

# Gemeinsame Schrift vorhanden?
if [ ! -f "${SCHRIFT}/Antique-Legacy-Light.woff2" ]; then
  echo "Hinweis: Die gemeinsame Schrift fehlt unter ${SCHRIFT} – Spence zeigt dann die Systemschrift."
  log "Hinweis: Schrift fehlt unter ${SCHRIFT}"
fi

# Einen bereits laufenden EIGENEN Server neu starten
if [ -f "$PIDFILE" ]; then
  OLDPID="$(cat "$PIDFILE" 2>/dev/null)"
  if [ -n "$OLDPID" ] && kill -0 "$OLDPID" 2>/dev/null; then
    echo "Beende vorherigen Spence-Server (PID ${OLDPID}) ..."
    kill "$OLDPID" 2>/dev/null
    sleep 1
    log "Vorherigen eigenen Server beendet (PID ${OLDPID})"
  fi
  rm -f "$PIDFILE"
fi

# Port noch belegt? Dann durch ein FREMDES Programm -> nicht abschiessen, nur melden
BUSYPID="$(lsof -ti tcp:${PORT} -sTCP:LISTEN 2>/dev/null | head -1)"
if [ -n "$BUSYPID" ]; then
  NAME="$(ps -p "$BUSYPID" -o comm= 2>/dev/null)"
  fail "Port ${PORT} ist von einem anderen Programm belegt (PID ${BUSYPID}, ${NAME}). Bitte dieses Programm beenden oder im Script oben einen anderen PORT eintragen."
fi

# Lokale Daten sichern (die letzten 20 Stände bleiben)
mkdir -p app
if [ -f "$DB" ]; then
  mkdir -p "$SICHERUNGEN"
  ZIEL="${SICHERUNGEN}/spence-$(date '+%Y%m%d-%H%M%S').db"
  if "$PHP" -r '$d=new PDO("sqlite:".$argv[1]); $d->exec("VACUUM INTO ".$d->quote($argv[2]));' "$DB" "$ZIEL" 2>>"$LOG"; then
    echo "Daten gesichert: ${ZIEL}"
    log "Daten gesichert: ${ZIEL}"
  else
    fail "Sicherung von ${DB} fehlgeschlagen – Server nicht gestartet. Details siehe ${LOG}."
  fi
  ls -1t "$SICHERUNGEN"/spence-*.db 2>/dev/null | tail -n +21 | while read -r ALT; do rm -f "$ALT"; done
fi

# Server starten
echo "Starte Server ..."
SPENCE_SCHRIFT="$SCHRIFT" "$PHP" -S "127.0.0.1:${PORT}" -t public dev-router.php >/dev/null 2>&1 &
SRVPID=$!
echo "$SRVPID" > "$PIDFILE"
sleep 1
if ! kill -0 "$SRVPID" 2>/dev/null; then
  fail "Server konnte nicht starten. Details siehe ${LOG}."
fi
log "Server gestartet (PID ${SRVPID}) auf ${URL}"

# Im Browser oeffnen
open "$URL" 2>/dev/null

echo ""
echo "Spence laeuft."
echo "   Adresse:       ${URL}"
echo "   Projektordner: $(pwd)"
echo "   Daten:         $(pwd)/${DB}"
echo "   Logdatei:      $(pwd)/${LOG}"
echo ""
echo "   Beenden mit Strg-C."
echo ""

# Sauber aufraeumen beim Beenden
trap 'echo ""; echo "Server wird beendet ..."; kill "$SRVPID" 2>/dev/null; rm -f "$PIDFILE"; log "Server beendet (PID '"${SRVPID}"')"; exit 0' INT TERM

# Vordergrund halten, bis Strg-C
wait "$SRVPID"

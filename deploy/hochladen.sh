#!/bin/sh
# Spence — dist zusammenstellen und auf spence.alltag.tools laden
# (scp über SFTP, Schlüssel aus ~/.ssh/config für den Server).
#
# Das Ziel steht NICHT im Repo, sondern in deploy/spence.ziel (per .gitignore
# ausgeschlossen), erste Zeile der Projektordner auf dem Server:
#   benutzer@server.example.com:/home/benutzer/alltag.tools/spence/
# zweite Zeile der SSH-Port (Namecheap: 21098). Optional SPENCE_ZIEL und
# SPENCE_PORT als Umgebungsvariablen statt der Datei.
#
# Auf dem Server (neben Braille, aufgeteilt wie kvist und klog):
#   alltag.tools/spence/public/   Web-Wurzel der Subdomain – wird hier hochgeladen
#   alltag.tools/spence/app/      Datenbank spence.db – legt api/ selbst an; hier geht nur
#                                 eine .htaccess hin, die alles sperrt, die Datenbank NIE
# Der Schutz von public/api/ kommt aus cPanel „Directory Privacy"; cPanel schreibt
# dafür public/api/.htaccess – darum liefert dieses Skript dort keine .htaccess aus.
set -e
cd "$(dirname "$0")/.."
ZIEL="${SPENCE_ZIEL:-$(sed -n 1p deploy/spence.ziel 2>/dev/null || true)}"
PORT="${SPENCE_PORT:-$(sed -n 2p deploy/spence.ziel 2>/dev/null || true)}"
PORT="${PORT:-22}"
if [ -z "$ZIEL" ]; then
  echo "Kein Ziel: deploy/spence.ziel anlegen (benutzer@server:/pfad/) oder SPENCE_ZIEL setzen." >&2
  exit 1
fi
HOST="${ZIEL%%:*}"
PFAD="${ZIEL#*:}"; PFAD="${PFAD%/}"

# Schnittstelle prüfen, bevor etwas hochgeht
for P in /Applications/MAMP/bin/php/php8.2*/bin/php "$(command -v php 2>/dev/null)"; do [ -x "$P" ] && PHP="$P" && break; done
if [ -n "$PHP" ]; then "$PHP" -l public/api/index.php >/dev/null || { echo "public/api/index.php hat Syntaxfehler — nicht hochgeladen." >&2; exit 1; }; fi

# dist: public/ kopieren, die Schrift auf die gemeinsame Ablage umstellen
DIST=dist/public
rm -rf dist
mkdir -p "$DIST"
cp -R public/. "$DIST"/
find dist -name .DS_Store -delete
rm -f "$DIST/api/.htaccess"
# Im Repo lädt die Seite fonts/… (lokal liefert dev-router.php sie aus der gemeinsamen
# Ablage); auf dem Server kommt dieselbe Datei für alle Werkzeuge von alltag.studio.
sed -i '' 's#url("fonts/#url("https://alltag.studio/fonts/#g' "$DIST/index.html"
if grep -q 'url("fonts/' "$DIST/index.html" || [ "$(grep -c 'https://alltag.studio/fonts/' "$DIST/index.html")" -lt 2 ]; then
  echo "Schrift-Adressen in index.html nicht wie erwartet — bitte prüfen." >&2; exit 1
fi

# Apache/LiteSpeed (Namecheap): HTTPS erzwingen, nicht indexieren, Datenbank nie
# ausliefern; Seite und Manifest nicht cachen (ändern sich mit jedem Hochladen), Icons eine Woche.
cat > "$DIST/.htaccess" <<'HTACCESS'
RewriteEngine On
RewriteCond %{HTTPS} !=on
RewriteRule ^ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]

Options -Indexes
DirectoryIndex index.html index.php

AddType application/manifest+json .webmanifest
AddType image/svg+xml .svg

<FilesMatch "\.(db|db-wal|db-shm|sqlite|sql)$">
  Require all denied
</FilesMatch>

<IfModule mod_headers.c>
  Header set X-Robots-Tag "noindex, nofollow, noarchive"
  Header set X-Content-Type-Options "nosniff"
  Header set Referrer-Policy "strict-origin-when-cross-origin"
  <FilesMatch "\.(png|svg)$">
    Header set Cache-Control "public, max-age=604800"
  </FilesMatch>
  <FilesMatch "\.(html|webmanifest)$">
    Header set Cache-Control "no-cache"
  </FilesMatch>
</IfModule>

<IfModule mod_deflate.c>
  AddOutputFilterByType DEFLATE text/html text/plain text/css application/javascript application/json application/manifest+json image/svg+xml
</IfModule>
HTACCESS
printf 'User-agent: *\nDisallow: /\n' > "$DIST/robots.txt"

# LiteSpeed braucht welt-lesbar, aber nicht gruppen-/welt-schreibbar (sonst 403)
find "$DIST" -type f -exec chmod 644 {} \;
find "$DIST" -type d -exec chmod 755 {} \;

# Ordner anlegen, falls es der erste Upload ist (bestehende bleiben, wie sie sind)
printf -- '-mkdir %s\n-mkdir %s/public\n-mkdir %s/app\nchmod 755 %s/app\n' "$PFAD" "$PFAD" "$PFAD" "$PFAD" \
  | sftp -q -o BatchMode=yes -P "$PORT" -b - "$HOST" >/dev/null 2>&1
# Der Namecheap-Webspace hat SFTP, aber keine Shell — rsync braucht eine.
# scp läuft über SFTP; es löscht nichts auf dem Server und rührt app/ nicht an.
scp -r -p -o BatchMode=yes -P "$PORT" "$DIST"/. "$HOST:$PFAD/public/"
# Zweite Absicherung: app/ liegt außerhalb der Web-Wurzel; zeigt alltag.tools selbst
# einmal auf den Sammelordner, sperrt diese Datei trotzdem jeden Zugriff.
printf 'Require all denied\n' > dist/app.htaccess && chmod 644 dist/app.htaccess
scp -p -o BatchMode=yes -P "$PORT" dist/app.htaccess "$HOST:$PFAD/app/.htaccess"
echo "Hochgeladen nach $HOST:$PFAD/public/ — https://spence.alltag.tools/"

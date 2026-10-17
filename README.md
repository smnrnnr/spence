# Spence

Was Dinge im Alltag kosten und wann sie leer sind: Verschleiß (Zahnbürste), Langlebiges (Jacke),
Verbrauch (Haferflocken). Eine Web-App für Handy und Rechner, auf dem Homescreen wie eine App.

Läuft auf **https://spence.alltag.tools/** (Namecheap-Webspace, wie Braille, klog und kvist).

## Aufbau

| Ordner / Datei | Was |
|---|---|
| `public/` | Web-Wurzel: `index.html` (die ganze App), Manifest, Icons |
| `public/api/index.php` | Schnittstelle: liest und schreibt die zwei Dokumente `items` und `cats` |
| `app/spence.db` | SQLite-Datenbank, **eine Ebene über** `public/` – nie per URL erreichbar, nicht im Repo |
| `dev-router.php` | nur lokal: liefert `/fonts/` aus der gemeinsamen Schrift-Ablage und `api/` |
| `starten.command` | Doppelklick: lokaler Server unter <http://127.0.0.1:8750/> |
| `deploy/hochladen.sh` | `public/` auf den Server laden |
| `deploy/einspielen.py` | Daten einmalig über die Schnittstelle einspielen (z. B. den Supabase-Export) |

Kein Build. Die Datei im Repo ist die eine Wahrheit; nur beim Hochladen wird die Schrift-Adresse umgeschrieben.

## Schnittstelle

`api/?t=items` und `api/?t=cats` liefern `{data, rev}`; ein POST mit `{data}` speichert das ganze Dokument.
`api/?t=stand` liefert nur die Stände (`rev`) – die App fragt das beim Öffnen, beim Zurückwechseln und alle
30 Sekunden ab und lädt nur nach, was sich geändert hat. Jede Speicherung legt die vorige Fassung in der
Tabelle `verlauf` ab (die letzten 200 je Dokument).

Bis Oktober 2026 lagen die Daten in Supabase. Das Gratis-Projekt wurde nach einer Woche ohne Zugriffe pausiert;
darum der eigene Speicher.

## Schutz

Nur der Ordner `public/api/` ist geschützt, per cPanel **Directory Privacy** (cPanel schreibt dafür
`public/api/.htaccess` und die `.htpasswd` – `hochladen.sh` liefert dort bewusst keine `.htaccess` aus).
Die Seite selbst bleibt offen, weil eine Homescreen-App auf dem iPhone mit dem Kennwort-Dialog des Browsers
schlecht zurechtkommt. Stattdessen fragt Spence bei einer 401 einmal nach Name und Kennwort, merkt sie sich
im Gerät (`localStorage`) und schickt sie bei jedem Abruf mit. Lokal gibt es keinen Schutz.

## Schrift

Antique Legacy liegt **einmal** für alle Werkzeuge: lokal in `~/Sites/alltagstudio/public/fonts`, auf dem
Server unter `https://alltag.studio/fonts/`. Die `.htaccess` dort gibt die Dateien für alltag.studio,
alltag.tools und ihre Subdomains frei (CORS), für fremde Seiten nicht. Spence hat keine eigene Kopie.

## Lokal

`starten.command` doppelklicken. Es sucht PHP 8 mit SQLite (MAMP), sichert `app/spence.db` nach
`app/sicherungen/` (die letzten 20) und öffnet die App.

## Veröffentlichen

Einmalig:

1. cPanel → **Domains** → `spence.alltag.tools`, Häkchen „Share document root" entfernen,
   Document Root `alltag.tools/spence/public` (neben `alltag.tools/braille`).
2. `deploy/spence.ziel` anlegen (liegt nicht im Repo):
   ```
   benutzer@server.example.com:/home/benutzer/alltag.tools/spence/
   21098
   ```
3. `deploy/hochladen.sh` – legt `spence/public` und `spence/app` an, lädt `public/` hoch und sperrt `app/` per `.htaccess`.
4. cPanel → **Directory Privacy** → `alltag.tools/spence/public/api` → schützen, Benutzer anlegen.
5. Daten einspielen: `python3 deploy/einspielen.py https://spence.alltag.tools items.json cats.json`.
6. Auf dem Handy `https://spence.alltag.tools` öffnen, anmelden, neu zum Homescreen hinzufügen.

Danach bei jeder Änderung nur `deploy/hochladen.sh`. Die Datenbank in `spence/app/` wird nie überschrieben.

## Sicherung

Auf dem Server liegt alles in `alltag.tools/spence/app/spence.db`; die cPanel-Sicherung erfasst den Ordner mit.
Von Hand: die Datei per SFTP herunterladen (vorher am besten keine App offen haben).

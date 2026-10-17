<?php
declare(strict_types=1);

/**
 * Spence – JSON-Schnittstelle zur eigenen SQLite-Datenbank (ersetzt Supabase).
 *
 * Spence hält genau zwei Dokumente: `items` (alle Dinge) und `cats` (die
 * Kategorien). Beide werden als Ganzes gelesen und geschrieben, wie bisher in
 * Supabase. Aufruf immer über  api/?t=<name>
 *
 *   GET   api/?t=items | cats   – {data, rev}; data ist null, solange nichts gespeichert ist
 *   GET   api/?t=stand          – {items: rev, cats: rev} – billiger Poll
 *   POST  api/?t=items | cats   – Body {data}; speichert, gibt {rev} zurück
 *
 * `rev` zählt jede Speicherung hoch. Ändert sich der Stand nicht, muss der Poll
 * keine Daten holen. Jede Speicherung legt die vorige Fassung in `verlauf` ab
 * (die letzten 200 je Dokument) – ein Netz, falls ein Gerät mit altem Stand
 * etwas überschreibt.
 *
 * Schutz: der Ordner api/ wird auf dem Server per cPanel „Directory Privacy"
 * (.htaccess + .htpasswd) geschützt; hier steckt bewusst keine Kennwort-Logik.
 * Die Datenbank liegt in app/, eine Ebene über der Web-Wurzel public/.
 */

const DOKUMENTE = ['items', 'cats'];
const MAX_BYTES = 2 * 1024 * 1024;
const VERLAUF   = 200;

date_default_timezone_set('Europe/Berlin');

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
header('X-Robots-Tag: noindex, nofollow');

function antwort(array $daten, int $code = 200): void {
  http_response_code($code);
  echo json_encode($daten, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
  exit;
}

function db(): PDO {
  $ordner = dirname(__DIR__, 2) . '/app';
  if (!is_dir($ordner) && !mkdir($ordner, 0755, true)) antwort(['fehler' => 'Ordner app/ fehlt und lässt sich nicht anlegen.'], 500);
  $pdo = new PDO('sqlite:' . $ordner . '/spence.db', null, null, [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
  $pdo->exec('PRAGMA journal_mode = WAL; PRAGMA busy_timeout = 5000;');
  $pdo->exec('CREATE TABLE IF NOT EXISTS dokumente (
    name TEXT PRIMARY KEY, daten TEXT NOT NULL, rev INTEGER NOT NULL, geaendert_am TEXT NOT NULL)');
  $pdo->exec('CREATE TABLE IF NOT EXISTS verlauf (
    id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, daten TEXT NOT NULL, rev INTEGER NOT NULL, gesichert_am TEXT NOT NULL)');
  return $pdo;
}

$t = $_GET['t'] ?? '';
try {
  $pdo = db();

  if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    if ($t === 'stand') {
      $stand = array_fill_keys(DOKUMENTE, 0);
      foreach ($pdo->query('SELECT name, rev FROM dokumente') as $z) $stand[$z['name']] = (int)$z['rev'];
      antwort($stand);
    }
    if (!in_array($t, DOKUMENTE, true)) antwort(['fehler' => 'Unbekanntes Dokument.'], 400);
    $q = $pdo->prepare('SELECT daten, rev FROM dokumente WHERE name = ?');
    $q->execute([$t]);
    $z = $q->fetch(PDO::FETCH_ASSOC);
    antwort($z ? ['data' => json_decode($z['daten'], true), 'rev' => (int)$z['rev']] : ['data' => null, 'rev' => 0]);
  }

  if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (!in_array($t, DOKUMENTE, true)) antwort(['fehler' => 'Unbekanntes Dokument.'], 400);
    $roh = file_get_contents('php://input', false, null, 0, MAX_BYTES + 1);
    if ($roh === false || strlen($roh) > MAX_BYTES) antwort(['fehler' => 'Zu groß.'], 413);
    $body = json_decode($roh, true);
    if (!is_array($body) || !array_key_exists('data', $body) || !is_array($body['data'])) antwort(['fehler' => 'Erwartet {data: […]}.'], 400);

    $jetzt = date('c');
    $pdo->beginTransaction();
    $alt = $pdo->prepare('SELECT daten, rev FROM dokumente WHERE name = ?');
    $alt->execute([$t]);
    $vorher = $alt->fetch(PDO::FETCH_ASSOC);
    $rev = $vorher ? (int)$vorher['rev'] + 1 : 1;
    if ($vorher) {
      $pdo->prepare('INSERT INTO verlauf (name, daten, rev, gesichert_am) VALUES (?, ?, ?, ?)')
          ->execute([$t, $vorher['daten'], (int)$vorher['rev'], $jetzt]);
      $pdo->prepare('DELETE FROM verlauf WHERE name = ? AND id NOT IN (SELECT id FROM verlauf WHERE name = ? ORDER BY id DESC LIMIT ' . VERLAUF . ')')
          ->execute([$t, $t]);
    }
    $pdo->prepare('INSERT INTO dokumente (name, daten, rev, geaendert_am) VALUES (?, ?, ?, ?)
                   ON CONFLICT(name) DO UPDATE SET daten = excluded.daten, rev = excluded.rev, geaendert_am = excluded.geaendert_am')
        ->execute([$t, json_encode($body['data'], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES), $rev, $jetzt]);
    $pdo->commit();
    antwort(['rev' => $rev]);
  }

  antwort(['fehler' => 'Nur GET und POST.'], 405);
} catch (Throwable $e) {
  if (isset($pdo) && $pdo->inTransaction()) $pdo->rollBack();
  error_log('spence api: ' . $e->getMessage());
  antwort(['fehler' => 'Serverfehler.'], 500);
}

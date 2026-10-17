<?php
/**
 * Nur für den lokalen PHP-Server aus starten.command – auf dem Server gibt es ihn nicht.
 *
 *   /fonts/…  kommt aus der gemeinsamen Schrift-Ablage aller Werkzeuge
 *             (~/Sites/alltagstudio/public/fonts, Pfad aus SPENCE_SCHRIFT).
 *             Auf dem Server lädt die Seite dieselben Dateien von https://alltag.studio/fonts/.
 *   /api/…    geht an public/api/index.php.
 *   alles andere liefert der PHP-Server selbst aus public/.
 */
$pfad = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH) ?: '/';

if (str_starts_with($pfad, '/fonts/')) {
  $datei = rtrim((string)getenv('SPENCE_SCHRIFT'), '/') . '/' . basename($pfad);
  if (!is_file($datei)) { http_response_code(404); echo 'Schrift fehlt: ' . basename($pfad); return true; }
  header('Content-Type: ' . (str_ends_with($datei, '.woff2') ? 'font/woff2' : 'font/woff'));
  header('Cache-Control: no-cache');
  readfile($datei);
  return true;
}

if ($pfad === '/api' || str_starts_with($pfad, '/api/')) {
  require __DIR__ . '/public/api/index.php';
  return true;
}

return false;

# fonts/

Dieser Ordner enthält die **lizenzierte Schrift** der App.

Die Font-Dateien selbst sind über die Repo-`.gitignore` **bewusst vom
öffentlichen Repository ausgeschlossen** (domain-gebundene Webfont-Lizenz).
Sie liegen nur lokal vor und werden ausschließlich über Netlify
(Drop / `netlify deploy --prod`) auf die lizenzierte Domain ausgeliefert.

## Erwartete Datei(en)

- `<schriftname>.woff2` — Webfont, eingebunden per `@font-face` in `index.html`

## Publish

Beim Netlify-Deploy muss dieser Ordner **mit der Font-Datei** vorhanden sein.
Nach `git clone` fehlt die Font (weil ignoriert) — dann die lizenzierte
Datei hier ablegen, bevor deployt wird.

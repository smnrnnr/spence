#!/usr/bin/env python3
"""Daten einmalig in Spence einspielen – über die Schnittstelle api/, wie die App selbst.

    python3 deploy/einspielen.py https://spence.alltag.tools items.json cats.json
    python3 deploy/einspielen.py http://127.0.0.1:8750 items.json cats.json

Die Dateien dürfen so aussehen, wie Supabase sie liefert ([{"data": [...]}]),
oder schlicht das Array sein. Name und Kennwort (cPanel „Directory Privacy")
fragt das Skript selbst ab; sie landen weder in Dateien noch in der Shell-Historie.
Hat der Server schon Daten, bricht es ab – außer mit --ueberschreiben
(die vorige Fassung bleibt dann im Verlauf der Datenbank).
"""
import base64, getpass, json, sys, urllib.error, urllib.request

args = [a for a in sys.argv[1:] if not a.startswith('--')]
if len(args) != 3:
    sys.exit(__doc__)
adresse, dateien = args[0].rstrip('/') + '/api/', {'items': args[1], 'cats': args[2]}
ueberschreiben = '--ueberschreiben' in sys.argv
lokal = adresse.startswith('http://127.0.0.1') or adresse.startswith('http://localhost')

def lesen(pfad):
    d = json.load(open(pfad, encoding='utf-8'))
    if isinstance(d, list) and d and isinstance(d[0], dict) and 'data' in d[0]:
        d = d[0]['data']
    if not isinstance(d, list):
        sys.exit(f'{pfad}: erwartet eine Liste.')
    return d

daten = {t: lesen(p) for t, p in dateien.items()}
kopf = {}
if not lokal:
    name = input('Name: ').strip()
    kennwort = getpass.getpass('Kennwort: ')
    kopf['Authorization'] = 'Basic ' + base64.b64encode(f'{name}:{kennwort}'.encode()).decode()

def rufen(query, body=None):
    req = urllib.request.Request(adresse + query, headers={**kopf, 'Content-Type': 'application/json'},
                                 data=None if body is None else json.dumps(body, ensure_ascii=False).encode(),
                                 method='GET' if body is None else 'POST')
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        sys.exit(f'{query}: HTTP {e.code}' + (' – Name oder Kennwort falsch.' if e.code == 401 else ''))

stand = rufen('?t=stand')
if any(stand.get(t, 0) for t in daten) and not ueberschreiben:
    sys.exit(f'Der Server hat schon Daten (Stand {stand}). Nichts geändert. Mit --ueberschreiben trotzdem einspielen.')
for t, d in daten.items():
    print(f'{t}: {len(d)} Einträge → Stand {rufen("?t=" + t, {"data": d})["rev"]}')

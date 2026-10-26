"""Run the actual project's create_event path on local HTML, without Redis/Flask."""
import os
from pathlib import Path
import runpy
import sys
root = Path(__file__).resolve().parents[1]
repo = root / 'repos/misp-scraper'
sys.path.insert(0, str(repo))
os.chdir(repo)
module = runpy.run_path(str(repo / 'misp-scraper.py'), run_name='part12_adapter')
client = module['MispScraperEvent']()
event = client.create_event(
    'Manual', 'Manual', 'Part12 synthetic incident',
    'https://source.example/part12', [],
    rawhtml=(root / 'fixtures/article.html').read_text())
if not event or isinstance(event, dict):
    raise SystemExit('Creation failed; inspect lab logs off-screen.')
print(f'Created lab event ID {event.id}. Record this ID even if validation fails.')
record = client.misp.get_event(event.id, pythonify=False)
stored = record.get('Event', {}) if isinstance(record, dict) else {}
reports = client.misp.get_event_reports(event.id)
reports = reports.get('response', reports) if isinstance(reports, dict) else reports
if isinstance(reports, list):
    reports = [client.misp.get_event_report(r.get('EventReport', r)['id'])
               for r in reports if isinstance(r, dict) and 'id' in r.get('EventReport', r)]
if not isinstance(reports, list) or not any(
    'training exercise' in r.get('EventReport', r).get('content', '')
    for r in reports if isinstance(r, dict)
):
    raise SystemExit('Event exists, but expected report content was not verified. Inspect it in MISP; do not rerun blindly.')
values = {a.get('value') for a in stored.get('Attribute', [])}
expected = {'beacon.example', '192.0.2.42', 'https://beacon.example/training'}
missing = expected - values
if missing:
    raise SystemExit('Report exists; expected extracted values missing: ' + ', '.join(sorted(missing)))
if str(stored.get('distribution')) != '0' or stored.get('published') not in (False, 0, '0'):
    raise SystemExit('Unexpected event sharing/publication state. Inspect before continuing.')
print('PASS: report, three expected extracted values, organisation-only distribution and unpublished state.')
print('Still review indicator types, context, warninglists and IDS flags in the UI.')
print('Repeated runs create another event: record IDs and delete only those after rehearsal.')

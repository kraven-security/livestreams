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
event = module['MispScraperEvent']().create_event(
    'Manual', 'Manual', 'Part12 synthetic incident',
    'https://source.example/part12', [],
    rawhtml=(root / 'fixtures/article.html').read_text())
if not event or isinstance(event, dict):
    raise SystemExit('Creation failed; inspect lab logs off-screen.')
print(f'Created lab event ID {event.id}; inspect report and extracted attributes in MISP.')
print('Repeated runs create another event: record IDs and delete only those after rehearsal.')

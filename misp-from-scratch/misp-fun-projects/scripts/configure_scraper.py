"""Create local configuration; credentials stay in the process environment."""
from pathlib import Path
import os
root = Path(__file__).resolve().parents[1]
repo = root / 'repos/misp-scraper'
default = (repo / 'scraper.py.default').read_text()
overrides = '''
# Part12 overrides for a disposable lab. Not production defaults.
import os, secrets
misp_url = os.environ['MISP_URL']
misp_key = os.environ['MISP_API_KEY']
misp_verifycert = True
misp_distribution = 0
misp_analysis_level = 0
rawhtml_distribution = 0
rawhtml_sharing_group_id = 0
misp_retentiontime = ''
extract_elements = True
autodelete_when_no_required_strings = False
autodelete_when_assumed_errors = False
misp_hard_delete_on_cleanup = False
flask_secret_key = secrets.token_urlsafe(32)
'''
overrides += f'\nmisp_scraper_log = {str(root / "output/scraper.log")!r}\n'
(root / 'output').mkdir(exist_ok=True)
(repo / 'scraper.py').write_text(default + overrides)
os.chmod(repo / 'scraper.py', 0o600)
print('Configured scraper.py; no key written to file. Keep environment set when running.')

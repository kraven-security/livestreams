#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p output
base=${TRANSMUTE_URL:-https://cti-transmute.org}
base=${base%/}
curl --fail-with-body --silent --show-error --connect-timeout 10 --max-time 20 \
  "$base/api/convert/list" -o output/converters.json
python3 - <<'PY'
import json
from pathlib import Path
r=json.loads(Path('output/converters.json').read_text())
routes=r.get('available', {})
for direction in ('misp_to_stix', 'stix_to_misp'):
    path='/api/convert/'+direction
    if routes.get(path, {}).get('method') != 'POST':
        raise SystemExit('Required converter not available: '+path)
print('PASS: both conversion routes advertised. diagnostics is a transport flag, not in converter params_schema.')
PY
curl --fail-with-body --silent --show-error --connect-timeout 10 --max-time 25 \
  -D output/stix-headers.txt -H 'Content-Type: application/json' \
  --data-binary @fixtures/misp-event.json \
  "$base/api/convert/misp_to_stix?diagnostics=true" -o output/stix-response.json
python3 - <<'PY'
import json
from pathlib import Path
r=json.loads(Path('output/stix-response.json').read_text())
payload=r.get('conversion', r)
if payload.get('type') != 'bundle' or not payload.get('objects'):
    raise SystemExit('Expected a nonempty STIX bundle; inspect response')
Path('output/stix-bundle.json').write_text(json.dumps(payload, indent=2)+'\n')
print('STIX bundle objects:', len(payload['objects']))
print('Forward diagnostics:', json.dumps(r.get('diagnostics', 'not recorded'), indent=2))
PY
curl --fail-with-body --silent --show-error --connect-timeout 10 --max-time 25 \
  -D output/roundtrip-headers.txt -H 'Content-Type: application/json' \
  --data-binary @output/stix-bundle.json \
  "$base/api/convert/stix_to_misp?diagnostics=true" -o output/roundtrip.json
python3 scripts/check_roundtrip.py

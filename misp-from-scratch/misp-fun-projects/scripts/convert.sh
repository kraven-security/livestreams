#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p output
base=${TRANSMUTE_URL:-https://cti-transmute.org}
curl --fail-with-body --silent --show-error --connect-timeout 10 --max-time 60 \
  "$base/api/convert/list" -o output/converters.json
printf 'Inspect output/converters.json for misp_to_stix and stix_to_misp and their parameter schemas.\n'
read -r -p 'Both directions and diagnostics parameter supported? Type yes: ' confirmed
if [ "$confirmed" != yes ]; then
  printf 'Stopped before submitting fixture.\n'
  exit 1
fi
curl --fail-with-body --silent --show-error --connect-timeout 10 --max-time 60 \
  -D output/stix-headers.txt -H 'Content-Type: application/json' \
  --data-binary @fixtures/misp-event.json \
  "$base/api/convert/misp_to_stix?diagnostics=true" -o output/stix-response.json
python3 - <<'PY'
import json
from pathlib import Path
r=json.loads(Path('output/stix-response.json').read_text())
payload=r.get('conversion', r)
assert payload.get('type') == 'bundle', 'Expected a STIX bundle; inspect response'
Path('output/stix-bundle.json').write_text(json.dumps(payload, indent=2)+'\n')
print('STIX bundle objects:', len(payload.get('objects', [])))
print('Diagnostics:', json.dumps(r.get('diagnostics', 'not recorded'), indent=2))
PY
curl --fail-with-body --silent --show-error --connect-timeout 10 --max-time 60 \
  -H 'Content-Type: application/json' --data-binary @output/stix-bundle.json \
  "$base/api/convert/stix_to_misp?diagnostics=true" -o output/roundtrip.json
printf 'Review roundtrip.json: values, types, to_ids, distribution and diagnostics.\n'

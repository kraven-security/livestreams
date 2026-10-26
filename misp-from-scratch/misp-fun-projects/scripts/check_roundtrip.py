"""Verify synthetic value survival; do not claim semantic/byte equality."""
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
response=json.loads((root/'output/roundtrip.json').read_text())
payload=response.get('conversion', response) if isinstance(response, dict) else response
expected={'beacon.example', '192.0.2.42', 'https://beacon.example/training'}
found=set()
events=[]
def walk(node):
    if isinstance(node, dict):
        if 'info' in node and ('Attribute' in node or 'Object' in node):
            events.append(node)
        if isinstance(node.get('value'), str):
            found.add(node['value'])
        for value in node.values(): walk(value)
    elif isinstance(node, list):
        for value in node: walk(value)
walk(payload)
if not events:
    raise SystemExit('No converted MISP event found; inspect roundtrip.json')
missing=expected-found
if missing:
    raise SystemExit('Round-trip values missing: '+', '.join(sorted(missing)))
print('PASS: three synthetic values survived the round trip.')
print('Reverse diagnostics:', json.dumps(response.get('diagnostics', 'not recorded'), indent=2))
print('Still compare types, to_ids, distribution, metadata and relationships manually. HTTP 200/value survival is not lossless conversion.')

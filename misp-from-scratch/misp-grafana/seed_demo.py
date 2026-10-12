#!/usr/bin/env python3
"""Generate harmless MISP events; --apply imports them into an explicit demo org.

Standard library only. Writes are opt-in; never deletes or edits existing events.
"""
import argparse
import datetime as dt
import getpass
import json
import pathlib
import ssl
import sys
import urllib.error
import urllib.parse
import urllib.request
import uuid

TAG = 'livestream-demo'
NAMESPACE = uuid.UUID('1cdb5ca0-a469-4f71-9a8f-01894140db10')


def build_events(today, run_id):
    offsets = [0, 0, 1, 2, 2, 3, 4, 5, 6, 7, 8, 10]
    themes = ['phishing', 'command-and-control', 'credential-theft']
    events = []
    for i, offset in enumerate(offsets, 1):
        theme = themes[(i - 1) % len(themes)]
        attrs = []
        for kind, category, value, to_ids in [
            ('domain', 'Network activity', f'campaign-{i}.example', True),
            ('ip-dst', 'Network activity', f'192.0.2.{i}', True),
            ('url', 'Network activity', f'https://campaign-{i}.example/login', True),
            ('text', 'Other', 'SYNTHETIC TRAINING DATA - no real incident', False),
        ]:
            attrs.append({'uuid': str(uuid.uuid5(NAMESPACE, f'{run_id}/{i}/{kind}')),
                          'type': kind, 'category': category, 'value': value,
                          'to_ids': to_ids, 'distribution': 5,
                          'comment': 'Harmless livestream example'})
        events.append({'Event': {
            'uuid': str(uuid.uuid5(NAMESPACE, f'{run_id}/{i}')),
            'info': f'[GRAFANA DEMO] {i:02d} Synthetic {theme}',
            'date': (today - dt.timedelta(days=offset)).isoformat(),
            'distribution': 0, 'threat_level_id': 2,
            'analysis': [0, 1, 2][(i - 1) % 3], 'published': False,
            'Attribute': attrs,
            'Tag': [{'name': TAG}, {'name': f'demo-theme:{theme}'}],
        }})
    return events


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise RuntimeError('Redirect refused. Use the canonical MISP HTTPS base URL.')


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--apply', action='store_true', help='Create events and publish first eight')
    ap.add_argument('--url', help='Canonical HTTPS MISP base URL, including any subpath')
    ap.add_argument('--ca-file', help='Optional trusted private CA PEM bundle')
    ap.add_argument('--run-id', default='livestream-v1', help='Keep stable across retries')
    args = ap.parse_args()
    events = build_events(dt.datetime.now(dt.timezone.utc).date(), args.run_id)
    out = pathlib.Path('synthetic-events')
    out.mkdir(exist_ok=True)
    for i, event in enumerate(events, 1):
        (out / f'event-{i:02d}.json').write_text(json.dumps(event, indent=2) + '\n')
    print('Generated 12 events, 48 attributes, 36 to_ids=true; distribution=0.')
    if not args.apply:
        print('No API requests sent. Use --apply --url https://YOUR-MISP to import.')
        return
    parts = urllib.parse.urlsplit(args.url or '')
    if parts.scheme != 'https' or not parts.hostname or parts.username or parts.query or parts.fragment:
        ap.error('--apply requires a canonical HTTPS --url with no credentials/query/fragment')
    base = args.url.rstrip('/')
    key = getpass.getpass('MISP demo writer API key (hidden): ')
    if not key.strip():
        ap.error('API key is empty')
    context = ssl.create_default_context(cafile=args.ca_file)
    opener = urllib.request.build_opener(urllib.request.HTTPSHandler(context=context), NoRedirect())

    def call(path, body=None):
        req = urllib.request.Request(base + path,
            data=None if body is None else json.dumps(body).encode(),
            headers={'Authorization': key, 'Accept': 'application/json',
                     'Content-Type': 'application/json'},
            method='GET' if body is None else 'POST')
        with opener.open(req, timeout=60) as r:
            result = json.load(r)
        if isinstance(result, dict) and (result.get('errors') or result.get('error')):
            raise RuntimeError('MISP returned an application error. Inspect the REST client off air.')
        return result

    manifest = []
    for i, payload in enumerate(events, 1):
        event_uuid = payload['Event']['uuid']
        existing = False
        try:
            response = call('/events/view/' + event_uuid)
            existing = True
        except urllib.error.HTTPError as err:
            if err.code != 404:
                raise
            create_payload = {'Event': {k: v for k, v in payload['Event'].items() if k != 'Tag'}}
            response = call('/events/add', create_payload)
        event = response.get('Event', {}) if isinstance(response, dict) else {}
        if not event.get('id') or event.get('uuid') != event_uuid:
            raise RuntimeError('Unexpected event response; check /events/add in your MISP REST client.')
        if int(event.get('distribution', -1)) != 0:
            raise RuntimeError('Demo event is not restricted to your organisation; stopping.')
        if not existing:
            # Explicit attachment also covers instances that omit tags during import.
            for tag in payload['Event']['Tag']:
                call('/events/addTag', {'event': str(event['id']), 'tag': tag['name']})
            if i <= 8:
                call('/events/publish/' + str(event['id']), {})
        manifest.append({'id': str(event['id']), 'uuid': event_uuid,
                         'info': payload['Event']['info'], 'existing': existing})
        pathlib.Path('demo-import-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
        print(f'{i:02d}: ' + ('already exists; left unchanged' if existing else 'created'))
    print('Finished. Verify the scope and 12/48/8/4 counts using the read-only key.')
    print('Existing events were not modified. Partial retries may need manual tagging/publication.')


if __name__ == '__main__':
    try:
        main()
    except urllib.error.HTTPError as err:
        print(f'MISP HTTP {err.code}; check permissions and the local API docs off air.', file=sys.stderr)
        sys.exit(1)
    except (RuntimeError, urllib.error.URLError, ValueError) as err:
        print(str(err), file=sys.stderr)
        sys.exit(1)

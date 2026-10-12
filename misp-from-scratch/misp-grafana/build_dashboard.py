#!/usr/bin/env python3
"""Build live/importable and explicitly offline Grafana dashboards and JQ files."""
import copy
import datetime as dt
import json
from pathlib import Path
from seed_demo import build_events

ROOT = Path(__file__).resolve().parent
PLUGIN = 'yesoreyeram-infinity-datasource'
DS = {'type': PLUGIN, 'uid': '${DS_MISP}'}
PREFIX = '''def events:
  (if type == "array" then .
   elif (.response | type) == "array" then .response
   else error("Expected MISP event array or response array") end)
  | .[] | (.Event // .);
def truth: . == true or . == 1 or . == "1";
def attrs: ((.Attribute // []) + [.Object[]?.Attribute[]?])
  | unique_by(.uuid // .id // ([.type, .value] | join("|"))) | .[];
'''
QUERIES = {
    'events': '[events] | {events: length}',
    'attributes': '[events | attrs] | {attributes: length}',
    'unpublished': '[events | select((.published | truth) | not)] | {unpublished: length}',
    'latest_modified': '[events | (.timestamp | tonumber)] | {latest_modified: (if length > 0 then max * 1000 else null end)}',
    'event_dates': '[events | {date: .date}] | group_by(.date) | .[] | {time: (.[0].date + "T00:00:00Z"), events: length}',
    'attribute_types': '[events | attrs] | group_by(.type) | map({type: .[0].type, count: length}) | sort_by(-.count, .type) | .[]',
    'ids_context': '[events | attrs | {label: (if (.to_ids | truth) then "to_ids true" else "Context only" end)}] | group_by(.label) | .[] | {label: .[0].label, count: length}',
    'themes': '[events | [.Tag[]?.name | select(startswith("demo-theme:"))] | unique | .[]] | group_by(.) | .[] | {theme: .[0], events: length}',
    'event_table': '[events | {id: (.id | tostring), info, date, published: (if (.published | truth) then "Published" else "Unpublished" end), analysis: ({"0":"Initial", "1":"Ongoing", "2":"Completed"}[.analysis | tostring] // "Unknown"), modified: (.timestamp | tonumber)}] | sort_by(-.modified, .id) | .[]',
}
BODY = {
    'returnFormat': 'json', 'tags': 'livestream-demo', 'limit': 100,
    'page': 1, 'withAttachments': False, 'metadata': False,
    'date': ['${__timeFrom:date:YYYY-MM-DD}', '${__timeTo:date:YYYY-MM-DD}'],
}


def target(key, columns, timeseries=False):
    return {'refId': 'A', 'datasource': DS, 'type': 'json', 'source': 'url',
            'parser': 'jq-backend', 'format': 'timeseries' if timeseries else 'table',
            'url': '/events/restSearch', 'root_selector': PREFIX + QUERIES[key],
            'columns': [{'selector': field, 'text': field, 'type': typ} for field, typ in columns],
            'url_options': {'method': 'POST', 'body_type': 'raw',
                            'body_content_type': 'application/json',
                            'data': json.dumps(BODY),
                            'headers': [{'key': 'Accept', 'value': 'application/json'}]}}


def main():
    (ROOT / 'queries').mkdir(exist_ok=True)
    for name, query in QUERIES.items():
        (ROOT / 'queries' / (name + '.jq')).write_text(PREFIX + query + '\n')
    fixture = build_events(dt.datetime.now(dt.timezone.utc).date(), 'offline-fixture')
    epoch = int(dt.datetime.now(dt.timezone.utc).timestamp())
    for i, wrapper in enumerate(fixture, 1):
        e = wrapper['Event']
        e.update(id=str(i), timestamp=str(epoch - i * 60), published=i <= 8)
        for n, a in enumerate(e['Attribute'], 1):
            a.update(id=str(i * 100 + n), timestamp=e['timestamp'])
    response = {'response': fixture}
    (ROOT / 'offline-fixture.json').write_text(json.dumps(response, indent=2) + '\n')
    panels = []
    def panel(title, kind, key, columns, x, y, w, h, unit='short', description=''):
        p = {'id': len(panels) + 1, 'title': title, 'type': kind,
             'description': description, 'gridPos': {'x': x, 'y': y, 'w': w, 'h': h},
             'datasource': DS, 'targets': [target(key, columns, kind == 'timeseries')],
             'fieldConfig': {'defaults': {'unit': unit, 'decimals': 0}, 'overrides': []},
             'options': {}}
        if kind == 'stat':
            p['options'] = {'reduceOptions': {'calcs': ['lastNotNull'], 'fields': '', 'values': False},
                            'textMode': 'auto', 'colorMode': 'value', 'graphMode': 'none'}
        elif kind == 'barchart':
            p['options'] = {'orientation': 'horizontal', 'showValue': 'always',
                            'legend': {'showLegend': False}, 'tooltip': {'mode': 'single'}}
        elif kind == 'piechart':
            p['options'] = {'pieType': 'donut', 'displayLabels': ['name', 'percent'],
                            'reduceOptions': {'calcs': ['lastNotNull'], 'fields': '', 'values': True},
                            'legend': {'displayMode': 'list', 'placement': 'right', 'values': ['value']}}
        elif kind == 'timeseries':
            p['fieldConfig']['defaults']['custom'] = {'drawStyle': 'bars', 'fillOpacity': 70,
                                                       'lineWidth': 0, 'spanNulls': False}
            p['options'] = {'legend': {'showLegend': False}, 'tooltip': {'mode': 'single'}}
        elif kind == 'table':
            p['options'] = {'showHeader': True, 'cellHeight': 'sm'}
            p['fieldConfig']['overrides'] = [{'matcher': {'id': 'byName', 'options': 'id'},
                'properties': [{'id': 'links', 'value': [{'title': 'Open event in MISP',
                    'url': '${misp_url}/events/view/${__value.raw}', 'targetBlank': True}]}]}]
        panels.append(p)

    panels.append({'id': 1, 'title': 'Scope and meaning', 'type': 'text',
                   'gridPos': {'x': 0, 'y': 0, 'w': 24, 'h': 3},
                   'options': {'mode': 'markdown', 'content': '**SYNTHETIC TRAINING DATA** — `livestream-demo` events visible to this MISP API key. Whole UTC event dates within the selected range. Page 1 only, maximum 100 events; verify page 2 is empty. Counts represent current records, including context attributes. Most recent modification is an event timestamp; it does not measure ingestion or platform health.'}})
    scope = 'Current visible records for the demo tag and selected whole UTC event dates. Page 1, up to 100 events.'
    panel('Visible demo events', 'stat', 'events', [('events','number')], 0,3,6,4,description=scope)
    panel('Attribute records including context', 'stat', 'attributes', [('attributes','number')], 6,3,6,4,description=scope)
    panel('Unpublished demo events', 'stat', 'unpublished', [('unpublished','number')], 12,3,6,4,description=scope)
    panel('Most recent event modification', 'stat', 'latest_modified', [('latest_modified','number')], 18,3,6,4,'dateTimeAsIso',scope)
    panel('Events by reported event date UTC', 'timeseries', 'event_dates', [('time','timestamp'),('events','number')], 0,7,12,8,description='Counts current events grouped by Event.date. This date is user supplied. Missing dates have no bucket; this is not ingestion history.')
    panel('Attribute records by type', 'barchart', 'attribute_types', [('type','string'),('count','number')], 12,7,12,8,description='Includes event and object attributes, deduplicated by UUID within each event. Repeated values across events remain separate records.')
    panel('Attributes marked to_ids and context', 'piechart', 'ids_context', [('label','string'),('count','number')], 0,15,12,8,description='The to_ids flag expresses intended IDS use; it is not a confidence or detection score.')
    panel('Events by synthetic theme tag', 'barchart', 'themes', [('theme','string'),('events','number')], 12,15,12,8,description='Custom demo labels, not ATT&CK mappings. Multi-tag events could contribute to multiple categories.')
    panel('Demo event workflow and MISP links', 'table', 'event_table', [('id','string'),('info','string'),('date','string'),('published','string'),('analysis','string'),('modified','timestamp_epoch_s')], 0,23,24,9,unit='none',description='Click the id to open the event. Set the misp_url constant to your browser-accessible MISP base URL.')
    dashboard = {'__inputs': [{'name': 'DS_MISP', 'label': 'MISP Infinity', 'type': 'datasource', 'pluginId': PLUGIN, 'pluginName': 'Infinity'}],
        'id': None, 'uid': 'misp-livestream-demo', 'title': 'MISP threat intelligence demo',
        'schemaVersion': 39, 'version': 1, 'timezone': 'utc', 'refresh': '',
        'time': {'from': 'now-30d/d', 'to': 'now'}, 'tags': ['MISP', 'livestream'],
        'templating': {'list': [{'name': 'misp_url', 'type': 'constant',
            'query': 'https://misp.example', 'hide': 2,
            'current': {'text': 'https://misp.example', 'value': 'https://misp.example'}}]},
        'panels': panels, 'annotations': {'list': []}}
    (ROOT / 'dashboard-live.json').write_text(json.dumps(dashboard, indent=2) + '\n')
    offline = copy.deepcopy(dashboard)
    offline.update(uid='misp-livestream-offline', title='OFFLINE synthetic MISP snapshot')
    offline['panels'][0]['options']['content'] = '**OFFLINE SYNTHETIC SNAPSHOT — no MISP connection.** Every query reads the bundled fixture. Time picker does not filter this snapshot. Import the live dashboard to query your instance. MISP links are disabled.'
    for p in offline['panels'][1:]:
        p['description'] = 'Offline fixture only. Time range does not filter these records.'
        p['fieldConfig']['overrides'] = []
        for t in p['targets']:
            t.update(source='inline', data=json.dumps(response), url='')
            t.pop('url_options', None)
    (ROOT / 'dashboard-offline.json').write_text(json.dumps(offline, indent=2) + '\n')
    (ROOT / 'request-body.json').write_text(json.dumps(BODY, indent=2) + '\n')
    print('Built nine live panels, offline dashboard, fixture and JQ query files.')


if __name__ == '__main__':
    main()

# MISP to Grafana YouTube livestream runbook

**Target environment**: Ubuntu with Bash. Viewers already have MISP; they start with no Grafana. Use synthetic threat intelligence and show both content and analyst workflow. 

**Viewer outcome:** Start Grafana in Docker, install Infinity, authenticate to an existing MISP API, turn nested event JSON into panels, and open an event back in MISP. The companion files contain the commands, nine-panel dashboard, harmless demo events and an offline fallback.

## Integration and scope

The browser opens Grafana. The Grafana server, through the Infinity data source and its backend JQ parser, sends authenticated HTTPS POST requests to the existing MISP `/events/restSearch` endpoint. JQ selects and aggregates fields; Grafana displays the result. MISP remains the source of truth. No direct MISP database access, exporter or additional data store is needed for this lesson. See sources 1–5.

Use **Grafana OSS 13.2.3** and **Infinity 4.1.1**, pinned in `compose.yaml`. These releases and compatibility constraints were checked in the official catalog on 9 October 2026. Rehearse this pair before broadcast; review current supported patches if the stream runs later. Pinning makes the demonstration repeatable, but does not replace upgrade review. See sources 6–8.

The demonstration queries only events tagged `livestream-demo`, within selected **whole UTC event dates**, with `page: 1` and `limit: 100`. This intentionally bounded dataset has 12 events and 48 attributes. Verify that page 2 is empty before describing the counts as complete for this scope. Do not describe them as the total size of the MISP instance.

Each panel currently issues its own request. Nine panels can mean nine calls per refresh per viewer. Manual refresh is the default. This is suitable for a small teaching dataset; production scale and durable history are closing discussion topics, not extra infrastructure to install live.

## Environment Preparation

### Host and access

Use an Ubuntu 24.04 or other Docker-supported Ubuntu host, a browser, Bash, curl, jq, Python 3 and the Docker Compose plugin. Docker Engine installation is a prestream dependency; Grafana installation is the live teaching segment. Existing Docker users skip this optional install block. On hosts with conflicting container packages, follow the official Docker migration instructions rather than replacing an existing stack during broadcast (source 9).

On a fresh Ubuntu host:

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl jq python3 unzip
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

. /etc/os-release
stream_ubuntu_codename="${UBUNTU_CODENAME:-$VERSION_CODENAME}"
stream_arch="$(dpkg --print-architecture)"
sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${stream_ubuntu_codename}
Components: stable
Architectures: ${stream_arch}
Signed-By: /etc/apt/keyrings/docker.asc
EOF
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
sudo docker run --rm hello-world
sudo docker compose version
```

This runbook uses `sudo docker` consistently and does not require changing Docker-group membership. Allow image/plugin downloads and outbound HTTPS from the Docker host to MISP. Reserve port 3000; choose a different host port in Compose if already occupied.

For a remote Ubuntu host, the local-only port binding needs an SSH tunnel. From the computer whose browser you will share:

```bash
ssh -N -L 3000:127.0.0.1:3000 YOUR_USER@YOUR_DOCKER_HOST
```

Then browse to `http://localhost:3000` on your computer. The MISP URL in the data source must be reachable **from Grafana**, while dashboard drilldown links must be reachable from the viewer's browser.

### Prepare synthetic MISP data

Do this before the stream in a dedicated demo organisation on the running MISP instance. Disable unrelated custom workflows/integrations for that organisation if they would act on training events. The supplied script creates organisation-only events (`distribution: 0`) and inheriting attributes (`distribution: 5`); it publishes the first eight. Review that publication behaves as expected in your environment before running it.

Create four custom tags using MISP's tag administration UI, with a demo writer account allowed to create/attach tags:

- `livestream-demo`
- `demo-theme:phishing`
- `demo-theme:command-and-control`
- `demo-theme:credential-theft`

Use two separate MISP API keys: a demo writer key for seeding, and a **read-only** key for Grafana and curl. Both accounts need to see the demo organisation's events, including unpublished ones. Give the Grafana key a clear comment and appropriate expiry; if IP restricted, allow the actual outbound address MISP sees from Grafana. Never enter the writer key into Grafana.

The commands below assume the extracted `misp-grafana-livestream` directory:

```bash
cd misp-grafana-livestream
python3 seed_demo.py
# Above: generates individual JSON files; makes no API requests.

python3 seed_demo.py --apply --url https://YOUR-MISP-HOST
# Hidden prompt asks for the demo writer key.
```

For a private CA:

```bash
python3 seed_demo.py --apply --url https://YOUR-MISP-HOST \
  --ca-file /path/to/trusted-ca.pem
```

The importer uses stable UUIDs for retries and writes `demo-import-manifest.json` listing created event IDs. It leaves existing events unchanged. If a prior run failed after creation, repair that event's tags/publication in the UI before retrying. A new `--run-id` creates a new set: remove or separate old demo data first, or the shared tag will include both sets.

Generated data: 12 events across the last 11 UTC dates; 48 attribute records (12 domain, 12 ip-dst, 12 url, 12 text); 36 `to_ids=true`; 12 context-only; 8 published and 4 unpublished; 4 events per synthetic theme. These are expected initial counts, subject to your instance's visibility and any later edits. Reserved example domains and documentation IPs contain no real threat content. Verify these expectations with the read-only key, not only the writer account.

## Start Grafana in Docker

1. Inspect `compose.yaml` on screen. It starts only Grafana, binds port 3000 to loopback, stores data in `grafana-data`, reads the initial admin password from a file and installs pinned Infinity synchronously.
2. Before capture, create the password file using the hidden prompt:

```bash
bash init.sh
```

The script protects `.secrets` with directory mode 0700. The Grafana password file is readable inside its read-only Compose secret mount. The file initializes a **new** Grafana database; changing it later does not reset an existing admin password.

3. Run the live startup:

```bash
sudo docker compose config --quiet
sudo docker compose pull
sudo docker compose up -d
sudo docker compose ps
sudo docker compose logs --tail=80 grafana
curl --fail --silent --show-error http://localhost:3000/api/health | jq
```

Wait for plugin installation and startup to finish. Expect a healthy running container and a health response with `database: ok` and the pinned Grafana version. Logs are a troubleshooting aid; inspect them before sharing them publicly.

4. Open `http://localhost:3000`, log in as `admin` with the password chosen earlier, and show that Infinity is available under Connections → Add new connection or Data sources. Menu labels can vary; use Grafana's search if necessary.

**Talking points:** “The container can be replaced; the volume holds our dashboards and settings.” “The port is local to this host.” “Infinity is a plugin; MISP itself does not need a Grafana plugin installed.”

## Prove the MISP API works

Set the canonical HTTPS URL including any deployment subpath, without a trailing slash. Do not use a URL that redirects to another hostname. Enter the key while the capture is on the holding screen:

```bash
export MISP_URL='https://YOUR-MISP-HOST'
umask 077
mkdir -p .secrets
chmod 700 .secrets
read -r -s -p 'MISP read-only API key: ' stream_misp_key
printf '\n'
printf 'Authorization: %s\nAccept: application/json\nContent-Type: application/json\n' \
  "$stream_misp_key" > .secrets/misp-headers
unset stream_misp_key
```

Do not display `.secrets/misp-headers`. The subsequent command reads headers from the private file rather than putting the key in the displayed command:

```bash
curl --fail-with-body --silent --show-error \
  --header @.secrets/misp-headers \
  --request POST "$MISP_URL/events/restSearch" \
  --data '{"returnFormat":"json","tags":"livestream-demo","limit":100,"page":1,"withAttachments":false,"metadata":false}' \
  --output demo-api-response.json

jq -f queries/events.jq demo-api-response.json
jq -f queries/attributes.jq demo-api-response.json
jq -f queries/unpublished.jq demo-api-response.json
jq -f queries/attribute_types.jq demo-api-response.json
jq -f queries/event_table.jq demo-api-response.json
```

Expected aggregate values: 12 events, 48 attributes, 4 unpublished; the type breakdown is 12 of each type. Before broadcasting any row output, inspect the JSON privately to confirm every row is a synthetic demo event.

The normal event export is an array of `Event` wrappers, commonly under `response`. The selectors supplied in `queries/` accept both that envelope and a top-level array, and fail explicitly if they receive an unexpected object. They flatten object attributes as well as top-level event attributes and deduplicate by UUID within each event.

### Check completeness

```bash
curl --fail-with-body --silent --show-error \
  --header @.secrets/misp-headers \
  --request POST "$MISP_URL/events/restSearch" \
  --data '{"returnFormat":"json","tags":"livestream-demo","limit":100,"page":2,"withAttachments":false,"metadata":false}' \
  --output demo-page2.json
jq -f queries/events.jq demo-page2.json
```

Expected result: `{"events":0}`. A nonempty page 2 means the imported dashboard is incomplete for that scope. Role/server caps may be below the requested 100, so do not rely only on page 1 being shorter than 100. Reconcile the expected demo UUIDs/counts and inspect page 2. The kit does not automatically retrieve every page; keep the synthetic dataset bounded. A general deployment must implement and verify pagination, cope with records changing between pages, and consider cached/collected data.

For a private CA, add `--cacert /path/to/trusted-ca.pem` to curl **and** configure the corresponding CA in Infinity. Host curl success is only the first connectivity check; the Grafana query is the container-side check.

**Talking points:** “MISP uses `Authorization: <key>` with no Bearer prefix.” “The key limits what this dashboard can see.” “We omitted the `published` filter to include both states.” “The returned attribute count is not a count of distinct indicator values or confirmed threats.”

## Configure the Infinity data source

In Grafana, go to Connections → Data sources → Add data source → Infinity. Configure:

| Setting | Value |
|---|---|
| Name | `MISP Demo` |
| Base URL | Canonical MISP URL reachable from the Grafana container, including a subpath if present |
| Allowed hosts | The exact MISP origin, for example `https://misp.example.org`; no wildcard |
| Authentication | API key |
| Key | `Authorization` |
| Value | Raw **read-only** MISP key, entered with capture paused |
| In | Header |
| Additional HTTP header | `Accept` = `application/json` |
| TLS | Certificate verification enabled; configure trusted private CA if needed |
| Timeout | Start with 30 seconds for this small demo |
| Dangerous HTTP methods | Leave disabled |

Save the data source. **Save & test alone is not the proof of a working MISP search**: Infinity's default health check may not validate the target URL, and a custom check tests status rather than JSON correctness. The real acceptance test is the authenticated table query below. See source 2.

If using a private CA, enable “With CA cert”, paste the CA PEM into the data-source TLS settings and set the server name to the certificate's hostname. A trusted CA does not fix a hostname mismatch. Avoid bypassing certificate verification in the walkthrough.

On Linux, the kit adds `host.docker.internal:host-gateway`. That can reach a MISP service listening on the host's reachable interface, using a URL whose TLS name is valid. A service bound only to host `127.0.0.1` is not reachable through the bridge gateway. Inside Grafana, `localhost` refers to the Grafana container. If MISP runs in another Docker project, use an intentionally shared Docker network/service name or its existing reachable HTTPS endpoint; do not rebuild the MISP stack for this lesson.

## Build panels live

### Common query settings

Create a dashboard → Add visualization → select `MISP Demo`. Choose Infinity **Type JSON**, **Source URL**, **Parser Backend → JQ**, **Format Table**. Set URL `/events/restSearch`, method POST, body type Raw, content type `application/json`, and body:

```json
{
  "returnFormat": "json",
  "tags": "livestream-demo",
  "limit": 100,
  "page": 1,
  "withAttachments": false,
  "metadata": false,
  "date": [
    "${__timeFrom:date:YYYY-MM-DD}",
    "${__timeTo:date:YYYY-MM-DD}"
  ]
}
```

Select last 30 days and dashboard timezone UTC. Date filtering operates at day precision. An intraday picker range can therefore include an entire matching day in Stat/table panels; explain that behaviour rather than claiming precise hourly filtering.

For each panel, paste the **entire** matching `.jq` file into Rows/Root. The shared `def` helpers are part of the expression. Clear any old columns when duplicating a query and add the columns listed below. Backend JQ is the chosen parser; these expressions are not JSONata. See sources 3–5.

| Panel | Selector file | Columns and Infinity types | Visualization and expected initial result |
|---|---|---|---|
| Demo event workflow | `event_table.jq` | `id` string; `info` string; `date` string; `published` string; `analysis` string; `modified` timestamp epoch seconds | Table; 12 synthetic rows |
| Visible demo events | `events.jq` | `events` number | Stat; calculation Last not null; 12 |
| Attribute records by type | `attribute_types.jq` | `type` string; `count` number | Horizontal Bar chart; 12 per type |
| Unpublished demo events | `unpublished.jq` | `unpublished` number | Stat; Last not null; 4 |
| Events by reported date | `event_dates.jq` | `time` timestamp/ISO; `events` number | Time series, query Format Time series, draw style Bars; counts by UTC date |
| Attribute records including context | `attributes.jq` | `attributes` number | Stat; 48 |
| Most recent event modification | `latest_modified.jq` | `latest_modified` number | Stat; Last not null; unit Date and time ISO; selector emits milliseconds |
| IDS intended use and context | `ids_context.jq` | `label` string; `count` number | Pie/Donut; show all values; 36 and 12 |
| Events by demo theme | `themes.jq` | `theme` string; `events` number | Bar chart; 4 per theme |

Start with the table because it makes parsing and scope visible. Duplicate its panel for the Stat and bar chart; keep the request and replace only the root selector/columns. Build the unpublished Stat if on time. Explain the remaining panels using the import instead of racing through repeated UI steps.

The first Stat's final aggregation is simply `[events] | {events: length}` after the supplied helper definitions. The attribute chart gathers `[events | attrs]`, groups by type and counts each group. Point out that MISP can serialize numeric/Boolean fields as strings; the helpers normalize `published` and `to_ids` values.

### Metric meaning to say aloud

| Field or panel | Interpretation | Limit on conclusions |
|---|---|---|
| `Event.date` | User-entered reported event date | Not import time, first observation, or first creation time |
| `Event.timestamp` | Most recent event modification | Does not identify every earlier modification or reliably measure feed freshness |
| `publish_timestamp` | Last publication time | Republishing changes it; it is not a history of every publication |
| `first_seen` and `last_seen` | Observation bounds where populated | Coverage depends on the source and analysts; absent in this demo |
| Unpublished events | Visible records awaiting or no longer in published state | Not automatically a backlog, SLA breach or platform fault |
| `to_ids` | Attribute marked for IDS use | Not maliciousness, confidence, warning-list clearance or an observed detection |
| Attributes by type | Record composition in the scoped result | Repeated values across events remain separate records; context attributes count |
| Demo theme tags | Synthetic event labels | Not real threat actor attribution, ATT&CK techniques or confidence |

The event-date chart reconstructs a distribution from current records. Empty date buckets are omitted, not explicitly filled with zero. Changes/deletions can alter this view. A dashboard that preserves historical ingestion or platform-health measurements requires a separate collection/storage design.

## Import the completed dashboard and verify it

In Grafana, use Dashboards → New → Import. Upload `dashboard-live.json`, select `MISP Demo` for the `MISP Infinity` input, and import. This data-source mapping is required; do not paste the JSON directly into an existing dashboard editor and expect `${DS_MISP}` to resolve.

Open dashboard settings → Variables → `misp_url`. Set its constant value to the MISP base URL **reachable from your browser**, including any deployment subpath and excluding a trailing slash. Save the dashboard. The variable is hidden from the normal viewer; it is used only for event drilldown links.

Acceptance checks:

1. The banner identifies synthetic data, tag, day precision and page limit.
2. Last 30 days gives 12 events, 48 attributes and 4 unpublished before any live edits.
3. Type counts are 12 each; IDS/context counts are 36/12; theme counts are 4 each.
4. The table contains exactly the known demo events. Click an ID and verify the opened MISP event UUID against the manifest.
5. Change to last 7 days: older reported-date events disappear. Inspect the expanded request body privately to confirm date boundaries change. Return to last 30 days.
6. The most recent modification has a sensible time, and the event-date plot uses UTC dates. Do not mistake seconds for milliseconds.
7. Refresh works with the read-only key. Keep auto-refresh off during the lesson; optional 5-minute refresh only after measuring the query load.
8. Test the offline fallback in the rehearsal instance. Its title/banner must clearly identify the snapshot; it has no live API calls and does not respond to time-range filtering.

## Failure and recovery runbook

| Symptom | Check and command or UI action | Presenter response |
|---|---|---|
| Grafana does not start | `sudo docker compose ps`; `sudo docker compose logs --tail=80 grafana`; check port 3000 and plugin download access | Explain container startup vs plugin startup; use the rehearsed instance if the fix exceeds 90 seconds. |
| Grafana cannot read admin secret | Check `.secrets` exists and `bash init.sh` completed; verify the password file is readable in its mount | Correct permissions off screen; do not print the file. |
| 401 or 403 from MISP | API key, raw Authorization header, read-only role's query permissions, expiry, actual source-IP allowlist | Keep capture paused for credential inspection. A 403 can represent invalid auth or insufficient permissions. |
| Browser reaches MISP but Grafana cannot | Data-source hostname, container DNS/routing, proxy, VPN, firewall and `localhost` usage | Explain that the server sends the request. Change to a container-reachable canonical URL; do not chase CORS first. |
| Certificate validation error | Trusted CA, full chain and hostname; configure Infinity CA and server name | Repair trust/name configuration. Switch to fallback if unresolved. |
| Save & test succeeds but table fails | Actual POST query and expected JSON envelope, base URL/subpath, auth configuration | Health checks are limited; use the real data query as the proof. |
| HTTP 200 but parser error | Inspect response off air: HTML login page, error object or unexpected API format | Do not turn malformed responses into an empty dataset. Use the local MISP REST client to confirm its schema. |
| Zero demo events | Read-only key's organisation visibility, tag spelling/attachment, selected UTC dates, published filtering | Remove the date filter only while retaining the demo tag, to separate date and visibility issues. |
| Unexpected totals | Duplicate demo runs, permissions, role caps, page 2, extra tag matches, live edits | State the scope and reconcile records before asserting totals. |
| Some attributes missing | `metadata` must be false; object attributes; export filters/role limits | Compare returned attributes with the synthetic manifest and expected 48 records. |
| Time chart empty or wildly dated | Timestamp column type, ISO formatting, picker window, UTC; epoch seconds vs milliseconds | Show the correctly typed table before changing the chart. |
| Query too slow | Inspect query duration privately; reduce scope; manual refresh; no attachments | The small demo should not need an unbounded full-instance export. |
| Event link wrong | `misp_url` variable, deployment subpath, ID mapping | Use the browser URL rather than an internal-only Docker hostname. |

## Common Questions

- “Can I use this with a private MISP?” Yes, if the Grafana server can reach it and authenticate with trusted TLS.
- “Why not Prometheus?” This lesson needs event/attribute content from JSON. Prometheus can be appropriate for collected numerical operational metrics, with different modelling and history requirements.
- “Why are counts different from my MISP UI?” Compare API identity, visibility, filters, dates and pagination before comparing totals.
- “Can I alert on this?” Infinity backend parsing supports Grafana alerting, but the alert needs a well-defined numeric signal, no-data/error handling and a rehearsed evaluation schedule. Alert setup is optional follow-up scope.
- “Does a large IOC count mean better intelligence?” Record volume describes quantity. Relevance, recency, provenance, confidence and usefulness need separate evidence.

## Lab shutdown actions

Stop Grafana while retaining its volume:

```bash
sudo docker compose down
```

For an intentional reset of **this demo's** Grafana data only, in the correct project directory:

```bash
sudo docker compose down --volumes
```

The second command deletes this project's Grafana named volume, including its dashboards, users and stored data-source settings. It does not delete MISP data. Keep any dashboard exports you want first.

## Companion file index

| File | Purpose |
|---|---|
| `RUNBOOK.md` | Action, commands, checks and troubleshooting |
| `compose.yaml` | Pinned Grafana container with persistent volume and Infinity installation |
| `init.sh` | Hidden prompt to create the initial Grafana password file |
| `seed_demo.py` | Generate JSON without network calls; optional explicit demo import |
| `synthetic-events/event-*.json` | Individual harmless MISP event payloads |
| `build_dashboard.py` | Regenerate dashboards, fixture and selector files |
| `dashboard-live.json` | Importable nine-panel API dashboard with data-source input mapping |
| `dashboard-offline.json` | Clearly labelled inline-data fallback with links disabled |
| `request-body.json` | Common Grafana POST body with Infinity date macros |
| `queries/*.jq` | Full paste-ready backend JQ root selectors |
| `offline-fixture.json` | Synthetic API-shaped JSON for local query demonstrations |

## Official reference sources

The links below establish the supported API and configuration mechanisms.

1. [Infinity overview](https://grafana.com/docs/plugins/yesoreyeram-infinity-datasource/latest/) — REST/JSON integration capabilities.
2. [Infinity configuration](https://grafana.com/docs/plugins/yesoreyeram-infinity-datasource/latest/configure/) — API-key auth, allowed hosts, TLS, server-side requests and health-check limits.
3. [Infinity JQ backend parser](https://grafana.com/docs/plugins/yesoreyeram-infinity-datasource/latest/query/jq-backend/) — parser choice and root selectors.
4. [Infinity time macros](https://grafana.com/docs/plugins/yesoreyeram-infinity-datasource/latest/query/macros/) — request-body macros and date formatting.
5. [MISP API documentation](https://github.com/MISP/MISP/blob/2.5/docs/API_Doc.md) and [MISP OpenAPI](https://www.misp-project.org/openapi/) — event search/add/tag/publication endpoints and pagination.
6. [Run Grafana in Docker](https://grafana.com/docs/grafana/latest/setup-grafana/installation/docker/) and [Docker configuration](https://grafana.com/docs/grafana/latest/setup-grafana/configure-docker/) — container, volume, plugin and file-secret configuration.
7. [Grafana 13.2.3 release download](https://grafana.com/grafana/download/13.2.3?edition=oss) — selected release.
8. [Infinity plugin catalog](https://grafana.com/grafana/plugins/yesoreyeram-infinity-datasource/) — selected plugin release and Grafana compatibility.
9. [Docker Engine on Ubuntu](https://docs.docker.com/engine/install/ubuntu/) — repository installation and prerequisites.
10. [MISP user guide API automation](https://www.circl.lu/doc/misp/automation/) — API auth, read-only authkeys, local API references and practical recipes.
11. [Infinity time formats](https://grafana.com/docs/plugins/yesoreyeram-infinity-datasource/latest/query/time-formats/) — ISO/epoch column types.

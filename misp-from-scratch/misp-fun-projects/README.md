# MISP From Scratch: Fun MISP Projects (Part 12)

Lab kit for trying five small MISP community projects, each one doing a different job:

| Project | Job | Needs a MISP instance? |
| --- | --- | --- |
| [misp-scraper](https://github.com/cudeso/misp-scraper) | Turn a report into a MISP event and extract indicators | Yes (writable key) |
| [CTI-Transmute](https://github.com/MISP/cti-transmute) | Convert MISP ↔ STIX | No (uses a bundled fixture) |
| [misp-mcp](https://github.com/MISP/misp-mcp) | Query MISP through read-only MCP tools | Yes (read-only key) |
| [MISP Fleet Commander](https://github.com/MISP/MISP-Fleet-Commander) | See health and version across several instances | Yes, plus Docker |
| [misp-guard](https://github.com/MISP/misp-guard) | Enforce sync policies (tested here with mocked flows) | No |

All data in `fixtures/` is synthetic training data. The domains, `192.0.2.42` and
URLs aren't real malicious infrastructure.

> **Lab only.** Use a disposable MISP instance and demo API keys. Don't point
> any of this at production.

## Requirements

- Linux VM or WSL2 with Bash, Git and curl
- Python 3.12 with `venv`
- A lab MISP instance with misp-modules, with your lab CA trusted (TLS
  verification stays on)
- For Fleet Commander: Node/npm, Docker Engine and Docker Compose v2
- Optional: a local CTI-Transmute install (the public service is used by default)

Run every command from this directory unless a step says `cd`.

## 1. Prepare

```bash
bash scripts/prepare.sh
```

This clones the four upstream repos at the commits pinned in
`source-revisions.json` into `repos/`. It also creates an isolated Python
environment for each project and writes revisions and package lists to
`output/`. The MCP SDK is pinned to `1.30.0` because SDK v2 breaks misp-mcp's
FastMCP import. Preparation doesn't contact your MISP.

### Lab MISP settings

- Create a **writable demo API user** for the scraper. It needs to create
  events and reports, extract report attributes, and have Tagger and Tag
  Editor permissions.
- Create a separate **read-only demo API key** for the MCP step.
- Enable `Plugin.Enrichment_html_to_markdown_enabled` under
  *Administration → Server settings & maintenance → Plugin*, and check that
  misp-modules is healthy.

### Configure credentials

Keep shell tracing off so the key isn't echoed:

```bash
set +x
export MISP_URL='https://YOUR-LAB-MISP'
read -r -s -p 'Lab MISP API key: ' MISP_API_KEY
printf '\n'
export MISP_API_KEY
# Optional, if your lab CA isn't in the system trust store:
# export REQUESTS_CA_BUNDLE=/path/to/lab-ca.pem
repos/misp-scraper/.venv/bin/python scripts/configure_scraper.py
```

This writes a local `scraper.py` config that reads credentials from the
environment, so no key is saved to disk. It keeps TLS verification on, sets
distribution to *Organisation only*, turns retention off and enables
`extract_elements`.

## 2. misp-scraper: HTML to a reviewed MISP event

```bash
cat fixtures/article.html
repos/misp-scraper/.venv/bin/python scripts/scrape_fixture.py
```

The adapter calls upstream `MispScraperEvent.create_event` with the bundled raw
HTML and skips the Redis queue and Flask UI. It then reads back the stored
event and fails if the report or any of the three expected values is missing.

Then, in MISP:

1. Open the printed event ID. Check that it's **unpublished** with
   *Organisation only* distribution.
2. Open *Event Reports* and view the report.
3. In *Attributes*, find `beacon.example`, `192.0.2.42` and the training URL.
   Review types and IDS flags.

> Each run creates a new event, so write down the ID and don't rerun blindly.
> Don't run the upstream cron job, because its cleanup can delete old events.
> An extracted value is a candidate indicator, not proof that it's malicious.

## 3. CTI-Transmute: MISP → STIX → MISP

```bash
python3 -m json.tool fixtures/misp-event.json
bash scripts/convert.sh
python3 -m json.tool output/stix-response.json
python3 -m json.tool output/roundtrip.json
```

`convert.sh` sends **only** the bundled synthetic event to
`https://cti-transmute.org`. Set `TRANSMUTE_URL` to use a self-hosted instance
instead. It checks the service's converter list, converts MISP → STIX and STIX
→ MISP, and checks that all three values survive the round trip.

A successful HTTP response doesn't prove a lossless conversion. Check the
diagnostics, plus the `to_ids`, distribution and relationship fields, yourself.
The reverse direction can report a warning that the parser was inferred from
the content.

If the public service is down, inspect the saved responses instead. They're
synthetic outputs captured on 21 October 2026, not a fresh conversion:

```bash
python3 -m json.tool fixtures/rehearsal-stix-response.json
python3 -m json.tool fixtures/rehearsal-roundtrip.json
```

## 4. misp-mcp: list tools and find the demo event

Switch to the **read-only** key and keep the same `MISP_URL`:

```bash
read -r -s -p 'Read-only lab API key: ' MISP_API_KEY
printf '\n'
export MISP_API_KEY
repos/misp-mcp/.venv/bin/python scripts/mcp_probe.py
```

The probe is a local MCP SDK client over stdio, so no LLM is involved. It lists
the server's tools (including `search_event_index` and `get_event`), then
searches for the synthetic event, returning at most five results from page 1.
It times out after 45 seconds. An empty or error result counts as a failure.
If nothing comes back, check that the read-only user can see the unpublished
demo event.

To use it from your own MCP client, point the client's stdio server command at
the absolute path of `repos/misp-mcp/.venv/bin/misp-mcp`, and set
`MISP_URL`, `MISP_API_KEY` and `MISP_VERIFYCERT=true` in the client's
environment.

## 5. MISP Fleet Commander: see your lab fleet

Prepare it once on the Docker host:

```bash
bash scripts/prepare_fleet.sh
```

The script:

- builds the frontend (a fresh checkout doesn't include it)
- applies a Marshmallow 4 schema compatibility fix
- makes the frontend call the browser's origin so remote access works
- generates `compose.part12.json` with a random session secret and port 5001
  published
- builds images, starts Redis, migrates the database and asks you for a new
  admin password

npm's automatic audit is skipped during install. Run `npm audit` in
`repos/MISP-Fleet-Commander/web` to review frontend dependencies.

Open `http://<docker-host-ip>:5001` (or `http://localhost:5001` on the host) and
log in as `admin@admin.test` with your new password. Then:

1. *Fleets → New fleet*, then select it.
2. *Add servers*: enter the name, URL and authorization key. Leave *Skip SSL
   validation* off.
3. Use *Quick refresh* and open the server to view health, version and refresh
   time.
4. Optionally, open *Strategic View / Connections*. Expect an empty topology
   with a single instance.

The MISP URL must be reachable from inside the containers, where `localhost`
means the container itself, not your host. Keep this read-only and don't
enroll production servers.

Check status from the repo:

```bash
cd repos/MISP-Fleet-Commander
docker compose -f compose.part12.json ps
docker compose -f compose.part12.json logs --tail=50 backend
cd ../..
```

## 6. misp-guard: test sync policy decisions

```bash
cd repos/misp-guard/src
../.venv/bin/python -m pytest test/test_misp_guard.py -vv \
  -k 'push_new_event_blocked_event_tags or reject_non_minimal_events_index or non_allowed_endpoint_is_blocked'
cd ../../..
```

Before running, look at `repos/misp-guard/src/test/test_config.json` (find
`blocked_tags` → `tlp:red`) and `test_push_scenarios.json` (find
`push_new_event_blocked_event_tags`, which expects a 403).

Expected result: **4 passed, 139 deselected**. The selector also picks up the
feed endpoint rejection test. If zero tests are selected, that's a failure.

These tests use mocked mitmproxy flows. Passing them doesn't prove a deployed
network is protected. A real deployment needs two MISP instances, Guard in the
sync path, a trusted interception CA, and tests showing that allowed events
get through, denied events don't, and sync can't bypass Guard.

## Cleanup

```bash
unset MISP_API_KEY
cd repos/MISP-Fleet-Commander
docker compose -f compose.part12.json down
cd ../..
```

- Revoke both demo API keys.
- In the MISP UI, delete only the event IDs you wrote down, after checking
  their title and owner. Don't bulk-delete by search.
- Put back any lab settings you changed.
- Avoid `docker compose down -v` unless you mean to erase the volumes.
- `output/`, `repos/`, local configs and logs can contain credentials or event
  data, so don't commit or share them.

## More

- `TALKING_POINTS.md`: short key points for each project
- `VALIDATION.md`: what was tested, and the limits of those tests
- `source-revisions.json`: pinned upstream commits

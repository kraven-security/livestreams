# Fun MISP Projects — Part 12 lab kit

Extract to `misp-fun-projects-livestream/`. Canonical presenter runbook:
https://docs.google.com/document/d/1XRJbxtU4x8tmINn0oQx55EFBSIj8pKzFZ1Mw5F66oB8/edit

Environment assumption: disposable Linux VM or WSL2 with Bash, Git, curl,
Python 3.12 with venv, Docker Engine and Compose v2; existing lab MISP with
misp-modules. No infrastructure is installed by extracting this archive.

## Off-screen preparation

Run `bash scripts/prepare.sh`. It clones four upstream repos, records their
revisions in `output/rehearsal-revisions.txt`, and installs isolated Python
environments. Source revisions are pinned in source-revisions.json; the MCP SDK is pinned to 1.30.0 for FastMCP v1 compatibility. Other dependencies are not fully frozen: retain the tested revisions
and generated package lists before the broadcast. The MCP environment is recreated on each prepare run to avoid v1/v2 file conflicts. No external repository source is bundled. See VALIDATION.md for the checks actually performed and their limits.

Set a lab URL and hidden API key in Bash, with shell tracing disabled:

```bash
set +x
export MISP_URL='https://YOUR-LAB-MISP'
read -r -s -p 'Lab MISP API key: ' MISP_API_KEY
printf '\n'
export MISP_API_KEY
repos/misp-scraper/.venv/bin/python scripts/configure_scraper.py
```

Use a disposable writable demo key for the scraper (create events/reports,
extract report attributes, Tagger and Tag Editor). Switch to a separate
read-only demo key before the MCP segment. Trust your lab CA; the kit retains
certificate verification. See the runbook for MISP module prerequisites.

Read TALKING_POINTS.md for short presenter cues for each project.

## Live commands, in episode order

```bash
repos/misp-scraper/.venv/bin/python scripts/scrape_fixture.py
bash scripts/convert.sh
repos/misp-mcp/.venv/bin/python scripts/mcp_probe.py
```

Scraper adapter calls the actual upstream `MispScraperEvent.create_event`
method with supplied raw HTML, bypassing the Redis queue and Flask UI. It
requires an accessible lab MISP, adds an event on every run, and does not
publish it. It now checks the stored event/report and all three expected values,
and fails if extraction did not complete. Record the printed event ID on failure. Review distribution, report, attributes and IDS flags in MISP.

CTI conversion sends ONLY the bundled synthetic JSON to the selected service.
Set `TRANSMUTE_URL` for a local installation. It calls discovery, then both
conversion directions, retaining diagnostics. HTTP 200 alone is not fidelity. If the service fails, use fixtures/rehearsal-stix-response.json and fixtures/rehearsal-roundtrip.json as explicitly labelled synthetic responses captured on 21 October 2026; they are not a fresh conversion.

MCP probe is a deterministic SDK client over stdio, not an LLM conversation.
It lists tools and searches at most five matching events. Run it only against
a synthetic lab; output includes event metadata.

For Fleet Commander, install Node/npm and Docker Compose v2 on the lab host,
then run off-screen from the extracted kit root:

```bash
bash scripts/prepare_fleet.sh
```

This builds the missing frontend with npm ci/buildproduction, checks index.html,
applies the Fleet schema compatibility fix for Marshmallow 4 (`missing=None`
becomes `load_default=None`), creates a private compose.part12.json with a
loopback-only port and a random session secret, builds images, starts Redis,
migrates the mounted database,
prompts for a new admin password and starts backend/workers. Login at
http://localhost:5001 on the Docker host using admin@admin.test and your chosen
password. Keep the enrollment screen off-camera: its API-key field is visible.
The MISP URL must be reachable from containers; localhost refers to a container,
not the host MISP. This full Docker path still requires rehearsal on your host.
The frontend build was blocked in the review container by a restricted
networkInterfaces() system call; Docker is not installed in that environment.

Use the generated configuration for later actions and cleanup:

```bash
cd repos/MISP-Fleet-Commander
docker compose -f compose.part12.json ps
docker compose -f compose.part12.json down
```

For Guard, use actual upstream mocked-flow tests, not a deployed proxy:

```bash
cd repos/misp-guard/src
../.venv/bin/python -m pytest test/test_misp_guard.py -vv \
  -k 'push_new_event_blocked_event_tags or reject_non_minimal_events_index or non_allowed_endpoint_is_blocked'
```

Review result: 4 selected tests passed (139 deselected); they assert 403 decisions. The substring selector also selects the feed endpoint rejection test.
Zero selected tests is a failure, not a demonstration. A successful deployment
requires separate two-instance sync and TLS/proxy testing.

## Cleanup

Stop your lab Fleet Commander with `docker compose -f compose.part12.json down` from its repo.
Do not use `down -v` as casual cleanup. Remove only recorded Part12-created
MISP event IDs in the UI after checking their titles/owner. Revoke demo keys,
`unset MISP_API_KEY`, and close the SDK client. No Guard proxy settings were
changed by this lab. Keep outputs private until reviewed. Do not repackage
repos, local configs, logs, credentials, or output in shared copies.

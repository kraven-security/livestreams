# Fun MISP Projects — Part 12 lab kit

Extract to `misp-fun-projects-livestream/`. Canonical presenter runbook:
https://docs.google.com/document/d/1XRJbxtU4x8tmINn0oQx55EFBSIj8pKzFZ1Mw5F66oB8/edit

Environment assumption: disposable Linux VM or WSL2 with Bash, Git, curl,
Python 3.12 with venv, Docker Engine and Compose v2; existing lab MISP with
misp-modules. No infrastructure is installed by extracting this archive.

## Off-screen preparation

Run `bash scripts/prepare.sh`. It clones four upstream repos, records their
revisions in `output/rehearsal-revisions.txt`, and installs isolated Python
environments. Dependencies are not frozen here: retain the tested revisions
and `pip freeze` output before the broadcast. No external repository source
is bundled or represented as having passed tests here.

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

## Live commands, in episode order

```bash
repos/misp-scraper/.venv/bin/python scripts/scrape_fixture.py
bash scripts/convert.sh
repos/misp-mcp/.venv/bin/python scripts/mcp_probe.py
```

Scraper adapter calls the actual upstream `MispScraperEvent.create_event`
method with supplied raw HTML, bypassing the Redis queue and Flask UI. It
requires an accessible lab MISP, adds an event on every run, and does not
publish it. Review distribution, report, attributes and IDS flags in MISP.

CTI conversion sends ONLY the bundled synthetic JSON to the selected service.
Set `TRANSMUTE_URL` for a local installation. It calls discovery, then both
conversion directions, retaining diagnostics. HTTP 200 alone is not fidelity.

MCP probe is a deterministic SDK client over stdio, not an LLM conversation.
It lists tools and searches at most five matching events. Run it only against
a synthetic lab; output includes event metadata.

For Fleet Commander, prepare off-screen:

```bash
cd repos/MISP-Fleet-Commander
docker compose config
docker compose up --build -d
```

Use a disposable VM reachable only from your workstation: upstream publishes
port 5001 on all interfaces. Log in at http://localhost:5001 using the
upstream demo credentials `admin@admin.test` / `Password1234`, then change
them before enrolling lab servers. See the runbook for the UI exercise.

For Guard, use actual upstream mocked-flow tests, not a deployed proxy:

```bash
cd repos/misp-guard/src
../.venv/bin/python -m pytest test/test_misp_guard.py -vv \
  -k 'push_new_event_blocked_event_tags or reject_non_minimal_events_index or non_allowed_endpoint_is_blocked'
```

Expected: selected tests are collected and pass; they assert 403 decisions.
Zero selected tests is a failure, not a demonstration. A successful deployment
requires separate two-instance sync and TLS/proxy testing.

## Cleanup

Stop your lab Fleet Commander with `docker compose down` from its repo.
Do not use `down -v` as casual cleanup. Remove only recorded Part12-created
MISP event IDs in the UI after checking their titles/owner. Revoke demo keys,
`unset MISP_API_KEY`, and close the SDK client. No Guard proxy settings were
changed by this lab. Keep outputs private until reviewed. Do not repackage
repos, local configs, logs, credentials, or output in shared copies.

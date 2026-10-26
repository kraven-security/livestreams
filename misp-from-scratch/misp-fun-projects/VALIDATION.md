# Preparation validation — 21 October 2026

Performed in the preparation environment:

- `python3 -m py_compile scripts/configure_scraper.py scripts/scrape_fixture.py scripts/mcp_probe.py`: PASS (syntax only; no project imports executed).
- `bash -n scripts/prepare.sh` and `bash -n scripts/convert.sh`: PASS.
- Fixture JSON parsing, valid event/attribute UUIDs, three expected indicator values, unpublished event, distribution 0 and false IDS flags: PASS.
- ZIP integrity and exact 10-file inventory: PASS. No repos, credentials, logs, output or bytecode are bundled.

Primary-source review checked method/argument names, MCP stdio behavior,
Guard selected test names/configuration and Fleet Compose service layout.
This is not runtime validation or a dependency audit. Source code remains in
the upstream repositories and is cloned by prepare.sh at rehearsal time.

Not performed: dependency installation, upstream Guard tests, MISP event
creation/extraction, MCP calls, Fleet startup/enrollment, conversion API calls,
real Guard sync/TLS tests, or a timed rehearsal. No live lab environment or
credentials were supplied. Do not infer success from syntax checks.

Manual tests pending: all checklist items in section 9 of the Google Doc.
Expected results and failure-report fields are specified there. Record the
actual Git commit and dependency versions after a successful rehearsal.

Drive/Linear artifact verification is performed separately after upload;
this ZIP makes no claim about those later operations.

# Review validation — 21 October 2026

## Checks actually performed

- Python 3.12.14: all four companion Python files compile; all three Bash scripts pass bash -n.
- All three Python environments installed; pip check reports no broken requirements.
- Scraper: actual upstream create_event/raw-HTML path and companion readback checks passed with a mocked MISP transport. A negative case with missing extracted values failed as intended. No live MISP used.
- MCP: found and fixed a real startup failure caused by SDK 2.x. Fresh kit environment with mcp==1.30.0 successfully initialized the actual upstream stdio server and listed 14 tools. The complete companion probe passed an actual stdio call with a mocked MISP backend; an empty-result case failed as intended. FastMCP v1 emits separate text blocks for list items; the parser now handles that.
- Guard at e8b3cfa1d0a7940f32497671ebfaef967ed79ea1, mitmproxy 12.2.3: selected upstream command passed 4 tests, 139 deselected, 42 dependency deprecation warnings. Selection also matches the feed endpoint rejection test. These are mocked-flow assertions, not real synchronization tests.
- CTI-Transmute: public discovery endpoint advertised both POST converters. Initial forward request returned 503; one retry succeeded. Forward conversion produced 9 STIX objects with 0 warnings/errors. Reverse conversion preserved the three synthetic values; diagnostics reported 1 warning (internal parser inferred from content), 0 errors. Rehearsal responses are included as dated, synthetic fallbacks. Availability and semantic fidelity still need checking before the stream.
- Fleet: source review confirmed a missing frontend build, mounted SQLite database migration and explicit password reset steps. Added prepare_fleet.sh with those steps, a loopback-only port and stable random session secret. npm ci succeeded (Node 24.19.0/npm 11.9.0, legacy engine/deprecation warnings). Frontend build was blocked here by uv_interface_addresses/system networkInterfaces permissions. Docker is unavailable here, so container build, runtime migrations, password reset and enrollment remain untested.
- Source revisions are pinned in source-revisions.json; complete installed package lists are generated in output/ during preparation. MCP environment is recreated on prepare reruns to prevent SDK v1/v2 leftover-file conflicts.
- Fixture JSON/UUID/value/state checks and final ZIP integrity/inventory passed. ZIP uses an explicit allowlist; no repositories, virtual environments, logs, local config, keys or output directories are shared.

## Commands used

```bash
# from repos/misp-guard/src
../.venv/bin/python -m pytest test/test_misp_guard.py -vv -k 'push_new_event_blocked_event_tags or reject_non_minimal_events_index or non_allowed_endpoint_is_blocked'

# from extracted root after conversion responses exist
python3 scripts/check_roundtrip.py
```

## Still pending

A real lab MISP scraper/extraction run; actual read-only MISP query; Fleet build/start/enrollment on the intended host; real Guard TLS/sync/bypass tests if that scope is later added; final timed rehearsal, screen/capture review, cleanup and Adam’s sign-off. Mock results do not satisfy live acceptance.

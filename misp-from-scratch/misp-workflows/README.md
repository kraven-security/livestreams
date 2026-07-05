# Kraven Security — MISP Workflow Blueprints

Four reusable [MISP Workflow](https://www.misp-project.org/misp-training/a.12-misp-workflows.pdf) blueprints, produced alongside the Kraven Security MISP Workflows livestream. Each is a node sub-graph in MISP's native blueprint format (the same schema used by [`MISP/misp-workflow-blueprints`](https://github.com/MISP/misp-workflow-blueprints)), so they import directly and can be PR'd upstream.

Blueprints contain **no trigger** (per MISP's rules). The trigger each one is designed for is noted in the file `description` field in `[square brackets]`, matching the official convention.

| Blueprint | Trigger | Type | What it does |
|-----------|---------|------|--------------|
| Auto-tag & enrich IP attributes on save | `attribute-after-save` | non-blocking | Filters new IP IoCs → mmdb geo enrichment → attaches `kraven:auto-tagged` |
| Notify on publish (webhook / Slack) | `event-publish` | non-blocking | POSTs the published event to a webhook (Slack incoming hook or listener) |
| Block publish if TLP marking is missing | `event-publish` | **blocking** | Stops publishing any event that has no `tlp:*` tag, and logs why |
| Push flagged events to automation hub | `event-publish` | non-blocking | Only events tagged `workflow:send-to-soar` are POSTed to an orchestrator |

## Requirements

- MISP ≥ **2.4.160** (Workflows introduced here)
- Workflows enabled: `Administration → Server Settings & Maintenance → Plugin → Workflow → enable` (`Plugin.Workflow_enable = true`)
- **Auto-tag & enrich**: `misp-modules` running + the `mmdb_lookup` enrichment module enabled
- **Webhook blueprints**: arbitrary outbound URLs allowed —
  `sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting Security.rest_client_enable_arbitrary_urls true`

## How to use

1. In MISP go to **Workflows → Blueprints** and import the JSON (or paste it).
2. Open the relevant trigger under **Workflows → List Triggers** (e.g. *Event Publish*) and edit its workflow.
3. Drag the imported blueprint onto the canvas and connect the **trigger's output → the blueprint's entry node**.
4. For webhook blueprints, open the **Webhook** node and replace the placeholder `url` with your real endpoint.
5. Save, enable the trigger, and test with a throwaway event before relying on it.

## Per-blueprint notes

**Auto-tag & enrich IP attributes on save** — non-blocking, so a failed enrichment never blocks the save. The tag is persisted; enrichment results follow normal enrichment-persistence behaviour, so if you need enrichment-*derived* objects stored, prefer an enrichment-oriented trigger path.

**Notify on publish (webhook / Slack)** — Slack incoming webhooks need no auth header, which sidesteps the webhook module's lack of custom-header support. Points at a Slack hook or the bundled `tools/misp-workflows/webhook-listener.py` for local testing. The webhook module's exact field labels (`url`, `data_extraction_path`) can vary slightly by MISP version — confirm in the node editor after import.

**Block publish if TLP marking is missing** — the headline governance pattern. `IF :: Tag` output 1 (has a TLP tag) lets publishing proceed; output 2 (no TLP tag) routes to `Stop execution`, which cancels the publish and logs the reason to `/admin/logs` and `app/tmp/logs/workflow-execution.log`. Because this is on a **blocking** trigger, a workflow that errors can stall publishing — always test before enabling. (See MISP issue #9621 for a known synced-event edge case.)

**Push flagged events to automation hub** — tag-gated so only events explicitly marked `workflow:send-to-soar` are pushed, keeping the firehose off. The receiver (n8n / SOAR / a PyMISP listener) can act on the payload and call back into the MISP REST API to close the loop.
